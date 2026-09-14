BEGIN;

-- F32 persistent contractings.object mutation boundary. This capability is a
-- sealed NOLOGIN technical owner and never an application credential. It is
-- intentionally separate from F26 next_action mutation and F29 creation.
DO $migration$
DECLARE
  capability_oid oid;
  migration_oid oid;
  migration_is_superuser boolean;
BEGIN
  SELECT r.oid, r.rolsuper
  INTO migration_oid, migration_is_superuser
  FROM pg_catalog.pg_roles AS r
  WHERE r.rolname = current_user;

  IF migration_oid IS NULL THEN
    RAISE EXCEPTION 'cannot resolve migration principal';
  END IF;

  SELECT r.oid
  INTO capability_oid
  FROM pg_catalog.pg_roles AS r
  WHERE r.rolname = 'compras_contracting_object_mutation_owner';

  IF capability_oid IS NULL THEN
    EXECUTE $role$
      CREATE ROLE compras_contracting_object_mutation_owner
        NOLOGIN
        NOSUPERUSER
        NOCREATEDB
        NOCREATEROLE
        NOINHERIT
        NOREPLICATION
        NOBYPASSRLS
    $role$;

    SELECT r.oid
    INTO capability_oid
    FROM pg_catalog.pg_roles AS r
    WHERE r.rolname = 'compras_contracting_object_mutation_owner';
  END IF;

  IF capability_oid IS NULL THEN
    RAISE EXCEPTION 'contracting object mutation capability role could not be created';
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
    RAISE EXCEPTION 'contracting object mutation capability role has unsafe attributes or configuration';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM pg_catalog.pg_auth_members AS membership
    WHERE membership.member = capability_oid
  ) THEN
    RAISE EXCEPTION 'contracting object mutation capability role must not be a member of another role';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM pg_catalog.pg_auth_members AS membership
    WHERE membership.roleid = capability_oid
      AND (
        membership.member <> migration_oid
        OR membership.set_option
        OR membership.inherit_option
        OR NOT membership.admin_option
      )
  ) THEN
    RAISE EXCEPTION 'contracting object mutation capability role has unsafe grantees or usable membership';
  END IF;

  IF NOT migration_is_superuser
     AND NOT EXISTS (
       SELECT 1
       FROM pg_catalog.pg_auth_members AS membership
       WHERE membership.roleid = capability_oid
         AND membership.member = migration_oid
         AND membership.admin_option
         AND NOT membership.set_option
         AND NOT membership.inherit_option
     ) THEN
    RAISE EXCEPTION 'migration principal cannot safely administer the contracting object mutation capability role';
  END IF;
END;
$migration$;

GRANT USAGE ON SCHEMA public TO compras_contracting_object_mutation_owner;

-- Trusted identity is issuer + subject carried only through the transaction
-- LOCAL context established by the server mutation adapter.
GRANT SELECT (id, auth_issuer, auth_subject, disabled_at)
  ON public.app_users TO compras_contracting_object_mutation_owner;
GRANT SELECT (id, team_id, user_id, revoked_at)
  ON public.memberships TO compras_contracting_object_mutation_owner;
GRANT EXECUTE ON FUNCTION public.current_auth_issuer()
  TO compras_contracting_object_mutation_owner;
GRANT EXECUTE ON FUNCTION public.current_auth_subject()
  TO compras_contracting_object_mutation_owner;
GRANT EXECUTE ON FUNCTION public.current_app_user_id()
  TO compras_contracting_object_mutation_owner;

-- The capability can locate and lock only the state required by ADR-013. Its
-- write authority is column-scoped to object + updated_at and includes no
-- INSERT/DELETE privilege on contractings.
GRANT SELECT (id, team_id, object, archived_at, cancelled_at)
  ON public.contractings TO compras_contracting_object_mutation_owner;
GRANT UPDATE (object, updated_at)
  ON public.contractings TO compras_contracting_object_mutation_owner;

-- Audit insertion is also column-scoped. Auxiliary event columns remain NULL
-- because this capability cannot write them.
GRANT INSERT (
  id,
  team_id,
  contracting_id,
  actor_membership_id,
  event_type,
  occurred_at,
  field_key,
  old_value,
  new_value,
  created_at
) ON public.contracting_events TO compras_contracting_object_mutation_owner;

