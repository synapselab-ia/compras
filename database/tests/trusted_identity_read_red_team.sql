\set ON_ERROR_STOP on

-- Additional adversarial coverage after the main trusted-identity suite.
-- Fixtures are the artificial rows created by trusted_identity_read_policies.sql.
CREATE SCHEMA test_support_rt;

CREATE FUNCTION test_support_rt.assert_count(query_text text, expected bigint, case_name text)
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

CREATE ROLE compras_read_red_team
  NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT NOBYPASSRLS;
GRANT USAGE ON SCHEMA public, test_support_rt TO compras_read_red_team;
GRANT SELECT ON TABLE
  teams, app_users, memberships, contractings,
  related_identifiers, contracting_items, contracting_events
TO compras_read_red_team;
GRANT EXECUTE ON FUNCTION public.current_auth_issuer() TO compras_read_red_team;
GRANT EXECUTE ON FUNCTION public.current_auth_subject() TO compras_read_red_team;
GRANT EXECUTE ON FUNCTION public.current_app_user_id() TO compras_read_red_team;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA test_support_rt TO compras_read_red_team;

SET ROLE compras_read_red_team;

-- issuer + subject are an exact composite identity. A correct subject under a
-- different issuer must not resolve to the existing app_user.
BEGIN;
SET LOCAL request.jwt.claims = '{"iss":"https://other-issuer.demo.invalid","sub":"DEMO-READ-A"}';
SELECT test_support_rt.assert_count('SELECT count(*) FROM public.app_users', 0, 'same subject wrong issuer');
SELECT test_support_rt.assert_count('SELECT count(*) FROM public.teams', 0, 'wrong issuer no team');
ROLLBACK;

-- Helpers must not silently normalize externally verified identifiers.
BEGIN;
SET LOCAL request.jwt.claims = '{"iss":" https://issuer.demo.invalid","sub":"DEMO-READ-A"}';
SELECT test_support_rt.assert_count('SELECT count(*) FROM public.app_users', 0, 'padded issuer not normalized');
ROLLBACK;

BEGIN;
SET LOCAL request.jwt.claims = '{"iss":"https://issuer.demo.invalid","sub":"DEMO-READ-A "}';
SELECT test_support_rt.assert_count('SELECT count(*) FROM public.app_users', 0, 'padded subject not normalized');
ROLLBACK;

-- A known user without membership receives no operational row in any table.
BEGIN;
SET LOCAL request.jwt.claims = '{"iss":"https://issuer.demo.invalid","sub":"DEMO-NO-MEMBERSHIP"}';
SELECT test_support_rt.assert_count('SELECT count(*) FROM public.contractings', 0, 'no-membership contractings');
SELECT test_support_rt.assert_count('SELECT count(*) FROM public.related_identifiers', 0, 'no-membership identifiers');
SELECT test_support_rt.assert_count('SELECT count(*) FROM public.contracting_items', 0, 'no-membership items');
SELECT test_support_rt.assert_count('SELECT count(*) FROM public.contracting_events', 0, 'no-membership events');
ROLLBACK;

-- Revocation denies every operational table, not only the contracting root.
BEGIN;
SET LOCAL request.jwt.claims = '{"iss":"https://issuer.demo.invalid","sub":"DEMO-REVOKED"}';
SELECT test_support_rt.assert_count('SELECT count(*) FROM public.contractings', 0, 'revoked contractings');
SELECT test_support_rt.assert_count('SELECT count(*) FROM public.related_identifiers', 0, 'revoked identifiers');
SELECT test_support_rt.assert_count('SELECT count(*) FROM public.contracting_items', 0, 'revoked items');
SELECT test_support_rt.assert_count('SELECT count(*) FROM public.contracting_events', 0, 'revoked events');
ROLLBACK;

-- A disabled app_user cannot retain access through an otherwise active membership.
BEGIN;
SET LOCAL request.jwt.claims = '{"iss":"https://issuer.demo.invalid","sub":"DEMO-DISABLED"}';
SELECT test_support_rt.assert_count('SELECT count(*) FROM public.contractings', 0, 'disabled contractings');
SELECT test_support_rt.assert_count('SELECT count(*) FROM public.related_identifiers', 0, 'disabled identifiers');
SELECT test_support_rt.assert_count('SELECT count(*) FROM public.contracting_items', 0, 'disabled items');
SELECT test_support_rt.assert_count('SELECT count(*) FROM public.contracting_events', 0, 'disabled events');
ROLLBACK;

RESET ROLE;

DROP OWNED BY compras_read_red_team;
DROP ROLE compras_read_red_team;
DROP SCHEMA test_support_rt CASCADE;
