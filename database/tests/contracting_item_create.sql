\set ON_ERROR_STOP on

-- F35 contracting item create proof. All identities, UUIDs and values are
-- synthetic and safe for the public repository.
CREATE SCHEMA test_support_f35;

CREATE FUNCTION test_support_f35.assert_text(
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

CREATE FUNCTION test_support_f35.assert_count(
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

CREATE FUNCTION test_support_f35.assert_true(
  query_text text,
  case_name text
)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
  actual boolean;
BEGIN
  EXECUTE query_text INTO actual;
  IF actual IS DISTINCT FROM true THEN
    RAISE EXCEPTION '%: expected true, got %', case_name, actual;
  END IF;
END;
$$;

GRANT USAGE ON SCHEMA test_support_f35 TO compras_domain_runtime_f35_ci;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA test_support_f35 TO compras_domain_runtime_f35_ci;

INSERT INTO public.teams (id, name, created_at) VALUES
  ('35010000-0000-4000-8000-000000000001', 'DEMO-F35-Team-A-Target', '2026-01-01T00:00:00Z'),
  ('35010000-0000-4000-8000-000000000002', 'DEMO-F35-Team-B-Cross', '2026-01-01T00:00:00Z'),
  ('35010000-0000-4000-8000-000000000003', 'DEMO-F35-Team-C-Multi', '2026-01-01T00:00:00Z'),
  ('35010000-0000-4000-8000-000000000004', 'DEMO-F35-Team-D-Disabled', '2026-01-01T00:00:00Z'),
  ('35010000-0000-4000-8000-000000000005', 'DEMO-F35-Team-E-Revoked', '2026-01-01T00:00:00Z'),
  ('35010000-0000-4000-8000-000000000006', 'DEMO-F35-Team-F-No-Membership', '2026-01-01T00:00:00Z'),
  ('35010000-0000-4000-8000-000000000007', 'DEMO-F35-Team-G-A-Second-Team', '2026-01-01T00:00:00Z');

INSERT INTO public.app_users (
  id, auth_issuer, auth_subject, display_name, created_at, disabled_at
) VALUES
  ('35020000-0000-4000-8000-000000000001', 'urn:compras:better-auth:self-hosted:v1', 'DEMO-F35-A', 'DEMO F35 A', '2026-01-01T00:00:00Z', NULL),
  ('35020000-0000-4000-8000-000000000002', 'urn:compras:better-auth:self-hosted:v1', 'DEMO-F35-B', 'DEMO F35 B', '2026-01-01T00:00:00Z', NULL),
  ('35020000-0000-4000-8000-000000000003', 'urn:compras:better-auth:self-hosted:v1', 'DEMO-F35-C', 'DEMO F35 C', '2026-01-01T00:00:00Z', NULL),
  ('35020000-0000-4000-8000-000000000004', 'urn:compras:better-auth:self-hosted:v1', 'DEMO-F35-C-DISABLED-MEMBER', 'DEMO F35 C Disabled Member', '2026-01-01T00:00:00Z', '2026-01-02T00:00:00Z'),
  ('35020000-0000-4000-8000-000000000005', 'urn:compras:better-auth:self-hosted:v1', 'DEMO-F35-D-DISABLED', 'DEMO F35 D Disabled', '2026-01-01T00:00:00Z', '2026-01-02T00:00:00Z'),
  ('35020000-0000-4000-8000-000000000006', 'urn:compras:better-auth:self-hosted:v1', 'DEMO-F35-E-REVOKED', 'DEMO F35 E Revoked', '2026-01-01T00:00:00Z', NULL),
  ('35020000-0000-4000-8000-000000000007', 'urn:compras:better-auth:self-hosted:v1', 'DEMO-F35-F-NO-MEMBERSHIP', 'DEMO F35 F No Membership', '2026-01-01T00:00:00Z', NULL);

INSERT INTO public.memberships (
  id, team_id, user_id, joined_at, revoked_at
) VALUES
  ('35030000-0000-4000-8000-000000000001', '35010000-0000-4000-8000-000000000001', '35020000-0000-4000-8000-000000000001', '2026-01-01T00:00:00Z', NULL),
  ('35030000-0000-4000-8000-000000000002', '35010000-0000-4000-8000-000000000007', '35020000-0000-4000-8000-000000000001', '2026-01-01T00:00:00Z', NULL),
  ('35030000-0000-4000-8000-000000000003', '35010000-0000-4000-8000-000000000002', '35020000-0000-4000-8000-000000000002', '2026-01-01T00:00:00Z', NULL),
  ('35030000-0000-4000-8000-000000000004', '35010000-0000-4000-8000-000000000003', '35020000-0000-4000-8000-000000000003', '2026-01-01T00:00:00Z', NULL),
  ('35030000-0000-4000-8000-000000000005', '35010000-0000-4000-8000-000000000003', '35020000-0000-4000-8000-000000000004', '2026-01-01T00:00:00Z', NULL),
  ('35030000-0000-4000-8000-000000000006', '35010000-0000-4000-8000-000000000004', '35020000-0000-4000-8000-000000000005', '2026-01-01T00:00:00Z', NULL),
  ('35030000-0000-4000-8000-000000000007', '35010000-0000-4000-8000-000000000005', '35020000-0000-4000-8000-000000000006', '2026-01-01T00:00:00Z', '2026-01-02T00:00:00Z');

INSERT INTO public.contractings (
  id, team_id, object, created_at, updated_at, archived_at, cancelled_at
) VALUES
  ('35040000-0000-4000-8000-000000000001', '35010000-0000-4000-8000-000000000001', 'DEMO F35 target one', '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z', NULL, NULL),
  ('35040000-0000-4000-8000-000000000002', '35010000-0000-4000-8000-000000000001', 'DEMO F35 target preexisting', '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z', NULL, NULL),
  ('35040000-0000-4000-8000-000000000003', '35010000-0000-4000-8000-000000000002', 'DEMO F35 cross', '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z', NULL, NULL),
  ('35040000-0000-4000-8000-000000000004', '35010000-0000-4000-8000-000000000003', 'DEMO F35 multi', '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z', NULL, NULL),
  ('35040000-0000-4000-8000-000000000005', '35010000-0000-4000-8000-000000000004', 'DEMO F35 disabled', '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z', NULL, NULL),
  ('35040000-0000-4000-8000-000000000006', '35010000-0000-4000-8000-000000000005', 'DEMO F35 revoked', '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z', NULL, NULL),
  ('35040000-0000-4000-8000-000000000007', '35010000-0000-4000-8000-000000000006', 'DEMO F35 no membership', '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z', NULL, NULL),
  ('35040000-0000-4000-8000-000000000008', '35010000-0000-4000-8000-000000000001', 'DEMO F35 archived', '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z', '2026-01-02T00:00:00Z', NULL),
  ('35040000-0000-4000-8000-000000000009', '35010000-0000-4000-8000-000000000001', 'DEMO F35 cancelled', '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z', NULL, '2026-01-02T00:00:00Z');

-- Preexisting ordinals include a gap and a retired maximum. A fresh allocator
-- must reconcile against 7 and allocate 8 without reusing 2/4/5/6.
INSERT INTO public.contracting_items (
  id, team_id, contracting_id, ordinal, description, quantity, unit,
  catalog_code, created_at, updated_at, retired_at
) VALUES
  ('35060000-0000-4000-8000-000000000201', '35010000-0000-4000-8000-000000000001', '35040000-0000-4000-8000-000000000002', 1, 'DEMO preexisting 1', NULL, NULL, NULL, '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z', NULL),
  ('35060000-0000-4000-8000-000000000203', '35010000-0000-4000-8000-000000000001', '35040000-0000-4000-8000-000000000002', 3, 'DEMO preexisting 3', NULL, NULL, NULL, '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z', NULL),
  ('35060000-0000-4000-8000-000000000207', '35010000-0000-4000-8000-000000000001', '35040000-0000-4000-8000-000000000002', 7, 'DEMO retired max', NULL, NULL, NULL, '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z', '2026-01-02T00:00:00Z');

-- Structural, least-privilege and authority-isolation proof.
DO $structure$
DECLARE
  capability_oid oid;
  migrator_oid oid;
  forced_rls_count bigint;
BEGIN
  SELECT oid INTO capability_oid
  FROM pg_catalog.pg_roles
  WHERE rolname = 'compras_contracting_item_create_owner';

  SELECT oid INTO migrator_oid
  FROM pg_catalog.pg_roles
  WHERE rolname = 'compras_f35_migrator_ci';

  IF capability_oid IS NULL OR migrator_oid IS NULL THEN
    RAISE EXCEPTION 'F35 structural roles are missing';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM pg_catalog.pg_roles
    WHERE oid = capability_oid
      AND (
        rolcanlogin OR rolsuper OR rolcreatedb OR rolcreaterole OR rolinherit
        OR rolreplication OR rolbypassrls OR rolconfig IS NOT NULL
      )
  ) THEN
    RAISE EXCEPTION 'F35 capability owner is privileged';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM pg_catalog.pg_auth_members
    WHERE member = capability_oid
       OR (
         roleid = capability_oid
         AND (
           member <> migrator_oid OR set_option OR inherit_option OR NOT admin_option
         )
       )
  ) THEN
    RAISE EXCEPTION 'F35 capability owner has usable membership';
  END IF;

  IF pg_catalog.has_any_column_privilege(
       'compras_contracting_item_create_owner', 'public.contractings', 'UPDATE'
     ) THEN
    RAISE EXCEPTION 'F35 capability can update contractings';
  END IF;

  IF pg_catalog.has_any_column_privilege(
       'compras_contracting_item_create_owner', 'public.contracting_items', 'UPDATE'
     )
     OR pg_catalog.has_table_privilege(
       'compras_contracting_item_create_owner', 'public.contracting_items', 'DELETE'
     )
     OR pg_catalog.has_table_privilege(
       'compras_contracting_item_create_owner', 'public.contracting_events', 'UPDATE'
     )
     OR pg_catalog.has_table_privilege(
       'compras_contracting_item_create_owner', 'public.contracting_events', 'DELETE'
     ) THEN
    RAISE EXCEPTION 'F35 capability can mutate existing item/event rows';
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
    RAISE EXCEPTION 'F35 allocator privileges are not narrow';
  END IF;

  IF pg_catalog.has_any_column_privilege(
       'compras_domain_runtime_f35_ci', 'public.contractings', 'UPDATE'
     )
     OR pg_catalog.has_any_column_privilege(
       'compras_domain_runtime_f35_ci', 'public.contracting_items', 'INSERT'
     )
     OR pg_catalog.has_any_column_privilege(
       'compras_domain_runtime_f35_ci', 'public.contracting_items', 'UPDATE'
     )
     OR pg_catalog.has_any_column_privilege(
       'compras_domain_runtime_f35_ci', 'public.contracting_events', 'INSERT'
     )
     OR pg_catalog.has_any_column_privilege(
       'compras_domain_runtime_f35_ci', 'public.contracting_item_ordinal_counters', 'INSERT'
     )
     OR pg_catalog.has_any_column_privilege(
       'compras_domain_runtime_f35_ci', 'public.contracting_item_ordinal_counters', 'UPDATE'
     ) THEN
    RAISE EXCEPTION 'F35 runtime received direct DML';
  END IF;

  IF NOT pg_catalog.has_function_privilege(
    'compras_domain_runtime_f35_ci',
    'public.create_contracting_item(uuid,text,numeric,text,text,uuid,uuid)',
    'EXECUTE'
  ) THEN
    RAISE EXCEPTION 'F35 runtime is missing narrow EXECUTE';
  END IF;

  IF pg_catalog.has_function_privilege(
       'compras_contracting_item_create_owner',
       'public.mutate_contracting_next_action(uuid,text,text,uuid)', 'EXECUTE'
     )
     OR pg_catalog.has_function_privilege(
       'compras_contracting_item_create_owner',
       'public.create_contracting_minimal(uuid,text,uuid)', 'EXECUTE'
     )
     OR pg_catalog.has_function_privilege(
       'compras_contracting_item_create_owner',
       'public.mutate_contracting_object(uuid,text,text,uuid)', 'EXECUTE'
     ) THEN
    RAISE EXCEPTION 'F35 capability inherited prior write authority';
  END IF;

  IF pg_catalog.has_function_privilege(
       'compras_next_action_mutation_owner',
       'public.create_contracting_item(uuid,text,numeric,text,text,uuid,uuid)', 'EXECUTE'
     )
     OR pg_catalog.has_function_privilege(
       'compras_contracting_create_owner',
       'public.create_contracting_item(uuid,text,numeric,text,text,uuid,uuid)', 'EXECUTE'
     )
     OR pg_catalog.has_function_privilege(
       'compras_contracting_object_mutation_owner',
       'public.create_contracting_item(uuid,text,numeric,text,text,uuid,uuid)', 'EXECUTE'
     ) THEN
    RAISE EXCEPTION 'F26/F29/F32 gained F35 authority';
  END IF;

  SELECT count(*) INTO forced_rls_count
  FROM pg_catalog.pg_class AS relation
  WHERE relation.oid IN (
    'public.contracting_items'::regclass,
    'public.contracting_events'::regclass,
    'public.contracting_item_ordinal_counters'::regclass
  )
    AND relation.relrowsecurity
    AND relation.relforcerowsecurity;

  IF forced_rls_count <> 3 THEN
    RAISE EXCEPTION 'F35 protected tables lost enabled/forced RLS';
  END IF;
