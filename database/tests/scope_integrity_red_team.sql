\set ON_ERROR_STOP on

-- Additional adversarial checks for same-scope composite foreign keys.
-- All values are artificial and limited to the disposable CI database.
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

SELECT pg_temp.expect_fk($sql$
  INSERT INTO contractings (
    id, team_id, object, created_by_membership_id, created_at, updated_at
  ) VALUES (
    '30000000-0000-4000-8000-000000000097',
    '00000000-0000-4000-8000-000000000001',
    'DEMO-Cross-Team-Creator',
    '20000000-0000-4000-8000-000000000002',
    '2026-01-04T00:00:00Z',
    '2026-01-04T00:00:00Z'
  )
$sql$, 'cross-team created_by membership');

SELECT pg_temp.expect_fk($sql$
  INSERT INTO contracting_events (
    id, team_id, contracting_id, event_type, occurred_at, created_at
  ) VALUES (
    '60000000-0000-4000-8000-000000000095',
    '00000000-0000-4000-8000-000000000002',
    '30000000-0000-4000-8000-000000000001',
    'DEMO-CROSS-TEAM-CONTRACTING',
    '2026-01-04T00:00:00Z',
    '2026-01-04T00:00:00Z'
  )
$sql$, 'cross-team event contracting');

SELECT pg_temp.expect_fk($sql$
  INSERT INTO contracting_events (
    id, team_id, contracting_id, event_type, occurred_at, related_identifier_id, created_at
  ) VALUES (
    '60000000-0000-4000-8000-000000000096',
    '00000000-0000-4000-8000-000000000001',
    '30000000-0000-4000-8000-000000000001',
    'DEMO-CROSS-TEAM-IDENTIFIER',
    '2026-01-04T00:00:00Z',
    '40000000-0000-4000-8000-000000000004',
    '2026-01-04T00:00:00Z'
  )
$sql$, 'event identifier from another team');
