BEGIN;

-- Additive repair for the F29 idempotent create boundary.
--
-- `contractings` has both a primary key on `id` and the composite unique key
-- `(team_id, id)` required by scoped foreign keys. Under concurrent retries of
-- the same prepared UUID, `ON CONFLICT (id) DO NOTHING` can lose the race on
-- the composite key first and raise 23505 instead of reaching replay
-- recognition. The original 0005 migration is immutable, so this migration
-- replaces only the existing SECURITY DEFINER function body and keeps the same
-- sealed owner, signature, grants, RLS policies and external outcomes.
DO $preflight$
DECLARE
  capability_oid oid;
  migration_oid oid;
  function_owner oid;
  migration_can_admin boolean;
BEGIN
  SELECT r.oid, (r.rolsuper OR r.rolcreaterole)
  INTO migration_oid, migration_can_admin
  FROM pg_catalog.pg_roles AS r
  WHERE r.rolname = current_user;

  SELECT r.oid
  INTO capability_oid
  FROM pg_catalog.pg_roles AS r
  WHERE r.rolname = 'compras_contracting_create_owner';

  IF migration_oid IS NULL OR capability_oid IS NULL THEN
    RAISE EXCEPTION 'cannot resolve contracting create repair principals';
  END IF;

  IF NOT COALESCE(migration_can_admin, false) THEN
    RAISE EXCEPTION 'migration principal cannot administer contracting create repair';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM pg_catalog.pg_roles AS r
    WHERE r.oid = capability_oid
      AND (
        r.rolcanlogin
        OR r.rolsuper
        OR r.rolcreatedb
        OR r.rolcreaterole
        OR r.rolinherit
        OR r.rolreplication
        OR r.rolbypassrls
        OR r.rolconfig IS NOT NULL
      )
  ) THEN
    RAISE EXCEPTION 'contracting create capability is unsafe before repair';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM pg_catalog.pg_auth_members AS membership
    WHERE membership.member = capability_oid
       OR (
         membership.roleid = capability_oid
         AND (membership.set_option OR membership.inherit_option)
       )
  ) THEN
    RAISE EXCEPTION 'contracting create capability is not sealed before repair';
  END IF;

  SELECT p.proowner
  INTO function_owner
  FROM pg_catalog.pg_proc AS p
  JOIN pg_catalog.pg_namespace AS n
    ON n.oid = p.pronamespace
  WHERE n.nspname = 'public'
    AND p.proname = 'create_contracting_minimal'
    AND pg_catalog.pg_get_function_identity_arguments(p.oid)
      = 'p_contracting_id uuid, p_object text, p_event_id uuid';

  IF function_owner IS DISTINCT FROM capability_oid THEN
    RAISE EXCEPTION 'contracting create function is not owned by the sealed capability';
  END IF;
END;
$preflight$;

-- Obtain a transaction-local SET edge exactly as the existing provisioning
-- scripts do. The edge is removed before commit and never reaches runtime.
GRANT compras_contracting_create_owner
  TO CURRENT_USER
  WITH INHERIT FALSE, SET TRUE
  GRANTED BY CURRENT_USER;

SET ROLE compras_contracting_create_owner;

CREATE OR REPLACE FUNCTION public.create_contracting_minimal(
  p_contracting_id uuid,
  p_object text,
  p_event_id uuid
)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog
AS $function$
DECLARE
  current_user_id uuid;
  actor_membership_id uuid;
  target_team_id uuid;
  team_archived_at timestamptz;
  user_membership_count bigint;
  team_membership_count bigint;
  inserted_contracting_id uuid;
  existing_team_id uuid;
  existing_created_by_membership_id uuid;
  existing_object text;
  operation_at timestamptz;
