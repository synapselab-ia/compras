import { betterAuth } from "better-auth";
import { Pool } from "pg";
import { afterAll, beforeAll, describe, expect, it, vi } from "vitest";

vi.mock("server-only", () => ({}));

import { bootstrapFictitiousIdentity } from "./bootstrap";

const integrationEnabled = process.env.F20_AUTH_POSTGRES_TEST === "1";
const describePostgres = integrationEnabled ? describe : describe.skip;
const TEST_ORIGIN = "https://f20-postgres-proof.example.invalid";
const TEST_SECRET = "f20-fictitious-postgres-proof-secret-not-operational-0001";
const TEST_EMAIL = "existing-f20-proof@example.invalid";
const TEST_PASSWORD = "fictitious-postgres-proof-password-0001";

function cookieHeaderFromSetCookie(responseHeaders: Headers): string {
  return responseHeaders
    .getSetCookie()
    .map((value) => value.split(";", 1)[0])
    .filter(Boolean)
    .join("; ");
}

describePostgres("F20 Better Auth PostgreSQL boundary", () => {
  let authPool: Pool;
  let domainPool: Pool;
  let superuserPool: Pool;

  beforeAll(() => {
    const authUrl = process.env.AUTH_INTEGRATION_DATABASE_URL;
    const domainUrl = process.env.AUTH_INTEGRATION_DOMAIN_DATABASE_URL;
    const superuserUrl = process.env.AUTH_INTEGRATION_SUPERUSER_DATABASE_URL;

    if (!authUrl || !domainUrl || !superuserUrl) {
      throw new Error("F20 PostgreSQL integration URLs are required");
    }

    process.env.AUTH_DATABASE_URL = authUrl;
    process.env.DATABASE_URL = domainUrl;
    process.env.BETTER_AUTH_SECRET = TEST_SECRET;
    process.env.COMPRAS_AUTH_BASE_URL = TEST_ORIGIN;

    authPool = new Pool({
      connectionString: authUrl,
      options: "-c search_path=auth",
      max: 2,
    });
    domainPool = new Pool({ connectionString: domainUrl, max: 1 });
    superuserPool = new Pool({ connectionString: superuserUrl, max: 1 });
  });

  afterAll(async () => {
    delete process.env.COMPRAS_AUTH_BOOTSTRAP_MODE;
    delete process.env.AUTH_DATABASE_URL;
    delete process.env.DATABASE_URL;
    delete process.env.BETTER_AUTH_SECRET;
    delete process.env.COMPRAS_AUTH_BASE_URL;

    await Promise.all([
      authPool?.end(),
      domainPool?.end(),
      superuserPool?.end(),
    ]);
  });

  it("bootstraps one fictitious identity, keeps signup closed, and isolates Auth from domain authorization", async () => {
    process.env.COMPRAS_AUTH_BOOTSTRAP_MODE = "FICTITIOUS_ONE_SHOT";
    const bootstrap = await bootstrapFictitiousIdentity({
      email: TEST_EMAIL,
      password: TEST_PASSWORD,
      name: "Existing F20 Proof User",
    });
    delete process.env.COMPRAS_AUTH_BOOTSTRAP_MODE;

    expect(bootstrap.kind).toBe("created");
    if (bootstrap.kind !== "created") return;

    const guardedAuth = betterAuth({
      database: authPool,
      baseURL: TEST_ORIGIN,
      secret: TEST_SECRET,
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
          email: "blocked-f20-proof@example.invalid",
          password: TEST_PASSWORD,
          name: "Blocked F20 Proof User",
        },
      }),
    ).rejects.toThrow(/sign.?up|signup/i);

    const signedIn = await guardedAuth.api.signInEmail({
      body: { email: TEST_EMAIL, password: TEST_PASSWORD },
      returnHeaders: true,
    });
    expect(signedIn.response.user.id).toBe(bootstrap.subject);

    const cookie = cookieHeaderFromSetCookie(signedIn.headers);
    expect(cookie).toContain("session_token");

    const session = await guardedAuth.api.getSession({
      headers: new Headers({ cookie }),
    });
    expect(session?.user.id).toBe(bootstrap.subject);

    const domainCounts = await superuserPool.query<{ app_users: string; memberships: string }>(
      `select
         (select count(*)::text from public.app_users) as app_users,
         (select count(*)::text from public.memberships) as memberships`,
    );
    expect(domainCounts.rows[0]).toEqual({ app_users: "0", memberships: "0" });

    const role = await superuserPool.query<{
      rolsuper: boolean;
      rolbypassrls: boolean;
      rolcreatedb: boolean;
      rolcreaterole: boolean;
      rolinherit: boolean;
    }>(
      `select rolsuper, rolbypassrls, rolcreatedb, rolcreaterole, rolinherit
         from pg_roles where rolname = 'compras_auth_runtime'`,
    );
    expect(role.rows[0]).toEqual({
      rolsuper: false,
      rolbypassrls: false,
      rolcreatedb: false,
      rolcreaterole: false,
      rolinherit: false,
    });

    const ownedRelations = await superuserPool.query<{ count: string }>(
      `select count(*)::text
         from pg_class c
         join pg_namespace n on n.oid = c.relnamespace
         join pg_roles r on r.oid = c.relowner
        where n.nspname = 'auth' and r.rolname = 'compras_auth_runtime'`,
    );
    expect(ownedRelations.rows[0]?.count).toBe("0");

    await expect(authPool.query("select id from public.teams limit 1")).rejects.toMatchObject({
      code: "42501",
    });
    await expect(domainPool.query('select id from auth."user" limit 1')).rejects.toMatchObject({
      code: "42501",
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
