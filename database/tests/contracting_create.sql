\set ON_ERROR_STOP on

-- F29 contracting creation proof. Every identity, UUID and value is synthetic.
CREATE SCHEMA test_support_f29;

CREATE FUNCTION test_support_f29.assert_text(
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

CREATE FUNCTION test_support_f29.assert_count(
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

CREATE FUNCTION test_support_f29.assert_duplicate_event_rolls_back(
  p_contracting_id uuid,
  p_object text,
  p_duplicate_event_id uuid,
  p_case_name text
)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
  create_result text;
  persisted_count bigint;
BEGIN
  BEGIN
    SELECT public.create_contracting_minimal(
      p_contracting_id,
      p_object,
      p_duplicate_event_id
    ) INTO create_result;

    RAISE EXCEPTION '%: expected duplicate event failure, got %', p_case_name, create_result;
  EXCEPTION
    WHEN unique_violation THEN
      NULL;
  END;

  SELECT count(*)
  INTO persisted_count
  FROM public.contractings
  WHERE id = p_contracting_id;

  IF persisted_count IS DISTINCT FROM 0 THEN
    RAISE EXCEPTION '%: contracting survived failed creation event', p_case_name;
  END IF;
END;
$$;

GRANT USAGE ON SCHEMA test_support_f29 TO compras_domain_runtime_f29_ci;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA test_support_f29 TO compras_domain_runtime_f29_ci;

-- Synthetic teams for authorized, cross-team, multi-member, archived,
-- multi-membership, disabled, revoked and no-membership cases.
INSERT INTO public.teams (id, name, created_at, archived_at) VALUES
  ('29010000-0000-4000-8000-000000000001', 'DEMO-F29-Team-A-Sole', '2026-01-01T00:00:00Z', NULL),
  ('29010000-0000-4000-8000-000000000002', 'DEMO-F29-Team-B-Cross', '2026-01-01T00:00:00Z', NULL),
  ('29010000-0000-4000-8000-000000000003', 'DEMO-F29-Team-C-Multi', '2026-01-01T00:00:00Z', NULL),
  ('29010000-0000-4000-8000-000000000004', 'DEMO-F29-Team-D-Archived', '2026-01-01T00:00:00Z', '2026-01-02T00:00:00Z'),
  ('29010000-0000-4000-8000-000000000005', 'DEMO-F29-Team-E-Ambiguous-1', '2026-01-01T00:00:00Z', NULL),
  ('29010000-0000-4000-8000-000000000006', 'DEMO-F29-Team-F-Ambiguous-2', '2026-01-01T00:00:00Z', NULL),
  ('29010000-0000-4000-8000-000000000007', 'DEMO-F29-Team-G-Disabled', '2026-01-01T00:00:00Z', NULL),
  ('29010000-0000-4000-8000-000000000008', 'DEMO-F29-Team-H-Revoked', '2026-01-01T00:00:00Z', NULL),
  ('29010000-0000-4000-8000-000000000009', 'DEMO-F29-Team-I-No-Membership', '2026-01-01T00:00:00Z', NULL);

INSERT INTO public.app_users (
  id, auth_issuer, auth_subject, display_name, created_at, disabled_at
) VALUES
  ('29020000-0000-4000-8000-000000000001', 'urn:compras:better-auth:self-hosted:v1', 'DEMO-F29-A', 'DEMO F29 A', '2026-01-01T00:00:00Z', NULL),
  ('29020000-0000-4000-8000-000000000002', 'urn:compras:better-auth:self-hosted:v1', 'DEMO-F29-B', 'DEMO F29 B', '2026-01-01T00:00:00Z', NULL),
  ('29020000-0000-4000-8000-000000000003', 'urn:compras:better-auth:self-hosted:v1', 'DEMO-F29-C', 'DEMO F29 C', '2026-01-01T00:00:00Z', NULL),
  ('29020000-0000-4000-8000-000000000004', 'urn:compras:better-auth:self-hosted:v1', 'DEMO-F29-C-DISABLED-SECOND', 'DEMO F29 C Disabled Second', '2026-01-01T00:00:00Z', '2026-01-02T00:00:00Z'),
  ('29020000-0000-4000-8000-000000000005', 'urn:compras:better-auth:self-hosted:v1', 'DEMO-F29-D-ARCHIVED', 'DEMO F29 D Archived', '2026-01-01T00:00:00Z', NULL),
  ('29020000-0000-4000-8000-000000000006', 'urn:compras:better-auth:self-hosted:v1', 'DEMO-F29-E-MULTI', 'DEMO F29 E Multi', '2026-01-01T00:00:00Z', NULL),
  ('29020000-0000-4000-8000-000000000007', 'urn:compras:better-auth:self-hosted:v1', 'DEMO-F29-G-DISABLED', 'DEMO F29 G Disabled', '2026-01-01T00:00:00Z', '2026-01-02T00:00:00Z'),
  ('29020000-0000-4000-8000-000000000008', 'urn:compras:better-auth:self-hosted:v1', 'DEMO-F29-H-REVOKED', 'DEMO F29 H Revoked', '2026-01-01T00:00:00Z', NULL),
  ('29020000-0000-4000-8000-000000000009', 'urn:compras:better-auth:self-hosted:v1', 'DEMO-F29-I-NO-MEMBERSHIP', 'DEMO F29 I No Membership', '2026-01-01T00:00:00Z', NULL);

INSERT INTO public.memberships (
  id, team_id, user_id, joined_at, revoked_at
) VALUES
  ('29030000-0000-4000-8000-000000000001', '29010000-0000-4000-8000-000000000001', '29020000-0000-4000-8000-000000000001', '2026-01-01T00:00:00Z', NULL),
  ('29030000-0000-4000-8000-000000000002', '29010000-0000-4000-8000-000000000002', '29020000-0000-4000-8000-000000000002', '2026-01-01T00:00:00Z', NULL),
  ('29030000-0000-4000-8000-000000000003', '29010000-0000-4000-8000-000000000003', '29020000-0000-4000-8000-000000000003', '2026-01-01T00:00:00Z', NULL),
  ('29030000-0000-4000-8000-000000000004', '29010000-0000-4000-8000-000000000003', '29020000-0000-4000-8000-000000000004', '2026-01-01T00:00:00Z', NULL),
  ('29030000-0000-4000-8000-000000000005', '29010000-0000-4000-8000-000000000004', '29020000-0000-4000-8000-000000000005', '2026-01-01T00:00:00Z', NULL),
  ('29030000-0000-4000-8000-000000000006', '29010000-0000-4000-8000-000000000005', '29020000-0000-4000-8000-000000000006', '2026-01-01T00:00:00Z', NULL),
  ('29030000-0000-4000-8000-000000000007', '29010000-0000-4000-8000-000000000006', '29020000-0000-4000-8000-000000000006', '2026-01-01T00:00:00Z', NULL),
  ('29030000-0000-4000-8000-000000000008', '29010000-0000-4000-8000-000000000007', '29020000-0000-4000-8000-000000000007', '2026-01-01T00:00:00Z', NULL),
  ('29030000-0000-4000-8000-000000000009', '29010000-0000-4000-8000-000000000008', '29020000-0000-4000-8000-000000000008', '2026-01-01T00:00:00Z', '2026-01-02T00:00:00Z');

-- Cross-team collision and one existing event used to prove event failure rollback.
INSERT INTO public.contractings (
  id, team_id, object, created_by_membership_id, created_at, updated_at
) VALUES
  ('29040000-0000-4000-8000-000000000900', '29010000-0000-4000-8000-000000000002', 'DEMO F29 Cross B', '29030000-0000-4000-8000-000000000002', '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z'),
  ('29040000-0000-4000-8000-000000000050', '29010000-0000-4000-8000-000000000001', 'DEMO F29 Seed A', '29030000-0000-4000-8000-000000000001', '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z');

INSERT INTO public.contracting_events (
  id, team_id, contracting_id, actor_membership_id, event_type, occurred_at, created_at
) VALUES (
  '29050000-0000-4000-8000-000000000050',
  '29010000-0000-4000-8000-000000000001',
  '29040000-0000-4000-8000-000000000050',
  '29030000-0000-4000-8000-000000000001',
  'contracting_created',
  '2026-01-01T00:00:00Z',
  '2026-01-01T00:00:00Z'
);

-- Structural and privilege red-team before exercising behavior.
DO $structure$
DECLARE
  capability_oid oid;
  migrator_oid oid;
  create_function_oid oid;
  forced_rls_count bigint;
BEGIN
  SELECT oid INTO capability_oid
  FROM pg_catalog.pg_roles
  WHERE rolname = 'compras_contracting_create_owner';

  SELECT oid INTO migrator_oid
  FROM pg_catalog.pg_roles
  WHERE rolname = 'compras_f29_migrator_ci';

  IF capability_oid IS NULL OR migrator_oid IS NULL THEN
    RAISE EXCEPTION 'F29 structural roles are missing';
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
    RAISE EXCEPTION 'F29 capability owner is privileged';
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
    RAISE EXCEPTION 'F29 capability owner has usable membership';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM pg_catalog.pg_class AS relation
    JOIN pg_catalog.pg_namespace AS namespace ON namespace.oid = relation.relnamespace
    WHERE namespace.nspname = 'public'
      AND relation.relname IN (
        'teams', 'app_users', 'memberships', 'contractings',
        'related_identifiers', 'contracting_items', 'contracting_events'
      )
      AND relation.relowner = capability_oid
  ) THEN
    RAISE EXCEPTION 'F29 capability owner owns a protected table';
  END IF;

  SELECT procedure.oid
  INTO create_function_oid
  FROM pg_catalog.pg_proc AS procedure
  JOIN pg_catalog.pg_namespace AS namespace ON namespace.oid = procedure.pronamespace
  WHERE namespace.nspname = 'public'
    AND procedure.proname = 'create_contracting_minimal'
    AND procedure.proowner = capability_oid
    AND procedure.prosecdef
    AND COALESCE(procedure.proconfig, ARRAY[]::text[])
      @> ARRAY['search_path=pg_catalog']
    AND position('EXECUTE ' IN upper(pg_catalog.pg_get_functiondef(procedure.oid))) = 0;

  IF create_function_oid IS NULL THEN
    RAISE EXCEPTION 'F29 primitive ownership/search_path/static SQL proof failed';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM pg_catalog.aclexplode(
      COALESCE(
        (SELECT proacl FROM pg_catalog.pg_proc WHERE oid = create_function_oid),
        pg_catalog.acldefault('f', capability_oid)
      )
    ) AS acl
    WHERE acl.grantee = 0
      AND acl.privilege_type = 'EXECUTE'
  ) THEN
    RAISE EXCEPTION 'F29 primitive leaked PUBLIC EXECUTE';
  END IF;

  IF NOT has_function_privilege(
    'compras_domain_runtime_f29_ci',
    'public.create_contracting_minimal(uuid,text,uuid)',
    'EXECUTE'
  ) THEN
    RAISE EXCEPTION 'F29 runtime is missing explicit create EXECUTE';
  END IF;

  IF has_any_column_privilege('compras_domain_runtime_f29_ci', 'public.contractings', 'INSERT')
     OR has_any_column_privilege('compras_domain_runtime_f29_ci', 'public.contractings', 'UPDATE')
     OR has_any_column_privilege('compras_domain_runtime_f29_ci', 'public.contracting_events', 'INSERT')
     OR has_table_privilege('compras_domain_runtime_f29_ci', 'public.contracting_events', 'UPDATE')
     OR has_table_privilege('compras_domain_runtime_f29_ci', 'public.contracting_events', 'DELETE') THEN
    RAISE EXCEPTION 'F29 runtime received direct DML';
  END IF;

  IF has_any_column_privilege('compras_next_action_mutation_owner', 'public.contractings', 'INSERT')
     OR has_any_column_privilege('compras_next_action_mutation_owner', 'public.contracting_events', 'INSERT') = false AND false THEN
    RAISE EXCEPTION 'F26 capability received contracting creation authority';
  END IF;

  IF has_column_privilege('compras_contracting_create_owner', 'public.contractings', 'next_action', 'UPDATE')
     OR has_table_privilege('compras_contracting_create_owner', 'public.contractings', 'UPDATE')
     OR has_table_privilege('compras_contracting_create_owner', 'public.contractings', 'DELETE')
     OR has_table_privilege('compras_contracting_create_owner', 'public.contracting_events', 'UPDATE')
     OR has_table_privilege('compras_contracting_create_owner', 'public.contracting_events', 'DELETE')
     OR has_function_privilege(
       'compras_contracting_create_owner',
       'public.mutate_contracting_next_action(uuid,text,text,uuid)',
       'EXECUTE'
     ) THEN
    RAISE EXCEPTION 'F29 capability can mutate outside creation boundary';
  END IF;

  IF has_column_privilege('compras_contracting_create_owner', 'public.contractings', 'stage_key', 'INSERT')
     OR has_column_privilege('compras_contracting_create_owner', 'public.contractings', 'status_key', 'INSERT')
     OR has_column_privilege('compras_contracting_create_owner', 'public.contractings', 'responsible_membership_id', 'INSERT')
     OR has_column_privilege('compras_contracting_create_owner', 'public.contractings', 'waiting_type', 'INSERT')
     OR has_column_privilege('compras_contracting_create_owner', 'public.contractings', 'waiting_reference', 'INSERT')
     OR has_column_privilege('compras_contracting_create_owner', 'public.contractings', 'waiting_since', 'INSERT')
     OR has_column_privilege('compras_contracting_create_owner', 'public.contractings', 'waiting_reason', 'INSERT')
     OR has_column_privilege('compras_contracting_create_owner', 'public.contractings', 'next_action', 'INSERT')
     OR has_column_privilege('compras_contracting_create_owner', 'public.contractings', 'archived_at', 'INSERT')
     OR has_column_privilege('compras_contracting_create_owner', 'public.contractings', 'cancelled_at', 'INSERT') THEN
    RAISE EXCEPTION 'F29 capability can populate unapproved contracting columns';
  END IF;

  SELECT count(*)
  INTO forced_rls_count
  FROM pg_catalog.pg_class AS relation
  WHERE relation.oid IN (
    'public.contractings'::regclass,
    'public.contracting_events'::regclass
  )
    AND relation.relrowsecurity
    AND relation.relforcerowsecurity;

  IF forced_rls_count <> 2 THEN
    RAISE EXCEPTION 'F29 protected tables lost enabled/forced RLS';
  END IF;
