\set ON_ERROR_STOP on

-- F44 adversarial proof. All identities and data are fictitious.
INSERT INTO public.teams (id, name, created_at, archived_at) VALUES
  ('44110000-0000-4000-8000-000000000001', 'DEMO-F44-Team-A', '2026-01-01T00:00:00Z', NULL),
  ('44110000-0000-4000-8000-000000000002', 'DEMO-F44-Team-B', '2026-01-01T00:00:00Z', NULL),
  ('44110000-0000-4000-8000-000000000003', 'DEMO-F44-Team-Multi', '2026-01-01T00:00:00Z', NULL),
  ('44110000-0000-4000-8000-000000000004', 'DEMO-F44-Team-Other', '2026-01-01T00:00:00Z', NULL),
  ('44110000-0000-4000-8000-000000000005', 'DEMO-F44-Team-Disabled', '2026-01-01T00:00:00Z', NULL),
  ('44110000-0000-4000-8000-000000000006', 'DEMO-F44-Team-Revoked', '2026-01-01T00:00:00Z', NULL);

INSERT INTO public.app_users (
  id, auth_issuer, auth_subject, display_name, created_at, disabled_at
) VALUES
  ('44120000-0000-4000-8000-000000000001', 'urn:compras:better-auth:self-hosted:v1', 'DEMO-F44-A', 'DEMO F44 A', '2026-01-01T00:00:00Z', NULL),
  ('44120000-0000-4000-8000-000000000002', 'urn:compras:better-auth:self-hosted:v1', 'DEMO-F44-B', 'DEMO F44 B', '2026-01-01T00:00:00Z', NULL),
  ('44120000-0000-4000-8000-000000000003', 'urn:compras:better-auth:self-hosted:v1', 'DEMO-F44-MULTI', 'DEMO F44 Multi', '2026-01-01T00:00:00Z', NULL),
  ('44120000-0000-4000-8000-000000000004', 'urn:compras:better-auth:self-hosted:v1', 'DEMO-F44-MULTI-DISABLED', 'DEMO F44 Multi Disabled', '2026-01-01T00:00:00Z', '2026-01-02T00:00:00Z'),
  ('44120000-0000-4000-8000-000000000005', 'urn:compras:better-auth:self-hosted:v1', 'DEMO-F44-DISABLED', 'DEMO F44 Disabled', '2026-01-01T00:00:00Z', '2026-01-02T00:00:00Z'),
  ('44120000-0000-4000-8000-000000000006', 'urn:compras:better-auth:self-hosted:v1', 'DEMO-F44-REVOKED', 'DEMO F44 Revoked', '2026-01-01T00:00:00Z', NULL),
  ('44120000-0000-4000-8000-000000000007', 'urn:compras:better-auth:self-hosted:v1', 'DEMO-F44-NO-MEMBERSHIP', 'DEMO F44 No Membership', '2026-01-01T00:00:00Z', NULL);

INSERT INTO public.memberships (id, team_id, user_id, joined_at, revoked_at) VALUES
  ('44130000-0000-4000-8000-000000000001', '44110000-0000-4000-8000-000000000001', '44120000-0000-4000-8000-000000000001', '2026-01-01T00:00:00Z', NULL),
  ('44130000-0000-4000-8000-000000000002', '44110000-0000-4000-8000-000000000002', '44120000-0000-4000-8000-000000000002', '2026-01-01T00:00:00Z', NULL),
  ('44130000-0000-4000-8000-000000000003', '44110000-0000-4000-8000-000000000003', '44120000-0000-4000-8000-000000000003', '2026-01-01T00:00:00Z', NULL),
  ('44130000-0000-4000-8000-000000000004', '44110000-0000-4000-8000-000000000003', '44120000-0000-4000-8000-000000000004', '2026-01-01T00:00:00Z', NULL),
  ('44130000-0000-4000-8000-000000000005', '44110000-0000-4000-8000-000000000005', '44120000-0000-4000-8000-000000000005', '2026-01-01T00:00:00Z', NULL),
  ('44130000-0000-4000-8000-000000000006', '44110000-0000-4000-8000-000000000006', '44120000-0000-4000-8000-000000000006', '2026-01-01T00:00:00Z', '2026-01-02T00:00:00Z'),
  ('44130000-0000-4000-8000-000000000007', '44110000-0000-4000-8000-000000000004', '44120000-0000-4000-8000-000000000001', '2026-01-01T00:00:00Z', NULL),
  ('44130000-0000-4000-8000-000000000008', '44110000-0000-4000-8000-000000000001', '44120000-0000-4000-8000-000000000002', '2025-01-01T00:00:00Z', '2025-02-01T00:00:00Z');

