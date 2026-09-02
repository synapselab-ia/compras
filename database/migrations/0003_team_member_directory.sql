BEGIN;

-- F11 capability boundary. This role is cluster-level, intentionally NOLOGIN,
-- and is never an application credential. PostgreSQL 17 automatically grants
-- an ADMIN-only membership (SET FALSE, INHERIT FALSE) back to a non-superuser
-- CREATEROLE principal that creates a role; ADR-005 records why that
-- administration-only edge is allowed while usable membership remains denied.
DO $migration$
DECLARE
  capability_oid oid;
  migration_oid oid;
  migration_is_superuser boolean;
BEGIN
  SELECT r.oid, r.rolsuper
  INTO migration_oid, migration_is_superuser
  FROM pg_catalog.pg_roles AS r
  WHERE r.rolname = current_user;

  IF migration_oid IS NULL THEN
    RAISE EXCEPTION 'cannot resolve migration principal';
  END IF;

  SELECT r.oid
  INTO capability_oid
  FROM pg_catalog.pg_roles AS r
  WHERE r.rolname = 'compras_team_directory_view_owner';

  IF capability_oid IS NULL THEN
    EXECUTE $role$
      CREATE ROLE compras_team_directory_view_owner
        NOLOGIN
        NOSUPERUSER
        NOCREATEDB
        NOCREATEROLE
        NOINHERIT
        NOREPLICATION
        NOBYPASSRLS
    $role$;

    SELECT r.oid
    INTO capability_oid
    FROM pg_catalog.pg_roles AS r
    WHERE r.rolname = 'compras_team_directory_view_owner';
  END IF;

  IF capability_oid IS NULL THEN
    RAISE EXCEPTION 'directory capability role could not be created';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM pg_catalog.pg_roles AS r
    WHERE r.oid = capability_oid
      AND (
        r.rolcanlogin
        OR r.rolsuper
        OR r.rolcreatedb
        OR r.rolcreaterole
        OR r.rolinherit
        OR r.rolreplication
        OR r.rolbypassrls
        OR r.rolconfig IS NOT NULL
      )
  ) THEN
    RAISE EXCEPTION 'directory capability role has unsafe attributes or configuration';
  END IF;

  -- The capability itself must not inherit any other role. This also rejects a
  -- role created through a control plane that silently makes it a member of a
  -- privileged provider role.
  IF EXISTS (
    SELECT 1
    FROM pg_catalog.pg_auth_members AS membership
    WHERE membership.member = capability_oid
  ) THEN
    RAISE EXCEPTION 'directory capability role must not be a member of another role';
  END IF;

  -- No role may inherit or SET ROLE into the capability. PostgreSQL 17 may
  -- leave only its automatic ADMIN edge to the non-operational migration
  -- principal; any other membership shape fails closed.
  IF EXISTS (
    SELECT 1
    FROM pg_catalog.pg_auth_members AS membership
    WHERE membership.roleid = capability_oid
      AND (
        membership.member <> migration_oid
        OR membership.set_option
        OR membership.inherit_option
        OR NOT membership.admin_option
      )
  ) THEN
    RAISE EXCEPTION 'directory capability role has unsafe grantees or usable membership';
  END IF;

  IF NOT migration_is_superuser
     AND NOT EXISTS (
       SELECT 1
       FROM pg_catalog.pg_auth_members AS membership
       WHERE membership.roleid = capability_oid
         AND membership.member = migration_oid
         AND membership.admin_option
         AND NOT membership.set_option
         AND NOT membership.inherit_option
     ) THEN
    RAISE EXCEPTION 'migration principal cannot safely administer the directory capability role';
  END IF;
END;
$migration$;

GRANT USAGE ON SCHEMA public TO compras_team_directory_view_owner;
GRANT SELECT (id, team_id, user_id, revoked_at)
  ON public.memberships TO compras_team_directory_view_owner;
GRANT SELECT (id, display_name, disabled_at)
  ON public.app_users TO compras_team_directory_view_owner;

CREATE POLICY memberships_select_directory_capability
ON public.memberships
FOR SELECT
TO compras_team_directory_view_owner
USING (revoked_at IS NULL);

CREATE POLICY app_users_select_directory_capability
ON public.app_users
FOR SELECT
TO compras_team_directory_view_owner
USING (disabled_at IS NULL);

CREATE VIEW public.team_member_directory
WITH (security_barrier = true, security_invoker = false)
AS
SELECT
  target.team_id,
  target.id AS membership_id,
  target_user.display_name
FROM public.memberships AS target
JOIN public.app_users AS target_user
  ON target_user.id = target.user_id
