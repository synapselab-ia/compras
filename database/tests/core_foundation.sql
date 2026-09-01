\set ON_ERROR_STOP on

-- All values in this file are artificial and exist only to exercise schema invariants.
CREATE FUNCTION pg_temp.expect_fk(statement text, case_name text)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  BEGIN
    EXECUTE statement;
  EXCEPTION WHEN foreign_key_violation THEN
    RETURN;
  END;
  RAISE EXCEPTION '%: expected foreign_key_violation', case_name;
END;
$$;

CREATE FUNCTION pg_temp.expect_unique(statement text, case_name text)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  BEGIN
    EXECUTE statement;
  EXCEPTION WHEN unique_violation THEN
    RETURN;
  END;
  RAISE EXCEPTION '%: expected unique_violation', case_name;
END;
$$;

INSERT INTO teams (id, name, created_at) VALUES
  ('00000000-0000-4000-8000-000000000001', 'DEMO-Team-A', '2026-01-01T00:00:00Z'),
  ('00000000-0000-4000-8000-000000000002', 'DEMO-Team-B', '2026-01-01T00:00:00Z');

INSERT INTO app_users (id, auth_issuer, auth_subject, display_name, created_at) VALUES
  ('10000000-0000-4000-8000-000000000001', 'https://issuer.demo.invalid', 'DEMO-SUBJECT-A', 'DEMO-User-A', '2026-01-01T00:00:00Z'),
  ('10000000-0000-4000-8000-000000000002', 'https://issuer.demo.invalid', 'DEMO-SUBJECT-B', 'DEMO-User-B', '2026-01-01T00:00:00Z');

INSERT INTO memberships (id, team_id, user_id, joined_at) VALUES
  ('20000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000001', '2026-01-01T00:00:00Z'),
  ('20000000-0000-4000-8000-000000000002', '00000000-0000-4000-8000-000000000002', '10000000-0000-4000-8000-000000000002', '2026-01-01T00:00:00Z');

INSERT INTO contractings (
  id, team_id, object, responsible_membership_id, stage_key, status_key,
  next_action, created_by_membership_id, created_at, updated_at
) VALUES
  ('30000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000001', 'DEMO-Contracting-A', '20000000-0000-4000-8000-000000000001', 'DEMO-STAGE', 'DEMO-STATUS', 'DEMO-Next-A', '20000000-0000-4000-8000-000000000001', '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z'),
  ('30000000-0000-4000-8000-000000000002', '00000000-0000-4000-8000-000000000002', 'DEMO-Contracting-B', '20000000-0000-4000-8000-000000000002', NULL, NULL, NULL, '20000000-0000-4000-8000-000000000002', '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z'),
  ('30000000-0000-4000-8000-000000000003', '00000000-0000-4000-8000-000000000001', 'DEMO-Contracting-C', '20000000-0000-4000-8000-000000000001', NULL, NULL, NULL, '20000000-0000-4000-8000-000000000001', '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z');

SELECT pg_temp.expect_fk($sql$
  INSERT INTO contractings (id, team_id, object, responsible_membership_id, created_at, updated_at)
  VALUES ('30000000-0000-4000-8000-000000000099', '00000000-0000-4000-8000-000000000001',
          'DEMO-Cross-Team-Responsible', '20000000-0000-4000-8000-000000000002',
          '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z')
$sql$, 'cross-team responsible membership');

INSERT INTO related_identifiers (id, team_id, contracting_id, identifier_kind, identifier_value, linked_at) VALUES
  ('40000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000001', '30000000-0000-4000-8000-000000000001', 'DEMO-KIND-A', 'DEMO-REF-001', '2026-01-01T00:00:00Z'),
  ('40000000-0000-4000-8000-000000000002', '00000000-0000-4000-8000-000000000001', '30000000-0000-4000-8000-000000000001', 'DEMO-KIND-B', 'DEMO-REF-002', '2026-01-01T00:00:00Z'),
  ('40000000-0000-4000-8000-000000000003', '00000000-0000-4000-8000-000000000001', '30000000-0000-4000-8000-000000000003', NULL, 'DEMO-REF-003', '2026-01-01T00:00:00Z'),
  ('40000000-0000-4000-8000-000000000004', '00000000-0000-4000-8000-000000000002', '30000000-0000-4000-8000-000000000002', NULL, 'DEMO-REF-004', '2026-01-01T00:00:00Z');

DO $$
BEGIN
  IF (SELECT count(*) FROM related_identifiers WHERE contracting_id = '30000000-0000-4000-8000-000000000001') <> 2 THEN
    RAISE EXCEPTION 'identifier cardinality N was not preserved';
  END IF;
END;
$$;

