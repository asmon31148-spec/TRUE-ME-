-- ==============================================================================
-- TRUE ME: SAGE-001 Reliable Source Ingestion & Idempotency Index
-- ==============================================================================

ALTER TABLE public.document_chunks
  ADD COLUMN IF NOT EXISTS doc_id TEXT;

CREATE INDEX IF NOT EXISTS idx_document_chunks_file_lookup
  ON public.document_chunks (user_id, notebook_id, file_name, chunk_index);