-- The pilot guard must count every non-revoked membership in the target team,
-- including a membership whose app_user has later been disabled.
CREATE POLICY memberships_select_contracting_object_mutation_capability
ON public.memberships
FOR SELECT
TO compras_contracting_object_mutation_owner
USING (revoked_at IS NULL);

-- F32 follows the F26 target-team guard. Another active membership of the same
-- user in a different team does not block this update. A second non-revoked
-- membership in the target team does block it while Q-009 remains open.
CREATE POLICY contractings_update_contracting_object_mutation_capability
ON public.contractings
FOR UPDATE
TO compras_contracting_object_mutation_owner
USING (
  archived_at IS NULL
  AND cancelled_at IS NULL
  AND EXISTS (
    SELECT 1
    FROM public.memberships AS actor_membership
    WHERE actor_membership.team_id = contractings.team_id
      AND actor_membership.user_id = public.current_app_user_id()
      AND actor_membership.revoked_at IS NULL
  )
  AND 1 = (
    SELECT count(*)
    FROM public.memberships AS active_membership
    WHERE active_membership.team_id = contractings.team_id
      AND active_membership.revoked_at IS NULL
  )
)
WITH CHECK (
  archived_at IS NULL
  AND cancelled_at IS NULL
  AND EXISTS (
    SELECT 1
    FROM public.memberships AS actor_membership
    WHERE actor_membership.team_id = contractings.team_id
      AND actor_membership.user_id = public.current_app_user_id()
      AND actor_membership.revoked_at IS NULL
  )
  AND 1 = (
    SELECT count(*)
    FROM public.memberships AS active_membership
    WHERE active_membership.team_id = contractings.team_id
      AND active_membership.revoked_at IS NULL
  )
);

CREATE POLICY contracting_events_insert_contracting_object_mutation_capability
ON public.contracting_events
FOR INSERT
TO compras_contracting_object_mutation_owner
WITH CHECK (
  event_type = 'object_changed'
  AND field_key = 'object'
  AND actor_membership_id IS NOT NULL
  AND old_value IS NOT NULL
  AND new_value IS NOT NULL
  AND note IS NULL
  AND related_identifier_id IS NULL
  AND item_id IS NULL
  AND EXISTS (
    SELECT 1
    FROM public.memberships AS actor_membership
    WHERE actor_membership.id = contracting_events.actor_membership_id
      AND actor_membership.team_id = contracting_events.team_id
      AND actor_membership.user_id = public.current_app_user_id()
      AND actor_membership.revoked_at IS NULL
  )
  AND 1 = (
    SELECT count(*)
    FROM public.memberships AS active_membership
    WHERE active_membership.team_id = contracting_events.team_id
      AND active_membership.revoked_at IS NULL
  )
  AND EXISTS (
    SELECT 1
    FROM public.contractings AS target
    WHERE target.id = contracting_events.contracting_id
      AND target.team_id = contracting_events.team_id
      AND target.archived_at IS NULL
      AND target.cancelled_at IS NULL
      AND target.object IS NOT DISTINCT FROM contracting_events.new_value
  )
);

CREATE FUNCTION public.mutate_contracting_object(
  p_contracting_id uuid,
  p_expected_object text,
  p_new_object text,
  p_event_id uuid
)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog
AS $function$
DECLARE
  current_user_id uuid;
  target_team_id uuid;
  actor_membership_id uuid;
  current_object text;
  operation_at timestamptz;
