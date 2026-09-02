\set ON_ERROR_STOP on

-- F11 production-migration proof. All values and roles are artificial.
CREATE SCHEMA test_support_directory_impl;

CREATE FUNCTION test_support_directory_impl.assert_count(
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

CREATE FUNCTION test_support_directory_impl.assert_true(
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

CREATE FUNCTION test_support_directory_impl.expect_sqlstate(
  statement_text text,
  expected_state text,
  case_name text
)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  BEGIN
    EXECUTE statement_text;
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLSTATE = expected_state THEN
        RETURN;
      END IF;

      RAISE EXCEPTION '%: expected SQLSTATE %, got % (%)',
        case_name, expected_state, SQLSTATE, SQLERRM;
  END;

  RAISE EXCEPTION '%: expected SQLSTATE %, statement succeeded',
    case_name, expected_state;
END;
$$;

CREATE FUNCTION test_support_directory_impl.assert_capability_membership_shape()
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
  capability_oid oid;
BEGIN
  SELECT oid INTO capability_oid
  FROM pg_catalog.pg_roles
  WHERE rolname = 'compras_team_directory_view_owner';

  IF capability_oid IS NULL THEN
    RAISE EXCEPTION 'directory capability role missing';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM pg_catalog.pg_auth_members AS membership
    WHERE membership.member = capability_oid
  ) THEN
    RAISE EXCEPTION 'capability must not inherit another role';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM pg_catalog.pg_auth_members AS membership
    JOIN pg_catalog.pg_roles AS member_role
      ON member_role.oid = membership.member
    WHERE membership.roleid = capability_oid
      AND (
        membership.set_option
        OR membership.inherit_option
        OR NOT membership.admin_option
        OR member_role.rolname <> 'compras_migrator_ci'
      )
  ) THEN
    RAISE EXCEPTION 'capability has usable or unexpected membership';
  END IF;
END;
$$;

CREATE FUNCTION test_support_directory_impl.assert_directory_shape()
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
  capability_oid oid;
  migrator_oid oid;
BEGIN
  SELECT oid INTO capability_oid
  FROM pg_catalog.pg_roles
  WHERE rolname = 'compras_team_directory_view_owner';

  SELECT oid INTO migrator_oid
  FROM pg_catalog.pg_roles
  WHERE rolname = 'compras_migrator_ci';

  IF capability_oid IS NULL OR migrator_oid IS NULL THEN
    RAISE EXCEPTION 'expected F11 roles are missing';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM pg_catalog.pg_roles
    WHERE oid = capability_oid
      AND (
        rolcanlogin
        OR rolsuper
        OR rolcreatedb
        OR rolcreaterole
        OR rolinherit
        OR rolreplication
        OR rolbypassrls
        OR rolconfig IS NOT NULL
      )
  ) THEN
    RAISE EXCEPTION 'capability role attributes are unsafe';
  END IF;

  PERFORM test_support_directory_impl.assert_capability_membership_shape();

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
    RAISE EXCEPTION 'capability owns a protected base table';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_catalog.pg_class AS relation
    JOIN pg_catalog.pg_namespace AS namespace
      ON namespace.oid = relation.relnamespace
    WHERE namespace.nspname = 'public'
      AND relation.relname = 'team_member_directory'
      AND relation.relkind = 'v'
      AND relation.relowner = capability_oid
      AND COALESCE(relation.reloptions, ARRAY[]::text[])
        @> ARRAY['security_barrier=true']
      AND COALESCE(relation.reloptions, ARRAY[]::text[])
        @> ARRAY['security_invoker=false']
  ) THEN
    RAISE EXCEPTION 'directory view owner/options are unsafe';
  END IF;

  IF has_schema_privilege(
       'compras_team_directory_view_owner',
       'public',
       'CREATE'
     ) THEN
    RAISE EXCEPTION 'capability retained CREATE on public schema';
  END IF;

  IF has_column_privilege(
       'compras_team_directory_view_owner',
       'public.app_users',
       'auth_issuer',
       'SELECT'
     )
     OR has_column_privilege(
       'compras_team_directory_view_owner',
       'public.app_users',
       'auth_subject',
       'SELECT'
     ) THEN
    RAISE EXCEPTION 'capability can read external auth identifiers';
  END IF;
