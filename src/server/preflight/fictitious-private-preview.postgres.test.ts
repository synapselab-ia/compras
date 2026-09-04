import { betterAuth } from "better-auth";
import { Pool, type PoolClient, type QueryResultRow } from "pg";
import { afterAll, beforeAll, describe, expect, it, vi } from "vitest";

vi.mock("server-only", () => ({}));

import { bootstrapFictitiousIdentity } from "../auth/bootstrap";
import { SELF_HOSTED_AUTH_ISSUER } from "../auth/configuration";
import {
  FICTITIOUS_PRIVATE_PREVIEW_FIXTURE,
  FICTITIOUS_PRIVATE_PREVIEW_MODE,
  seedFictitiousPrivatePreviewAuthorization,
} from "./fictitious-private-preview";

const integrationEnabled =
  process.env.F22_PRIVATE_PREVIEW_POSTGRES_TEST === "1";
const describePostgres = integrationEnabled ? describe : describe.skip;
const TEST_ORIGIN = "https://f22-private-preview.example.invalid";

function requiredEnvironment(name: string): string {
  const value = process.env[name];

  if (!value) {
    throw new Error(`F22 integration environment is incomplete: ${name}`);
  }

  return value;
}

function cookieHeaderFromSetCookie(responseHeaders: Headers): string {
  return responseHeaders
    .getSetCookie()
    .map((value) => value.split(";", 1)[0])
    .filter(Boolean)
    .join("; ");
}

async function readWithClaims<T extends QueryResultRow>(
  pool: Pool,
  sql: string,
  values: readonly unknown[] = [],
  claims?: unknown,
): Promise<T[]> {
  let client: PoolClient | null = null;
  let transactionOpen = false;

  try {
    client = await pool.connect();
    await client.query("BEGIN READ ONLY");
    transactionOpen = true;

    if (claims !== undefined) {
      const serialized =
        typeof claims === "string" ? claims : JSON.stringify(claims);
      await client.query(
        "SELECT set_config('request.jwt.claims', $1, true)",
        [serialized],
      );
    }

    const result = await client.query<T>(sql, [...values]);
    await client.query("COMMIT");
    transactionOpen = false;

    return result.rows;
  } catch (error) {
    if (client && transactionOpen) {
      await client.query("ROLLBACK").catch(() => undefined);
    }

    throw error;
  } finally {
    client?.release(true);
  }
}

