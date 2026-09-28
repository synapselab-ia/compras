BEGIN;

-- F44 persistent manual timeline note creation boundary.
-- This capability owns only the narrow SECURITY DEFINER primitive and never
-- owns a protected base table.
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
  WHERE r.rolname = 'compras_manual_timeline_note_create_owner';

  IF capability_oid IS NULL THEN
    EXECUTE $role$
      CREATE ROLE compras_manual_timeline_note_create_owner
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
    WHERE r.rolname = 'compras_manual_timeline_note_create_owner';
  END IF;

  IF capability_oid IS NULL THEN
    RAISE EXCEPTION 'manual timeline note create capability role could not be created';
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
    RAISE EXCEPTION 'manual timeline note create capability role has unsafe attributes or configuration';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM pg_catalog.pg_auth_members AS membership
    WHERE membership.member = capability_oid
  ) THEN
    RAISE EXCEPTION 'manual timeline note create capability role must not be a member of another role';
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
    RAISE EXCEPTION 'manual timeline note create capability role has unsafe grantees or usable membership';
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
    RAISE EXCEPTION 'migration principal cannot safely administer the manual timeline note create capability role';
  END IF;
END;
$migration$;

GRANT USAGE ON SCHEMA public TO compras_manual_timeline_note_create_owner;

GRANT SELECT (id, auth_issuer, auth_subject, disabled_at)
  ON public.app_users TO compras_manual_timeline_note_create_owner;
GRANT SELECT (id, team_id, user_id, revoked_at)
  ON public.memberships TO compras_manual_timeline_note_create_owner;
GRANT EXECUTE ON FUNCTION public.current_auth_issuer()
  TO compras_manual_timeline_note_create_owner;
GRANT EXECUTE ON FUNCTION public.current_auth_subject()
  TO compras_manual_timeline_note_create_owner;
GRANT EXECUTE ON FUNCTION public.current_app_user_id()
  TO compras_manual_timeline_note_create_owner;

GRANT SELECT (id, team_id, archived_at, cancelled_at)
  ON public.contractings TO compras_manual_timeline_note_create_owner;

GRANT SELECT (
  id,
  team_id,
  contracting_id,
  actor_membership_id,
  event_type,
  occurred_at,
  field_key,
  old_value,
  new_value,
  note,
  related_identifier_id,
  item_id,
  created_at
) ON public.contracting_events TO compras_manual_timeline_note_create_owner;

GRANT INSERT (
  id,
  team_id,
  contracting_id,
  actor_membership_id,
  event_type,
  occurred_at,
  note,
  created_at
) ON public.contracting_events TO compras_manual_timeline_note_create_owner;

-- The pilot guard counts every non-revoked membership in the target team,
-- including memberships whose app_user is disabled.
CREATE POLICY memberships_select_manual_timeline_note_create_capability
ON public.memberships
FOR SELECT
TO compras_manual_timeline_note_create_owner
USING (revoked_at IS NULL);

CREATE POLICY contractings_select_manual_timeline_note_create_capability
ON public.contractings
AS RESTRICTIVE
FOR SELECT
TO compras_manual_timeline_note_create_owner
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
);

CREATE POLICY contracting_events_select_manual_timeline_note_create_capability
ON public.contracting_events
AS RESTRICTIVE
FOR SELECT
TO compras_manual_timeline_note_create_owner
USING (
  event_type = 'manual_note_added'
  AND EXISTS (
    SELECT 1
    FROM public.contractings AS target
    WHERE target.id = contracting_events.contracting_id
      AND target.team_id = contracting_events.team_id
      AND target.archived_at IS NULL
      AND target.cancelled_at IS NULL
  )
  AND EXISTS (
    SELECT 1
    FROM public.memberships AS actor_membership
    WHERE actor_membership.team_id = contracting_events.team_id
      AND actor_membership.user_id = public.current_app_user_id()
      AND actor_membership.revoked_at IS NULL
  )
  AND 1 = (
    SELECT count(*)
    FROM public.memberships AS active_membership
    WHERE active_membership.team_id = contracting_events.team_id
      AND active_membership.revoked_at IS NULL
  )
);

CREATE POLICY contracting_events_insert_manual_timeline_note_create_capability
ON public.contracting_events
FOR INSERT
TO compras_manual_timeline_note_create_owner
WITH CHECK (
  event_type = 'manual_note_added'
  AND actor_membership_id IS NOT NULL
  AND field_key IS NULL
  AND old_value IS NULL
  AND new_value IS NULL
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
  )
);

