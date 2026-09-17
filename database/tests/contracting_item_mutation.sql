\set ON_ERROR_STOP on

-- F38 item mutation proof. Every identity, UUID and value is synthetic.
CREATE SCHEMA test_support_f38;

CREATE FUNCTION test_support_f38.assert_text(
  query_text text,
  expected text,
  case_name text
)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
  actual text;
BEGIN
  EXECUTE query_text INTO actual;
  IF actual IS DISTINCT FROM expected THEN
    RAISE EXCEPTION '%: expected %, got %', case_name, expected, actual;
  END IF;
END;
$$;

CREATE FUNCTION test_support_f38.assert_count(
  query_text text,
  expected bigint,
  case_name text
)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
  actual bigint;
BEGIN
  EXECUTE query_text INTO actual;
  IF actual IS DISTINCT FROM expected THEN
    RAISE EXCEPTION '%: expected %, got %', case_name, expected, actual;
  END IF;
END;
$$;

CREATE FUNCTION test_support_f38.assert_event_failure_rolls_back(
  p_item_id uuid,
  p_duplicate_position integer,
  p_case_name text
)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
  duplicate_id uuid;
  description_id uuid := '38180000-0000-4000-8000-000000000101';
  quantity_id uuid := '38180000-0000-4000-8000-000000000102';
  unit_id uuid := '38180000-0000-4000-8000-000000000103';
  catalog_id uuid := '38180000-0000-4000-8000-000000000104';
  before_updated_at timestamptz;
  after_updated_at timestamptz;
  persisted_description text;
  persisted_quantity text;
  persisted_unit text;
  persisted_catalog text;
  event_count bigint;
BEGIN
  SELECT updated_at INTO before_updated_at
  FROM public.contracting_items
  WHERE id = p_item_id;

  IF p_duplicate_position = 1 THEN
    duplicate_id := '38170000-0000-4000-8000-000000000901';
    description_id := duplicate_id;
  ELSIF p_duplicate_position = 3 THEN
    duplicate_id := '38170000-0000-4000-8000-000000000903';
    unit_id := duplicate_id;
  ELSIF p_duplicate_position = 4 THEN
    duplicate_id := '38170000-0000-4000-8000-000000000904';
    catalog_id := duplicate_id;
  ELSE
    RAISE EXCEPTION 'unsupported duplicate position';
  END IF;

  BEGIN
    PERFORM public.mutate_contracting_item_fields(
      '38140000-0000-4000-8000-000000000010'::uuid,
      p_item_id,
      'DEMO rollback old', 10.5, 'u-old', 'c-old',
      'DEMO rollback new', 20.75, 'u-new', 'c-new',
      description_id, quantity_id, unit_id, catalog_id
    );
    RAISE EXCEPTION '%: expected duplicate event failure', p_case_name;
  EXCEPTION
    WHEN unique_violation THEN
      NULL;
  END;

  SELECT description, quantity::text, unit, catalog_code, updated_at
  INTO persisted_description, persisted_quantity, persisted_unit, persisted_catalog, after_updated_at
  FROM public.contracting_items
  WHERE id = p_item_id;

  IF persisted_description IS DISTINCT FROM 'DEMO rollback old'
     OR persisted_quantity IS DISTINCT FROM '10.5'
     OR persisted_unit IS DISTINCT FROM 'u-old'
     OR persisted_catalog IS DISTINCT FROM 'c-old'
     OR after_updated_at IS DISTINCT FROM before_updated_at THEN
    RAISE EXCEPTION '%: failed event left partial item state', p_case_name;
  END IF;

  SELECT count(*) INTO event_count
  FROM public.contracting_events
  WHERE item_id = p_item_id
    AND event_type = 'item_changed';

  IF event_count <> 0 THEN
    RAISE EXCEPTION '%: failed event left partial F38 audit rows', p_case_name;
  END IF;
END;
$$;

GRANT USAGE ON SCHEMA test_support_f38 TO compras_domain_runtime_f38_ci;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA test_support_f38 TO compras_domain_runtime_f38_ci;

INSERT INTO public.teams (id, name, created_at) VALUES
  ('38110000-0000-4000-8000-000000000001', 'DEMO-F38-Team-A-Target', '2026-01-01T00:00:00Z'),
  ('38110000-0000-4000-8000-000000000002', 'DEMO-F38-Team-B-Cross', '2026-01-01T00:00:00Z'),
  ('38110000-0000-4000-8000-000000000003', 'DEMO-F38-Team-C-Multi', '2026-01-01T00:00:00Z'),
  ('38110000-0000-4000-8000-000000000004', 'DEMO-F38-Team-D-Second-Team', '2026-01-01T00:00:00Z'),
  ('38110000-0000-4000-8000-000000000005', 'DEMO-F38-Team-E-Revoked', '2026-01-01T00:00:00Z'),
  ('38110000-0000-4000-8000-000000000006', 'DEMO-F38-Team-F-Disabled', '2026-01-01T00:00:00Z');

