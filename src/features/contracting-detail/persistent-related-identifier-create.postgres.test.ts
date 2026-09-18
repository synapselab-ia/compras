import { Pool } from "pg";
import { afterAll, beforeAll, beforeEach, describe, expect, it } from "vitest";

const integrationEnabled = process.env.F41_RELATED_IDENTIFIER_CREATE_POSTGRES_TEST === "1";
const describePostgres = integrationEnabled ? describe : describe.skip;

const TEAM_ID = "41910000-0000-4000-8000-000000000001";
const USER_ID = "41920000-0000-4000-8000-000000000001";
const MEMBERSHIP_ID = "41930000-0000-4000-8000-000000000001";
const CONTRACTING_ID = "41940000-0000-4000-8000-000000000001";
const SAME_ID = "41950000-0000-4000-8000-000000000001";
const DIVERGENT_ID = "41950000-0000-4000-8000-000000000002";
const DISTINCT_A_ID = "41950000-0000-4000-8000-000000000003";
const DISTINCT_B_ID = "41950000-0000-4000-8000-000000000004";
const ISSUER = "urn:compras:better-auth:self-hosted:v1";
const SUBJECT = "DEMO-F41-CONCURRENT";
const VALUE = "  DEMO F41 concurrent identifier preserved  ";

describePostgres("F41 PostgreSQL related identifier concurrency boundary", () => {
  let runtimePool: Pool;
  let adminPool: Pool;
  let eventSequence = 1;

  beforeAll(async () => {
    const runtimeUrl = process.env.F41_DOMAIN_RUNTIME_DATABASE_URL;
    const adminUrl = process.env.F41_ADMIN_DATABASE_URL;

    if (!runtimeUrl || !adminUrl) {
      throw new Error("F41 PostgreSQL integration references are required");
    }

    runtimePool = new Pool({ connectionString: runtimeUrl, max: 16 });
    adminPool = new Pool({ connectionString: adminUrl, max: 3 });

    await adminPool.query(
      `insert into public.teams (id, name, created_at, archived_at)
       values ($1::uuid, 'DEMO-F41-Team-Concurrent', '2026-01-01T00:00:00Z', null)`,
      [TEAM_ID],
    );
    await adminPool.query(
      `insert into public.app_users (
         id, auth_issuer, auth_subject, display_name, created_at, disabled_at
       ) values (
         $1::uuid, $2, $3, 'DEMO F41 Concurrent', '2026-01-01T00:00:00Z', null
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
         $1::uuid, $2::uuid, 'DEMO F41 concurrent target',
         '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z', null, null
       )`,
      [CONTRACTING_ID, TEAM_ID],
    );
  });

  async function clearCandidates(): Promise<void> {
    const ids = [SAME_ID, DIVERGENT_ID, DISTINCT_A_ID, DISTINCT_B_ID];

    await adminPool.query(
      "delete from public.contracting_events where related_identifier_id = any($1::uuid[])",
      [ids],
    );
    await adminPool.query(
      "delete from public.related_identifiers where id = any($1::uuid[])",
      [ids],
    );
  }

  beforeEach(async () => {
    await clearCandidates();
  });

  afterAll(async () => {
    await Promise.all([runtimePool?.end(), adminPool?.end()]);
  });

  function nextEventId(): string {
    const suffix = eventSequence.toString().padStart(12, "0");
    eventSequence += 1;
    return `41960000-0000-4000-8000-${suffix}`;
  }

  async function create(
    relatedIdentifierId: string,
    identifierValue: string,
    identifierKind: string | null = "DEMO-kind",
    sourceSystem: string | null = "DEMO-source",
    note: string | null = "DEMO-note",
  ): Promise<string> {
    const client = await runtimePool.connect();
    const eventId = nextEventId();

    try {
      await client.query("begin");
      await client.query(
        "select set_config('request.jwt.claims', $1, true)",
        [JSON.stringify({ iss: ISSUER, sub: SUBJECT })],
      );
      const result = await client.query<{ outcome: string }>(
        `select public.create_related_identifier(
           $1::uuid, $2::uuid, $3::text, $4::text, $5::text, $6::text, $7::uuid
         ) as outcome`,
        [
          CONTRACTING_ID,
          relatedIdentifierId,
          identifierKind,
          identifierValue,
          sourceSystem,
          note,
          eventId,
        ],
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

  it("collapses concurrent retries of one prepared UUID into one row and one canonical event", async () => {
    for (let round = 0; round < 3; round += 1) {
      if (round > 0) {
        await clearCandidates();
      }

      const outcomes = await Promise.all(
        Array.from({ length: 8 }, () => create(SAME_ID, VALUE)),
      );

      expect(outcomes.filter((outcome) => outcome === "created")).toHaveLength(1);
      expect(outcomes.filter((outcome) => outcome === "already-linked")).toHaveLength(7);
    }

    const persisted = await adminPool.query<{
      identifier_value: string;
      team_id: string;
      contracting_id: string;
      event_count: string;
      canonical_event_count: string;
      timestamps_match: boolean;
      parent_updated_at: Date;
    }>(
      `select
         related.identifier_value,
         related.team_id::text,
         related.contracting_id::text,
         count(event.id)::text as event_count,
         count(event.id) filter (
           where event.event_type = 'related_identifier_linked'
             and event.team_id = $2::uuid
             and event.contracting_id = $3::uuid
             and event.actor_membership_id = $4::uuid
             and event.related_identifier_id = related.id
             and event.field_key is null
             and event.old_value is null
             and event.new_value is null
             and event.note is null
             and event.item_id is null
         )::text as canonical_event_count,
         bool_and(
           related.linked_at = event.occurred_at
           and event.occurred_at = event.created_at
         ) as timestamps_match,
         max(contracting.updated_at) as parent_updated_at
       from public.related_identifiers as related
       join public.contractings as contracting
         on contracting.id = related.contracting_id
        and contracting.team_id = related.team_id
       left join public.contracting_events as event
         on event.related_identifier_id = related.id
        and event.contracting_id = related.contracting_id
        and event.team_id = related.team_id
       where related.id = $1::uuid
       group by related.id`,
      [SAME_ID, TEAM_ID, CONTRACTING_ID, MEMBERSHIP_ID],
    );

    expect(persisted.rows).toHaveLength(1);
    expect(persisted.rows[0]?.identifier_value).toBe(VALUE);
    expect(persisted.rows[0]?.team_id).toBe(TEAM_ID);
    expect(persisted.rows[0]?.contracting_id).toBe(CONTRACTING_ID);
    expect(persisted.rows[0]?.event_count).toBe("1");
    expect(persisted.rows[0]?.canonical_event_count).toBe("1");
    expect(persisted.rows[0]?.timestamps_match).toBe(true);
    expect(persisted.rows[0]?.parent_updated_at.toISOString()).toBe(
      "2026-01-01T00:00:00.000Z",
    );
  });

  it("does not overwrite when concurrent calls reuse one UUID with divergent payloads", async () => {
    const outcomes = await Promise.all([
      create(DIVERGENT_ID, "DEMO divergent A"),
      create(DIVERGENT_ID, "DEMO divergent B"),
    ]);

    expect(outcomes.filter((outcome) => outcome === "created")).toHaveLength(1);
    expect(outcomes.filter((outcome) => outcome === "denied")).toHaveLength(1);

    const state = await adminPool.query<{
      identifier_value: string;
      event_count: string;
    }>(
      `select
         related.identifier_value,
         count(event.id)::text as event_count
       from public.related_identifiers as related
       left join public.contracting_events as event
         on event.related_identifier_id = related.id
       where related.id = $1::uuid
       group by related.id`,
      [DIVERGENT_ID],
    );

    expect(state.rows).toHaveLength(1);
    expect(["DEMO divergent A", "DEMO divergent B"]).toContain(
      state.rows[0]?.identifier_value,
    );
    expect(state.rows[0]?.event_count).toBe("1");
  });

  it("allows distinct UUIDs to carry identical textual payloads", async () => {
    const outcomes = await Promise.all([
      create(DISTINCT_A_ID, VALUE, null, "", "   "),
      create(DISTINCT_B_ID, VALUE, null, "", "   "),
    ]);

    expect(outcomes).toEqual(["created", "created"]);

    const state = await adminPool.query<{ row_count: string; event_count: string }>(
      `select
         count(distinct related.id)::text as row_count,
         count(event.id)::text as event_count
       from public.related_identifiers as related
       left join public.contracting_events as event
         on event.related_identifier_id = related.id
       where related.id = any($1::uuid[])`,
      [[DISTINCT_A_ID, DISTINCT_B_ID]],
    );

    expect(state.rows[0]?.row_count).toBe("2");
    expect(state.rows[0]?.event_count).toBe("2");
  });
});