INSERT INTO public.contractings (
  id, team_id, object, created_at, updated_at, archived_at, cancelled_at
) VALUES
  ('44140000-0000-4000-8000-000000000001', '44110000-0000-4000-8000-000000000001', 'DEMO F44 active A', '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z', NULL, NULL),
  ('44140000-0000-4000-8000-000000000002', '44110000-0000-4000-8000-000000000002', 'DEMO F44 active B', '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z', NULL, NULL),
  ('44140000-0000-4000-8000-000000000003', '44110000-0000-4000-8000-000000000003', 'DEMO F44 multi', '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z', NULL, NULL),
  ('44140000-0000-4000-8000-000000000004', '44110000-0000-4000-8000-000000000001', 'DEMO F44 archived', '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z', '2026-01-02T00:00:00Z', NULL),
  ('44140000-0000-4000-8000-000000000005', '44110000-0000-4000-8000-000000000001', 'DEMO F44 cancelled', '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z', NULL, '2026-01-02T00:00:00Z'),
  ('44140000-0000-4000-8000-000000000006', '44110000-0000-4000-8000-000000000005', 'DEMO F44 disabled user target', '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z', NULL, NULL),
  ('44140000-0000-4000-8000-000000000007', '44110000-0000-4000-8000-000000000006', 'DEMO F44 revoked target', '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z', NULL, NULL);

-- Pre-existing collisions prove replay exactness and opacity.
INSERT INTO public.contracting_events (
  id, team_id, contracting_id, actor_membership_id, event_type, occurred_at,
  field_key, old_value, new_value, note, related_identifier_id, item_id, created_at
) VALUES
  ('44160000-0000-4000-8000-000000000090', '44110000-0000-4000-8000-000000000002', '44140000-0000-4000-8000-000000000002', '44130000-0000-4000-8000-000000000002', 'manual_note_added', '2026-01-01T00:00:00Z', NULL, NULL, NULL, 'DEMO cross collision', NULL, NULL, '2026-01-01T00:00:00Z'),
  ('44160000-0000-4000-8000-000000000091', '44110000-0000-4000-8000-000000000001', '44140000-0000-4000-8000-000000000001', '44130000-0000-4000-8000-000000000001', 'other_event', '2026-01-01T00:00:00Z', NULL, NULL, NULL, 'DEMO other type', NULL, NULL, '2026-01-01T00:00:00Z'),
  ('44160000-0000-4000-8000-000000000092', '44110000-0000-4000-8000-000000000001', '44140000-0000-4000-8000-000000000001', '44130000-0000-4000-8000-000000000008', 'manual_note_added', '2026-01-01T00:00:00Z', NULL, NULL, NULL, 'DEMO actor mismatch', NULL, NULL, '2026-01-01T00:00:00Z'),
  ('44160000-0000-4000-8000-000000000093', '44110000-0000-4000-8000-000000000001', '44140000-0000-4000-8000-000000000001', '44130000-0000-4000-8000-000000000001', 'manual_note_added', '2026-01-01T00:00:00Z', 'forged', NULL, NULL, 'DEMO bad shape', NULL, NULL, '2026-01-01T00:00:00Z');

DO $structure$
DECLARE
  capability_oid oid;
