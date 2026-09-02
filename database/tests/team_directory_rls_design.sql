\set ON_ERROR_STOP on

-- F10 design proof only. All values and roles are artificial and disposable.
-- No object in this file is a production migration.

CREATE SCHEMA test_support_directory;

CREATE FUNCTION test_support_directory.assert_count(
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

CREATE FUNCTION test_support_directory.assert_true(
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

CREATE FUNCTION test_support_directory.expect_sqlstate(
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

INSERT INTO public.teams (id, name, created_at) VALUES
  ('71000000-0000-4000-8000-000000000001', 'DEMO-Directory-Team-A', '2026-01-01T00:00:00Z'),
  ('71000000-0000-4000-8000-000000000002', 'DEMO-Directory-Team-B', '2026-01-01T00:00:00Z');

INSERT INTO public.app_users (
  id, auth_issuer, auth_subject, display_name, created_at, disabled_at
) VALUES
  ('72000000-0000-4000-8000-000000000001', 'https://directory.demo.invalid', 'DEMO-DIR-A1', 'DEMO Directory A1', '2026-01-01T00:00:00Z', NULL),
  ('72000000-0000-4000-8000-000000000002', 'https://directory.demo.invalid', 'DEMO-DIR-A2', 'DEMO Directory A2', '2026-01-01T00:00:00Z', NULL),
  ('72000000-0000-4000-8000-000000000003', 'https://directory.demo.invalid', 'DEMO-DIR-B1', 'DEMO Directory B1', '2026-01-01T00:00:00Z', NULL),
  ('72000000-0000-4000-8000-000000000004', 'https://directory.demo.invalid', 'DEMO-DIR-DISABLED', 'DEMO Directory Disabled', '2026-01-01T00:00:00Z', '2026-01-02T00:00:00Z'),
  ('72000000-0000-4000-8000-000000000005', 'https://directory.demo.invalid', 'DEMO-DIR-REVOKED', 'DEMO Directory Revoked', '2026-01-01T00:00:00Z', NULL),
  ('72000000-0000-4000-8000-000000000006', 'https://directory.demo.invalid', 'DEMO-DIR-NO-MEMBERSHIP', 'DEMO Directory No Membership', '2026-01-01T00:00:00Z', NULL);

INSERT INTO public.memberships (
  id, team_id, user_id, joined_at, revoked_at
) VALUES
  ('73000000-0000-4000-8000-000000000001', '71000000-0000-4000-8000-000000000001', '72000000-0000-4000-8000-000000000001', '2026-01-01T00:00:00Z', NULL),
  ('73000000-0000-4000-8000-000000000002', '71000000-0000-4000-8000-000000000001', '72000000-0000-4000-8000-000000000002', '2026-01-01T00:00:00Z', NULL),
  ('73000000-0000-4000-8000-000000000003', '71000000-0000-4000-8000-000000000002', '72000000-0000-4000-8000-000000000003', '2026-01-01T00:00:00Z', NULL),
  ('73000000-0000-4000-8000-000000000004', '71000000-0000-4000-8000-000000000001', '72000000-0000-4000-8000-000000000004', '2026-01-01T00:00:00Z', NULL),
  ('73000000-0000-4000-8000-000000000005', '71000000-0000-4000-8000-000000000001', '72000000-0000-4000-8000-000000000005', '2026-01-01T00:00:00Z', '2026-01-02T00:00:00Z');

CREATE ROLE compras_directory_probe
  NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT NOBYPASSRLS;
GRANT USAGE ON SCHEMA public, test_support_directory TO compras_directory_probe;
GRANT SELECT ON TABLE public.memberships, public.app_users TO compras_directory_probe;
GRANT EXECUTE ON FUNCTION public.current_auth_issuer() TO compras_directory_probe;
GRANT EXECUTE ON FUNCTION public.current_auth_subject() TO compras_directory_probe;
GRANT EXECUTE ON FUNCTION public.current_app_user_id() TO compras_directory_probe;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA test_support_directory TO compras_directory_probe;

-- Alternative 1: security-invoker projection is safe but still self-only.
CREATE VIEW public.team_member_directory_invoker_probe
WITH (security_invoker = true)
AS
SELECT
  m.team_id,
  m.id AS membership_id,
  u.display_name
FROM public.memberships AS m
JOIN public.app_users AS u ON u.id = m.user_id
WHERE m.revoked_at IS NULL
  AND u.disabled_at IS NULL;
REVOKE ALL ON public.team_member_directory_invoker_probe FROM PUBLIC;
GRANT SELECT ON public.team_member_directory_invoker_probe TO compras_directory_probe;

SET ROLE compras_directory_probe;
BEGIN;
SET LOCAL request.jwt.claims = '{"iss":"https://directory.demo.invalid","sub":"DEMO-DIR-A1"}';
SELECT test_support_directory.assert_count(
  'SELECT count(*) FROM public.memberships', 1,
  'baseline memberships remain self-only'
);
SELECT test_support_directory.assert_count(
  'SELECT count(*) FROM public.app_users', 1,
  'baseline app_users remain self-only'
);
SELECT test_support_directory.assert_count(
  'SELECT count(*) FROM public.team_member_directory_invoker_probe', 1,
  'security-invoker view cannot widen F07 RLS'
);
ROLLBACK;
RESET ROLE;

-- Alternative 2: intuitive same-table policy is rejected as recursive.
CREATE POLICY memberships_same_team_recursive_probe
ON public.memberships
FOR SELECT
TO compras_directory_probe
USING (
  EXISTS (
    SELECT 1
    FROM public.memberships AS viewer
    WHERE viewer.team_id = memberships.team_id
      AND viewer.user_id = public.current_app_user_id()
      AND viewer.revoked_at IS NULL
  )
);

SET ROLE compras_directory_probe;
BEGIN;
SET LOCAL request.jwt.claims = '{"iss":"https://directory.demo.invalid","sub":"DEMO-DIR-A1"}';
SELECT test_support_directory.expect_sqlstate(
  'SELECT count(*) FROM public.memberships', '42P17',
  'self-referential memberships policy must fail with recursion'
);
ROLLBACK;
RESET ROLE;
DROP POLICY memberships_same_team_recursive_probe ON public.memberships;

-- Preferred design probe: sealed capability role, column-minimized grants,
-- targeted RLS policies and a security-barrier owner view.
CREATE ROLE compras_directory_view_owner_probe
  NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT NOBYPASSRLS;
GRANT USAGE ON SCHEMA public TO compras_directory_view_owner_probe;
GRANT SELECT (id, team_id, user_id, revoked_at)
  ON public.memberships TO compras_directory_view_owner_probe;
GRANT SELECT (id, display_name, disabled_at)
  ON public.app_users TO compras_directory_view_owner_probe;

CREATE POLICY memberships_directory_capability_probe
ON public.memberships
FOR SELECT
TO compras_directory_view_owner_probe
USING (revoked_at IS NULL);

CREATE POLICY app_users_directory_capability_probe
ON public.app_users
FOR SELECT
TO compras_directory_view_owner_probe
USING (disabled_at IS NULL);

CREATE VIEW public.team_member_directory_capability_probe
WITH (security_barrier = true, security_invoker = false)
AS
SELECT
  target.team_id,
  target.id AS membership_id,
  target_user.display_name
FROM public.memberships AS target
JOIN public.app_users AS target_user
  ON target_user.id = target.user_id
WHERE target.revoked_at IS NULL
  AND target_user.disabled_at IS NULL
  AND EXISTS (
    SELECT 1
    FROM public.memberships AS viewer
    WHERE viewer.team_id = target.team_id
      AND viewer.user_id = public.current_app_user_id()
      AND viewer.revoked_at IS NULL
  );

-- Ownership transfer requires schema CREATE privilege for the target owner.
-- The proof grants it only for the transfer and revokes it immediately.
GRANT CREATE ON SCHEMA public TO compras_directory_view_owner_probe;
ALTER VIEW public.team_member_directory_capability_probe
  OWNER TO compras_directory_view_owner_probe;
REVOKE CREATE ON SCHEMA public FROM compras_directory_view_owner_probe;
REVOKE ALL ON public.team_member_directory_capability_probe FROM PUBLIC;
GRANT SELECT ON public.team_member_directory_capability_probe TO compras_directory_probe;

DO $$
DECLARE
  capability_oid oid;
BEGIN
  SELECT oid INTO capability_oid
  FROM pg_catalog.pg_roles
  WHERE rolname = 'compras_directory_view_owner_probe';

  IF capability_oid IS NULL THEN
    RAISE EXCEPTION 'directory capability role missing';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM pg_catalog.pg_roles
    WHERE oid = capability_oid
      AND (rolcanlogin OR rolsuper OR rolbypassrls OR rolcreatedb OR rolcreaterole)
  ) THEN
    RAISE EXCEPTION 'directory capability role has unsafe attributes';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM pg_catalog.pg_class AS c
    JOIN pg_catalog.pg_namespace AS n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public'
      AND c.relname IN ('memberships', 'app_users')
      AND c.relowner = capability_oid
  ) THEN
    RAISE EXCEPTION 'directory capability must not own protected base tables';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM pg_catalog.pg_auth_members
    WHERE roleid = capability_oid OR member = capability_oid
  ) THEN
    RAISE EXCEPTION 'directory capability role must remain sealed from role membership';
  END IF;

  IF has_column_privilege(
       'compras_directory_view_owner_probe', 'public.app_users',
       'auth_issuer', 'SELECT'
     )
     OR has_column_privilege(
       'compras_directory_view_owner_probe', 'public.app_users',
       'auth_subject', 'SELECT'
     ) THEN
    RAISE EXCEPTION 'directory capability must not read external auth identifiers';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_catalog.pg_class AS c
    JOIN pg_catalog.pg_namespace AS n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public'
      AND c.relname = 'team_member_directory_capability_probe'
      AND c.relkind = 'v'
      AND c.relowner = capability_oid
      AND COALESCE(c.reloptions, ARRAY[]::text[]) @> ARRAY['security_barrier=true']
      AND COALESCE(c.reloptions, ARRAY[]::text[]) @> ARRAY['security_invoker=false']
  ) THEN
    RAISE EXCEPTION 'capability view ownership/options are not explicit';
  END IF;
