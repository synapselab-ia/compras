import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

const identityMocks = vi.hoisted(() => ({
  getVerifiedExternalIdentity: vi.fn(),
}));

const databaseMocks = vi.hoisted(() => ({
  Pool: vi.fn(),
}));

vi.mock("server-only", () => ({}));
vi.mock("@/server/auth/external-identity", () => ({
  getVerifiedExternalIdentity: identityMocks.getVerifiedExternalIdentity,
}));
vi.mock("@neondatabase/serverless", () => ({
  Pool: databaseMocks.Pool,
}));

import {
  TrustedDatabaseMutationContextError,
  withTrustedDatabaseMutationContext,
} from "./trusted-mutation-context";

const SAFE_ROLE = {
  rolname: "compras_domain_runtime_f26",
  rolsuper: false,
  rolbypassrls: false,
  rolcreatedb: false,
  rolcreaterole: false,
  rolreplication: false,
  owns_protected_tables: false,
};

function createDatabaseDouble(role = SAFE_ROLE) {
  const query = vi.fn(
    async (...args: [text: string, values?: unknown[]]) => {
      const [text] = args;

      if (text.includes("FROM pg_catalog.pg_roles AS r")) {
        return { rows: [role] };
      }

      return { rows: [] };
    },
  );
  const client = {
    query,
    release: vi.fn(),
  };
  const pool = {
    connect: vi.fn().mockResolvedValue(client),
    end: vi.fn().mockResolvedValue(undefined),
  };

  databaseMocks.Pool.mockImplementation(function MockPool() {
    return pool;
  });

  return { client, pool, query };
}

describe("withTrustedDatabaseMutationContext", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    databaseMocks.Pool.mockReset();
    process.env.DATABASE_URL = "postgresql://db.demo.invalid/compras";
    identityMocks.getVerifiedExternalIdentity.mockResolvedValue({
      issuer: "urn:compras:better-auth:self-hosted:v1",
      subject: "DEMO-F26-SUBJECT",
    });
  });

  afterEach(() => {
    delete process.env.DATABASE_URL;
  });

  it("fails before opening a database connection when verified identity is absent", async () => {
    identityMocks.getVerifiedExternalIdentity.mockResolvedValue(null);

    await expect(
      withTrustedDatabaseMutationContext(async () => "unreachable"),
    ).rejects.toBeInstanceOf(TrustedDatabaseMutationContextError);

    expect(databaseMocks.Pool).not.toHaveBeenCalled();
  });

  it("fails before opening a database connection when DATABASE_URL is invalid", async () => {
    process.env.DATABASE_URL = " https://not-postgres.demo.invalid";

    await expect(
      withTrustedDatabaseMutationContext(async () => "unreachable"),
    ).rejects.toBeInstanceOf(TrustedDatabaseMutationContextError);

    expect(databaseMocks.Pool).not.toHaveBeenCalled();
  });

  it("uses a normal transaction and installs only LOCAL iss/sub before mutation", async () => {
    const { client, pool, query } = createDatabaseDouble();
    const operation = vi.fn(async (db) => {
      await db.query("SELECT public.mutate_contracting_next_action($1, $2, $3, $4)", [
        "00000000-0000-4000-8000-000000002601",
        "DEMO old",
        "DEMO new",
        "00000000-0000-4000-8000-000000002699",
      ]);
      return "updated";
    });

    await expect(withTrustedDatabaseMutationContext(operation)).resolves.toBe("updated");

    expect(query.mock.calls.some(([text]) => text === "BEGIN")).toBe(true);
    expect(query.mock.calls.some(([text]) => text === "BEGIN READ ONLY")).toBe(false);

    const setContextCallIndex = query.mock.calls.findIndex(
      ([text]) => text === "SELECT set_config('request.jwt.claims', $1, true)",
    );
    const operationCallIndex = query.mock.calls.findIndex(
      ([text]) => text.includes("mutate_contracting_next_action"),
    );

    expect(setContextCallIndex).toBeGreaterThan(-1);
    expect(operationCallIndex).toBeGreaterThan(setContextCallIndex);
    expect(query.mock.calls[setContextCallIndex]?.[1]).toEqual([
      JSON.stringify({
        iss: "urn:compras:better-auth:self-hosted:v1",
        sub: "DEMO-F26-SUBJECT",
      }),
    ]);
    expect(
      query.mock.calls.some(
        ([text]) => text.includes("set_config") && text.includes("false"),
      ),
    ).toBe(false);
    expect(query.mock.calls.some(([text]) => text === "COMMIT")).toBe(true);
    expect(client.release).toHaveBeenCalledWith(true);
    expect(pool.end).toHaveBeenCalledOnce();
  });

  it("rejects administrative and capability principals before installing claims", async () => {
    for (const unsafeRole of [
      { ...SAFE_ROLE, rolsuper: true },
      { ...SAFE_ROLE, rolbypassrls: true },
      { ...SAFE_ROLE, rolcreatedb: true },
      { ...SAFE_ROLE, rolcreaterole: true },
      { ...SAFE_ROLE, rolreplication: true },
      { ...SAFE_ROLE, owns_protected_tables: true },
      { ...SAFE_ROLE, rolname: "neondb_owner" },
      { ...SAFE_ROLE, rolname: "compras_team_directory_view_owner" },
      { ...SAFE_ROLE, rolname: "compras_next_action_mutation_owner" },
    ]) {
      databaseMocks.Pool.mockReset();
      identityMocks.getVerifiedExternalIdentity.mockClear();
      identityMocks.getVerifiedExternalIdentity.mockResolvedValue({
        issuer: "urn:compras:better-auth:self-hosted:v1",
        subject: "DEMO-F26-SUBJECT",
      });
      const { query } = createDatabaseDouble(unsafeRole);
      const operation = vi.fn(async () => "unreachable");

      await expect(
        withTrustedDatabaseMutationContext(operation),
      ).rejects.toBeInstanceOf(TrustedDatabaseMutationContextError);

      expect(operation).not.toHaveBeenCalled();
      expect(
        query.mock.calls.some(
          ([text]) => text === "SELECT set_config('request.jwt.claims', $1, true)",
        ),
      ).toBe(false);
    }
  });

  it("rolls back a failed mutation and sanitizes driver details", async () => {
    const { query } = createDatabaseDouble();
    query.mockImplementation(
      async (...args: [text: string, values?: unknown[]]) => {
        const [text] = args;

        if (text.includes("FROM pg_catalog.pg_roles AS r")) {
          return { rows: [SAFE_ROLE] };
        }
        if (text === "SELECT MUTATION") {
          throw new Error("postgresql://must-not-escape.example.invalid/private");
        }
        return { rows: [] };
      },
    );

    await expect(
      withTrustedDatabaseMutationContext(async (db) => {
        await db.query("SELECT MUTATION");
      }),
    ).rejects.toEqual(
      expect.objectContaining({
        name: "TrustedDatabaseMutationContextError",
        message: "Trusted database mutation context is unavailable.",
      }),
    );

    expect(query.mock.calls.some(([text]) => text === "ROLLBACK")).toBe(true);
  });
});