END;
$$;

SELECT test_support_directory_impl.assert_directory_shape();

SELECT test_support_directory_impl.assert_count(
  $$SELECT count(*)
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'team_member_directory'$$,
  3,
  'directory exposes exactly three columns'
);

SELECT test_support_directory_impl.assert_count(
  $$SELECT count(*)
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'team_member_directory'
      AND column_name IN ('team_id', 'membership_id', 'display_name')$$,
  3,
  'directory exposes only approved column names'
);

SELECT test_support_directory_impl.assert_count(
  $$SELECT count(*)
    FROM pg_catalog.pg_policies
    WHERE schemaname = 'public'
      AND policyname IN (
        'memberships_select_directory_capability',
        'app_users_select_directory_capability'
      )
      AND cmd = 'SELECT'$$,
  2,
  'F11 adds exactly two SELECT policies'
);

SELECT test_support_directory_impl.assert_count(
  $$SELECT count(*)
    FROM pg_catalog.pg_policies
    WHERE schemaname = 'public'
      AND cmd IN ('INSERT', 'UPDATE', 'DELETE', 'ALL')$$,
  0,
  'F11 adds no write-capable policy'
);

SELECT test_support_directory_impl.assert_count(
  $$SELECT count(*)
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
      AND relation.relrowsecurity
      AND relation.relforcerowsecurity$$,
  7,
  'FORCE RLS remains enabled on all protected base tables'
);

INSERT INTO public.teams (id, name, created_at) VALUES
  ('81000000-0000-4000-8000-000000000001', 'DEMO-F11-Team-A', '2026-01-01T00:00:00Z'),
  ('81000000-0000-4000-8000-000000000002', 'DEMO-F11-Team-B', '2026-01-01T00:00:00Z');

INSERT INTO public.app_users (
  id, auth_issuer, auth_subject, display_name, created_at, disabled_at
) VALUES
  ('82000000-0000-4000-8000-000000000001', 'https://f11.demo.invalid', 'DEMO-F11-A1', 'DEMO F11 A1', '2026-01-01T00:00:00Z', NULL),
  ('82000000-0000-4000-8000-000000000002', 'https://f11.demo.invalid', 'DEMO-F11-A2', 'DEMO F11 A2', '2026-01-01T00:00:00Z', NULL),
  ('82000000-0000-4000-8000-000000000003', 'https://f11.demo.invalid', 'DEMO-F11-B1', 'DEMO F11 B1', '2026-01-01T00:00:00Z', NULL),
  ('82000000-0000-4000-8000-000000000004', 'https://f11.demo.invalid', 'DEMO-F11-DISABLED', 'DEMO F11 Disabled', '2026-01-01T00:00:00Z', '2026-01-02T00:00:00Z'),
  ('82000000-0000-4000-8000-000000000005', 'https://f11.demo.invalid', 'DEMO-F11-REVOKED', 'DEMO F11 Revoked', '2026-01-01T00:00:00Z', NULL),
  ('82000000-0000-4000-8000-000000000006', 'https://f11.demo.invalid', 'DEMO-F11-NO-MEMBERSHIP', 'DEMO F11 No Membership', '2026-01-01T00:00:00Z', NULL);

INSERT INTO public.memberships (
  id, team_id, user_id, joined_at, revoked_at
) VALUES
  ('83000000-0000-4000-8000-000000000001', '81000000-0000-4000-8000-000000000001', '82000000-0000-4000-8000-000000000001', '2026-01-01T00:00:00Z', NULL),
  ('83000000-0000-4000-8000-000000000002', '81000000-0000-4000-8000-000000000001', '82000000-0000-4000-8000-000000000002', '2026-01-01T00:00:00Z', NULL),
  ('83000000-0000-4000-8000-000000000003', '81000000-0000-4000-8000-000000000002', '82000000-0000-4000-8000-000000000003', '2026-01-01T00:00:00Z', NULL),
  ('83000000-0000-4000-8000-000000000004', '81000000-0000-4000-8000-000000000001', '82000000-0000-4000-8000-000000000004', '2026-01-01T00:00:00Z', NULL),
  ('83000000-0000-4000-8000-000000000005', '81000000-0000-4000-8000-000000000001', '82000000-0000-4000-8000-000000000005', '2026-01-01T00:00:00Z', '2026-01-02T00:00:00Z');

