BEGIN;

-- F29 minimal persistent contracting creation boundary. The capability is a
-- sealed NOLOGIN technical owner, never an application credential. Its role
-- lifecycle follows ADR-005 and remains independent from the F26 capability.
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
  WHERE r.rolname = 'compras_contracting_create_owner';

  IF capability_oid IS NULL THEN
    EXECUTE $role$
      CREATE ROLE compras_contracting_create_owner
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
    WHERE r.rolname = 'compras_contracting_create_owner';
  END IF;

  IF capability_oid IS NULL THEN
    RAISE EXCEPTION 'contracting create capability role could not be created';
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
    RAISE EXCEPTION 'contracting create capability role has unsafe attributes or configuration';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM pg_catalog.pg_auth_members AS membership
    WHERE membership.member = capability_oid
  ) THEN
    RAISE EXCEPTION 'contracting create capability role must not be a member of another role';
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
    RAISE EXCEPTION 'contracting create capability role has unsafe grantees or usable membership';
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
    RAISE EXCEPTION 'migration principal cannot safely administer the contracting create capability role';
  END IF;
END;
$migration$;

GRANT USAGE ON SCHEMA public TO compras_contracting_create_owner;

-- Identity resolution remains issuer + subject from the trusted LOCAL context.
GRANT SELECT (id, auth_issuer, auth_subject, disabled_at)
  ON public.app_users TO compras_contracting_create_owner;
GRANT SELECT (id, team_id, user_id, revoked_at)
  ON public.memberships TO compras_contracting_create_owner;
GRANT SELECT (id, archived_at)
  ON public.teams TO compras_contracting_create_owner;
GRANT EXECUTE ON FUNCTION public.current_auth_issuer()
  TO compras_contracting_create_owner;
GRANT EXECUTE ON FUNCTION public.current_auth_subject()
  TO compras_contracting_create_owner;
GRANT EXECUTE ON FUNCTION public.current_app_user_id()
  TO compras_contracting_create_owner;

-- Replay recognition can inspect only the immutable request identity needed by
-- ADR-012. Creation itself is column-scoped and cannot populate operational
-- fields that remain deliberately NULL in this slice.
GRANT SELECT (id, team_id, object, created_by_membership_id)
  ON public.contractings TO compras_contracting_create_owner;
GRANT INSERT (
  id,
  team_id,
  object,
  created_by_membership_id,
  created_at,
  updated_at
) ON public.contractings TO compras_contracting_create_owner;

-- The initial audit fact is also column-scoped. Auxiliary event fields are not
-- writable by this capability and therefore remain NULL.
GRANT INSERT (
  id,
  team_id,
  contracting_id,
  actor_membership_id,
  event_type,
  occurred_at,
  created_at
) ON public.contracting_events TO compras_contracting_create_owner;

-- The sealed capability must count every non-revoked membership both for the
-- current user's global-scope ambiguity guard and for the derived team's
-- pilot-only guard, including memberships whose app_user is disabled.
CREATE POLICY memberships_select_contracting_create_capability
ON public.memberships
FOR SELECT
TO compras_contracting_create_owner
USING (revoked_at IS NULL);

-- INSERT remains authoritative under FORCE RLS. Scope and creator must be the
-- sole current membership derived from issuer+subject; all operational fields
-- outside the approved creation shape must stay NULL.
CREATE POLICY contractings_insert_contracting_create_capability
ON public.contractings
FOR INSERT
TO compras_contracting_create_owner
WITH CHECK (
  created_by_membership_id IS NOT NULL
  AND responsible_membership_id IS NULL
  AND stage_key IS NULL
  AND status_key IS NULL
  AND waiting_type IS NULL
  AND waiting_reference IS NULL
  AND waiting_since IS NULL
  AND waiting_reason IS NULL
  AND next_action IS NULL
  AND archived_at IS NULL
  AND cancelled_at IS NULL
  AND EXISTS (
    SELECT 1
    FROM public.memberships AS actor_membership
    JOIN public.teams AS actor_team
      ON actor_team.id = actor_membership.team_id
    WHERE actor_membership.id = contractings.created_by_membership_id
      AND actor_membership.team_id = contractings.team_id
      AND actor_membership.user_id = public.current_app_user_id()
      AND actor_membership.revoked_at IS NULL
      AND actor_team.archived_at IS NULL
  )
  AND 1 = (
    SELECT count(*)
    FROM public.memberships AS user_membership
    WHERE user_membership.user_id = public.current_app_user_id()
      AND user_membership.revoked_at IS NULL
  )
  AND 1 = (
    SELECT count(*)
    FROM public.memberships AS team_membership
    WHERE team_membership.team_id = contractings.team_id
      AND team_membership.revoked_at IS NULL
  )
);

