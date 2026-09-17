import { Pool, type PoolClient } from "pg";
import { afterAll, beforeAll, beforeEach, describe, expect, it } from "vitest";

const integrationEnabled = process.env.F38_CONTRACTING_ITEM_MUTATION_POSTGRES_TEST === "1";
const describePostgres = integrationEnabled ? describe : describe.skip;

const TEAM_ID = "38210000-0000-4000-8000-000000000001";
const SECOND_TEAM_ID = "38210000-0000-4000-8000-000000000002";
const USER_ID = "38220000-0000-4000-8000-000000000001";
const MEMBERSHIP_ID = "38230000-0000-4000-8000-000000000001";
const SECOND_MEMBERSHIP_ID = "38230000-0000-4000-8000-000000000002";
const CONTRACTING_ID = "38240000-0000-4000-8000-000000000001";
const ITEM_ID = "38250000-0000-4000-8000-000000000001";
const ISSUER = "urn:compras:better-auth:self-hosted:v1";
const SUBJECT = "DEMO-F38-CONCURRENT";
const BASE_UPDATED_AT = "2026-01-01T00:00:00Z";

function eventUuid(writer: number, field: number): string {
  const candidate = writer * 10 + field;
  return `38260000-0000-4000-8000-${candidate.toString().padStart(12, "0")}`;
}

