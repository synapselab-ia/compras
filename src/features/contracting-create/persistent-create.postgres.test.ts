import { Pool } from "pg";
import { afterAll, beforeAll, beforeEach, describe, expect, it } from "vitest";

const integrationEnabled = process.env.F29_CONTRACTING_CREATE_POSTGRES_TEST === "1";
const describePostgres = integrationEnabled ? describe : describe.skip;

const TARGET_ID = "29040000-0000-4000-8000-000000000090";
const TEAM_ID = "29010000-0000-4000-8000-000000000090";
const USER_ID = "29020000-0000-4000-8000-000000000090";
const MEMBERSHIP_ID = "29030000-0000-4000-8000-000000000090";
const ISSUER = "urn:compras:better-auth:self-hosted:v1";
const SUBJECT = "DEMO-F29-CONCURRENT";
const OBJECT = "  DEMO F29 concurrent object preserved  ";

describePostgres("F29 PostgreSQL contracting create concurrency boundary", () => {
  let runtimePool: Pool;
  let adminPool: Pool;

  beforeAll(async () => {
    const runtimeUrl = process.env.F29_DOMAIN_RUNTIME_DATABASE_URL;
    const adminUrl = process.env.F29_ADMIN_DATABASE_URL;

    if (!runtimeUrl || !adminUrl) {
      throw new Error("F29 PostgreSQL integration references are required");
    }

    runtimePool = new Pool({ connectionString: runtimeUrl, max: 12 });
    adminPool = new Pool({ connectionString: adminUrl, max: 2 });

    await adminPool.query(
      `insert into public.teams (id, name, created_at, archived_at)
       values ($1::uuid, 'DEMO-F29-Team-Concurrent', '2026-01-01T00:00:00Z', null)`,
      [TEAM_ID],
    );
    await adminPool.query(
      `insert into public.app_users (
         id, auth_issuer, auth_subject, display_name, created_at, disabled_at
       ) values (
         $1::uuid, $2, $3, 'DEMO F29 Concurrent', '2026-01-01T00:00:00Z', null
       )`,
      [USER_ID, ISSUER, SUBJECT],
    );
    await adminPool.query(
      `insert into public.memberships (id, team_id, user_id, joined_at, revoked_at)
       values ($1::uuid, $2::uuid, $3::uuid, '2026-01-01T00:00:00Z', null)`,
      [MEMBERSHIP_ID, TEAM_ID, USER_ID],
    );
  });

  beforeEach(async () => {
    await adminPool.query(
      "delete from public.contracting_events where contracting_id = $1::uuid",
      [TARGET_ID],
    );
    await adminPool.query(
      "delete from public.contractings where id = $1::uuid",
      [TARGET_ID],
    );
  });

  afterAll(async () => {
    await Promise.all([runtimePool?.end(), adminPool?.end()]);
  });

  async function create(candidate: number): Promise<string> {
    const client = await runtimePool.connect();
    const eventId = `29050000-0000-4000-8000-${candidate.toString().padStart(12, "0")}`;

    try {
      await client.query("begin");
      await client.query(
        "select set_config('request.jwt.claims', $1, true)",
        [JSON.stringify({ iss: ISSUER, sub: SUBJECT })],
      );
      const result = await client.query<{ outcome: string }>(
        `select public.create_contracting_minimal(
           $1::uuid, $2::text, $3::uuid
         ) as outcome`,
        [TARGET_ID, OBJECT, eventId],
      );
      await client.query("commit");
      return result.rows[0]?.outcome ?? "missing";
    } catch (error) {
      try {
        await client.query("rollback");
      } catch {
        // The test discards this client below.
      }
      throw error;
    } finally {
      client.release(true);
    }
  }

  it("collapses eight concurrent retries into one row and one creation event", async () => {
    const outcomes = await Promise.all(
      Array.from({ length: 8 }, (_, index) => create(index + 1)),
    );

    expect(outcomes.filter((outcome) => outcome === "created")).toHaveLength(1);
    expect(outcomes.filter((outcome) => outcome === "already-created")).toHaveLength(7);

    const persisted = await adminPool.query<{
      object: string;
      team_id: string;
      created_by_membership_id: string;
      event_count: string;
      matching_event_count: string;
      initial_shape_ok: boolean;
      timestamps_match: boolean;
    }>(
      `select
         contracting.object,
         contracting.team_id::text,
         contracting.created_by_membership_id::text,
         count(event.id)::text as event_count,
         count(event.id) filter (
           where event.team_id = $2::uuid
             and event.actor_membership_id = $3::uuid
             and event.event_type = 'contracting_created'
             and event.field_key is null
             and event.old_value is null
             and event.new_value is null
             and event.note is null
             and event.related_identifier_id is null
             and event.item_id is null
         )::text as matching_event_count,
         (
           contracting.responsible_membership_id is null
           and contracting.stage_key is null
           and contracting.status_key is null
           and contracting.waiting_type is null
           and contracting.waiting_reference is null
           and contracting.waiting_since is null
           and contracting.waiting_reason is null
           and contracting.next_action is null
           and contracting.archived_at is null
           and contracting.cancelled_at is null
         ) as initial_shape_ok,
         bool_and(
           contracting.created_at = contracting.updated_at
           and contracting.created_at = event.occurred_at
           and event.occurred_at = event.created_at
         ) as timestamps_match
       from public.contractings as contracting
       left join public.contracting_events as event
         on event.contracting_id = contracting.id
        and event.team_id = contracting.team_id
       where contracting.id = $1::uuid
       group by contracting.id`,
      [TARGET_ID, TEAM_ID, MEMBERSHIP_ID],
    );

    expect(persisted.rows).toHaveLength(1);
    expect(persisted.rows[0]?.object).toBe(OBJECT);
    expect(persisted.rows[0]?.team_id).toBe(TEAM_ID);
    expect(persisted.rows[0]?.created_by_membership_id).toBe(MEMBERSHIP_ID);
    expect(persisted.rows[0]?.event_count).toBe("1");
    expect(persisted.rows[0]?.matching_event_count).toBe("1");
    expect(persisted.rows[0]?.initial_shape_ok).toBe(true);
    expect(persisted.rows[0]?.timestamps_match).toBe(true);
  });
});
