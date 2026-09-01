\set ON_ERROR_STOP on

-- All identities, UUIDs and operational values in this file are artificial.
-- The database context below is only a reproducible transport for ADR-003;
-- it is not authentication and would be unsafe if an untrusted client held SQL credentials.

CREATE SCHEMA test_support;

CREATE FUNCTION test_support.assert_count(query_text text, expected bigint, case_name text)
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

CREATE FUNCTION test_support.assert_true(query_text text, case_name text)
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

CREATE FUNCTION test_support.expect_insufficient_privilege(statement_text text, case_name text)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  BEGIN
    EXECUTE statement_text;
  EXCEPTION
    WHEN insufficient_privilege THEN
      RETURN;
  END;

  RAISE EXCEPTION '%: expected insufficient_privilege', case_name;
END;
$$;

CREATE FUNCTION test_support.expect_zero_rows(statement_text text, case_name text)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
  touched bigint;
BEGIN
  EXECUTE statement_text;
  GET DIAGNOSTICS touched = ROW_COUNT;
  IF touched <> 0 THEN
    RAISE EXCEPTION '%: expected zero affected rows, got %', case_name, touched;
  END IF;
END;
$$;

-- Structural checks are evaluated before adding any disposable test grants.
DO $$
DECLARE
  select_policy_count integer;
  write_policy_count integer;
  safe_function_count integer;
BEGIN
  SELECT count(*) INTO select_policy_count
  FROM pg_policies
  WHERE schemaname = 'public'
    AND tablename IN (
      'teams', 'app_users', 'memberships', 'contractings',
      'related_identifiers', 'contracting_items', 'contracting_events'
    )
    AND cmd = 'SELECT';

  IF select_policy_count <> 7 THEN
    RAISE EXCEPTION 'expected exactly seven SELECT policies, got %', select_policy_count;
  END IF;

  SELECT count(*) INTO write_policy_count
  FROM pg_policies
  WHERE schemaname = 'public'
    AND tablename IN (
      'teams', 'app_users', 'memberships', 'contractings',
      'related_identifiers', 'contracting_items', 'contracting_events'
    )
    AND cmd IN ('INSERT', 'UPDATE', 'DELETE', 'ALL');

  IF write_policy_count <> 0 THEN
    RAISE EXCEPTION 'read slice must not contain permissive write policies';
  END IF;

  SELECT count(*) INTO safe_function_count
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public'
    AND p.proname IN ('current_auth_issuer', 'current_auth_subject', 'current_app_user_id')
    AND p.provolatile = 's'
    AND NOT p.prosecdef
    AND p.proconfig @> ARRAY['search_path=pg_catalog'];

  IF safe_function_count <> 3 THEN
    RAISE EXCEPTION 'identity helpers must be STABLE, SECURITY INVOKER and pin search_path';
  END IF;

  IF has_function_privilege('public', 'public.current_auth_issuer()', 'EXECUTE')
     OR has_function_privilege('public', 'public.current_auth_subject()', 'EXECUTE')
     OR has_function_privilege('public', 'public.current_app_user_id()', 'EXECUTE') THEN
    RAISE EXCEPTION 'PUBLIC must not execute identity helpers';
  END IF;
END;
$$;

INSERT INTO teams (id, name, created_at) VALUES
  ('00000000-0000-4000-8000-000000000011', 'DEMO-Read-Team-A', '2026-01-01T00:00:00Z'),
  ('00000000-0000-4000-8000-000000000012', 'DEMO-Read-Team-B', '2026-01-01T00:00:00Z'),
  ('00000000-0000-4000-8000-000000000013', 'DEMO-Read-Team-Revoked', '2026-01-01T00:00:00Z'),
  ('00000000-0000-4000-8000-000000000014', 'DEMO-Read-Team-Disabled', '2026-01-01T00:00:00Z');

