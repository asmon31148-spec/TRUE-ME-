-- ==============================================================================
-- TRUE ME: Phase C & D — Syllabus Hierarchy, Source Coverage & Study Artifacts
-- ==============================================================================

-- 1. Add provenance columns to document_chunks
ALTER TABLE public.document_chunks
  ADD COLUMN IF NOT EXISTS page_number INT,
  ADD COLUMN IF NOT EXISTS section_label TEXT;

-- 2. Syllabus Hierarchy Nodes (semester -> unit -> topic -> subtopic)
CREATE TABLE IF NOT EXISTS public.syllabus_nodes (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  notebook_id TEXT NOT NULL,
  parent_id TEXT,
  node_type TEXT NOT NULL,
  title TEXT NOT NULL,
  academic_level TEXT,
  source_origin TEXT NOT NULL DEFAULT 'official_syllabus',
  confirmed BOOLEAN NOT NULL DEFAULT true,
  archived BOOLEAN NOT NULL DEFAULT false,
  sort_order INT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_syllabus_nodes_user_nb
  ON public.syllabus_nodes (user_id, notebook_id, archived, sort_order);

-- 3. Source-to-Syllabus Coverage Mappings
CREATE TABLE IF NOT EXISTS public.source_syllabus_mappings (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  notebook_id TEXT NOT NULL,
  source_name TEXT NOT NULL,
  node_id TEXT NOT NULL,
  coverage_status TEXT NOT NULL DEFAULT 'covered',
  confidence REAL NOT NULL DEFAULT 0.8,
  page_range TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_source_mappings_user_nb
  ON public.source_syllabus_mappings (user_id, notebook_id);

-- 4. Persistent Study Artifacts Library
CREATE TABLE IF NOT EXISTS public.study_artifacts (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  notebook_id TEXT NOT NULL,
  node_id TEXT,
  artifact_type TEXT NOT NULL,
  title TEXT NOT NULL,
  topic_label TEXT,
  depth_level TEXT,
  content_json JSONB,
  file_path TEXT,
  vault_id TEXT,
  source_chat_id TEXT,
  archived BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_study_artifacts_user_nb_type
  ON public.study_artifacts (user_id, notebook_id, artifact_type, created_at DESC);

-- 5. Strict Owner-Scoped RLS
ALTER TABLE public.syllabus_nodes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.source_syllabus_mappings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.study_artifacts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users manage own syllabus_nodes" ON public.syllabus_nodes;
CREATE POLICY "Users manage own syllabus_nodes"
ON public.syllabus_nodes FOR ALL
TO authenticated
USING ((SELECT auth.uid())::text = user_id)
WITH CHECK ((SELECT auth.uid())::text = user_id);

DROP POLICY IF EXISTS "Users manage own source_syllabus_mappings" ON public.source_syllabus_mappings;
CREATE POLICY "Users manage own source_syllabus_mappings"
ON public.source_syllabus_mappings FOR ALL
TO authenticated
USING ((SELECT auth.uid())::text = user_id)
WITH CHECK ((SELECT auth.uid())::text = user_id);

DROP POLICY IF EXISTS "Users manage own study_artifacts" ON public.study_artifacts;
CREATE POLICY "Users manage own study_artifacts"
ON public.study_artifacts FOR ALL
TO authenticated
USING ((SELECT auth.uid())::text = user_id)
WITH CHECK ((SELECT auth.uid())::text = user_id);
