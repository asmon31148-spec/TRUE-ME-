-- Hybrid RAG Search (pgvector cosine similarity + PostgreSQL full-text search via RRF)
-- Inspired by open-notebook's hybrid search pipeline, native to Supabase PostgreSQL.

ALTER TABLE public.document_chunks
  ADD COLUMN IF NOT EXISTS fts_vector tsvector
  GENERATED ALWAYS AS (to_tsvector('english', coalesce(content, ''))) STORED;

CREATE INDEX IF NOT EXISTS idx_document_chunks_fts
  ON public.document_chunks USING GIN (fts_vector);

CREATE OR REPLACE FUNCTION public.match_document_chunks_hybrid (
  query_embedding VECTOR(768),
  query_text TEXT DEFAULT '',
  match_count INT DEFAULT 6,
  filter_user_id TEXT DEFAULT NULL,
  filter_notebook_id TEXT DEFAULT NULL,
  rrf_k INT DEFAULT 50
)
RETURNS TABLE (
  id UUID,
  notebook_id TEXT,
  file_name TEXT,
  chunk_index INT,
  content TEXT,
  similarity FLOAT
)
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS $$
DECLARE
  effective_user_id TEXT;
  clean_query TEXT;
  ts_q tsquery;
BEGIN
  effective_user_id := auth.uid()::text;

  IF effective_user_id IS NULL THEN
    RAISE EXCEPTION 'Unauthorized: Authenticated session required for hybrid search';
  END IF;

  clean_query := NULLIF(BTRIM(COALESCE(query_text, '')), '');
  IF clean_query IS NOT NULL THEN
    ts_q := websearch_to_tsquery('english', clean_query);
  END IF;

  RETURN QUERY
  WITH vector_matches AS (
    SELECT
      dc.id,
      dc.notebook_id,
      dc.file_name,
      dc.chunk_index,
      dc.content,
      (1 - (dc.embedding <=> query_embedding))::FLOAT AS vec_sim,
      ROW_NUMBER() OVER (ORDER BY dc.embedding <=> query_embedding) AS vec_rank
    FROM public.document_chunks dc
    WHERE
      dc.user_id = effective_user_id
      AND (filter_notebook_id IS NULL OR dc.notebook_id = filter_notebook_id)
    ORDER BY dc.embedding <=> query_embedding
    LIMIT GREATEST(match_count * 3, 15)
  ),
  keyword_matches AS (
    SELECT
      dc.id,
      dc.notebook_id,
      dc.file_name,
      dc.chunk_index,
      dc.content,
      ts_rank_cd(dc.fts_vector, ts_q)::FLOAT AS kw_score,
      ROW_NUMBER() OVER (ORDER BY ts_rank_cd(dc.fts_vector, ts_q) DESC) AS kw_rank
    FROM public.document_chunks dc
    WHERE
      ts_q IS NOT NULL
      AND dc.user_id = effective_user_id
      AND (filter_notebook_id IS NULL OR dc.notebook_id = filter_notebook_id)
      AND dc.fts_vector @@ ts_q
    ORDER BY ts_rank_cd(dc.fts_vector, ts_q) DESC
    LIMIT GREATEST(match_count * 3, 15)
  ),
  fused AS (
    SELECT
      COALESCE(v.id, k.id) AS id,
      COALESCE(v.notebook_id, k.notebook_id) AS notebook_id,
      COALESCE(v.file_name, k.file_name) AS file_name,
      COALESCE(v.chunk_index, k.chunk_index) AS chunk_index,
      COALESCE(v.content, k.content) AS content,
      GREATEST(
        COALESCE(v.vec_sim, 0.0),
        LEAST(
          0.99,
          (COALESCE(1.0 / (rrf_k + v.vec_rank), 0.0) +
           COALESCE(1.0 / (rrf_k + k.kw_rank), 0.0)) * 30.0
        )
      )::FLOAT AS similarity,
      (
        COALESCE(1.0 / (rrf_k + v.vec_rank), 0.0) +
        COALESCE(1.0 / (rrf_k + k.kw_rank), 0.0)
      ) AS rrf_score
    FROM vector_matches v
    FULL OUTER JOIN keyword_matches k ON v.id = k.id
  )
  SELECT
    f.id,
    f.notebook_id,
    f.file_name,
    f.chunk_index,
    f.content,
    f.similarity
  FROM fused f
  ORDER BY f.rrf_score DESC, f.similarity DESC
  LIMIT match_count;
END;
$$;

REVOKE ALL ON FUNCTION public.match_document_chunks_hybrid(VECTOR(768), TEXT, INT, TEXT, TEXT, INT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.match_document_chunks_hybrid(VECTOR(768), TEXT, INT, TEXT, TEXT, INT) TO authenticated;
