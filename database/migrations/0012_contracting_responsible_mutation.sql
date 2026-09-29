BEGIN;

-- F47 responsible membership mutation boundary. The capability owns only the
-- narrow SECURITY DEFINER primitive and never a protected base table.
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

  SELECT r.oid INTO capability_oid
  FROM pg_catalog.pg_roles AS r
  WHERE r.rolname = 'compras_contracting_responsible_mutation_owner';

  IF capability_oid IS NULL THEN
    EXECUTE $role$
      CREATE ROLE compras_contracting_responsible_mutation_owner
        NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT
        NOREPLICATION NOBYPASSRLS
    $role$;

    SELECT r.oid INTO capability_oid
    FROM pg_catalog.pg_roles AS r
    WHERE r.rolname = 'compras_contracting_responsible_mutation_owner';
  END IF;

  IF capability_oid IS NULL THEN
    RAISE EXCEPTION 'responsible mutation capability role could not be created';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM pg_catalog.pg_roles AS r
    WHERE r.oid = capability_oid
      AND (
        r.rolcanlogin OR r.rolsuper OR r.rolcreatedb OR r.rolcreaterole
        OR r.rolinherit OR r.rolreplication OR r.rolbypassrls
        OR r.rolconfig IS NOT NULL
      )
  ) THEN
    RAISE EXCEPTION 'responsible mutation capability role has unsafe attributes or configuration';
  END IF;

  IF EXISTS (
    SELECT 1 FROM pg_catalog.pg_auth_members AS membership
    WHERE membership.member = capability_oid
  ) THEN
    RAISE EXCEPTION 'responsible mutation capability role must not be a member of another role';
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
    RAISE EXCEPTION 'responsible mutation capability role has unsafe grantees or usable membership';
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
    RAISE EXCEPTION 'migration principal cannot safely administer responsible mutation capability role';
  END IF;
END;
$migration$;

GRANT USAGE ON SCHEMA public TO compras_contracting_responsible_mutation_owner;

GRANT SELECT (id, auth_issuer, auth_subject, disabled_at)
  ON public.app_users TO compras_contracting_responsible_mutation_owner;
GRANT SELECT (id, team_id, user_id, revoked_at)
  ON public.memberships TO compras_contracting_responsible_mutation_owner;
GRANT SELECT (
  id, team_id, responsible_membership_id, archived_at, cancelled_at
) ON public.contractings TO compras_contracting_responsible_mutation_owner;
GRANT UPDATE (responsible_membership_id, updated_at)
  ON public.contractings TO compras_contracting_responsible_mutation_owner;
GRANT INSERT (
  id, team_id, contracting_id, actor_membership_id, event_type,
  occurred_at, field_key, old_value, new_value, created_at
) ON public.contracting_events TO compras_contracting_responsible_mutation_owner;

GRANT EXECUTE ON FUNCTION public.current_auth_issuer()
  TO compras_contracting_responsible_mutation_owner;
GRANT EXECUTE ON FUNCTION public.current_auth_subject()
  TO compras_contracting_responsible_mutation_owner;
GRANT EXECUTE ON FUNCTION public.current_app_user_id()
  TO compras_contracting_responsible_mutation_owner;

CREATE POLICY app_users_select_contracting_responsible_mutation_capability
ON public.app_users
FOR SELECT
TO compras_contracting_responsible_mutation_owner
USING (disabled_at IS NULL);

CREATE POLICY memberships_select_contracting_responsible_mutation_capability
ON public.memberships
FOR SELECT
TO compras_contracting_responsible_mutation_owner
USING (revoked_at IS NULL);

CREATE POLICY contractings_update_contracting_responsible_mutation_capability
ON public.contractings
FOR UPDATE
TO compras_contracting_responsible_mutation_owner
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
  AND (
    responsible_membership_id IS NULL
    OR EXISTS (
      SELECT 1
      FROM public.memberships AS candidate
      JOIN public.app_users AS candidate_user
        ON candidate_user.id = candidate.user_id
      WHERE candidate.id = contractings.responsible_membership_id
        AND candidate.team_id = contractings.team_id
        AND candidate.revoked_at IS NULL
        AND candidate_user.disabled_at IS NULL
    )
  )
);