INSERT INTO app_users (
  id, auth_issuer, auth_subject, display_name, created_at, disabled_at
) VALUES
  ('10000000-0000-4000-8000-000000000011', 'https://issuer.demo.invalid', 'DEMO-READ-A', 'DEMO-Read-User-A', '2026-01-01T00:00:00Z', NULL),
  ('10000000-0000-4000-8000-000000000012', 'https://issuer.demo.invalid', 'DEMO-READ-B', 'DEMO-Read-User-B', '2026-01-01T00:00:00Z', NULL),
  ('10000000-0000-4000-8000-000000000013', 'https://issuer.demo.invalid', 'DEMO-NO-MEMBERSHIP', 'DEMO-No-Membership', '2026-01-01T00:00:00Z', NULL),
  ('10000000-0000-4000-8000-000000000014', 'https://issuer.demo.invalid', 'DEMO-DISABLED', 'DEMO-Disabled', '2026-01-01T00:00:00Z', '2026-01-05T00:00:00Z'),
  ('10000000-0000-4000-8000-000000000015', 'https://issuer.demo.invalid', 'DEMO-REVOKED', 'DEMO-Revoked', '2026-01-01T00:00:00Z', NULL);

INSERT INTO memberships (id, team_id, user_id, joined_at, revoked_at) VALUES
  ('20000000-0000-4000-8000-000000000011', '00000000-0000-4000-8000-000000000011', '10000000-0000-4000-8000-000000000011', '2026-01-01T00:00:00Z', NULL),
  ('20000000-0000-4000-8000-000000000012', '00000000-0000-4000-8000-000000000012', '10000000-0000-4000-8000-000000000012', '2026-01-01T00:00:00Z', NULL),
  ('20000000-0000-4000-8000-000000000014', '00000000-0000-4000-8000-000000000014', '10000000-0000-4000-8000-000000000014', '2026-01-01T00:00:00Z', NULL),
  ('20000000-0000-4000-8000-000000000015', '00000000-0000-4000-8000-000000000013', '10000000-0000-4000-8000-000000000015', '2026-01-01T00:00:00Z', '2026-01-05T00:00:00Z');

INSERT INTO contractings (
  id, team_id, object, created_by_membership_id, created_at, updated_at
) VALUES
  ('30000000-0000-4000-8000-000000000011', '00000000-0000-4000-8000-000000000011', 'DEMO-Read-Contracting-A', '20000000-0000-4000-8000-000000000011', '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z'),
  ('30000000-0000-4000-8000-000000000012', '00000000-0000-4000-8000-000000000012', 'DEMO-Read-Contracting-B', '20000000-0000-4000-8000-000000000012', '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z'),
  ('30000000-0000-4000-8000-000000000013', '00000000-0000-4000-8000-000000000013', 'DEMO-Read-Contracting-Revoked', '20000000-0000-4000-8000-000000000015', '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z'),
  ('30000000-0000-4000-8000-000000000014', '00000000-0000-4000-8000-000000000014', 'DEMO-Read-Contracting-Disabled', '20000000-0000-4000-8000-000000000014', '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z');

INSERT INTO related_identifiers (
  id, team_id, contracting_id, identifier_value, linked_at
) VALUES
  ('40000000-0000-4000-8000-000000000011', '00000000-0000-4000-8000-000000000011', '30000000-0000-4000-8000-000000000011', 'DEMO-READ-REF-A', '2026-01-01T00:00:00Z'),
  ('40000000-0000-4000-8000-000000000012', '00000000-0000-4000-8000-000000000012', '30000000-0000-4000-8000-000000000012', 'DEMO-READ-REF-B', '2026-01-01T00:00:00Z'),
  ('40000000-0000-4000-8000-000000000013', '00000000-0000-4000-8000-000000000013', '30000000-0000-4000-8000-000000000013', 'DEMO-READ-REF-REVOKED', '2026-01-01T00:00:00Z'),
  ('40000000-0000-4000-8000-000000000014', '00000000-0000-4000-8000-000000000014', '30000000-0000-4000-8000-000000000014', 'DEMO-READ-REF-DISABLED', '2026-01-01T00:00:00Z');

