BEGIN;

CREATE TABLE teams (
  id uuid PRIMARY KEY,
  name text NOT NULL,
  created_at timestamptz NOT NULL,
  archived_at timestamptz NULL
);

CREATE TABLE app_users (
  id uuid PRIMARY KEY,
  auth_issuer text NOT NULL,
  auth_subject text NOT NULL,
  display_name text NOT NULL,
  created_at timestamptz NOT NULL,
  disabled_at timestamptz NULL,
  CONSTRAINT app_users_auth_identity_key UNIQUE (auth_issuer, auth_subject)
);

CREATE TABLE memberships (
  id uuid PRIMARY KEY,
  team_id uuid NOT NULL REFERENCES teams(id),
  user_id uuid NOT NULL REFERENCES app_users(id),
  joined_at timestamptz NOT NULL,
  revoked_at timestamptz NULL,
  CONSTRAINT memberships_team_user_key UNIQUE (team_id, user_id),
  CONSTRAINT memberships_team_id_id_key UNIQUE (team_id, id)
);

CREATE TABLE contractings (
  id uuid PRIMARY KEY,
  team_id uuid NOT NULL REFERENCES teams(id),
  object text NOT NULL,
  responsible_membership_id uuid NULL,
  stage_key text NULL,
  status_key text NULL,
  waiting_type text NULL,
  waiting_reference text NULL,
  waiting_since timestamptz NULL,
  waiting_reason text NULL,
  next_action text NULL,
  created_by_membership_id uuid NULL,
  created_at timestamptz NOT NULL,
  updated_at timestamptz NOT NULL,
  archived_at timestamptz NULL,
  cancelled_at timestamptz NULL,
  CONSTRAINT contractings_team_id_id_key UNIQUE (team_id, id),
  CONSTRAINT contractings_responsible_membership_fk
    FOREIGN KEY (team_id, responsible_membership_id)
    REFERENCES memberships(team_id, id),
  CONSTRAINT contractings_created_by_membership_fk
    FOREIGN KEY (team_id, created_by_membership_id)
    REFERENCES memberships(team_id, id)
);

CREATE TABLE related_identifiers (
  id uuid PRIMARY KEY,
  team_id uuid NOT NULL,
  contracting_id uuid NOT NULL,
  identifier_kind text NULL,
  identifier_value text NOT NULL,
  source_system text NULL,
  note text NULL,
  linked_at timestamptz NOT NULL,
  unlinked_at timestamptz NULL,
  CONSTRAINT related_identifiers_contracting_fk
    FOREIGN KEY (team_id, contracting_id)
    REFERENCES contractings(team_id, id),
  CONSTRAINT related_identifiers_scope_key
    UNIQUE (team_id, contracting_id, id)
);

CREATE TABLE contracting_items (
  id uuid PRIMARY KEY,
  team_id uuid NOT NULL,
  contracting_id uuid NOT NULL,
  ordinal integer NOT NULL,
  description text NOT NULL,
  quantity numeric NULL,
  unit text NULL,
  catalog_code text NULL,
  created_at timestamptz NOT NULL,
  updated_at timestamptz NOT NULL,
  retired_at timestamptz NULL,
  CONSTRAINT contracting_items_contracting_fk
    FOREIGN KEY (team_id, contracting_id)
    REFERENCES contractings(team_id, id),
  CONSTRAINT contracting_items_contracting_ordinal_key
    UNIQUE (contracting_id, ordinal),
  CONSTRAINT contracting_items_scope_key
    UNIQUE (team_id, contracting_id, id)
);

CREATE TABLE contracting_events (
  id uuid PRIMARY KEY,
  team_id uuid NOT NULL,
  contracting_id uuid NOT NULL,
  actor_membership_id uuid NULL,
  event_type text NOT NULL,
  occurred_at timestamptz NOT NULL,
  field_key text NULL,
  old_value text NULL,
  new_value text NULL,
  note text NULL,
  related_identifier_id uuid NULL,
  item_id uuid NULL,
  created_at timestamptz NOT NULL,
  CONSTRAINT contracting_events_contracting_fk
    FOREIGN KEY (team_id, contracting_id)
    REFERENCES contractings(team_id, id),
  CONSTRAINT contracting_events_actor_membership_fk
    FOREIGN KEY (team_id, actor_membership_id)
    REFERENCES memberships(team_id, id),
  CONSTRAINT contracting_events_related_identifier_fk
    FOREIGN KEY (team_id, contracting_id, related_identifier_id)
    REFERENCES related_identifiers(team_id, contracting_id, id),
  CONSTRAINT contracting_events_item_fk
    FOREIGN KEY (team_id, contracting_id, item_id)
    REFERENCES contracting_items(team_id, contracting_id, id)
);

CREATE INDEX memberships_user_id_idx
  ON memberships(user_id);
CREATE INDEX memberships_user_id_active_idx
  ON memberships(user_id)
  WHERE revoked_at IS NULL;

CREATE INDEX contractings_team_id_idx
  ON contractings(team_id);
CREATE INDEX contractings_team_responsible_idx
  ON contractings(team_id, responsible_membership_id);
CREATE INDEX contractings_team_stage_idx
  ON contractings(team_id, stage_key);
CREATE INDEX contractings_team_status_idx
  ON contractings(team_id, status_key);
CREATE INDEX contractings_team_active_idx
  ON contractings(team_id)
  WHERE archived_at IS NULL AND cancelled_at IS NULL;

CREATE INDEX related_identifiers_team_value_idx
  ON related_identifiers(team_id, identifier_value);
CREATE INDEX related_identifiers_contracting_idx
  ON related_identifiers(contracting_id);

CREATE INDEX contracting_events_contracting_occurred_idx
  ON contracting_events(contracting_id, occurred_at DESC);

ALTER TABLE teams ENABLE ROW LEVEL SECURITY;
ALTER TABLE teams FORCE ROW LEVEL SECURITY;
ALTER TABLE app_users ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_users FORCE ROW LEVEL SECURITY;
ALTER TABLE memberships ENABLE ROW LEVEL SECURITY;
ALTER TABLE memberships FORCE ROW LEVEL SECURITY;
ALTER TABLE contractings ENABLE ROW LEVEL SECURITY;
ALTER TABLE contractings FORCE ROW LEVEL SECURITY;
ALTER TABLE related_identifiers ENABLE ROW LEVEL SECURITY;
ALTER TABLE related_identifiers FORCE ROW LEVEL SECURITY;
ALTER TABLE contracting_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE contracting_items FORCE ROW LEVEL SECURITY;
ALTER TABLE contracting_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE contracting_events FORCE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE teams FROM PUBLIC;
REVOKE ALL ON TABLE app_users FROM PUBLIC;
REVOKE ALL ON TABLE memberships FROM PUBLIC;
REVOKE ALL ON TABLE contractings FROM PUBLIC;
REVOKE ALL ON TABLE related_identifiers FROM PUBLIC;
REVOKE ALL ON TABLE contracting_items FROM PUBLIC;
REVOKE ALL ON TABLE contracting_events FROM PUBLIC;

COMMIT;
