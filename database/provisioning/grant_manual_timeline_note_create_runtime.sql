\if :{?runtime_role}
\else
\echo 'runtime_role psql variable is required'
\quit 3
\endif

BEGIN;

SELECT pg_catalog.set_config(
  'compras.provision.runtime_role',
  :'runtime_role',
  true
);

DO $preflight$
DECLARE
  runtime_name text := pg_catalog.current_setting('compras.provision.runtime_role');
  runtime_oid oid;
  capability_oid oid;
  function_owner oid;
BEGIN
  SELECT r.oid INTO runtime_oid
  FROM pg_catalog.pg_roles AS r
  WHERE r.rolname = runtime_name;

  IF runtime_oid IS NULL THEN
    RAISE EXCEPTION 'runtime role does not exist';
  END IF;

  SELECT r.oid INTO capability_oid
  FROM pg_catalog.pg_roles AS r
  WHERE r.rolname = 'compras_manual_timeline_note_create_owner';

  IF capability_oid IS NULL THEN
    RAISE EXCEPTION 'manual timeline note create capability role does not exist';
  END IF;

  IF runtime_oid = capability_oid THEN
    RAISE EXCEPTION 'runtime role cannot be the manual timeline note create capability owner';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM pg_catalog.pg_roles AS r
    WHERE r.oid = runtime_oid
      AND (
        NOT r.rolcanlogin
        OR r.rolsuper
        OR r.rolcreatedb
        OR r.rolcreaterole
        OR r.rolinherit
        OR r.rolreplication
        OR r.rolbypassrls
      )
  ) THEN
    RAISE EXCEPTION 'runtime role has unsafe attributes';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM pg_catalog.pg_auth_members AS membership
    WHERE membership.member = runtime_oid
      AND membership.roleid = capability_oid
  ) THEN
    RAISE EXCEPTION 'runtime role already has manual timeline note create capability membership';
  END IF;

  IF pg_catalog.has_any_column_privilege(runtime_name, 'public.contractings', 'UPDATE')
     OR pg_catalog.has_any_column_privilege(runtime_name, 'public.related_identifiers', 'INSERT')
     OR pg_catalog.has_any_column_privilege(runtime_name, 'public.related_identifiers', 'UPDATE')
     OR pg_catalog.has_table_privilege(runtime_name, 'public.related_identifiers', 'DELETE')
     OR pg_catalog.has_any_column_privilege(runtime_name, 'public.contracting_items', 'INSERT')
     OR pg_catalog.has_any_column_privilege(runtime_name, 'public.contracting_items', 'UPDATE')
     OR pg_catalog.has_table_privilege(runtime_name, 'public.contracting_items', 'DELETE')
     OR pg_catalog.has_any_column_privilege(runtime_name, 'public.contracting_events', 'INSERT')
     OR pg_catalog.has_table_privilege(runtime_name, 'public.contracting_events', 'UPDATE')
     OR pg_catalog.has_table_privilege(runtime_name, 'public.contracting_events', 'DELETE')
     OR pg_catalog.has_any_column_privilege(runtime_name, 'public.contracting_item_ordinal_counters', 'INSERT')
     OR pg_catalog.has_any_column_privilege(runtime_name, 'public.contracting_item_ordinal_counters', 'UPDATE')
     OR pg_catalog.has_table_privilege(runtime_name, 'public.contracting_item_ordinal_counters', 'DELETE') THEN
    RAISE EXCEPTION 'runtime role already has direct domain mutation privileges';
  END IF;

  SELECT p.proowner INTO function_owner
  FROM pg_catalog.pg_proc AS p
  JOIN pg_catalog.pg_namespace AS n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public'
    AND p.proname = 'create_manual_timeline_note'
    AND pg_catalog.pg_get_function_identity_arguments(p.oid)
      = 'p_contracting_id uuid, p_event_id uuid, p_note text';

  IF function_owner IS DISTINCT FROM capability_oid THEN
    RAISE EXCEPTION 'manual timeline note create function is not owned by the sealed capability';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM pg_catalog.pg_auth_members AS membership
    WHERE membership.member = capability_oid
       OR (
         membership.roleid = capability_oid
         AND (membership.set_option OR membership.inherit_option)
       )
  ) THEN
    RAISE EXCEPTION 'manual timeline note create capability is not sealed before runtime provisioning';
  END IF;