INSERT INTO public.app_users (
  id, auth_issuer, auth_subject, display_name, created_at, disabled_at
) VALUES
  ('38120000-0000-4000-8000-000000000001', 'urn:compras:better-auth:self-hosted:v1', 'DEMO-F38-A', 'DEMO F38 A', '2026-01-01T00:00:00Z', NULL),
  ('38120000-0000-4000-8000-000000000002', 'urn:compras:better-auth:self-hosted:v1', 'DEMO-F38-B', 'DEMO F38 B', '2026-01-01T00:00:00Z', NULL),
  ('38120000-0000-4000-8000-000000000003', 'urn:compras:better-auth:self-hosted:v1', 'DEMO-F38-C', 'DEMO F38 C', '2026-01-01T00:00:00Z', NULL),
  ('38120000-0000-4000-8000-000000000004', 'urn:compras:better-auth:self-hosted:v1', 'DEMO-F38-C-DISABLED-MEMBER', 'DEMO F38 C Disabled Member', '2026-01-01T00:00:00Z', '2026-01-02T00:00:00Z'),
  ('38120000-0000-4000-8000-000000000005', 'urn:compras:better-auth:self-hosted:v1', 'DEMO-F38-REVOKED', 'DEMO F38 Revoked', '2026-01-01T00:00:00Z', NULL),
  ('38120000-0000-4000-8000-000000000006', 'urn:compras:better-auth:self-hosted:v1', 'DEMO-F38-DISABLED', 'DEMO F38 Disabled', '2026-01-01T00:00:00Z', '2026-01-02T00:00:00Z');

INSERT INTO public.memberships (
  id, team_id, user_id, joined_at, revoked_at
) VALUES
  ('38130000-0000-4000-8000-000000000001', '38110000-0000-4000-8000-000000000001', '38120000-0000-4000-8000-000000000001', '2026-01-01T00:00:00Z', NULL),
  ('38130000-0000-4000-8000-000000000002', '38110000-0000-4000-8000-000000000004', '38120000-0000-4000-8000-000000000001', '2026-01-01T00:00:00Z', NULL),
  ('38130000-0000-4000-8000-000000000003', '38110000-0000-4000-8000-000000000002', '38120000-0000-4000-8000-000000000002', '2026-01-01T00:00:00Z', NULL),
  ('38130000-0000-4000-8000-000000000004', '38110000-0000-4000-8000-000000000003', '38120000-0000-4000-8000-000000000003', '2026-01-01T00:00:00Z', NULL),
  ('38130000-0000-4000-8000-000000000005', '38110000-0000-4000-8000-000000000003', '38120000-0000-4000-8000-000000000004', '2026-01-01T00:00:00Z', NULL),
  ('38130000-0000-4000-8000-000000000006', '38110000-0000-4000-8000-000000000005', '38120000-0000-4000-8000-000000000005', '2026-01-01T00:00:00Z', '2026-01-02T00:00:00Z'),
  ('38130000-0000-4000-8000-000000000007', '38110000-0000-4000-8000-000000000006', '38120000-0000-4000-8000-000000000006', '2026-01-01T00:00:00Z', NULL);

INSERT INTO public.contractings (
  id, team_id, object, created_at, updated_at, archived_at, cancelled_at
) VALUES
  ('38140000-0000-4000-8000-000000000001', '38110000-0000-4000-8000-000000000001', 'DEMO F38 target', '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z', NULL, NULL),
  ('38140000-0000-4000-8000-000000000002', '38110000-0000-4000-8000-000000000001', 'DEMO F38 same-team mismatch parent', '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z', NULL, NULL),
  ('38140000-0000-4000-8000-000000000003', '38110000-0000-4000-8000-000000000002', 'DEMO F38 cross', '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z', NULL, NULL),
  ('38140000-0000-4000-8000-000000000004', '38110000-0000-4000-8000-000000000003', 'DEMO F38 multi', '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z', NULL, NULL),
  ('38140000-0000-4000-8000-000000000005', '38110000-0000-4000-8000-000000000001', 'DEMO F38 archived', '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z', '2026-01-02T00:00:00Z', NULL),
  ('38140000-0000-4000-8000-000000000006', '38110000-0000-4000-8000-000000000001', 'DEMO F38 cancelled', '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z', NULL, '2026-01-02T00:00:00Z'),
  ('38140000-0000-4000-8000-000000000010', '38110000-0000-4000-8000-000000000001', 'DEMO F38 rollback', '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z', NULL, NULL),
  ('38140000-0000-4000-8000-000000000011', '38110000-0000-4000-8000-000000000006', 'DEMO F38 disabled', '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z', NULL, NULL),
  ('38140000-0000-4000-8000-000000000012', '38110000-0000-4000-8000-000000000005', 'DEMO F38 revoked', '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z', NULL, NULL);

