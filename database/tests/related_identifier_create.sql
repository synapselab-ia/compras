\set ON_ERROR_STOP on

-- F41 related identifier creation proof. Every identity, UUID and value is
-- synthetic and deliberately non-operational.
CREATE SCHEMA test_support_f41;

CREATE FUNCTION test_support_f41.assert_text(
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

CREATE FUNCTION test_support_f41.assert_count(
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

CREATE FUNCTION test_support_f41.assert_event_collision_rolls_back()
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
  outcome text;
  row_count bigint;
BEGIN
  BEGIN
    SELECT public.create_related_identifier(
      '41140000-0000-4000-8000-000000000001'::uuid,
      '41150000-0000-4000-8000-000000000199'::uuid,
      'DEMO-kind',
      'DEMO event collision rollback',
      'DEMO-source',
      'DEMO-note',
      '41160000-0000-4000-8000-000000000999'::uuid
    )
    INTO outcome;

    RAISE EXCEPTION 'event collision should have failed, got %', outcome;
  EXCEPTION
    WHEN unique_violation THEN
      NULL;
  END;

  SELECT count(*)
  INTO row_count
  FROM public.related_identifiers
  WHERE id = '41150000-0000-4000-8000-000000000199'::uuid;

  IF row_count <> 0 THEN
    RAISE EXCEPTION 'event collision left a partial related identifier row';
  END IF;
END;
$$;

GRANT USAGE ON SCHEMA test_support_f41 TO compras_domain_runtime_f41_ci;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA test_support_f41 TO compras_domain_runtime_f41_ci;

INSERT INTO public.teams (id, name, created_at) VALUES
  ('41110000-0000-4000-8000-000000000001', 'DEMO-F41-Team-A-Target', '2026-01-01T00:00:00Z'),
  ('41110000-0000-4000-8000-000000000002', 'DEMO-F41-Team-B-Cross', '2026-01-01T00:00:00Z'),
  ('41110000-0000-4000-8000-000000000003', 'DEMO-F41-Team-C-Multi', '2026-01-01T00:00:00Z'),
  ('41110000-0000-4000-8000-000000000004', 'DEMO-F41-Team-D-Other', '2026-01-01T00:00:00Z'),
  ('41110000-0000-4000-8000-000000000005', 'DEMO-F41-Team-E-Revoked', '2026-01-01T00:00:00Z'),
  ('41110000-0000-4000-8000-000000000006', 'DEMO-F41-Team-F-Disabled', '2026-01-01T00:00:00Z');

INSERT INTO public.app_users (
  id, auth_issuer, auth_subject, display_name, created_at, disabled_at
) VALUES
  ('41120000-0000-4000-8000-000000000001', 'urn:compras:better-auth:self-hosted:v1', 'DEMO-F41-A', 'DEMO F41 A', '2026-01-01T00:00:00Z', NULL),
  ('41120000-0000-4000-8000-000000000002', 'urn:compras:better-auth:self-hosted:v1', 'DEMO-F41-B', 'DEMO F41 B', '2026-01-01T00:00:00Z', NULL),
  ('41120000-0000-4000-8000-000000000003', 'urn:compras:better-auth:self-hosted:v1', 'DEMO-F41-C', 'DEMO F41 C', '2026-01-01T00:00:00Z', NULL),
  ('41120000-0000-4000-8000-000000000004', 'urn:compras:better-auth:self-hosted:v1', 'DEMO-F41-C-DISABLED-MEMBER', 'DEMO F41 C disabled member', '2026-01-01T00:00:00Z', '2026-01-02T00:00:00Z'),
  ('41120000-0000-4000-8000-000000000005', 'urn:compras:better-auth:self-hosted:v1', 'DEMO-F41-REVOKED', 'DEMO F41 revoked', '2026-01-01T00:00:00Z', NULL),
  ('41120000-0000-4000-8000-000000000006', 'urn:compras:better-auth:self-hosted:v1', 'DEMO-F41-DISABLED', 'DEMO F41 disabled', '2026-01-01T00:00:00Z', '2026-01-02T00:00:00Z'),
  ('41120000-0000-4000-8000-000000000008', 'urn:compras:better-auth:self-hosted:v1', 'DEMO-F41-NO-MEMBERSHIP', 'DEMO F41 no membership', '2026-01-01T00:00:00Z', NULL);

INSERT INTO public.memberships (
  id, team_id, user_id, joined_at, revoked_at
) VALUES
  ('41130000-0000-4000-8000-000000000001', '41110000-0000-4000-8000-000000000001', '41120000-0000-4000-8000-000000000001', '2026-01-01T00:00:00Z', NULL),
  ('41130000-0000-4000-8000-000000000002', '41110000-0000-4000-8000-000000000004', '41120000-0000-4000-8000-000000000001', '2026-01-01T00:00:00Z', NULL),
  ('41130000-0000-4000-8000-000000000003', '41110000-0000-4000-8000-000000000002', '41120000-0000-4000-8000-000000000002', '2026-01-01T00:00:00Z', NULL),
  ('41130000-0000-4000-8000-000000000004', '41110000-0000-4000-8000-000000000003', '41120000-0000-4000-8000-000000000003', '2026-01-01T00:00:00Z', NULL),
  ('41130000-0000-4000-8000-000000000005', '41110000-0000-4000-8000-000000000003', '41120000-0000-4000-8000-000000000004', '2026-01-01T00:00:00Z', NULL),
  ('41130000-0000-4000-8000-000000000006', '41110000-0000-4000-8000-000000000005', '41120000-0000-4000-8000-000000000005', '2026-01-01T00:00:00Z', '2026-01-02T00:00:00Z'),
  ('41130000-0000-4000-8000-000000000007', '41110000-0000-4000-8000-000000000006', '41120000-0000-4000-8000-000000000006', '2026-01-01T00:00:00Z', NULL);

INSERT INTO public.contractings (
  id, team_id, object, created_at, updated_at, archived_at, cancelled_at
) VALUES
  ('41140000-0000-4000-8000-000000000001', '41110000-0000-4000-8000-000000000001', 'DEMO F41 target', '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z', NULL, NULL),
  ('41140000-0000-4000-8000-000000000002', '41110000-0000-4000-8000-000000000002', 'DEMO F41 cross', '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z', NULL, NULL),
  ('41140000-0000-4000-8000-000000000003', '41110000-0000-4000-8000-000000000003', 'DEMO F41 multi', '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z', NULL, NULL),
  ('41140000-0000-4000-8000-000000000004', '41110000-0000-4000-8000-000000000001', 'DEMO F41 archived', '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z', '2026-01-02T00:00:00Z', NULL),
  ('41140000-0000-4000-8000-000000000005', '41110000-0000-4000-8000-000000000001', 'DEMO F41 cancelled', '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z', NULL, '2026-01-02T00:00:00Z'),
  ('41140000-0000-4000-8000-000000000006', '41110000-0000-4000-8000-000000000005', 'DEMO F41 revoked', '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z', NULL, NULL),
  ('41140000-0000-4000-8000-000000000007', '41110000-0000-4000-8000-000000000006', 'DEMO F41 disabled', '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z', NULL, NULL);

-- Rows used to prove collision and replay denial. They are created directly by
-- the disposable test administrator so no application capability is widened.
INSERT INTO public.related_identifiers (
  id, team_id, contracting_id, identifier_kind, identifier_value,
  source_system, note, linked_at, unlinked_at
) VALUES
  ('41150000-0000-4000-8000-000000000090', '41110000-0000-4000-8000-000000000002', '41140000-0000-4000-8000-000000000002', 'DEMO-kind', 'DEMO cross collision', 'DEMO-source', 'DEMO-note', '2026-01-01T00:00:00Z', NULL),
  ('41150000-0000-4000-8000-000000000091', '41110000-0000-4000-8000-000000000001', '41140000-0000-4000-8000-000000000001', 'DEMO-kind', 'DEMO row without event', 'DEMO-source', 'DEMO-note', '2026-01-01T00:00:00Z', NULL),
  ('41150000-0000-4000-8000-000000000092', '41110000-0000-4000-8000-000000000001', '41140000-0000-4000-8000-000000000001', 'DEMO-kind', 'DEMO unlinked row', 'DEMO-source', 'DEMO-note', '2026-01-01T00:00:00Z', '2026-01-02T00:00:00Z'),
  ('41150000-0000-4000-8000-000000000093', '41110000-0000-4000-8000-000000000001', '41140000-0000-4000-8000-000000000001', 'DEMO-kind', 'DEMO duplicate canonical events', 'DEMO-source', 'DEMO-note', '2026-01-01T00:00:00Z', NULL);

INSERT INTO public.contracting_events (
  id, team_id, contracting_id, actor_membership_id, event_type, occurred_at,
  related_identifier_id, created_at
) VALUES
  ('41160000-0000-4000-8000-000000000093', '41110000-0000-4000-8000-000000000001', '41140000-0000-4000-8000-000000000001', '41130000-0000-4000-8000-000000000001', 'related_identifier_linked', '2026-01-01T00:00:00Z', '41150000-0000-4000-8000-000000000093', '2026-01-01T00:00:00Z'),
  ('41160000-0000-4000-8000-000000000094', '41110000-0000-4000-8000-000000000001', '41140000-0000-4000-8000-000000000001', '41130000-0000-4000-8000-000000000001', 'related_identifier_linked', '2026-01-01T00:00:00Z', '41150000-0000-4000-8000-000000000093', '2026-01-01T00:00:00Z'),
  ('41160000-0000-4000-8000-000000000999', '41110000-0000-4000-8000-000000000001', '41140000-0000-4000-8000-000000000001', '41130000-0000-4000-8000-000000000001', 'DEMO-existing-event-id', '2026-01-01T00:00:00Z', NULL, '2026-01-01T00:00:00Z');

-- Structural least-privilege and authority-isolation proof.
DO $structure$
DECLARE
  capability_oid oid;
  migrator_oid oid;
BEGIN
  SELECT oid INTO capability_oid
  FROM pg_catalog.pg_roles
  WHERE rolname = 'compras_related_identifier_create_owner';

  SELECT oid INTO migrator_oid
  FROM pg_catalog.pg_roles
  WHERE rolname = 'compras_f41_migrator_ci';

  IF capability_oid IS NULL OR migrator_oid IS NULL THEN
    RAISE EXCEPTION 'F41 structural roles are missing';
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
    RAISE EXCEPTION 'F41 capability owner is privileged';
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
    RAISE EXCEPTION 'F41 capability owner has usable membership';
  END IF;

  IF NOT pg_catalog.has_function_privilege(
       'compras_domain_runtime_f41_ci',
       'public.create_related_identifier(uuid,uuid,text,text,text,text,uuid)',
       'EXECUTE'
     ) THEN
    RAISE EXCEPTION 'F41 domain runtime is missing narrow EXECUTE';
  END IF;

  IF pg_catalog.has_any_column_privilege('compras_domain_runtime_f41_ci', 'public.related_identifiers', 'INSERT')
     OR pg_catalog.has_any_column_privilege('compras_domain_runtime_f41_ci', 'public.related_identifiers', 'UPDATE')
     OR pg_catalog.has_table_privilege('compras_domain_runtime_f41_ci', 'public.related_identifiers', 'DELETE')
     OR pg_catalog.has_any_column_privilege('compras_domain_runtime_f41_ci', 'public.contracting_events', 'INSERT')
     OR pg_catalog.has_any_column_privilege('compras_domain_runtime_f41_ci', 'public.contractings', 'UPDATE') THEN
    RAISE EXCEPTION 'F41 domain runtime received direct DML';
  END IF;

  IF NOT pg_catalog.has_column_privilege('compras_related_identifier_create_owner', 'public.related_identifiers', 'id', 'INSERT')
     OR NOT pg_catalog.has_column_privilege('compras_related_identifier_create_owner', 'public.related_identifiers', 'identifier_value', 'INSERT')
     OR NOT pg_catalog.has_column_privilege('compras_related_identifier_create_owner', 'public.related_identifiers', 'linked_at', 'INSERT')
     OR pg_catalog.has_column_privilege('compras_related_identifier_create_owner', 'public.related_identifiers', 'unlinked_at', 'INSERT')
     OR pg_catalog.has_any_column_privilege('compras_related_identifier_create_owner', 'public.related_identifiers', 'UPDATE')
     OR pg_catalog.has_table_privilege('compras_related_identifier_create_owner', 'public.related_identifiers', 'DELETE')
     OR pg_catalog.has_any_column_privilege('compras_related_identifier_create_owner', 'public.contractings', 'UPDATE')
     OR pg_catalog.has_table_privilege('compras_related_identifier_create_owner', 'public.contracting_events', 'UPDATE')
     OR pg_catalog.has_table_privilege('compras_related_identifier_create_owner', 'public.contracting_events', 'DELETE') THEN
    RAISE EXCEPTION 'F41 capability authority is broader than approved';
  END IF;

  IF pg_catalog.has_function_privilege('compras_next_action_mutation_owner', 'public.create_related_identifier(uuid,uuid,text,text,text,text,uuid)', 'EXECUTE')
     OR pg_catalog.has_function_privilege('compras_contracting_create_owner', 'public.create_related_identifier(uuid,uuid,text,text,text,text,uuid)', 'EXECUTE')
     OR pg_catalog.has_function_privilege('compras_contracting_object_mutation_owner', 'public.create_related_identifier(uuid,uuid,text,text,text,text,uuid)', 'EXECUTE')
     OR pg_catalog.has_function_privilege('compras_contracting_item_create_owner', 'public.create_related_identifier(uuid,uuid,text,text,text,text,uuid)', 'EXECUTE')
     OR pg_catalog.has_function_privilege('compras_contracting_item_mutation_owner', 'public.create_related_identifier(uuid,uuid,text,text,text,text,uuid)', 'EXECUTE') THEN
    RAISE EXCEPTION 'prior write capability gained F41 EXECUTE';
  END IF;

  IF pg_catalog.has_function_privilege('compras_related_identifier_create_owner', 'public.mutate_contracting_next_action(uuid,text,text,uuid)', 'EXECUTE')
     OR pg_catalog.has_function_privilege('compras_related_identifier_create_owner', 'public.create_contracting_minimal(uuid,text,uuid)', 'EXECUTE')
     OR pg_catalog.has_function_privilege('compras_related_identifier_create_owner', 'public.mutate_contracting_object(uuid,text,text,uuid)', 'EXECUTE')
     OR pg_catalog.has_function_privilege('compras_related_identifier_create_owner', 'public.create_contracting_item(uuid,text,numeric,text,text,uuid,uuid)', 'EXECUTE')
     OR pg_catalog.has_function_privilege('compras_related_identifier_create_owner', 'public.mutate_contracting_item_fields(uuid,uuid,text,numeric,text,text,text,numeric,text,text,uuid,uuid,uuid,uuid)', 'EXECUTE') THEN
    RAISE EXCEPTION 'F41 capability inherited prior write EXECUTE';
  END IF;
END;
$structure$;

SET SESSION AUTHORIZATION compras_domain_runtime_f41_ci;

-- Missing, malformed and unknown identity contexts fail closed.
BEGIN;
SELECT set_config('request.jwt.claims', '', true);
SELECT test_support_f41.assert_text(
  $$SELECT public.create_related_identifier(
    '41140000-0000-4000-8000-000000000001',
    '41150000-0000-4000-8000-000000000001',
    'DEMO-kind', 'DEMO missing claims', 'DEMO-source', 'DEMO-note',
    '41160000-0000-4000-8000-000000000001')$$,
  'denied', 'missing claims deny'
);
COMMIT;

BEGIN;
SELECT set_config('request.jwt.claims', 'not-json', true);
SELECT test_support_f41.assert_text(
  $$SELECT public.create_related_identifier(
    '41140000-0000-4000-8000-000000000001',
    '41150000-0000-4000-8000-000000000002',
    'DEMO-kind', 'DEMO malformed claims', 'DEMO-source', 'DEMO-note',
    '41160000-0000-4000-8000-000000000002')$$,
  'denied', 'malformed claims deny'
);
COMMIT;

BEGIN;
SELECT set_config('request.jwt.claims', '{"iss":"urn:compras:better-auth:self-hosted:v1","sub":"DEMO-F41-UNKNOWN"}', true);
SELECT test_support_f41.assert_text(
  $$SELECT public.create_related_identifier(
    '41140000-0000-4000-8000-000000000001',
    '41150000-0000-4000-8000-000000000003',
    'DEMO-kind', 'DEMO unknown identity', 'DEMO-source', 'DEMO-note',
    '41160000-0000-4000-8000-000000000003')$$,
  'denied', 'unknown identity deny'
);
COMMIT;

-- Disabled user and revoked membership fail closed.
BEGIN;
SELECT set_config('request.jwt.claims', '{"iss":"urn:compras:better-auth:self-hosted:v1","sub":"DEMO-F41-DISABLED"}', true);
SELECT test_support_f41.assert_text(
  $$SELECT public.create_related_identifier(
    '41140000-0000-4000-8000-000000000007',
    '41150000-0000-4000-8000-000000000004',
    'DEMO-kind', 'DEMO disabled', 'DEMO-source', 'DEMO-note',
    '41160000-0000-4000-8000-000000000004')$$,
  'denied', 'disabled app user deny'
);
COMMIT;

BEGIN;
SELECT set_config('request.jwt.claims', '{"iss":"urn:compras:better-auth:self-hosted:v1","sub":"DEMO-F41-REVOKED"}', true);
SELECT test_support_f41.assert_text(
  $$SELECT public.create_related_identifier(
    '41140000-0000-4000-8000-000000000006',
    '41150000-0000-4000-8000-000000000005',
    'DEMO-kind', 'DEMO revoked', 'DEMO-source', 'DEMO-note',
    '41160000-0000-4000-8000-000000000005')$$,
  'denied', 'revoked membership deny'
);
COMMIT;

BEGIN;
SELECT set_config('request.jwt.claims', '{"iss":"urn:compras:better-auth:self-hosted:v1","sub":"DEMO-F41-NO-MEMBERSHIP"}', true);
SELECT test_support_f41.assert_text(
  $SELECT public.create_related_identifier(
    '41140000-0000-4000-8000-000000000001',
    '41150000-0000-4000-8000-000000000006',
    'DEMO-kind', 'DEMO no membership', 'DEMO-source', 'DEMO-note',
    '41160000-0000-4000-8000-000000000006')$,
  'denied', 'active app user without membership deny'
);
COMMIT;

-- The target-team guard permits A even though the same user also belongs to
-- another team. Text and nullability are preserved exactly.
BEGIN;
SELECT set_config('request.jwt.claims', '{"iss":"urn:compras:better-auth:self-hosted:v1","sub":"DEMO-F41-A"}', true);
SELECT test_support_f41.assert_text(
  $$SELECT public.create_related_identifier(
    '41140000-0000-4000-8000-000000000001',
    '41150000-0000-4000-8000-000000000101',
    NULL, '', '   ', '  DEMO note  ',
    '41160000-0000-4000-8000-000000000101')$$,
  'created', 'authorized create'
);
SELECT test_support_f41.assert_text(
  $$SELECT identifier_kind FROM public.related_identifiers
    WHERE id='41150000-0000-4000-8000-000000000101'$$,
  NULL, 'nullable identifier kind preserved'
);
SELECT test_support_f41.assert_text(
  $$SELECT identifier_value FROM public.related_identifiers
    WHERE id='41150000-0000-4000-8000-000000000101'$$,
  '', 'empty identifier value preserved'
);
SELECT test_support_f41.assert_text(
  $$SELECT source_system FROM public.related_identifiers
    WHERE id='41150000-0000-4000-8000-000000000101'$$,
  '   ', 'spaces-only source preserved'
);
SELECT test_support_f41.assert_text(
  $$SELECT note FROM public.related_identifiers
    WHERE id='41150000-0000-4000-8000-000000000101'$$,
  '  DEMO note  ', 'leading and trailing note spaces preserved'
);
SELECT test_support_f41.assert_count(
  $$SELECT count(*) FROM public.contracting_events AS event
    JOIN public.related_identifiers AS related
      ON related.id=event.related_identifier_id
     AND related.team_id=event.team_id
     AND related.contracting_id=event.contracting_id
    WHERE related.id='41150000-0000-4000-8000-000000000101'
      AND event.event_type='related_identifier_linked'
      AND event.actor_membership_id='41130000-0000-4000-8000-000000000001'
      AND event.field_key IS NULL
      AND event.old_value IS NULL
      AND event.new_value IS NULL
      AND event.note IS NULL
      AND event.item_id IS NULL
      AND event.occurred_at=related.linked_at
      AND event.created_at=related.linked_at$$,
  1, 'canonical audit event exact'
);
SELECT test_support_f41.assert_text(
  $$SELECT updated_at::text FROM public.contractings
    WHERE id='41140000-0000-4000-8000-000000000001'$$,
  '2026-01-01 00:00:00+00', 'parent updated_at unchanged'
);
COMMIT;

-- An exact retry uses the same prepared row UUID, accepts a fresh event UUID,
-- and returns replay success without creating another event.
BEGIN;
SELECT set_config('request.jwt.claims', '{"iss":"urn:compras:better-auth:self-hosted:v1","sub":"DEMO-F41-A"}', true);
SELECT test_support_f41.assert_text(
  $$SELECT public.create_related_identifier(
    '41140000-0000-4000-8000-000000000001',
    '41150000-0000-4000-8000-000000000101',
    NULL, '', '   ', '  DEMO note  ',
    '41160000-0000-4000-8000-000000000102')$$,
  'already-linked', 'exact authorized replay'
);
SELECT test_support_f41.assert_count(
  $$SELECT count(*) FROM public.contracting_events
    WHERE related_identifier_id='41150000-0000-4000-8000-000000000101'
      AND event_type='related_identifier_linked'$$,
  1, 'replay adds no second event'
);
SELECT test_support_f41.assert_text(
  $SELECT public.create_related_identifier(
    '41140000-0000-4000-8000-000000000001',
    '41150000-0000-4000-8000-000000000101',
    NULL, 'DIFFERENT', '   ', '  DEMO note  ',
    '41160000-0000-4000-8000-000000000103')$,
  'denied', 'same UUID divergent payload deny'
);
SELECT test_support_f41.assert_text(
  $SELECT public.create_related_identifier(
    '41140000-0000-4000-8000-000000000001',
    '41150000-0000-4000-8000-000000000101',
    '', '', '   ', '  DEMO note  ',
    '41160000-0000-4000-8000-000000000104')$,
  'denied', 'null and empty identifier kind remain distinct on replay'
);
COMMIT;

-- Replay requires exactly one canonical event and never accepts an unlinked row.
BEGIN;
SELECT set_config('request.jwt.claims', '{"iss":"urn:compras:better-auth:self-hosted:v1","sub":"DEMO-F41-A"}', true);
SELECT test_support_f41.assert_text(
  $$SELECT public.create_related_identifier(
    '41140000-0000-4000-8000-000000000001',
    '41150000-0000-4000-8000-000000000091',
    'DEMO-kind', 'DEMO row without event', 'DEMO-source', 'DEMO-note',
    '41160000-0000-4000-8000-000000000191')$$,
  'denied', 'row without canonical event deny'
);
SELECT test_support_f41.assert_text(
  $$SELECT public.create_related_identifier(
    '41140000-0000-4000-8000-000000000001',
    '41150000-0000-4000-8000-000000000092',
    'DEMO-kind', 'DEMO unlinked row', 'DEMO-source', 'DEMO-note',
    '41160000-0000-4000-8000-000000000192')$$,
  'denied', 'unlinked row replay deny'
);
SELECT test_support_f41.assert_text(
  $$SELECT public.create_related_identifier(
    '41140000-0000-4000-8000-000000000001',
    '41150000-0000-4000-8000-000000000093',
    'DEMO-kind', 'DEMO duplicate canonical events', 'DEMO-source', 'DEMO-note',
    '41160000-0000-4000-8000-000000000193')$$,
  'denied', 'duplicate canonical events replay deny'
);
COMMIT;

-- Cross-team, nonexistent and inactive resources collapse to the same denial.
-- A global PK collision in another team must not become an existence oracle.
BEGIN;
SELECT set_config('request.jwt.claims', '{"iss":"urn:compras:better-auth:self-hosted:v1","sub":"DEMO-F41-A"}', true);
SELECT test_support_f41.assert_text(
  $$SELECT public.create_related_identifier(
    '41140000-0000-4000-8000-000000000001',
    '41150000-0000-4000-8000-000000000090',
    'DEMO-kind', 'DEMO cross collision', 'DEMO-source', 'DEMO-note',
    '41160000-0000-4000-8000-000000000201')$$,
  'denied', 'cross-team related UUID collision deny'
);
SELECT test_support_f41.assert_text(
  $$SELECT public.create_related_identifier(
    '41140000-0000-4000-8000-000000000002',
    '41150000-0000-4000-8000-000000000201',
    'DEMO-kind', 'DEMO cross target', 'DEMO-source', 'DEMO-note',
    '41160000-0000-4000-8000-000000000202')$$,
  'denied', 'cross-team contracting deny'
);
SELECT test_support_f41.assert_text(
  $$SELECT public.create_related_identifier(
    '41140000-0000-4000-8000-000000009999',
    '41150000-0000-4000-8000-000000000202',
    'DEMO-kind', 'DEMO nonexistent', 'DEMO-source', 'DEMO-note',
    '41160000-0000-4000-8000-000000000203')$$,
  'denied', 'nonexistent contracting deny'
);
SELECT test_support_f41.assert_text(
  $$SELECT public.create_related_identifier(
    '41140000-0000-4000-8000-000000000004',
    '41150000-0000-4000-8000-000000000203',
    'DEMO-kind', 'DEMO archived', 'DEMO-source', 'DEMO-note',
    '41160000-0000-4000-8000-000000000204')$$,
  'denied', 'archived contracting deny'
);
SELECT test_support_f41.assert_text(
  $$SELECT public.create_related_identifier(
    '41140000-0000-4000-8000-000000000005',
    '41150000-0000-4000-8000-000000000204',
    'DEMO-kind', 'DEMO cancelled', 'DEMO-source', 'DEMO-note',
    '41160000-0000-4000-8000-000000000205')$$,
  'denied', 'cancelled contracting deny'
);
COMMIT;

-- A second non-revoked membership in the target team blocks even when that
-- second app_user is disabled.
BEGIN;
SELECT set_config('request.jwt.claims', '{"iss":"urn:compras:better-auth:self-hosted:v1","sub":"DEMO-F41-C"}', true);
SELECT test_support_f41.assert_text(
  $$SELECT public.create_related_identifier(
    '41140000-0000-4000-8000-000000000003',
    '41150000-0000-4000-8000-000000000205',
    'DEMO-kind', 'DEMO multi', 'DEMO-source', 'DEMO-note',
    '41160000-0000-4000-8000-000000000206')$$,
  'denied', 'second non-revoked member deny including disabled app_user'
);
COMMIT;

-- No business deduplication exists. Distinct prepared UUIDs may carry the same
-- exact textual payload. Empty, spaces and null remain separate states.
BEGIN;
SELECT set_config('request.jwt.claims', '{"iss":"urn:compras:better-auth:self-hosted:v1","sub":"DEMO-F41-A"}', true);
SELECT test_support_f41.assert_text(
  $$SELECT public.create_related_identifier(
    '41140000-0000-4000-8000-000000000001',
    '41150000-0000-4000-8000-000000000110',
    '', '   ', NULL, '',
    '41160000-0000-4000-8000-000000000110')$$,
  'created', 'spaces payload first UUID'
);
SELECT test_support_f41.assert_text(
  $$SELECT public.create_related_identifier(
    '41140000-0000-4000-8000-000000000001',
    '41150000-0000-4000-8000-000000000111',
    '', '   ', NULL, '',
    '41160000-0000-4000-8000-000000000111')$$,
  'created', 'spaces payload second UUID'
);
SELECT test_support_f41.assert_count(
  $$SELECT count(*) FROM public.related_identifiers
    WHERE id IN (
      '41150000-0000-4000-8000-000000000110',
      '41150000-0000-4000-8000-000000000111'
    )
      AND identifier_kind=''
      AND identifier_value='   '
      AND source_system IS NULL
      AND note=''$$,
  2, 'distinct UUIDs with identical payload remain distinct'
);
SELECT test_support_f41.assert_text(
  $$SELECT public.create_related_identifier(
    '41140000-0000-4000-8000-000000000001',
    '41150000-0000-4000-8000-000000000112',
    '  kind  ', '  value  ', '', NULL,
    '41160000-0000-4000-8000-000000000112')$$,
  'created', 'leading and trailing spaces payload'
);
SELECT test_support_f41.assert_text(
  $$SELECT identifier_value FROM public.related_identifiers
    WHERE id='41150000-0000-4000-8000-000000000112'$$,
  '  value  ', 'identifier value spaces preserved exactly'
);
SELECT test_support_f41.assert_text(
  $$SELECT public.create_related_identifier(
    '41140000-0000-4000-8000-000000000001',
    '41150000-0000-4000-8000-000000000113',
    'DEMO-kind', NULL, 'DEMO-source', 'DEMO-note',
    '41160000-0000-4000-8000-000000000113')$$,
  'denied', 'null identifier value denied by physical contract'
);
COMMIT;

-- Event insertion failure is part of the same transaction and must roll back
-- the new related identifier row.
BEGIN;
SELECT set_config('request.jwt.claims', '{"iss":"urn:compras:better-auth:self-hosted:v1","sub":"DEMO-F41-A"}', true);
SELECT test_support_f41.assert_event_collision_rolls_back();
COMMIT;

RESET SESSION AUTHORIZATION;

-- Re-check parent timeline invariant outside operational RLS.
SELECT test_support_f41.assert_text(
  $$SELECT updated_at::text FROM public.contractings
    WHERE id='41140000-0000-4000-8000-000000000001'$$,
  '2026-01-01 00:00:00+00', 'parent updated_at remains unchanged after all F41 creates'
);
