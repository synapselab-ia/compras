BEGIN;

-- F35 persistent contracting item creation boundary. The allocator is
-- technical state only and is not part of the product read model.
CREATE TABLE public.contracting_item_ordinal_counters (
  team_id uuid NOT NULL,
  contracting_id uuid PRIMARY KEY,
  last_ordinal integer NULL,
  CONSTRAINT contracting_item_ordinal_counters_contracting_fk
    FOREIGN KEY (team_id, contracting_id)
    REFERENCES public.contractings(team_id, id)
);

ALTER TABLE public.contracting_item_ordinal_counters ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.contracting_item_ordinal_counters FORCE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.contracting_item_ordinal_counters FROM PUBLIC;

-- The item-create capability is a sealed NOLOGIN technical owner. It remains
-- separate from F26 next_action, F29 contracting create and F32 object edit.
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
  WHERE r.rolname = 'compras_contracting_item_create_owner';

  IF capability_oid IS NULL THEN
    EXECUTE $role$
      CREATE ROLE compras_contracting_item_create_owner
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
    WHERE r.rolname = 'compras_contracting_item_create_owner';
  END IF;

  IF capability_oid IS NULL THEN
    RAISE EXCEPTION 'contracting item create capability role could not be created';
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
    RAISE EXCEPTION 'contracting item create capability role has unsafe attributes or configuration';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM pg_catalog.pg_auth_members AS membership
    WHERE membership.member = capability_oid
  ) THEN
    RAISE EXCEPTION 'contracting item create capability role must not be a member of another role';
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
    RAISE EXCEPTION 'contracting item create capability role has unsafe grantees or usable membership';
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
    RAISE EXCEPTION 'migration principal cannot safely administer the contracting item create capability role';
  END IF;
END;
$migration$;

GRANT USAGE ON SCHEMA public TO compras_contracting_item_create_owner;

-- Trusted identity remains issuer + subject established only in the trusted
-- server transaction context.
GRANT SELECT (id, auth_issuer, auth_subject, disabled_at)
  ON public.app_users TO compras_contracting_item_create_owner;
GRANT SELECT (id, team_id, user_id, revoked_at)
  ON public.memberships TO compras_contracting_item_create_owner;
GRANT EXECUTE ON FUNCTION public.current_auth_issuer()
  TO compras_contracting_item_create_owner;
GRANT EXECUTE ON FUNCTION public.current_auth_subject()
  TO compras_contracting_item_create_owner;
GRANT EXECUTE ON FUNCTION public.current_app_user_id()
  TO compras_contracting_item_create_owner;

-- Parent access is read-only. F35 receives zero UPDATE authority on
-- contractings and therefore never row-locks the parent.
GRANT SELECT (id, team_id, archived_at, cancelled_at)
  ON public.contractings TO compras_contracting_item_create_owner;

-- Existing items are read only for ordinal reconciliation and event checks.
-- Creation is column-scoped and retired_at is deliberately omitted.
GRANT SELECT (id, team_id, contracting_id, ordinal, retired_at)
  ON public.contracting_items TO compras_contracting_item_create_owner;
GRANT INSERT (
  id,
  team_id,
  contracting_id,
  ordinal,
  description,
  quantity,
  unit,
  catalog_code,
  created_at,
  updated_at
) ON public.contracting_items TO compras_contracting_item_create_owner;

-- The allocator is the only table on which this capability may update state.
GRANT SELECT (team_id, contracting_id, last_ordinal)
  ON public.contracting_item_ordinal_counters TO compras_contracting_item_create_owner;
GRANT INSERT (team_id, contracting_id, last_ordinal)
  ON public.contracting_item_ordinal_counters TO compras_contracting_item_create_owner;
GRANT UPDATE (last_ordinal)
  ON public.contracting_item_ordinal_counters TO compras_contracting_item_create_owner;