INSERT INTO public.contracting_items (
  id, team_id, contracting_id, ordinal, description, quantity, unit,
  catalog_code, created_at, updated_at, retired_at
) VALUES
  ('38150000-0000-4000-8000-000000000001', '38110000-0000-4000-8000-000000000001', '38140000-0000-4000-8000-000000000001', 1, 'DEMO old', 1.2300, 'kg', 'CAT-A', '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z', NULL),
  ('38150000-0000-4000-8000-000000000002', '38110000-0000-4000-8000-000000000001', '38140000-0000-4000-8000-000000000001', 2, '  DEMO spaces  ', NULL, '', NULL, '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z', NULL),
  ('38150000-0000-4000-8000-000000000003', '38110000-0000-4000-8000-000000000002', '38140000-0000-4000-8000-000000000003', 1, 'DEMO cross item', 3, 'u', 'c', '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z', NULL),
  ('38150000-0000-4000-8000-000000000004', '38110000-0000-4000-8000-000000000003', '38140000-0000-4000-8000-000000000004', 1, 'DEMO multi item', 4, 'u', 'c', '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z', NULL),
  ('38150000-0000-4000-8000-000000000005', '38110000-0000-4000-8000-000000000001', '38140000-0000-4000-8000-000000000005', 1, 'DEMO archived item', 5, 'u', 'c', '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z', NULL),
  ('38150000-0000-4000-8000-000000000006', '38110000-0000-4000-8000-000000000001', '38140000-0000-4000-8000-000000000006', 1, 'DEMO cancelled item', 6, 'u', 'c', '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z', NULL),
  ('38150000-0000-4000-8000-000000000007', '38110000-0000-4000-8000-000000000001', '38140000-0000-4000-8000-000000000001', 7, 'DEMO retired item', 7, 'u', 'c', '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z', '2026-01-02T00:00:00Z'),
  ('38150000-0000-4000-8000-000000000010', '38110000-0000-4000-8000-000000000001', '38140000-0000-4000-8000-000000000010', 1, 'DEMO rollback old', 10.5, 'u-old', 'c-old', '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z', NULL),
  ('38150000-0000-4000-8000-000000000011', '38110000-0000-4000-8000-000000000006', '38140000-0000-4000-8000-000000000011', 1, 'DEMO disabled item', 11, 'u', 'c', '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z', NULL),
  ('38150000-0000-4000-8000-000000000012', '38110000-0000-4000-8000-000000000005', '38140000-0000-4000-8000-000000000012', 1, 'DEMO revoked item', 12, 'u', 'c', '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z', NULL);

-- Pre-existing synthetic event IDs used to force first/intermediate/last audit
-- failures. They are not item_changed events and remain invariant.
INSERT INTO public.contracting_events (
  id, team_id, contracting_id, actor_membership_id, event_type, occurred_at,
  field_key, item_id, created_at
) VALUES
  ('38170000-0000-4000-8000-000000000901', '38110000-0000-4000-8000-000000000001', '38140000-0000-4000-8000-000000000010', '38130000-0000-4000-8000-000000000001', 'DEMO-existing', '2026-01-01T00:00:00Z', NULL, '38150000-0000-4000-8000-000000000010', '2026-01-01T00:00:00Z'),
  ('38170000-0000-4000-8000-000000000903', '38110000-0000-4000-8000-000000000001', '38140000-0000-4000-8000-000000000010', '38130000-0000-4000-8000-000000000001', 'DEMO-existing', '2026-01-01T00:00:00Z', NULL, '38150000-0000-4000-8000-000000000010', '2026-01-01T00:00:00Z'),
  ('38170000-0000-4000-8000-000000000904', '38110000-0000-4000-8000-000000000001', '38140000-0000-4000-8000-000000000010', '38130000-0000-4000-8000-000000000001', 'DEMO-existing', '2026-01-01T00:00:00Z', NULL, '38150000-0000-4000-8000-000000000010', '2026-01-01T00:00:00Z');

