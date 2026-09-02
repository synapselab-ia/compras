\set ON_ERROR_STOP on

-- F12 protected-detail proof. All identities, UUIDs and content are artificial.
CREATE SCHEMA test_support_detail;

CREATE FUNCTION test_support_detail.assert_count(
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

CREATE FUNCTION test_support_detail.assert_text(
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

INSERT INTO public.teams (id, name, created_at) VALUES
  ('91000000-0000-4000-8000-000000000001', 'DEMO-F12-Team-A', '2026-01-01T00:00:00Z'),
  ('91000000-0000-4000-8000-000000000002', 'DEMO-F12-Team-B', '2026-01-01T00:00:00Z');

INSERT INTO public.app_users (
  id, auth_issuer, auth_subject, display_name, created_at, disabled_at
) VALUES
  ('92000000-0000-4000-8000-000000000001', 'https://f12.demo.invalid', 'DEMO-F12-A1', 'DEMO F12 A1', '2026-01-01T00:00:00Z', NULL),
  ('92000000-0000-4000-8000-000000000002', 'https://f12.demo.invalid', 'DEMO-F12-A2', 'DEMO F12 A2', '2026-01-01T00:00:00Z', NULL),
  ('92000000-0000-4000-8000-000000000003', 'https://f12.demo.invalid', 'DEMO-F12-B1', 'DEMO F12 B1', '2026-01-01T00:00:00Z', NULL),
  ('92000000-0000-4000-8000-000000000004', 'https://f12.demo.invalid', 'DEMO-F12-DISABLED', 'DEMO F12 Disabled', '2026-01-01T00:00:00Z', '2026-01-02T00:00:00Z'),
  ('92000000-0000-4000-8000-000000000005', 'https://f12.demo.invalid', 'DEMO-F12-REVOKED', 'DEMO F12 Revoked', '2026-01-01T00:00:00Z', NULL),
  ('92000000-0000-4000-8000-000000000006', 'https://f12.demo.invalid', 'DEMO-F12-NO-MEMBERSHIP', 'DEMO F12 No Membership', '2026-01-01T00:00:00Z', NULL);

INSERT INTO public.memberships (
  id, team_id, user_id, joined_at, revoked_at
) VALUES
  ('93000000-0000-4000-8000-000000000001', '91000000-0000-4000-8000-000000000001', '92000000-0000-4000-8000-000000000001', '2026-01-01T00:00:00Z', NULL),
  ('93000000-0000-4000-8000-000000000002', '91000000-0000-4000-8000-000000000001', '92000000-0000-4000-8000-000000000002', '2026-01-01T00:00:00Z', NULL),
  ('93000000-0000-4000-8000-000000000003', '91000000-0000-4000-8000-000000000002', '92000000-0000-4000-8000-000000000003', '2026-01-01T00:00:00Z', NULL),
  ('93000000-0000-4000-8000-000000000004', '91000000-0000-4000-8000-000000000001', '92000000-0000-4000-8000-000000000004', '2026-01-01T00:00:00Z', NULL),
  ('93000000-0000-4000-8000-000000000005', '91000000-0000-4000-8000-000000000001', '92000000-0000-4000-8000-000000000005', '2026-01-01T00:00:00Z', '2026-01-02T00:00:00Z');

INSERT INTO public.contractings (
  id, team_id, object, responsible_membership_id, stage_key, status_key,
  waiting_type, waiting_reference, waiting_since, waiting_reason, next_action,
  created_by_membership_id, created_at, updated_at, archived_at, cancelled_at
) VALUES
  ('94000000-0000-4000-8000-000000000001', '91000000-0000-4000-8000-000000000001', 'DEMO F12 Contracting A', '93000000-0000-4000-8000-000000000002', 'stage-demo', 'status-demo', 'setor-demo', 'referencia-demo', '2026-01-03T00:00:00Z', 'motivo-demo', 'acao-demo', '93000000-0000-4000-8000-000000000001', '2026-01-01T00:00:00Z', '2026-01-04T00:00:00Z', NULL, NULL),
  ('94000000-0000-4000-8000-000000000002', '91000000-0000-4000-8000-000000000002', 'DEMO F12 Contracting B', '93000000-0000-4000-8000-000000000003', 'stage-demo', 'status-demo', NULL, NULL, NULL, NULL, 'acao-demo-b', '93000000-0000-4000-8000-000000000003', '2026-01-01T00:00:00Z', '2026-01-04T00:00:00Z', NULL, NULL),
  ('94000000-0000-4000-8000-000000000003', '91000000-0000-4000-8000-000000000001', 'DEMO F12 Disabled Responsible', '93000000-0000-4000-8000-000000000004', NULL, NULL, NULL, NULL, NULL, NULL, NULL, '93000000-0000-4000-8000-000000000001', '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z', NULL, NULL),
  ('94000000-0000-4000-8000-000000000004', '91000000-0000-4000-8000-000000000001', 'DEMO F12 Revoked Responsible', '93000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, '93000000-0000-4000-8000-000000000001', '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z', NULL, NULL);

INSERT INTO public.related_identifiers (
  id, team_id, contracting_id, identifier_kind, identifier_value, source_system, note, linked_at, unlinked_at
) VALUES
  ('95000000-0000-4000-8000-000000000001', '91000000-0000-4000-8000-000000000001', '94000000-0000-4000-8000-000000000001', 'kind-demo', 'DEMO-A-REF', 'demo-system', NULL, '2026-01-02T00:00:00Z', NULL),
  ('95000000-0000-4000-8000-000000000002', '91000000-0000-4000-8000-000000000001', '94000000-0000-4000-8000-000000000001', 'kind-demo', 'DEMO-A-OLD', 'demo-system', NULL, '2026-01-01T00:00:00Z', '2026-01-05T00:00:00Z'),
  ('95000000-0000-4000-8000-000000000003', '91000000-0000-4000-8000-000000000002', '94000000-0000-4000-8000-000000000002', 'kind-demo', 'DEMO-B-REF', 'demo-system', NULL, '2026-01-02T00:00:00Z', NULL);

INSERT INTO public.contracting_items (
  id, team_id, contracting_id, ordinal, description, quantity, unit, catalog_code, created_at, updated_at, retired_at
) VALUES
  ('96000000-0000-4000-8000-000000000001', '91000000-0000-4000-8000-000000000001', '94000000-0000-4000-8000-000000000001', 1, 'DEMO A Item', 3, 'UN', NULL, '2026-01-01T00:00:00Z', '2026-01-02T00:00:00Z', NULL),
  ('96000000-0000-4000-8000-000000000002', '91000000-0000-4000-8000-000000000001', '94000000-0000-4000-8000-000000000001', 2, 'DEMO A Retired', 1, 'UN', NULL, '2026-01-01T00:00:00Z', '2026-01-02T00:00:00Z', '2026-01-05T00:00:00Z'),
  ('96000000-0000-4000-8000-000000000003', '91000000-0000-4000-8000-000000000002', '94000000-0000-4000-8000-000000000002', 1, 'DEMO B Item', 4, 'UN', NULL, '2026-01-01T00:00:00Z', '2026-01-02T00:00:00Z', NULL);

INSERT INTO public.contracting_events (
  id, team_id, contracting_id, actor_membership_id, event_type, occurred_at,
  field_key, old_value, new_value, note, related_identifier_id, item_id, created_at
) VALUES
  ('97000000-0000-4000-8000-000000000001', '91000000-0000-4000-8000-000000000001', '94000000-0000-4000-8000-000000000001', '93000000-0000-4000-8000-000000000001', 'event-demo-old', '2026-01-03T00:00:00Z', NULL, NULL, NULL, NULL, NULL, NULL, '2026-01-03T00:00:00Z'),
  ('97000000-0000-4000-8000-000000000002', '91000000-0000-4000-8000-000000000001', '94000000-0000-4000-8000-000000000001', '93000000-0000-4000-8000-000000000001', 'event-demo-new', '2026-01-04T00:00:00Z', 'status-demo', 'old-demo', 'new-demo', NULL, NULL, NULL, '2026-01-04T00:00:00Z'),
  ('97000000-0000-4000-8000-000000000003', '91000000-0000-4000-8000-000000000002', '94000000-0000-4000-8000-000000000002', '93000000-0000-4000-8000-000000000003', 'event-demo-b', '2026-01-04T00:00:00Z', NULL, NULL, NULL, NULL, NULL, NULL, '2026-01-04T00:00:00Z');

CREATE ROLE compras_detail_app_test
  NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT NOREPLICATION NOBYPASSRLS;
GRANT USAGE ON SCHEMA public, test_support_detail TO compras_detail_app_test;
GRANT SELECT ON public.app_users, public.memberships, public.contractings,
  public.related_identifiers, public.contracting_items, public.contracting_events
  TO compras_detail_app_test;
GRANT SELECT ON public.team_member_directory TO compras_detail_app_test;
GRANT EXECUTE ON FUNCTION public.current_auth_issuer() TO compras_detail_app_test;
GRANT EXECUTE ON FUNCTION public.current_auth_subject() TO compras_detail_app_test;
GRANT EXECUTE ON FUNCTION public.current_app_user_id() TO compras_detail_app_test;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA test_support_detail TO compras_detail_app_test;

SET SESSION AUTHORIZATION compras_detail_app_test;

SELECT test_support_detail.assert_count(
  $$SELECT count(*) FROM public.contractings
    WHERE id = '94000000-0000-4000-8000-000000000001'::uuid$$,
  0,
  'missing context sees no known contracting'
);

BEGIN;
SET LOCAL request.jwt.claims = '{"iss":"https://f12.demo.invalid","sub":"DEMO-F12-A1"}';
SELECT test_support_detail.assert_count(
  $$SELECT count(*) FROM public.contractings
    WHERE id = '94000000-0000-4000-8000-000000000001'::uuid$$,
  1,
  'A1 reads own-team contracting by known UUID'
);
SELECT test_support_detail.assert_count(
  $$SELECT count(*) FROM public.contractings
    WHERE id = '94000000-0000-4000-8000-000000000002'::uuid$$,
  0,
  'A1 known cross-team UUID is invisible'
);
SELECT test_support_detail.assert_text(
  $$SELECT d.display_name
    FROM public.contractings AS c
    LEFT JOIN public.team_member_directory AS d
      ON d.team_id = c.team_id
     AND d.membership_id = c.responsible_membership_id
    WHERE c.id = '94000000-0000-4000-8000-000000000001'::uuid$$,
  'DEMO F12 A2',
  'A1 resolves active teammate responsible through directory'
);
SELECT test_support_detail.assert_count(
  $$SELECT count(*)
    FROM public.contractings AS c
    LEFT JOIN public.team_member_directory AS d
      ON d.team_id = c.team_id
     AND d.membership_id = c.responsible_membership_id
    WHERE c.id IN (
      '94000000-0000-4000-8000-000000000003'::uuid,
      '94000000-0000-4000-8000-000000000004'::uuid
    )
      AND d.display_name IS NULL$$,
  2,
  'disabled or revoked responsible remains generic'
);
SELECT test_support_detail.assert_count(
  $$SELECT count(*) FROM public.related_identifiers
    WHERE contracting_id = '94000000-0000-4000-8000-000000000001'::uuid
      AND unlinked_at IS NULL$$,
  1,
  'A1 sees only active identifiers of own contracting'
);
SELECT test_support_detail.assert_count(
  $$SELECT count(*) FROM public.contracting_items
    WHERE contracting_id = '94000000-0000-4000-8000-000000000001'::uuid
      AND retired_at IS NULL$$,
  1,
  'A1 sees only active items of own contracting'
);
SELECT test_support_detail.assert_count(
  $$SELECT count(*) FROM public.contracting_events
    WHERE contracting_id = '94000000-0000-4000-8000-000000000001'::uuid$$,
  2,
  'A1 sees only events of own contracting'
);
SELECT test_support_detail.assert_text(
  $$SELECT event_type FROM public.contracting_events
    WHERE contracting_id = '94000000-0000-4000-8000-000000000001'::uuid
    ORDER BY occurred_at DESC, id ASC
    LIMIT 1$$,
  'event-demo-new',
  'timeline is deterministically ordered by occurred_at'
);
SELECT test_support_detail.assert_count(
  $$SELECT count(*) FROM public.related_identifiers
    WHERE contracting_id = '94000000-0000-4000-8000-000000000002'::uuid$$,
  0,
  'cross-team identifiers stay invisible'
);
SELECT test_support_detail.assert_count(
  $$SELECT count(*) FROM public.contracting_items
    WHERE contracting_id = '94000000-0000-4000-8000-000000000002'::uuid$$,
  0,
  'cross-team items stay invisible'
);
SELECT test_support_detail.assert_count(
  $$SELECT count(*) FROM public.contracting_events
    WHERE contracting_id = '94000000-0000-4000-8000-000000000002'::uuid$$,
  0,
  'cross-team events stay invisible'
);
ROLLBACK;

BEGIN;
SET LOCAL request.jwt.claims = '{"iss":"https://f12.demo.invalid","sub":"DEMO-F12-B1"}';
SELECT test_support_detail.assert_count(
  $$SELECT count(*) FROM public.contractings
    WHERE id = '94000000-0000-4000-8000-000000000002'::uuid$$,
  1,
  'B1 reads own-team contracting'
);
SELECT test_support_detail.assert_count(
  $$SELECT count(*) FROM public.contractings
    WHERE id = '94000000-0000-4000-8000-000000000001'::uuid$$,
  0,
  'B1 cannot read team A contracting'
);
ROLLBACK;

BEGIN;
SET LOCAL request.jwt.claims = '{"iss":"https://f12.demo.invalid","sub":"DEMO-F12-DISABLED"}';
SELECT test_support_detail.assert_count('SELECT count(*) FROM public.contractings', 0, 'disabled caller sees zero contractings');
ROLLBACK;
BEGIN;
SET LOCAL request.jwt.claims = '{"iss":"https://f12.demo.invalid","sub":"DEMO-F12-REVOKED"}';
SELECT test_support_detail.assert_count('SELECT count(*) FROM public.contractings', 0, 'revoked caller sees zero contractings');
ROLLBACK;
BEGIN;
SET LOCAL request.jwt.claims = '{"iss":"https://f12.demo.invalid","sub":"DEMO-F12-NO-MEMBERSHIP"}';
SELECT test_support_detail.assert_count('SELECT count(*) FROM public.contractings', 0, 'caller without membership sees zero contractings');
ROLLBACK;
BEGIN;
SET LOCAL request.jwt.claims = '{"iss":"https://f12.demo.invalid","sub":"DEMO-F12-UNKNOWN"}';
SELECT test_support_detail.assert_count('SELECT count(*) FROM public.contractings', 0, 'unknown caller sees zero contractings');
ROLLBACK;

RESET SESSION AUTHORIZATION;
DROP OWNED BY compras_detail_app_test;
DROP ROLE compras_detail_app_test;
DROP SCHEMA test_support_detail CASCADE;