CREATE POLICY contracting_events_insert_contracting_responsible_mutation_capability
ON public.contracting_events
FOR INSERT
TO compras_contracting_responsible_mutation_owner
WITH CHECK (
  event_type = 'responsible_changed'
  AND field_key = 'responsible_membership_id'
  AND actor_membership_id IS NOT NULL
  AND note IS NULL
  AND related_identifier_id IS NULL
  AND item_id IS NULL
  AND created_at = occurred_at
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
      AND target.responsible_membership_id::text
        IS NOT DISTINCT FROM contracting_events.new_value
  )
  AND (
    new_value IS NULL
    OR EXISTS (
      SELECT 1
      FROM public.memberships AS candidate
      JOIN public.app_users AS candidate_user
        ON candidate_user.id = candidate.user_id
      WHERE candidate.team_id = contracting_events.team_id
        AND candidate.id::text = contracting_events.new_value
        AND candidate.revoked_at IS NULL
        AND candidate_user.disabled_at IS NULL
    )
  )
);

CREATE FUNCTION public.mutate_contracting_responsible(
  p_contracting_id uuid,
  p_expected_responsible_membership_id uuid,
  p_new_responsible_membership_id uuid,
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
  current_responsible_membership_id uuid;
  candidate_membership_id uuid;
  operation_at timestamptz;
BEGIN
  IF p_contracting_id IS NULL OR p_event_id IS NULL THEN
    RETURN 'denied';
  END IF;

  current_user_id := public.current_app_user_id();
  IF current_user_id IS NULL THEN
    RETURN 'denied';
  END IF;

  SELECT target.team_id, target.responsible_membership_id
  INTO target_team_id, current_responsible_membership_id
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

  IF current_responsible_membership_id
       IS DISTINCT FROM p_expected_responsible_membership_id THEN
    RETURN 'conflict';
  END IF;

  IF current_responsible_membership_id
       IS NOT DISTINCT FROM p_new_responsible_membership_id THEN
    RETURN 'unchanged';
  END IF;

  IF p_new_responsible_membership_id IS NOT NULL THEN
    SELECT candidate.id
    INTO candidate_membership_id
    FROM public.memberships AS candidate
    JOIN public.app_users AS candidate_user
      ON candidate_user.id = candidate.user_id
    WHERE candidate.id = p_new_responsible_membership_id
      AND candidate.team_id = target_team_id
      AND candidate.revoked_at IS NULL
      AND candidate_user.disabled_at IS NULL;

    IF candidate_membership_id IS NULL THEN
      RETURN 'denied';
    END IF;
  END IF;

  operation_at := pg_catalog.clock_timestamp();

  UPDATE public.contractings
  SET responsible_membership_id = p_new_responsible_membership_id,
      updated_at = operation_at
  WHERE id = p_contracting_id
    AND team_id = target_team_id
    AND archived_at IS NULL
    AND cancelled_at IS NULL;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'authorized contracting disappeared before responsible update';
  END IF;

  INSERT INTO public.contracting_events (
    id, team_id, contracting_id, actor_membership_id, event_type,
    occurred_at, field_key, old_value, new_value, created_at
  ) VALUES (
    p_event_id, target_team_id, p_contracting_id, actor_membership_id,
    'responsible_changed', operation_at, 'responsible_membership_id',
    current_responsible_membership_id::text,
    p_new_responsible_membership_id::text,
    operation_at
  );

  RETURN 'updated';
END;
$function$;

REVOKE ALL ON FUNCTION public.mutate_contracting_responsible(
  uuid, uuid, uuid, uuid
) FROM PUBLIC;

GRANT CREATE ON SCHEMA public TO compras_contracting_responsible_mutation_owner;

DO $ownership$
DECLARE
  migration_is_superuser boolean;
BEGIN
  SELECT r.rolsuper INTO migration_is_superuser
  FROM pg_catalog.pg_roles AS r
  WHERE r.rolname = current_user;

  IF NOT COALESCE(migration_is_superuser, false) THEN
    EXECUTE format(
      'GRANT compras_contracting_responsible_mutation_owner TO %I WITH INHERIT FALSE, SET TRUE GRANTED BY %I',
      current_user,
      current_user
    );
  END IF;

  ALTER FUNCTION public.mutate_contracting_responsible(uuid, uuid, uuid, uuid)
    OWNER TO compras_contracting_responsible_mutation_owner;

  IF NOT COALESCE(migration_is_superuser, false) THEN
    EXECUTE format(
      'REVOKE compras_contracting_responsible_mutation_owner FROM %I GRANTED BY %I',
      current_user,
      current_user
    );
  END IF;
END;
$ownership$;

REVOKE CREATE ON SCHEMA public FROM compras_contracting_responsible_mutation_owner;

DO $postflight$
DECLARE
  capability_oid oid;
  migration_oid oid;
  prior_role text;
BEGIN
  SELECT r.oid INTO capability_oid
  FROM pg_catalog.pg_roles AS r
  WHERE r.rolname = 'compras_contracting_responsible_mutation_owner';

  SELECT r.oid INTO migration_oid
  FROM pg_catalog.pg_roles AS r
  WHERE r.rolname = current_user;

  IF capability_oid IS NULL OR migration_oid IS NULL THEN
    RAISE EXCEPTION 'cannot resolve responsible mutation postflight principals';
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
    RAISE EXCEPTION 'responsible mutation capability role is not sealed';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM pg_catalog.pg_class AS relation
    JOIN pg_catalog.pg_namespace AS namespace
      ON namespace.oid = relation.relnamespace
    WHERE namespace.nspname = 'public'
      AND relation.relname IN (
        'teams', 'app_users', 'memberships', 'contractings',
        'related_identifiers', 'contracting_items', 'contracting_events',
        'contracting_item_ordinal_counters'
      )
      AND relation.relowner = capability_oid
  ) THEN
    RAISE EXCEPTION 'responsible mutation capability owns a protected base table';
  END IF;

  IF pg_catalog.has_schema_privilege(
       'compras_contracting_responsible_mutation_owner', 'public', 'CREATE'
     ) THEN
    RAISE EXCEPTION 'responsible mutation capability retained schema CREATE';
  END IF;

  IF NOT pg_catalog.has_column_privilege(
       'compras_contracting_responsible_mutation_owner',
       'public.contractings', 'responsible_membership_id', 'UPDATE'
     )
     OR NOT pg_catalog.has_column_privilege(
       'compras_contracting_responsible_mutation_owner',
       'public.contractings', 'updated_at', 'UPDATE'
     ) THEN
    RAISE EXCEPTION 'responsible mutation capability is missing narrow UPDATE';
  END IF;

  IF pg_catalog.has_table_privilege(
       'compras_contracting_responsible_mutation_owner', 'public.contractings', 'INSERT'
     )
     OR pg_catalog.has_table_privilege(
       'compras_contracting_responsible_mutation_owner', 'public.contractings', 'DELETE'
     )
     OR pg_catalog.has_column_privilege(
       'compras_contracting_responsible_mutation_owner', 'public.contractings', 'object', 'UPDATE'
     )
     OR pg_catalog.has_column_privilege(
       'compras_contracting_responsible_mutation_owner', 'public.contractings', 'next_action', 'UPDATE'
     )
     OR pg_catalog.has_column_privilege(
       'compras_contracting_responsible_mutation_owner', 'public.contractings', 'stage_key', 'UPDATE'
     )
     OR pg_catalog.has_column_privilege(
       'compras_contracting_responsible_mutation_owner', 'public.contractings', 'status_key', 'UPDATE'
     )
     OR pg_catalog.has_column_privilege(
       'compras_contracting_responsible_mutation_owner', 'public.contractings', 'waiting_type', 'UPDATE'
     )
     OR pg_catalog.has_column_privilege(
       'compras_contracting_responsible_mutation_owner', 'public.contractings', 'waiting_reference', 'UPDATE'
     )
     OR pg_catalog.has_column_privilege(
       'compras_contracting_responsible_mutation_owner', 'public.contractings', 'waiting_since', 'UPDATE'
     )
     OR pg_catalog.has_column_privilege(
       'compras_contracting_responsible_mutation_owner', 'public.contractings', 'waiting_reason', 'UPDATE'
     )
     OR pg_catalog.has_column_privilege(
       'compras_contracting_responsible_mutation_owner', 'public.contractings', 'created_by_membership_id', 'UPDATE'
     )
     OR pg_catalog.has_column_privilege(
       'compras_contracting_responsible_mutation_owner', 'public.contractings', 'archived_at', 'UPDATE'
     )
     OR pg_catalog.has_column_privilege(
       'compras_contracting_responsible_mutation_owner', 'public.contractings', 'cancelled_at', 'UPDATE'
     ) THEN
    RAISE EXCEPTION 'responsible mutation capability can update unrelated contracting state';
  END IF;

  IF pg_catalog.has_any_column_privilege(
       'compras_contracting_responsible_mutation_owner', 'public.memberships', 'INSERT'
     )
     OR pg_catalog.has_any_column_privilege(
       'compras_contracting_responsible_mutation_owner', 'public.memberships', 'UPDATE'
     )
     OR pg_catalog.has_table_privilege(
       'compras_contracting_responsible_mutation_owner', 'public.memberships', 'DELETE'
     )
     OR pg_catalog.has_any_column_privilege(
       'compras_contracting_responsible_mutation_owner', 'public.app_users', 'INSERT'
     )
     OR pg_catalog.has_any_column_privilege(
       'compras_contracting_responsible_mutation_owner', 'public.app_users', 'UPDATE'
     )
     OR pg_catalog.has_table_privilege(
       'compras_contracting_responsible_mutation_owner', 'public.app_users', 'DELETE'
     ) THEN
    RAISE EXCEPTION 'responsible mutation capability can write identity state';
  END IF;

  IF pg_catalog.has_table_privilege(
       'compras_contracting_responsible_mutation_owner', 'public.contracting_events', 'UPDATE'
     )
     OR pg_catalog.has_table_privilege(
       'compras_contracting_responsible_mutation_owner', 'public.contracting_events', 'DELETE'
     ) THEN
    RAISE EXCEPTION 'responsible mutation capability can mutate existing events';
  END IF;

  FOREACH prior_role IN ARRAY ARRAY[
    'compras_next_action_mutation_owner',
    'compras_contracting_create_owner',
    'compras_contracting_object_mutation_owner',
    'compras_contracting_item_create_owner',
    'compras_contracting_item_mutation_owner',
    'compras_related_identifier_create_owner',
    'compras_manual_timeline_note_create_owner'
  ] LOOP
    IF pg_catalog.has_column_privilege(
         prior_role, 'public.contractings', 'responsible_membership_id', 'UPDATE'
       ) THEN
      RAISE EXCEPTION 'prior capability % gained responsible update authority', prior_role;
    END IF;
  END LOOP;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_catalog.pg_proc AS procedure
    JOIN pg_catalog.pg_namespace AS namespace
      ON namespace.oid = procedure.pronamespace
    WHERE namespace.nspname = 'public'
      AND procedure.proname = 'mutate_contracting_responsible'
      AND pg_catalog.pg_get_function_identity_arguments(procedure.oid)
        = 'p_contracting_id uuid, p_expected_responsible_membership_id uuid, p_new_responsible_membership_id uuid, p_event_id uuid'
      AND procedure.proowner = capability_oid
      AND procedure.prosecdef
      AND COALESCE(procedure.proconfig, ARRAY[]::text[])
        @> ARRAY['search_path=pg_catalog']
  ) THEN
    RAISE EXCEPTION 'responsible mutation function has unsafe ownership or search_path';
  END IF;
END;
$postflight$;

COMMIT;