END;
$$;

SELECT test_support_directory.assert_count(
  $$SELECT count(*)
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'team_member_directory_capability_probe'
      AND column_name IN ('auth_issuer', 'auth_subject')$$,
  0,
  'directory projection excludes external auth columns'
);

-- SET ROLE permission is determined from session_user. SET ROLE in earlier
-- probes ran under a postgres session, so use SESSION AUTHORIZATION here to
-- model a genuinely non-privileged authenticated database principal.
SET SESSION AUTHORIZATION compras_directory_probe;

SELECT test_support_directory.assert_true(
  $$SELECT NOT pg_catalog.pg_has_role(
      current_user,
      'compras_directory_view_owner_probe',
      'MEMBER'
    )$$,
  'operational probe is not member of capability role'
);
SELECT test_support_directory.expect_sqlstate(
  'SET ROLE compras_directory_view_owner_probe', '42501',
  'operational role cannot set capability role'
);

-- Active A1 sees exactly the active, non-disabled directory of team A.
BEGIN;
SET LOCAL request.jwt.claims = '{"iss":"https://directory.demo.invalid","sub":"DEMO-DIR-A1"}';
SELECT test_support_directory.assert_count(
  'SELECT count(*) FROM public.team_member_directory_capability_probe', 2,
  'A1 sees A1 and A2 only'
);
SELECT test_support_directory.assert_count(
  $$SELECT count(*)
    FROM public.team_member_directory_capability_probe
    WHERE membership_id = '73000000-0000-4000-8000-000000000002'$$,
  1,
  'A1 resolves teammate A2'
);
SELECT test_support_directory.assert_count(
  $$SELECT count(*)
    FROM public.team_member_directory_capability_probe
    WHERE membership_id = '73000000-0000-4000-8000-000000000003'$$,
  0,
  'known B1 membership UUID stays cross-team hidden'
);
SELECT test_support_directory.assert_count(
  $$SELECT count(*)
    FROM public.team_member_directory_capability_probe
    WHERE membership_id = '73000000-0000-4000-8000-000000000004'$$,
  0,
  'disabled target is excluded'
);
SELECT test_support_directory.assert_count(
  $$SELECT count(*)
    FROM public.team_member_directory_capability_probe
    WHERE membership_id = '73000000-0000-4000-8000-000000000005'$$,
  0,
  'revoked target is excluded'
);
-- Capability policies are targeted to the view owner and do not widen direct
-- caller access to the protected tables.
SELECT test_support_directory.assert_count(
  'SELECT count(*) FROM public.memberships', 1,
  'caller direct memberships remains self-only'
);
SELECT test_support_directory.assert_count(
  'SELECT count(*) FROM public.app_users', 1,
  'caller direct app_users remains self-only'
);
ROLLBACK;