BEGIN
  SELECT oid INTO capability_oid FROM pg_catalog.pg_roles
  WHERE rolname = 'compras_manual_timeline_note_create_owner';

  IF capability_oid IS NULL OR EXISTS (
    SELECT 1 FROM pg_catalog.pg_roles WHERE oid = capability_oid AND (
      rolcanlogin OR rolsuper OR rolcreatedb OR rolcreaterole OR rolinherit
      OR rolreplication OR rolbypassrls OR rolconfig IS NOT NULL
    )
  ) THEN
    RAISE EXCEPTION 'F44 capability role is missing or unsafe';
  END IF;

  IF NOT pg_catalog.has_function_privilege(
       'compras_domain_runtime_f44_ci',
       'public.create_manual_timeline_note(uuid,uuid,text)', 'EXECUTE'
     ) THEN
    RAISE EXCEPTION 'F44 runtime is missing narrow EXECUTE';
  END IF;

  IF pg_catalog.has_any_column_privilege('compras_domain_runtime_f44_ci', 'public.contracting_events', 'INSERT')
     OR pg_catalog.has_table_privilege('compras_domain_runtime_f44_ci', 'public.contracting_events', 'UPDATE')
     OR pg_catalog.has_table_privilege('compras_domain_runtime_f44_ci', 'public.contracting_events', 'DELETE')
     OR pg_catalog.has_any_column_privilege('compras_domain_runtime_f44_ci', 'public.contractings', 'UPDATE') THEN
    RAISE EXCEPTION 'F44 runtime has direct DML';
  END IF;

  IF NOT pg_catalog.has_column_privilege('compras_manual_timeline_note_create_owner', 'public.contracting_events', 'id', 'INSERT')
     OR NOT pg_catalog.has_column_privilege('compras_manual_timeline_note_create_owner', 'public.contracting_events', 'note', 'INSERT')
     OR pg_catalog.has_column_privilege('compras_manual_timeline_note_create_owner', 'public.contracting_events', 'field_key', 'INSERT')
     OR pg_catalog.has_column_privilege('compras_manual_timeline_note_create_owner', 'public.contracting_events', 'related_identifier_id', 'INSERT')
     OR pg_catalog.has_any_column_privilege('compras_manual_timeline_note_create_owner', 'public.contractings', 'UPDATE')
     OR pg_catalog.has_table_privilege('compras_manual_timeline_note_create_owner', 'public.contracting_events', 'UPDATE')
     OR pg_catalog.has_table_privilege('compras_manual_timeline_note_create_owner', 'public.contracting_events', 'DELETE') THEN
    RAISE EXCEPTION 'F44 capability authority is broader than approved';
  END IF;
END;
$structure$;

SET SESSION AUTHORIZATION compras_domain_runtime_f44_ci;

-- Missing, malformed and unknown identity fail closed.
DO $tests$
DECLARE out text;
BEGIN
  PERFORM set_config('request.jwt.claims', '', true);
  out := public.create_manual_timeline_note('44140000-0000-4000-8000-000000000001', '44160000-0000-4000-8000-000000000001', 'DEMO');
  IF out <> 'denied' THEN RAISE EXCEPTION 'missing claims accepted: %', out; END IF;

  PERFORM set_config('request.jwt.claims', 'not-json', true);
  out := public.create_manual_timeline_note('44140000-0000-4000-8000-000000000001', '44160000-0000-4000-8000-000000000002', 'DEMO');
  IF out <> 'denied' THEN RAISE EXCEPTION 'malformed claims accepted: %', out; END IF;

  PERFORM set_config('request.jwt.claims', '{"iss":"urn:compras:better-auth:self-hosted:v1","sub":"DEMO-F44-UNKNOWN"}', true);
  out := public.create_manual_timeline_note('44140000-0000-4000-8000-000000000001', '44160000-0000-4000-8000-000000000003', 'DEMO');
  IF out <> 'denied' THEN RAISE EXCEPTION 'unknown identity accepted: %', out; END IF;
END;
$tests$;

-- Disabled, revoked and active-without-membership identities fail closed.
DO $tests$
DECLARE out text;
BEGIN
  PERFORM set_config('request.jwt.claims', '{"iss":"urn:compras:better-auth:self-hosted:v1","sub":"DEMO-F44-DISABLED"}', true);
  out := public.create_manual_timeline_note('44140000-0000-4000-8000-000000000006', '44160000-0000-4000-8000-000000000004', 'DEMO');
  IF out <> 'denied' THEN RAISE EXCEPTION 'disabled user accepted: %', out; END IF;

  PERFORM set_config('request.jwt.claims', '{"iss":"urn:compras:better-auth:self-hosted:v1","sub":"DEMO-F44-REVOKED"}', true);
  out := public.create_manual_timeline_note('44140000-0000-4000-8000-000000000007', '44160000-0000-4000-8000-000000000005', 'DEMO');
  IF out <> 'denied' THEN RAISE EXCEPTION 'revoked membership accepted: %', out; END IF;

  PERFORM set_config('request.jwt.claims', '{"iss":"urn:compras:better-auth:self-hosted:v1","sub":"DEMO-F44-NO-MEMBERSHIP"}', true);
  out := public.create_manual_timeline_note('44140000-0000-4000-8000-000000000001', '44160000-0000-4000-8000-000000000006', 'DEMO');
  IF out <> 'denied' THEN RAISE EXCEPTION 'missing membership accepted: %', out; END IF;