-- Audit insertion is column-scoped. Textual old/new/note fields remain NULL.
GRANT INSERT (
  id,
  team_id,
  contracting_id,
  actor_membership_id,
  event_type,
  occurred_at,
  item_id,
  created_at
) ON public.contracting_events TO compras_contracting_item_create_owner;

-- The pilot guard must count every non-revoked membership in the target team,
-- including memberships whose app_user is disabled.
CREATE POLICY memberships_select_contracting_item_create_capability
ON public.memberships
FOR SELECT
TO compras_contracting_item_create_owner
USING (revoked_at IS NULL);

CREATE POLICY contracting_item_ordinal_counters_select_capability
ON public.contracting_item_ordinal_counters
FOR SELECT
TO compras_contracting_item_create_owner
USING (
  EXISTS (
    SELECT 1
    FROM public.contractings AS target
    WHERE target.id = contracting_item_ordinal_counters.contracting_id
      AND target.team_id = contracting_item_ordinal_counters.team_id
      AND target.archived_at IS NULL
      AND target.cancelled_at IS NULL
  )
  AND EXISTS (
    SELECT 1
    FROM public.memberships AS actor_membership
    WHERE actor_membership.team_id = contracting_item_ordinal_counters.team_id
      AND actor_membership.user_id = public.current_app_user_id()
      AND actor_membership.revoked_at IS NULL
  )
  AND 1 = (
    SELECT count(*)
    FROM public.memberships AS active_membership
    WHERE active_membership.team_id = contracting_item_ordinal_counters.team_id
      AND active_membership.revoked_at IS NULL
  )
);

CREATE POLICY contracting_item_ordinal_counters_insert_capability
ON public.contracting_item_ordinal_counters
FOR INSERT
TO compras_contracting_item_create_owner
WITH CHECK (
  last_ordinal IS NULL
  AND EXISTS (
    SELECT 1
    FROM public.contractings AS target
    WHERE target.id = contracting_item_ordinal_counters.contracting_id
      AND target.team_id = contracting_item_ordinal_counters.team_id
      AND target.archived_at IS NULL
      AND target.cancelled_at IS NULL
  )
  AND EXISTS (
    SELECT 1
    FROM public.memberships AS actor_membership
    WHERE actor_membership.team_id = contracting_item_ordinal_counters.team_id
      AND actor_membership.user_id = public.current_app_user_id()
      AND actor_membership.revoked_at IS NULL
  )
  AND 1 = (
    SELECT count(*)
    FROM public.memberships AS active_membership
    WHERE active_membership.team_id = contracting_item_ordinal_counters.team_id
      AND active_membership.revoked_at IS NULL
  )
);

CREATE POLICY contracting_item_ordinal_counters_update_capability
ON public.contracting_item_ordinal_counters
FOR UPDATE
TO compras_contracting_item_create_owner
USING (
  EXISTS (
    SELECT 1
    FROM public.contractings AS target
    WHERE target.id = contracting_item_ordinal_counters.contracting_id
      AND target.team_id = contracting_item_ordinal_counters.team_id
      AND target.archived_at IS NULL
      AND target.cancelled_at IS NULL
  )
  AND EXISTS (
    SELECT 1
    FROM public.memberships AS actor_membership
    WHERE actor_membership.team_id = contracting_item_ordinal_counters.team_id
      AND actor_membership.user_id = public.current_app_user_id()
      AND actor_membership.revoked_at IS NULL
  )
  AND 1 = (
    SELECT count(*)
    FROM public.memberships AS active_membership
    WHERE active_membership.team_id = contracting_item_ordinal_counters.team_id
      AND active_membership.revoked_at IS NULL
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1
    FROM public.contractings AS target
    WHERE target.id = contracting_item_ordinal_counters.contracting_id
      AND target.team_id = contracting_item_ordinal_counters.team_id
      AND target.archived_at IS NULL
      AND target.cancelled_at IS NULL
  )
  AND EXISTS (
    SELECT 1
    FROM public.memberships AS actor_membership
    WHERE actor_membership.team_id = contracting_item_ordinal_counters.team_id
      AND actor_membership.user_id = public.current_app_user_id()
      AND actor_membership.revoked_at IS NULL
  )
  AND 1 = (
    SELECT count(*)
    FROM public.memberships AS active_membership
    WHERE active_membership.team_id = contracting_item_ordinal_counters.team_id
      AND active_membership.revoked_at IS NULL
  )
);

