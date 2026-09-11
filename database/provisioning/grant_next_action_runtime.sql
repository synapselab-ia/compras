\if :{?runtime_role}
\else
\echo 'runtime_role psql variable is required'
\quit 3
\endif

BEGIN;

-- This is environment provisioning, not a schema migration. The mutation
-- function is intentionally owned by a sealed NOLOGIN capability, so the
-- migrator must not retain authority to GRANT object privileges after 0004.
-- PostgreSQL 17 permits the migration principal to create a transaction-local
-- SET-capable edge, use the capability owner to grant exactly EXECUTE, and
-- revoke that edge before commit. ADR-005 requires the final state to contain
-- no usable capability membership.
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
  SELECT r.oid
  INTO runtime_oid
  FROM pg_catalog.pg_roles AS r
  WHERE r.rolname = runtime_name;

  IF runtime_oid IS NULL THEN
    RAISE EXCEPTION 'runtime role does not exist';
  END IF;

  SELECT r.oid
  INTO capability_oid
  FROM pg_catalog.pg_roles AS r
  WHERE r.rolname = 'compras_next_action_mutation_owner';

  IF capability_oid IS NULL THEN
    RAISE EXCEPTION 'next-action mutation capability role does not exist';
  END IF;

  IF runtime_oid = capability_oid THEN
    RAISE EXCEPTION 'runtime role cannot be the mutation capability owner';
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
    RAISE EXCEPTION 'runtime role already has mutation capability membership';
  END IF;

  IF pg_catalog.has_any_column_privilege(
       runtime_name,
       'public.contractings',
       'UPDATE'
     )
     OR pg_catalog.has_any_column_privilege(
       runtime_name,
       'public.contracting_events',
       'INSERT'
     )
     OR pg_catalog.has_table_privilege(
       runtime_name,
       'public.contracting_events',
       'UPDATE'
     )
     OR pg_catalog.has_table_privilege(
       runtime_name,
       'public.contracting_events',
       'DELETE'
     ) THEN
    RAISE EXCEPTION 'runtime role already has direct mutation privileges';
  END IF;

  SELECT p.proowner
  INTO function_owner
  FROM pg_catalog.pg_proc AS p
  JOIN pg_catalog.pg_namespace AS n
    ON n.oid = p.pronamespace
  WHERE n.nspname = 'public'
    AND p.proname = 'mutate_contracting_next_action'
    AND pg_catalog.pg_get_function_identity_arguments(p.oid)
      = 'p_contracting_id uuid, p_expected_next_action text, p_new_next_action text, p_event_id uuid';

  IF function_owner IS DISTINCT FROM capability_oid THEN
    RAISE EXCEPTION 'mutation function is not owned by the sealed capability';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM pg_catalog.pg_auth_members AS membership
    WHERE membership.member = capability_oid
       OR (
         membership.roleid = capability_oid
         AND (
           membership.set_option
           OR membership.inherit_option
         )
       )
  ) THEN
    RAISE EXCEPTION 'mutation capability is not sealed before runtime provisioning';
  END IF;
END;
$preflight$;

-- Keep the SET-capable membership and the EXECUTE grant in one transaction.
-- GRANTED BY CURRENT_USER ensures the REVOKE removes only this temporary edge,
-- not PostgreSQL 17's automatic ADMIN-only edge created by CREATEROLE.
GRANT compras_next_action_mutation_owner
  TO CURRENT_USER
  WITH INHERIT FALSE, SET TRUE
  GRANTED BY CURRENT_USER;

SET ROLE compras_next_action_mutation_owner;

GRANT EXECUTE ON FUNCTION public.mutate_contracting_next_action(uuid, text, text, uuid)
  TO :"runtime_role";

RESET ROLE;

REVOKE compras_next_action_mutation_owner
  FROM CURRENT_USER
  GRANTED BY CURRENT_USER;

DO $postflight$
DECLARE
  runtime_name text := pg_catalog.current_setting('compras.provision.runtime_role');
  runtime_oid oid;
  capability_oid oid;
BEGIN
  SELECT r.oid
  INTO runtime_oid
  FROM pg_catalog.pg_roles AS r
  WHERE r.rolname = runtime_name;

  SELECT r.oid
  INTO capability_oid
  FROM pg_catalog.pg_roles AS r
  WHERE r.rolname = 'compras_next_action_mutation_owner';

  IF runtime_oid IS NULL OR capability_oid IS NULL THEN
    RAISE EXCEPTION 'cannot resolve runtime provisioning principals';
  END IF;

  IF NOT pg_catalog.has_function_privilege(
       runtime_name,
       'public.mutate_contracting_next_action(uuid,text,text,uuid)',
       'EXECUTE'
     ) THEN
    RAISE EXCEPTION 'runtime did not receive mutation EXECUTE';
  END IF;

  IF pg_catalog.has_any_column_privilege(
       runtime_name,
       'public.contractings',
       'UPDATE'
     )
     OR pg_catalog.has_any_column_privilege(
       runtime_name,
       'public.contracting_events',
       'INSERT'
     ) THEN
    RAISE EXCEPTION 'runtime gained direct DML during mutation provisioning';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM pg_catalog.pg_auth_members AS membership
    WHERE membership.member = capability_oid
       OR (
         membership.roleid = capability_oid
         AND (
           membership.set_option
           OR membership.inherit_option
         )
       )
       OR (
         membership.roleid = capability_oid
         AND membership.member = runtime_oid
       )
  ) THEN
    RAISE EXCEPTION 'usable mutation capability membership remained after provisioning';
  END IF;
END;
$postflight$;

COMMIT;
