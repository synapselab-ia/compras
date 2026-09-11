\set ON_ERROR_STOP on

-- F26 next_action mutation proof. Every identity, UUID and value is synthetic.
CREATE SCHEMA test_support_f26;

CREATE FUNCTION test_support_f26.assert_text(
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

CREATE FUNCTION test_support_f26.assert_count(
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

CREATE FUNCTION test_support_f26.assert_duplicate_event_rolls_back(
  p_contracting_id uuid,
  p_expected_next_action text,
  p_new_next_action text,
  p_duplicate_event_id uuid,
  p_expected_persisted_next_action text,
  p_case_name text
)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
  mutation_result text;
  persisted_next_action text;
  persisted_event_count bigint;
BEGIN
  BEGIN
    SELECT public.mutate_contracting_next_action(
      p_contracting_id,
      p_expected_next_action,
      p_new_next_action,
      p_duplicate_event_id
    ) INTO mutation_result;

    RAISE EXCEPTION '%: expected duplicate event failure, got %', p_case_name, mutation_result;
  EXCEPTION
    WHEN unique_violation THEN
      NULL;
  END;

  SELECT next_action
  INTO persisted_next_action
  FROM public.contractings
  WHERE id = p_contracting_id;

  IF persisted_next_action IS DISTINCT FROM p_expected_persisted_next_action THEN
    RAISE EXCEPTION '%: state update survived failed event insert', p_case_name;
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

GRANT USAGE ON SCHEMA test_support_f26 TO compras_domain_runtime_f26_ci;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA test_support_f26 TO compras_domain_runtime_f26_ci;

-- Synthetic teams.
INSERT INTO public.teams (id, name, created_at) VALUES
  ('26010000-0000-4000-8000-000000000001', 'DEMO-F26-Team-A-Single', '2026-01-01T00:00:00Z'),
  ('26010000-0000-4000-8000-000000000002', 'DEMO-F26-Team-B-Cross', '2026-01-01T00:00:00Z'),
  ('26010000-0000-4000-8000-000000000003', 'DEMO-F26-Team-C-Multi', '2026-01-01T00:00:00Z'),
  ('26010000-0000-4000-8000-000000000004', 'DEMO-F26-Team-D-Disabled', '2026-01-01T00:00:00Z'),
  ('26010000-0000-4000-8000-000000000005', 'DEMO-F26-Team-E-Revoked', '2026-01-01T00:00:00Z'),
  ('26010000-0000-4000-8000-000000000006', 'DEMO-F26-Team-F-No-Membership', '2026-01-01T00:00:00Z');

INSERT INTO public.app_users (
  id, auth_issuer, auth_subject, display_name, created_at, disabled_at
) VALUES
  ('26020000-0000-4000-8000-000000000001', 'urn:compras:better-auth:self-hosted:v1', 'DEMO-F26-A', 'DEMO F26 A', '2026-01-01T00:00:00Z', NULL),
  ('26020000-0000-4000-8000-000000000002', 'urn:compras:better-auth:self-hosted:v1', 'DEMO-F26-B', 'DEMO F26 B', '2026-01-01T00:00:00Z', NULL),
  ('26020000-0000-4000-8000-000000000003', 'urn:compras:better-auth:self-hosted:v1', 'DEMO-F26-C', 'DEMO F26 C', '2026-01-01T00:00:00Z', NULL),
  ('26020000-0000-4000-8000-000000000004', 'urn:compras:better-auth:self-hosted:v1', 'DEMO-F26-C-DISABLED-MEMBER', 'DEMO F26 C Disabled Member', '2026-01-01T00:00:00Z', '2026-01-02T00:00:00Z'),
  ('26020000-0000-4000-8000-000000000005', 'urn:compras:better-auth:self-hosted:v1', 'DEMO-F26-D-DISABLED', 'DEMO F26 D Disabled', '2026-01-01T00:00:00Z', '2026-01-02T00:00:00Z'),
  ('26020000-0000-4000-8000-000000000006', 'urn:compras:better-auth:self-hosted:v1', 'DEMO-F26-E-REVOKED', 'DEMO F26 E Revoked', '2026-01-01T00:00:00Z', NULL),
  ('26020000-0000-4000-8000-000000000007', 'urn:compras:better-auth:self-hosted:v1', 'DEMO-F26-F-NO-MEMBERSHIP', 'DEMO F26 F No Membership', '2026-01-01T00:00:00Z', NULL);

INSERT INTO public.memberships (
  id, team_id, user_id, joined_at, revoked_at
) VALUES
  ('26030000-0000-4000-8000-000000000001', '26010000-0000-4000-8000-000000000001', '26020000-0000-4000-8000-000000000001', '2026-01-01T00:00:00Z', NULL),
  ('26030000-0000-4000-8000-000000000002', '26010000-0000-4000-8000-000000000002', '26020000-0000-4000-8000-000000000002', '2026-01-01T00:00:00Z', NULL),
  ('26030000-0000-4000-8000-000000000003', '26010000-0000-4000-8000-000000000003', '26020000-0000-4000-8000-000000000003', '2026-01-01T00:00:00Z', NULL),
  ('26030000-0000-4000-8000-000000000004', '26010000-0000-4000-8000-000000000003', '26020000-0000-4000-8000-000000000004', '2026-01-01T00:00:00Z', NULL),
  ('26030000-0000-4000-8000-000000000005', '26010000-0000-4000-8000-000000000004', '26020000-0000-4000-8000-000000000005', '2026-01-01T00:00:00Z', NULL),
  ('26030000-0000-4000-8000-000000000006', '26010000-0000-4000-8000-000000000005', '26020000-0000-4000-8000-000000000006', '2026-01-01T00:00:00Z', '2026-01-02T00:00:00Z');

INSERT INTO public.contractings (
  id, team_id, object, next_action, created_at, updated_at, archived_at, cancelled_at
) VALUES
  ('26040000-0000-4000-8000-000000000001', '26010000-0000-4000-8000-000000000001', 'DEMO F26 Active A', 'DEMO old', '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z', NULL, NULL),
  ('26040000-0000-4000-8000-000000000002', '26010000-0000-4000-8000-000000000001', 'DEMO F26 Null A', NULL, '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z', NULL, NULL),
  ('26040000-0000-4000-8000-000000000003', '26010000-0000-4000-8000-000000000002', 'DEMO F26 Cross B', 'DEMO B old', '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z', NULL, NULL),
  ('26040000-0000-4000-8000-000000000004', '26010000-0000-4000-8000-000000000003', 'DEMO F26 Multi C', 'DEMO C old', '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z', NULL, NULL),
  ('26040000-0000-4000-8000-000000000005', '26010000-0000-4000-8000-000000000004', 'DEMO F26 Disabled D', 'DEMO D old', '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z', NULL, NULL),
  ('26040000-0000-4000-8000-000000000006', '26010000-0000-4000-8000-000000000005', 'DEMO F26 Revoked E', 'DEMO E old', '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z', NULL, NULL),
  ('26040000-0000-4000-8000-000000000007', '26010000-0000-4000-8000-000000000006', 'DEMO F26 No Membership F', 'DEMO F old', '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z', NULL, NULL),
  ('26040000-0000-4000-8000-000000000008', '26010000-0000-4000-8000-000000000001', 'DEMO F26 Archived A', 'DEMO archived', '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z', '2026-01-02T00:00:00Z', NULL),
  ('26040000-0000-4000-8000-000000000009', '26010000-0000-4000-8000-000000000001', 'DEMO F26 Cancelled A', 'DEMO cancelled', '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z', NULL, '2026-01-02T00:00:00Z');

-- Structural and privilege red-team before exercising behavior.
DO $structure$
DECLARE
  capability_oid oid;
  migrator_oid oid;
BEGIN
  SELECT oid INTO capability_oid
  FROM pg_catalog.pg_roles
  WHERE rolname = 'compras_next_action_mutation_owner';

  SELECT oid INTO migrator_oid
  FROM pg_catalog.pg_roles
  WHERE rolname = 'compras_f26_migrator_ci';

  IF capability_oid IS NULL OR migrator_oid IS NULL THEN
    RAISE EXCEPTION 'F26 structural roles are missing';
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
    RAISE EXCEPTION 'F26 capability owner is privileged';
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
    RAISE EXCEPTION 'F26 capability owner has usable membership';
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
    RAISE EXCEPTION 'F26 capability owner owns a protected table';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_catalog.pg_proc AS procedure
    JOIN pg_catalog.pg_namespace AS namespace ON namespace.oid = procedure.pronamespace
    WHERE namespace.nspname = 'public'
      AND procedure.proname = 'mutate_contracting_next_action'
      AND procedure.proowner = capability_oid
      AND procedure.prosecdef
      AND COALESCE(procedure.proconfig, ARRAY[]::text[])
        @> ARRAY['search_path=pg_catalog']
      AND position('EXECUTE ' IN upper(pg_catalog.pg_get_functiondef(procedure.oid))) = 0
  ) THEN
    RAISE EXCEPTION 'F26 primitive ownership/search_path/static SQL proof failed';
  END IF;

  IF has_table_privilege('compras_domain_runtime_f26_ci', 'public.contractings', 'UPDATE')
     OR has_table_privilege('compras_domain_runtime_f26_ci', 'public.contracting_events', 'INSERT')
     OR has_table_privilege('compras_domain_runtime_f26_ci', 'public.contracting_events', 'UPDATE')
     OR has_table_privilege('compras_domain_runtime_f26_ci', 'public.contracting_events', 'DELETE') THEN
    RAISE EXCEPTION 'F26 runtime received direct write privileges';
  END IF;

  IF has_column_privilege('compras_domain_runtime_f26_ci', 'public.contractings', 'next_action', 'UPDATE')
     OR has_column_privilege('compras_domain_runtime_f26_ci', 'public.contractings', 'updated_at', 'UPDATE') THEN
    RAISE EXCEPTION 'F26 runtime received direct column UPDATE privileges';
  END IF;

  IF NOT has_function_privilege(
    'compras_domain_runtime_f26_ci',
    'public.mutate_contracting_next_action(uuid,text,text,uuid)',
    'EXECUTE'
  ) THEN
    RAISE EXCEPTION 'F26 runtime is missing the narrow EXECUTE capability';
  END IF;

  IF has_column_privilege('compras_next_action_mutation_owner', 'public.contractings', 'stage_key', 'UPDATE')
     OR has_column_privilege('compras_next_action_mutation_owner', 'public.contractings', 'status_key', 'UPDATE')
     OR has_column_privilege('compras_next_action_mutation_owner', 'public.contractings', 'responsible_membership_id', 'UPDATE')
     OR has_column_privilege('compras_next_action_mutation_owner', 'public.contractings', 'waiting_type', 'UPDATE')
     OR has_column_privilege('compras_next_action_mutation_owner', 'public.contractings', 'waiting_reference', 'UPDATE')
     OR has_column_privilege('compras_next_action_mutation_owner', 'public.contractings', 'waiting_since', 'UPDATE')
     OR has_column_privilege('compras_next_action_mutation_owner', 'public.contractings', 'waiting_reason', 'UPDATE') THEN
    RAISE EXCEPTION 'F26 capability can update unrelated operational columns';
  END IF;

  IF has_table_privilege('compras_next_action_mutation_owner', 'public.contracting_events', 'UPDATE')
     OR has_table_privilege('compras_next_action_mutation_owner', 'public.contracting_events', 'DELETE') THEN
    RAISE EXCEPTION 'F26 capability can rewrite/delete events';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_catalog.pg_class AS relation
    WHERE relation.oid IN ('public.contractings'::regclass, 'public.contracting_events'::regclass)
      AND relation.relrowsecurity
      AND relation.relforcerowsecurity
    GROUP BY true
    HAVING count(*) = 2
  ) THEN
    RAISE EXCEPTION 'F26 protected tables lost enabled/forced RLS';
  END IF;