END;
$preflight$;

GRANT compras_manual_timeline_note_create_owner
  TO CURRENT_USER
  WITH INHERIT FALSE, SET TRUE
  GRANTED BY CURRENT_USER;

SET ROLE compras_manual_timeline_note_create_owner;

GRANT EXECUTE ON FUNCTION public.create_manual_timeline_note(
  uuid, uuid, text
) TO :"runtime_role";

RESET ROLE;

REVOKE compras_manual_timeline_note_create_owner
  FROM CURRENT_USER
  GRANTED BY CURRENT_USER;

DO $postflight$
DECLARE
  runtime_name text := pg_catalog.current_setting('compras.provision.runtime_role');
  runtime_oid oid;
  capability_oid oid;
BEGIN
  SELECT r.oid INTO runtime_oid
  FROM pg_catalog.pg_roles AS r
  WHERE r.rolname = runtime_name;

  SELECT r.oid INTO capability_oid
  FROM pg_catalog.pg_roles AS r
  WHERE r.rolname = 'compras_manual_timeline_note_create_owner';

  IF runtime_oid IS NULL OR capability_oid IS NULL THEN
    RAISE EXCEPTION 'cannot resolve manual timeline note create runtime provisioning principals';
  END IF;

  IF NOT pg_catalog.has_function_privilege(
       runtime_name,
       'public.create_manual_timeline_note(uuid,uuid,text)',
       'EXECUTE'
     ) THEN
    RAISE EXCEPTION 'runtime did not receive manual timeline note create EXECUTE';
  END IF;

  IF pg_catalog.has_any_column_privilege(runtime_name, 'public.contractings', 'UPDATE')
     OR pg_catalog.has_any_column_privilege(runtime_name, 'public.related_identifiers', 'INSERT')
     OR pg_catalog.has_any_column_privilege(runtime_name, 'public.related_identifiers', 'UPDATE')
     OR pg_catalog.has_table_privilege(runtime_name, 'public.related_identifiers', 'DELETE')
     OR pg_catalog.has_any_column_privilege(runtime_name, 'public.contracting_items', 'INSERT')
     OR pg_catalog.has_any_column_privilege(runtime_name, 'public.contracting_items', 'UPDATE')
     OR pg_catalog.has_table_privilege(runtime_name, 'public.contracting_items', 'DELETE')
     OR pg_catalog.has_any_column_privilege(runtime_name, 'public.contracting_events', 'INSERT')
     OR pg_catalog.has_table_privilege(runtime_name, 'public.contracting_events', 'UPDATE')
     OR pg_catalog.has_table_privilege(runtime_name, 'public.contracting_events', 'DELETE')
     OR pg_catalog.has_any_column_privilege(runtime_name, 'public.contracting_item_ordinal_counters', 'INSERT')
     OR pg_catalog.has_any_column_privilege(runtime_name, 'public.contracting_item_ordinal_counters', 'UPDATE')
     OR pg_catalog.has_table_privilege(runtime_name, 'public.contracting_item_ordinal_counters', 'DELETE') THEN
    RAISE EXCEPTION 'runtime gained direct DML during manual timeline note create provisioning';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM pg_catalog.pg_auth_members AS membership
    WHERE membership.member = capability_oid
       OR (
         membership.roleid = capability_oid
         AND (membership.set_option OR membership.inherit_option)
       )
       OR (
         membership.roleid = capability_oid
         AND membership.member = runtime_oid
       )
  ) THEN
    RAISE EXCEPTION 'usable manual timeline note create capability membership remained after provisioning';
  END IF;
END;
$postflight$;

COMMIT;