SELECT pg_temp.expect_fk($sql$
  INSERT INTO related_identifiers (id, team_id, contracting_id, identifier_value, linked_at)
  VALUES ('40000000-0000-4000-8000-000000000099', '00000000-0000-4000-8000-000000000002',
          '30000000-0000-4000-8000-000000000001', 'DEMO-CROSS-TEAM-REF', '2026-01-01T00:00:00Z')
$sql$, 'cross-team related identifier');

INSERT INTO contracting_items (id, team_id, contracting_id, ordinal, description, quantity, unit, created_at, updated_at) VALUES
  ('50000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000001', '30000000-0000-4000-8000-000000000001', 1, 'DEMO-Item-A', 1.25, 'DEMO-UNIT', '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z'),
  ('50000000-0000-4000-8000-000000000002', '00000000-0000-4000-8000-000000000001', '30000000-0000-4000-8000-000000000001', 2, 'DEMO-No-Invented-Quantity-Rule', -0.5, NULL, '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z'),
  ('50000000-0000-4000-8000-000000000003', '00000000-0000-4000-8000-000000000001', '30000000-0000-4000-8000-000000000003', 1, 'DEMO-Item-C', NULL, NULL, '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z'),
  ('50000000-0000-4000-8000-000000000004', '00000000-0000-4000-8000-000000000002', '30000000-0000-4000-8000-000000000002', 1, 'DEMO-Item-B', NULL, NULL, '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z');

SELECT pg_temp.expect_unique($sql$
  INSERT INTO contracting_items (id, team_id, contracting_id, ordinal, description, created_at, updated_at)
  VALUES ('50000000-0000-4000-8000-000000000098', '00000000-0000-4000-8000-000000000001',
          '30000000-0000-4000-8000-000000000001', 1, 'DEMO-Duplicate-Ordinal',
          '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z')
$sql$, 'duplicate ordinal');

SELECT pg_temp.expect_fk($sql$
  INSERT INTO contracting_items (id, team_id, contracting_id, ordinal, description, created_at, updated_at)
  VALUES ('50000000-0000-4000-8000-000000000099', '00000000-0000-4000-8000-000000000002',
          '30000000-0000-4000-8000-000000000001', 99, 'DEMO-Cross-Team-Item',
          '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z')
$sql$, 'cross-team item');

INSERT INTO contracting_events (
  id, team_id, contracting_id, actor_membership_id, event_type, occurred_at,
  note, related_identifier_id, item_id, created_at
) VALUES (
  '60000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000001',
  '30000000-0000-4000-8000-000000000001', '20000000-0000-4000-8000-000000000001',
  'DEMO-EVENT', '2026-01-02T00:00:00Z', 'DEMO-Event-A',
  '40000000-0000-4000-8000-000000000001', '50000000-0000-4000-8000-000000000001',
  '2026-01-02T00:00:00Z'
);

SELECT pg_temp.expect_fk($sql$
  INSERT INTO contracting_events (id, team_id, contracting_id, actor_membership_id, event_type, occurred_at, created_at)
  VALUES ('60000000-0000-4000-8000-000000000091', '00000000-0000-4000-8000-000000000001',
          '30000000-0000-4000-8000-000000000001', '20000000-0000-4000-8000-000000000002',
          'DEMO-CROSS-TEAM-ACTOR', '2026-01-02T00:00:00Z', '2026-01-02T00:00:00Z')
$sql$, 'cross-team event actor');

SELECT pg_temp.expect_fk($sql$
  INSERT INTO contracting_events (id, team_id, contracting_id, event_type, occurred_at, related_identifier_id, created_at)
  VALUES ('60000000-0000-4000-8000-000000000092', '00000000-0000-4000-8000-000000000001',
          '30000000-0000-4000-8000-000000000001', 'DEMO-WRONG-CONTRACTING-IDENTIFIER',
          '2026-01-02T00:00:00Z', '40000000-0000-4000-8000-000000000003', '2026-01-02T00:00:00Z')
$sql$, 'event identifier from another contracting');

SELECT pg_temp.expect_fk($sql$
  INSERT INTO contracting_events (id, team_id, contracting_id, event_type, occurred_at, item_id, created_at)
  VALUES ('60000000-0000-4000-8000-000000000093', '00000000-0000-4000-8000-000000000001',
          '30000000-0000-4000-8000-000000000001', 'DEMO-WRONG-CONTRACTING-ITEM',
          '2026-01-02T00:00:00Z', '50000000-0000-4000-8000-000000000003', '2026-01-02T00:00:00Z')
$sql$, 'event item from another contracting');

SELECT pg_temp.expect_fk($sql$
  INSERT INTO contracting_events (id, team_id, contracting_id, event_type, occurred_at, item_id, created_at)
  VALUES ('60000000-0000-4000-8000-000000000094', '00000000-0000-4000-8000-000000000001',
          '30000000-0000-4000-8000-000000000001', 'DEMO-CROSS-TEAM-ITEM',
          '2026-01-02T00:00:00Z', '50000000-0000-4000-8000-000000000004', '2026-01-02T00:00:00Z')
$sql$, 'event item from another team');