END;
$tests$;

-- Authorized create, exact replay, divergent replay, and text preservation.
DO $tests$
DECLARE out text;
BEGIN
  PERFORM set_config('request.jwt.claims', '{"iss":"urn:compras:better-auth:self-hosted:v1","sub":"DEMO-F44-A"}', true);

  out := public.create_manual_timeline_note('44140000-0000-4000-8000-000000000001', '44160000-0000-4000-8000-000000000101', '  DEMO note  ');
  IF out <> 'created' THEN RAISE EXCEPTION 'authorized create failed: %', out; END IF;

  out := public.create_manual_timeline_note('44140000-0000-4000-8000-000000000001', '44160000-0000-4000-8000-000000000101', '  DEMO note  ');
  IF out <> 'already-added' THEN RAISE EXCEPTION 'exact replay failed: %', out; END IF;

  out := public.create_manual_timeline_note('44140000-0000-4000-8000-000000000001', '44160000-0000-4000-8000-000000000101', 'DIFFERENT');
  IF out <> 'denied' THEN RAISE EXCEPTION 'divergent replay accepted: %', out; END IF;

  out := public.create_manual_timeline_note('44140000-0000-4000-8000-000000000001', '44160000-0000-4000-8000-000000000102', NULL);
  IF out <> 'created' THEN RAISE EXCEPTION 'NULL note failed: %', out; END IF;
  out := public.create_manual_timeline_note('44140000-0000-4000-8000-000000000001', '44160000-0000-4000-8000-000000000103', '');
  IF out <> 'created' THEN RAISE EXCEPTION 'empty note failed: %', out; END IF;
  out := public.create_manual_timeline_note('44140000-0000-4000-8000-000000000001', '44160000-0000-4000-8000-000000000104', '   ');
  IF out <> 'created' THEN RAISE EXCEPTION 'spaces note failed: %', out; END IF;

  IF (SELECT note FROM public.contracting_events WHERE id='44160000-0000-4000-8000-000000000102') IS NOT NULL THEN
    RAISE EXCEPTION 'NULL note normalized';
  END IF;
  IF (SELECT note FROM public.contracting_events WHERE id='44160000-0000-4000-8000-000000000103') IS DISTINCT FROM '' THEN
    RAISE EXCEPTION 'empty note normalized';
  END IF;
  IF (SELECT note FROM public.contracting_events WHERE id='44160000-0000-4000-8000-000000000104') IS DISTINCT FROM '   ' THEN
    RAISE EXCEPTION 'spaces note normalized';
  END IF;
END;
$tests$;

-- Same note with distinct IDs is not deduplicated; shape stays closed.
DO $tests$
DECLARE out_a text; out_b text; cnt bigint;
BEGIN
  PERFORM set_config('request.jwt.claims', '{"iss":"urn:compras:better-auth:self-hosted:v1","sub":"DEMO-F44-A"}', true);
  out_a := public.create_manual_timeline_note('44140000-0000-4000-8000-000000000001', '44160000-0000-4000-8000-000000000110', 'SAME');
  out_b := public.create_manual_timeline_note('44140000-0000-4000-8000-000000000001', '44160000-0000-4000-8000-000000000111', 'SAME');
  IF out_a <> 'created' OR out_b <> 'created' THEN RAISE EXCEPTION 'distinct IDs were deduplicated: %, %', out_a, out_b; END IF;
  SELECT count(*) INTO cnt FROM public.contracting_events WHERE id IN ('44160000-0000-4000-8000-000000000110','44160000-0000-4000-8000-000000000111');
  IF cnt <> 2 THEN RAISE EXCEPTION 'distinct IDs did not persist twice: %', cnt; END IF;

  IF EXISTS (
    SELECT 1 FROM public.contracting_events WHERE id='44160000-0000-4000-8000-000000000101'
      AND (event_type <> 'manual_note_added' OR actor_membership_id <> '44130000-0000-4000-8000-000000000001'
        OR field_key IS NOT NULL OR old_value IS NOT NULL OR new_value IS NOT NULL
        OR related_identifier_id IS NOT NULL OR item_id IS NOT NULL OR created_at <> occurred_at)
  ) THEN RAISE EXCEPTION 'canonical event shape is open'; END IF;