WHERE target.revoked_at IS NULL
  AND target_user.disabled_at IS NULL
  AND EXISTS (
    SELECT 1
    FROM public.memberships AS viewer
    WHERE viewer.team_id = target.team_id
      AND viewer.user_id = public.current_app_user_id()
      AND viewer.revoked_at IS NULL
  );

REVOKE ALL ON public.team_member_directory FROM PUBLIC;

-- ALTER VIEW OWNER requires the migration session to be able to SET ROLE to
-- the new owner, and the new owner to have CREATE on the schema. A
-- non-superuser CREATEROLE principal receives a separate, transaction-local
-- SET-capable grant from itself, uses it only for ownership transfer, and then
-- removes that grant before commit. The automatic ADMIN-only grant remains
-- SET FALSE / INHERIT FALSE and cannot exercise capability privileges.
GRANT CREATE ON SCHEMA public TO compras_team_directory_view_owner;

DO $ownership$
DECLARE
  migration_is_superuser boolean;
BEGIN
  SELECT r.rolsuper
  INTO migration_is_superuser
  FROM pg_catalog.pg_roles AS r
  WHERE r.rolname = current_user;

  IF NOT COALESCE(migration_is_superuser, false) THEN
    EXECUTE format(
      'GRANT compras_team_directory_view_owner TO %I WITH INHERIT FALSE, SET TRUE GRANTED BY %I',
      current_user,
      current_user
    );
  END IF;

  ALTER VIEW public.team_member_directory
    OWNER TO compras_team_directory_view_owner;

  IF NOT COALESCE(migration_is_superuser, false) THEN
    EXECUTE format(
      'REVOKE compras_team_directory_view_owner FROM %I GRANTED BY %I',
      current_user,
      current_user
    );
  END IF;
END;
$ownership$;

REVOKE CREATE ON SCHEMA public FROM compras_team_directory_view_owner;

-- Final structural guard: migration succeeds only when the capability is
-- sealed for runtime use and owns exactly the intended view boundary.
DO $postflight$
DECLARE
  capability_oid oid;
  migration_oid oid;
BEGIN
  SELECT r.oid
  INTO capability_oid
  FROM pg_catalog.pg_roles AS r
  WHERE r.rolname = 'compras_team_directory_view_owner';

  SELECT r.oid
  INTO migration_oid
  FROM pg_catalog.pg_roles AS r
  WHERE r.rolname = current_user;

  IF EXISTS (
    SELECT 1
    FROM pg_catalog.pg_auth_members AS membership
    WHERE membership.member = capability_oid
       OR (
         membership.roleid = capability_oid
         AND (
           membership.member <> migration_oid
           OR membership.set_option
           OR membership.inherit_option
           OR NOT membership.admin_option
         )
       )
  ) THEN
    RAISE EXCEPTION 'directory capability role is not sealed after ownership transfer';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM pg_catalog.pg_class AS relation
    JOIN pg_catalog.pg_namespace AS namespace
      ON namespace.oid = relation.relnamespace
    WHERE namespace.nspname = 'public'
      AND relation.relname IN (
        'teams',
        'app_users',
        'memberships',
        'contractings',
        'related_identifiers',
        'contracting_items',
        'contracting_events'
      )
      AND relation.relowner = capability_oid
  ) THEN
    RAISE EXCEPTION 'directory capability role must not own protected base tables';
  END IF;

  IF has_column_privilege(
       'compras_team_directory_view_owner',
       'public.app_users',
       'auth_issuer',
       'SELECT'
     )
     OR has_column_privilege(
       'compras_team_directory_view_owner',
       'public.app_users',
       'auth_subject',
       'SELECT'
     ) THEN
    RAISE EXCEPTION 'directory capability role must not read external auth identifiers';
  END IF;

  IF has_schema_privilege(
       'compras_team_directory_view_owner',
       'public',
       'CREATE'
     ) THEN
    RAISE EXCEPTION 'directory capability role retained schema CREATE privilege';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_catalog.pg_class AS relation
    JOIN pg_catalog.pg_namespace AS namespace
      ON namespace.oid = relation.relnamespace
    WHERE namespace.nspname = 'public'
      AND relation.relname = 'team_member_directory'
      AND relation.relkind = 'v'
      AND relation.relowner = capability_oid
      AND COALESCE(relation.reloptions, ARRAY[]::text[])
        @> ARRAY['security_barrier=true']
      AND COALESCE(relation.reloptions, ARRAY[]::text[])
        @> ARRAY['security_invoker=false']
  ) THEN
    RAISE EXCEPTION 'team member directory view has unsafe ownership or options';
  END IF;
END;
$postflight$;

COMMIT;