INSERT INTO contracting_items (
  id, team_id, contracting_id, ordinal, description, created_at, updated_at
) VALUES
  ('50000000-0000-4000-8000-000000000011', '00000000-0000-4000-8000-000000000011', '30000000-0000-4000-8000-000000000011', 1, 'DEMO-Read-Item-A', '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z'),
  ('50000000-0000-4000-8000-000000000012', '00000000-0000-4000-8000-000000000012', '30000000-0000-4000-8000-000000000012', 1, 'DEMO-Read-Item-B', '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z'),
  ('50000000-0000-4000-8000-000000000013', '00000000-0000-4000-8000-000000000013', '30000000-0000-4000-8000-000000000013', 1, 'DEMO-Read-Item-Revoked', '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z'),
  ('50000000-0000-4000-8000-000000000014', '00000000-0000-4000-8000-000000000014', '30000000-0000-4000-8000-000000000014', 1, 'DEMO-Read-Item-Disabled', '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z');

INSERT INTO contracting_events (
  id, team_id, contracting_id, actor_membership_id, event_type, occurred_at, created_at
) VALUES
  ('60000000-0000-4000-8000-000000000011', '00000000-0000-4000-8000-000000000011', '30000000-0000-4000-8000-000000000011', '20000000-0000-4000-8000-000000000011', 'DEMO-READ-EVENT-A', '2026-01-02T00:00:00Z', '2026-01-02T00:00:00Z'),
  ('60000000-0000-4000-8000-000000000012', '00000000-0000-4000-8000-000000000012', '30000000-0000-4000-8000-000000000012', '20000000-0000-4000-8000-000000000012', 'DEMO-READ-EVENT-B', '2026-01-02T00:00:00Z', '2026-01-02T00:00:00Z'),
  ('60000000-0000-4000-8000-000000000013', '00000000-0000-4000-8000-000000000013', '30000000-0000-4000-8000-000000000013', '20000000-0000-4000-8000-000000000015', 'DEMO-READ-EVENT-REVOKED', '2026-01-02T00:00:00Z', '2026-01-02T00:00:00Z'),
  ('60000000-0000-4000-8000-000000000014', '00000000-0000-4000-8000-000000000014', '30000000-0000-4000-8000-000000000014', '20000000-0000-4000-8000-000000000014', 'DEMO-READ-EVENT-DISABLED', '2026-01-02T00:00:00Z', '2026-01-02T00:00:00Z');

-- Test-only role. Broad DML grants intentionally make RLS, rather than missing
-- table privileges, responsible for the authorization outcome in this disposable DB.
CREATE ROLE compras_read_test
  NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT NOBYPASSRLS;
GRANT USAGE ON SCHEMA public, test_support TO compras_read_test;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE
  teams, app_users, memberships, contractings,
  related_identifiers, contracting_items, contracting_events
TO compras_read_test;
GRANT EXECUTE ON FUNCTION public.current_auth_issuer() TO compras_read_test;
GRANT EXECUTE ON FUNCTION public.current_auth_subject() TO compras_read_test;
GRANT EXECUTE ON FUNCTION public.current_app_user_id() TO compras_read_test;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA test_support TO compras_read_test;

DO $$
DECLARE
  role_is_safe boolean;
  role_owns_table boolean;
BEGIN
  SELECT NOT rolsuper AND NOT rolbypassrls
  INTO role_is_safe
  FROM pg_roles
  WHERE rolname = 'compras_read_test';

  IF role_is_safe IS DISTINCT FROM true THEN
    RAISE EXCEPTION 'operational test role must be non-superuser and NOBYPASSRLS';
  END IF;

  SELECT EXISTS (
    SELECT 1
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    JOIN pg_roles r ON r.oid = c.relowner
    WHERE n.nspname = 'public'
      AND c.relname IN (
        'teams', 'app_users', 'memberships', 'contractings',
        'related_identifiers', 'contracting_items', 'contracting_events'
      )
      AND r.rolname = 'compras_read_test'
  ) INTO role_owns_table;

  IF role_owns_table THEN
    RAISE EXCEPTION 'operational test role must not own protected tables';
  END IF;
END;
$$;

SET ROLE compras_read_test;

