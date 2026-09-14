\set ON_ERROR_STOP on

-- F32 contractings.object mutation proof. Every identity, UUID and value below
-- is synthetic and safe for this public repository.
CREATE SCHEMA test_support_f32;

CREATE FUNCTION test_support_f32.assert_text(
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

CREATE FUNCTION test_support_f32.assert_count(
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

CREATE FUNCTION test_support_f32.assert_duplicate_event_rolls_back(
  p_contracting_id uuid,
  p_expected_object text,
  p_new_object text,
  p_duplicate_event_id uuid,
  p_expected_persisted_object text,
  p_case_name text
)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
  mutation_result text;
  before_updated_at timestamptz;
  after_updated_at timestamptz;
  persisted_object text;
  persisted_event_count bigint;
BEGIN
  SELECT updated_at
  INTO before_updated_at
  FROM public.contractings
  WHERE id = p_contracting_id;

  BEGIN
    SELECT public.mutate_contracting_object(
      p_contracting_id,
      p_expected_object,
      p_new_object,
      p_duplicate_event_id
    ) INTO mutation_result;

    RAISE EXCEPTION '%: expected duplicate event failure, got %', p_case_name, mutation_result;
  EXCEPTION
    WHEN unique_violation THEN
      NULL;
  END;

  SELECT object, updated_at
  INTO persisted_object, after_updated_at
  FROM public.contractings
  WHERE id = p_contracting_id;

  IF persisted_object IS DISTINCT FROM p_expected_persisted_object THEN
    RAISE EXCEPTION '%: object update survived failed event insert', p_case_name;
  END IF;

  IF after_updated_at IS DISTINCT FROM before_updated_at THEN
    RAISE EXCEPTION '%: updated_at survived failed event insert', p_case_name;
  END IF;

  SELECT count(*)
  INTO persisted_event_count
  FROM public.contracting_events
  WHERE id = p_duplicate_event_id;

  IF persisted_event_count IS DISTINCT FROM 1 THEN
    RAISE EXCEPTION '%: duplicate event failure changed existing event count', p_case_name;
  END IF;
END;
$$;

GRANT USAGE ON SCHEMA test_support_f32 TO compras_domain_runtime_f32_ci;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA test_support_f32 TO compras_domain_runtime_f32_ci;

INSERT INTO public.teams (id, name, created_at) VALUES
  ('32010000-0000-4000-8000-000000000001', 'DEMO-F32-Team-A-Target', '2026-01-01T00:00:00Z'),
  ('32010000-0000-4000-8000-000000000002', 'DEMO-F32-Team-B-Cross', '2026-01-01T00:00:00Z'),
  ('32010000-0000-4000-8000-000000000003', 'DEMO-F32-Team-C-Multi', '2026-01-01T00:00:00Z'),
  ('32010000-0000-4000-8000-000000000004', 'DEMO-F32-Team-D-Disabled', '2026-01-01T00:00:00Z'),
  ('32010000-0000-4000-8000-000000000005', 'DEMO-F32-Team-E-Revoked', '2026-01-01T00:00:00Z'),
  ('32010000-0000-4000-8000-000000000006', 'DEMO-F32-Team-F-No-Membership', '2026-01-01T00:00:00Z'),
  ('32010000-0000-4000-8000-000000000007', 'DEMO-F32-Team-G-A-Second-Team', '2026-01-01T00:00:00Z');

INSERT INTO public.app_users (
  id, auth_issuer, auth_subject, display_name, created_at, disabled_at
) VALUES
  ('32020000-0000-4000-8000-000000000001', 'urn:compras:better-auth:self-hosted:v1', 'DEMO-F32-A', 'DEMO F32 A', '2026-01-01T00:00:00Z', NULL),
  ('32020000-0000-4000-8000-000000000002', 'urn:compras:better-auth:self-hosted:v1', 'DEMO-F32-B', 'DEMO F32 B', '2026-01-01T00:00:00Z', NULL),
  ('32020000-0000-4000-8000-000000000003', 'urn:compras:better-auth:self-hosted:v1', 'DEMO-F32-C', 'DEMO F32 C', '2026-01-01T00:00:00Z', NULL),
  ('32020000-0000-4000-8000-000000000004', 'urn:compras:better-auth:self-hosted:v1', 'DEMO-F32-C-DISABLED-MEMBER', 'DEMO F32 C Disabled Member', '2026-01-01T00:00:00Z', '2026-01-02T00:00:00Z'),
  ('32020000-0000-4000-8000-000000000005', 'urn:compras:better-auth:self-hosted:v1', 'DEMO-F32-D-DISABLED', 'DEMO F32 D Disabled', '2026-01-01T00:00:00Z', '2026-01-02T00:00:00Z'),
  ('32020000-0000-4000-8000-000000000006', 'urn:compras:better-auth:self-hosted:v1', 'DEMO-F32-E-REVOKED', 'DEMO F32 E Revoked', '2026-01-01T00:00:00Z', NULL),
  ('32020000-0000-4000-8000-000000000007', 'urn:compras:better-auth:self-hosted:v1', 'DEMO-F32-F-NO-MEMBERSHIP', 'DEMO F32 F No Membership', '2026-01-01T00:00:00Z', NULL);

INSERT INTO public.memberships (
  id, team_id, user_id, joined_at, revoked_at
) VALUES
  ('32030000-0000-4000-8000-000000000001', '32010000-0000-4000-8000-000000000001', '32020000-0000-4000-8000-000000000001', '2026-01-01T00:00:00Z', NULL),
  ('32030000-0000-4000-8000-000000000002', '32010000-0000-4000-8000-000000000007', '32020000-0000-4000-8000-000000000001', '2026-01-01T00:00:00Z', NULL),
  ('32030000-0000-4000-8000-000000000003', '32010000-0000-4000-8000-000000000002', '32020000-0000-4000-8000-000000000002', '2026-01-01T00:00:00Z', NULL),
  ('32030000-0000-4000-8000-000000000004', '32010000-0000-4000-8000-000000000003', '32020000-0000-4000-8000-000000000003', '2026-01-01T00:00:00Z', NULL),
  ('32030000-0000-4000-8000-000000000005', '32010000-0000-4000-8000-000000000003', '32020000-0000-4000-8000-000000000004', '2026-01-01T00:00:00Z', NULL),
  ('32030000-0000-4000-8000-000000000006', '32010000-0000-4000-8000-000000000004', '32020000-0000-4000-8000-000000000005', '2026-01-01T00:00:00Z', NULL),
  ('32030000-0000-4000-8000-000000000007', '32010000-0000-4000-8000-000000000005', '32020000-0000-4000-8000-000000000006', '2026-01-01T00:00:00Z', '2026-01-02T00:00:00Z');

INSERT INTO public.contractings (
  id, team_id, object, next_action, stage_key, status_key, waiting_reason,
  created_at, updated_at, archived_at, cancelled_at
) VALUES
  ('32040000-0000-4000-8000-000000000001', '32010000-0000-4000-8000-000000000001', 'DEMO object old', 'DEMO next invariant', 'DEMO stage invariant', 'DEMO status invariant', 'DEMO waiting invariant', '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z', NULL, NULL),
  ('32040000-0000-4000-8000-000000000002', '32010000-0000-4000-8000-000000000001', '  DEMO spaces old  ', NULL, NULL, NULL, NULL, '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z', NULL, NULL),
  ('32040000-0000-4000-8000-000000000003', '32010000-0000-4000-8000-000000000002', 'DEMO cross old', NULL, NULL, NULL, NULL, '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z', NULL, NULL),
  ('32040000-0000-4000-8000-000000000004', '32010000-0000-4000-8000-000000000003', 'DEMO multi old', NULL, NULL, NULL, NULL, '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z', NULL, NULL),
  ('32040000-0000-4000-8000-000000000005', '32010000-0000-4000-8000-000000000004', 'DEMO disabled old', NULL, NULL, NULL, NULL, '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z', NULL, NULL),
  ('32040000-0000-4000-8000-000000000006', '32010000-0000-4000-8000-000000000005', 'DEMO revoked old', NULL, NULL, NULL, NULL, '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z', NULL, NULL),
  ('32040000-0000-4000-8000-000000000007', '32010000-0000-4000-8000-000000000006', 'DEMO no membership old', NULL, NULL, NULL, NULL, '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z', NULL, NULL),
  ('32040000-0000-4000-8000-000000000008', '32010000-0000-4000-8000-000000000001', 'DEMO archived old', NULL, NULL, NULL, NULL, '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z', '2026-01-02T00:00:00Z', NULL),
  ('32040000-0000-4000-8000-000000000009', '32010000-0000-4000-8000-000000000001', 'DEMO cancelled old', NULL, NULL, NULL, NULL, '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z', NULL, '2026-01-02T00:00:00Z');

-- Structural, least-privilege and authority-isolation proof.
DO $structure$
DECLARE
  capability_oid oid;
  migrator_oid oid;
  forced_rls_count bigint;
BEGIN
  SELECT oid INTO capability_oid
  FROM pg_catalog.pg_roles
  WHERE rolname = 'compras_contracting_object_mutation_owner';

  SELECT oid INTO migrator_oid
  FROM pg_catalog.pg_roles
  WHERE rolname = 'compras_f32_migrator_ci';

  IF capability_oid IS NULL OR migrator_oid IS NULL THEN
    RAISE EXCEPTION 'F32 structural roles are missing';
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
    RAISE EXCEPTION 'F32 capability owner is privileged';
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
    RAISE EXCEPTION 'F32 capability owner has usable membership';
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
    RAISE EXCEPTION 'F32 capability owner owns a protected table';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_catalog.pg_proc AS procedure
    JOIN pg_catalog.pg_namespace AS namespace ON namespace.oid = procedure.pronamespace
    WHERE namespace.nspname = 'public'
      AND procedure.proname = 'mutate_contracting_object'
      AND procedure.proowner = capability_oid
      AND procedure.prosecdef
      AND COALESCE(procedure.proconfig, ARRAY[]::text[])
        @> ARRAY['search_path=pg_catalog']
      AND position('EXECUTE ' IN upper(pg_catalog.pg_get_functiondef(procedure.oid))) = 0
  ) THEN
    RAISE EXCEPTION 'F32 primitive ownership/search_path/static SQL proof failed';
  END IF;

  IF has_table_privilege('compras_domain_runtime_f32_ci', 'public.contractings', 'UPDATE')
     OR has_table_privilege('compras_domain_runtime_f32_ci', 'public.contracting_events', 'INSERT')
     OR has_table_privilege('compras_domain_runtime_f32_ci', 'public.contracting_events', 'UPDATE')
     OR has_table_privilege('compras_domain_runtime_f32_ci', 'public.contracting_events', 'DELETE')
     OR has_column_privilege('compras_domain_runtime_f32_ci', 'public.contractings', 'object', 'UPDATE')
     OR has_column_privilege('compras_domain_runtime_f32_ci', 'public.contractings', 'updated_at', 'UPDATE') THEN
    RAISE EXCEPTION 'F32 runtime received direct write privileges';
  END IF;

  IF NOT has_function_privilege(
    'compras_domain_runtime_f32_ci',
    'public.mutate_contracting_object(uuid,text,text,uuid)',
    'EXECUTE'
  ) THEN
    RAISE EXCEPTION 'F32 runtime is missing narrow EXECUTE';
  END IF;

  IF NOT has_column_privilege('compras_contracting_object_mutation_owner', 'public.contractings', 'object', 'UPDATE')
     OR NOT has_column_privilege('compras_contracting_object_mutation_owner', 'public.contractings', 'updated_at', 'UPDATE') THEN
    RAISE EXCEPTION 'F32 capability is missing approved update columns';
  END IF;

  IF has_column_privilege('compras_contracting_object_mutation_owner', 'public.contractings', 'next_action', 'UPDATE')
     OR has_column_privilege('compras_contracting_object_mutation_owner', 'public.contractings', 'stage_key', 'UPDATE')
     OR has_column_privilege('compras_contracting_object_mutation_owner', 'public.contractings', 'status_key', 'UPDATE')
     OR has_column_privilege('compras_contracting_object_mutation_owner', 'public.contractings', 'responsible_membership_id', 'UPDATE')
     OR has_column_privilege('compras_contracting_object_mutation_owner', 'public.contractings', 'waiting_reason', 'UPDATE')
     OR has_column_privilege('compras_contracting_object_mutation_owner', 'public.contractings', 'created_by_membership_id', 'UPDATE')
     OR has_column_privilege('compras_contracting_object_mutation_owner', 'public.contractings', 'archived_at', 'UPDATE')
     OR has_column_privilege('compras_contracting_object_mutation_owner', 'public.contractings', 'cancelled_at', 'UPDATE')
     OR has_table_privilege('compras_contracting_object_mutation_owner', 'public.contractings', 'INSERT')
     OR has_table_privilege('compras_contracting_object_mutation_owner', 'public.contractings', 'DELETE') THEN
    RAISE EXCEPTION 'F32 capability can mutate outside object/updated_at';
  END IF;

  IF has_table_privilege('compras_contracting_object_mutation_owner', 'public.contracting_events', 'UPDATE')
     OR has_table_privilege('compras_contracting_object_mutation_owner', 'public.contracting_events', 'DELETE') THEN
    RAISE EXCEPTION 'F32 capability can mutate existing events';
  END IF;

  IF has_column_privilege('compras_next_action_mutation_owner', 'public.contractings', 'object', 'UPDATE') THEN
    RAISE EXCEPTION 'F26 gained object update authority';
  END IF;

  IF has_column_privilege('compras_contracting_create_owner', 'public.contractings', 'object', 'UPDATE')
     OR has_table_privilege('compras_contracting_create_owner', 'public.contractings', 'UPDATE') THEN
    RAISE EXCEPTION 'F29 gained update authority';
  END IF;

  IF has_function_privilege('compras_contracting_object_mutation_owner', 'public.mutate_contracting_next_action(uuid,text,text,uuid)', 'EXECUTE')
     OR has_function_privilege('compras_contracting_object_mutation_owner', 'public.create_contracting_minimal(uuid,text,uuid)', 'EXECUTE') THEN
    RAISE EXCEPTION 'F32 inherited F26/F29 EXECUTE authority';
  END IF;

  SELECT count(*) INTO forced_rls_count
  FROM pg_catalog.pg_class AS relation
  WHERE relation.oid IN (
    'public.contractings'::regclass,
    'public.contracting_events'::regclass
  )
    AND relation.relrowsecurity
    AND relation.relforcerowsecurity;

  IF forced_rls_count <> 2 THEN
    RAISE EXCEPTION 'F32 protected tables lost enabled/forced RLS';
  END IF;
END;
$structure$;

SET SESSION AUTHORIZATION compras_domain_runtime_f32_ci;

-- Missing/malformed context and NULL direct-call scalars fail closed.
BEGIN;
SELECT set_config('request.jwt.claims', '', true);
SELECT test_support_f32.assert_text(
  $$SELECT public.mutate_contracting_object(
      '32040000-0000-4000-8000-000000000001'::uuid,
      'DEMO object old', 'DEMO missing claims',
      '32050000-0000-4000-8000-000000000001'::uuid
    )$$,
  'denied', 'missing claims deny'
);
COMMIT;

BEGIN;
SELECT set_config('request.jwt.claims', 'not-json', true);
SELECT test_support_f32.assert_text(
  $$SELECT public.mutate_contracting_object(
      '32040000-0000-4000-8000-000000000001'::uuid,
      'DEMO object old', 'DEMO malformed claims',
      '32050000-0000-4000-8000-000000000002'::uuid
    )$$,
  'denied', 'malformed claims deny'
);
COMMIT;

BEGIN;
SELECT set_config(
  'request.jwt.claims',
  '{"iss":"urn:compras:better-auth:self-hosted:v1","sub":"DEMO-F32-A"}',
  true
);
SELECT test_support_f32.assert_text(
  $$SELECT public.mutate_contracting_object(
      '32040000-0000-4000-8000-000000000001'::uuid,
      NULL, 'DEMO null expected',
      '32050000-0000-4000-8000-000000000003'::uuid
    )$$,
  'denied', 'NULL expected deny'
);
SELECT test_support_f32.assert_text(
  $$SELECT public.mutate_contracting_object(
      '32040000-0000-4000-8000-000000000001'::uuid,
      'DEMO object old', NULL,
      '32050000-0000-4000-8000-000000000004'::uuid
    )$$,
  'denied', 'NULL new object deny'
);
COMMIT;

-- Unknown, disabled, absent/revoked membership and second target-team member deny.
BEGIN;
SELECT set_config(
  'request.jwt.claims',
  '{"iss":"urn:compras:better-auth:self-hosted:v1","sub":"DEMO-F32-UNKNOWN"}', true
);
SELECT test_support_f32.assert_text(
  $$SELECT public.mutate_contracting_object(
      '32040000-0000-4000-8000-000000000001'::uuid,
      'DEMO object old', 'DEMO unknown',
      '32050000-0000-4000-8000-000000000005'::uuid
    )$$,
  'denied', 'unknown identity deny'
);
COMMIT;

BEGIN;
SELECT set_config(
  'request.jwt.claims',
  '{"iss":"urn:compras:better-auth:self-hosted:v1","sub":"DEMO-F32-D-DISABLED"}', true
);
SELECT test_support_f32.assert_text(
  $$SELECT public.mutate_contracting_object(
      '32040000-0000-4000-8000-000000000005'::uuid,
      'DEMO disabled old', 'DEMO disabled',
      '32050000-0000-4000-8000-000000000006'::uuid
    )$$,
  'denied', 'disabled user deny'
);
COMMIT;

BEGIN;
SELECT set_config(
  'request.jwt.claims',
  '{"iss":"urn:compras:better-auth:self-hosted:v1","sub":"DEMO-F32-F-NO-MEMBERSHIP"}', true
);
SELECT test_support_f32.assert_text(
  $$SELECT public.mutate_contracting_object(
      '32040000-0000-4000-8000-000000000007'::uuid,
      'DEMO no membership old', 'DEMO no membership',
      '32050000-0000-4000-8000-000000000007'::uuid
    )$$,
  'denied', 'no membership deny'
);
COMMIT;

BEGIN;
SELECT set_config(
  'request.jwt.claims',
  '{"iss":"urn:compras:better-auth:self-hosted:v1","sub":"DEMO-F32-E-REVOKED"}', true
);
SELECT test_support_f32.assert_text(
  $$SELECT public.mutate_contracting_object(
      '32040000-0000-4000-8000-000000000006'::uuid,
      'DEMO revoked old', 'DEMO revoked',
      '32050000-0000-4000-8000-000000000008'::uuid
    )$$,
  'denied', 'revoked membership deny'
);
COMMIT;

BEGIN;
SELECT set_config(
  'request.jwt.claims',
  '{"iss":"urn:compras:better-auth:self-hosted:v1","sub":"DEMO-F32-C"}', true
);
SELECT test_support_f32.assert_text(
  $$SELECT public.mutate_contracting_object(
      '32040000-0000-4000-8000-000000000004'::uuid,
      'DEMO multi old', 'DEMO multi denied',
      '32050000-0000-4000-8000-000000000009'::uuid
    )$$,
  'denied', 'second non-revoked target member including disabled app_user denies'
);
COMMIT;

-- Authorized A has another active membership in Team G. F32 must still use the
-- F26 target-team guard, not F29's global one-membership creation guard.
BEGIN;
SELECT set_config(
  'request.jwt.claims',
  '{"iss":"urn:compras:better-auth:self-hosted:v1","sub":"DEMO-F32-A"}', true
);
SELECT test_support_f32.assert_text(
  $$SELECT public.mutate_contracting_object(
      '32040000-0000-4000-8000-000000000001'::uuid,
      'DEMO object old', '  DEMO object new  ',
      '32050000-0000-4000-8000-000000000101'::uuid
    )$$,
  'updated', 'authorized target-team update despite second-team membership'
);
SELECT test_support_f32.assert_text(
  $$SELECT object FROM public.contractings
    WHERE id = '32040000-0000-4000-8000-000000000001'::uuid$$,
  '  DEMO object new  ', 'object preserves leading/trailing spaces'
);
SELECT test_support_f32.assert_text(
  $$SELECT next_action FROM public.contractings
    WHERE id = '32040000-0000-4000-8000-000000000001'::uuid$$,
  'DEMO next invariant', 'next_action stays unchanged'
);
SELECT test_support_f32.assert_text(
  $$SELECT stage_key FROM public.contractings
    WHERE id = '32040000-0000-4000-8000-000000000001'::uuid$$,
  'DEMO stage invariant', 'stage stays unchanged'
);
SELECT test_support_f32.assert_text(
  $$SELECT status_key FROM public.contractings
    WHERE id = '32040000-0000-4000-8000-000000000001'::uuid$$,
  'DEMO status invariant', 'status stays unchanged'
);
SELECT test_support_f32.assert_text(
  $$SELECT waiting_reason FROM public.contractings
    WHERE id = '32040000-0000-4000-8000-000000000001'::uuid$$,
  'DEMO waiting invariant', 'waiting stays unchanged'
);
SELECT test_support_f32.assert_count(
  $$SELECT count(*)
    FROM public.contracting_events
    WHERE id = '32050000-0000-4000-8000-000000000101'::uuid
      AND contracting_id = '32040000-0000-4000-8000-000000000001'::uuid
      AND team_id = '32010000-0000-4000-8000-000000000001'::uuid
      AND actor_membership_id = '32030000-0000-4000-8000-000000000001'::uuid
      AND event_type = 'object_changed'
      AND field_key = 'object'
      AND old_value = 'DEMO object old'
      AND new_value = '  DEMO object new  '
      AND note IS NULL
      AND related_identifier_id IS NULL
      AND item_id IS NULL$$,
  1, 'event derives actor/team/contracting and exact values'
);
SELECT test_support_f32.assert_count(
  $$SELECT count(*)
    FROM public.contractings AS contracting
    JOIN public.contracting_events AS event
      ON event.contracting_id = contracting.id
     AND event.team_id = contracting.team_id
    WHERE contracting.id = '32040000-0000-4000-8000-000000000001'::uuid
      AND event.id = '32050000-0000-4000-8000-000000000101'::uuid
      AND contracting.updated_at = event.occurred_at
      AND event.occurred_at = event.created_at$$,
  1, 'state and event share one database instant'
);
COMMIT;

-- No-op changes neither timestamp nor event. Stale expected is evaluated first,
-- including retry where the current value already equals p_new_object.
BEGIN;
SELECT set_config(
  'request.jwt.claims',
  '{"iss":"urn:compras:better-auth:self-hosted:v1","sub":"DEMO-F32-A"}', true
);
SELECT test_support_f32.assert_text(
  $$SELECT public.mutate_contracting_object(
      '32040000-0000-4000-8000-000000000001'::uuid,
      '  DEMO object new  ', '  DEMO object new  ',
      '32050000-0000-4000-8000-000000000102'::uuid
    )$$,
  'unchanged', 'authorized no-op'
);
SELECT test_support_f32.assert_count(
  $$SELECT count(*) FROM public.contracting_events
    WHERE contracting_id = '32040000-0000-4000-8000-000000000001'::uuid$$,
  1, 'no-op creates no event'
);
SELECT test_support_f32.assert_count(
  $$SELECT count(*)
    FROM public.contractings AS contracting
    JOIN public.contracting_events AS event
      ON event.id = '32050000-0000-4000-8000-000000000101'::uuid
    WHERE contracting.id = '32040000-0000-4000-8000-000000000001'::uuid
      AND contracting.updated_at = event.occurred_at$$,
  1, 'no-op preserves updated_at'
);
SELECT test_support_f32.assert_text(
  $$SELECT public.mutate_contracting_object(
      '32040000-0000-4000-8000-000000000001'::uuid,
      'DEMO object old', '  DEMO object new  ',
      '32050000-0000-4000-8000-000000000103'::uuid
    )$$,
  'conflict', 'stale retry conflicts before no-op'
);
SELECT test_support_f32.assert_count(
  $$SELECT count(*) FROM public.contracting_events
    WHERE contracting_id = '32040000-0000-4000-8000-000000000001'::uuid$$,
  1, 'conflict creates no event'
);
COMMIT;

-- Empty string and spaces are valid exact object values and remain auditable.
BEGIN;
SELECT set_config(
  'request.jwt.claims',
  '{"iss":"urn:compras:better-auth:self-hosted:v1","sub":"DEMO-F32-A"}', true
);
SELECT test_support_f32.assert_text(
  $$SELECT public.mutate_contracting_object(
      '32040000-0000-4000-8000-000000000002'::uuid,
      '  DEMO spaces old  ', '',
      '32050000-0000-4000-8000-000000000104'::uuid
    )$$,
  'updated', 'empty string update'
);
SELECT test_support_f32.assert_text(
  $$SELECT object FROM public.contractings
    WHERE id = '32040000-0000-4000-8000-000000000002'::uuid$$,
  '', 'empty string persisted exactly'
);
SELECT test_support_f32.assert_text(
  $$SELECT public.mutate_contracting_object(
      '32040000-0000-4000-8000-000000000002'::uuid,
      '', '   ',
      '32050000-0000-4000-8000-000000000105'::uuid
    )$$,
  'updated', 'spaces-only update'
);
SELECT test_support_f32.assert_text(
  $$SELECT object FROM public.contractings
    WHERE id = '32040000-0000-4000-8000-000000000002'::uuid$$,
  '   ', 'spaces-only object persisted exactly'
);
SELECT test_support_f32.assert_count(
  $$SELECT count(*) FROM public.contracting_events
    WHERE contracting_id = '32040000-0000-4000-8000-000000000002'::uuid
      AND event_type = 'object_changed'
      AND field_key = 'object'$$,
  2, 'empty/spaces transitions each audited once'
);
COMMIT;

-- Cross-team/nonexistent are identical denial. Archived/cancelled are denied
-- before conflict/no-op semantics even when caller supplies arbitrary expected.
BEGIN;
SELECT set_config(
  'request.jwt.claims',
  '{"iss":"urn:compras:better-auth:self-hosted:v1","sub":"DEMO-F32-A"}', true
);
SELECT test_support_f32.assert_text(
  $$SELECT public.mutate_contracting_object(
      '32040000-0000-4000-8000-000000000003'::uuid,
      'DEMO cross old', 'DEMO cross write',
      '32050000-0000-4000-8000-000000000010'::uuid
    )$$,
  'denied', 'cross-team deny'
);
SELECT test_support_f32.assert_text(
  $$SELECT public.mutate_contracting_object(
      '32040000-0000-4000-8000-000000009999'::uuid,
      'DEMO absent', 'DEMO absent',
      '32050000-0000-4000-8000-000000000011'::uuid
    )$$,
  'denied', 'nonexistent matches cross-team deny'
);
SELECT test_support_f32.assert_text(
  $$SELECT public.mutate_contracting_object(
      '32040000-0000-4000-8000-000000000008'::uuid,
      'WRONG EXPECTED', 'DEMO archived write',
      '32050000-0000-4000-8000-000000000012'::uuid
    )$$,
  'denied', 'archived deny before conflict'
);
SELECT test_support_f32.assert_text(
  $$SELECT public.mutate_contracting_object(
      '32040000-0000-4000-8000-000000000009'::uuid,
      'WRONG EXPECTED', 'DEMO cancelled write',
      '32050000-0000-4000-8000-000000000013'::uuid
    )$$,
  'denied', 'cancelled deny before conflict'
);
COMMIT;

-- Event insertion failure must atomically roll back object and updated_at.
BEGIN;
SELECT set_config(
  'request.jwt.claims',
  '{"iss":"urn:compras:better-auth:self-hosted:v1","sub":"DEMO-F32-A"}', true
);
SELECT test_support_f32.assert_duplicate_event_rolls_back(
  '32040000-0000-4000-8000-000000000001'::uuid,
  '  DEMO object new  ',
  'DEMO must roll back',
  '32050000-0000-4000-8000-000000000101'::uuid,
  '  DEMO object new  ',
  'event failure rolls back state and timestamp'
);
COMMIT;

RESET SESSION AUTHORIZATION;

-- Admin-side proof that every denied/no-op/conflict event ID stayed absent and
-- protected rows outside the authorized target were untouched.
DO $final$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM public.contractings
    WHERE (id = '32040000-0000-4000-8000-000000000003'::uuid AND object <> 'DEMO cross old')
       OR (id = '32040000-0000-4000-8000-000000000004'::uuid AND object <> 'DEMO multi old')
       OR (id = '32040000-0000-4000-8000-000000000005'::uuid AND object <> 'DEMO disabled old')
       OR (id = '32040000-0000-4000-8000-000000000006'::uuid AND object <> 'DEMO revoked old')
       OR (id = '32040000-0000-4000-8000-000000000007'::uuid AND object <> 'DEMO no membership old')
       OR (id = '32040000-0000-4000-8000-000000000008'::uuid AND object <> 'DEMO archived old')
       OR (id = '32040000-0000-4000-8000-000000000009'::uuid AND object <> 'DEMO cancelled old')
  ) THEN
    RAISE EXCEPTION 'a denied F32 path mutated protected state';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.contracting_events
    WHERE id IN (
      '32050000-0000-4000-8000-000000000001'::uuid,
      '32050000-0000-4000-8000-000000000002'::uuid,
      '32050000-0000-4000-8000-000000000003'::uuid,
      '32050000-0000-4000-8000-000000000004'::uuid,
      '32050000-0000-4000-8000-000000000005'::uuid,
      '32050000-0000-4000-8000-000000000006'::uuid,
      '32050000-0000-4000-8000-000000000007'::uuid,
      '32050000-0000-4000-8000-000000000008'::uuid,
      '32050000-0000-4000-8000-000000000009'::uuid,
      '32050000-0000-4000-8000-000000000010'::uuid,
      '32050000-0000-4000-8000-000000000011'::uuid,
      '32050000-0000-4000-8000-000000000012'::uuid,
      '32050000-0000-4000-8000-000000000013'::uuid,
      '32050000-0000-4000-8000-000000000102'::uuid,
      '32050000-0000-4000-8000-000000000103'::uuid
    )
  ) THEN
    RAISE EXCEPTION 'denied/no-op/conflict F32 path created an event';
  END IF;
END;
$final$;

DROP SCHEMA test_support_f32 CASCADE;
