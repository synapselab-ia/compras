BEGIN;

-- F38 persistent contracting item mutation boundary. This capability owns only
-- the narrow SECURITY DEFINER primitive and never a protected base table.
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
  WHERE r.rolname = 'compras_contracting_item_mutation_owner';

  IF capability_oid IS NULL THEN
    EXECUTE $role$
      CREATE ROLE compras_contracting_item_mutation_owner
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
    WHERE r.rolname = 'compras_contracting_item_mutation_owner';
  END IF;

  IF capability_oid IS NULL THEN
    RAISE EXCEPTION 'contracting item mutation capability role could not be created';
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
    RAISE EXCEPTION 'contracting item mutation capability role has unsafe attributes or configuration';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM pg_catalog.pg_auth_members AS membership
    WHERE membership.member = capability_oid
  ) THEN
    RAISE EXCEPTION 'contracting item mutation capability role must not be a member of another role';
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
    RAISE EXCEPTION 'contracting item mutation capability role has unsafe grantees or usable membership';
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
    RAISE EXCEPTION 'migration principal cannot safely administer the contracting item mutation capability role';
  END IF;
END;
$migration$;

GRANT USAGE ON SCHEMA public TO compras_contracting_item_mutation_owner;

-- Identity and pilot guard inputs remain database-derived from trusted issuer
-- and subject carried by the server transaction context.
GRANT SELECT (id, auth_issuer, auth_subject, disabled_at)
  ON public.app_users TO compras_contracting_item_mutation_owner;
GRANT SELECT (id, team_id, user_id, revoked_at)
  ON public.memberships TO compras_contracting_item_mutation_owner;
GRANT EXECUTE ON FUNCTION public.current_auth_issuer()
  TO compras_contracting_item_mutation_owner;
GRANT EXECUTE ON FUNCTION public.current_auth_subject()
  TO compras_contracting_item_mutation_owner;
GRANT EXECUTE ON FUNCTION public.current_app_user_id()
  TO compras_contracting_item_mutation_owner;

-- Parent state is read-only. F38 has no UPDATE authority on contractings.
GRANT SELECT (id, team_id, archived_at, cancelled_at)
  ON public.contractings TO compras_contracting_item_mutation_owner;

-- The item itself is the only mutable domain row. Locking the row is justified
-- by the same five-column UPDATE authority required by the operation.
GRANT SELECT (
  id,
  team_id,
  contracting_id,
  description,
  quantity,
  unit,
  catalog_code,
  retired_at
) ON public.contracting_items TO compras_contracting_item_mutation_owner;
GRANT UPDATE (
  description,
  quantity,
  unit,
  catalog_code,
  updated_at
) ON public.contracting_items TO compras_contracting_item_mutation_owner;

-- Audit insertion is column-scoped. note and related_identifier_id remain NULL
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
  item_id,
  created_at
) ON public.contracting_events TO compras_contracting_item_mutation_owner;

-- The pilot guard counts every non-revoked membership in the target team,
-- including memberships whose app_user is disabled.
CREATE POLICY memberships_select_contracting_item_mutation_capability
ON public.memberships
FOR SELECT
TO compras_contracting_item_mutation_owner
USING (revoked_at IS NULL);

-- Generic read RLS from 0002 is permissive. Make this capability-specific
-- policy restrictive so an F38 item row must also be active, have an active
-- parent and satisfy the pilot-only target-team guard before it can be locked.
CREATE POLICY contracting_items_select_contracting_item_mutation_capability
ON public.contracting_items
AS RESTRICTIVE
FOR SELECT
TO compras_contracting_item_mutation_owner
USING (
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
);

CREATE POLICY contracting_items_update_contracting_item_mutation_capability
ON public.contracting_items
FOR UPDATE
TO compras_contracting_item_mutation_owner
USING (
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
)
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
);

CREATE POLICY contracting_events_insert_contracting_item_mutation_capability
ON public.contracting_events
FOR INSERT
TO compras_contracting_item_mutation_owner
WITH CHECK (
  event_type = 'item_changed'
  AND actor_membership_id IS NOT NULL
  AND item_id IS NOT NULL
  AND field_key IN ('description', 'quantity', 'unit', 'catalog_code')
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
      AND item.retired_at IS NULL
      AND (
        (contracting_events.field_key = 'description'
          AND item.description IS NOT DISTINCT FROM contracting_events.new_value)
        OR (contracting_events.field_key = 'quantity'
          AND item.quantity::text IS NOT DISTINCT FROM contracting_events.new_value)
        OR (contracting_events.field_key = 'unit'
          AND item.unit IS NOT DISTINCT FROM contracting_events.new_value)
        OR (contracting_events.field_key = 'catalog_code'
          AND item.catalog_code IS NOT DISTINCT FROM contracting_events.new_value)
      )
  )
);