-- No authenticated context: everything fails closed.
SELECT test_support.assert_true(
  'SELECT public.current_auth_issuer() IS NULL AND public.current_auth_subject() IS NULL AND public.current_app_user_id() IS NULL',
  'no context returns null identity'
);
SELECT test_support.assert_count('SELECT count(*) FROM public.app_users', 0, 'no context app_users');
SELECT test_support.assert_count('SELECT count(*) FROM public.memberships', 0, 'no context memberships');
SELECT test_support.assert_count('SELECT count(*) FROM public.teams', 0, 'no context teams');
SELECT test_support.assert_count('SELECT count(*) FROM public.contractings', 0, 'no context contractings');

-- Malformed, partial and unknown identities fail closed rather than widening access.
BEGIN;
SET LOCAL request.jwt.claims = 'not-json';
SELECT test_support.assert_true(
  'SELECT public.current_auth_issuer() IS NULL AND public.current_auth_subject() IS NULL',
  'invalid json returns null claims'
);
SELECT test_support.assert_count('SELECT count(*) FROM public.app_users', 0, 'invalid json app_users');
ROLLBACK;

BEGIN;
SET LOCAL request.jwt.claims = '{"sub":"DEMO-READ-A"}';
SELECT test_support.assert_count('SELECT count(*) FROM public.app_users', 0, 'missing issuer');
ROLLBACK;

BEGIN;
SET LOCAL request.jwt.claims = '{"iss":"https://issuer.demo.invalid"}';
SELECT test_support.assert_count('SELECT count(*) FROM public.app_users', 0, 'missing subject');
ROLLBACK;

BEGIN;
SET LOCAL request.jwt.claims = '{"iss":"https://issuer.demo.invalid","sub":"DEMO-UNKNOWN"}';
SELECT test_support.assert_true(
  'SELECT public.current_app_user_id() IS NULL',
  'unknown identity has no app_user'
);
SELECT test_support.assert_count('SELECT count(*) FROM public.app_users', 0, 'unknown identity app_users');
SELECT test_support.assert_count('SELECT count(*) FROM public.teams', 0, 'unknown identity teams');
ROLLBACK;

-- Known user without membership can see only its own active app_user row.
BEGIN;
SET LOCAL request.jwt.claims = '{"iss":"https://issuer.demo.invalid","sub":"DEMO-NO-MEMBERSHIP"}';
SELECT test_support.assert_count('SELECT count(*) FROM public.app_users', 1, 'no-membership own app_user');
SELECT test_support.assert_count('SELECT count(*) FROM public.memberships', 0, 'no-membership memberships');
SELECT test_support.assert_count('SELECT count(*) FROM public.teams', 0, 'no-membership teams');
SELECT test_support.assert_count('SELECT count(*) FROM public.contractings', 0, 'no-membership contractings');
ROLLBACK;

-- Disabled internal user fails closed even with an otherwise active membership.
BEGIN;
SET LOCAL request.jwt.claims = '{"iss":"https://issuer.demo.invalid","sub":"DEMO-DISABLED"}';
SELECT test_support.assert_true(
  'SELECT public.current_app_user_id() IS NULL',
  'disabled app_user does not resolve'
);
SELECT test_support.assert_count('SELECT count(*) FROM public.app_users', 0, 'disabled own app_user');
SELECT test_support.assert_count('SELECT count(*) FROM public.memberships', 0, 'disabled memberships');
SELECT test_support.assert_count('SELECT count(*) FROM public.teams', 0, 'disabled teams');
SELECT test_support.assert_count('SELECT count(*) FROM public.contractings', 0, 'disabled contractings');
ROLLBACK;

-- Revoked membership disappears immediately without requiring a new login.
BEGIN;
SET LOCAL request.jwt.claims = '{"iss":"https://issuer.demo.invalid","sub":"DEMO-REVOKED"}';
SELECT test_support.assert_count('SELECT count(*) FROM public.app_users', 1, 'revoked user own app_user');
SELECT test_support.assert_count('SELECT count(*) FROM public.memberships', 0, 'revoked membership hidden');
SELECT test_support.assert_count('SELECT count(*) FROM public.teams', 0, 'revoked team hidden');
SELECT test_support.assert_count('SELECT count(*) FROM public.contractings', 0, 'revoked contractings hidden');
ROLLBACK;

