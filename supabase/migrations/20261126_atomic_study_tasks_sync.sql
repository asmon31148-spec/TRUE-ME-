-- ==============================================================================
-- TRUE ME: Phase 2 Atomic Study-Task Sync RPC (DATA-02)
-- Replaces separate delete + upsert calls with a single transactional RPC.
-- ==============================================================================

CREATE OR REPLACE FUNCTION public.sync_study_tasks_for_date(
  p_plan_date TEXT,
  p_tasks JSONB
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS $$
DECLARE
  v_user_id TEXT;
  v_item JSONB;
  v_idx INT := 0;
  v_task_id TEXT;
  v_keep_ids TEXT[] := ARRAY[]::TEXT[];
BEGIN
  v_user_id := auth.uid()::text;
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Unauthorized: Authenticated session required for study task sync';
  END IF;

  IF p_tasks IS NULL OR jsonb_typeof(p_tasks) <> 'array' THEN
    p_tasks := '[]'::jsonb;
  END IF;

  -- 1. Upsert all incoming tasks in one transaction
  FOR v_item IN SELECT * FROM jsonb_array_elements(p_tasks)
  LOOP
    v_task_id := COALESCE(NULLIF(v_item->>'id', ''), 'task_' || v_user_id || '_' || p_plan_date || '_' || v_idx::text);
    v_keep_ids := array_append(v_keep_ids, v_task_id);

    INSERT INTO public.study_tasks (
      id,
      user_id,
      plan_date,
      title,
      subject,
      task_type,
      duration_min,
      completed,
      sort_order,
      updated_at
    )
    VALUES (
      v_task_id,
      v_user_id,
      p_plan_date,
      COALESCE(NULLIF(v_item->>'title', ''), 'Study task'),
      COALESCE(NULLIF(v_item->>'subject', ''), 'General'),
      COALESCE(NULLIF(v_item->>'type', ''), 'reading'),
      COALESCE((v_item->>'duration')::INT, 20),
      COALESCE((v_item->>'completed')::BOOLEAN, false),
      v_idx,
      NOW()
    )
    ON CONFLICT (id) DO UPDATE SET
      title = EXCLUDED.title,
      subject = EXCLUDED.subject,
      task_type = EXCLUDED.task_type,
      duration_min = EXCLUDED.duration_min,
      completed = EXCLUDED.completed,
      sort_order = EXCLUDED.sort_order,
      updated_at = NOW()
    WHERE public.study_tasks.user_id = v_user_id;

    v_idx := v_idx + 1;
  END LOOP;

  -- 2. Remove only tasks for this date that are no longer in p_tasks
  DELETE FROM public.study_tasks
  WHERE user_id = v_user_id
    AND plan_date = p_plan_date
    AND NOT (id = ANY(v_keep_ids));
END;
$$;

REVOKE ALL ON FUNCTION public.sync_study_tasks_for_date(TEXT, JSONB) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.sync_study_tasks_for_date(TEXT, JSONB) TO authenticated;
