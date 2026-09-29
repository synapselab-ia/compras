import { Pool } from "pg";
import { afterAll, beforeAll, beforeEach, describe, expect, it } from "vitest";

const integrationEnabled =
  process.env.F47_CONTRACTING_RESPONSIBLE_MUTATION_POSTGRES_TEST === "1";
const describePostgres = integrationEnabled ? describe : describe.skip;

const TEAM_ID = "47210000-0000-4000-8000-000000000001";
const USER_ID = "47220000-0000-4000-8000-000000000001";
const MEMBERSHIP_ID = "47230000-0000-4000-8000-000000000001";
const CONTRACTING_ID = "47240000-0000-4000-8000-000000000001";
const ISSUER = "urn:compras:better-auth:self-hosted:v1";
const SUBJECT = "DEMO-F47-CONCURRENT";
const BASE_UPDATED_AT = "2026-01-01T00:00:00Z";

describePostgres("F47 PostgreSQL responsible mutation concurrency boundary", () => {
  let runtimePool: Pool;
  let adminPool: Pool;

  beforeAll(async () => {
    const runtimeUrl = process.env.F47_DOMAIN_RUNTIME_DATABASE_URL;
    const adminUrl = process.env.F47_ADMIN_DATABASE_URL;

    if (!runtimeUrl || !adminUrl) {
      throw new Error("F47 PostgreSQL integration references are required");
    }

    runtimePool = new Pool({ connectionString: runtimeUrl, max: 12 });
    adminPool = new Pool({ connectionString: adminUrl, max: 2 });

    await adminPool.query(
      `insert into public.teams (id, name, created_at)
       values ($1::uuid, 'DEMO-F47-Concurrent-Team', '2026-01-01T00:00:00Z')`,
      [TEAM_ID],
    );
    await adminPool.query(
      `insert into public.app_users (
         id, auth_issuer, auth_subject, display_name, created_at, disabled_at
       ) values (
         $1::uuid, $2, $3, 'DEMO F47 Concurrent', '2026-01-01T00:00:00Z', null
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
         id, team_id, object, responsible_membership_id, created_at, updated_at
       ) values (
         $1::uuid, $2::uuid, 'DEMO F47 concurrent target', null,
         '2026-01-01T00:00:00Z', $3::timestamptz
       )`,
      [CONTRACTING_ID, TEAM_ID, BASE_UPDATED_AT],
    );
  });

  beforeEach(async () => {
    await adminPool.query(
      "delete from public.contracting_events where contracting_id = $1::uuid",
      [CONTRACTING_ID],
    );
    await adminPool.query(
      `update public.contractings
       set responsible_membership_id = null, updated_at = $2::timestamptz,
           archived_at = null, cancelled_at = null
       where id = $1::uuid`,
      [CONTRACTING_ID, BASE_UPDATED_AT],
    );
  });

  afterAll(async () => {
    await Promise.all([runtimePool?.end(), adminPool?.end()]);
  });

  async function mutate(writer: number): Promise<string> {
    const client = await runtimePool.connect();
    const eventId =
      `47250000-0000-4000-8000-${writer.toString().padStart(12, "0")}`;

    try {
      await client.query("begin");
      await client.query("select set_config('request.jwt.claims', $1, true)", [
        JSON.stringify({ iss: ISSUER, sub: SUBJECT }),
      ]);
      const result = await client.query<{ outcome: string }>(
        `select public.mutate_contracting_responsible(
           $1::uuid, $2::uuid, $3::uuid, $4::uuid
         ) as outcome`,
        [CONTRACTING_ID, null, MEMBERSHIP_ID, eventId],
      );
      await client.query("commit");
      return result.rows[0]?.outcome ?? "missing";
    } catch (error) {
      try {
        await client.query("rollback");
      } catch {
        // This client is destroyed below.
      }
      throw error;
    } finally {
      client.release(true);
    }
  }

  it("allows one of eight same-expected writers and conflicts the seven losers", async () => {
    const outcomes = await Promise.all(
      Array.from({ length: 8 }, (_, index) => mutate(index + 1)),
    );

    expect(outcomes.filter((outcome) => outcome === "updated")).toHaveLength(1);
    expect(outcomes.filter((outcome) => outcome === "conflict")).toHaveLength(7);

    const persisted = await adminPool.query<{
      responsible_membership_id: string;
      event_count: string;
      matching_event_count: string;
    }>(
      `select
         contracting.responsible_membership_id::text,
         count(event.id)::text as event_count,
         count(event.id) filter (
           where event.event_type = 'responsible_changed'
             and event.field_key = 'responsible_membership_id'
             and event.old_value is null
             and event.new_value = $2::text
             and event.actor_membership_id = $2::uuid
             and event.team_id = $3::uuid
             and event.note is null
             and event.related_identifier_id is null
             and event.item_id is null
             and event.occurred_at = event.created_at
             and event.occurred_at = contracting.updated_at
         )::text as matching_event_count
       from public.contractings as contracting
       left join public.contracting_events as event
         on event.contracting_id = contracting.id
        and event.team_id = contracting.team_id
       where contracting.id = $1::uuid
       group by contracting.id`,
      [CONTRACTING_ID, MEMBERSHIP_ID, TEAM_ID],
    );

    expect(persisted.rows[0]?.responsible_membership_id).toBe(MEMBERSHIP_ID);
    expect(persisted.rows[0]?.event_count).toBe("1");
    expect(persisted.rows[0]?.matching_event_count).toBe("1");

    expect(await mutate(99)).toBe("conflict");

    const afterRetry = await adminPool.query<{ count: string }>(
      `select count(*)::text as count
       from public.contracting_events
       where contracting_id = $1::uuid`,
      [CONTRACTING_ID],
    );
    expect(afterRetry.rows[0]?.count).toBe("1");
  });
});