END;
$structure$;

SET SESSION AUTHORIZATION compras_domain_runtime_f26_ci;

-- Missing or malformed context fails closed.
BEGIN;
SELECT set_config('request.jwt.claims', '', true);
SELECT test_support_f26.assert_text(
  $$SELECT public.mutate_contracting_next_action(
      '26040000-0000-4000-8000-000000000001'::uuid,
      'DEMO old', 'DEMO missing claims',
      '26050000-0000-4000-8000-000000000001'::uuid
    )$$,
  'denied',
  'missing claims deny'
);
ROLLBACK;

BEGIN;
SELECT set_config('request.jwt.claims', 'not-json', true);
SELECT test_support_f26.assert_text(
  $$SELECT public.mutate_contracting_next_action(
      '26040000-0000-4000-8000-000000000001'::uuid,
      'DEMO old', 'DEMO malformed claims',
      '26050000-0000-4000-8000-000000000002'::uuid
    )$$,
  'denied',
  'malformed claims deny'
);
ROLLBACK;

-- Unknown/disabled/no-membership/revoked identities all deny without mutation.
BEGIN;
SELECT set_config(
  'request.jwt.claims',
  '{"iss":"urn:compras:better-auth:self-hosted:v1","sub":"DEMO-F26-UNKNOWN"}',
  true
);
SELECT test_support_f26.assert_text(
  $$SELECT public.mutate_contracting_next_action(
      '26040000-0000-4000-8000-000000000001'::uuid,
      'DEMO old', 'DEMO unknown',
      '26050000-0000-4000-8000-000000000003'::uuid
    )$$,
  'denied',
  'unknown identity deny'
);
ROLLBACK;