DO $$
DECLARE
  secured_tables integer;
  policy_count integer;
BEGIN
  SELECT count(*) INTO secured_tables
  FROM pg_class c
  JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname = 'public'
    AND c.relname IN ('teams', 'app_users', 'memberships', 'contractings', 'related_identifiers', 'contracting_items', 'contracting_events')
    AND c.relrowsecurity
    AND c.relforcerowsecurity;
  IF secured_tables <> 7 THEN
    RAISE EXCEPTION 'all internal tables must have RLS enabled and forced';
  END IF;

  SELECT count(*) INTO policy_count
  FROM pg_policies
  WHERE schemaname = 'public'
    AND tablename IN ('teams', 'app_users', 'memberships', 'contractings', 'related_identifiers', 'contracting_items', 'contracting_events');
  IF policy_count <> 0 THEN
    RAISE EXCEPTION 'foundation must contain no RLS policy yet';
  END IF;
END;
$$;

-- This role exists only in the disposable test database. Broad test grants distinguish
-- RLS enforcement from a simple lack of table privileges; production migration grants none.
CREATE ROLE compras_operational_test
  NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT NOBYPASSRLS;
GRANT USAGE ON SCHEMA public TO compras_operational_test;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE
  teams, app_users, memberships, contractings, related_identifiers, contracting_items, contracting_events
TO compras_operational_test;

SET ROLE compras_operational_test;

DO $$
DECLARE
  touched bigint;
  visible_rows bigint;
BEGIN
  SELECT
    (SELECT count(*) FROM teams) +
    (SELECT count(*) FROM app_users) +
    (SELECT count(*) FROM memberships) +
    (SELECT count(*) FROM contractings) +
    (SELECT count(*) FROM related_identifiers) +
    (SELECT count(*) FROM contracting_items) +
    (SELECT count(*) FROM contracting_events)
  INTO visible_rows;
  IF visible_rows <> 0 THEN
    RAISE EXCEPTION 'default-deny RLS exposed internal rows';
  END IF;

  IF EXISTS (SELECT 1 FROM contractings WHERE id = '30000000-0000-4000-8000-000000000001') THEN
    RAISE EXCEPTION 'known UUID bypassed RLS';
  END IF;

  BEGIN
    INSERT INTO teams (id, name, created_at)
    VALUES ('00000000-0000-4000-8000-000000000099', 'DEMO-RLS-INSERT', '2026-01-03T00:00:00Z');
    RAISE EXCEPTION 'insert unexpectedly passed default-deny RLS';
  EXCEPTION WHEN insufficient_privilege THEN
    NULL;
  END;

  UPDATE contractings
  SET object = 'DEMO-RLS-UPDATE-SHOULD-NOT-HAPPEN'
  WHERE id = '30000000-0000-4000-8000-000000000001';
  GET DIAGNOSTICS touched = ROW_COUNT;
  IF touched <> 0 THEN
    RAISE EXCEPTION 'update modified a hidden row';
  END IF;

  DELETE FROM contractings
  WHERE id = '30000000-0000-4000-8000-000000000001';
  GET DIAGNOSTICS touched = ROW_COUNT;
  IF touched <> 0 THEN
    RAISE EXCEPTION 'delete removed a hidden row';
  END IF;

  UPDATE contracting_events
  SET note = 'DEMO-EVENT-MUTATION-SHOULD-NOT-HAPPEN'
  WHERE id = '60000000-0000-4000-8000-000000000001';
  GET DIAGNOSTICS touched = ROW_COUNT;
  IF touched <> 0 THEN
    RAISE EXCEPTION 'operational role mutated an event';
  END IF;

  DELETE FROM contracting_events
  WHERE id = '60000000-0000-4000-8000-000000000001';
  GET DIAGNOSTICS touched = ROW_COUNT;
  IF touched <> 0 THEN
    RAISE EXCEPTION 'operational role deleted an event';
  END IF;
END;
$$;

RESET ROLE;

DO $$
BEGIN
  IF (SELECT object FROM contractings WHERE id = '30000000-0000-4000-8000-000000000001') <> 'DEMO-Contracting-A' THEN
    RAISE EXCEPTION 'RLS update attempt changed persisted state';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM contracting_events
    WHERE id = '60000000-0000-4000-8000-000000000001'
      AND note = 'DEMO-Event-A'
  ) THEN
    RAISE EXCEPTION 'event immutability check failed';
  END IF;
END;
$$;

DROP OWNED BY compras_operational_test;
DROP ROLE compras_operational_test;