describePostgres("F38 PostgreSQL contracting item mutation concurrency boundary", () => {
  let runtimePool: Pool;
  let adminPool: Pool;

  beforeAll(async () => {
    const runtimeUrl = process.env.F38_DOMAIN_RUNTIME_DATABASE_URL;
    const adminUrl = process.env.F38_ADMIN_DATABASE_URL;

    if (!runtimeUrl || !adminUrl) {
      throw new Error("F38 PostgreSQL integration references are required");
    }

    runtimePool = new Pool({ connectionString: runtimeUrl, max: 12 });
    adminPool = new Pool({ connectionString: adminUrl, max: 8 });

    await adminPool.query(
      `insert into public.teams (id, name, created_at, archived_at)
       values
         ($1::uuid, 'DEMO-F38-Concurrent-Team', '2026-01-01T00:00:00Z', null),
         ($2::uuid, 'DEMO-F38-Second-Team', '2026-01-01T00:00:00Z', null)`,
      [TEAM_ID, SECOND_TEAM_ID],
    );
    await adminPool.query(
      `insert into public.app_users (
         id, auth_issuer, auth_subject, display_name, created_at, disabled_at
       ) values (
         $1::uuid, $2, $3, 'DEMO F38 Concurrent', '2026-01-01T00:00:00Z', null
       )`,
      [USER_ID, ISSUER, SUBJECT],
    );
    await adminPool.query(
      `insert into public.memberships (id, team_id, user_id, joined_at, revoked_at)
       values
         ($1::uuid, $2::uuid, $3::uuid, '2026-01-01T00:00:00Z', null),
         ($4::uuid, $5::uuid, $3::uuid, '2026-01-01T00:00:00Z', null)`,
      [MEMBERSHIP_ID, TEAM_ID, USER_ID, SECOND_MEMBERSHIP_ID, SECOND_TEAM_ID],
    );
    await adminPool.query(
      `insert into public.contractings (
         id, team_id, object, created_at, updated_at, archived_at, cancelled_at
       ) values (
         $1::uuid, $2::uuid, 'DEMO F38 concurrent parent',
         '2026-01-01T00:00:00Z', $3::timestamptz, null, null
       )`,
      [CONTRACTING_ID, TEAM_ID, BASE_UPDATED_AT],
    );
    await adminPool.query(
      `insert into public.contracting_items (
         id, team_id, contracting_id, ordinal, description, quantity, unit,
         catalog_code, created_at, updated_at, retired_at
       ) values (
         $1::uuid, $2::uuid, $3::uuid, 1, 'DEMO F38 old', 10.2500, 'kg',
         'CAT-OLD', '2026-01-01T00:00:00Z', $4::timestamptz, null
       )`,
      [ITEM_ID, TEAM_ID, CONTRACTING_ID, BASE_UPDATED_AT],
    );
  });

  beforeEach(async () => {
    await adminPool.query(
      `delete from public.contracting_events
       where contracting_id = $1::uuid`,
      [CONTRACTING_ID],
    );
    await adminPool.query(
      `update public.contracting_items
       set description = 'DEMO F38 old', quantity = 10.2500, unit = 'kg',
           catalog_code = 'CAT-OLD', updated_at = $2::timestamptz,
           retired_at = null
       where id = $1::uuid`,
      [ITEM_ID, BASE_UPDATED_AT],
    );
    await adminPool.query(
      `update public.contractings
       set archived_at = null, cancelled_at = null, updated_at = $2::timestamptz
       where id = $1::uuid`,
      [CONTRACTING_ID, BASE_UPDATED_AT],
    );
    await adminPool.query(
      `update public.memberships
       set revoked_at = null
       where id = $1::uuid`,
      [MEMBERSHIP_ID],
    );
  });

  afterAll(async () => {
    await Promise.all([runtimePool?.end(), adminPool?.end()]);
  });

  async function mutateItem(writer: number): Promise<string> {
    const client = await runtimePool.connect();

    try {
      await client.query("begin");
      await client.query("select set_config('request.jwt.claims', $1, true)", [
        JSON.stringify({ iss: ISSUER, sub: SUBJECT }),
      ]);
      const result = await client.query<{ outcome: string }>(
        `select public.mutate_contracting_item_fields(
           $1::uuid, $2::uuid,
           $3::text, $4::numeric, $5::text, $6::text,
           $7::text, $8::numeric, $9::text, $10::text,
           $11::uuid, $12::uuid, $13::uuid, $14::uuid
         ) as outcome`,
        [
          CONTRACTING_ID,
          ITEM_ID,
          "DEMO F38 old",
          "10.2500",
          "kg",
          "CAT-OLD",
          "DEMO F38 winner",
          "-20.5000",
          "  unidade  ",
          "CAT-NEW",
          eventUuid(writer, 1),
          eventUuid(writer, 2),
          eventUuid(writer, 3),
          eventUuid(writer, 4),
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

  async function waitForItemLockWait(): Promise<void> {
    const deadline = Date.now() + 5_000;

    while (Date.now() < deadline) {
      const result = await adminPool.query<{ blocked: boolean }>(
        `select exists (
           select 1
           from pg_catalog.pg_stat_activity
           where datname = current_database()
             and usename = 'compras_domain_runtime_f38_ci'
             and query like '%mutate_contracting_item_fields%'
             and wait_event_type = 'Lock'
         ) as blocked`,
      );

      if (result.rows[0]?.blocked) {
        return;
      }

      await new Promise((resolve) => setTimeout(resolve, 25));
    }

    throw new Error("F38 writer did not block on item row lock");
  }

  it("allows exactly one of eight same-snapshot writers and conflicts the seven losers", async () => {
    const outcomes = await Promise.all(
      Array.from({ length: 8 }, (_, index) => mutateItem(index + 1)),
    );

    expect(outcomes.filter((outcome) => outcome === "updated")).toHaveLength(1);
    expect(outcomes.filter((outcome) => outcome === "conflict")).toHaveLength(7);

    const item = await adminPool.query<{
      description: string;
      quantity: string;
      unit: string;
      catalog_code: string;
      updated_at: Date;
    }>(
      `select description, quantity::text as quantity, unit, catalog_code, updated_at
       from public.contracting_items where id = $1::uuid`,
      [ITEM_ID],
    );
    expect(item.rows[0]?.description).toBe("DEMO F38 winner");
    expect(item.rows[0]?.quantity).toBe("-20.5000");
    expect(item.rows[0]?.unit).toBe("  unidade  ");
    expect(item.rows[0]?.catalog_code).toBe("CAT-NEW");
    expect(item.rows[0]?.updated_at.toISOString()).not.toBe("2026-01-01T00:00:00.000Z");

    const events = await adminPool.query<{
      event_count: string;
      distinct_time_count: string;
      matching_time_count: string;
    }>(
      `select
         count(*)::text as event_count,
         count(distinct occurred_at)::text as distinct_time_count,
         count(*) filter (
           where occurred_at = created_at
             and occurred_at = (select updated_at from public.contracting_items where id = $1::uuid)
         )::text as matching_time_count
       from public.contracting_events
       where item_id = $1::uuid and event_type = 'item_changed'`,
      [ITEM_ID],
    );
    expect(events.rows[0]?.event_count).toBe("4");
    expect(events.rows[0]?.distinct_time_count).toBe("1");
    expect(events.rows[0]?.matching_time_count).toBe("4");

    const retry = await mutateItem(99);
    expect(retry).toBe("conflict");

    const afterRetry = await adminPool.query<{ event_count: string }>(
      `select count(*)::text as event_count
       from public.contracting_events
       where item_id = $1::uuid and event_type = 'item_changed'`,
      [ITEM_ID],
    );
    expect(afterRetry.rows[0]?.event_count).toBe("4");
  });

  it("rejects invalid numeric text before the primitive can mutate state", async () => {
    const client = await runtimePool.connect();
    try {
      await client.query("begin");
      await client.query("select set_config('request.jwt.claims', $1, true)", [
        JSON.stringify({ iss: ISSUER, sub: SUBJECT }),
      ]);

      await expect(
        client.query(
          `select public.mutate_contracting_item_fields(
             $1::uuid, $2::uuid,
             $3::text, $4::numeric, $5::text, $6::text,
             $7::text, $8::numeric, $9::text, $10::text,
             $11::uuid, $12::uuid, $13::uuid, $14::uuid
           ) as outcome`,
          [
            CONTRACTING_ID,
            ITEM_ID,
            "DEMO F38 old",
            "10.2500",
            "kg",
            "CAT-OLD",
            "DEMO invalid numeric",
            "not-a-number",
            "kg",
            "CAT-OLD",
            eventUuid(201, 1),
            eventUuid(201, 2),
            eventUuid(201, 3),
            eventUuid(201, 4),
          ],
        ),
      ).rejects.toThrow();
      await client.query("rollback");
    } finally {
      try {
        await client.query("rollback");
      } catch {
        // Connection is discarded below.
      }
      client.release(true);
    }

    const residue = await adminPool.query<{
      description: string;
      updated_at: Date;
      event_count: string;
    }>(
      `select
         item.description,
         item.updated_at,
         (select count(*) from public.contracting_events where item_id = item.id)::text as event_count
       from public.contracting_items as item
       where item.id = $1::uuid`,
      [ITEM_ID],
    );
    expect(residue.rows[0]?.description).toBe("DEMO F38 old");
    expect(residue.rows[0]?.updated_at.toISOString()).toBe("2026-01-01T00:00:00.000Z");
    expect(residue.rows[0]?.event_count).toBe("0");
  });

  it("revalidates an archived parent after waiting on the item lock", async () => {
    const lockClient: PoolClient = await adminPool.connect();
    let writer: Promise<string> | null = null;

    try {
      await lockClient.query("begin");
      await lockClient.query(
        "select id from public.contracting_items where id = $1::uuid for update",
        [ITEM_ID],
      );

      writer = mutateItem(301);
      await waitForItemLockWait();
      await adminPool.query(
        `update public.contractings
         set archived_at = '2026-01-03T00:00:00Z'
         where id = $1::uuid`,
        [CONTRACTING_ID],
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

    const residue = await adminPool.query<{ event_count: string; description: string }>(
      `select item.description,
              (select count(*) from public.contracting_events where item_id=item.id)::text as event_count
       from public.contracting_items as item where item.id=$1::uuid`,
      [ITEM_ID],
    );
    expect(residue.rows[0]?.description).toBe("DEMO F38 old");
    expect(residue.rows[0]?.event_count).toBe("0");
  });

  it("revalidates membership revocation after waiting on the item lock", async () => {
    const lockClient: PoolClient = await adminPool.connect();
    let writer: Promise<string> | null = null;

    try {
      await lockClient.query("begin");
      await lockClient.query(
        "select id from public.contracting_items where id = $1::uuid for update",
        [ITEM_ID],
      );

      writer = mutateItem(401);
      await waitForItemLockWait();
      await adminPool.query(
        `update public.memberships
         set revoked_at = '2026-01-03T00:00:00Z'
         where id = $1::uuid`,
        [MEMBERSHIP_ID],
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

    const residue = await adminPool.query<{ event_count: string; description: string }>(
      `select item.description,
              (select count(*) from public.contracting_events where item_id=item.id)::text as event_count
       from public.contracting_items as item where item.id=$1::uuid`,
      [ITEM_ID],
    );
    expect(residue.rows[0]?.description).toBe("DEMO F38 old");
    expect(residue.rows[0]?.event_count).toBe("0");
  });
});