BEGIN;
SELECT set_config(
  'request.jwt.claims',
  '{"iss":"urn:compras:better-auth:self-hosted:v1","sub":"DEMO-F26-D-DISABLED"}',
  true
);
SELECT test_support_f26.assert_text(
  $$SELECT public.mutate_contracting_next_action(
      '26040000-0000-4000-8000-000000000005'::uuid,
      'DEMO D old', 'DEMO disabled',
      '26050000-0000-4000-8000-000000000004'::uuid
    )$$,
  'denied',
  'disabled app user deny'
);
ROLLBACK;

BEGIN;
SELECT set_config(
  'request.jwt.claims',
  '{"iss":"urn:compras:better-auth:self-hosted:v1","sub":"DEMO-F26-F-NO-MEMBERSHIP"}',
  true
);
SELECT test_support_f26.assert_text(
  $$SELECT public.mutate_contracting_next_action(
      '26040000-0000-4000-8000-000000000007'::uuid,
      'DEMO F old', 'DEMO no membership',
      '26050000-0000-4000-8000-000000000005'::uuid
    )$$,
  'denied',
  'no membership deny'
);
ROLLBACK;

BEGIN;
SELECT set_config(
  'request.jwt.claims',
  '{"iss":"urn:compras:better-auth:self-hosted:v1","sub":"DEMO-F26-E-REVOKED"}',
  true
);
SELECT test_support_f26.assert_text(
  $$SELECT public.mutate_contracting_next_action(
      '26040000-0000-4000-8000-000000000006'::uuid,
      'DEMO E old', 'DEMO revoked',
      '26050000-0000-4000-8000-000000000006'::uuid
    )$$,
  'denied',
  'revoked membership deny'
);
ROLLBACK;