-- Least privilege and authority isolation.
DO $structure$
DECLARE
  capability_oid oid;
  migrator_oid oid;
BEGIN
  SELECT oid INTO capability_oid FROM pg_catalog.pg_roles
  WHERE rolname = 'compras_contracting_item_mutation_owner';
  SELECT oid INTO migrator_oid FROM pg_catalog.pg_roles
  WHERE rolname = 'compras_f38_migrator_ci';

  IF capability_oid IS NULL OR migrator_oid IS NULL THEN
    RAISE EXCEPTION 'F38 structural roles are missing';
  END IF;

  IF EXISTS (
    SELECT 1 FROM pg_catalog.pg_roles
    WHERE oid = capability_oid
      AND (rolcanlogin OR rolsuper OR rolcreatedb OR rolcreaterole OR rolinherit
           OR rolreplication OR rolbypassrls OR rolconfig IS NOT NULL)
  ) THEN
    RAISE EXCEPTION 'F38 capability owner is privileged';
  END IF;

  IF EXISTS (
    SELECT 1 FROM pg_catalog.pg_auth_members
    WHERE member = capability_oid
       OR (roleid = capability_oid AND
           (member <> migrator_oid OR set_option OR inherit_option OR NOT admin_option))
  ) THEN
    RAISE EXCEPTION 'F38 capability owner has usable membership';
  END IF;

  IF NOT pg_catalog.has_function_privilege(
      'compras_domain_runtime_f38_ci',
      'public.mutate_contracting_item_fields(uuid,uuid,text,numeric,text,text,text,numeric,text,text,uuid,uuid,uuid,uuid)',
      'EXECUTE'
    ) THEN
    RAISE EXCEPTION 'F38 domain runtime is missing narrow EXECUTE';
  END IF;

  IF pg_catalog.has_any_column_privilege('compras_domain_runtime_f38_ci', 'public.contracting_items', 'UPDATE')
     OR pg_catalog.has_any_column_privilege('compras_domain_runtime_f38_ci', 'public.contracting_events', 'INSERT')
     OR pg_catalog.has_any_column_privilege('compras_domain_runtime_f38_ci', 'public.contractings', 'UPDATE') THEN
    RAISE EXCEPTION 'F38 domain runtime received direct DML';
  END IF;

  IF NOT pg_catalog.has_column_privilege('compras_contracting_item_mutation_owner', 'public.contracting_items', 'description', 'UPDATE')
     OR NOT pg_catalog.has_column_privilege('compras_contracting_item_mutation_owner', 'public.contracting_items', 'quantity', 'UPDATE')
     OR NOT pg_catalog.has_column_privilege('compras_contracting_item_mutation_owner', 'public.contracting_items', 'unit', 'UPDATE')
     OR NOT pg_catalog.has_column_privilege('compras_contracting_item_mutation_owner', 'public.contracting_items', 'catalog_code', 'UPDATE')
     OR NOT pg_catalog.has_column_privilege('compras_contracting_item_mutation_owner', 'public.contracting_items', 'updated_at', 'UPDATE') THEN
    RAISE EXCEPTION 'F38 capability missing approved item UPDATE columns';
  END IF;

  IF pg_catalog.has_column_privilege('compras_contracting_item_mutation_owner', 'public.contracting_items', 'ordinal', 'UPDATE')
     OR pg_catalog.has_column_privilege('compras_contracting_item_mutation_owner', 'public.contracting_items', 'retired_at', 'UPDATE')
     OR pg_catalog.has_table_privilege('compras_contracting_item_mutation_owner', 'public.contracting_items', 'INSERT')
     OR pg_catalog.has_table_privilege('compras_contracting_item_mutation_owner', 'public.contracting_items', 'DELETE')
     OR pg_catalog.has_any_column_privilege('compras_contracting_item_mutation_owner', 'public.contractings', 'UPDATE')
     OR pg_catalog.has_any_column_privilege('compras_contracting_item_mutation_owner', 'public.contracting_item_ordinal_counters', 'UPDATE') THEN
    RAISE EXCEPTION 'F38 capability has unrelated item/parent/allocator authority';
  END IF;

  IF pg_catalog.has_function_privilege('compras_next_action_mutation_owner', 'public.mutate_contracting_item_fields(uuid,uuid,text,numeric,text,text,text,numeric,text,text,uuid,uuid,uuid,uuid)', 'EXECUTE')
     OR pg_catalog.has_function_privilege('compras_contracting_create_owner', 'public.mutate_contracting_item_fields(uuid,uuid,text,numeric,text,text,text,numeric,text,text,uuid,uuid,uuid,uuid)', 'EXECUTE')
     OR pg_catalog.has_function_privilege('compras_contracting_object_mutation_owner', 'public.mutate_contracting_item_fields(uuid,uuid,text,numeric,text,text,text,numeric,text,text,uuid,uuid,uuid,uuid)', 'EXECUTE')
     OR pg_catalog.has_function_privilege('compras_contracting_item_create_owner', 'public.mutate_contracting_item_fields(uuid,uuid,text,numeric,text,text,text,numeric,text,text,uuid,uuid,uuid,uuid)', 'EXECUTE') THEN
    RAISE EXCEPTION 'prior write capability gained F38 EXECUTE';
  END IF;

  IF pg_catalog.has_function_privilege('compras_contracting_item_mutation_owner', 'public.mutate_contracting_next_action(uuid,text,text,uuid)', 'EXECUTE')
     OR pg_catalog.has_function_privilege('compras_contracting_item_mutation_owner', 'public.create_contracting_minimal(uuid,text,uuid)', 'EXECUTE')
     OR pg_catalog.has_function_privilege('compras_contracting_item_mutation_owner', 'public.mutate_contracting_object(uuid,text,text,uuid)', 'EXECUTE')
     OR pg_catalog.has_function_privilege('compras_contracting_item_mutation_owner', 'public.create_contracting_item(uuid,text,numeric,text,text,uuid,uuid)', 'EXECUTE') THEN
    RAISE EXCEPTION 'F38 capability inherited earlier write EXECUTE';
  END IF;
