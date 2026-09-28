import { Pool } from "pg";
import { afterAll, beforeAll, beforeEach, describe, expect, it } from "vitest";

const integrationEnabled = process.env.F44_MANUAL_TIMELINE_NOTE_POSTGRES_TEST === "1";
const describePostgres = integrationEnabled ? describe : describe.skip;

const TEAM_ID = "44910000-0000-4000-8000-000000000001";
const USER_ID = "44920000-0000-4000-8000-000000000001";
const MEMBERSHIP_ID = "44930000-0000-4000-8000-000000000001";
const CONTRACTING_ID = "44940000-0000-4000-8000-000000000001";
const SAME_EVENT_ID = "44960000-0000-4000-8000-000000000001";
const DIVERGENT_EVENT_ID = "44960000-0000-4000-8000-000000000002";
const DISTINCT_A_EVENT_ID = "44960000-0000-4000-8000-000000000003";
const DISTINCT_B_EVENT_ID = "44960000-0000-4000-8000-000000000004";
const ISSUER = "urn:compras:better-auth:self-hosted:v1";
const SUBJECT = "DEMO-F44-CONCURRENT";
const NOTE = "  DEMO F44 concurrent manual note preserved  ";

describePostgres("F44 PostgreSQL manual timeline note concurrency boundary", () => {
  let runtimePool: Pool;
  let adminPool: Pool;

  beforeAll(async () => {
    const runtimeUrl = process.env.F44_DOMAIN_RUNTIME_DATABASE_URL;
    const adminUrl = process.env.F44_ADMIN_DATABASE_URL;

    if (!runtimeUrl || !adminUrl) {
      throw new Error("F44 PostgreSQL integration references are required");
    }

    runtimePool = new Pool({ connectionString: runtimeUrl, max: 16 });
    adminPool = new Pool({ connectionString: adminUrl, max: 3 });

    await adminPool.query(
      `insert into public.teams (id, name, created_at, archived_at)
       values ($1::uuid, 'DEMO-F44-Team-Concurrent', '2026-01-01T00:00:00Z', null)`,
      [TEAM_ID],
    );
    await adminPool.query(
      `insert into public.app_users (
         id, auth_issuer, auth_subject, display_name, created_at, disabled_at
       ) values (
         $1::uuid, $2, $3, 'DEMO F44 Concurrent', '2026-01-01T00:00:00Z', null
       )`,
      [USER_ID, ISSUER, SUBJECT],
    );
    await adminPool.query(
      `insert into public.memberships (id, team_id, user_id, joined_at, revoked_at)
       values ($1::uuid, $2::uuid, $3::uuid, '2026-01-01T00:00:00Z', null)`,
      [MEMBERSHIP_ID, TEAM_ID, USER_ID],
    );
    await adminPool.query(
      `insert into public.contractings (
         id, team_id, object, created_at, updated_at, archived_at, cancelled_at
       ) values (
         $1::uuid, $2::uuid, 'DEMO F44 concurrent target',
         '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z', null, null
       )`,
      [CONTRACTING_ID, TEAM_ID],
    );
  });

  async function clearCandidates(): Promise<void> {
    await adminPool.query(
      "delete from public.contracting_events where id = any($1::uuid[])",
      [[SAME_EVENT_ID, DIVERGENT_EVENT_ID, DISTINCT_A_EVENT_ID, DISTINCT_B_EVENT_ID]],
    );
  }

  beforeEach(async () => {
    await clearCandidates();
  });

  afterAll(async () => {
    await Promise.all([runtimePool?.end(), adminPool?.end()]);
  });

  async function create(eventId: string, note: string | null): Promise<string> {
    const client = await runtimePool.connect();

    try {
      await client.query("begin");
      await client.query(
        "select set_config('request.jwt.claims', $1, true)",
        [JSON.stringify({ iss: ISSUER, sub: SUBJECT })],
      );
      const result = await client.query<{ outcome: string }>(
        `select public.create_manual_timeline_note(
           $1::uuid, $2::uuid, $3::text
         ) as outcome`,
        [CONTRACTING_ID, eventId, note],
      );
      await client.query("commit");
      return result.rows[0]?.outcome ?? "missing";
    } catch (error) {
      try {
        await client.query("rollback");
      } catch {
        // The client is discarded below.
      }
      throw error;
    } finally {
      client.release(true);
    }
  }

  it("collapses concurrent retries of one prepared event UUID into exactly one canonical event", async () => {
    const outcomes = await Promise.all(
      Array.from({ length: 8 }, () => create(SAME_EVENT_ID, NOTE)),
    );

    expect(outcomes.filter((outcome) => outcome === "created")).toHaveLength(1);
    expect(outcomes.filter((outcome) => outcome === "already-added")).toHaveLength(7);

    const persisted = await adminPool.query<{
      row_count: string;
      team_id: string;
      contracting_id: string;
      actor_membership_id: string;
      event_type: string;
      note: string;
      closed_shape: boolean;
      timestamps_match: boolean;
      parent_updated_at: Date;
    }>(
      `select
         count(event.id)::text as row_count,
         max(event.team_id::text) as team_id,
         max(event.contracting_id::text) as contracting_id,
         max(event.actor_membership_id::text) as actor_membership_id,
         max(event.event_type) as event_type,
         max(event.note) as note,
         bool_and(
           event.field_key is null
           and event.old_value is null
           and event.new_value is null
           and event.related_identifier_id is null
           and event.item_id is null
         ) as closed_shape,
         bool_and(event.occurred_at = event.created_at) as timestamps_match,
         max(contracting.updated_at) as parent_updated_at
       from public.contracting_events as event
       join public.contractings as contracting
         on contracting.id = event.contracting_id
        and contracting.team_id = event.team_id
       where event.id = $1::uuid`,
      [SAME_EVENT_ID],
    );

    expect(persisted.rows).toHaveLength(1);
    expect(persisted.rows[0]?.row_count).toBe("1");
    expect(persisted.rows[0]?.team_id).toBe(TEAM_ID);
    expect(persisted.rows[0]?.contracting_id).toBe(CONTRACTING_ID);
    expect(persisted.rows[0]?.actor_membership_id).toBe(MEMBERSHIP_ID);
    expect(persisted.rows[0]?.event_type).toBe("manual_note_added");
    expect(persisted.rows[0]?.note).toBe(NOTE);
    expect(persisted.rows[0]?.closed_shape).toBe(true);
    expect(persisted.rows[0]?.timestamps_match).toBe(true);
    expect(persisted.rows[0]?.parent_updated_at.toISOString()).toBe(
      "2026-01-01T00:00:00.000Z",
    );
  });

  it("does not overwrite when concurrent calls reuse one event UUID with divergent notes", async () => {
    const outcomes = await Promise.all([
      create(DIVERGENT_EVENT_ID, "DEMO divergent A"),
      create(DIVERGENT_EVENT_ID, "DEMO divergent B"),
    ]);

    expect(outcomes.filter((outcome) => outcome === "created")).toHaveLength(1);
    expect(outcomes.filter((outcome) => outcome === "denied")).toHaveLength(1);

    const state = await adminPool.query<{ note: string; row_count: string }>(
      `select max(note) as note, count(*)::text as row_count
       from public.contracting_events
       where id = $1::uuid`,
      [DIVERGENT_EVENT_ID],
    );

    expect(state.rows[0]?.row_count).toBe("1");
    expect(["DEMO divergent A", "DEMO divergent B"]).toContain(state.rows[0]?.note);
  });

  it("allows different event UUIDs to carry identical manual-note content", async () => {
    const outcomes = await Promise.all([
      create(DISTINCT_A_EVENT_ID, NOTE),
      create(DISTINCT_B_EVENT_ID, NOTE),
    ]);

    expect(outcomes).toEqual(["created", "created"]);

    const state = await adminPool.query<{ row_count: string }>(
      `select count(*)::text as row_count
       from public.contracting_events
       where id = any($1::uuid[])
         and event_type = 'manual_note_added'
         and note = $2`,
      [[DISTINCT_A_EVENT_ID, DISTINCT_B_EVENT_ID], NOTE],
    );

    expect(state.rows[0]?.row_count).toBe("2");
  });
});