CREATE FUNCTION public.mutate_contracting_item_fields(
  p_contracting_id uuid,
  p_item_id uuid,
  p_expected_description text,
  p_expected_quantity numeric,
  p_expected_unit text,
  p_expected_catalog_code text,
  p_new_description text,
  p_new_quantity numeric,
  p_new_unit text,
  p_new_catalog_code text,
  p_description_event_id uuid,
  p_quantity_event_id uuid,
  p_unit_event_id uuid,
  p_catalog_code_event_id uuid
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
  current_description text;
  current_quantity numeric;
  current_unit text;
  current_catalog_code text;
  revalidated_team_id uuid;
  operation_at timestamptz;
BEGIN
  IF p_contracting_id IS NULL
     OR p_item_id IS NULL
     OR p_expected_description IS NULL
     OR p_new_description IS NULL
     OR p_description_event_id IS NULL
     OR p_quantity_event_id IS NULL
     OR p_unit_event_id IS NULL
     OR p_catalog_code_event_id IS NULL THEN
    RETURN 'denied';
  END IF;

  current_user_id := public.current_app_user_id();

  IF current_user_id IS NULL THEN
    RETURN 'denied';
  END IF;

  -- Both IDs are candidate selectors only. RLS plus the explicit parent bind
  -- prevent an item from another contracting or team becoming authority.
  SELECT
    item.team_id,
    item.description,
    item.quantity,
    item.unit,
    item.catalog_code
  INTO
    target_team_id,
    current_description,
    current_quantity,
    current_unit,
    current_catalog_code
  FROM public.contracting_items AS item
  WHERE item.id = p_item_id
    AND item.contracting_id = p_contracting_id
    AND item.retired_at IS NULL
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN 'denied';
  END IF;

  -- Revalidate parent, identity and pilot guard after the item row lock. The
  -- UPDATE and event RLS policies remain the final enforcement layer.
  current_user_id := public.current_app_user_id();

  IF current_user_id IS NULL THEN
    RETURN 'denied';
  END IF;

  SELECT target.team_id
  INTO revalidated_team_id
  FROM public.contractings AS target
  WHERE target.id = p_contracting_id
    AND target.team_id = target_team_id
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

  -- Snapshot conflict is deliberately evaluated before no-op. A stale retry
  -- cannot be reported as unchanged just because new values match current.
  IF current_description IS DISTINCT FROM p_expected_description
     OR current_quantity IS DISTINCT FROM p_expected_quantity
     OR current_unit IS DISTINCT FROM p_expected_unit
     OR current_catalog_code IS DISTINCT FROM p_expected_catalog_code THEN
    RETURN 'conflict';
  END IF;

  IF current_description IS NOT DISTINCT FROM p_new_description
     AND current_quantity IS NOT DISTINCT FROM p_new_quantity
     AND current_unit IS NOT DISTINCT FROM p_new_unit
     AND current_catalog_code IS NOT DISTINCT FROM p_new_catalog_code THEN
    RETURN 'unchanged';
  END IF;

  operation_at := pg_catalog.clock_timestamp();

  UPDATE public.contracting_items
  SET description = p_new_description,
      quantity = p_new_quantity,
      unit = p_new_unit,
      catalog_code = p_new_catalog_code,
      updated_at = operation_at
  WHERE id = p_item_id
    AND team_id = target_team_id
    AND contracting_id = p_contracting_id
    AND retired_at IS NULL;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'authorized contracting item disappeared before update';
  END IF;

  IF current_description IS DISTINCT FROM p_new_description THEN
    INSERT INTO public.contracting_events (
      id, team_id, contracting_id, actor_membership_id, event_type,
      occurred_at, field_key, old_value, new_value, item_id, created_at
    ) VALUES (
      p_description_event_id, target_team_id, p_contracting_id,
      actor_membership_id, 'item_changed', operation_at, 'description',
      current_description, p_new_description, p_item_id, operation_at
    );
  END IF;

  IF current_quantity IS DISTINCT FROM p_new_quantity THEN
    INSERT INTO public.contracting_events (
      id, team_id, contracting_id, actor_membership_id, event_type,
      occurred_at, field_key, old_value, new_value, item_id, created_at
    ) VALUES (
      p_quantity_event_id, target_team_id, p_contracting_id,
      actor_membership_id, 'item_changed', operation_at, 'quantity',
      current_quantity::text, p_new_quantity::text, p_item_id, operation_at
    );
  END IF;

  IF current_unit IS DISTINCT FROM p_new_unit THEN
    INSERT INTO public.contracting_events (
      id, team_id, contracting_id, actor_membership_id, event_type,
      occurred_at, field_key, old_value, new_value, item_id, created_at
    ) VALUES (
      p_unit_event_id, target_team_id, p_contracting_id,
      actor_membership_id, 'item_changed', operation_at, 'unit',
      current_unit, p_new_unit, p_item_id, operation_at
    );
  END IF;

  IF current_catalog_code IS DISTINCT FROM p_new_catalog_code THEN
    INSERT INTO public.contracting_events (
      id, team_id, contracting_id, actor_membership_id, event_type,
      occurred_at, field_key, old_value, new_value, item_id, created_at
    ) VALUES (
      p_catalog_code_event_id, target_team_id, p_contracting_id,
      actor_membership_id, 'item_changed', operation_at, 'catalog_code',
      current_catalog_code, p_new_catalog_code, p_item_id, operation_at
    );
  END IF;

  RETURN 'updated';
END;
$function$;

REVOKE ALL ON FUNCTION public.mutate_contracting_item_fields(
  uuid, uuid, text, numeric, text, text, text, numeric, text, text,
  uuid, uuid, uuid, uuid
) FROM PUBLIC;

-- Transfer only the primitive to the sealed owner. CREATE and SET authority are
-- temporary migration edges and are removed before commit.
GRANT CREATE ON SCHEMA public TO compras_contracting_item_mutation_owner;

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
      'GRANT compras_contracting_item_mutation_owner TO %I WITH INHERIT FALSE, SET TRUE GRANTED BY %I',
      current_user,
      current_user
    );
  END IF;

  ALTER FUNCTION public.mutate_contracting_item_fields(
    uuid, uuid, text, numeric, text, text, text, numeric, text, text,
    uuid, uuid, uuid, uuid
  ) OWNER TO compras_contracting_item_mutation_owner;

  IF NOT COALESCE(migration_is_superuser, false) THEN
    EXECUTE format(
      'REVOKE compras_contracting_item_mutation_owner FROM %I GRANTED BY %I',
      current_user,
      current_user
    );
  END IF;