-- Team C has a second non-revoked membership whose app_user is disabled. The
-- conservative pilot guard must still deny.
BEGIN;
SELECT set_config(
  'request.jwt.claims',
  '{"iss":"urn:compras:better-auth:self-hosted:v1","sub":"DEMO-F26-C"}',
  true
);
SELECT test_support_f26.assert_text(
  $$SELECT public.mutate_contracting_next_action(
      '26040000-0000-4000-8000-000000000004'::uuid,
      'DEMO C old', 'DEMO multi member',
      '26050000-0000-4000-8000-000000000007'::uuid
    )$$,
  'denied',
  'second active membership deny'
);
ROLLBACK;

-- Authorized A: cross-team and nonexistent UUIDs are deliberately identical;
-- archived/cancelled targets are also denied before conflict/no-op semantics.
BEGIN;
SELECT set_config(
  'request.jwt.claims',
  '{"iss":"urn:compras:better-auth:self-hosted:v1","sub":"DEMO-F26-A"}',
  true
);
SELECT test_support_f26.assert_text(
  $$SELECT public.mutate_contracting_next_action(
      '26040000-0000-4000-8000-000000000003'::uuid,
      'DEMO B old', 'DEMO cross',
      '26050000-0000-4000-8000-000000000008'::uuid
    )$$,
  'denied',
  'known cross-team UUID deny'
);
SELECT test_support_f26.assert_text(
  $$SELECT public.mutate_contracting_next_action(
      '26040000-0000-4000-8000-000000009999'::uuid,
      'DEMO absent', 'DEMO absent',
      '26050000-0000-4000-8000-000000000009'::uuid
    )$$,
  'denied',
  'nonexistent UUID matches cross-team denial'
);
SELECT test_support_f26.assert_text(
  $$SELECT public.mutate_contracting_next_action(
      '26040000-0000-4000-8000-000000000008'::uuid,
      'DEMO archived', 'DEMO archived changed',
      '26050000-0000-4000-8000-000000000010'::uuid
    )$$,
  'denied',
  'archived contracting deny'
);
SELECT test_support_f26.assert_text(
  $$SELECT public.mutate_contracting_next_action(
      '26040000-0000-4000-8000-000000000009'::uuid,
      'DEMO cancelled', 'DEMO cancelled changed',
      '26050000-0000-4000-8000-000000000011'::uuid
    )$$,
  'denied',
  'cancelled contracting deny'
);
COMMIT;