BEGIN
  IF p_contracting_id IS NULL OR p_object IS NULL OR p_event_id IS NULL THEN
    RETURN 'denied';
  END IF;

  current_user_id := public.current_app_user_id();

  IF current_user_id IS NULL THEN
    RETURN 'denied';
  END IF;

  SELECT count(*)
  INTO user_membership_count
  FROM public.memberships AS user_membership
  WHERE user_membership.user_id = current_user_id
    AND user_membership.revoked_at IS NULL;

  IF user_membership_count <> 1 THEN
    RETURN 'denied';
  END IF;

  SELECT membership.id, membership.team_id
  INTO actor_membership_id, target_team_id
  FROM public.memberships AS membership
  WHERE membership.user_id = current_user_id
    AND membership.revoked_at IS NULL;

  IF actor_membership_id IS NULL OR target_team_id IS NULL THEN
    RETURN 'denied';
  END IF;

  SELECT team.archived_at
  INTO team_archived_at
  FROM public.teams AS team
  WHERE team.id = target_team_id;

  IF NOT FOUND OR team_archived_at IS NOT NULL THEN
    RETURN 'denied';
  END IF;

  SELECT count(*)
  INTO team_membership_count
  FROM public.memberships AS active_membership
  WHERE active_membership.team_id = target_team_id
    AND active_membership.revoked_at IS NULL;

  IF team_membership_count <> 1 THEN
    RETURN 'denied';
  END IF;

  operation_at := clock_timestamp();

  INSERT INTO public.contractings (
    id,
    team_id,
    object,
    created_by_membership_id,
    created_at,
    updated_at
  ) VALUES (
    p_contracting_id,
    target_team_id,
    p_object,
    actor_membership_id,
    operation_at,
    operation_at
  )
  -- No conflict target is intentional. The same logical candidate is covered
  -- by both `contractings_pkey (id)` and `contractings_team_id_id_key`; either
  -- may become the first detected arbiter under concurrency. Suppressing any
  -- unique conflict here is safe because the exact authorized replay identity
  -- is verified below before `already-created` can be returned.
  ON CONFLICT DO NOTHING
  RETURNING id INTO inserted_contracting_id;

  IF inserted_contracting_id IS NOT NULL THEN
    INSERT INTO public.contracting_events (
      id,
      team_id,
      contracting_id,
      actor_membership_id,
      event_type,
      occurred_at,
      created_at
    ) VALUES (
      p_event_id,
      target_team_id,
      p_contracting_id,
      actor_membership_id,
      'contracting_created',
      operation_at,
      operation_at
    );

    RETURN 'created';
  END IF;

  SELECT target.team_id, target.created_by_membership_id, target.object
  INTO existing_team_id, existing_created_by_membership_id, existing_object
  FROM public.contractings AS target
  WHERE target.id = p_contracting_id;

  IF FOUND
     AND existing_team_id = target_team_id
     AND existing_created_by_membership_id = actor_membership_id
     AND existing_object IS NOT DISTINCT FROM p_object THEN
    RETURN 'already-created';
  END IF;

  RETURN 'denied';
END;
$function$;

RESET ROLE;

REVOKE compras_contracting_create_owner
  FROM CURRENT_USER
  GRANTED BY CURRENT_USER;

DO $postflight$
DECLARE
  capability_oid oid;
  function_owner oid;
  is_security_definer boolean;
  configured_search_path text[];
BEGIN
  SELECT r.oid
  INTO capability_oid
  FROM pg_catalog.pg_roles AS r
  WHERE r.rolname = 'compras_contracting_create_owner';

  IF capability_oid IS NULL THEN
    RAISE EXCEPTION 'cannot resolve contracting create capability after repair';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM pg_catalog.pg_auth_members AS membership
    WHERE membership.member = capability_oid
       OR (
         membership.roleid = capability_oid
         AND (membership.set_option OR membership.inherit_option)
       )
  ) THEN
    RAISE EXCEPTION 'usable contracting create capability membership remained after repair';
  END IF;

  SELECT p.proowner, p.prosecdef, p.proconfig
  INTO function_owner, is_security_definer, configured_search_path
  FROM pg_catalog.pg_proc AS p
  JOIN pg_catalog.pg_namespace AS n
    ON n.oid = p.pronamespace
  WHERE n.nspname = 'public'
    AND p.proname = 'create_contracting_minimal'
    AND pg_catalog.pg_get_function_identity_arguments(p.oid)
      = 'p_contracting_id uuid, p_object text, p_event_id uuid';

  IF function_owner IS DISTINCT FROM capability_oid
     OR NOT COALESCE(is_security_definer, false)
     OR configured_search_path IS DISTINCT FROM ARRAY['search_path=pg_catalog']::text[] THEN
    RAISE EXCEPTION 'contracting create repair changed the sealed function boundary';
  END IF;
END;
$postflight$;

COMMIT;