END;
$structure$;

SET SESSION AUTHORIZATION compras_domain_runtime_f38_ci;

-- Missing, malformed and unknown identity contexts fail closed.
BEGIN;
SELECT set_config('request.jwt.claims', '', true);
SELECT test_support_f38.assert_text(
  $$SELECT public.mutate_contracting_item_fields(
    '38140000-0000-4000-8000-000000000001', '38150000-0000-4000-8000-000000000001',
    'DEMO old', 1.2300, 'kg', 'CAT-A', 'x', 2, 'u', 'c',
    '38160000-0000-4000-8000-000000000001', '38160000-0000-4000-8000-000000000002',
    '38160000-0000-4000-8000-000000000003', '38160000-0000-4000-8000-000000000004')$$,
  'denied', 'missing claims deny'
);
COMMIT;

BEGIN;
SELECT set_config('request.jwt.claims', 'not-json', true);
SELECT test_support_f38.assert_text(
  $$SELECT public.mutate_contracting_item_fields(
    '38140000-0000-4000-8000-000000000001', '38150000-0000-4000-8000-000000000001',
    'DEMO old', 1.2300, 'kg', 'CAT-A', 'x', 2, 'u', 'c',
    '38160000-0000-4000-8000-000000000011', '38160000-0000-4000-8000-000000000012',
    '38160000-0000-4000-8000-000000000013', '38160000-0000-4000-8000-000000000014')$$,
  'denied', 'malformed claims deny'
);
COMMIT;

BEGIN;
SELECT set_config('request.jwt.claims', '{"iss":"urn:compras:better-auth:self-hosted:v1","sub":"DEMO-F38-UNKNOWN"}', true);
SELECT test_support_f38.assert_text(
  $$SELECT public.mutate_contracting_item_fields(
    '38140000-0000-4000-8000-000000000001', '38150000-0000-4000-8000-000000000001',
    'DEMO old', 1.2300, 'kg', 'CAT-A', 'x', 2, 'u', 'c',
    '38160000-0000-4000-8000-000000000021', '38160000-0000-4000-8000-000000000022',
    '38160000-0000-4000-8000-000000000023', '38160000-0000-4000-8000-000000000024')$$,
  'denied', 'unknown identity deny'
);
COMMIT;

-- Disabled user and revoked membership fail closed.
BEGIN;
SELECT set_config('request.jwt.claims', '{"iss":"urn:compras:better-auth:self-hosted:v1","sub":"DEMO-F38-DISABLED"}', true);
SELECT test_support_f38.assert_text(
  $$SELECT public.mutate_contracting_item_fields(
    '38140000-0000-4000-8000-000000000011', '38150000-0000-4000-8000-000000000011',
    'DEMO disabled item', 11, 'u', 'c', 'x', 2, 'u', 'c',
    '38160000-0000-4000-8000-000000000031', '38160000-0000-4000-8000-000000000032',
    '38160000-0000-4000-8000-000000000033', '38160000-0000-4000-8000-000000000034')$$,
  'denied', 'disabled app user deny'
);
COMMIT;

