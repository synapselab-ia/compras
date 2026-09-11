BEGIN;

-- F26 first persistent write boundary. The capability is cluster-level,
-- NOLOGIN and never an application credential. Its lifecycle mirrors ADR-005:
-- PostgreSQL 17 may retain only the automatic ADMIN-only edge back to the
-- non-operational migration principal (SET FALSE / INHERIT FALSE).
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
  WHERE r.rolname = 'compras_next_action_mutation_owner';

  IF capability_oid IS NULL THEN
    EXECUTE $role$
      CREATE ROLE compras_next_action_mutation_owner
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
    WHERE r.rolname = 'compras_next_action_mutation_owner';
  END IF;

  IF capability_oid IS NULL THEN
    RAISE EXCEPTION 'next-action mutation capability role could not be created';
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
    RAISE EXCEPTION 'next-action mutation capability role has unsafe attributes or configuration';
  END IF;

  -- The capability itself must not inherit provider/admin roles.
  IF EXISTS (
    SELECT 1
    FROM pg_catalog.pg_auth_members AS membership
    WHERE membership.member = capability_oid
  ) THEN
    RAISE EXCEPTION 'next-action mutation capability role must not be a member of another role';
  END IF;

  -- No principal may inherit or SET ROLE into the capability. The only
  -- tolerated edge is PostgreSQL 17's automatic administration-only grant to
  -- the migration principal.
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
    RAISE EXCEPTION 'next-action mutation capability role has unsafe grantees or usable membership';
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
    RAISE EXCEPTION 'migration principal cannot safely administer the next-action capability role';
  END IF;
END;
$migration$;

GRANT USAGE ON SCHEMA public TO compras_next_action_mutation_owner;

-- Identity resolution remains issuer + subject from the trusted LOCAL context.
GRANT SELECT (id, auth_issuer, auth_subject, disabled_at)
  ON public.app_users TO compras_next_action_mutation_owner;
GRANT SELECT (id, team_id, user_id, revoked_at)
  ON public.memberships TO compras_next_action_mutation_owner;
GRANT EXECUTE ON FUNCTION public.current_auth_issuer()
  TO compras_next_action_mutation_owner;
GRANT EXECUTE ON FUNCTION public.current_auth_subject()
  TO compras_next_action_mutation_owner;
GRANT EXECUTE ON FUNCTION public.current_app_user_id()
  TO compras_next_action_mutation_owner;

-- The capability can inspect only the columns needed to locate/lock the target
-- and can update only next_action + updated_at. It receives no INSERT/DELETE on
-- contractings and no write grant on any other operational column.
GRANT SELECT (id, team_id, next_action, archived_at, cancelled_at)
  ON public.contractings TO compras_next_action_mutation_owner;
GRANT UPDATE (next_action, updated_at)
  ON public.contractings TO compras_next_action_mutation_owner;

-- Event insertion is column-scoped. Nullable columns that are not part of this
-- event shape are deliberately omitted from the grant and from the INSERT.
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
) ON public.contracting_events TO compras_next_action_mutation_owner;

-- The capability must count every non-revoked membership in an authorized
-- team's pilot guard, including memberships whose app_user is disabled. This
-- broad active-membership visibility exists only for the sealed NOLOGIN owner.
CREATE POLICY memberships_select_next_action_mutation_capability
ON public.memberships
FOR SELECT
TO compras_next_action_mutation_owner
USING (revoked_at IS NULL);

-- UPDATE remains fail-closed under FORCE RLS. The caller's identity must own an
-- active membership in the target team and that membership must be the only
-- non-revoked membership in the team. Q-009 therefore stays unresolved.
CREATE POLICY contractings_update_next_action_mutation_capability
ON public.contractings
FOR UPDATE
TO compras_next_action_mutation_owner
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

-- Event rows can only be inserted for the same authorized active contracting,
-- with the actor derived from the current identity and under the same pilot-only
-- unique-membership guard.
CREATE POLICY contracting_events_insert_next_action_mutation_capability
ON public.contracting_events
FOR INSERT
TO compras_next_action_mutation_owner
WITH CHECK (
  event_type = 'next_action_changed'
  AND field_key = 'next_action'
  AND actor_membership_id IS NOT NULL
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
  )
);

CREATE FUNCTION public.mutate_contracting_next_action(
  p_contracting_id uuid,
  p_expected_next_action text,
  p_new_next_action text,
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
  current_next_action text;
  operation_at timestamptz;
BEGIN
  IF p_contracting_id IS NULL OR p_event_id IS NULL THEN
    RETURN 'denied';
  END IF;

  current_user_id := public.current_app_user_id();

  IF current_user_id IS NULL THEN
    RETURN 'denied';
  END IF;

  -- The UUID is only a candidate selector. Existing SELECT RLS plus the
  -- active-row predicate makes cross-team, archived, cancelled and nonexistent
  -- targets collapse to the same denied state before conflict/no-op semantics.
  SELECT target.team_id, target.next_action
  INTO target_team_id, current_next_action
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

  IF current_next_action IS DISTINCT FROM p_expected_next_action THEN
    RETURN 'conflict';
  END IF;

  IF current_next_action IS NOT DISTINCT FROM p_new_next_action THEN
    RETURN 'unchanged';
  END IF;

  operation_at := clock_timestamp();

  UPDATE public.contractings
  SET next_action = p_new_next_action,
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
    'next_action_changed',
    operation_at,
    'next_action',
    current_next_action,
    p_new_next_action,
    operation_at
  );

  RETURN 'updated';