CREATE POLICY contracting_items_insert_contracting_item_create_capability
ON public.contracting_items
FOR INSERT
TO compras_contracting_item_create_owner
WITH CHECK (
  retired_at IS NULL
  AND EXISTS (
    SELECT 1
    FROM public.contractings AS target
    WHERE target.id = contracting_items.contracting_id
      AND target.team_id = contracting_items.team_id
      AND target.archived_at IS NULL
      AND target.cancelled_at IS NULL
  )
  AND EXISTS (
    SELECT 1
    FROM public.memberships AS actor_membership
    WHERE actor_membership.team_id = contracting_items.team_id
      AND actor_membership.user_id = public.current_app_user_id()
      AND actor_membership.revoked_at IS NULL
  )
  AND 1 = (
    SELECT count(*)
    FROM public.memberships AS active_membership
    WHERE active_membership.team_id = contracting_items.team_id
      AND active_membership.revoked_at IS NULL
  )
  AND EXISTS (
    SELECT 1
    FROM public.contracting_item_ordinal_counters AS counter
    WHERE counter.team_id = contracting_items.team_id
      AND counter.contracting_id = contracting_items.contracting_id
      AND counter.last_ordinal = contracting_items.ordinal
  )
);

CREATE POLICY contracting_events_insert_contracting_item_create_capability
ON public.contracting_events
FOR INSERT
TO compras_contracting_item_create_owner
WITH CHECK (
  event_type = 'item_created'
  AND actor_membership_id IS NOT NULL
  AND item_id IS NOT NULL
  AND field_key IS NULL
  AND old_value IS NULL
  AND new_value IS NULL
  AND note IS NULL
  AND related_identifier_id IS NULL
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
    FROM public.contracting_items AS item
    WHERE item.id = contracting_events.item_id
      AND item.team_id = contracting_events.team_id
      AND item.contracting_id = contracting_events.contracting_id
  )
);