END;
$structure$;

SET SESSION AUTHORIZATION compras_domain_runtime_f35_ci;

-- Missing/malformed/unknown context fails closed before allocator creation.
BEGIN;
SELECT set_config('request.jwt.claims', '', true);
SELECT test_support_f35.assert_text(
  $$SELECT public.create_contracting_item(
      '35040000-0000-4000-8000-000000000001'::uuid,
      'DEMO missing claims', NULL, NULL, NULL,
      '35060000-0000-4000-8000-000000000001'::uuid,
      '35070000-0000-4000-8000-000000000001'::uuid
    )$$,
  'denied', 'missing claims deny'
);
COMMIT;

BEGIN;
SELECT set_config('request.jwt.claims', 'not-json', true);
SELECT test_support_f35.assert_text(
  $$SELECT public.create_contracting_item(
      '35040000-0000-4000-8000-000000000001'::uuid,
      'DEMO malformed claims', NULL, NULL, NULL,
      '35060000-0000-4000-8000-000000000002'::uuid,
      '35070000-0000-4000-8000-000000000002'::uuid
    )$$,
  'denied', 'malformed claims deny'
);
COMMIT;

BEGIN;
SELECT set_config(
  'request.jwt.claims',
  '{"iss":"urn:compras:better-auth:self-hosted:v1","sub":"DEMO-F35-UNKNOWN"}', true
);
SELECT test_support_f35.assert_text(
  $$SELECT public.create_contracting_item(
      '35040000-0000-4000-8000-000000000001'::uuid,
      'DEMO unknown', NULL, NULL, NULL,
      '35060000-0000-4000-8000-000000000003'::uuid,
      '35070000-0000-4000-8000-000000000003'::uuid
    )$$,
  'denied', 'unknown identity deny'
);
COMMIT;