CREATE ROLE compras_directory_app_test
  NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT NOREPLICATION NOBYPASSRLS;
GRANT USAGE ON SCHEMA public, test_support_directory_impl TO compras_directory_app_test;
GRANT SELECT ON public.memberships, public.app_users TO compras_directory_app_test;
GRANT SELECT ON public.team_member_directory TO compras_directory_app_test;
GRANT EXECUTE ON FUNCTION public.current_auth_issuer() TO compras_directory_app_test;
GRANT EXECUTE ON FUNCTION public.current_auth_subject() TO compras_directory_app_test;
GRANT EXECUTE ON FUNCTION public.current_app_user_id() TO compras_directory_app_test;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA test_support_directory_impl TO compras_directory_app_test;

-- Test-only grant lets the capability invoke the assertion helper while a
-- superuser session deliberately assumes the NOLOGIN role to probe column ACLs.
GRANT USAGE ON SCHEMA test_support_directory_impl TO compras_team_directory_view_owner;
GRANT EXECUTE ON FUNCTION test_support_directory_impl.expect_sqlstate(text, text, text)
  TO compras_team_directory_view_owner;

SET ROLE compras_team_directory_view_owner;
SELECT test_support_directory_impl.expect_sqlstate(
  'SELECT auth_issuer FROM public.app_users LIMIT 1',
  '42501',
  'capability cannot read auth_issuer'
);
SELECT test_support_directory_impl.expect_sqlstate(
  'SELECT auth_subject FROM public.app_users LIMIT 1',
  '42501',
  'capability cannot read auth_subject'
);
RESET ROLE;

REVOKE EXECUTE ON FUNCTION test_support_directory_impl.expect_sqlstate(text, text, text)
  FROM compras_team_directory_view_owner;
REVOKE USAGE ON SCHEMA test_support_directory_impl
  FROM compras_team_directory_view_owner;

-- A genuinely non-privileged authenticated principal cannot assume the
-- capability role. Permission is evaluated from session_user.
SET SESSION AUTHORIZATION compras_directory_app_test;
SELECT test_support_directory_impl.expect_sqlstate(
  'SET ROLE compras_team_directory_view_owner',
  '42501',
  'operational role cannot SET ROLE to capability'
);

SELECT test_support_directory_impl.assert_count(
  'SELECT count(*) FROM public.team_member_directory',
  0,
  'missing context sees empty directory'
);

BEGIN;
SET LOCAL request.jwt.claims = '{"iss":"https://f11.demo.invalid","sub":"DEMO-F11-UNKNOWN"}';
SELECT test_support_directory_impl.assert_count(
  'SELECT count(*) FROM public.team_member_directory',
  0,
  'unknown identity sees empty directory'
);
ROLLBACK;

BEGIN;
SET LOCAL request.jwt.claims = '{"iss":"https://f11.demo.invalid","sub":"DEMO-F11-NO-MEMBERSHIP"}';
SELECT test_support_directory_impl.assert_count(
  'SELECT count(*) FROM public.team_member_directory',
  0,
  'known user without membership sees empty directory'
);
ROLLBACK;

BEGIN;
SET LOCAL request.jwt.claims = '{"iss":"https://f11.demo.invalid","sub":"DEMO-F11-DISABLED"}';
SELECT test_support_directory_impl.assert_count(
  'SELECT count(*) FROM public.team_member_directory',
  0,
  'disabled caller sees empty directory'
);
ROLLBACK;

