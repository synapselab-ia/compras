\set ON_ERROR_STOP on

-- All values below are artificial and exist only to exercise schema invariants.
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

DO $$
BEGIN
  BEGIN
    INSERT INTO contractings (
      id, team_id, object, responsible_membership_id, created_at, updated_at
    ) VALUES (
      '30000000-0000-4000-8000-000000000099',
      '00000000-0000-4000-8000-000000000001',
      'DEMO-Cross-Team-Responsible-Rejected',
      '20000000-0000-4000-8000-000000000002',
      '2026-01-01T00:00:00Z',
      '2026-01-01T00:00:00Z'
    );
    RAISE EXCEPTION 'cross-team responsible membership was accepted';
  EXCEPTION WHEN foreign_key_violation THEN
    NULL;
  END;
END $$;

INSERT INTO related_identifiers (
  id, team_id, contracting_id, identifier_kind, identifier_value, linked_at
) VALUES
  ('40000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000001', '30000000-0000-4000-8000-000000000001', 'DEMO-KIND-A', 'DEMO-REF-001', '2026-01-01T00:00:00Z'),
  ('40000000-0000-4000-8000-000000000002', '00000000-0000-4000-8000-000000000001', '30000000-0000-4000-8000-000000000001', 'DEMO-KIND-B', 'DEMO-REF-002', '2026-01-01T00:00:00Z'),
  ('40000000-0000-4000-8000-000000000003', '00000000-0000-4000-8000-000000000001', '30000000-0000-4000-8000-000000000003', NULL, 'DEMO-REF-003', '2026-01-01T00:00:00Z'),
  ('40000000-0000-4000-8000-000000000004', '00000000-0000-4000-8000-000000000002', '30000000-0000-4000-8000-000000000002', NULL, 'DEMO-REF-004', '2026-01-01T00:00:00Z');

DO $$
BEGIN
  IF (SELECT count(*) FROM related_identifiers WHERE contracting_id = '30000000-0000-4000-8000-000000000001') <> 2 THEN
    RAISE EXCEPTION 'identifier cardinality N was not preserved';
  END IF;

  BEGIN
    INSERT INTO related_identifiers (id, team_id, contracting_id, identifier_value, linked_at)
    VALUES (
      '40000000-0000-4000-8000-000000000099',
      '00000000-0000-4000-8000-000000000002',
      '30000000-0000-4000-8000-000000000001',
      'DEMO-CROSS-TEAM-REF',
      '2026-01-01T00:00:00Z'
    );
    RAISE EXCEPTION 'cross-team related identifier was accepted';
  EXCEPTION WHEN foreign_key_violation THEN
    NULL;
  END;
END $$;

INSERT INTO contracting_items (
  id, team_id, contracting_id, ordinal, description, quantity, unit, created_at, updated_at
) VALUES
  ('50000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000001', '30000000-0000-4000-8000-000000000001', 1, 'DEMO-Item-A', 1.25, 'DEMO-UNIT', '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z'),
  ('50000000-0000-4000-8000-000000000002', '00000000-0000-4000-8000-000000000001', '30000000-0000-4000-8000-000000000001', 2, 'DEMO-Item-No-Invented-Quantity-Rule', -0.5, NULL, '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z'),
  ('50000000-0000-4000-8000-000000000003', '00000000-0000-4000-8000-000000000001', '30000000-0000-4000-8000-000000000003', 1, 'DEMO-Item-C', NULL, NULL, '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z'),
  ('50000000-0000-4000-8000-000000000004', '00000000-0000-4000-8000-000000000002', '30000000-0000-4000-8000-000000000002', 1, 'DEMO-Item-B', NULL, NULL, '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z');

DO $$
BEGIN
  BEGIN
    INSERT INTO contracting_items (
      id, team_id, contracting_id, ordinal, description, created_at, updated_at
    ) VALUES (
      '50000000-0000-4000-8000-000000000098',
      '00000000-0000-4000-8000-000000000001',
      '30000000-0000-4000-8000-000000000001',
      1,
      'DEMO-Duplicate-Ordinal-Rejected',
      '2026-01-01T00:00:00Z',
      '2026-01-01T00:00:00Z'
    );
    RAISE EXCEPTION 'duplicate ordinal was accepted';
  EXCEPTION WHEN unique_violation THEN
    NULL;
  END;

  BEGIN
    INSERT INTO contracting_items (
      id, team_id, contracting_id, ordinal, description, created_at, updated_at
    ) VALUES (
      '50000000-0000-4000-8000-000000000099',
      '00000000-0000-4000-8000-000000000002',
      '30000000-0000-4000-8000-000000000001',
      99,
      'DEMO-Cross-Team-Item-Rejected',
      '2026-01-01T00:00:00Z',
      '2026-01-01T00:00:00Z'
    );
    RAISE EXCEPTION 'cross-team item was accepted';
  EXCEPTION WHEN foreign_key_violation THEN
    NULL;
  END;
END $$;