END;
$function$;

-- PostgreSQL grants EXECUTE on new functions to PUBLIC by default. Remove it
-- before transferring ownership. Each environment must grant only EXECUTE to
-- its actual non-privileged domain runtime role.
REVOKE ALL ON FUNCTION public.mutate_contracting_next_action(uuid, text, text, uuid)
  FROM PUBLIC;

-- Ownership transfer uses the same transaction-local SET-capable edge as
-- ADR-005. It is revoked before commit; the persistent automatic ADMIN edge,
-- when PostgreSQL 17 creates one, remains SET FALSE / INHERIT FALSE.
GRANT CREATE ON SCHEMA public TO compras_next_action_mutation_owner;

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
      'GRANT compras_next_action_mutation_owner TO %I WITH INHERIT FALSE, SET TRUE GRANTED BY %I',
      current_user,
      current_user
    );
  END IF;

  ALTER FUNCTION public.mutate_contracting_next_action(uuid, text, text, uuid)
    OWNER TO compras_next_action_mutation_owner;

  IF NOT COALESCE(migration_is_superuser, false) THEN
    EXECUTE format(
      'REVOKE compras_next_action_mutation_owner FROM %I GRANTED BY %I',
      current_user,
      current_user
    );
  END IF;
END;
$ownership$;

REVOKE CREATE ON SCHEMA public FROM compras_next_action_mutation_owner;

-- Final structural guard: migration succeeds only if the capability is sealed,
-- non-privileged, owns no base tables and the function retains the intended
-- SECURITY DEFINER + fixed search_path boundary.
DO $postflight$
DECLARE
  capability_oid oid;
  migration_oid oid;
BEGIN
  SELECT r.oid
  INTO capability_oid
  FROM pg_catalog.pg_roles AS r
  WHERE r.rolname = 'compras_next_action_mutation_owner';

  SELECT r.oid
  INTO migration_oid
  FROM pg_catalog.pg_roles AS r
  WHERE r.rolname = current_user;

  IF capability_oid IS NULL OR migration_oid IS NULL THEN
    RAISE EXCEPTION 'cannot resolve next-action capability postflight principals';
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
    RAISE EXCEPTION 'next-action mutation capability role is not sealed after ownership transfer';
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
    RAISE EXCEPTION 'next-action mutation capability must not own protected base tables';
  END IF;

  IF has_schema_privilege(
       'compras_next_action_mutation_owner',
       'public',
       'CREATE'
     ) THEN
    RAISE EXCEPTION 'next-action mutation capability retained schema CREATE privilege';
  END IF;

  IF NOT has_column_privilege(
       'compras_next_action_mutation_owner',
       'public.contractings',
       'next_action',
       'UPDATE'
     )
     OR NOT has_column_privilege(
       'compras_next_action_mutation_owner',
       'public.contractings',
       'updated_at',
       'UPDATE'
     ) THEN
    RAISE EXCEPTION 'next-action mutation capability is missing narrow contractings update privileges';
  END IF;

  IF has_column_privilege(
       'compras_next_action_mutation_owner',
       'public.contractings',
       'stage_key',
       'UPDATE'
     )
     OR has_column_privilege(
       'compras_next_action_mutation_owner',
       'public.contractings',
       'status_key',
       'UPDATE'
     )
     OR has_column_privilege(
       'compras_next_action_mutation_owner',
       'public.contractings',
       'responsible_membership_id',
       'UPDATE'
     )
     OR has_column_privilege(
       'compras_next_action_mutation_owner',
       'public.contractings',
       'waiting_type',
       'UPDATE'
     )
     OR has_column_privilege(
       'compras_next_action_mutation_owner',
       'public.contractings',
       'waiting_reference',
       'UPDATE'
     )
     OR has_column_privilege(
       'compras_next_action_mutation_owner',
       'public.contractings',
       'waiting_since',
       'UPDATE'
     )
     OR has_column_privilege(
       'compras_next_action_mutation_owner',
       'public.contractings',
       'waiting_reason',
       'UPDATE'
     ) THEN
    RAISE EXCEPTION 'next-action mutation capability can update unrelated operational columns';
  END IF;

  IF has_table_privilege(
       'compras_next_action_mutation_owner',
       'public.contracting_events',
       'UPDATE'
     )
     OR has_table_privilege(
       'compras_next_action_mutation_owner',
       'public.contracting_events',
       'DELETE'
     ) THEN
    RAISE EXCEPTION 'next-action mutation capability can mutate existing events';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_catalog.pg_proc AS procedure
    JOIN pg_catalog.pg_namespace AS namespace
      ON namespace.oid = procedure.pronamespace
    WHERE namespace.nspname = 'public'
      AND procedure.proname = 'mutate_contracting_next_action'
      AND pg_catalog.pg_get_function_identity_arguments(procedure.oid)
        = 'p_contracting_id uuid, p_expected_next_action text, p_new_next_action text, p_event_id uuid'
      AND procedure.proowner = capability_oid
      AND procedure.prosecdef
      AND COALESCE(procedure.proconfig, ARRAY[]::text[])
        @> ARRAY['search_path=pg_catalog']
  ) THEN
    RAISE EXCEPTION 'next-action mutation function has unsafe ownership, security mode or search_path';
  END IF;
END;
$postflight$;

COMMIT;
