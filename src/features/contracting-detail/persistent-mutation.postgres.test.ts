import { Pool } from "pg";
import { afterAll, beforeAll, beforeEach, describe, expect, it } from "vitest";

const integrationEnabled = process.env.F26_NEXT_ACTION_POSTGRES_TEST === "1";
const describePostgres = integrationEnabled ? describe : describe.skip;

const TARGET_ID = "26040000-0000-4000-8000-000000000010";
const TEAM_ID = "26010000-0000-4000-8000-000000000010";
const USER_ID = "26020000-0000-4000-8000-000000000010";
const MEMBERSHIP_ID = "26030000-0000-4000-8000-000000000010";
const ISSUER = "urn:compras:better-auth:self-hosted:v1";
const SUBJECT = "DEMO-F26-CONCURRENT";
const INITIAL_NEXT_ACTION = "DEMO concurrent old";

describePostgres("F26 PostgreSQL next_action concurrency boundary", () => {
  let runtimePool: Pool;
  let adminPool: Pool;

  beforeAll(async () => {
    const runtimeUrl = process.env.F26_DOMAIN_RUNTIME_DATABASE_URL;
    const adminUrl = process.env.F26_ADMIN_DATABASE_URL;

    if (!runtimeUrl || !adminUrl) {
      throw new Error("F26 PostgreSQL integration references are required");
    }

    runtimePool = new Pool({ connectionString: runtimeUrl, max: 12 });
    adminPool = new Pool({ connectionString: adminUrl, max: 2 });

    await adminPool.query(
      `insert into public.teams (id, name, created_at)
       values ($1::uuid, 'DEMO-F26-Team-Concurrent', '2026-01-01T00:00:00Z')`,
      [TEAM_ID],
    );
    await adminPool.query(
      `insert into public.app_users (
         id, auth_issuer, auth_subject, display_name, created_at, disabled_at
       ) values (
         $1::uuid, $2, $3, 'DEMO F26 Concurrent', '2026-01-01T00:00:00Z', null
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
         id, team_id, object, next_action, created_at, updated_at
       ) values (
         $1::uuid, $2::uuid, 'DEMO F26 Concurrent Contracting', $3,
         '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z'
       )`,
      [TARGET_ID, TEAM_ID, INITIAL_NEXT_ACTION],
    );
  });

  beforeEach(async () => {
    await adminPool.query(
      "delete from public.contracting_events where contracting_id = $1::uuid",
      [TARGET_ID],
    );
    await adminPool.query(
      `update public.contractings
          set next_action = $2,
              updated_at = '2026-01-01T00:00:00Z'
        where id = $1::uuid`,
      [TARGET_ID, INITIAL_NEXT_ACTION],
    );
  });

  afterAll(async () => {
    await Promise.all([runtimePool?.end(), adminPool?.end()]);
  });

  async function mutate(candidate: number): Promise<string> {
    const client = await runtimePool.connect();
    const eventId = `26050000-0000-4000-8000-${candidate.toString().padStart(12, "0")}`;
    const nextAction = `DEMO concurrent winner ${candidate}`;

    try {
      await client.query("begin");
      await client.query(
        "select set_config('request.jwt.claims', $1, true)",
        [JSON.stringify({ iss: ISSUER, sub: SUBJECT })],
      );
      const result = await client.query<{ outcome: string }>(
        `select public.mutate_contracting_next_action(
           $1::uuid, $2::text, $3::text, $4::uuid
         ) as outcome`,
        [TARGET_ID, INITIAL_NEXT_ACTION, nextAction, eventId],
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

  it("serializes stale writers so exactly one update/event wins", async () => {
    const outcomes = await Promise.all(
      Array.from({ length: 8 }, (_, index) => mutate(index + 1)),
    );

    expect(outcomes.filter((outcome) => outcome === "updated")).toHaveLength(1);
    expect(outcomes.filter((outcome) => outcome === "conflict")).toHaveLength(7);

    const persisted = await adminPool.query<{
      next_action: string;
      event_count: string;
      matching_event_count: string;
    }>(
      `select
         contracting.next_action,
         count(event.id)::text as event_count,
         count(event.id) filter (
           where event.old_value = $2
             and event.new_value = contracting.next_action
             and event.actor_membership_id = $3::uuid
             and event.team_id = $4::uuid
         )::text as matching_event_count
       from public.contractings as contracting
       left join public.contracting_events as event
         on event.contracting_id = contracting.id
       where contracting.id = $1::uuid
       group by contracting.next_action`,
      [TARGET_ID, INITIAL_NEXT_ACTION, MEMBERSHIP_ID, TEAM_ID],
    );

    expect(persisted.rows[0]?.next_action).toMatch(/^DEMO concurrent winner [1-8]$/);
    expect(persisted.rows[0]?.event_count).toBe("1");
    expect(persisted.rows[0]?.matching_event_count).toBe("1");

    const timestamps = await adminPool.query<{ count: string }>(
      `select count(*)::text as count
         from public.contractings as contracting
         join public.contracting_events as event
           on event.contracting_id = contracting.id
          and event.team_id = contracting.team_id
        where contracting.id = $1::uuid
          and contracting.updated_at = event.occurred_at
          and event.occurred_at = event.created_at`,
      [TARGET_ID],
    );

    expect(timestamps.rows[0]?.count).toBe("1");
  });
});
