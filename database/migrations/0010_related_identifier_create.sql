BEGIN;

-- F41 persistent related identifier creation boundary.
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
  WHERE r.rolname = 'compras_related_identifier_create_owner';

  IF capability_oid IS NULL THEN
    EXECUTE $role$
      CREATE ROLE compras_related_identifier_create_owner
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
    WHERE r.rolname = 'compras_related_identifier_create_owner';
  END IF;

  IF capability_oid IS NULL THEN
    RAISE EXCEPTION 'related identifier create capability role could not be created';
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
    RAISE EXCEPTION 'related identifier create capability role has unsafe attributes or configuration';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM pg_catalog.pg_auth_members AS membership
    WHERE membership.member = capability_oid
  ) THEN
    RAISE EXCEPTION 'related identifier create capability role must not be a member of another role';
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
    RAISE EXCEPTION 'related identifier create capability role has unsafe grantees or usable membership';
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
    RAISE EXCEPTION 'migration principal cannot safely administer the related identifier create capability role';
  END IF;
END;
$migration$;

GRANT USAGE ON SCHEMA public TO compras_related_identifier_create_owner;

GRANT SELECT (id, auth_issuer, auth_subject, disabled_at)
  ON public.app_users TO compras_related_identifier_create_owner;
GRANT SELECT (id, team_id, user_id, revoked_at)
  ON public.memberships TO compras_related_identifier_create_owner;
GRANT EXECUTE ON FUNCTION public.current_auth_issuer()
  TO compras_related_identifier_create_owner;
GRANT EXECUTE ON FUNCTION public.current_auth_subject()
  TO compras_related_identifier_create_owner;
GRANT EXECUTE ON FUNCTION public.current_app_user_id()
  TO compras_related_identifier_create_owner;

GRANT SELECT (id, team_id, archived_at, cancelled_at)
  ON public.contractings TO compras_related_identifier_create_owner;

GRANT SELECT (
  id,
  team_id,
  contracting_id,
  identifier_kind,
  identifier_value,
  source_system,
  note,
  linked_at,
  unlinked_at
) ON public.related_identifiers TO compras_related_identifier_create_owner;

GRANT INSERT (
  id,
  team_id,
  contracting_id,
  identifier_kind,
  identifier_value,
  source_system,
  note,
  linked_at
) ON public.related_identifiers TO compras_related_identifier_create_owner;

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
) ON public.contracting_events TO compras_related_identifier_create_owner;

GRANT INSERT (
  id,
  team_id,
  contracting_id,
  actor_membership_id,
  event_type,
  occurred_at,
  related_identifier_id,
  created_at
) ON public.contracting_events TO compras_related_identifier_create_owner;

-- The pilot guard must count every non-revoked membership in the target team,
-- including a membership whose app_user is disabled.
CREATE POLICY memberships_select_related_identifier_create_capability
ON public.memberships
FOR SELECT
TO compras_related_identifier_create_owner
USING (revoked_at IS NULL);

-- Generic read policies remain permissive for normal read roles. These
-- capability-specific restrictive policies keep the F41 owner inside the
-- active target-team pilot boundary when it reads state for authorization or
-- replay proof.
CREATE POLICY contractings_select_related_identifier_create_capability
ON public.contractings
AS RESTRICTIVE
FOR SELECT
TO compras_related_identifier_create_owner
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

CREATE POLICY related_identifiers_select_related_identifier_create_capability
ON public.related_identifiers
AS RESTRICTIVE
FOR SELECT
TO compras_related_identifier_create_owner
USING (
  unlinked_at IS NULL
  AND EXISTS (
    SELECT 1
    FROM public.contractings AS target
    WHERE target.id = related_identifiers.contracting_id
      AND target.team_id = related_identifiers.team_id
      AND target.archived_at IS NULL
      AND target.cancelled_at IS NULL
  )
  AND EXISTS (
    SELECT 1
    FROM public.memberships AS actor_membership
    WHERE actor_membership.team_id = related_identifiers.team_id
      AND actor_membership.user_id = public.current_app_user_id()
      AND actor_membership.revoked_at IS NULL
  )
  AND 1 = (
    SELECT count(*)
    FROM public.memberships AS active_membership
    WHERE active_membership.team_id = related_identifiers.team_id
      AND active_membership.revoked_at IS NULL
  )
);