-- Disabled, revoked, no membership and second non-revoked member deny.
BEGIN;
SELECT set_config(
  'request.jwt.claims',
  '{"iss":"urn:compras:better-auth:self-hosted:v1","sub":"DEMO-F35-D-DISABLED"}', true
);
SELECT test_support_f35.assert_text(
  $$SELECT public.create_contracting_item(
      '35040000-0000-4000-8000-000000000005'::uuid,
      'DEMO disabled', NULL, NULL, NULL,
      '35060000-0000-4000-8000-000000000004'::uuid,
      '35070000-0000-4000-8000-000000000004'::uuid
    )$$,
  'denied', 'disabled user deny'
);
COMMIT;

BEGIN;
SELECT set_config(
  'request.jwt.claims',
  '{"iss":"urn:compras:better-auth:self-hosted:v1","sub":"DEMO-F35-E-REVOKED"}', true
);
SELECT test_support_f35.assert_text(
  $$SELECT public.create_contracting_item(
      '35040000-0000-4000-8000-000000000006'::uuid,
      'DEMO revoked', NULL, NULL, NULL,
      '35060000-0000-4000-8000-000000000005'::uuid,
      '35070000-0000-4000-8000-000000000005'::uuid
    )$$,
  'denied', 'revoked membership deny'
);
COMMIT;

