-- ==============================================================================
-- TRUE ME: Durable Generation Jobs Ledger
-- Persists document generation job state, stages, and errors per authenticated user.
-- ==============================================================================

CREATE TABLE IF NOT EXISTS public.generation_jobs (
  job_id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  notebook_id TEXT NOT NULL,
  subject TEXT NOT NULL,
  topic TEXT NOT NULL,
  scope_label TEXT NOT NULL DEFAULT 'Full Subject Sources',
  format TEXT NOT NULL,
  style_id TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'queued',
  stage_index INT NOT NULL DEFAULT 0,
  stage_label TEXT NOT NULL DEFAULT 'Queued',
  file_path TEXT,
  title TEXT,
  error_message TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_generation_jobs_user_updated
  ON public.generation_jobs (user_id, updated_at DESC);

ALTER TABLE public.generation_jobs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users manage own generation_jobs" ON public.generation_jobs;
CREATE POLICY "Users manage own generation_jobs"
ON public.generation_jobs FOR ALL
TO authenticated
USING ((auth.uid())::text = user_id)
WITH CHECK ((auth.uid())::text = user_id);