CREATE POLICY contracting_events_select_related_identifier_create_capability
ON public.contracting_events
AS RESTRICTIVE
FOR SELECT
TO compras_related_identifier_create_owner
USING (
  EXISTS (
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

CREATE POLICY related_identifiers_insert_related_identifier_create_capability
ON public.related_identifiers
FOR INSERT
TO compras_related_identifier_create_owner
WITH CHECK (
  unlinked_at IS NULL
  AND EXISTS (
    SELECT 1
    FROM public.contractings AS target
    WHERE target.id = related_identifiers.contracting_id
      AND target.team_id = related_identifiers.team_id
      AND target.archived_at IS NULL
      AND target.cancelled_at IS NULL
  )
  AND EXISTS (
    SELECT 1
    FROM public.memberships AS actor_membership
    WHERE actor_membership.team_id = related_identifiers.team_id
      AND actor_membership.user_id = public.current_app_user_id()
      AND actor_membership.revoked_at IS NULL
  )
  AND 1 = (
    SELECT count(*)
    FROM public.memberships AS active_membership
    WHERE active_membership.team_id = related_identifiers.team_id
      AND active_membership.revoked_at IS NULL
  )
);

CREATE POLICY contracting_events_insert_related_identifier_create_capability
ON public.contracting_events
FOR INSERT
TO compras_related_identifier_create_owner
WITH CHECK (
  event_type = 'related_identifier_linked'
  AND actor_membership_id IS NOT NULL
  AND related_identifier_id IS NOT NULL
  AND item_id IS NULL
  AND field_key IS NULL
  AND old_value IS NULL
  AND new_value IS NULL
  AND note IS NULL
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
  AND EXISTS (
    SELECT 1
    FROM public.related_identifiers AS related
    WHERE related.id = contracting_events.related_identifier_id
      AND related.team_id = contracting_events.team_id
      AND related.contracting_id = contracting_events.contracting_id
      AND related.unlinked_at IS NULL
      AND related.linked_at = contracting_events.occurred_at
  )
);

CREATE FUNCTION public.create_related_identifier(
  p_contracting_id uuid,
  p_related_identifier_id uuid,
  p_identifier_kind text,
  p_identifier_value text,
  p_source_system text,
  p_note text,
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
  existing_team_id uuid;
  existing_contracting_id uuid;
  existing_identifier_kind text;
  existing_identifier_value text;
  existing_source_system text;
  existing_note text;
  existing_linked_at timestamptz;
  existing_unlinked_at timestamptz;
  canonical_event_count bigint;
  inserted_related_identifier_id uuid;
  operation_at timestamptz;
BEGIN
  IF p_contracting_id IS NULL
     OR p_related_identifier_id IS NULL
     OR p_identifier_value IS NULL
     OR p_event_id IS NULL THEN
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

  -- A prepared UUID is only an idempotency selector. Replay is accepted only
  -- after current authorization and exact row plus canonical-event proof.
  SELECT
    related.team_id,
    related.contracting_id,
    related.identifier_kind,
    related.identifier_value,
    related.source_system,
    related.note,
    related.linked_at,
    related.unlinked_at
  INTO
    existing_team_id,
    existing_contracting_id,
    existing_identifier_kind,
    existing_identifier_value,
    existing_source_system,
    existing_note,
    existing_linked_at,
    existing_unlinked_at
  FROM public.related_identifiers AS related
  WHERE related.id = p_related_identifier_id;

  IF FOUND THEN
    IF existing_team_id = target_team_id
       AND existing_contracting_id = p_contracting_id
       AND existing_unlinked_at IS NULL
       AND existing_identifier_kind IS NOT DISTINCT FROM p_identifier_kind
       AND existing_identifier_value = p_identifier_value
       AND existing_source_system IS NOT DISTINCT FROM p_source_system
       AND existing_note IS NOT DISTINCT FROM p_note THEN

      SELECT count(*)
      INTO canonical_event_count
      FROM public.contracting_events AS event
      WHERE event.team_id = target_team_id
        AND event.contracting_id = p_contracting_id
        AND event.related_identifier_id = p_related_identifier_id
        AND event.event_type = 'related_identifier_linked'
        AND event.actor_membership_id = actor_membership_id
        AND event.occurred_at = existing_linked_at
        AND event.created_at = existing_linked_at
        AND event.field_key IS NULL
        AND event.old_value IS NULL
        AND event.new_value IS NULL
        AND event.note IS NULL
        AND event.item_id IS NULL;

      IF canonical_event_count = 1 THEN
        RETURN 'already-linked';
      END IF;
    END IF;

    RETURN 'denied';
  END IF;

  operation_at := pg_catalog.clock_timestamp();

  INSERT INTO public.related_identifiers (
    id,
    team_id,
    contracting_id,
    identifier_kind,
    identifier_value,
    source_system,
    note,
    linked_at
  ) VALUES (
    p_related_identifier_id,
    target_team_id,
    p_contracting_id,
    p_identifier_kind,
    p_identifier_value,
    p_source_system,
    p_note,
    operation_at
  )
  ON CONFLICT DO NOTHING
  RETURNING id INTO inserted_related_identifier_id;

  IF inserted_related_identifier_id IS NOT NULL THEN
    INSERT INTO public.contracting_events (
      id,
      team_id,
      contracting_id,
      actor_membership_id,
      event_type,
      occurred_at,
      related_identifier_id,
      created_at
    ) VALUES (
      p_event_id,
      target_team_id,
      p_contracting_id,
      actor_membership_id,
      'related_identifier_linked',
      operation_at,
      p_related_identifier_id,
      operation_at
    );

    RETURN 'created';
  END IF;

  -- A concurrent writer may have won the prepared UUID. Re-read only after
  -- the target has already been authorized, then require the same exact proof.
  SELECT
    related.team_id,
    related.contracting_id,
    related.identifier_kind,
    related.identifier_value,
    related.source_system,
    related.note,
    related.linked_at,
    related.unlinked_at
  INTO
    existing_team_id,
    existing_contracting_id,
    existing_identifier_kind,
    existing_identifier_value,
    existing_source_system,
    existing_note,
    existing_linked_at,
    existing_unlinked_at
  FROM public.related_identifiers AS related
  WHERE related.id = p_related_identifier_id;

  IF FOUND
     AND existing_team_id = target_team_id
     AND existing_contracting_id = p_contracting_id
     AND existing_unlinked_at IS NULL
     AND existing_identifier_kind IS NOT DISTINCT FROM p_identifier_kind
     AND existing_identifier_value = p_identifier_value
     AND existing_source_system IS NOT DISTINCT FROM p_source_system
     AND existing_note IS NOT DISTINCT FROM p_note THEN

    SELECT count(*)
    INTO canonical_event_count
    FROM public.contracting_events AS event
    WHERE event.team_id = target_team_id
      AND event.contracting_id = p_contracting_id
      AND event.related_identifier_id = p_related_identifier_id
      AND event.event_type = 'related_identifier_linked'
      AND event.actor_membership_id = actor_membership_id
      AND event.occurred_at = existing_linked_at
      AND event.created_at = existing_linked_at
      AND event.field_key IS NULL
      AND event.old_value IS NULL
      AND event.new_value IS NULL
      AND event.note IS NULL
      AND event.item_id IS NULL;

    IF canonical_event_count = 1 THEN
      RETURN 'already-linked';
    END IF;
  END IF;

  RETURN 'denied';
END;
$function$;

REVOKE ALL ON FUNCTION public.create_related_identifier(
  uuid, uuid, text, text, text, text, uuid
) FROM PUBLIC;

GRANT CREATE ON SCHEMA public TO compras_related_identifier_create_owner;

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
      'GRANT compras_related_identifier_create_owner TO %I WITH INHERIT FALSE, SET TRUE GRANTED BY %I',
      current_user,
      current_user
    );
  END IF;

  ALTER FUNCTION public.create_related_identifier(
    uuid, uuid, text, text, text, text, uuid
  ) OWNER TO compras_related_identifier_create_owner;

  IF NOT COALESCE(migration_is_superuser, false) THEN
    EXECUTE format(
      'REVOKE compras_related_identifier_create_owner FROM %I GRANTED BY %I',
      current_user,
      current_user
    );
  END IF;
END;
$ownership$;

REVOKE CREATE ON SCHEMA public FROM compras_related_identifier_create_owner;

DO $postflight$
DECLARE
  capability_oid oid;
  migration_oid oid;
BEGIN
  SELECT r.oid
  INTO capability_oid
  FROM pg_catalog.pg_roles AS r
  WHERE r.rolname = 'compras_related_identifier_create_owner';

  SELECT r.oid
  INTO migration_oid
  FROM pg_catalog.pg_roles AS r
  WHERE r.rolname = current_user;

  IF capability_oid IS NULL OR migration_oid IS NULL THEN
    RAISE EXCEPTION 'cannot resolve related identifier create postflight principals';
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
    RAISE EXCEPTION 'related identifier create capability role is not sealed after ownership transfer';
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
    RAISE EXCEPTION 'related identifier create capability must not own protected base tables';
  END IF;

  IF pg_catalog.has_schema_privilege(
       'compras_related_identifier_create_owner',
       'public',
       'CREATE'
     ) THEN
    RAISE EXCEPTION 'related identifier create capability retained schema CREATE privilege';
  END IF;

  IF pg_catalog.has_any_column_privilege(
       'compras_related_identifier_create_owner',
       'public.contractings',
       'UPDATE'
     )
     OR pg_catalog.has_any_column_privilege(
       'compras_related_identifier_create_owner',
       'public.related_identifiers',
       'UPDATE'
     )
     OR pg_catalog.has_table_privilege(
       'compras_related_identifier_create_owner',
       'public.related_identifiers',
       'DELETE'
     )
     OR pg_catalog.has_table_privilege(
       'compras_related_identifier_create_owner',
       'public.contracting_events',
       'UPDATE'
     )
     OR pg_catalog.has_table_privilege(
       'compras_related_identifier_create_owner',
       'public.contracting_events',
       'DELETE'
     ) THEN
    RAISE EXCEPTION 'related identifier create capability can mutate existing domain state';
  END IF;

  IF NOT pg_catalog.has_column_privilege(
       'compras_related_identifier_create_owner',
       'public.related_identifiers',
       'id',
       'INSERT'
     )
     OR NOT pg_catalog.has_column_privilege(
       'compras_related_identifier_create_owner',
       'public.related_identifiers',
       'linked_at',
       'INSERT'
     )
     OR pg_catalog.has_column_privilege(
       'compras_related_identifier_create_owner',
       'public.related_identifiers',
       'unlinked_at',
       'INSERT'
     ) THEN
    RAISE EXCEPTION 'related identifier create INSERT authority is not column-scoped as required';
  END IF;

  IF pg_catalog.has_function_privilege(
       'compras_related_identifier_create_owner',
       'public.mutate_contracting_next_action(uuid,text,text,uuid)',
       'EXECUTE'
     )
     OR pg_catalog.has_function_privilege(
       'compras_related_identifier_create_owner',
       'public.create_contracting_minimal(uuid,text,uuid)',
       'EXECUTE'
     )
     OR pg_catalog.has_function_privilege(
       'compras_related_identifier_create_owner',
       'public.mutate_contracting_object(uuid,text,text,uuid)',
       'EXECUTE'
     )
     OR pg_catalog.has_function_privilege(
       'compras_related_identifier_create_owner',
       'public.create_contracting_item(uuid,text,numeric,text,text,uuid,uuid)',
       'EXECUTE'
     )
     OR pg_catalog.has_function_privilege(
       'compras_related_identifier_create_owner',
       'public.mutate_contracting_item_fields(uuid,uuid,text,numeric,text,text,text,numeric,text,text,uuid,uuid,uuid,uuid)',
       'EXECUTE'
     ) THEN
    RAISE EXCEPTION 'related identifier create capability inherited prior write authority';
  END IF;

  IF pg_catalog.has_function_privilege(
       'compras_next_action_mutation_owner',
       'public.create_related_identifier(uuid,uuid,text,text,text,text,uuid)',
       'EXECUTE'
     )
     OR pg_catalog.has_function_privilege(
       'compras_contracting_create_owner',
       'public.create_related_identifier(uuid,uuid,text,text,text,text,uuid)',
       'EXECUTE'
     )
     OR pg_catalog.has_function_privilege(
       'compras_contracting_object_mutation_owner',
       'public.create_related_identifier(uuid,uuid,text,text,text,text,uuid)',
       'EXECUTE'
     )
     OR pg_catalog.has_function_privilege(
       'compras_contracting_item_create_owner',
       'public.create_related_identifier(uuid,uuid,text,text,text,text,uuid)',
       'EXECUTE'
     )
     OR pg_catalog.has_function_privilege(
       'compras_contracting_item_mutation_owner',
       'public.create_related_identifier(uuid,uuid,text,text,text,text,uuid)',
       'EXECUTE'
     ) THEN
    RAISE EXCEPTION 'prior write capability gained related identifier create EXECUTE';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_catalog.pg_proc AS procedure
    JOIN pg_catalog.pg_namespace AS namespace
      ON namespace.oid = procedure.pronamespace
    WHERE namespace.nspname = 'public'
      AND procedure.proname = 'create_related_identifier'
      AND procedure.proowner = capability_oid
      AND procedure.prosecdef
      AND pg_catalog.pg_get_function_identity_arguments(procedure.oid)
        = 'p_contracting_id uuid, p_related_identifier_id uuid, p_identifier_kind text, p_identifier_value text, p_source_system text, p_note text, p_event_id uuid'
      AND COALESCE(procedure.proconfig, ARRAY[]::text[])
        @> ARRAY['search_path=pg_catalog']
      AND position('EXECUTE ' IN upper(pg_catalog.pg_get_functiondef(procedure.oid))) = 0
  ) THEN
    RAISE EXCEPTION 'related identifier create primitive ownership/search_path/static SQL proof failed';
  END IF;
END;
$postflight$;

COMMIT;