BEGIN
  IF p_contracting_id IS NULL
     OR p_expected_object IS NULL
     OR p_new_object IS NULL
     OR p_event_id IS NULL THEN
    RETURN 'denied';
  END IF;

  current_user_id := public.current_app_user_id();

  IF current_user_id IS NULL THEN
    RETURN 'denied';
  END IF;

  -- The candidate UUID never grants authority. Generic SELECT RLS plus these
  -- active-row predicates make cross-team, archived, cancelled and nonexistent
  -- candidates indistinguishable before conflict/no-op evaluation.
  SELECT target.team_id, target.object
  INTO target_team_id, current_object
  FROM public.contractings AS target
  WHERE target.id = p_contracting_id
    AND target.archived_at IS NULL
    AND target.cancelled_at IS NULL
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN 'denied';
  END IF;

  SELECT membership.id
  INTO actor_membership_id
  FROM public.memberships AS membership
  WHERE membership.team_id = target_team_id
    AND membership.user_id = current_user_id
    AND membership.revoked_at IS NULL;

  IF actor_membership_id IS NULL THEN
    RETURN 'denied';
  END IF;

  IF (
    SELECT count(*)
    FROM public.memberships AS active_membership
    WHERE active_membership.team_id = target_team_id
      AND active_membership.revoked_at IS NULL
  ) <> 1 THEN
    RETURN 'denied';
  END IF;

  -- A stale precondition wins over no-op even if another writer already
  -- reached p_new_object. This prevents silent lost-update/replay success.
  IF current_object IS DISTINCT FROM p_expected_object THEN
    RETURN 'conflict';
  END IF;

  IF current_object IS NOT DISTINCT FROM p_new_object THEN
    RETURN 'unchanged';
  END IF;

  operation_at := clock_timestamp();

  UPDATE public.contractings
  SET object = p_new_object,
      updated_at = operation_at
  WHERE id = p_contracting_id;

  INSERT INTO public.contracting_events (
    id,
    team_id,
    contracting_id,
    actor_membership_id,
    event_type,
    occurred_at,
    field_key,
    old_value,
    new_value,
    created_at
  ) VALUES (
    p_event_id,
    target_team_id,
    p_contracting_id,
    actor_membership_id,
    'object_changed',
    operation_at,
    'object',
    current_object,
    p_new_object,
    operation_at
  );

  RETURN 'updated';
END;
$function$;

-- New functions receive PUBLIC EXECUTE by default. Keep F32 unavailable until
-- explicit environment provisioning grants only the intended domain runtime.
REVOKE ALL ON FUNCTION public.mutate_contracting_object(uuid, text, text, uuid)
  FROM PUBLIC;

-- Transfer only the primitive to the sealed owner. The temporary SET-capable
-- edge is removed before commit, preserving the ADR-005 lifecycle.
GRANT CREATE ON SCHEMA public TO compras_contracting_object_mutation_owner;

DO $ownership$
DECLARE
  migration_is_superuser boolean;
BEGIN
  SELECT r.rolsuper
  INTO migration_is_superuser
  FROM pg_catalog.pg_roles AS r
  WHERE r.rolname = current_user;

  IF NOT COALESCE(migration_is_superuser, false) THEN
    EXECUTE format(
      'GRANT compras_contracting_object_mutation_owner TO %I WITH INHERIT FALSE, SET TRUE GRANTED BY %I',
      current_user,
      current_user
    );
  END IF;

  ALTER FUNCTION public.mutate_contracting_object(uuid, text, text, uuid)
    OWNER TO compras_contracting_object_mutation_owner;

  IF NOT COALESCE(migration_is_superuser, false) THEN
    EXECUTE format(
      'REVOKE compras_contracting_object_mutation_owner FROM %I GRANTED BY %I',
      current_user,
      current_user
    );
  END IF;
END;
$ownership$;

REVOKE CREATE ON SCHEMA public FROM compras_contracting_object_mutation_owner;

DO $postflight$
DECLARE
  capability_oid oid;
  migration_oid oid;