END;
$structure$;

SET SESSION AUTHORIZATION compras_domain_runtime_f29_ci;

-- Missing and malformed context deny without creating rows.
BEGIN;
SELECT set_config('request.jwt.claims', '', true);
SELECT test_support_f29.assert_text(
  $$SELECT public.create_contracting_minimal(
      '29040000-0000-4000-8000-000000000001'::uuid,
      'DEMO missing claims',
      '29050000-0000-4000-8000-000000000001'::uuid
    )$$,
  'denied',
  'missing claims deny'
);
ROLLBACK;

BEGIN;
SELECT set_config('request.jwt.claims', 'not-json', true);
SELECT test_support_f29.assert_text(
  $$SELECT public.create_contracting_minimal(
      '29040000-0000-4000-8000-000000000002'::uuid,
      'DEMO malformed claims',
      '29050000-0000-4000-8000-000000000002'::uuid
    )$$,
  'denied',
  'malformed claims deny'
);
ROLLBACK;

-- Unknown, disabled, no-membership, revoked, ambiguous-membership, archived-team
-- and second-member identities all fail closed.
BEGIN;
SELECT set_config('request.jwt.claims', '{"iss":"urn:compras:better-auth:self-hosted:v1","sub":"DEMO-F29-UNKNOWN"}', true);
SELECT test_support_f29.assert_text(
  $$SELECT public.create_contracting_minimal('29040000-0000-4000-8000-000000000003'::uuid, 'DEMO unknown', '29050000-0000-4000-8000-000000000003'::uuid)$$,
  'denied', 'unknown identity deny'
);
ROLLBACK;

