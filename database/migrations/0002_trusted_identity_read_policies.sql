BEGIN;

-- Transport contract only. These helpers do not validate the external session.
-- ADR-003 requires a trusted server to validate the session and set this context
-- locally inside the database transaction before using an operational role.
CREATE FUNCTION public.current_auth_issuer()
RETURNS text
LANGUAGE plpgsql
STABLE
SECURITY INVOKER
SET search_path = pg_catalog
AS $$
DECLARE
  raw_claims text;
  claims jsonb;
BEGIN
  raw_claims := current_setting('request.jwt.claims', true);

  IF raw_claims IS NULL OR btrim(raw_claims) = '' THEN
    RETURN NULL;
  END IF;

  BEGIN
    claims := raw_claims::jsonb;
  EXCEPTION
    WHEN invalid_text_representation THEN
      RETURN NULL;
  END;

  RETURN NULLIF(claims ->> 'iss', '');
END;
$$;

CREATE FUNCTION public.current_auth_subject()
RETURNS text
LANGUAGE plpgsql
STABLE
SECURITY INVOKER
SET search_path = pg_catalog
AS $$
DECLARE
  raw_claims text;
  claims jsonb;
BEGIN
  raw_claims := current_setting('request.jwt.claims', true);

  IF raw_claims IS NULL OR btrim(raw_claims) = '' THEN
    RETURN NULL;
  END IF;

  BEGIN
    claims := raw_claims::jsonb;
  EXCEPTION
    WHEN invalid_text_representation THEN
      RETURN NULL;
  END;

  RETURN NULLIF(claims ->> 'sub', '');
END;
$$;

CREATE FUNCTION public.current_app_user_id()
RETURNS uuid
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = pg_catalog
AS $$
  SELECT app_users.id
  FROM public.app_users
  WHERE app_users.auth_issuer = public.current_auth_issuer()
    AND app_users.auth_subject = public.current_auth_subject()
    AND app_users.disabled_at IS NULL
$$;

-- Function execution is explicit. A future server role must receive only the
-- EXECUTE privileges it needs; PUBLIC is not an authenticated principal.
REVOKE ALL ON FUNCTION public.current_auth_issuer() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.current_auth_subject() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.current_app_user_id() FROM PUBLIC;

-- app_users deliberately does not call current_app_user_id(), avoiding policy
-- recursion because that helper resolves through app_users itself.
CREATE POLICY app_users_select_self
ON public.app_users
FOR SELECT
USING (
  disabled_at IS NULL
  AND auth_issuer = public.current_auth_issuer()
  AND auth_subject = public.current_auth_subject()
);

CREATE POLICY memberships_select_active_self
ON public.memberships
FOR SELECT
USING (
  revoked_at IS NULL
  AND user_id = public.current_app_user_id()
);

CREATE POLICY teams_select_active_membership
ON public.teams
FOR SELECT
USING (
  EXISTS (
    SELECT 1
    FROM public.memberships
    WHERE memberships.team_id = teams.id
      AND memberships.user_id = public.current_app_user_id()
      AND memberships.revoked_at IS NULL
  )
);

CREATE POLICY contractings_select_active_membership
ON public.contractings
FOR SELECT
USING (
  EXISTS (
    SELECT 1
    FROM public.memberships
    WHERE memberships.team_id = contractings.team_id
      AND memberships.user_id = public.current_app_user_id()
      AND memberships.revoked_at IS NULL
  )
);

CREATE POLICY related_identifiers_select_active_membership
ON public.related_identifiers
FOR SELECT
USING (
  EXISTS (
    SELECT 1
    FROM public.memberships
    WHERE memberships.team_id = related_identifiers.team_id
      AND memberships.user_id = public.current_app_user_id()
      AND memberships.revoked_at IS NULL
  )
);

CREATE POLICY contracting_items_select_active_membership
ON public.contracting_items
FOR SELECT
USING (
  EXISTS (
    SELECT 1
    FROM public.memberships
    WHERE memberships.team_id = contracting_items.team_id
      AND memberships.user_id = public.current_app_user_id()
      AND memberships.revoked_at IS NULL
  )
);

CREATE POLICY contracting_events_select_active_membership
ON public.contracting_events
FOR SELECT
USING (
  EXISTS (
    SELECT 1
    FROM public.memberships
    WHERE memberships.team_id = contracting_events.team_id
      AND memberships.user_id = public.current_app_user_id()
      AND memberships.revoked_at IS NULL
  )
);

COMMIT;
