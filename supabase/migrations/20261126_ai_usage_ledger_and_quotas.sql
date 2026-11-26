-- ==============================================================================
-- TRUE ME: Phase 3 AI Usage Ledger & Server-Side Quotas (AI-01 & AI-02)
-- Single-owner idempotent usage accounting and trusted server-side quota checks.
-- ==============================================================================

CREATE TABLE IF NOT EXISTS public.user_ai_quotas (
  user_id TEXT PRIMARY KEY,
  plan TEXT NOT NULL DEFAULT 'free',
  daily_limit INT NOT NULL DEFAULT 150,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.ai_usage_ledger (
  request_id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  provider TEXT NOT NULL,
  task_type TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'success',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_ai_usage_ledger_user_day
  ON public.ai_usage_ledger (user_id, created_at DESC);

ALTER TABLE public.user_ai_quotas ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_usage_ledger ENABLE ROW LEVEL SECURITY;

-- Users can read their own quota and usage ledger, but cannot self-modify limits
DROP POLICY IF EXISTS "Users read own ai_quotas" ON public.user_ai_quotas;
CREATE POLICY "Users read own ai_quotas"
ON public.user_ai_quotas FOR SELECT
TO authenticated
USING ((auth.uid())::text = user_id);

DROP POLICY IF EXISTS "Users read own ai_usage_ledger" ON public.ai_usage_ledger;
CREATE POLICY "Users read own ai_usage_ledger"
ON public.ai_usage_ledger FOR SELECT
TO authenticated
USING ((auth.uid())::text = user_id);

-- Atomic, idempotent quota check + usage recording RPC
CREATE OR REPLACE FUNCTION public.check_and_record_ai_usage(
  p_request_id TEXT,
  p_provider TEXT,
  p_task_type TEXT,
  p_status TEXT DEFAULT 'success'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id TEXT;
  v_limit INT;
  v_used_today INT;
  v_day_start TIMESTAMPTZ;
BEGIN
  v_user_id := auth.uid()::text;
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Unauthorized: Authenticated session required for AI usage';
  END IF;

  IF p_request_id IS NULL OR length(trim(p_request_id)) = 0 THEN
    RAISE EXCEPTION 'Invalid request_id';
  END IF;

  -- Idempotency: if this request_id was already recorded, return current state without double-counting
  IF EXISTS (SELECT 1 FROM public.ai_usage_ledger WHERE request_id = p_request_id) THEN
    SELECT COALESCE(q.daily_limit, 150) INTO v_limit
    FROM public.user_ai_quotas q WHERE q.user_id = v_user_id;
    v_limit := COALESCE(v_limit, 150);

    v_day_start := date_trunc('day', NOW() AT TIME ZONE 'UTC') AT TIME ZONE 'UTC';
    SELECT COUNT(*)::INT INTO v_used_today
    FROM public.ai_usage_ledger
    WHERE user_id = v_user_id AND created_at >= v_day_start AND status = 'success';

    RETURN jsonb_build_object(
      'allowed', true,
      'duplicate', true,
      'used_today', v_used_today,
      'daily_limit', v_limit
    );
  END IF;

  -- Ensure default quota row exists
  INSERT INTO public.user_ai_quotas (user_id, plan, daily_limit)
  VALUES (v_user_id, 'free', 150)
  ON CONFLICT (user_id) DO NOTHING;

  SELECT daily_limit INTO v_limit
  FROM public.user_ai_quotas
  WHERE user_id = v_user_id;

  v_day_start := date_trunc('day', NOW() AT TIME ZONE 'UTC') AT TIME ZONE 'UTC';
  SELECT COUNT(*)::INT INTO v_used_today
  FROM public.ai_usage_ledger
  WHERE user_id = v_user_id AND created_at >= v_day_start AND status = 'success';

  IF v_used_today >= v_limit AND p_status = 'success' THEN
    RETURN jsonb_build_object(
      'allowed', false,
      'duplicate', false,
      'used_today', v_used_today,
      'daily_limit', v_limit
    );
  END IF;

  INSERT INTO public.ai_usage_ledger (request_id, user_id, provider, task_type, status)
  VALUES (p_request_id, v_user_id, COALESCE(p_provider, 'unknown'), COALESCE(p_task_type, 'general'), COALESCE(p_status, 'success'))
  ON CONFLICT (request_id) DO NOTHING;

  RETURN jsonb_build_object(
    'allowed', true,
    'duplicate', false,
    'used_today', CASE WHEN p_status = 'success' THEN v_used_today + 1 ELSE v_used_today END,
    'daily_limit', v_limit
  );
END;
$$;

REVOKE ALL ON FUNCTION public.check_and_record_ai_usage(TEXT, TEXT, TEXT, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.check_and_record_ai_usage(TEXT, TEXT, TEXT, TEXT) TO authenticated;