BEGIN;
SELECT set_config('request.jwt.claims', '{"iss":"urn:compras:better-auth:self-hosted:v1","sub":"DEMO-F29-G-DISABLED"}', true);
SELECT test_support_f29.assert_text(
  $$SELECT public.create_contracting_minimal('29040000-0000-4000-8000-000000000004'::uuid, 'DEMO disabled', '29050000-0000-4000-8000-000000000004'::uuid)$$,
  'denied', 'disabled app user deny'
);
ROLLBACK;

BEGIN;
SELECT set_config('request.jwt.claims', '{"iss":"urn:compras:better-auth:self-hosted:v1","sub":"DEMO-F29-I-NO-MEMBERSHIP"}', true);
SELECT test_support_f29.assert_text(
  $$SELECT public.create_contracting_minimal('29040000-0000-4000-8000-000000000005'::uuid, 'DEMO no membership', '29050000-0000-4000-8000-000000000005'::uuid)$$,
  'denied', 'no membership deny'
);
ROLLBACK;

BEGIN;
SELECT set_config('request.jwt.claims', '{"iss":"urn:compras:better-auth:self-hosted:v1","sub":"DEMO-F29-H-REVOKED"}', true);
SELECT test_support_f29.assert_text(
  $$SELECT public.create_contracting_minimal('29040000-0000-4000-8000-000000000006'::uuid, 'DEMO revoked', '29050000-0000-4000-8000-000000000006'::uuid)$$,
  'denied', 'revoked membership deny'
);
ROLLBACK;

