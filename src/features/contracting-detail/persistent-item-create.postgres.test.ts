import { Pool, type PoolClient } from "pg";
import { afterAll, beforeAll, beforeEach, describe, expect, it } from "vitest";

const integrationEnabled = process.env.F35_CONTRACTING_ITEM_CREATE_POSTGRES_TEST === "1";
const describePostgres = integrationEnabled ? describe : describe.skip;

const TEAM_ID = "35110000-0000-4000-8000-000000000001";
const USER_ID = "35120000-0000-4000-8000-000000000001";
const MEMBERSHIP_ID = "35130000-0000-4000-8000-000000000001";
const TARGET_A = "35140000-0000-4000-8000-000000000001";
const TARGET_B = "35140000-0000-4000-8000-000000000002";
const TARGET_C = "35140000-0000-4000-8000-000000000003";
const ISSUER = "urn:compras:better-auth:self-hosted:v1";
const SUBJECT = "DEMO-F35-CONCURRENT";
const BASE_UPDATED_AT = "2026-01-01T00:00:00Z";

function syntheticUuid(prefix: "3516" | "3517", candidate: number): string {
  return `${prefix}0000-0000-4000-8000-${candidate.toString().padStart(12, "0")}`;
}

describePostgres("F35 PostgreSQL contracting item create concurrency boundary", () => {
  let runtimePool: Pool;
  let adminPool: Pool;

  beforeAll(async () => {
    const runtimeUrl = process.env.F35_DOMAIN_RUNTIME_DATABASE_URL;
    const adminUrl = process.env.F35_ADMIN_DATABASE_URL;

    if (!runtimeUrl || !adminUrl) {
      throw new Error("F35 PostgreSQL integration references are required");
    }

    runtimePool = new Pool({ connectionString: runtimeUrl, max: 12 });
    adminPool = new Pool({ connectionString: adminUrl, max: 6 });

    await adminPool.query(
      `insert into public.teams (id, name, created_at, archived_at)
       values ($1::uuid, 'DEMO-F35-Team-Concurrent', '2026-01-01T00:00:00Z', null)`,
      [TEAM_ID],
    );
    await adminPool.query(
      `insert into public.app_users (
         id, auth_issuer, auth_subject, display_name, created_at, disabled_at
       ) values (
         $1::uuid, $2, $3, 'DEMO F35 Concurrent', '2026-01-01T00:00:00Z', null
       )`,
      [USER_ID, ISSUER, SUBJECT],
    );
    await adminPool.query(
      `insert into public.memberships (id, team_id, user_id, joined_at, revoked_at)
       values ($1::uuid, $2::uuid, $3::uuid, '2026-01-01T00:00:00Z', null)`,
      [MEMBERSHIP_ID, TEAM_ID, USER_ID],
    );

    for (const [index, contractingId] of [TARGET_A, TARGET_B, TARGET_C].entries()) {
      await adminPool.query(
        `insert into public.contractings (
           id, team_id, object, created_at, updated_at, archived_at, cancelled_at
         ) values (
           $1::uuid, $2::uuid, $3, '2026-01-01T00:00:00Z', $4::timestamptz, null, null
         )`,
        [contractingId, TEAM_ID, `DEMO F35 concurrent target ${index + 1}`, BASE_UPDATED_AT],
      );
    }
  });

  beforeEach(async () => {
    await adminPool.query(
      `delete from public.contracting_events
       where contracting_id = any($1::uuid[])`,
      [[TARGET_A, TARGET_B, TARGET_C]],
    );
    await adminPool.query(
      `delete from public.contracting_items
       where contracting_id = any($1::uuid[])`,
      [[TARGET_A, TARGET_B, TARGET_C]],
    );
    await adminPool.query(
      `delete from public.contracting_item_ordinal_counters
       where contracting_id = any($1::uuid[])`,
      [[TARGET_A, TARGET_B, TARGET_C]],
    );
    await adminPool.query(
      `update public.contractings
       set archived_at = null, cancelled_at = null, updated_at = $2::timestamptz
       where id = any($1::uuid[])`,
      [[TARGET_A, TARGET_B, TARGET_C], BASE_UPDATED_AT],
    );
  });

  afterAll(async () => {
    await Promise.all([runtimePool?.end(), adminPool?.end()]);
  });

  async function createItem(
    contractingId: string,
    candidate: number,
    description = `DEMO F35 concurrent item ${candidate}`,
  ): Promise<string> {
    const client = await runtimePool.connect();

    try {
      await client.query("begin");
      await client.query(
        "select set_config('request.jwt.claims', $1, true)",
        [JSON.stringify({ iss: ISSUER, sub: SUBJECT })],
      );
      const result = await client.query<{ outcome: string }>(
        `select public.create_contracting_item(
           $1::uuid, $2::text, $3::numeric, $4::text, $5::text,
           $6::uuid, $7::uuid
         ) as outcome`,
        [
          contractingId,
          description,
          null,
          null,
          null,
          syntheticUuid("3516", candidate),
          syntheticUuid("3517", candidate),
        ],
      );
      await client.query("commit");
      return result.rows[0]?.outcome ?? "missing";
    } catch (error) {
      try {
        await client.query("rollback");
      } catch {
        // This test discards the client below.
      }
      throw error;
    } finally {
      client.release(true);
    }
  }

  async function waitForAllocatorLockWait(contractingId: string): Promise<void> {
    const deadline = Date.now() + 5_000;

    while (Date.now() < deadline) {
      const result = await adminPool.query<{ blocked: boolean }>(
        `select exists (
           select 1
           from pg_catalog.pg_stat_activity
           where datname = current_database()
             and usename = 'compras_domain_runtime_f35_ci'
             and query like '%create_contracting_item%'
             and wait_event_type = 'Lock'
         ) as blocked`,
      );

      if (result.rows[0]?.blocked) {
        return;
      }

      await new Promise((resolve) => setTimeout(resolve, 25));
    }

    throw new Error(`writer did not block on allocator row for ${contractingId}`);
  }

  it("serializes eight writers on one allocator and reconciles a stale counter", async () => {
    await adminPool.query(
      `insert into public.contracting_items (
         id, team_id, contracting_id, ordinal, description, quantity, unit,
         catalog_code, created_at, updated_at, retired_at
       ) values (
         '35160000-0000-4000-8000-000000000900'::uuid,
         $1::uuid, $2::uuid, 4, 'DEMO F35 retired prior maximum', null, null,
         null, '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z',
         '2026-01-02T00:00:00Z'
       )`,
      [TEAM_ID, TARGET_A],
    );
    await adminPool.query(
      `insert into public.contracting_item_ordinal_counters (
         team_id, contracting_id, last_ordinal
       ) values ($1::uuid, $2::uuid, 2)`,
      [TEAM_ID, TARGET_A],
    );

    const outcomes = await Promise.all(
      Array.from({ length: 8 }, (_, index) => createItem(TARGET_A, index + 1)),
    );

    expect(outcomes).toEqual(Array(8).fill("created"));

    const items = await adminPool.query<{ ordinal: number; quantity: string | null }>(
      `select ordinal, quantity::text
       from public.contracting_items
       where contracting_id = $1::uuid
         and id <> '35160000-0000-4000-8000-000000000900'::uuid
       order by ordinal`,
      [TARGET_A],
    );

    expect(items.rows.map((row) => row.ordinal)).toEqual([5, 6, 7, 8, 9, 10, 11, 12]);
    expect(items.rows.every((row) => row.quantity === null)).toBe(true);

    const audit = await adminPool.query<{
      event_count: string;
      matching_event_count: string;
      distinct_ordinal_count: string;
      last_ordinal: number;
      timestamps_match: boolean;
    }>(
      `select
         count(event.id)::text as event_count,
         count(event.id) filter (
           where event.event_type = 'item_created'
             and event.team_id = $2::uuid
             and event.actor_membership_id = $3::uuid
             and event.item_id = item.id
             and event.field_key is null
             and event.old_value is null
             and event.new_value is null
             and event.note is null
             and event.related_identifier_id is null
         )::text as matching_event_count,
         count(distinct item.ordinal)::text as distinct_ordinal_count,
         max(counter.last_ordinal) as last_ordinal,
         bool_and(
           item.created_at = item.updated_at
           and item.created_at = event.occurred_at
           and event.occurred_at = event.created_at
         ) as timestamps_match
       from public.contracting_items as item
       join public.contracting_events as event
         on event.item_id = item.id
        and event.contracting_id = item.contracting_id
        and event.team_id = item.team_id
       join public.contracting_item_ordinal_counters as counter
         on counter.contracting_id = item.contracting_id
        and counter.team_id = item.team_id
       where item.contracting_id = $1::uuid
         and item.id <> '35160000-0000-4000-8000-000000000900'::uuid`,
      [TARGET_A, TEAM_ID, MEMBERSHIP_ID],
    );

    expect(audit.rows[0]?.event_count).toBe("8");
    expect(audit.rows[0]?.matching_event_count).toBe("8");
    expect(audit.rows[0]?.distinct_ordinal_count).toBe("8");
    expect(audit.rows[0]?.last_ordinal).toBe(12);
    expect(audit.rows[0]?.timestamps_match).toBe(true);

    const parent = await adminPool.query<{ updated_at: Date }>(
      "select updated_at from public.contractings where id = $1::uuid",
      [TARGET_A],
    );
    expect(parent.rows[0]?.updated_at.toISOString()).toBe("2026-01-01T00:00:00.000Z");
  });

  it("does not serialize a different contracting behind an unrelated allocator row lock", async () => {
    await adminPool.query(
      `insert into public.contracting_item_ordinal_counters (
         team_id, contracting_id, last_ordinal
       ) values ($1::uuid, $2::uuid, null), ($1::uuid, $3::uuid, null)`,
      [TEAM_ID, TARGET_A, TARGET_B],
    );

    const lockClient = await adminPool.connect();
    try {
      await lockClient.query("begin");
      await lockClient.query(
        `select last_ordinal
         from public.contracting_item_ordinal_counters
         where contracting_id = $1::uuid
         for update`,
        [TARGET_A],
      );

      const createB = createItem(TARGET_B, 101);
      const result = await Promise.race([
        createB,
        new Promise<string>((_, reject) =>
          setTimeout(() => reject(new Error("different contracting was globally blocked")), 5_000),
        ),
      ]);

      expect(result).toBe("created");
      await lockClient.query("rollback");
    } finally {
      try {
        await lockClient.query("rollback");
      } catch {
        // Connection is discarded below.
      }
      lockClient.release(true);
    }

    const created = await adminPool.query<{ ordinal: number }>(
      `select ordinal from public.contracting_items
       where contracting_id = $1::uuid`,
      [TARGET_B],
    );
    expect(created.rows.map((row) => row.ordinal)).toEqual([1]);
  });

  it("revalidates the parent after waiting for the allocator lock", async () => {
    await adminPool.query(
      `insert into public.contracting_item_ordinal_counters (
         team_id, contracting_id, last_ordinal
       ) values ($1::uuid, $2::uuid, null)`,
      [TEAM_ID, TARGET_C],
    );

    const lockClient: PoolClient = await adminPool.connect();
    let writer: Promise<string> | null = null;

    try {
      await lockClient.query("begin");
      await lockClient.query(
        `select last_ordinal
         from public.contracting_item_ordinal_counters
         where contracting_id = $1::uuid
         for update`,
        [TARGET_C],
      );

      writer = createItem(TARGET_C, 201, "DEMO must be denied after wait");
      await waitForAllocatorLockWait(TARGET_C);

      await adminPool.query(
        `update public.contractings
         set archived_at = '2026-01-03T00:00:00Z'
         where id = $1::uuid`,
        [TARGET_C],
      );

      await lockClient.query("commit");
      expect(await writer).toBe("denied");
    } finally {
      try {
        await lockClient.query("rollback");
      } catch {
        // Connection is discarded below.
      }
      lockClient.release(true);
    }

    const residue = await adminPool.query<{ item_count: string; event_count: string }>(
      `select
         (select count(*) from public.contracting_items where contracting_id = $1::uuid)::text as item_count,
         (select count(*) from public.contracting_events where contracting_id = $1::uuid)::text as event_count`,
      [TARGET_C],
    );
    expect(residue.rows[0]?.item_count).toBe("0");
    expect(residue.rows[0]?.event_count).toBe("0");
  });
});
