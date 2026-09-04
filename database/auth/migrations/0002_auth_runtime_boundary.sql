-- F20 Auth runtime boundary.
-- The login role is provisioned outside this migration without embedding a
-- password. This migration fails closed unless the fixed runtime role exists
-- and is non-privileged.
BEGIN;

DO $f20_auth_role$
DECLARE
  role_row pg_roles%ROWTYPE;
BEGIN
  SELECT *
    INTO role_row
    FROM pg_roles
   WHERE rolname = 'compras_auth_runtime';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'required role compras_auth_runtime does not exist';
  END IF;

  IF role_row.rolsuper
     OR role_row.rolbypassrls
     OR role_row.rolcreatedb
     OR role_row.rolcreaterole
     OR role_row.rolreplication
     OR role_row.rolinherit
     OR NOT role_row.rolcanlogin THEN
    RAISE EXCEPTION 'compras_auth_runtime must be LOGIN NOINHERIT NOSUPERUSER NOBYPASSRLS NOCREATEDB NOCREATEROLE NOREPLICATION';
  END IF;
END;
$f20_auth_role$;

REVOKE ALL PRIVILEGES ON SCHEMA auth FROM PUBLIC;
REVOKE ALL PRIVILEGES ON ALL TABLES IN SCHEMA auth FROM PUBLIC;
REVOKE ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA auth FROM PUBLIC;

GRANT USAGE ON SCHEMA auth TO compras_auth_runtime;
GRANT SELECT, INSERT, UPDATE, DELETE
  ON ALL TABLES IN SCHEMA auth
  TO compras_auth_runtime;
GRANT USAGE, SELECT, UPDATE
  ON ALL SEQUENCES IN SCHEMA auth
  TO compras_auth_runtime;

ALTER DEFAULT PRIVILEGES IN SCHEMA auth
  REVOKE ALL ON TABLES FROM PUBLIC;
ALTER DEFAULT PRIVILEGES IN SCHEMA auth
  REVOKE ALL ON SEQUENCES FROM PUBLIC;
ALTER DEFAULT PRIVILEGES IN SCHEMA auth
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO compras_auth_runtime;
ALTER DEFAULT PRIVILEGES IN SCHEMA auth
  GRANT USAGE, SELECT, UPDATE ON SEQUENCES TO compras_auth_runtime;

-- Defense in depth: the Auth runtime gets no role-specific privileges in the
-- domain schema. Domain migrations already revoke domain tables from PUBLIC.
REVOKE ALL PRIVILEGES ON ALL TABLES IN SCHEMA public FROM compras_auth_runtime;
REVOKE ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public FROM compras_auth_runtime;

DO $f20_auth_owner$
BEGIN
  IF EXISTS (
    SELECT 1
      FROM pg_class c
      JOIN pg_namespace n ON n.oid = c.relnamespace
      JOIN pg_roles r ON r.oid = c.relowner
     WHERE n.nspname = 'auth'
       AND r.rolname = 'compras_auth_runtime'
  ) THEN
    RAISE EXCEPTION 'compras_auth_runtime must not own Auth relations';
  END IF;
END;
$f20_auth_owner$;

COMMIT;
