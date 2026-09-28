BEGIN;

-- F44 persistent manual timeline note creation boundary.
-- This capability owns only the narrow SECURITY DEFINER primitive and never
-- owns a protected base table.
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
  WHERE r.rolname = 'compras_manual_timeline_note_create_owner';

  IF capability_oid IS NULL THEN
    EXECUTE $role$
      CREATE ROLE compras_manual_timeline_note_create_owner
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
    WHERE r.rolname = 'compras_manual_timeline_note_create_owner';
  END IF;

  IF capability_oid IS NULL THEN
    RAISE EXCEPTION 'manual timeline note create capability role could not be created';
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
    RAISE EXCEPTION 'manual timeline note create capability role has unsafe attributes or configuration';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM pg_catalog.pg_auth_members AS membership
    WHERE membership.member = capability_oid
  ) THEN
    RAISE EXCEPTION 'manual timeline note create capability role must not be a member of another role';
  END IF;

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
    RAISE EXCEPTION 'manual timeline note create capability role has unsafe grantees or usable membership';
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
    RAISE EXCEPTION 'migration principal cannot safely administer the manual timeline note create capability role';
  END IF;
END;
$migration$;

GRANT USAGE ON SCHEMA public TO compras_manual_timeline_note_create_owner;

GRANT SELECT (id, auth_issuer, auth_subject, disabled_at)
  ON public.app_users TO compras_manual_timeline_note_create_owner;
GRANT SELECT (id, team_id, user_id, revoked_at)
  ON public.memberships TO compras_manual_timeline_note_create_owner;
GRANT EXECUTE ON FUNCTION public.current_auth_issuer()
  TO compras_manual_timeline_note_create_owner;
GRANT EXECUTE ON FUNCTION public.current_auth_subject()
  TO compras_manual_timeline_note_create_owner;
GRANT EXECUTE ON FUNCTION public.current_app_user_id()
  TO compras_manual_timeline_note_create_owner;

GRANT SELECT (id, team_id, archived_at, cancelled_at)
  ON public.contractings TO compras_manual_timeline_note_create_owner;

GRANT SELECT (
  id,
  team_id,
  contracting_id,
  actor_membership_id,
  event_type,
  occurred_at,
  field_key,
  old_value,
  new_value,
  note,
  related_identifier_id,
  item_id,
  created_at
) ON public.contracting_events TO compras_manual_timeline_note_create_owner;

GRANT INSERT (
  id,
  team_id,
  contracting_id,
  actor_membership_id,
  event_type,
  occurred_at,
  note,
  created_at
) ON public.contracting_events TO compras_manual_timeline_note_create_owner;

-- The pilot guard counts every non-revoked membership in the target team,
-- including memberships whose app_user is disabled.
CREATE POLICY memberships_select_manual_timeline_note_create_capability
ON public.memberships
FOR SELECT
TO compras_manual_timeline_note_create_owner
USING (revoked_at IS NULL);

CREATE POLICY contractings_select_manual_timeline_note_create_capability
ON public.contractings
AS RESTRICTIVE
FOR SELECT
TO compras_manual_timeline_note_create_owner
USING (
  archived_at IS NULL
  AND cancelled_at IS NULL
  AND EXISTS (
    SELECT 1
    FROM public.memberships AS actor_membership
    WHERE actor_membership.team_id = contractings.team_id
      AND actor_membership.user_id = public.current_app_user_id()
      AND actor_membership.revoked_at IS NULL
  )
  AND 1 = (
    SELECT count(*)
    FROM public.memberships AS active_membership
    WHERE active_membership.team_id = contractings.team_id
      AND active_membership.revoked_at IS NULL
  )
);

CREATE POLICY contracting_events_select_manual_timeline_note_create_capability
ON public.contracting_events
AS RESTRICTIVE
FOR SELECT
TO compras_manual_timeline_note_create_owner
USING (
  event_type = 'manual_note_added'
  AND EXISTS (
    SELECT 1
    FROM public.contractings AS target
    WHERE target.id = contracting_events.contracting_id
      AND target.team_id = contracting_events.team_id
      AND target.archived_at IS NULL
      AND target.cancelled_at IS NULL
  )
  AND EXISTS (
    SELECT 1
    FROM public.memberships AS actor_membership
    WHERE actor_membership.team_id = contracting_events.team_id
      AND actor_membership.user_id = public.current_app_user_id()
      AND actor_membership.revoked_at IS NULL
  )
  AND 1 = (
    SELECT count(*)
    FROM public.memberships AS active_membership
    WHERE active_membership.team_id = contracting_events.team_id
      AND active_membership.revoked_at IS NULL
  )
);

CREATE POLICY contracting_events_insert_manual_timeline_note_create_capability
ON public.contracting_events
FOR INSERT
TO compras_manual_timeline_note_create_owner
WITH CHECK (
  event_type = 'manual_note_added'
  AND actor_membership_id IS NOT NULL
  AND field_key IS NULL
  AND old_value IS NULL
  AND new_value IS NULL
  AND related_identifier_id IS NULL
  AND item_id IS NULL
  AND created_at = occurred_at
  AND EXISTS (
    SELECT 1
    FROM public.memberships AS actor_membership
    WHERE actor_membership.id = contracting_events.actor_membership_id
      AND actor_membership.team_id = contracting_events.team_id
      AND actor_membership.user_id = public.current_app_user_id()
      AND actor_membership.revoked_at IS NULL
  )
  AND 1 = (
    SELECT count(*)
    FROM public.memberships AS active_membership
    WHERE active_membership.team_id = contracting_events.team_id
      AND active_membership.revoked_at IS NULL
  )
  AND EXISTS (
    SELECT 1
    FROM public.contractings AS target
    WHERE target.id = contracting_events.contracting_id
      AND target.team_id = contracting_events.team_id
      AND target.archived_at IS NULL
      AND target.cancelled_at IS NULL
  )
);

CREATE FUNCTION public.create_manual_timeline_note(
  p_contracting_id uuid,
  p_event_id uuid,
  p_note text
)
RETURNS text
LANGUAGE plpgsql