-- The capability may append only the creation fact shape for a contracting in
-- the derived team, with the actor matching the same sole membership.
CREATE POLICY contracting_events_insert_contracting_create_capability
ON public.contracting_events
FOR INSERT
TO compras_contracting_create_owner
WITH CHECK (
  event_type = 'contracting_created'
  AND actor_membership_id IS NOT NULL
  AND field_key IS NULL
  AND old_value IS NULL
  AND new_value IS NULL
  AND note IS NULL
  AND related_identifier_id IS NULL
  AND item_id IS NULL
  AND EXISTS (
    SELECT 1
    FROM public.memberships AS actor_membership
    JOIN public.teams AS actor_team
      ON actor_team.id = actor_membership.team_id
    WHERE actor_membership.id = contracting_events.actor_membership_id
      AND actor_membership.team_id = contracting_events.team_id
      AND actor_membership.user_id = public.current_app_user_id()
      AND actor_membership.revoked_at IS NULL
      AND actor_team.archived_at IS NULL
  )
  AND 1 = (
    SELECT count(*)
    FROM public.memberships AS user_membership
    WHERE user_membership.user_id = public.current_app_user_id()
      AND user_membership.revoked_at IS NULL
  )
  AND 1 = (
    SELECT count(*)
    FROM public.memberships AS team_membership
    WHERE team_membership.team_id = contracting_events.team_id
      AND team_membership.revoked_at IS NULL
  )
  AND EXISTS (
    SELECT 1
    FROM public.contractings AS target
    WHERE target.id = contracting_events.contracting_id
      AND target.team_id = contracting_events.team_id
      AND target.created_by_membership_id = contracting_events.actor_membership_id
  )
);

CREATE FUNCTION public.create_contracting_minimal(
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
  ON CONFLICT (id) DO NOTHING
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

  -- A UUID collision only becomes an idempotent replay after current
  -- authorization has already passed and the existing row is visible through
  -- RLS with the exact immutable request identity. Cross-team/mismatched rows
  -- therefore collapse to the same denied outcome.
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

-- PostgreSQL grants EXECUTE on new functions to PUBLIC by default. Remove it
-- before ownership transfer; environment provisioning grants only the intended
-- non-privileged runtime role.
REVOKE ALL ON FUNCTION public.create_contracting_minimal(uuid, text, uuid)
  FROM PUBLIC;

-- Ownership transfer uses a transaction-local SET-capable edge as in ADR-005.
-- The edge is revoked before commit; only PostgreSQL 17's automatic ADMIN-only
-- edge may remain for the non-operational migration principal.
GRANT CREATE ON SCHEMA public TO compras_contracting_create_owner;

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
      'GRANT compras_contracting_create_owner TO %I WITH INHERIT FALSE, SET TRUE GRANTED BY %I',
      current_user,
      current_user
    );
  END IF;

  ALTER FUNCTION public.create_contracting_minimal(uuid, text, uuid)
    OWNER TO compras_contracting_create_owner;

  IF NOT COALESCE(migration_is_superuser, false) THEN
    EXECUTE format(
      'REVOKE compras_contracting_create_owner FROM %I GRANTED BY %I',
      current_user,
      current_user
    );
  END IF;
END;
$ownership$;

REVOKE CREATE ON SCHEMA public FROM compras_contracting_create_owner;