BEGIN;
SELECT set_config(
  'request.jwt.claims',
  '{"iss":"urn:compras:better-auth:self-hosted:v1","sub":"DEMO-F35-F-NO-MEMBERSHIP"}', true
);
SELECT test_support_f35.assert_text(
  $$SELECT public.create_contracting_item(
      '35040000-0000-4000-8000-000000000007'::uuid,
      'DEMO no membership', NULL, NULL, NULL,
      '35060000-0000-4000-8000-000000000006'::uuid,
      '35070000-0000-4000-8000-000000000006'::uuid
    )$$,
  'denied', 'no membership deny'
);
COMMIT;

BEGIN;
SELECT set_config(
  'request.jwt.claims',
  '{"iss":"urn:compras:better-auth:self-hosted:v1","sub":"DEMO-F35-C"}', true
);
SELECT test_support_f35.assert_text(
  $$SELECT public.create_contracting_item(
      '35040000-0000-4000-8000-000000000004'::uuid,
      'DEMO multi', NULL, NULL, NULL,
      '35060000-0000-4000-8000-000000000007'::uuid,
      '35070000-0000-4000-8000-000000000007'::uuid
    )$$,
  'denied', 'second target-team member including disabled app_user denies'
);
COMMIT;

-- Authorized A also belongs to Team G. The target-team guard still permits A.
BEGIN;
SELECT set_config(
  'request.jwt.claims',
  '{"iss":"urn:compras:better-auth:self-hosted:v1","sub":"DEMO-F35-A"}', true
);
SELECT test_support_f35.assert_text(
  $$SELECT public.create_contracting_item(
      '35040000-0000-4000-8000-000000000001'::uuid,
      '  DEMO exact description  ',
      0.000000000000000000123456789::numeric,
      '   ', '',
      '35060000-0000-4000-8000-000000000101'::uuid,
      '35070000-0000-4000-8000-000000000101'::uuid
    )$$,
  'created', 'authorized create despite second-team membership'
);
SELECT test_support_f35.assert_text(
  $$SELECT ordinal::text FROM public.contracting_items
    WHERE id = '35060000-0000-4000-8000-000000000101'::uuid$$,
  '1', 'first ordinal is one'
);
SELECT test_support_f35.assert_text(
  $$SELECT description FROM public.contracting_items
    WHERE id = '35060000-0000-4000-8000-000000000101'::uuid$$,
  '  DEMO exact description  ', 'description preserved exactly'
);
SELECT test_support_f35.assert_text(
  $$SELECT unit FROM public.contracting_items
    WHERE id = '35060000-0000-4000-8000-000000000101'::uuid$$,
  '   ', 'spaces-only unit preserved exactly'
);
SELECT test_support_f35.assert_text(
  $$SELECT catalog_code FROM public.contracting_items
    WHERE id = '35060000-0000-4000-8000-000000000101'::uuid$$,
  '', 'empty catalog preserved exactly'
);
SELECT test_support_f35.assert_text(
  $$SELECT quantity::text FROM public.contracting_items
    WHERE id = '35060000-0000-4000-8000-000000000101'::uuid$$,
  '0.000000000000000000123456789', 'high precision quantity preserved'
);
SELECT test_support_f35.assert_count(
  $$SELECT count(*) FROM public.contracting_events
    WHERE id = '35070000-0000-4000-8000-000000000101'::uuid
      AND team_id = '35010000-0000-4000-8000-000000000001'::uuid
      AND contracting_id = '35040000-0000-4000-8000-000000000001'::uuid
      AND actor_membership_id = '35030000-0000-4000-8000-000000000001'::uuid
      AND event_type = 'item_created'
      AND item_id = '35060000-0000-4000-8000-000000000101'::uuid
      AND field_key IS NULL
      AND old_value IS NULL
      AND new_value IS NULL
      AND note IS NULL
      AND related_identifier_id IS NULL$$,
  1, 'item_created event shape and derived scope'
);
SELECT test_support_f35.assert_true(
  $$SELECT item.created_at = item.updated_at
      AND item.created_at = event.occurred_at
      AND event.occurred_at = event.created_at
    FROM public.contracting_items AS item
    JOIN public.contracting_events AS event ON event.item_id = item.id
    WHERE item.id = '35060000-0000-4000-8000-000000000101'::uuid$$,
  'item and event share operation timestamp'
);
SELECT test_support_f35.assert_text(
  $$SELECT updated_at::text FROM public.contractings
    WHERE id = '35040000-0000-4000-8000-000000000001'::uuid$$,
  '2026-01-01 00:00:00+00', 'parent updated_at remains unchanged'
);
COMMIT;