BEGIN;
SELECT set_config('request.jwt.claims', '{"iss":"urn:compras:better-auth:self-hosted:v1","sub":"DEMO-F29-E-MULTI"}', true);
SELECT test_support_f29.assert_text(
  $$SELECT public.create_contracting_minimal('29040000-0000-4000-8000-000000000007'::uuid, 'DEMO ambiguous', '29050000-0000-4000-8000-000000000007'::uuid)$$,
  'denied', 'multiple user memberships deny'
);
ROLLBACK;

BEGIN;
SELECT set_config('request.jwt.claims', '{"iss":"urn:compras:better-auth:self-hosted:v1","sub":"DEMO-F29-D-ARCHIVED"}', true);
SELECT test_support_f29.assert_text(
  $$SELECT public.create_contracting_minimal('29040000-0000-4000-8000-000000000008'::uuid, 'DEMO archived team', '29050000-0000-4000-8000-000000000008'::uuid)$$,
  'denied', 'archived team deny'
);
ROLLBACK;

BEGIN;
SELECT set_config('request.jwt.claims', '{"iss":"urn:compras:better-auth:self-hosted:v1","sub":"DEMO-F29-C"}', true);
SELECT test_support_f29.assert_text(
  $$SELECT public.create_contracting_minimal('29040000-0000-4000-8000-000000000009'::uuid, 'DEMO second member', '29050000-0000-4000-8000-000000000009'::uuid)$$,
  'denied', 'second non-revoked member including disabled user deny'
);
ROLLBACK;

