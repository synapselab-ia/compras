import { createHash } from "node:crypto";

import { Pool } from "pg";
import { afterAll, beforeAll, beforeEach, describe, expect, it, vi } from "vitest";

vi.mock("server-only", () => ({}));

import {
  consumeSignInLimiterDigests,
  type SignInLimiterDigests,
} from "./signin-limiter";

const integrationEnabled = process.env.F24_SIGNIN_LIMITER_POSTGRES_TEST === "1";
const describePostgres = integrationEnabled ? describe : describe.skip;

function digest(label: string): string {
  return createHash("sha256").update(`f24:${label}`, "utf8").digest("hex");
}

function buckets(label: string): SignInLimiterDigests {
  return Object.freeze({
    source: digest(`source:${label}`),
    identifier: digest(`identifier:${label}`),
    pair: digest(`pair:${label}`),
  });
}

describePostgres("F24 PostgreSQL sign-in limiter boundary", () => {
  let authPool: Pool;
  let domainPool: Pool;
  let adminPool: Pool;

  beforeAll(() => {
    const authUrl = process.env.AUTH_INTEGRATION_DATABASE_URL;
    const domainUrl = process.env.AUTH_INTEGRATION_DOMAIN_DATABASE_URL;
    const adminUrl = process.env.AUTH_INTEGRATION_SUPERUSER_DATABASE_URL;

    if (!authUrl || !domainUrl || !adminUrl) {
      throw new Error("F24 PostgreSQL integration references are required");
    }

    authPool = new Pool({ connectionString: authUrl, max: 20 });
    domainPool = new Pool({ connectionString: domainUrl, max: 2 });
    adminPool = new Pool({ connectionString: adminUrl, max: 2 });
  });

  beforeEach(async () => {
    await adminPool.query("truncate table auth_guard.signin_rate_limit_buckets");
  });

  afterAll(async () => {
    await Promise.all([authPool?.end(), domainPool?.end(), adminPool?.end()]);
  });

  it("keeps the runtime non-privileged with EXECUTE-only limiter access", async () => {
    const role = await adminPool.query<{
      rolsuper: boolean;
      rolbypassrls: boolean;
      rolcreatedb: boolean;
      rolcreaterole: boolean;
      rolreplication: boolean;
      rolinherit: boolean;
    }>(
      `select rolsuper, rolbypassrls, rolcreatedb, rolcreaterole, rolreplication, rolinherit
         from pg_roles
        where rolname = 'compras_auth_runtime'`,
    );

    expect(role.rows[0]).toEqual({
      rolsuper: false,
      rolbypassrls: false,
      rolcreatedb: false,
      rolcreaterole: false,
      rolreplication: false,
      rolinherit: false,
    });

    const privileges = await adminPool.query<{
      schema_usage: boolean;
      function_execute: boolean;
      table_select: boolean;
      table_insert: boolean;
      table_update: boolean;
      table_delete: boolean;
      owned_relations: string;
    }>(
      `select
         has_schema_privilege('compras_auth_runtime', 'auth_guard', 'USAGE') as schema_usage,
         has_function_privilege(
           'compras_auth_runtime',
           'auth_guard.consume_signin_attempt(text,text,text)',
           'EXECUTE'
         ) as function_execute,
         has_table_privilege(
           'compras_auth_runtime',
           'auth_guard.signin_rate_limit_buckets',
           'SELECT'
         ) as table_select,
         has_table_privilege(
           'compras_auth_runtime',
           'auth_guard.signin_rate_limit_buckets',
           'INSERT'
         ) as table_insert,
         has_table_privilege(
           'compras_auth_runtime',
           'auth_guard.signin_rate_limit_buckets',
           'UPDATE'
         ) as table_update,
         has_table_privilege(
           'compras_auth_runtime',
           'auth_guard.signin_rate_limit_buckets',
           'DELETE'
         ) as table_delete,
         (
           select count(*)::text
             from pg_class c
             join pg_namespace n on n.oid = c.relnamespace
             join pg_roles r on r.oid = c.relowner
            where n.nspname = 'auth_guard'
              and r.rolname = 'compras_auth_runtime'
         ) as owned_relations`,
    );

    expect(privileges.rows[0]).toEqual({
      schema_usage: true,
      function_execute: true,
      table_select: false,
      table_insert: false,
      table_update: false,
      table_delete: false,
      owned_relations: "0",
    });

    await expect(
      authPool.query("select * from auth_guard.signin_rate_limit_buckets limit 1"),
    ).rejects.toMatchObject({ code: "42501" });

    const sample = buckets("domain-deny");
    await expect(
      domainPool.query(
        "select auth_guard.consume_signin_attempt($1, $2, $3)",
        [sample.source, sample.identifier, sample.pair],
      ),
    ).rejects.toMatchObject({ code: "42501" });
  });

  it("enforces source 120/15m without contaminating unique identifier/pair buckets", async () => {
    const source = digest("source:fixed-120");

    for (let attempt = 1; attempt <= 120; attempt += 1) {
      const decision = await consumeSignInLimiterDigests(authPool, {
        source,
        identifier: digest(`identifier:source-test:${attempt}`),
        pair: digest(`pair:source-test:${attempt}`),
      });
      expect(decision).toBe("allowed");
    }

    await expect(
      consumeSignInLimiterDigests(authPool, {
        source,
        identifier: digest("identifier:source-test:121"),
        pair: digest("pair:source-test:121"),
      }),
    ).resolves.toBe("rejected");
  });

  it("enforces identifier 20/15m without a global blocking bucket", async () => {
    const identifier = digest("identifier:fixed-20");

    for (let attempt = 1; attempt <= 20; attempt += 1) {
      const decision = await consumeSignInLimiterDigests(authPool, {
        source: digest(`source:identifier-test:${attempt}`),
        identifier,
        pair: digest(`pair:identifier-test:${attempt}`),
      });
      expect(decision).toBe("allowed");
    }

    await expect(
      consumeSignInLimiterDigests(authPool, {
        source: digest("source:identifier-test:21"),
        identifier,
        pair: digest("pair:identifier-test:21"),
      }),
    ).resolves.toBe("rejected");

    await expect(consumeSignInLimiterDigests(authPool, buckets("unrelated"))).resolves.toBe(
      "allowed",
    );
  });

  it("enforces pair 8/5m and allows again after the database window expires", async () => {
    const fixed = buckets("pair-window");

    for (let attempt = 1; attempt <= 8; attempt += 1) {
      await expect(consumeSignInLimiterDigests(authPool, fixed)).resolves.toBe("allowed");
    }

    await expect(consumeSignInLimiterDigests(authPool, fixed)).resolves.toBe("rejected");

    await adminPool.query(
      `update auth_guard.signin_rate_limit_buckets
          set window_started_at = clock_timestamp() - interval '10 minutes',
              window_ends_at = clock_timestamp() - interval '1 second'
        where bucket_kind = 'pair'
          and bucket_digest = $1`,
      [fixed.pair],
    );

    await expect(consumeSignInLimiterDigests(authPool, fixed)).resolves.toBe("allowed");
  });

  it("serializes concurrent bursts without allowing more than the pair maximum", async () => {
    const fixed = buckets("concurrent-burst");
    const decisions = await Promise.all(
      Array.from({ length: 32 }, () => consumeSignInLimiterDigests(authPool, fixed)),
    );

    expect(decisions.filter((decision) => decision === "allowed")).toHaveLength(8);
    expect(decisions.filter((decision) => decision === "rejected")).toHaveLength(24);
    expect(decisions).not.toContain("unavailable");

    const persisted = await adminPool.query<{ attempt_count: number }>(
      `select attempt_count
         from auth_guard.signin_rate_limit_buckets
        where bucket_kind = 'pair'
          and bucket_digest = $1`,
      [fixed.pair],
    );
    expect(persisted.rows[0]?.attempt_count).toBe(32);
  });

  it("purges expired rows opportunistically while preserving active buckets", async () => {
    const expired = digest("expired-row");
    const active = digest("active-row");

    await adminPool.query(
      `insert into auth_guard.signin_rate_limit_buckets (
         bucket_kind,
         bucket_digest,
         window_started_at,
         window_ends_at,
         attempt_count,
         updated_at
       ) values
       ('source', $1, clock_timestamp() - interval '20 minutes', clock_timestamp() - interval '5 minutes', 1, clock_timestamp()),
       ('source', $2, clock_timestamp(), clock_timestamp() + interval '15 minutes', 1, clock_timestamp())`,
      [expired, active],
    );

    await expect(consumeSignInLimiterDigests(authPool, buckets("cleanup-trigger"))).resolves.toBe(
      "allowed",
    );

    const rows = await adminPool.query<{ bucket_digest: string }>(
      `select bucket_digest
         from auth_guard.signin_rate_limit_buckets
        where bucket_digest = any($1::text[])
        order by bucket_digest`,
      [[expired, active]],
    );

    expect(rows.rows.map((row) => row.bucket_digest)).toEqual([active]);
  });

  it("maps invalid primitive input or missing EXECUTE grant to unavailable", async () => {
    await expect(
      consumeSignInLimiterDigests(authPool, {
        source: "not-a-digest",
        identifier: digest("identifier:invalid-input"),
        pair: digest("pair:invalid-input"),
      }),
    ).resolves.toBe("unavailable");

    await adminPool.query(
      "revoke execute on function auth_guard.consume_signin_attempt(text,text,text) from compras_auth_runtime",
    );

    try {
      await expect(
        consumeSignInLimiterDigests(authPool, buckets("revoked-execute")),
      ).resolves.toBe("unavailable");
    } finally {
      await adminPool.query(
        "grant execute on function auth_guard.consume_signin_attempt(text,text,text) to compras_auth_runtime",
      );
    }
  });
});
