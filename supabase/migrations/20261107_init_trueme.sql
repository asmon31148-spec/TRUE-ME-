-- ==============================================================================
-- TRUE ME: Supabase PostgreSQL & pgvector Schema
-- Version: 1.1.0
-- ==============================================================================

-- 1. Enable pgvector extension
CREATE EXTENSION IF NOT EXISTS vector;

-- 2. Processed document chunks for RAG
CREATE TABLE IF NOT EXISTS document_chunks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT NOT NULL,
  notebook_id TEXT NOT NULL,
  file_name TEXT,
  file_type TEXT,
  chunk_index INT NOT NULL,
  content TEXT NOT NULL,
  embedding VECTOR(768), -- Gemini text-embedding dimension
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index for user and notebook queries
CREATE INDEX IF NOT EXISTS idx_doc_chunks_user_notebook 
ON document_chunks(user_id, notebook_id);

-- Cosine distance IVFFlat index on embedding
CREATE INDEX IF NOT EXISTS idx_doc_chunks_embedding 
ON document_chunks 
USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100);

-- 3. User file metadata (raw content remains in user's Google Drive)
CREATE TABLE IF NOT EXISTS user_files (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT NOT NULL,
  notebook_id TEXT NOT NULL,
  file_name TEXT NOT NULL,
  file_type TEXT NOT NULL, -- pdf, audio, image, web_url, youtube
  drive_file_id TEXT,      -- Provider file reference
  size_bytes BIGINT DEFAULT 0,
  processed BOOLEAN DEFAULT FALSE,
  chunk_count INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_user_files_user_notebook 
ON user_files(user_id, notebook_id);

-- 4. Study session activity logs (for Sage's 6:00 AM daily analysis)
CREATE TABLE IF NOT EXISTS study_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT NOT NULL,
  subject TEXT NOT NULL,
  topic TEXT NOT NULL,
  session_type TEXT NOT NULL, -- flashcard, quiz, chat, voice_tutor, explainer
  duration_min INT NOT NULL DEFAULT 0,
  score FLOAT,                -- 0.0 - 100.0, null if not a scored session
  metadata JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_study_sessions_user_time 
ON study_sessions(user_id, created_at DESC);

-- 5. Semantic Vector Search Function (RPC)
CREATE OR REPLACE FUNCTION match_document_chunks (
  query_embedding VECTOR(768),
  match_count INT DEFAULT 5,
  filter_user_id TEXT DEFAULT NULL,
  filter_notebook_id TEXT DEFAULT NULL
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
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT
    dc.id,
    dc.notebook_id,
    dc.file_name,
    dc.chunk_index,
    dc.content,
    (1 - (dc.embedding <=> query_embedding))::FLOAT AS similarity
  FROM document_chunks dc
  WHERE
    (filter_user_id IS NULL OR dc.user_id = filter_user_id)
    AND (filter_notebook_id IS NULL OR dc.notebook_id = filter_notebook_id)
  ORDER BY dc.embedding <=> query_embedding
  LIMIT match_count;
END;
$$;

-- 6. Row Level Security (RLS) Permissive Policies for True Me app
ALTER TABLE document_chunks ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_files ENABLE ROW LEVEL SECURITY;
ALTER TABLE study_sessions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow app access to document_chunks" ON document_chunks;
CREATE POLICY "Allow app access to document_chunks" ON document_chunks FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow app access to user_files" ON user_files;
CREATE POLICY "Allow app access to user_files" ON user_files FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow app access to study_sessions" ON study_sessions;
CREATE POLICY "Allow app access to study_sessions" ON study_sessions FOR ALL USING (true) WITH CHECK (true);
