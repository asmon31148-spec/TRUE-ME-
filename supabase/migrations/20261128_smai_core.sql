-- ==============================================================================
-- TRUE ME: SMAI (Student Memory & Adaptive Intelligence) Core Schema
-- Non-destructive additive tables with strict tenant RLS & FTS (no chat vectors).
-- ==============================================================================

-- 1. Immutable Learning Events (Source of Truth for Student Activity)
CREATE TABLE IF NOT EXISTS public.learning_events (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  subject_id TEXT,
  node_id TEXT,
  event_type TEXT NOT NULL,
  idempotency_key TEXT NOT NULL,
  schema_version INT NOT NULL DEFAULT 1,
  processing_status TEXT NOT NULL DEFAULT 'processed',
  occurred_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  payload JSONB NOT NULL DEFAULT '{}'::jsonb,
  provenance_refs JSONB NOT NULL DEFAULT '[]'::jsonb,
  search_text TEXT NOT NULL DEFAULT '',
  search_tsv TSVECTOR GENERATED ALWAYS AS (
    to_tsvector('english', coalesce(search_text, ''))
  ) STORED
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_learning_events_idempotency
  ON public.learning_events (user_id, idempotency_key);

CREATE INDEX IF NOT EXISTS idx_learning_events_user_subject_time
  ON public.learning_events (user_id, subject_id, occurred_at DESC);

CREATE INDEX IF NOT EXISTS idx_learning_events_search_tsv
  ON public.learning_events USING GIN (search_tsv);

-- 2. Derived Versioned Memory Records (Evidence-Linked & Correctable)
CREATE TABLE IF NOT EXISTS public.memory_records (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  subject_id TEXT,
  node_id TEXT,
  memory_type TEXT NOT NULL,
  information_class TEXT NOT NULL DEFAULT 'derived_insight',
  content TEXT NOT NULL,
  confidence REAL NOT NULL DEFAULT 0.5,
  sample_size INT NOT NULL DEFAULT 1,
  evidence_ids JSONB NOT NULL DEFAULT '[]'::jsonb,
  supersedes_id TEXT,
  derivation_version INT NOT NULL DEFAULT 1,
  access_scope TEXT NOT NULL DEFAULT 'subject',
  is_active BOOLEAN NOT NULL DEFAULT true,
  observed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  last_confirmed_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_memory_records_user_scope_active
  ON public.memory_records (user_id, subject_id, is_active, last_confirmed_at DESC);

-- 3. Time-Stamped Topic Mastery Snapshots
CREATE TABLE IF NOT EXISTS public.mastery_snapshots (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  subject_id TEXT NOT NULL,
  node_id TEXT,
  topic_label TEXT NOT NULL,
  mastery_score REAL NOT NULL,
  confidence REAL NOT NULL DEFAULT 0.5,
  sample_size INT NOT NULL DEFAULT 1,
  method TEXT NOT NULL DEFAULT 'deterministic_weighted',
  evidence_ids JSONB NOT NULL DEFAULT '[]'::jsonb,
  captured_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_mastery_snapshots_user_subject_time
  ON public.mastery_snapshots (user_id, subject_id, captured_at DESC);

-- 4. Retrieval Audit Trail (Traceability)
CREATE TABLE IF NOT EXISTS public.retrieval_audits (
  trace_id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  ai_mode TEXT NOT NULL,
  subject_id TEXT,
  request_intent TEXT NOT NULL,
  retrieved_count INT NOT NULL DEFAULT 0,
  uncertainty_flags JSONB NOT NULL DEFAULT '[]'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 5. Strict Owner-Scoped Row Level Security
ALTER TABLE public.learning_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.memory_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.mastery_snapshots ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.retrieval_audits ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users manage own learning_events" ON public.learning_events;
CREATE POLICY "Users manage own learning_events"
ON public.learning_events FOR ALL
TO authenticated
USING ((SELECT auth.uid())::text = user_id)
WITH CHECK ((SELECT auth.uid())::text = user_id);

DROP POLICY IF EXISTS "Users manage own memory_records" ON public.memory_records;
CREATE POLICY "Users manage own memory_records"
ON public.memory_records FOR ALL
TO authenticated
USING ((SELECT auth.uid())::text = user_id)
WITH CHECK ((SELECT auth.uid())::text = user_id);

DROP POLICY IF EXISTS "Users manage own mastery_snapshots" ON public.mastery_snapshots;
CREATE POLICY "Users manage own mastery_snapshots"
ON public.mastery_snapshots FOR ALL
TO authenticated
USING ((SELECT auth.uid())::text = user_id)
WITH CHECK ((SELECT auth.uid())::text = user_id);

DROP POLICY IF EXISTS "Users manage own retrieval_audits" ON public.retrieval_audits;
CREATE POLICY "Users manage own retrieval_audits"
ON public.retrieval_audits FOR ALL
TO authenticated
USING ((SELECT auth.uid())::text = user_id)
WITH CHECK ((SELECT auth.uid())::text = user_id);
