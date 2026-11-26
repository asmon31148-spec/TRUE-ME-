-- ==============================================================================
-- TRUE ME: AI Model & Quota Monitor Telemetry & Snapshot Schema
-- Stores model registry, per-request telemetry (no prompts/PII), and official
-- provider usage snapshots for reconciliation and historical analytics.
-- ==============================================================================

CREATE TABLE IF NOT EXISTS public.ai_request_telemetry (
  request_id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  provider TEXT NOT NULL,
  model_id TEXT NOT NULL,
  feature_name TEXT NOT NULL DEFAULT 'General',
  callback_route TEXT NOT NULL DEFAULT 'unknown',
  status TEXT NOT NULL DEFAULT 'success',
  input_tokens INT NOT NULL DEFAULT 0,
  output_tokens INT NOT NULL DEFAULT 0,
  cached_tokens INT NOT NULL DEFAULT 0,
  total_tokens INT NOT NULL DEFAULT 0,
  token_source TEXT NOT NULL DEFAULT 'ESTIMATED',
  provider_cost_usd NUMERIC(12, 8),
  calculated_cost_usd NUMERIC(12, 8) NOT NULL DEFAULT 0,
  cost_source TEXT NOT NULL DEFAULT 'ESTIMATED',
  latency_ms INT NOT NULL DEFAULT 0,
  retry_count INT NOT NULL DEFAULT 0,
  fallback_used BOOLEAN NOT NULL DEFAULT FALSE,
  error_detail TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_ai_telemetry_user_created
  ON public.ai_request_telemetry (user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_ai_telemetry_model_created
  ON public.ai_request_telemetry (model_id, created_at DESC);

CREATE TABLE IF NOT EXISTS public.ai_provider_snapshots (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id TEXT NOT NULL,
  provider TEXT NOT NULL,
  source_status TEXT NOT NULL DEFAULT 'OFFICIAL',
  snapshot_json JSONB NOT NULL DEFAULT '{}'::jsonb,
  error_message TEXT,
  fetched_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_ai_snapshots_user_provider
  ON public.ai_provider_snapshots (user_id, provider, fetched_at DESC);

ALTER TABLE public.ai_request_telemetry ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_provider_snapshots ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users read own ai_request_telemetry" ON public.ai_request_telemetry;
CREATE POLICY "Users read own ai_request_telemetry"
ON public.ai_request_telemetry FOR SELECT
TO authenticated
USING ((auth.uid())::text = user_id);

DROP POLICY IF EXISTS "Users insert own ai_request_telemetry" ON public.ai_request_telemetry;
CREATE POLICY "Users insert own ai_request_telemetry"
ON public.ai_request_telemetry FOR INSERT
TO authenticated
WITH CHECK ((auth.uid())::text = user_id);

DROP POLICY IF EXISTS "Users read own ai_provider_snapshots" ON public.ai_provider_snapshots;
CREATE POLICY "Users read own ai_provider_snapshots"
ON public.ai_provider_snapshots FOR SELECT
TO authenticated
USING ((auth.uid())::text = user_id);

DROP POLICY IF EXISTS "Users insert own ai_provider_snapshots" ON public.ai_provider_snapshots;
CREATE POLICY "Users insert own ai_provider_snapshots"
ON public.ai_provider_snapshots FOR INSERT
TO authenticated
WITH CHECK ((auth.uid())::text = user_id);