BEGIN;
SET LOCAL request.jwt.claims = '{"iss":"https://f11.demo.invalid","sub":"DEMO-F11-REVOKED"}';
SELECT test_support_directory_impl.assert_count(
  'SELECT count(*) FROM public.team_member_directory',
  0,
  'caller with revoked membership sees empty directory'
);
ROLLBACK;

BEGIN;
SET LOCAL request.jwt.claims = '{"iss":"https://f11.demo.invalid","sub":"DEMO-F11-A1"}';
SELECT test_support_directory_impl.assert_count(
  'SELECT count(*) FROM public.team_member_directory',
  2,
  'A1 sees exactly A1 and A2'
);
SELECT test_support_directory_impl.assert_count(
  $$SELECT count(*) FROM public.team_member_directory
    WHERE membership_id = '83000000-0000-4000-8000-000000000002'$$,
  1,
  'A1 resolves teammate A2'
);
SELECT test_support_directory_impl.assert_count(
  $$SELECT count(*) FROM public.team_member_directory
    WHERE membership_id = '83000000-0000-4000-8000-000000000003'$$,
  0,
  'known B1 UUID remains cross-team hidden'
);
SELECT test_support_directory_impl.assert_count(
  $$SELECT count(*) FROM public.team_member_directory
    WHERE membership_id = '83000000-0000-4000-8000-000000000004'$$,
  0,
  'disabled target is excluded'
);
SELECT test_support_directory_impl.assert_count(
  $$SELECT count(*) FROM public.team_member_directory
    WHERE membership_id = '83000000-0000-4000-8000-000000000005'$$,
  0,
  'revoked target is excluded'
);
SELECT test_support_directory_impl.assert_count(
  'SELECT count(*) FROM public.memberships',
  1,
  'direct memberships remain self-only'
);
SELECT test_support_directory_impl.assert_count(
  'SELECT count(*) FROM public.app_users',
  1,
  'direct app_users remain self-only'
);
ROLLBACK;

BEGIN;
SET LOCAL request.jwt.claims = '{"iss":"https://f11.demo.invalid","sub":"DEMO-F11-B1"}';
SELECT test_support_directory_impl.assert_count(
  'SELECT count(*) FROM public.team_member_directory',
  1,
  'B1 sees only team B'
);
ROLLBACK;

RESET SESSION AUTHORIZATION;

-- Red-team the persisted membership invariant. A SET-capable grant must be
-- detected by the same structural assertion used above.
GRANT compras_team_directory_view_owner TO compras_directory_app_test
  WITH INHERIT FALSE, SET TRUE;
SELECT test_support_directory_impl.expect_sqlstate(
  'SELECT test_support_directory_impl.assert_capability_membership_shape()',
  'P0001',
  'SET-capable membership must be detected'
);
REVOKE compras_team_directory_view_owner FROM compras_directory_app_test;
SELECT test_support_directory_impl.assert_capability_membership_shape();

-- Red-team owner and view security options, then restore the canonical shape.
ALTER VIEW public.team_member_directory SET (security_barrier = false);
SELECT test_support_directory_impl.expect_sqlstate(
  'SELECT test_support_directory_impl.assert_directory_shape()',
  'P0001',
  'security_barrier removal must be detected'
);
ALTER VIEW public.team_member_directory SET (security_barrier = true);

ALTER VIEW public.team_member_directory SET (security_invoker = true);
SELECT test_support_directory_impl.expect_sqlstate(
  'SELECT test_support_directory_impl.assert_directory_shape()',
  'P0001',
  'security_invoker enablement must be detected'
);
ALTER VIEW public.team_member_directory SET (security_invoker = false);

ALTER VIEW public.team_member_directory OWNER TO compras_migrator_ci;
SELECT test_support_directory_impl.expect_sqlstate(
  'SELECT test_support_directory_impl.assert_directory_shape()',
  'P0001',
  'base-table migration owner as view owner must be detected'
);
ALTER VIEW public.team_member_directory OWNER TO compras_team_directory_view_owner;

SELECT test_support_directory_impl.assert_directory_shape();

DROP OWNED BY compras_directory_app_test;
DROP ROLE compras_directory_app_test;
DROP SCHEMA test_support_directory_impl CASCADE;