-- Authorized sole user/team creates the exact sparse row and one atomic event.
BEGIN;
SELECT set_config('request.jwt.claims', '{"iss":"urn:compras:better-auth:self-hosted:v1","sub":"DEMO-F29-A"}', true);
SELECT test_support_f29.assert_text(
  $$SELECT public.create_contracting_minimal(
      '29040000-0000-4000-8000-000000000101'::uuid,
      '  DEMO F29 object preserved exactly  ',
      '29050000-0000-4000-8000-000000000101'::uuid
    )$$,
  'created',
  'authorized creation'
);
SELECT test_support_f29.assert_text(
  $$SELECT object FROM public.contractings
    WHERE id = '29040000-0000-4000-8000-000000000101'::uuid$$,
  '  DEMO F29 object preserved exactly  ',
  'object preserved exactly'
);
SELECT test_support_f29.assert_count(
  $$SELECT count(*) FROM public.contractings
    WHERE id = '29040000-0000-4000-8000-000000000101'::uuid
      AND team_id = '29010000-0000-4000-8000-000000000001'::uuid
      AND created_by_membership_id = '29030000-0000-4000-8000-000000000001'::uuid
      AND responsible_membership_id IS NULL
      AND stage_key IS NULL
      AND status_key IS NULL
      AND waiting_type IS NULL
      AND waiting_reference IS NULL
      AND waiting_since IS NULL
      AND waiting_reason IS NULL
      AND next_action IS NULL
      AND archived_at IS NULL
      AND cancelled_at IS NULL$$,
  1,
  'initial row shape is sparse and derived'
);
SELECT test_support_f29.assert_count(
  $$SELECT count(*) FROM public.contracting_events
    WHERE id = '29050000-0000-4000-8000-000000000101'::uuid
      AND contracting_id = '29040000-0000-4000-8000-000000000101'::uuid
      AND team_id = '29010000-0000-4000-8000-000000000001'::uuid
      AND actor_membership_id = '29030000-0000-4000-8000-000000000001'::uuid
      AND event_type = 'contracting_created'
      AND field_key IS NULL
      AND old_value IS NULL
      AND new_value IS NULL
      AND note IS NULL
      AND related_identifier_id IS NULL
      AND item_id IS NULL$$,
  1,
  'creation event shape derives actor/team/contracting'
);
SELECT test_support_f29.assert_count(
  $$SELECT count(*)
    FROM public.contractings AS contracting
    JOIN public.contracting_events AS event
      ON event.contracting_id = contracting.id
     AND event.team_id = contracting.team_id
    WHERE contracting.id = '29040000-0000-4000-8000-000000000101'::uuid
      AND event.id = '29050000-0000-4000-8000-000000000101'::uuid
      AND contracting.created_at = contracting.updated_at
      AND contracting.created_at = event.occurred_at
      AND event.occurred_at = event.created_at$$,
  1,
  'row and event share one database instant'
);
COMMIT;