CREATE FUNCTION public.create_manual_timeline_note(
  p_contracting_id uuid,
  p_event_id uuid,
  p_note text
)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog
AS $function$
DECLARE
  current_user_id uuid;
  target_team_id uuid;
  current_actor_membership_id uuid;
  existing_team_id uuid;
  existing_contracting_id uuid;
  existing_actor_membership_id uuid;
  existing_event_type text;
  existing_occurred_at timestamptz;
  existing_field_key text;
  existing_old_value text;
  existing_new_value text;
  existing_note text;
  existing_related_identifier_id uuid;
  existing_item_id uuid;
  existing_created_at timestamptz;
  inserted_event_id uuid;
  operation_at timestamptz;
BEGIN
  IF p_contracting_id IS NULL OR p_event_id IS NULL THEN
    RETURN 'denied';
  END IF;

  current_user_id := public.current_app_user_id();

  IF current_user_id IS NULL THEN
    RETURN 'denied';
  END IF;

  SELECT target.team_id
  INTO target_team_id
  FROM public.contractings AS target
  WHERE target.id = p_contracting_id
    AND target.archived_at IS NULL
    AND target.cancelled_at IS NULL;

  IF NOT FOUND THEN
    RETURN 'denied';
  END IF;

  SELECT membership.id
  INTO current_actor_membership_id
  FROM public.memberships AS membership
  WHERE membership.team_id = target_team_id
    AND membership.user_id = current_user_id
    AND membership.revoked_at IS NULL;

  IF current_actor_membership_id IS NULL THEN
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

  -- The prepared event UUID is only an idempotency selector. Replay requires
  -- current authorization and exact canonical-event proof.
  SELECT
    event.team_id,
    event.contracting_id,
    event.actor_membership_id,
    event.event_type,
    event.occurred_at,
    event.field_key,
    event.old_value,
    event.new_value,
    event.note,
    event.related_identifier_id,
    event.item_id,
    event.created_at
  INTO
    existing_team_id,
    existing_contracting_id,
    existing_actor_membership_id,
    existing_event_type,
    existing_occurred_at,
    existing_field_key,
    existing_old_value,
    existing_new_value,
    existing_note,
    existing_related_identifier_id,
    existing_item_id,
    existing_created_at
  FROM public.contracting_events AS event
  WHERE event.id = p_event_id;

  IF FOUND THEN
    IF existing_team_id = target_team_id
       AND existing_contracting_id = p_contracting_id
       AND existing_actor_membership_id = current_actor_membership_id
       AND existing_event_type = 'manual_note_added'
       AND existing_note IS NOT DISTINCT FROM p_note
       AND existing_field_key IS NULL
       AND existing_old_value IS NULL
       AND existing_new_value IS NULL
       AND existing_related_identifier_id IS NULL
       AND existing_item_id IS NULL
       AND existing_created_at = existing_occurred_at THEN
      RETURN 'already-added';
    END IF;

    RETURN 'denied';
  END IF;

  operation_at := pg_catalog.clock_timestamp();

  INSERT INTO public.contracting_events (
    id,
    team_id,
    contracting_id,
    actor_membership_id,
    event_type,
    occurred_at,
    note,
    created_at
  ) VALUES (
    p_event_id,
    target_team_id,
    p_contracting_id,
    current_actor_membership_id,
    'manual_note_added',
    operation_at,
    p_note,
    operation_at
  )
  ON CONFLICT DO NOTHING
  RETURNING id INTO inserted_event_id;

  IF inserted_event_id IS NOT NULL THEN
    RETURN 'created';
  END IF;

  -- A concurrent writer may have won the prepared UUID. Re-read only after
  -- the target has already been authorized, then require the same exact proof.
  SELECT
    event.team_id,
    event.contracting_id,
    event.actor_membership_id,
    event.event_type,
    event.occurred_at,
    event.field_key,
    event.old_value,
    event.new_value,
    event.note,
    event.related_identifier_id,
    event.item_id,
    event.created_at
  INTO
    existing_team_id,
    existing_contracting_id,
    existing_actor_membership_id,
    existing_event_type,
    existing_occurred_at,
    existing_field_key,
    existing_old_value,
    existing_new_value,
    existing_note,
    existing_related_identifier_id,
    existing_item_id,
    existing_created_at
  FROM public.contracting_events AS event
  WHERE event.id = p_event_id;

  IF FOUND
     AND existing_team_id = target_team_id
     AND existing_contracting_id = p_contracting_id
     AND existing_actor_membership_id = current_actor_membership_id
     AND existing_event_type = 'manual_note_added'
     AND existing_note IS NOT DISTINCT FROM p_note
     AND existing_field_key IS NULL
     AND existing_old_value IS NULL
     AND existing_new_value IS NULL
     AND existing_related_identifier_id IS NULL
     AND existing_item_id IS NULL
     AND existing_created_at = existing_occurred_at THEN
    RETURN 'already-added';
  END IF;

  RETURN 'denied';