-- Real mutation: state + exactly one event, actor/team derived from the DB,
-- and one database instant shared by state/event timestamps.
BEGIN;
SELECT set_config(
  'request.jwt.claims',
  '{"iss":"urn:compras:better-auth:self-hosted:v1","sub":"DEMO-F26-A"}',
  true
);
SELECT test_support_f26.assert_text(
  $$SELECT public.mutate_contracting_next_action(
      '26040000-0000-4000-8000-000000000001'::uuid,
      'DEMO old', 'DEMO new',
      '26050000-0000-4000-8000-000000000101'::uuid
    )$$,
  'updated',
  'authorized single-member update'
);
SELECT test_support_f26.assert_text(
  $$SELECT next_action
    FROM public.contractings
    WHERE id = '26040000-0000-4000-8000-000000000001'::uuid$$,
  'DEMO new',
  'state updated'
);
SELECT test_support_f26.assert_count(
  $$SELECT count(*)
    FROM public.contracting_events
    WHERE contracting_id = '26040000-0000-4000-8000-000000000001'::uuid
      AND id = '26050000-0000-4000-8000-000000000101'::uuid
      AND team_id = '26010000-0000-4000-8000-000000000001'::uuid
      AND actor_membership_id = '26030000-0000-4000-8000-000000000001'::uuid
      AND event_type = 'next_action_changed'
      AND field_key = 'next_action'
      AND old_value = 'DEMO old'
      AND new_value = 'DEMO new'
      AND note IS NULL
      AND related_identifier_id IS NULL
      AND item_id IS NULL$$,
  1,
  'event shape derives actor/team/contracting'
);
SELECT test_support_f26.assert_count(
  $$SELECT count(*)
    FROM public.contractings AS contracting
    JOIN public.contracting_events AS event
      ON event.contracting_id = contracting.id
     AND event.team_id = contracting.team_id
    WHERE contracting.id = '26040000-0000-4000-8000-000000000001'::uuid
      AND event.id = '26050000-0000-4000-8000-000000000101'::uuid
      AND contracting.updated_at = event.occurred_at
      AND event.occurred_at = event.created_at$$,
  1,
  'state and event share one database instant'
);
COMMIT;

-- No-op preserves timestamp/event; stale expected returns conflict with no write.
BEGIN;
SELECT set_config(
  'request.jwt.claims',
  '{"iss":"urn:compras:better-auth:self-hosted:v1","sub":"DEMO-F26-A"}',
  true
);
SELECT test_support_f26.assert_text(
  $$SELECT public.mutate_contracting_next_action(
      '26040000-0000-4000-8000-000000000001'::uuid,
      'DEMO new', 'DEMO new',
      '26050000-0000-4000-8000-000000000102'::uuid
    )$$,
  'unchanged',
  'authorized no-op'
);
SELECT test_support_f26.assert_count(
  $$SELECT count(*) FROM public.contracting_events
    WHERE contracting_id = '26040000-0000-4000-8000-000000000001'::uuid$$,
  1,
  'no-op creates no event'
);
SELECT test_support_f26.assert_count(
  $$SELECT count(*)
    FROM public.contractings AS contracting
    JOIN public.contracting_events AS event
      ON event.id = '26050000-0000-4000-8000-000000000101'::uuid
    WHERE contracting.id = '26040000-0000-4000-8000-000000000001'::uuid
      AND contracting.updated_at = event.occurred_at$$,
  1,
  'no-op preserves updated_at'
);
SELECT test_support_f26.assert_text(
  $$SELECT public.mutate_contracting_next_action(
      '26040000-0000-4000-8000-000000000001'::uuid,
      'DEMO old', 'DEMO stale overwrite',
      '26050000-0000-4000-8000-000000000103'::uuid
    )$$,
  'conflict',
  'stale expected conflicts'
);
SELECT test_support_f26.assert_text(
  $$SELECT next_action FROM public.contractings
    WHERE id = '26040000-0000-4000-8000-000000000001'::uuid$$,
  'DEMO new',
  'conflict preserves state'
);
SELECT test_support_f26.assert_count(
  $$SELECT count(*) FROM public.contracting_events
    WHERE contracting_id = '26040000-0000-4000-8000-000000000001'::uuid$$,
  1,
  'conflict creates no event'
);
COMMIT;

