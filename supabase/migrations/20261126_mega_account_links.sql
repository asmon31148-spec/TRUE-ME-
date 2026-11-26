-- ==============================================================================
-- TRUE ME: Phase A — Mega Identity Ownership & Duplicate Prevention
-- Enforces strict 1-to-1 binding between a TRUE ME user_id and a Mega identity.
-- ==============================================================================

CREATE TABLE IF NOT EXISTS public.mega_account_links (
  user_id TEXT PRIMARY KEY,
  mega_identity_hash TEXT NOT NULL UNIQUE,
  mega_email TEXT NOT NULL,
  linked_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.mega_account_links ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users manage own mega_account_links" ON public.mega_account_links;
CREATE POLICY "Users manage own mega_account_links"
ON public.mega_account_links FOR ALL
TO authenticated
USING ((SELECT auth.uid())::text = user_id)
WITH CHECK ((SELECT auth.uid())::text = user_id);

-- Atomic RPC to claim a Mega identity for the currently authenticated TRUE ME user.
-- Blocks duplicate association if another TRUE ME account already owns it.
CREATE OR REPLACE FUNCTION public.claim_mega_identity(
  p_mega_email TEXT,
  p_mega_identity_hash TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id TEXT;
  v_existing_owner TEXT;
BEGIN
  v_user_id := auth.uid()::text;
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Authentication required to link MEGA.');
  END IF;

  SELECT user_id INTO v_existing_owner
  FROM public.mega_account_links
  WHERE mega_identity_hash = p_mega_identity_hash;

  IF v_existing_owner IS NOT NULL AND v_existing_owner <> v_user_id THEN
    RETURN jsonb_build_object(
      'ok', false,
      'error', 'This MEGA account is already linked to another TRUE ME account. Unlink it from that account first.'
    );
  END IF;

  INSERT INTO public.mega_account_links (user_id, mega_identity_hash, mega_email, linked_at)
  VALUES (v_user_id, p_mega_identity_hash, p_mega_email, NOW())
  ON CONFLICT (user_id) DO UPDATE SET
    mega_identity_hash = EXCLUDED.mega_identity_hash,
    mega_email = EXCLUDED.mega_email,
    linked_at = NOW();

  RETURN jsonb_build_object('ok', true);
END;
$$;

REVOKE ALL ON FUNCTION public.claim_mega_identity(TEXT, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.claim_mega_identity(TEXT, TEXT) TO authenticated;