BEGIN
  SELECT r.oid
  INTO capability_oid
  FROM pg_catalog.pg_roles AS r
  WHERE r.rolname = 'compras_contracting_object_mutation_owner';

  SELECT r.oid
  INTO migration_oid
  FROM pg_catalog.pg_roles AS r
  WHERE r.rolname = current_user;

  IF capability_oid IS NULL OR migration_oid IS NULL THEN
    RAISE EXCEPTION 'cannot resolve contracting object mutation postflight principals';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM pg_catalog.pg_auth_members AS membership
    WHERE membership.member = capability_oid
       OR (
         membership.roleid = capability_oid
         AND (
           membership.member <> migration_oid
           OR membership.set_option
           OR membership.inherit_option
           OR NOT membership.admin_option
         )
       )
  ) THEN
    RAISE EXCEPTION 'contracting object mutation capability role is not sealed after ownership transfer';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM pg_catalog.pg_class AS relation
    JOIN pg_catalog.pg_namespace AS namespace
      ON namespace.oid = relation.relnamespace
    WHERE namespace.nspname = 'public'
      AND relation.relname IN (
        'teams',
        'app_users',
        'memberships',
        'contractings',
        'related_identifiers',
        'contracting_items',
        'contracting_events'
      )
      AND relation.relowner = capability_oid
  ) THEN
    RAISE EXCEPTION 'contracting object mutation capability must not own protected base tables';
  END IF;

  IF has_schema_privilege(
       'compras_contracting_object_mutation_owner',
       'public',
       'CREATE'
     ) THEN
    RAISE EXCEPTION 'contracting object mutation capability retained schema CREATE privilege';
  END IF;

  IF NOT has_column_privilege(
       'compras_contracting_object_mutation_owner',
       'public.contractings',
       'object',
       'UPDATE'
     )
     OR NOT has_column_privilege(
       'compras_contracting_object_mutation_owner',
       'public.contractings',
       'updated_at',
       'UPDATE'
     ) THEN
    RAISE EXCEPTION 'contracting object mutation capability is missing narrow update privileges';
  END IF;

  IF has_table_privilege(
       'compras_contracting_object_mutation_owner',
       'public.contractings',
       'INSERT'
     )
     OR has_table_privilege(
       'compras_contracting_object_mutation_owner',
       'public.contractings',
       'DELETE'
     ) THEN
    RAISE EXCEPTION 'contracting object mutation capability can create or delete contractings';
  END IF;

  IF has_column_privilege('compras_contracting_object_mutation_owner', 'public.contractings', 'next_action', 'UPDATE')
     OR has_column_privilege('compras_contracting_object_mutation_owner', 'public.contractings', 'stage_key', 'UPDATE')
     OR has_column_privilege('compras_contracting_object_mutation_owner', 'public.contractings', 'status_key', 'UPDATE')
     OR has_column_privilege('compras_contracting_object_mutation_owner', 'public.contractings', 'responsible_membership_id', 'UPDATE')
     OR has_column_privilege('compras_contracting_object_mutation_owner', 'public.contractings', 'waiting_type', 'UPDATE')
     OR has_column_privilege('compras_contracting_object_mutation_owner', 'public.contractings', 'waiting_reference', 'UPDATE')
     OR has_column_privilege('compras_contracting_object_mutation_owner', 'public.contractings', 'waiting_since', 'UPDATE')
     OR has_column_privilege('compras_contracting_object_mutation_owner', 'public.contractings', 'waiting_reason', 'UPDATE')
     OR has_column_privilege('compras_contracting_object_mutation_owner', 'public.contractings', 'created_by_membership_id', 'UPDATE')
     OR has_column_privilege('compras_contracting_object_mutation_owner', 'public.contractings', 'archived_at', 'UPDATE')
     OR has_column_privilege('compras_contracting_object_mutation_owner', 'public.contractings', 'cancelled_at', 'UPDATE') THEN
    RAISE EXCEPTION 'contracting object mutation capability can update unrelated operational columns';
  END IF;

  IF has_table_privilege(
       'compras_contracting_object_mutation_owner',
       'public.contracting_events',
       'UPDATE'
     )
     OR has_table_privilege(
       'compras_contracting_object_mutation_owner',
       'public.contracting_events',
       'DELETE'
     ) THEN
    RAISE EXCEPTION 'contracting object mutation capability can mutate existing events';
  END IF;

  IF has_function_privilege(
       'compras_contracting_object_mutation_owner',
       'public.mutate_contracting_next_action(uuid,text,text,uuid)',
       'EXECUTE'
     )
     OR has_function_privilege(
       'compras_contracting_object_mutation_owner',
       'public.create_contracting_minimal(uuid,text,uuid)',
       'EXECUTE'
     ) THEN
    RAISE EXCEPTION 'contracting object mutation capability inherited F26/F29 authority';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_catalog.pg_proc AS procedure
    JOIN pg_catalog.pg_namespace AS namespace
      ON namespace.oid = procedure.pronamespace
    WHERE namespace.nspname = 'public'
      AND procedure.proname = 'mutate_contracting_object'
      AND pg_catalog.pg_get_function_identity_arguments(procedure.oid)
        = 'p_contracting_id uuid, p_expected_object text, p_new_object text, p_event_id uuid'
      AND procedure.proowner = capability_oid
      AND procedure.prosecdef
      AND COALESCE(procedure.proconfig, ARRAY[]::text[])
        @> ARRAY['search_path=pg_catalog']
  ) THEN
    RAISE EXCEPTION 'contracting object mutation function has unsafe ownership, security mode or search_path';
  END IF;
END;
$postflight$;

COMMIT;