-- NULL remains a supported scalar because the canonical column is nullable.
BEGIN;
SELECT set_config(
  'request.jwt.claims',
  '{"iss":"urn:compras:better-auth:self-hosted:v1","sub":"DEMO-F26-A"}',
  true
);
SELECT test_support_f26.assert_text(
  $$SELECT public.mutate_contracting_next_action(
      '26040000-0000-4000-8000-000000000002'::uuid,
      NULL, 'DEMO from null',
      '26050000-0000-4000-8000-000000000104'::uuid
    )$$,
  'updated',
  'NULL to text update'
);
SELECT test_support_f26.assert_text(
  $$SELECT public.mutate_contracting_next_action(
      '26040000-0000-4000-8000-000000000002'::uuid,
      'DEMO from null', NULL,
      '26050000-0000-4000-8000-000000000105'::uuid
    )$$,
  'updated',
  'text to NULL update'
);
SELECT test_support_f26.assert_count(
  $$SELECT count(*) FROM public.contractings
    WHERE id = '26040000-0000-4000-8000-000000000002'::uuid
      AND next_action IS NULL$$,
  1,
  'NULL result persisted'
);
SELECT test_support_f26.assert_count(
  $$SELECT count(*) FROM public.contracting_events
    WHERE contracting_id = '26040000-0000-4000-8000-000000000002'::uuid$$,
  2,
  'NULL transitions remain auditable'
);
COMMIT;

-- Force the event insert to fail with a duplicate event UUID. The nested
-- exception block proves the preceding state UPDATE is rolled back with it.
BEGIN;
SELECT set_config(
  'request.jwt.claims',
  '{"iss":"urn:compras:better-auth:self-hosted:v1","sub":"DEMO-F26-A"}',
  true
);
SELECT test_support_f26.assert_duplicate_event_rolls_back(
  '26040000-0000-4000-8000-000000000001'::uuid,
  'DEMO new',
  'DEMO must roll back',
  '26050000-0000-4000-8000-000000000101'::uuid,
  'DEMO new',
  'event failure rolls back state'
);
COMMIT;

RESET SESSION AUTHORIZATION;

-- Final admin-level proof that all denied paths left their synthetic targets
-- unchanged and did not create stray events.
DO $final$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM public.contractings
    WHERE (id = '26040000-0000-4000-8000-000000000003'::uuid AND next_action <> 'DEMO B old')
       OR (id = '26040000-0000-4000-8000-000000000004'::uuid AND next_action <> 'DEMO C old')
       OR (id = '26040000-0000-4000-8000-000000000005'::uuid AND next_action <> 'DEMO D old')
       OR (id = '26040000-0000-4000-8000-000000000006'::uuid AND next_action <> 'DEMO E old')
       OR (id = '26040000-0000-4000-8000-000000000007'::uuid AND next_action <> 'DEMO F old')
       OR (id = '26040000-0000-4000-8000-000000000008'::uuid AND next_action <> 'DEMO archived')
       OR (id = '26040000-0000-4000-8000-000000000009'::uuid AND next_action <> 'DEMO cancelled')
  ) THEN
    RAISE EXCEPTION 'a denied F26 path mutated protected state';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.contracting_events
    WHERE id IN (
      '26050000-0000-4000-8000-000000000001'::uuid,
      '26050000-0000-4000-8000-000000000002'::uuid,
      '26050000-0000-4000-8000-000000000003'::uuid,
      '26050000-0000-4000-8000-000000000004'::uuid,
      '26050000-0000-4000-8000-000000000005'::uuid,
      '26050000-0000-4000-8000-000000000006'::uuid,
      '26050000-0000-4000-8000-000000000007'::uuid,
      '26050000-0000-4000-8000-000000000008'::uuid,
      '26050000-0000-4000-8000-000000000009'::uuid,
      '26050000-0000-4000-8000-000000000010'::uuid,
      '26050000-0000-4000-8000-000000000011'::uuid,
      '26050000-0000-4000-8000-000000000102'::uuid,
      '26050000-0000-4000-8000-000000000103'::uuid
    )
  ) THEN
    RAISE EXCEPTION 'denied/no-op/conflict F26 path created an event';
  END IF;
END;
$final$;

DROP SCHEMA test_support_f26 CASCADE;
