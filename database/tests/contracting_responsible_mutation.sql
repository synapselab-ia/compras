\set ON_ERROR_STOP on

-- F47 responsible mutation proof. Every identity, UUID and value is fictitious.
CREATE SCHEMA test_support_f47;

CREATE FUNCTION test_support_f47.assert_text(
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

CREATE FUNCTION test_support_f47.assert_count(
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

CREATE FUNCTION test_support_f47.assert_duplicate_event_rolls_back(
  p_contracting_id uuid,
  p_expected uuid,
  p_new uuid,
  p_duplicate_event_id uuid,
  p_expected_persisted uuid,
  p_case_name text
)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
  mutation_result text;
  before_updated_at timestamptz;
  after_updated_at timestamptz;
  persisted uuid;
BEGIN
  SELECT responsible_membership_id, updated_at
  INTO persisted, before_updated_at
  FROM public.contractings
  WHERE id = p_contracting_id;

  BEGIN
    SELECT public.mutate_contracting_responsible(
      p_contracting_id, p_expected, p_new, p_duplicate_event_id
    ) INTO mutation_result;

    RAISE EXCEPTION '%: expected duplicate event failure, got %',
      p_case_name, mutation_result;
  EXCEPTION
    WHEN unique_violation THEN
      NULL;
  END;

  SELECT responsible_membership_id, updated_at
  INTO persisted, after_updated_at
  FROM public.contractings
  WHERE id = p_contracting_id;

  IF persisted IS DISTINCT FROM p_expected_persisted THEN
    RAISE EXCEPTION '%: responsible update survived failed event insert', p_case_name;
  END IF;

  IF after_updated_at IS DISTINCT FROM before_updated_at THEN
    RAISE EXCEPTION '%: updated_at survived failed event insert', p_case_name;
  END IF;
END;
$$;

GRANT USAGE ON SCHEMA test_support_f47 TO compras_domain_runtime_f47_ci;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA test_support_f47 TO compras_domain_runtime_f47_ci;

INSERT INTO public.teams (id, name, created_at) VALUES
  ('47010000-0000-4000-8000-000000000001', 'DEMO-F47-Team-A', '2026-01-01T00:00:00Z'),
  ('47010000-0000-4000-8000-000000000002', 'DEMO-F47-Team-B-Cross', '2026-01-01T00:00:00Z'),
  ('47010000-0000-4000-8000-000000000003', 'DEMO-F47-Team-C-Revoked-Current', '2026-01-01T00:00:00Z'),
  ('47010000-0000-4000-8000-000000000004', 'DEMO-F47-Team-D-Disabled-Member', '2026-01-01T00:00:00Z'),
  ('47010000-0000-4000-8000-000000000005', 'DEMO-F47-Team-E-Actor-Other-Team', '2026-01-01T00:00:00Z'),
  ('47010000-0000-4000-8000-000000000006', 'DEMO-F47-Team-F-Revoked-Actor', '2026-01-01T00:00:00Z'),
  ('47010000-0000-4000-8000-000000000007', 'DEMO-F47-Team-G-Two-Active', '2026-01-01T00:00:00Z');

INSERT INTO public.app_users (
  id, auth_issuer, auth_subject, display_name, created_at, disabled_at
) VALUES
  ('47020000-0000-4000-8000-000000000001', 'urn:compras:better-auth:self-hosted:v1', 'DEMO-F47-A', 'DEMO F47 A', '2026-01-01T00:00:00Z', NULL),
  ('47020000-0000-4000-8000-000000000002', 'urn:compras:better-auth:self-hosted:v1', 'DEMO-F47-B', 'DEMO F47 B', '2026-01-01T00:00:00Z', NULL),
  ('47020000-0000-4000-8000-000000000003', 'urn:compras:better-auth:self-hosted:v1', 'DEMO-F47-REVOKED', 'DEMO F47 Revoked', '2026-01-01T00:00:00Z', NULL),
  ('47020000-0000-4000-8000-000000000004', 'urn:compras:better-auth:self-hosted:v1', 'DEMO-F47-DISABLED', 'DEMO F47 Disabled', '2026-01-01T00:00:00Z', '2026-01-02T00:00:00Z');

INSERT INTO public.memberships (
  id, team_id, user_id, joined_at, revoked_at
) VALUES
  ('47030000-0000-4000-8000-000000000001', '47010000-0000-4000-8000-000000000001', '47020000-0000-4000-8000-000000000001', '2026-01-01T00:00:00Z', NULL),
  ('47030000-0000-4000-8000-000000000002', '47010000-0000-4000-8000-000000000005', '47020000-0000-4000-8000-000000000001', '2026-01-01T00:00:00Z', NULL),
  ('47030000-0000-4000-8000-000000000003', '47010000-0000-4000-8000-000000000002', '47020000-0000-4000-8000-000000000002', '2026-01-01T00:00:00Z', NULL),
  ('47030000-0000-4000-8000-000000000004', '47010000-0000-4000-8000-000000000003', '47020000-0000-4000-8000-000000000001', '2026-01-01T00:00:00Z', NULL),
  ('47030000-0000-4000-8000-000000000005', '47010000-0000-4000-8000-000000000003', '47020000-0000-4000-8000-000000000003', '2026-01-01T00:00:00Z', '2026-01-02T00:00:00Z'),
  ('47030000-0000-4000-8000-000000000006', '47010000-0000-4000-8000-000000000004', '47020000-0000-4000-8000-000000000001', '2026-01-01T00:00:00Z', NULL),
  ('47030000-0000-4000-8000-000000000007', '47010000-0000-4000-8000-000000000004', '47020000-0000-4000-8000-000000000004', '2026-01-01T00:00:00Z', NULL),
  ('47030000-0000-4000-8000-000000000008', '47010000-0000-4000-8000-000000000006', '47020000-0000-4000-8000-000000000003', '2026-01-01T00:00:00Z', '2026-01-02T00:00:00Z'),
  ('47030000-0000-4000-8000-000000000009', '47010000-0000-4000-8000-000000000007', '47020000-0000-4000-8000-000000000001', '2026-01-01T00:00:00Z', NULL),
  ('47030000-0000-4000-8000-000000000010', '47010000-0000-4000-8000-000000000007', '47020000-0000-4000-8000-000000000002', '2026-01-01T00:00:00Z', NULL);

INSERT INTO public.contractings (
  id, team_id, object, responsible_membership_id, created_at, updated_at,
  archived_at, cancelled_at
) VALUES
  ('47040000-0000-4000-8000-000000000001', '47010000-0000-4000-8000-000000000001', 'DEMO A null', NULL, '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z', NULL, NULL),
  ('47040000-0000-4000-8000-000000000002', '47010000-0000-4000-8000-000000000001', 'DEMO A assigned', '47030000-0000-4000-8000-000000000001', '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z', NULL, NULL),
  ('47040000-0000-4000-8000-000000000003', '47010000-0000-4000-8000-000000000002', 'DEMO cross target', NULL, '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z', NULL, NULL),
  ('47040000-0000-4000-8000-000000000004', '47010000-0000-4000-8000-000000000003', 'DEMO revoked current', '47030000-0000-4000-8000-000000000005', '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z', NULL, NULL),
  ('47040000-0000-4000-8000-000000000005', '47010000-0000-4000-8000-000000000004', 'DEMO disabled current', '47030000-0000-4000-8000-000000000007', '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z', NULL, NULL),
  ('47040000-0000-4000-8000-000000000006', '47010000-0000-4000-8000-000000000001', 'DEMO archived', NULL, '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z', '2026-01-02T00:00:00Z', NULL),
  ('47040000-0000-4000-8000-000000000007', '47010000-0000-4000-8000-000000000001', 'DEMO cancelled', NULL, '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z', NULL, '2026-01-02T00:00:00Z'),
  ('47040000-0000-4000-8000-000000000008', '47010000-0000-4000-8000-000000000006', 'DEMO revoked actor target', NULL, '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z', NULL, NULL),
  ('47040000-0000-4000-8000-000000000009', '47010000-0000-4000-8000-000000000007', 'DEMO two active', NULL, '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z', NULL, NULL);

DO $structure$
DECLARE
  capability_oid oid;
  migrator_oid oid;
  prior_role text;
BEGIN
  SELECT oid INTO capability_oid
  FROM pg_catalog.pg_roles
  WHERE rolname = 'compras_contracting_responsible_mutation_owner';

  SELECT oid INTO migrator_oid
  FROM pg_catalog.pg_roles
  WHERE rolname = 'compras_f47_migrator_ci';

  IF capability_oid IS NULL OR migrator_oid IS NULL THEN
    RAISE EXCEPTION 'F47 structural roles are missing';
  END IF;

  IF EXISTS (
    SELECT 1 FROM pg_catalog.pg_roles
    WHERE oid = capability_oid
      AND (
        rolcanlogin OR rolsuper OR rolcreatedb OR rolcreaterole OR rolinherit
        OR rolreplication OR rolbypassrls OR rolconfig IS NOT NULL
      )
  ) THEN
    RAISE EXCEPTION 'F47 capability owner is privileged';
  END IF;

  IF EXISTS (
    SELECT 1 FROM pg_catalog.pg_auth_members
    WHERE member = capability_oid
       OR (
         roleid = capability_oid
         AND (
           member <> migrator_oid OR set_option OR inherit_option OR NOT admin_option
         )
       )
  ) THEN
    RAISE EXCEPTION 'F47 capability owner has usable membership';
  END IF;

  IF NOT pg_catalog.has_function_privilege(
       'compras_domain_runtime_f47_ci',
       'public.mutate_contracting_responsible(uuid,uuid,uuid,uuid)',
       'EXECUTE'
     ) THEN
    RAISE EXCEPTION 'F47 runtime is missing narrow EXECUTE';
  END IF;

  IF pg_catalog.has_any_column_privilege(
       'compras_domain_runtime_f47_ci', 'public.contractings', 'UPDATE'
     )
     OR pg_catalog.has_any_column_privilege(
       'compras_domain_runtime_f47_ci', 'public.contracting_events', 'INSERT'
     ) THEN
    RAISE EXCEPTION 'F47 runtime received direct write privileges';
  END IF;

  IF NOT pg_catalog.has_column_privilege(
       'compras_contracting_responsible_mutation_owner',
       'public.contractings', 'responsible_membership_id', 'UPDATE'
     )
     OR NOT pg_catalog.has_column_privilege(
       'compras_contracting_responsible_mutation_owner',
       'public.contractings', 'updated_at', 'UPDATE'
     ) THEN
    RAISE EXCEPTION 'F47 capability is missing approved update columns';
  END IF;

  IF pg_catalog.has_column_privilege(
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
     OR pg_catalog.has_any_column_privilege(
       'compras_contracting_responsible_mutation_owner', 'public.memberships', 'UPDATE'
     )
     OR pg_catalog.has_any_column_privilege(
       'compras_contracting_responsible_mutation_owner', 'public.app_users', 'UPDATE'
     )
     OR pg_catalog.has_table_privilege(
       'compras_contracting_responsible_mutation_owner', 'public.contracting_events', 'UPDATE'
     )
     OR pg_catalog.has_table_privilege(
       'compras_contracting_responsible_mutation_owner', 'public.contracting_events', 'DELETE'
     ) THEN
    RAISE EXCEPTION 'F47 capability authority is too broad';
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
      RAISE EXCEPTION 'prior capability % gained F47 authority', prior_role;
    END IF;
  END LOOP;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_catalog.pg_proc AS procedure
    JOIN pg_catalog.pg_namespace AS namespace
      ON namespace.oid = procedure.pronamespace
    WHERE namespace.nspname = 'public'
      AND procedure.proname = 'mutate_contracting_responsible'
      AND procedure.proowner = capability_oid
      AND procedure.prosecdef
      AND COALESCE(procedure.proconfig, ARRAY[]::text[])
        @> ARRAY['search_path=pg_catalog']
      AND position('EXECUTE ' IN upper(pg_catalog.pg_get_functiondef(procedure.oid))) = 0
  ) THEN
    RAISE EXCEPTION 'F47 primitive ownership/search_path/static SQL proof failed';
  END IF;
END;
$structure$;

SET SESSION AUTHORIZATION compras_domain_runtime_f47_ci;

-- Missing, malformed and unknown identity fail closed.
BEGIN;
SELECT set_config('request.jwt.claims', '', true);
SELECT test_support_f47.assert_text(
  $$SELECT public.mutate_contracting_responsible(
      '47040000-0000-4000-8000-000000000001'::uuid,
      NULL,
      '47030000-0000-4000-8000-000000000001'::uuid,
      '47050000-0000-4000-8000-000000000001'::uuid
    )$$,
  'denied', 'missing claims deny'
);
COMMIT;

BEGIN;
SELECT set_config('request.jwt.claims', 'not-json', true);
SELECT test_support_f47.assert_text(
  $$SELECT public.mutate_contracting_responsible(
      '47040000-0000-4000-8000-000000000001'::uuid,
      NULL, NULL,
      '47050000-0000-4000-8000-000000000002'::uuid
    )$$,
  'denied', 'malformed claims deny'
);
COMMIT;

BEGIN;
SELECT set_config(
  'request.jwt.claims',
  '{"iss":"urn:compras:better-auth:self-hosted:v1","sub":"DEMO-F47-UNKNOWN"}',
  true
);
SELECT test_support_f47.assert_text(
  $$SELECT public.mutate_contracting_responsible(
      '47040000-0000-4000-8000-000000000001'::uuid,
      NULL, NULL,
      '47050000-0000-4000-8000-000000000003'::uuid
    )$$,
  'denied', 'unknown identity deny'
);
COMMIT;

-- A is the only member of Team A and has another active membership elsewhere.
BEGIN;
SELECT set_config(
  'request.jwt.claims',
  '{"iss":"urn:compras:better-auth:self-hosted:v1","sub":"DEMO-F47-A"}',
  true
);
SELECT test_support_f47.assert_text(
  $$SELECT public.mutate_contracting_responsible(
      '47040000-0000-4000-8000-000000000001'::uuid,
      NULL,
      '47030000-0000-4000-8000-000000000001'::uuid,
      '47050000-0000-4000-8000-000000000101'::uuid
    )$$,
  'updated', 'NULL to actor membership'
);

SELECT test_support_f47.assert_count(
  $$SELECT count(*)
    FROM public.contracting_events
    WHERE id = '47050000-0000-4000-8000-000000000101'::uuid
      AND team_id = '47010000-0000-4000-8000-000000000001'::uuid
      AND contracting_id = '47040000-0000-4000-8000-000000000001'::uuid
      AND actor_membership_id = '47030000-0000-4000-8000-000000000001'::uuid
      AND event_type = 'responsible_changed'
      AND field_key = 'responsible_membership_id'
      AND old_value IS NULL
      AND new_value = '47030000-0000-4000-8000-000000000001'
      AND note IS NULL
      AND related_identifier_id IS NULL
      AND item_id IS NULL$$,
  1, 'event shape derives target and actor'
);

SELECT test_support_f47.assert_count(
  $$SELECT count(*)
    FROM public.contractings AS contracting
    JOIN public.contracting_events AS event
      ON event.contracting_id = contracting.id
     AND event.team_id = contracting.team_id
    WHERE contracting.id = '47040000-0000-4000-8000-000000000001'::uuid
      AND event.id = '47050000-0000-4000-8000-000000000101'::uuid
      AND contracting.updated_at = event.occurred_at
      AND event.occurred_at = event.created_at$$,
  1, 'state and event share operation timestamp'
);

-- Stale expected remains conflict even when new already equals current.
SELECT test_support_f47.assert_text(
  $$SELECT public.mutate_contracting_responsible(
      '47040000-0000-4000-8000-000000000001'::uuid,
      NULL,
      '47030000-0000-4000-8000-000000000001'::uuid,
      '47050000-0000-4000-8000-000000000102'::uuid
    )$$,
  'conflict', 'stale precedes no-op'
);

SELECT test_support_f47.assert_count(
  $$SELECT count(*) FROM public.contracting_events
    WHERE contracting_id = '47040000-0000-4000-8000-000000000001'::uuid$$,
  1, 'conflict creates no event'
);

SELECT test_support_f47.assert_text(
  $$SELECT public.mutate_contracting_responsible(
      '47040000-0000-4000-8000-000000000001'::uuid,
      '47030000-0000-4000-8000-000000000001'::uuid,
      '47030000-0000-4000-8000-000000000001'::uuid,
      '47050000-0000-4000-8000-000000000103'::uuid
    )$$,
  'unchanged', 'authorized no-op'
);

SELECT test_support_f47.assert_count(
  $$SELECT count(*) FROM public.contracting_events
    WHERE contracting_id = '47040000-0000-4000-8000-000000000001'::uuid$$,
  1, 'no-op creates no event'
);

-- Clear assigned responsible.
SELECT test_support_f47.assert_text(
  $$SELECT public.mutate_contracting_responsible(
      '47040000-0000-4000-8000-000000000002'::uuid,
      '47030000-0000-4000-8000-000000000001'::uuid,
      NULL,
      '47050000-0000-4000-8000-000000000104'::uuid
    )$$,
  'updated', 'actor membership to NULL'
);

SELECT test_support_f47.assert_count(
  $$SELECT count(*) FROM public.contracting_events
    WHERE id = '47050000-0000-4000-8000-000000000104'::uuid
      AND old_value = '47030000-0000-4000-8000-000000000001'
      AND new_value IS NULL$$,
  1, 'clear event preserves nullable values'
);

-- Current revoked responsible can be unchanged and then cleared.
SELECT test_support_f47.assert_text(
  $$SELECT public.mutate_contracting_responsible(
      '47040000-0000-4000-8000-000000000004'::uuid,
      '47030000-0000-4000-8000-000000000005'::uuid,
      '47030000-0000-4000-8000-000000000005'::uuid,
      '47050000-0000-4000-8000-000000000105'::uuid
    )$$,
  'unchanged', 'revoked current no-op'
);

SELECT test_support_f47.assert_text(
  $$SELECT public.mutate_contracting_responsible(
      '47040000-0000-4000-8000-000000000004'::uuid,
      '47030000-0000-4000-8000-000000000005'::uuid,
      NULL,
      '47050000-0000-4000-8000-000000000106'::uuid
    )$$,
  'updated', 'revoked current can be cleared'
);

SELECT test_support_f47.assert_text(
  $$SELECT public.mutate_contracting_responsible(
      '47040000-0000-4000-8000-000000000004'::uuid,
      NULL,
      '47030000-0000-4000-8000-000000000005'::uuid,
      '47050000-0000-4000-8000-000000000107'::uuid
    )$$,
  'denied', 'revoked new candidate denied'
);

-- Cross-team and nonexistent candidates are opaque denied results.
SELECT test_support_f47.assert_text(
  $$SELECT public.mutate_contracting_responsible(
      '47040000-0000-4000-8000-000000000001'::uuid,
      '47030000-0000-4000-8000-000000000001'::uuid,
      '47030000-0000-4000-8000-000000000003'::uuid,
      '47050000-0000-4000-8000-000000000108'::uuid
    )$$,
  'denied', 'cross-team candidate denied'
);

SELECT test_support_f47.assert_text(
  $$SELECT public.mutate_contracting_responsible(
      '47040000-0000-4000-8000-000000000001'::uuid,
      '47030000-0000-4000-8000-000000000001'::uuid,
      '47039999-0000-4000-8000-000000000999'::uuid,
      '47050000-0000-4000-8000-000000000109'::uuid
    )$$,
  'denied', 'missing candidate denied'
);

-- Cross-team, nonexistent, archived and cancelled targets deny identically.
SELECT test_support_f47.assert_text(
  $$SELECT public.mutate_contracting_responsible(
      '47040000-0000-4000-8000-000000000003'::uuid,
      NULL, NULL,
      '47050000-0000-4000-8000-000000000110'::uuid
    )$$,
  'denied', 'cross-team target denied'
);

SELECT test_support_f47.assert_text(
  $$SELECT public.mutate_contracting_responsible(
      '47049999-0000-4000-8000-000000000999'::uuid,
      NULL, NULL,
      '47050000-0000-4000-8000-000000000111'::uuid
    )$$,
  'denied', 'missing target denied'
);

SELECT test_support_f47.assert_text(
  $$SELECT public.mutate_contracting_responsible(
      '47040000-0000-4000-8000-000000000006'::uuid,
      NULL, NULL,
      '47050000-0000-4000-8000-000000000112'::uuid
    )$$,
  'denied', 'archived target denied'
);

SELECT test_support_f47.assert_text(
  $$SELECT public.mutate_contracting_responsible(
      '47040000-0000-4000-8000-000000000007'::uuid,
      NULL, NULL,
      '47050000-0000-4000-8000-000000000113'::uuid
    )$$,
  'denied', 'cancelled target denied'
);

-- A second active member blocks the pilot capability.
SELECT test_support_f47.assert_text(
  $$SELECT public.mutate_contracting_responsible(
      '47040000-0000-4000-8000-000000000009'::uuid,
      NULL, NULL,
      '47050000-0000-4000-8000-000000000114'::uuid
    )$$,
  'denied', 'second active member blocks'
);

-- A disabled app_user whose membership remains non-revoked also blocks.
SELECT test_support_f47.assert_text(
  $$SELECT public.mutate_contracting_responsible(
      '47040000-0000-4000-8000-000000000005'::uuid,
      '47030000-0000-4000-8000-000000000007'::uuid,
      NULL,
      '47050000-0000-4000-8000-000000000115'::uuid
    )$$,
  'denied', 'disabled app_user membership still blocks guard'
);
COMMIT;

-- Disabled current user cannot resolve current_app_user_id.
BEGIN;
SELECT set_config(
  'request.jwt.claims',
  '{"iss":"urn:compras:better-auth:self-hosted:v1","sub":"DEMO-F47-DISABLED"}',
  true
);
SELECT test_support_f47.assert_text(
  $$SELECT public.mutate_contracting_responsible(
      '47040000-0000-4000-8000-000000000005'::uuid,
      '47030000-0000-4000-8000-000000000007'::uuid,
      NULL,
      '47050000-0000-4000-8000-000000000116'::uuid
    )$$,
  'denied', 'disabled current user denied'
);
COMMIT;

-- Revoked actor membership cannot authorize the target.
BEGIN;
SELECT set_config(
  'request.jwt.claims',
  '{"iss":"urn:compras:better-auth:self-hosted:v1","sub":"DEMO-F47-REVOKED"}',
  true
);
SELECT test_support_f47.assert_text(
  $$SELECT public.mutate_contracting_responsible(
      '47040000-0000-4000-8000-000000000008'::uuid,
      NULL, NULL,
      '47050000-0000-4000-8000-000000000117'::uuid
    )$$,
  'denied', 'revoked actor denied'
);
COMMIT;

RESET SESSION AUTHORIZATION;

-- Seed a duplicate event id, then prove event failure rolls back state+timestamp.
INSERT INTO public.contracting_events (
  id, team_id, contracting_id, actor_membership_id,
  event_type, occurred_at, created_at
) VALUES (
  '47050000-0000-4000-8000-000000000900',
  '47010000-0000-4000-8000-000000000001',
  '47040000-0000-4000-8000-000000000001',
  '47030000-0000-4000-8000-000000000001',
  'DEMO-existing',
  '2026-01-01T00:00:00Z',
  '2026-01-01T00:00:00Z'
);

SET SESSION AUTHORIZATION compras_domain_runtime_f47_ci;

BEGIN;
SELECT set_config(
  'request.jwt.claims',
  '{"iss":"urn:compras:better-auth:self-hosted:v1","sub":"DEMO-F47-A"}',
  true
);
SELECT test_support_f47.assert_duplicate_event_rolls_back(
  '47040000-0000-4000-8000-000000000001'::uuid,
  '47030000-0000-4000-8000-000000000001'::uuid,
  NULL,
  '47050000-0000-4000-8000-000000000900'::uuid,
  '47030000-0000-4000-8000-000000000001'::uuid,
  'duplicate event rollback'
);
COMMIT;

RESET SESSION AUTHORIZATION;