END;
$function$;

REVOKE ALL ON FUNCTION public.create_manual_timeline_note(
  uuid, uuid, text
) FROM PUBLIC;

GRANT CREATE ON SCHEMA public TO compras_manual_timeline_note_create_owner;

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
      'GRANT compras_manual_timeline_note_create_owner TO %I WITH INHERIT FALSE, SET TRUE GRANTED BY %I',
      current_user,
      current_user
    );
  END IF;

  ALTER FUNCTION public.create_manual_timeline_note(
    uuid, uuid, text
  ) OWNER TO compras_manual_timeline_note_create_owner;

  IF NOT COALESCE(migration_is_superuser, false) THEN
    EXECUTE format(
      'REVOKE compras_manual_timeline_note_create_owner FROM %I GRANTED BY %I',
      current_user,
      current_user
    );
  END IF;
END;
$ownership$;

REVOKE CREATE ON SCHEMA public FROM compras_manual_timeline_note_create_owner;

DO $postflight$
DECLARE
  capability_oid oid;
  migration_oid oid;
BEGIN
  SELECT r.oid
  INTO capability_oid
  FROM pg_catalog.pg_roles AS r
  WHERE r.rolname = 'compras_manual_timeline_note_create_owner';

  SELECT r.oid
  INTO migration_oid
  FROM pg_catalog.pg_roles AS r
  WHERE r.rolname = current_user;

  IF capability_oid IS NULL OR migration_oid IS NULL THEN
    RAISE EXCEPTION 'cannot resolve manual timeline note create postflight principals';
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
    RAISE EXCEPTION 'manual timeline note create capability role is not sealed after ownership transfer';
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
        'contracting_events',
        'contracting_item_ordinal_counters'
      )
      AND relation.relowner = capability_oid
  ) THEN
    RAISE EXCEPTION 'manual timeline note create capability must not own protected base tables';
  END IF;

  IF pg_catalog.has_schema_privilege(
       'compras_manual_timeline_note_create_owner',
       'public',
       'CREATE'
     ) THEN
    RAISE EXCEPTION 'manual timeline note create capability retained schema CREATE privilege';
  END IF;

  IF pg_catalog.has_any_column_privilege(
       'compras_manual_timeline_note_create_owner',
       'public.contractings',
       'UPDATE'
     )
     OR pg_catalog.has_any_column_privilege(
       'compras_manual_timeline_note_create_owner',
       'public.related_identifiers',
       'INSERT'
     )
     OR pg_catalog.has_any_column_privilege(
       'compras_manual_timeline_note_create_owner',
       'public.related_identifiers',
       'UPDATE'
     )
     OR pg_catalog.has_table_privilege(
       'compras_manual_timeline_note_create_owner',
       'public.related_identifiers',
       'DELETE'
     )
     OR pg_catalog.has_any_column_privilege(
       'compras_manual_timeline_note_create_owner',
       'public.contracting_items',
       'INSERT'
     )
     OR pg_catalog.has_any_column_privilege(
       'compras_manual_timeline_note_create_owner',
       'public.contracting_items',
       'UPDATE'
     )
     OR pg_catalog.has_table_privilege(
       'compras_manual_timeline_note_create_owner',
       'public.contracting_items',
       'DELETE'
     )
     OR pg_catalog.has_table_privilege(
       'compras_manual_timeline_note_create_owner',
       'public.contracting_events',
       'UPDATE'
     )
     OR pg_catalog.has_table_privilege(
       'compras_manual_timeline_note_create_owner',
       'public.contracting_events',
       'DELETE'
     ) THEN
    RAISE EXCEPTION 'manual timeline note create capability can mutate existing domain state';
  END IF;

  IF NOT pg_catalog.has_column_privilege(
       'compras_manual_timeline_note_create_owner',
       'public.contracting_events',
       'id',
       'INSERT'
     )
     OR NOT pg_catalog.has_column_privilege(
       'compras_manual_timeline_note_create_owner',
       'public.contracting_events',
       'note',
       'INSERT'
     )
     OR NOT pg_catalog.has_column_privilege(
       'compras_manual_timeline_note_create_owner',
       'public.contracting_events',
       'created_at',
       'INSERT'
     )
     OR pg_catalog.has_column_privilege(
       'compras_manual_timeline_note_create_owner',
       'public.contracting_events',
       'field_key',
       'INSERT'
     )
     OR pg_catalog.has_column_privilege(
       'compras_manual_timeline_note_create_owner',
       'public.contracting_events',
       'old_value',
       'INSERT'
     )
     OR pg_catalog.has_column_privilege(
       'compras_manual_timeline_note_create_owner',
       'public.contracting_events',
       'new_value',
       'INSERT'
     )
     OR pg_catalog.has_column_privilege(
       'compras_manual_timeline_note_create_owner',
       'public.contracting_events',
       'related_identifier_id',
       'INSERT'
     )
     OR pg_catalog.has_column_privilege(
       'compras_manual_timeline_note_create_owner',
       'public.contracting_events',
       'item_id',
       'INSERT'
     ) THEN
    RAISE EXCEPTION 'manual timeline note create INSERT authority is not column-scoped as required';
  END IF;

  IF pg_catalog.has_function_privilege(
       'compras_manual_timeline_note_create_owner',
       'public.mutate_contracting_next_action(uuid,text,text,uuid)',
       'EXECUTE'
     )
     OR pg_catalog.has_function_privilege(
       'compras_manual_timeline_note_create_owner',
       'public.create_contracting_minimal(uuid,text,uuid)',
       'EXECUTE'
     )
     OR pg_catalog.has_function_privilege(
       'compras_manual_timeline_note_create_owner',
       'public.mutate_contracting_object(uuid,text,text,uuid)',
       'EXECUTE'
     )
     OR pg_catalog.has_function_privilege(
       'compras_manual_timeline_note_create_owner',
       'public.create_contracting_item(uuid,text,numeric,text,text,uuid,uuid)',
       'EXECUTE'
     )
     OR pg_catalog.has_function_privilege(
       'compras_manual_timeline_note_create_owner',
       'public.mutate_contracting_item_fields(uuid,uuid,text,numeric,text,text,text,numeric,text,text,uuid,uuid,uuid,uuid)',
       'EXECUTE'
     )
     OR pg_catalog.has_function_privilege(
       'compras_manual_timeline_note_create_owner',
       'public.create_related_identifier(uuid,uuid,text,text,text,text,uuid)',
       'EXECUTE'
     ) THEN
    RAISE EXCEPTION 'manual timeline note create capability inherited prior write authority';
  END IF;

  IF pg_catalog.has_function_privilege(
       'compras_next_action_mutation_owner',
       'public.create_manual_timeline_note(uuid,uuid,text)',
       'EXECUTE'
     )
     OR pg_catalog.has_function_privilege(
       'compras_contracting_create_owner',
       'public.create_manual_timeline_note(uuid,uuid,text)',
       'EXECUTE'
     )
     OR pg_catalog.has_function_privilege(
       'compras_contracting_object_mutation_owner',
       'public.create_manual_timeline_note(uuid,uuid,text)',
       'EXECUTE'
     )
     OR pg_catalog.has_function_privilege(
       'compras_contracting_item_create_owner',
       'public.create_manual_timeline_note(uuid,uuid,text)',
       'EXECUTE'
     )
     OR pg_catalog.has_function_privilege(
       'compras_contracting_item_mutation_owner',
       'public.create_manual_timeline_note(uuid,uuid,text)',
       'EXECUTE'
     )
     OR pg_catalog.has_function_privilege(
       'compras_related_identifier_create_owner',
       'public.create_manual_timeline_note(uuid,uuid,text)',
       'EXECUTE'
     ) THEN
    RAISE EXCEPTION 'prior write capability gained manual timeline note create EXECUTE';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_catalog.pg_proc AS procedure
    JOIN pg_catalog.pg_namespace AS namespace
      ON namespace.oid = procedure.pronamespace
    WHERE namespace.nspname = 'public'
      AND procedure.proname = 'create_manual_timeline_note'
      AND procedure.proowner = capability_oid
      AND procedure.prosecdef
      AND pg_catalog.pg_get_function_identity_arguments(procedure.oid)
        = 'p_contracting_id uuid, p_event_id uuid, p_note text'
      AND COALESCE(procedure.proconfig, ARRAY[]::text[])
        @> ARRAY['search_path=pg_catalog']
      AND position('EXECUTE ' IN upper(pg_catalog.pg_get_functiondef(procedure.oid))) = 0
  ) THEN
    RAISE EXCEPTION 'manual timeline note create primitive ownership/search_path/static SQL proof failed';
  END IF;
END;
$postflight$;

COMMIT;