-- Sequential creation advances the allocator and permits nullable/negative data.
BEGIN;
SELECT set_config(
  'request.jwt.claims',
  '{"iss":"urn:compras:better-auth:self-hosted:v1","sub":"DEMO-F35-A"}', true
);
SELECT test_support_f35.assert_text(
  $$SELECT public.create_contracting_item(
      '35040000-0000-4000-8000-000000000001'::uuid,
      '', -2.500::numeric, NULL, NULL,
      '35060000-0000-4000-8000-000000000102'::uuid,
      '35070000-0000-4000-8000-000000000102'::uuid
    )$$,
  'created', 'second sequential create'
);
SELECT test_support_f35.assert_text(
  $$SELECT ordinal::text FROM public.contracting_items
    WHERE id = '35060000-0000-4000-8000-000000000102'::uuid$$,
  '2', 'second sequential ordinal'
);
SELECT test_support_f35.assert_text(
  $$SELECT description FROM public.contracting_items
    WHERE id = '35060000-0000-4000-8000-000000000102'::uuid$$,
  '', 'empty description preserved'
);
SELECT test_support_f35.assert_text(
  $$SELECT quantity::text FROM public.contracting_items
    WHERE id = '35060000-0000-4000-8000-000000000102'::uuid$$,
  '-2.500', 'negative fractional quantity preserved'
);
COMMIT;