CREATE FUNCTION public.create_contracting_item(
  p_contracting_id uuid,
  p_description text,
  p_quantity numeric,
  p_unit text,
  p_catalog_code text,
  p_item_id uuid,
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
  revalidated_team_id uuid;
  actor_membership_id uuid;
  allocator_last_ordinal integer;
  persisted_max_ordinal integer;
  base_ordinal integer;
  next_ordinal integer;
  operation_at timestamptz;
BEGIN
  IF p_contracting_id IS NULL
     OR p_description IS NULL
     OR p_item_id IS NULL
     OR p_event_id IS NULL THEN
    RETURN 'denied';
  END IF;

  current_user_id := public.current_app_user_id();

  IF current_user_id IS NULL THEN
    RETURN 'denied';
  END IF;

  -- Candidate contracting UUID is only a selector. Generic SELECT RLS and the
  -- active-row predicate collapse cross-team/inexistent/inactive targets.
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

  -- Create the per-contracting allocator only for a currently authorized
  -- target. ON CONFLICT is not a retry mechanism; it only converges writers
  -- onto the same technical row before the row lock.
  INSERT INTO public.contracting_item_ordinal_counters (
    team_id,
    contracting_id,
    last_ordinal
  ) VALUES (
    target_team_id,
    p_contracting_id,
    NULL
  )
  ON CONFLICT (contracting_id) DO NOTHING;

  SELECT counter.last_ordinal
  INTO allocator_last_ordinal
  FROM public.contracting_item_ordinal_counters AS counter
  WHERE counter.team_id = target_team_id
    AND counter.contracting_id = p_contracting_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN 'denied';
  END IF;

  -- Revalidate identity, active parent and pilot guard after waiting on the
  -- allocator lock. No parent UPDATE privilege is needed or granted.
  current_user_id := public.current_app_user_id();

  IF current_user_id IS NULL THEN
    RETURN 'denied';
  END IF;

  SELECT target.team_id
  INTO revalidated_team_id
  FROM public.contractings AS target
  WHERE target.id = p_contracting_id
    AND target.archived_at IS NULL
    AND target.cancelled_at IS NULL;

  IF NOT FOUND OR revalidated_team_id IS DISTINCT FROM target_team_id THEN
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

  SELECT max(item.ordinal)
  INTO persisted_max_ordinal
  FROM public.contracting_items AS item
  WHERE item.team_id = target_team_id
    AND item.contracting_id = p_contracting_id;

  IF allocator_last_ordinal IS NULL AND persisted_max_ordinal IS NULL THEN
    base_ordinal := NULL;
  ELSIF allocator_last_ordinal IS NULL THEN
    base_ordinal := persisted_max_ordinal;
  ELSIF persisted_max_ordinal IS NULL THEN
    base_ordinal := allocator_last_ordinal;
  ELSIF allocator_last_ordinal >= persisted_max_ordinal THEN
    base_ordinal := allocator_last_ordinal;
  ELSE
    base_ordinal := persisted_max_ordinal;
  END IF;

  IF base_ordinal IS NULL THEN
    next_ordinal := 1;
  ELSE
    next_ordinal := base_ordinal + 1;
  END IF;

  operation_at := pg_catalog.clock_timestamp();

  UPDATE public.contracting_item_ordinal_counters
  SET last_ordinal = next_ordinal
  WHERE team_id = target_team_id
    AND contracting_id = p_contracting_id;

  INSERT INTO public.contracting_items (
    id,
    team_id,
    contracting_id,
    ordinal,
    description,
    quantity,
    unit,
    catalog_code,
    created_at,
    updated_at
  ) VALUES (
    p_item_id,
    target_team_id,
    p_contracting_id,
    next_ordinal,
    p_description,
    p_quantity,
    p_unit,
    p_catalog_code,
    operation_at,
    operation_at
  );

  INSERT INTO public.contracting_events (
    id,
    team_id,
    contracting_id,
    actor_membership_id,
    event_type,
    occurred_at,
    item_id,
    created_at
  ) VALUES (
    p_event_id,
    target_team_id,
    p_contracting_id,
    actor_membership_id,
    'item_created',
    operation_at,
    p_item_id,
    operation_at
  );

  RETURN 'created';
END;
$function$;

REVOKE ALL ON FUNCTION public.create_contracting_item(uuid, text, numeric, text, text, uuid, uuid)
  FROM PUBLIC;

-- Transfer only the primitive to the sealed owner. The temporary SET-capable
-- edge is removed before commit, preserving the ADR-005 lifecycle.
GRANT CREATE ON SCHEMA public TO compras_contracting_item_create_owner;

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
      'GRANT compras_contracting_item_create_owner TO %I WITH INHERIT FALSE, SET TRUE GRANTED BY %I',
      current_user,
      current_user
    );
  END IF;

  ALTER FUNCTION public.create_contracting_item(uuid, text, numeric, text, text, uuid, uuid)
    OWNER TO compras_contracting_item_create_owner;

  IF NOT COALESCE(migration_is_superuser, false) THEN
    EXECUTE format(
      'REVOKE compras_contracting_item_create_owner FROM %I GRANTED BY %I',
      current_user,
      current_user
    );
  END IF;
END;
$ownership$;

REVOKE CREATE ON SCHEMA public FROM compras_contracting_item_create_owner;

DO $postflight$
DECLARE
  capability_oid oid;
  migration_oid oid;