describePostgres("F22 private preview seed and smoke assets", () => {
  let authPool: Pool;
  let domainPool: Pool;
  let adminPool: Pool;
  let bootstrapPassword: string;
  let betterAuthSecret: string;

  beforeAll(() => {
    const authUrl = requiredEnvironment("F22_AUTH_RUNTIME_DATABASE_URL");
    const domainUrl = requiredEnvironment("F22_DOMAIN_RUNTIME_DATABASE_URL");
    const adminUrl = requiredEnvironment("F22_ADMIN_DATABASE_URL");
    bootstrapPassword = requiredEnvironment("F22_BOOTSTRAP_PASSWORD");
    betterAuthSecret = requiredEnvironment("F22_BETTER_AUTH_SECRET");

    process.env.AUTH_DATABASE_URL = authUrl;
    process.env.DATABASE_URL = domainUrl;
    process.env.BETTER_AUTH_SECRET = betterAuthSecret;
    process.env.COMPRAS_AUTH_BASE_URL = TEST_ORIGIN;

    authPool = new Pool({
      connectionString: authUrl,
      options: "-c search_path=auth",
      max: 2,
    });
    domainPool = new Pool({ connectionString: domainUrl, max: 2 });
    adminPool = new Pool({ connectionString: adminUrl, max: 1 });
  });

  afterAll(async () => {
    delete process.env.COMPRAS_AUTH_BOOTSTRAP_MODE;
    delete process.env.COMPRAS_PRIVATE_PREVIEW_PREFLIGHT_MODE;
    delete process.env.AUTH_DATABASE_URL;
    delete process.env.DATABASE_URL;
    delete process.env.BETTER_AUTH_SECRET;
    delete process.env.COMPRAS_AUTH_BASE_URL;

    await Promise.all([
      authPool?.end(),
      domainPool?.end(),
      adminPool?.end(),
    ]);
  });

  it("proves bootstrap, separate authorization, RLS isolation, and fail-closed behavior", async () => {
    process.env.COMPRAS_AUTH_BOOTSTRAP_MODE = "FICTITIOUS_ONE_SHOT";

    await expect(
      bootstrapFictitiousIdentity({
        email: "rejected-f22@example.com",
        password: bootstrapPassword,
        name: "Rejected Fictitious Preview User",
      }),
    ).resolves.toEqual({ kind: "rejected" });

    const bootstrap = await bootstrapFictitiousIdentity({
      email: FICTITIOUS_PRIVATE_PREVIEW_FIXTURE.email,
      password: bootstrapPassword,
      name: FICTITIOUS_PRIVATE_PREVIEW_FIXTURE.displayName,
    });
    delete process.env.COMPRAS_AUTH_BOOTSTRAP_MODE;

    expect(bootstrap.kind).toBe("created");
    if (bootstrap.kind !== "created") return;

    const domainCountsBeforeSeed = await adminPool.query<{
      app_users: string;
      memberships: string;
    }>(
      `SELECT
         (SELECT count(*)::text FROM public.app_users) AS app_users,
         (SELECT count(*)::text FROM public.memberships) AS memberships`,
    );
    expect(domainCountsBeforeSeed.rows[0]).toEqual({
      app_users: "0",
      memberships: "0",
    });

    const claims = {
      iss: SELF_HOSTED_AUTH_ISSUER,
      sub: bootstrap.subject,
    };

    const visibleBeforeSeed = await readWithClaims<{ id: string }>(
      domainPool,
      "SELECT id::text FROM public.contractings ORDER BY id",
      [],
      claims,
    );
    expect(visibleBeforeSeed).toEqual([]);

    process.env.COMPRAS_PRIVATE_PREVIEW_PREFLIGHT_MODE =
      FICTITIOUS_PRIVATE_PREVIEW_MODE;
    await expect(
      seedFictitiousPrivatePreviewAuthorization(adminPool, bootstrap.subject),
    ).resolves.toEqual({ kind: "seeded" });
    delete process.env.COMPRAS_PRIVATE_PREVIEW_PREFLIGHT_MODE;

    const guardedAuth = betterAuth({
      database: authPool,
      baseURL: TEST_ORIGIN,
      secret: betterAuthSecret,
      trustedOrigins: [TEST_ORIGIN],
      emailAndPassword: {
        enabled: true,
        disableSignUp: true,
      },
      socialProviders: {},
      plugins: [],
    });

    await expect(
      guardedAuth.api.signUpEmail({
        body: {
          email: "blocked-f22@example.invalid",
          password: bootstrapPassword,
          name: "Blocked Fictitious Preview User",
        },
      }),
    ).rejects.toThrow(/sign.?up|signup/i);

    const signedIn = await guardedAuth.api.signInEmail({
      body: {
        email: FICTITIOUS_PRIVATE_PREVIEW_FIXTURE.email,
        password: bootstrapPassword,
      },
      returnHeaders: true,
    });
    expect(signedIn.response.user.id).toBe(bootstrap.subject);

    const cookie = cookieHeaderFromSetCookie(signedIn.headers);
    expect(cookie).toContain("session_token");
    await expect(
      guardedAuth.api.getSession({ headers: new Headers({ cookie }) }),
    ).resolves.toMatchObject({ user: { id: bootstrap.subject } });

    const visibleContractings = await readWithClaims<{
      id: string;
      team_id: string;
    }>(
      domainPool,
      "SELECT id::text, team_id::text FROM public.contractings ORDER BY id",
      [],
      claims,
    );
    expect(visibleContractings).toEqual([
      {
        id: FICTITIOUS_PRIVATE_PREVIEW_FIXTURE.contractingAlphaId,
        team_id: FICTITIOUS_PRIVATE_PREVIEW_FIXTURE.teamAlphaId,
      },
    ]);

    const knownCrossTeamId = await readWithClaims<{ id: string }>(
      domainPool,
      "SELECT id::text FROM public.contractings WHERE id = $1::uuid",
      [FICTITIOUS_PRIVATE_PREVIEW_FIXTURE.contractingBetaId],
      claims,
    );
    expect(knownCrossTeamId).toEqual([]);

    await expect(
      readWithClaims<{ id: string }>(
        domainPool,
        "SELECT id::text FROM public.contractings ORDER BY id",
      ),
    ).resolves.toEqual([]);

    await expect(
      readWithClaims<{ id: string }>(
        domainPool,
        "SELECT id::text FROM public.contractings ORDER BY id",
        [],
        { iss: "urn:fictitious:wrong-issuer", sub: bootstrap.subject },
      ),
    ).resolves.toEqual([]);

    await expect(
      readWithClaims<{ id: string }>(
        domainPool,
        "SELECT id::text FROM public.contractings ORDER BY id",
        [],
        { iss: SELF_HOSTED_AUTH_ISSUER, sub: "wrong-fictitious-subject" },
      ),
    ).resolves.toEqual([]);

    await expect(
      readWithClaims<{ id: string }>(
        domainPool,
        "SELECT id::text FROM public.contractings ORDER BY id",
        [],
        "not-json",
      ),
    ).resolves.toEqual([]);

    const runtimeRoles = await adminPool.query<{
      rolname: string;
      rolsuper: boolean;
      rolbypassrls: boolean;
      rolcreatedb: boolean;
      rolcreaterole: boolean;
      rolinherit: boolean;
    }>(
      `SELECT rolname, rolsuper, rolbypassrls, rolcreatedb, rolcreaterole, rolinherit
         FROM pg_catalog.pg_roles
        WHERE rolname = ANY($1::text[])
        ORDER BY rolname`,
      [["compras_auth_runtime", "compras_domain_runtime_f22"]],
    );

    expect(runtimeRoles.rows).toHaveLength(2);
    for (const role of runtimeRoles.rows) {
      expect(role).toMatchObject({
        rolsuper: false,
        rolbypassrls: false,
        rolcreatedb: false,
        rolcreaterole: false,
        rolinherit: false,
      });
    }

    const runtimeOwnership = await adminPool.query<{
      rolname: string;
      owned_relations: string;
    }>(
      `SELECT r.rolname,
              count(c.oid)::text AS owned_relations
         FROM pg_catalog.pg_roles AS r
         LEFT JOIN pg_catalog.pg_class AS c ON c.relowner = r.oid
         LEFT JOIN pg_catalog.pg_namespace AS n
           ON n.oid = c.relnamespace AND n.nspname IN ('public', 'auth')
        WHERE r.rolname = ANY($1::text[])
        GROUP BY r.rolname
        ORDER BY r.rolname`,
      [["compras_auth_runtime", "compras_domain_runtime_f22"]],
    );
    expect(runtimeOwnership.rows).toEqual([
      { rolname: "compras_auth_runtime", owned_relations: "0" },
      { rolname: "compras_domain_runtime_f22", owned_relations: "0" },
    ]);

    await expect(
      authPool.query("SELECT id FROM public.teams LIMIT 1"),
    ).rejects.toMatchObject({ code: "42501" });
    await expect(
      domainPool.query('SELECT id FROM auth."user" LIMIT 1'),
    ).rejects.toMatchObject({ code: "42501" });

    const finalCounts = await adminPool.query<{
      auth_users: string;
      app_users: string;
      memberships: string;
      teams: string;
      contractings: string;
    }>(
      `SELECT
         (SELECT count(*)::text FROM auth."user") AS auth_users,
         (SELECT count(*)::text FROM public.app_users) AS app_users,
         (SELECT count(*)::text FROM public.memberships) AS memberships,
         (SELECT count(*)::text FROM public.teams) AS teams,
         (SELECT count(*)::text FROM public.contractings) AS contractings`,
    );
    expect(finalCounts.rows[0]).toEqual({
      auth_users: "1",
      app_users: "1",
      memberships: "1",
      teams: "2",
      contractings: "2",
    });

    const signedOut = await guardedAuth.api.signOut({
      headers: new Headers({ cookie }),
      returnHeaders: true,
    });
    expect(signedOut.headers.getSetCookie().join("\n").toLowerCase()).toMatch(
      /session_token=.*(max-age=0|expires=)/,
    );
    await expect(
      guardedAuth.api.getSession({ headers: new Headers({ cookie }) }),
    ).resolves.toBeNull();
  });
});