BEGIN;
SET LOCAL request.jwt.claims = '{"iss":"https://directory.demo.invalid","sub":"DEMO-DIR-B1"}';
SELECT test_support_directory.assert_count(
  'SELECT count(*) FROM public.team_member_directory_capability_probe', 1,
  'B1 sees only team B directory'
);
ROLLBACK;

BEGIN;
SET LOCAL request.jwt.claims = '{"iss":"https://directory.demo.invalid","sub":"DEMO-DIR-NO-MEMBERSHIP"}';
SELECT test_support_directory.assert_count(
  'SELECT count(*) FROM public.team_member_directory_capability_probe', 0,
  'known user without membership sees no directory'
);
ROLLBACK;

BEGIN;
SET LOCAL request.jwt.claims = '{"iss":"https://directory.demo.invalid","sub":"DEMO-DIR-DISABLED"}';
SELECT test_support_directory.assert_count(
  'SELECT count(*) FROM public.team_member_directory_capability_probe', 0,
  'disabled caller sees no directory'
);
ROLLBACK;

BEGIN;
SET LOCAL request.jwt.claims = '{"iss":"https://directory.demo.invalid","sub":"DEMO-DIR-REVOKED"}';
SELECT test_support_directory.assert_count(
  'SELECT count(*) FROM public.team_member_directory_capability_probe', 0,
  'caller with only revoked membership sees no directory'
);
ROLLBACK;

BEGIN;
SET LOCAL request.jwt.claims = '{"iss":"https://directory.demo.invalid","sub":"DEMO-DIR-UNKNOWN"}';
SELECT test_support_directory.assert_count(
  'SELECT count(*) FROM public.team_member_directory_capability_probe', 0,
  'unknown identity sees no directory'
);
ROLLBACK;

RESET SESSION AUTHORIZATION;

DROP VIEW public.team_member_directory_invoker_probe;
DROP VIEW public.team_member_directory_capability_probe;
DROP POLICY memberships_directory_capability_probe ON public.memberships;
DROP POLICY app_users_directory_capability_probe ON public.app_users;
DROP OWNED BY compras_directory_view_owner_probe;
DROP ROLE compras_directory_view_owner_probe;
DROP OWNED BY compras_directory_probe;
DROP ROLE compras_directory_probe;
DROP SCHEMA test_support_directory CASCADE;