-- Final structural guard: the migration succeeds only with a sealed,
-- non-privileged owner and the exact narrow function/grant surface.
DO $postflight$
DECLARE
  capability_oid oid;
  migration_oid oid;
  create_function_oid oid;
BEGIN
  SELECT r.oid
  INTO capability_oid
  FROM pg_catalog.pg_roles AS r
  WHERE r.rolname = 'compras_contracting_create_owner';

  SELECT r.oid
  INTO migration_oid
  FROM pg_catalog.pg_roles AS r
  WHERE r.rolname = current_user;

  IF capability_oid IS NULL OR migration_oid IS NULL THEN
    RAISE EXCEPTION 'cannot resolve contracting create capability postflight principals';
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
    RAISE EXCEPTION 'contracting create capability role is not sealed after ownership transfer';
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
    RAISE EXCEPTION 'contracting create capability must not own protected base tables';
  END IF;

  IF pg_catalog.has_schema_privilege(
       'compras_contracting_create_owner',
       'public',
       'CREATE'
     ) THEN
    RAISE EXCEPTION 'contracting create capability retained schema CREATE privilege';
  END IF;

  IF NOT pg_catalog.has_column_privilege('compras_contracting_create_owner', 'public.contractings', 'id', 'INSERT')
     OR NOT pg_catalog.has_column_privilege('compras_contracting_create_owner', 'public.contractings', 'team_id', 'INSERT')
     OR NOT pg_catalog.has_column_privilege('compras_contracting_create_owner', 'public.contractings', 'object', 'INSERT')
     OR NOT pg_catalog.has_column_privilege('compras_contracting_create_owner', 'public.contractings', 'created_by_membership_id', 'INSERT')
     OR NOT pg_catalog.has_column_privilege('compras_contracting_create_owner', 'public.contractings', 'created_at', 'INSERT')
     OR NOT pg_catalog.has_column_privilege('compras_contracting_create_owner', 'public.contractings', 'updated_at', 'INSERT') THEN
    RAISE EXCEPTION 'contracting create capability is missing approved contracting INSERT columns';
  END IF;

  IF pg_catalog.has_column_privilege('compras_contracting_create_owner', 'public.contractings', 'responsible_membership_id', 'INSERT')
     OR pg_catalog.has_column_privilege('compras_contracting_create_owner', 'public.contractings', 'stage_key', 'INSERT')
     OR pg_catalog.has_column_privilege('compras_contracting_create_owner', 'public.contractings', 'status_key', 'INSERT')
     OR pg_catalog.has_column_privilege('compras_contracting_create_owner', 'public.contractings', 'waiting_type', 'INSERT')
     OR pg_catalog.has_column_privilege('compras_contracting_create_owner', 'public.contractings', 'waiting_reference', 'INSERT')
     OR pg_catalog.has_column_privilege('compras_contracting_create_owner', 'public.contractings', 'waiting_since', 'INSERT')
     OR pg_catalog.has_column_privilege('compras_contracting_create_owner', 'public.contractings', 'waiting_reason', 'INSERT')
     OR pg_catalog.has_column_privilege('compras_contracting_create_owner', 'public.contractings', 'next_action', 'INSERT')
     OR pg_catalog.has_column_privilege('compras_contracting_create_owner', 'public.contractings', 'archived_at', 'INSERT')
     OR pg_catalog.has_column_privilege('compras_contracting_create_owner', 'public.contractings', 'cancelled_at', 'INSERT') THEN
    RAISE EXCEPTION 'contracting create capability can populate unapproved contracting columns';
  END IF;

  IF NOT pg_catalog.has_column_privilege('compras_contracting_create_owner', 'public.contracting_events', 'id', 'INSERT')
     OR NOT pg_catalog.has_column_privilege('compras_contracting_create_owner', 'public.contracting_events', 'team_id', 'INSERT')
     OR NOT pg_catalog.has_column_privilege('compras_contracting_create_owner', 'public.contracting_events', 'contracting_id', 'INSERT')
     OR NOT pg_catalog.has_column_privilege('compras_contracting_create_owner', 'public.contracting_events', 'actor_membership_id', 'INSERT')
     OR NOT pg_catalog.has_column_privilege('compras_contracting_create_owner', 'public.contracting_events', 'event_type', 'INSERT')
     OR NOT pg_catalog.has_column_privilege('compras_contracting_create_owner', 'public.contracting_events', 'occurred_at', 'INSERT')
     OR NOT pg_catalog.has_column_privilege('compras_contracting_create_owner', 'public.contracting_events', 'created_at', 'INSERT') THEN
    RAISE EXCEPTION 'contracting create capability is missing approved event INSERT columns';
  END IF;

  IF pg_catalog.has_column_privilege('compras_contracting_create_owner', 'public.contracting_events', 'field_key', 'INSERT')
     OR pg_catalog.has_column_privilege('compras_contracting_create_owner', 'public.contracting_events', 'old_value', 'INSERT')
     OR pg_catalog.has_column_privilege('compras_contracting_create_owner', 'public.contracting_events', 'new_value', 'INSERT')
     OR pg_catalog.has_column_privilege('compras_contracting_create_owner', 'public.contracting_events', 'note', 'INSERT')
     OR pg_catalog.has_column_privilege('compras_contracting_create_owner', 'public.contracting_events', 'related_identifier_id', 'INSERT')
     OR pg_catalog.has_column_privilege('compras_contracting_create_owner', 'public.contracting_events', 'item_id', 'INSERT') THEN
    RAISE EXCEPTION 'contracting create capability can populate unapproved event columns';
  END IF;

  IF pg_catalog.has_table_privilege('compras_contracting_create_owner', 'public.contractings', 'UPDATE')
     OR pg_catalog.has_table_privilege('compras_contracting_create_owner', 'public.contractings', 'DELETE')
     OR pg_catalog.has_table_privilege('compras_contracting_create_owner', 'public.contracting_events', 'UPDATE')
     OR pg_catalog.has_table_privilege('compras_contracting_create_owner', 'public.contracting_events', 'DELETE')
     OR pg_catalog.has_column_privilege('compras_contracting_create_owner', 'public.contractings', 'next_action', 'UPDATE') THEN
    RAISE EXCEPTION 'contracting create capability can mutate existing operational state';
  END IF;

  IF pg_catalog.has_function_privilege(
       'compras_contracting_create_owner',
       'public.mutate_contracting_next_action(uuid,text,text,uuid)',
       'EXECUTE'
     ) THEN
    RAISE EXCEPTION 'contracting create capability unexpectedly received F26 EXECUTE';
  END IF;

  SELECT procedure.oid
  INTO create_function_oid
  FROM pg_catalog.pg_proc AS procedure
  JOIN pg_catalog.pg_namespace AS namespace
    ON namespace.oid = procedure.pronamespace
  WHERE namespace.nspname = 'public'
    AND procedure.proname = 'create_contracting_minimal'
    AND pg_catalog.pg_get_function_identity_arguments(procedure.oid)
      = 'p_contracting_id uuid, p_object text, p_event_id uuid'
    AND procedure.proowner = capability_oid
    AND procedure.prosecdef
    AND COALESCE(procedure.proconfig, ARRAY[]::text[])
      @> ARRAY['search_path=pg_catalog']
    AND pg_catalog.position(
      'EXECUTE ' IN pg_catalog.upper(pg_catalog.pg_get_functiondef(procedure.oid))
    ) = 0;

  IF create_function_oid IS NULL THEN
    RAISE EXCEPTION 'contracting create function has unsafe ownership, security mode, search_path or SQL';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM pg_catalog.aclexplode(
      COALESCE(
        (SELECT p.proacl FROM pg_catalog.pg_proc AS p WHERE p.oid = create_function_oid),
        pg_catalog.acldefault('f', capability_oid)
      )
    ) AS acl
    WHERE acl.grantee = 0
      AND acl.privilege_type = 'EXECUTE'
  ) THEN
    RAISE EXCEPTION 'contracting create function leaked PUBLIC EXECUTE';
  END IF;
END;
$postflight$;

COMMIT;