END;
$ownership$;

REVOKE CREATE ON SCHEMA public FROM compras_contracting_item_mutation_owner;

DO $postflight$
DECLARE
  capability_oid oid;
  migration_oid oid;
BEGIN
  SELECT r.oid
  INTO capability_oid
  FROM pg_catalog.pg_roles AS r
  WHERE r.rolname = 'compras_contracting_item_mutation_owner';

  SELECT r.oid
  INTO migration_oid
  FROM pg_catalog.pg_roles AS r
  WHERE r.rolname = current_user;

  IF capability_oid IS NULL OR migration_oid IS NULL THEN
    RAISE EXCEPTION 'cannot resolve contracting item mutation postflight principals';
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
    RAISE EXCEPTION 'contracting item mutation capability role is not sealed after ownership transfer';
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
    RAISE EXCEPTION 'contracting item mutation capability must not own protected base tables';
  END IF;

  IF pg_catalog.has_schema_privilege(
       'compras_contracting_item_mutation_owner', 'public', 'CREATE'
     ) THEN
    RAISE EXCEPTION 'contracting item mutation capability retained schema CREATE privilege';
  END IF;

  IF NOT pg_catalog.has_column_privilege(
       'compras_contracting_item_mutation_owner', 'public.contracting_items',
       'description', 'UPDATE'
     )
     OR NOT pg_catalog.has_column_privilege(
       'compras_contracting_item_mutation_owner', 'public.contracting_items',
       'quantity', 'UPDATE'
     )
     OR NOT pg_catalog.has_column_privilege(
       'compras_contracting_item_mutation_owner', 'public.contracting_items',
       'unit', 'UPDATE'
     )
     OR NOT pg_catalog.has_column_privilege(
       'compras_contracting_item_mutation_owner', 'public.contracting_items',
       'catalog_code', 'UPDATE'
     )
     OR NOT pg_catalog.has_column_privilege(
       'compras_contracting_item_mutation_owner', 'public.contracting_items',
       'updated_at', 'UPDATE'
     ) THEN
    RAISE EXCEPTION 'contracting item mutation capability is missing narrow update privileges';
  END IF;

  IF pg_catalog.has_column_privilege('compras_contracting_item_mutation_owner', 'public.contracting_items', 'id', 'UPDATE')
     OR pg_catalog.has_column_privilege('compras_contracting_item_mutation_owner', 'public.contracting_items', 'team_id', 'UPDATE')
     OR pg_catalog.has_column_privilege('compras_contracting_item_mutation_owner', 'public.contracting_items', 'contracting_id', 'UPDATE')
     OR pg_catalog.has_column_privilege('compras_contracting_item_mutation_owner', 'public.contracting_items', 'ordinal', 'UPDATE')
     OR pg_catalog.has_column_privilege('compras_contracting_item_mutation_owner', 'public.contracting_items', 'created_at', 'UPDATE')
     OR pg_catalog.has_column_privilege('compras_contracting_item_mutation_owner', 'public.contracting_items', 'retired_at', 'UPDATE') THEN
    RAISE EXCEPTION 'contracting item mutation capability can update protected item columns';
  END IF;

  IF pg_catalog.has_table_privilege('compras_contracting_item_mutation_owner', 'public.contracting_items', 'INSERT')
     OR pg_catalog.has_table_privilege('compras_contracting_item_mutation_owner', 'public.contracting_items', 'DELETE')
     OR pg_catalog.has_any_column_privilege('compras_contracting_item_mutation_owner', 'public.contractings', 'UPDATE')
     OR pg_catalog.has_any_column_privilege('compras_contracting_item_mutation_owner', 'public.contracting_item_ordinal_counters', 'SELECT')
     OR pg_catalog.has_any_column_privilege('compras_contracting_item_mutation_owner', 'public.contracting_item_ordinal_counters', 'INSERT')
     OR pg_catalog.has_any_column_privilege('compras_contracting_item_mutation_owner', 'public.contracting_item_ordinal_counters', 'UPDATE')
     OR pg_catalog.has_table_privilege('compras_contracting_item_mutation_owner', 'public.contracting_item_ordinal_counters', 'DELETE') THEN
    RAISE EXCEPTION 'contracting item mutation capability has unrelated item/parent/allocator authority';
  END IF;

  IF pg_catalog.has_table_privilege('compras_contracting_item_mutation_owner', 'public.contracting_events', 'UPDATE')
     OR pg_catalog.has_table_privilege('compras_contracting_item_mutation_owner', 'public.contracting_events', 'DELETE') THEN
    RAISE EXCEPTION 'contracting item mutation capability can mutate existing events';
  END IF;

  IF pg_catalog.has_function_privilege(
       'compras_contracting_item_mutation_owner',
       'public.mutate_contracting_next_action(uuid,text,text,uuid)', 'EXECUTE'
     )
     OR pg_catalog.has_function_privilege(
       'compras_contracting_item_mutation_owner',
       'public.create_contracting_minimal(uuid,text,uuid)', 'EXECUTE'
     )
     OR pg_catalog.has_function_privilege(
       'compras_contracting_item_mutation_owner',
       'public.mutate_contracting_object(uuid,text,text,uuid)', 'EXECUTE'
     )
     OR pg_catalog.has_function_privilege(
       'compras_contracting_item_mutation_owner',
       'public.create_contracting_item(uuid,text,numeric,text,text,uuid,uuid)', 'EXECUTE'
     ) THEN
    RAISE EXCEPTION 'contracting item mutation capability inherited prior write authority';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_catalog.pg_proc AS procedure
    JOIN pg_catalog.pg_namespace AS namespace
      ON namespace.oid = procedure.pronamespace
    WHERE namespace.nspname = 'public'
      AND procedure.proname = 'mutate_contracting_item_fields'
      AND procedure.proowner = capability_oid
      AND procedure.prosecdef
      AND pg_catalog.pg_get_function_identity_arguments(procedure.oid)
        = 'p_contracting_id uuid, p_item_id uuid, p_expected_description text, p_expected_quantity numeric, p_expected_unit text, p_expected_catalog_code text, p_new_description text, p_new_quantity numeric, p_new_unit text, p_new_catalog_code text, p_description_event_id uuid, p_quantity_event_id uuid, p_unit_event_id uuid, p_catalog_code_event_id uuid'
      AND COALESCE(procedure.proconfig, ARRAY[]::text[])
        @> ARRAY['search_path=pg_catalog']
      AND position('EXECUTE ' IN upper(pg_catalog.pg_get_functiondef(procedure.oid))) = 0
  ) THEN
    RAISE EXCEPTION 'contracting item mutation primitive ownership/search_path/static SQL proof failed';
  END IF;
END;
$postflight$;

COMMIT;