-- Fresh allocator over existing/gapped/retired data reconciles to ordinal 8.
BEGIN;
SELECT set_config(
  'request.jwt.claims',
  '{"iss":"urn:compras:better-auth:self-hosted:v1","sub":"DEMO-F35-A"}', true
);
SELECT test_support_f35.assert_text(
  $$SELECT public.create_contracting_item(
      '35040000-0000-4000-8000-000000000002'::uuid,
      'DEMO after retired max', NULL, NULL, NULL,
      '35060000-0000-4000-8000-000000000108'::uuid,
      '35070000-0000-4000-8000-000000000108'::uuid
    )$$,
  'created', 'allocator reconciles existing retired maximum'
);
SELECT test_support_f35.assert_text(
  $$SELECT ordinal::text FROM public.contracting_items
    WHERE id = '35060000-0000-4000-8000-000000000108'::uuid$$,
  '8', 'gaps are not reused and retired max participates'
);
COMMIT;

-- Cross-team, nonexistent, archived and cancelled targets are the same denial.
BEGIN;
SELECT set_config(
  'request.jwt.claims',
  '{"iss":"urn:compras:better-auth:self-hosted:v1","sub":"DEMO-F35-A"}', true
);
SELECT test_support_f35.assert_text(
  $$SELECT public.create_contracting_item(
      '35040000-0000-4000-8000-000000000003'::uuid,
      'DEMO cross', NULL, NULL, NULL,
      '35060000-0000-4000-8000-000000000110'::uuid,
      '35070000-0000-4000-8000-000000000110'::uuid
    )$$,
  'denied', 'cross-team deny'
);
SELECT test_support_f35.assert_text(
  $$SELECT public.create_contracting_item(
      '35040000-0000-4000-8000-000000009999'::uuid,
      'DEMO absent', NULL, NULL, NULL,
      '35060000-0000-4000-8000-000000000111'::uuid,
      '35070000-0000-4000-8000-000000000111'::uuid
    )$$,
  'denied', 'nonexistent deny matches cross-team'
);
SELECT test_support_f35.assert_text(
  $$SELECT public.create_contracting_item(
      '35040000-0000-4000-8000-000000000008'::uuid,
      'DEMO archived', NULL, NULL, NULL,
      '35060000-0000-4000-8000-000000000112'::uuid,
      '35070000-0000-4000-8000-000000000112'::uuid
    )$$,
  'denied', 'archived deny'
);
SELECT test_support_f35.assert_text(
  $$SELECT public.create_contracting_item(
      '35040000-0000-4000-8000-000000000009'::uuid,
      'DEMO cancelled', NULL, NULL, NULL,
      '35060000-0000-4000-8000-000000000113'::uuid,
      '35070000-0000-4000-8000-000000000113'::uuid
    )$$,
  'denied', 'cancelled deny'
);
COMMIT;