-- Active membership authorizes exactly one team and all four operational tables in that team.
BEGIN;
SET LOCAL request.jwt.claims = '{"iss":"https://issuer.demo.invalid","sub":"DEMO-READ-A"}';
SELECT test_support.assert_true(
  $$SELECT public.current_app_user_id() = '10000000-0000-4000-8000-000000000011'::uuid$$,
  'active identity resolves expected app_user'
);
SELECT test_support.assert_count('SELECT count(*) FROM public.app_users', 1, 'active user only own app_user');
SELECT test_support.assert_count('SELECT count(*) FROM public.memberships', 1, 'active user only own active membership');
SELECT test_support.assert_count('SELECT count(*) FROM public.teams', 1, 'active user only authorized team');
SELECT test_support.assert_count('SELECT count(*) FROM public.contractings', 1, 'active user scoped contractings');
SELECT test_support.assert_count('SELECT count(*) FROM public.related_identifiers', 1, 'active user scoped identifiers');
SELECT test_support.assert_count('SELECT count(*) FROM public.contracting_items', 1, 'active user scoped items');
SELECT test_support.assert_count('SELECT count(*) FROM public.contracting_events', 1, 'active user scoped events');

-- Knowing valid UUIDs in another team does not widen access.
SELECT test_support.assert_count(
  $$SELECT count(*) FROM public.contractings WHERE id = '30000000-0000-4000-8000-000000000012'$$,
  0,
  'known cross-team contracting uuid'
);
SELECT test_support.assert_count(
  $$SELECT count(*) FROM public.related_identifiers WHERE id = '40000000-0000-4000-8000-000000000012'$$,
  0,
  'known cross-team identifier uuid'
);
SELECT test_support.assert_count(
  $$SELECT count(*) FROM public.contracting_items WHERE id = '50000000-0000-4000-8000-000000000012'$$,
  0,
  'known cross-team item uuid'
);
SELECT test_support.assert_count(
  $$SELECT count(*) FROM public.contracting_events WHERE id = '60000000-0000-4000-8000-000000000012'$$,
  0,
  'known cross-team event uuid'
);
SELECT test_support.assert_count(
  $$SELECT count(*) FROM public.app_users WHERE id = '10000000-0000-4000-8000-000000000012'$$,
  0,
  'other app_user hidden'
);

-- Test-only DML grants prove that missing write policies, not missing grants, deny writes.
SELECT test_support.expect_insufficient_privilege(
  $$INSERT INTO public.teams (id, name, created_at)
    VALUES ('00000000-0000-4000-8000-000000000099', 'DEMO-Blocked-Insert', '2026-01-09T00:00:00Z')$$,
  'insert blocked by RLS'
);
SELECT test_support.expect_zero_rows(
  $$UPDATE public.contractings
    SET object = 'DEMO-Blocked-Update'
    WHERE id = '30000000-0000-4000-8000-000000000011'$$,
  'update blocked by RLS'
);
SELECT test_support.expect_zero_rows(
  $$DELETE FROM public.contractings
    WHERE id = '30000000-0000-4000-8000-000000000011'$$,
  'delete blocked by RLS'
);
ROLLBACK;

RESET ROLE;

-- Ensure the blocked write checks did not mutate owner-visible state.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM teams
    WHERE id = '00000000-0000-4000-8000-000000000099'
  ) THEN
    RAISE EXCEPTION 'blocked insert persisted unexpectedly';
  END IF;

  IF (SELECT object FROM contractings WHERE id = '30000000-0000-4000-8000-000000000011') <> 'DEMO-Read-Contracting-A' THEN
    RAISE EXCEPTION 'blocked update changed persisted state';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM contractings
    WHERE id = '30000000-0000-4000-8000-000000000011'
  ) THEN
    RAISE EXCEPTION 'blocked delete removed persisted state';
  END IF;
END;
$$;

DROP OWNED BY compras_read_test;
DROP ROLE compras_read_test;
DROP SCHEMA test_support CASCADE;