END;
$tests$;

-- Cross-team, nonexistent, inactive and non-equivalent collisions stay denied.
DO $tests$
DECLARE out text;
BEGIN
  PERFORM set_config('request.jwt.claims', '{"iss":"urn:compras:better-auth:self-hosted:v1","sub":"DEMO-F44-A"}', true);
  out := public.create_manual_timeline_note('44140000-0000-4000-8000-000000000002', '44160000-0000-4000-8000-000000000201', 'DEMO');
  IF out <> 'denied' THEN RAISE EXCEPTION 'cross-team target accepted: %', out; END IF;
  out := public.create_manual_timeline_note('44140000-0000-4000-8000-000000009999', '44160000-0000-4000-8000-000000000202', 'DEMO');
  IF out <> 'denied' THEN RAISE EXCEPTION 'nonexistent target accepted: %', out; END IF;
  out := public.create_manual_timeline_note('44140000-0000-4000-8000-000000000004', '44160000-0000-4000-8000-000000000203', 'DEMO');
  IF out <> 'denied' THEN RAISE EXCEPTION 'archived target accepted: %', out; END IF;
  out := public.create_manual_timeline_note('44140000-0000-4000-8000-000000000005', '44160000-0000-4000-8000-000000000204', 'DEMO');
  IF out <> 'denied' THEN RAISE EXCEPTION 'cancelled target accepted: %', out; END IF;
  out := public.create_manual_timeline_note('44140000-0000-4000-8000-000000000001', '44160000-0000-4000-8000-000000000090', 'DEMO cross collision');
  IF out <> 'denied' THEN RAISE EXCEPTION 'cross-team UUID collision leaked: %', out; END IF;
  out := public.create_manual_timeline_note('44140000-0000-4000-8000-000000000001', '44160000-0000-4000-8000-000000000091', 'DEMO other type');
  IF out <> 'denied' THEN RAISE EXCEPTION 'other event type replay accepted: %', out; END IF;
  out := public.create_manual_timeline_note('44140000-0000-4000-8000-000000000001', '44160000-0000-4000-8000-000000000092', 'DEMO actor mismatch');
  IF out <> 'denied' THEN RAISE EXCEPTION 'actor mismatch replay accepted: %', out; END IF;
  out := public.create_manual_timeline_note('44140000-0000-4000-8000-000000000001', '44160000-0000-4000-8000-000000000093', 'DEMO bad shape');
  IF out <> 'denied' THEN RAISE EXCEPTION 'noncanonical shape replay accepted: %', out; END IF;
END;
$tests$;

-- A second non-revoked membership blocks even when the second app_user is disabled.
DO $tests$
DECLARE out text;
BEGIN
  PERFORM set_config('request.jwt.claims', '{"iss":"urn:compras:better-auth:self-hosted:v1","sub":"DEMO-F44-MULTI"}', true);
  out := public.create_manual_timeline_note('44140000-0000-4000-8000-000000000003', '44160000-0000-4000-8000-000000000205', 'DEMO');
  IF out <> 'denied' THEN RAISE EXCEPTION 'second non-revoked member accepted: %', out; END IF;
END;
$tests$;

RESET SESSION AUTHORIZATION;

DO $parent$
BEGIN
  IF (SELECT updated_at FROM public.contractings WHERE id='44140000-0000-4000-8000-000000000001') <> '2026-01-01T00:00:00Z'::timestamptz THEN
    RAISE EXCEPTION 'F44 changed contractings.updated_at';
  END IF;
END;
$parent$;