BEGIN;
SELECT set_config('request.jwt.claims', '{"iss":"urn:compras:better-auth:self-hosted:v1","sub":"DEMO-F38-REVOKED"}', true);
SELECT test_support_f38.assert_text(
  $$SELECT public.mutate_contracting_item_fields(
    '38140000-0000-4000-8000-000000000012', '38150000-0000-4000-8000-000000000012',
    'DEMO revoked item', 12, 'u', 'c', 'x', 2, 'u', 'c',
    '38160000-0000-4000-8000-000000000041', '38160000-0000-4000-8000-000000000042',
    '38160000-0000-4000-8000-000000000043', '38160000-0000-4000-8000-000000000044')$$,
  'denied', 'revoked membership deny'
);
COMMIT;

-- A has one active member in Team A plus another membership in Team D. Target
-- team authorization remains valid. All four fields change atomically.
BEGIN;
SELECT set_config('request.jwt.claims', '{"iss":"urn:compras:better-auth:self-hosted:v1","sub":"DEMO-F38-A"}', true);
SELECT test_support_f38.assert_text(
  $$SELECT public.mutate_contracting_item_fields(
    '38140000-0000-4000-8000-000000000001', '38150000-0000-4000-8000-000000000001',
    'DEMO old', 1.2300, 'kg', 'CAT-A',
    '  DEMO new  ', -2.500, '  unidade  ', '',
    '38160000-0000-4000-8000-000000000101', '38160000-0000-4000-8000-000000000102',
    '38160000-0000-4000-8000-000000000103', '38160000-0000-4000-8000-000000000104')$$,
  'updated', 'authorized four-field update'
);
SELECT test_support_f38.assert_text(
  $$SELECT description FROM public.contracting_items WHERE id='38150000-0000-4000-8000-000000000001'$$,
  '  DEMO new  ', 'description exact'
);
SELECT test_support_f38.assert_text(
  $$SELECT quantity::text FROM public.contracting_items WHERE id='38150000-0000-4000-8000-000000000001'$$,
  '-2.500', 'quantity persisted without JS roundtrip'
);
SELECT test_support_f38.assert_text(
  $$SELECT unit FROM public.contracting_items WHERE id='38150000-0000-4000-8000-000000000001'$$,
  '  unidade  ', 'unit exact'
);
SELECT test_support_f38.assert_text(
  $$SELECT catalog_code FROM public.contracting_items WHERE id='38150000-0000-4000-8000-000000000001'$$,
  '', 'catalog empty string exact'
);
SELECT test_support_f38.assert_count(
  $$SELECT count(*) FROM public.contracting_events
    WHERE item_id='38150000-0000-4000-8000-000000000001'
      AND event_type='item_changed'
      AND field_key IN ('description','quantity','unit','catalog_code')$$,
  4, 'four changed fields generate four events'
);
SELECT test_support_f38.assert_count(
  $$SELECT count(*) FROM public.contracting_events
    WHERE item_id='38150000-0000-4000-8000-000000000001'
      AND event_type='item_changed'
      AND team_id='38110000-0000-4000-8000-000000000001'
      AND contracting_id='38140000-0000-4000-8000-000000000001'
      AND actor_membership_id='38130000-0000-4000-8000-000000000001'
      AND note IS NULL AND related_identifier_id IS NULL$$,
  4, 'audit scope and actor are database-derived'
);
SELECT test_support_f38.assert_count(
  $$SELECT count(*) FROM public.contracting_events
    WHERE item_id='38150000-0000-4000-8000-000000000001'
      AND event_type='item_changed'
      AND (
        (field_key='description' AND old_value='DEMO old' AND new_value='  DEMO new  ')
        OR (field_key='quantity' AND old_value='1.2300' AND new_value='-2.500')
        OR (field_key='unit' AND old_value='kg' AND new_value='  unidade  ')
        OR (field_key='catalog_code' AND old_value='CAT-A' AND new_value='')
      )$$,
  4, 'audit old/new scalar values are exact'
);
SELECT test_support_f38.assert_count(
  $$SELECT count(*) FROM public.contracting_events AS event
    JOIN public.contracting_items AS item ON item.id=event.item_id
    WHERE item.id='38150000-0000-4000-8000-000000000001'
      AND event.event_type='item_changed'
      AND item.updated_at=event.occurred_at
      AND event.occurred_at=event.created_at$$,
  4, 'item and audit rows share operation_at'
);
COMMIT;