-- A duplicate event ID forces the final audit insert to fail. The PL/pgSQL DO
-- block creates a subtransaction, so item and allocator movement must rollback.
BEGIN;
SELECT set_config(
  'request.jwt.claims',
  '{"iss":"urn:compras:better-auth:self-hosted:v1","sub":"DEMO-F35-A"}', true
);
DO $rollback_test$
BEGIN
  BEGIN
    PERFORM public.create_contracting_item(
      '35040000-0000-4000-8000-000000000001'::uuid,
      'DEMO must rollback', NULL, NULL, NULL,
      '35060000-0000-4000-8000-000000000199'::uuid,
      '35070000-0000-4000-8000-000000000101'::uuid
    );
    RAISE EXCEPTION 'expected duplicate event failure';
  EXCEPTION
    WHEN unique_violation THEN
      NULL;
  END;
END;
$rollback_test$;
SELECT test_support_f35.assert_count(
  $$SELECT count(*) FROM public.contracting_items
    WHERE id = '35060000-0000-4000-8000-000000000199'::uuid$$,
  0, 'failed event rolls back item'
);
COMMIT;

RESET SESSION AUTHORIZATION;

-- Denied targets never receive allocator rows.
SELECT test_support_f35.assert_count(
  $$SELECT count(*) FROM public.contracting_item_ordinal_counters
    WHERE contracting_id IN (
      '35040000-0000-4000-8000-000000000003'::uuid,
      '35040000-0000-4000-8000-000000000004'::uuid,
      '35040000-0000-4000-8000-000000000005'::uuid,
      '35040000-0000-4000-8000-000000000006'::uuid,
      '35040000-0000-4000-8000-000000000007'::uuid,
      '35040000-0000-4000-8000-000000000008'::uuid,
      '35040000-0000-4000-8000-000000000009'::uuid
    )$$,
  0, 'denied targets do not create allocator rows'
);

SELECT test_support_f35.assert_text(
  $$SELECT last_ordinal::text FROM public.contracting_item_ordinal_counters
    WHERE contracting_id = '35040000-0000-4000-8000-000000000001'::uuid$$,
  '2', 'failed event rolls back allocator advancement'
);

SELECT test_support_f35.assert_text(
  $$SELECT last_ordinal::text FROM public.contracting_item_ordinal_counters
    WHERE contracting_id = '35040000-0000-4000-8000-000000000002'::uuid$$,
  '8', 'allocator tracks reconciled maximum'
);

-- No denied or rollback-only UUID may have produced an event.
SELECT test_support_f35.assert_count(
  $$SELECT count(*) FROM public.contracting_events
    WHERE id IN (
      '35070000-0000-4000-8000-000000000110'::uuid,
      '35070000-0000-4000-8000-000000000111'::uuid,
      '35070000-0000-4000-8000-000000000112'::uuid,
      '35070000-0000-4000-8000-000000000113'::uuid
    )$$,
  0, 'denied targets create no events'
);