-- Exact replay is idempotent; mismatch and cross-team collision are generic deny.
BEGIN;
SELECT set_config('request.jwt.claims', '{"iss":"urn:compras:better-auth:self-hosted:v1","sub":"DEMO-F29-A"}', true);
SELECT test_support_f29.assert_text(
  $$SELECT public.create_contracting_minimal(
      '29040000-0000-4000-8000-000000000101'::uuid,
      '  DEMO F29 object preserved exactly  ',
      '29050000-0000-4000-8000-000000000102'::uuid
    )$$,
  'already-created',
  'exact replay idempotent'
);
SELECT test_support_f29.assert_count(
  $$SELECT count(*) FROM public.contracting_events
    WHERE contracting_id = '29040000-0000-4000-8000-000000000101'::uuid$$,
  1,
  'replay creates no second event'
);
SELECT test_support_f29.assert_text(
  $$SELECT public.create_contracting_minimal(
      '29040000-0000-4000-8000-000000000101'::uuid,
      'DEMO mismatched object',
      '29050000-0000-4000-8000-000000000103'::uuid
    )$$,
  'denied',
  'same UUID mismatched object deny'
);
SELECT test_support_f29.assert_text(
  $$SELECT public.create_contracting_minimal(
      '29040000-0000-4000-8000-000000000900'::uuid,
      'DEMO F29 Cross B',
      '29050000-0000-4000-8000-000000000104'::uuid
    )$$,
  'denied',
  'cross-team collision deny'
);
COMMIT;

-- Empty string is preserved because ADR-012 adds no non-empty business rule.
BEGIN;
SELECT set_config('request.jwt.claims', '{"iss":"urn:compras:better-auth:self-hosted:v1","sub":"DEMO-F29-A"}', true);
SELECT test_support_f29.assert_text(
  $$SELECT public.create_contracting_minimal(
      '29040000-0000-4000-8000-000000000103'::uuid,
      '',
      '29050000-0000-4000-8000-000000000105'::uuid
    )$$,
  'created',
  'empty object remains allowed by current schema'
);
SELECT test_support_f29.assert_text(
  $$SELECT object FROM public.contractings
    WHERE id = '29040000-0000-4000-8000-000000000103'::uuid$$,
  '',
  'empty object preserved exactly'
);
COMMIT;

-- A failed event INSERT must roll the new contracting back atomically.
BEGIN;
SELECT set_config('request.jwt.claims', '{"iss":"urn:compras:better-auth:self-hosted:v1","sub":"DEMO-F29-A"}', true);
SELECT test_support_f29.assert_duplicate_event_rolls_back(
  '29040000-0000-4000-8000-000000000102'::uuid,
  'DEMO must roll back',
  '29050000-0000-4000-8000-000000000050'::uuid,
  'event failure rolls back creation'
);
COMMIT;

RESET SESSION AUTHORIZATION;

-- Final admin proof that every denied candidate remained absent and the failed
-- event path did not leave a contracting behind.
DO $final$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM public.contractings
    WHERE id IN (
      '29040000-0000-4000-8000-000000000001'::uuid,
      '29040000-0000-4000-8000-000000000002'::uuid,
      '29040000-0000-4000-8000-000000000003'::uuid,
      '29040000-0000-4000-8000-000000000004'::uuid,
      '29040000-0000-4000-8000-000000000005'::uuid,
      '29040000-0000-4000-8000-000000000006'::uuid,
      '29040000-0000-4000-8000-000000000007'::uuid,
      '29040000-0000-4000-8000-000000000008'::uuid,
      '29040000-0000-4000-8000-000000000009'::uuid,
      '29040000-0000-4000-8000-000000000102'::uuid
    )
  ) THEN
    RAISE EXCEPTION 'a denied or rolled-back F29 path persisted a contracting';
  END IF;

  IF (SELECT count(*) FROM public.contracting_events
      WHERE contracting_id = '29040000-0000-4000-8000-000000000101'::uuid) <> 1 THEN
    RAISE EXCEPTION 'authorized replay changed F29 creation event count';
  END IF;
END;
$final$;

DROP SCHEMA test_support_f29 CASCADE;