-- No-op does not touch timestamp/history. Stale expected wins before no-op and
-- an identical retry after success is therefore conflict.
BEGIN;
SELECT set_config('request.jwt.claims', '{"iss":"urn:compras:better-auth:self-hosted:v1","sub":"DEMO-F38-A"}', true);
SELECT test_support_f38.assert_text(
  $$SELECT public.mutate_contracting_item_fields(
    '38140000-0000-4000-8000-000000000001', '38150000-0000-4000-8000-000000000001',
    '  DEMO new  ', -2.500, '  unidade  ', '',
    '  DEMO new  ', -2.500, '  unidade  ', '',
    '38160000-0000-4000-8000-000000000111', '38160000-0000-4000-8000-000000000112',
    '38160000-0000-4000-8000-000000000113', '38160000-0000-4000-8000-000000000114')$$,
  'unchanged', 'exact no-op'
);
SELECT test_support_f38.assert_count(
  $$SELECT count(*) FROM public.contracting_events WHERE item_id='38150000-0000-4000-8000-000000000001' AND event_type='item_changed'$$,
  4, 'no-op adds no audit event'
);
SELECT test_support_f38.assert_text(
  $$SELECT public.mutate_contracting_item_fields(
    '38140000-0000-4000-8000-000000000001', '38150000-0000-4000-8000-000000000001',
    'DEMO old', 1.2300, 'kg', 'CAT-A',
    '  DEMO new  ', -2.500, '  unidade  ', '',
    '38160000-0000-4000-8000-000000000121', '38160000-0000-4000-8000-000000000122',
    '38160000-0000-4000-8000-000000000123', '38160000-0000-4000-8000-000000000124')$$,
  'conflict', 'stale retry conflicts before unchanged'
);
COMMIT;

-- Nullable/empty/spaces semantics and single-field audit.
BEGIN;
SELECT set_config('request.jwt.claims', '{"iss":"urn:compras:better-auth:self-hosted:v1","sub":"DEMO-F38-A"}', true);
SELECT test_support_f38.assert_text(
  $$SELECT public.mutate_contracting_item_fields(
    '38140000-0000-4000-8000-000000000001', '38150000-0000-4000-8000-000000000002',
    '  DEMO spaces  ', NULL, '', NULL,
    '   ', 0.000000000000000000123456789, '', NULL,
    '38160000-0000-4000-8000-000000000131', '38160000-0000-4000-8000-000000000132',
    '38160000-0000-4000-8000-000000000133', '38160000-0000-4000-8000-000000000134')$$,
  'updated', 'description plus high precision quantity update'
);
SELECT test_support_f38.assert_text(
  $$SELECT description FROM public.contracting_items WHERE id='38150000-0000-4000-8000-000000000002'$$,
  '   ', 'spaces-only description exact'
);
SELECT test_support_f38.assert_text(
  $$SELECT quantity::text FROM public.contracting_items WHERE id='38150000-0000-4000-8000-000000000002'$$,
  '0.000000000000000000123456789', 'high precision numeric exact in database text form'
);
SELECT test_support_f38.assert_count(
  $$SELECT count(*) FROM public.contracting_events WHERE item_id='38150000-0000-4000-8000-000000000002' AND event_type='item_changed'$$,
  2, 'two changed fields generate exactly two events'
);
COMMIT;