INSERT INTO contracting_events (
  id, team_id, contracting_id, actor_membership_id, event_type, occurred_at,
  note, related_identifier_id, item_id, created_at
) VALUES (
  '60000000-0000-4000-8000-000000000001',
  '00000000-0000-4000-8000-000000000001',
  '30000000-0000-4000-8000-000000000001',
  '20000000-0000-4000-8000-000000000001',
  'DEMO-EVENT',
  '2026-01-02T00:00:00Z',
  'DEMO-Event-A',
  '40000000-0000-4000-8000-000000000001',
  '50000000-0000-4000-8000-000000000001',
  '2026-01-02T00:00:00Z'
);

DO $$
BEGIN
  BEGIN
    INSERT INTO contracting_events (
      id, team_id, contracting_id, actor_membership_id, event_type, occurred_at, created_at
    ) VALUES (
      '60000000-0000-4000-8000-000000000091',
      '00000000-0000-4000-8000-000000000001',
      '30000000-0000-4000-8000-000000000001',
      '20000000-0000-4000-8000-000000000002',
      'DEMO-CROSS-TEAM-ACTOR',
      '2026-01-02T00:00:00Z',
      '2026-01-02T00:00:00Z'
    );
    RAISE EXCEPTION 'cross-team event actor was accepted';
  EXCEPTION WHEN foreign_key_violation THEN
    NULL;
  END;

  BEGIN
    INSERT INTO contracting_events (
      id, team_id, contracting_id, event_type, occurred_at, related_identifier_id, created_at
    ) VALUES (
      '60000000-0000-4000-8000-000000000092',
      '00000000-0000-4000-8000-000000000001',
      '30000000-0000-4000-8000-000000000001',
      'DEMO-WRONG-CONTRACTING-IDENTIFIER',
      '2026-01-02T00:00:00Z',
      '40000000-0000-4000-8000-000000000003',
      '2026-01-02T00:00:00Z'
    );
    RAISE EXCEPTION 'event referenced identifier from another contracting';
  EXCEPTION WHEN foreign_key_violation THEN
    NULL;
  END;

  BEGIN
    INSERT INTO contracting_events (
      id, team_id, contracting_id, event_type, occurred_at, item_id, created_at
    ) VALUES (
      '60000000-0000-4000-8000-000000000093',
      '00000000-0000-4000-8000-000000000001',
      '30000000-0000-4000-8000-000000000001',
      'DEMO-WRONG-CONTRACTING-ITEM',
      '2026-01-02T00:00:00Z',
      '50000000-0000-4000-8000-000000000003',
      '2026-01-02T00:00:00Z'
    );
    RAISE EXCEPTION 'event referenced item from another contracting';
  EXCEPTION WHEN foreign_key_violation THEN
    NULL;
  END;

  BEGIN
    INSERT INTO contracting_events (
      id, team_id, contracting_id, event_type, occurred_at, item_id, created_at
    ) VALUES (
      '60000000-0000-4000-8000-000000000094',
      '00000000-0000-4000-8000-000000000001',
      '30000000-0000-4000-8000-000000000001',
      'DEMO-CROSS-TEAM-ITEM',
      '2026-01-02T00:00:00Z',
      '50000000-0000-4000-8000-000000000004',
      '2026-01-02T00:00:00Z'
    );
    RAISE EXCEPTION 'event referenced item from another team';
  EXCEPTION WHEN foreign_key_violation THEN
    NULL;
  END;
END $$;

DO $$
DECLARE
  secured_tables integer;
  permissive_policies integer;
BEGIN
  SELECT count(*) INTO secured_tables
  FROM pg_class c
  JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname = 'public'
    AND c.relname IN (
      'teams', 'app_users', 'memberships', 'contractings',
      'related_identifiers', 'contracting_items', 'contracting_events'
    )
    AND c.relrowsecurity
    AND c.relforcerowsecurity;

  IF secured_tables <> 7 THEN
    RAISE EXCEPTION 'all seven internal tables must have RLS enabled and forced';
  END IF;

  SELECT count(*) INTO permissive_policies
  FROM pg_policies
  WHERE schemaname = 'public'
    AND tablename IN (
      'teams', 'app_users', 'memberships', 'contractings',
      'related_identifiers', 'contracting_items', 'contracting_events'
    );

  IF permissive_policies <> 0 THEN
    RAISE EXCEPTION 'foundation must not contain permissive RLS policies';
  END IF;
END $$;

CREATE ROLE compras_operational_test
  NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT NOBYPASSRLS;
GRANT USAGE ON SCHEMA public TO compras_operational_test;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE
  teams,
  app_users,
  memberships,
  contractings,
  related_identifiers,
  contracting_items,
  contracting_events
TO compras_operational_test;

SET ROLE compras_operational_test;

DO $$
DECLARE
  touched bigint;
BEGIN
  IF (SELECT count(*) FROM contractings) <> 0 THEN
    RAISE EXCEPTION 'default-deny RLS exposed internal rows';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM contractings
    WHERE id = '30000000-0000-4000-8000-000000000001'
  ) THEN
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
    RAISE EXCEPTION 'update modified a row through default-deny RLS';
  END IF;

  DELETE FROM contractings
  WHERE id = '30000000-0000-4000-8000-000000000001';
  GET DIAGNOSTICS touched = ROW_COUNT;
  IF touched <> 0 THEN
    RAISE EXCEPTION 'delete removed a row through default-deny RLS';
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
END $$;

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
END $$;

DROP ROLE compras_operational_test;