BEGIN
  SELECT r.oid
  INTO capability_oid
  FROM pg_catalog.pg_roles AS r
  WHERE r.rolname = 'compras_contracting_item_create_owner';

  SELECT r.oid
  INTO migration_oid
  FROM pg_catalog.pg_roles AS r
  WHERE r.rolname = current_user;

  IF capability_oid IS NULL OR migration_oid IS NULL THEN
    RAISE EXCEPTION 'cannot resolve contracting item create postflight principals';
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
    RAISE EXCEPTION 'contracting item create capability role is not sealed after ownership transfer';
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
    RAISE EXCEPTION 'contracting item create capability must not own protected base tables';
  END IF;

  IF pg_catalog.has_schema_privilege(
       'compras_contracting_item_create_owner',
       'public',
       'CREATE'
     ) THEN
    RAISE EXCEPTION 'contracting item create capability retained schema CREATE privilege';
  END IF;

  IF pg_catalog.has_any_column_privilege(
       'compras_contracting_item_create_owner',
       'public.contractings',
       'UPDATE'
     ) THEN
    RAISE EXCEPTION 'contracting item create capability has UPDATE on contractings';
  END IF;

  IF pg_catalog.has_any_column_privilege(
       'compras_contracting_item_create_owner',
       'public.contracting_items',
       'UPDATE'
     )
     OR pg_catalog.has_table_privilege(
       'compras_contracting_item_create_owner',
       'public.contracting_items',
       'DELETE'
     )
     OR pg_catalog.has_table_privilege(
       'compras_contracting_item_create_owner',
       'public.contracting_events',
       'UPDATE'
     )
     OR pg_catalog.has_table_privilege(
       'compras_contracting_item_create_owner',
       'public.contracting_events',
       'DELETE'
     ) THEN
    RAISE EXCEPTION 'contracting item create capability can mutate existing item/event state';
  END IF;

  IF NOT pg_catalog.has_column_privilege(
       'compras_contracting_item_create_owner',
       'public.contracting_item_ordinal_counters',
       'last_ordinal',
       'UPDATE'
     )
     OR pg_catalog.has_table_privilege(
       'compras_contracting_item_create_owner',
       'public.contracting_item_ordinal_counters',
       'DELETE'
     ) THEN
    RAISE EXCEPTION 'contracting item create allocator authority is not narrow';
  END IF;

  IF pg_catalog.has_function_privilege(
       'compras_contracting_item_create_owner',
       'public.mutate_contracting_next_action(uuid,text,text,uuid)',
       'EXECUTE'
     )
     OR pg_catalog.has_function_privilege(
       'compras_contracting_item_create_owner',
       'public.create_contracting_minimal(uuid,text,uuid)',
       'EXECUTE'
     )
     OR pg_catalog.has_function_privilege(
       'compras_contracting_item_create_owner',
       'public.mutate_contracting_object(uuid,text,text,uuid)',
       'EXECUTE'
     ) THEN
    RAISE EXCEPTION 'contracting item create capability inherited prior write authority';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_catalog.pg_proc AS procedure
    JOIN pg_catalog.pg_namespace AS namespace
      ON namespace.oid = procedure.pronamespace
    WHERE namespace.nspname = 'public'
      AND procedure.proname = 'create_contracting_item'
      AND procedure.proowner = capability_oid
      AND procedure.prosecdef
      AND pg_catalog.pg_get_function_identity_arguments(procedure.oid)
        = 'p_contracting_id uuid, p_description text, p_quantity numeric, p_unit text, p_catalog_code text, p_item_id uuid, p_event_id uuid'
      AND COALESCE(procedure.proconfig, ARRAY[]::text[])
        @> ARRAY['search_path=pg_catalog']
      AND position('EXECUTE ' IN upper(pg_catalog.pg_get_functiondef(procedure.oid))) = 0
  ) THEN
    RAISE EXCEPTION 'contracting item create primitive ownership/search_path/static SQL proof failed';
  END IF;
END;
$postflight$;

COMMIT;