-- Protected target failures are indistinguishable and happen before conflict.
BEGIN;
SELECT set_config('request.jwt.claims', '{"iss":"urn:compras:better-auth:self-hosted:v1","sub":"DEMO-F38-A"}', true);
SELECT test_support_f38.assert_text(
  $$SELECT public.mutate_contracting_item_fields(
    '38140000-0000-4000-8000-000000000003', '38150000-0000-4000-8000-000000000003',
    'DEMO cross item', 3, 'u', 'c', 'x', 2, 'u', 'c',
    '38160000-0000-4000-8000-000000000201', '38160000-0000-4000-8000-000000000202',
    '38160000-0000-4000-8000-000000000203', '38160000-0000-4000-8000-000000000204')$$,
  'denied', 'cross-team deny'
);
SELECT test_support_f38.assert_text(
  $$SELECT public.mutate_contracting_item_fields(
    '38140000-0000-4000-8000-000000009999', '38150000-0000-4000-8000-000000009999',
    'x', NULL, NULL, NULL, 'x', NULL, NULL, NULL,
    '38160000-0000-4000-8000-000000000211', '38160000-0000-4000-8000-000000000212',
    '38160000-0000-4000-8000-000000000213', '38160000-0000-4000-8000-000000000214')$$,
  'denied', 'nonexistent deny'
);
SELECT test_support_f38.assert_text(
  $$SELECT public.mutate_contracting_item_fields(
    '38140000-0000-4000-8000-000000000002', '38150000-0000-4000-8000-000000000001',
    'WRONG', NULL, NULL, NULL, 'x', NULL, NULL, NULL,
    '38160000-0000-4000-8000-000000000221', '38160000-0000-4000-8000-000000000222',
    '38160000-0000-4000-8000-000000000223', '38160000-0000-4000-8000-000000000224')$$,
  'denied', 'same-team parent mismatch deny before conflict'
);
SELECT test_support_f38.assert_text(
  $$SELECT public.mutate_contracting_item_fields(
    '38140000-0000-4000-8000-000000000001', '38150000-0000-4000-8000-000000000007',
    'WRONG', NULL, NULL, NULL, 'x', NULL, NULL, NULL,
    '38160000-0000-4000-8000-000000000231', '38160000-0000-4000-8000-000000000232',
    '38160000-0000-4000-8000-000000000233', '38160000-0000-4000-8000-000000000234')$$,
  'denied', 'retired item deny before conflict'
);
SELECT test_support_f38.assert_text(
  $$SELECT public.mutate_contracting_item_fields(
    '38140000-0000-4000-8000-000000000005', '38150000-0000-4000-8000-000000000005',
    'WRONG', NULL, NULL, NULL, 'x', NULL, NULL, NULL,
    '38160000-0000-4000-8000-000000000241', '38160000-0000-4000-8000-000000000242',
    '38160000-0000-4000-8000-000000000243', '38160000-0000-4000-8000-000000000244')$$,
  'denied', 'archived parent deny'
);
SELECT test_support_f38.assert_text(
  $$SELECT public.mutate_contracting_item_fields(
    '38140000-0000-4000-8000-000000000006', '38150000-0000-4000-8000-000000000006',
    'WRONG', NULL, NULL, NULL, 'x', NULL, NULL, NULL,
    '38160000-0000-4000-8000-000000000251', '38160000-0000-4000-8000-000000000252',
    '38160000-0000-4000-8000-000000000253', '38160000-0000-4000-8000-000000000254')$$,
  'denied', 'cancelled parent deny'
);
COMMIT;

-- A second non-revoked membership in target team blocks even when that second
-- app_user is disabled.
BEGIN;
SELECT set_config('request.jwt.claims', '{"iss":"urn:compras:better-auth:self-hosted:v1","sub":"DEMO-F38-C"}', true);
SELECT test_support_f38.assert_text(
  $$SELECT public.mutate_contracting_item_fields(
    '38140000-0000-4000-8000-000000000004', '38150000-0000-4000-8000-000000000004',
    'DEMO multi item', 4, 'u', 'c', 'x', 5, 'u', 'c',
    '38160000-0000-4000-8000-000000000261', '38160000-0000-4000-8000-000000000262',
    '38160000-0000-4000-8000-000000000263', '38160000-0000-4000-8000-000000000264')$$,
  'denied', 'second non-revoked member deny including disabled app_user'
);
COMMIT;

-- First, intermediate and last audit failures each roll back item state,
-- timestamp and all earlier events from the same attempt.
BEGIN;
SELECT set_config('request.jwt.claims', '{"iss":"urn:compras:better-auth:self-hosted:v1","sub":"DEMO-F38-A"}', true);
SELECT test_support_f38.assert_event_failure_rolls_back('38150000-0000-4000-8000-000000000010', 1, 'first audit failure rollback');
SELECT test_support_f38.assert_event_failure_rolls_back('38150000-0000-4000-8000-000000000010', 3, 'intermediate audit failure rollback');
SELECT test_support_f38.assert_event_failure_rolls_back('38150000-0000-4000-8000-000000000010', 4, 'last audit failure rollback');
COMMIT;

RESET SESSION AUTHORIZATION;

-- Parent updated_at is never part of item mutation state.
SELECT test_support_f38.assert_text(
  $$SELECT updated_at::text FROM public.contractings WHERE id='38140000-0000-4000-8000-000000000001'$$,
  '2026-01-01 00:00:00+00', 'parent updated_at invariant'
);
