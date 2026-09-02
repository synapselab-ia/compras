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
  TrustedDatabaseContextError,
  withTrustedDatabaseContext,
} from "./trusted-context";

const SAFE_ROLE = {
  rolname: "compras_app",
  rolsuper: false,
  rolbypassrls: false,
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

describe("withTrustedDatabaseContext", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    databaseMocks.Pool.mockReset();
    process.env.DATABASE_URL = "postgresql://db.demo.invalid/compras";
    identityMocks.getVerifiedExternalIdentity.mockResolvedValue({
      issuer: "https://auth.demo.invalid/neondb/auth",
      subject: "DEMO-SUBJECT",
    });
  });

  afterEach(() => {
    delete process.env.DATABASE_URL;
  });

  it("fails closed before opening a database connection when identity is absent", async () => {
    identityMocks.getVerifiedExternalIdentity.mockResolvedValue(null);

    await expect(
      withTrustedDatabaseContext(async () => "unreachable"),
    ).rejects.toBeInstanceOf(TrustedDatabaseContextError);

    expect(databaseMocks.Pool).not.toHaveBeenCalled();
  });

  it("fails closed before opening a database connection when server database configuration is invalid", async () => {
    process.env.DATABASE_URL = " https://not-postgres.demo.invalid";

    await expect(
      withTrustedDatabaseContext(async () => "unreachable"),
    ).rejects.toBeInstanceOf(TrustedDatabaseContextError);

    expect(databaseMocks.Pool).not.toHaveBeenCalled();
  });

  it("wraps driver construction failures without serializing driver details", async () => {
    databaseMocks.Pool.mockImplementationOnce(function MockPoolFailure() {
      throw new Error("driver detail that must not escape");
    });

    await expect(
      withTrustedDatabaseContext(async () => "unreachable"),
    ).rejects.toEqual(
      expect.objectContaining({
        name: "TrustedDatabaseContextError",
        message: "Trusted database context is unavailable.",
      }),
    );
  });

  it("sets only iss and sub with a parameterized LOCAL context before the protected operation", async () => {
    const { client, pool, query } = createDatabaseDouble();
    const operation = vi.fn(async (db) => {
      await db.query("SELECT 42 AS answer");
      return 42;
    });

    await expect(withTrustedDatabaseContext(operation)).resolves.toBe(42);

    const setContextCallIndex = query.mock.calls.findIndex(
      ([text]) => text === "SELECT set_config('request.jwt.claims', $1, true)",
    );
    const operationCallIndex = query.mock.calls.findIndex(
      ([text]) => text === "SELECT 42 AS answer",
    );

    expect(setContextCallIndex).toBeGreaterThan(-1);
    expect(operationCallIndex).toBeGreaterThan(setContextCallIndex);
    expect(query.mock.calls[setContextCallIndex]?.[1]).toEqual([
      JSON.stringify({
        iss: "https://auth.demo.invalid/neondb/auth",
        sub: "DEMO-SUBJECT",
      }),
    ]);
    expect(
      query.mock.calls.some(
        ([text]) => text.includes("set_config") && text.includes("false"),
      ),
    ).toBe(false);
    expect(query.mock.calls.some(([text]) => text === "BEGIN READ ONLY")).toBe(true);
    expect(query.mock.calls.some(([text]) => text === "COMMIT")).toBe(true);
    expect(client.release).toHaveBeenCalledWith(true);
    expect(pool.end).toHaveBeenCalledOnce();
  });

  it("rejects a superuser, BYPASSRLS role, protected-table owner, or neondb_owner before setting claims", async () => {
    for (const unsafeRole of [
      { ...SAFE_ROLE, rolsuper: true },
      { ...SAFE_ROLE, rolbypassrls: true },
      { ...SAFE_ROLE, owns_protected_tables: true },
      { ...SAFE_ROLE, rolname: "neondb_owner" },
    ]) {
      databaseMocks.Pool.mockReset();
      identityMocks.getVerifiedExternalIdentity.mockClear();
      identityMocks.getVerifiedExternalIdentity.mockResolvedValue({
        issuer: "https://auth.demo.invalid/neondb/auth",
        subject: "DEMO-SUBJECT",
      });
      const { query } = createDatabaseDouble(unsafeRole);
      const operation = vi.fn(async () => "unreachable");

      await expect(withTrustedDatabaseContext(operation)).rejects.toBeInstanceOf(
        TrustedDatabaseContextError,
      );

      expect(operation).not.toHaveBeenCalled();
      expect(
        query.mock.calls.some(
          ([text]) => text === "SELECT set_config('request.jwt.claims', $1, true)",
        ),
      ).toBe(false);
    }
  });

  it("rolls back and never runs the protected operation when context establishment fails", async () => {
    const { query } = createDatabaseDouble();
    query.mockImplementation(
      async (...args: [text: string, values?: unknown[]]) => {
        const [text] = args;

        if (text.includes("FROM pg_catalog.pg_roles AS r")) {
          return { rows: [SAFE_ROLE] };
        }
        if (text === "SELECT set_config('request.jwt.claims', $1, true)") {
          throw new Error("context failed");
        }
        return { rows: [] };
      },
    );
    const operation = vi.fn(async () => "unreachable");

    await expect(withTrustedDatabaseContext(operation)).rejects.toBeInstanceOf(
      TrustedDatabaseContextError,
    );

    expect(operation).not.toHaveBeenCalled();
    expect(query.mock.calls.some(([text]) => text === "ROLLBACK")).toBe(true);
  });

  it("closes each pool so transaction-local identity cannot survive into a later operation", async () => {
    const first = createDatabaseDouble();
    await withTrustedDatabaseContext(async () => "first");

    const second = createDatabaseDouble();
    identityMocks.getVerifiedExternalIdentity.mockResolvedValue({
      issuer: "https://auth.demo.invalid/neondb/auth",
      subject: "DEMO-SUBJECT-2",
    });
    await withTrustedDatabaseContext(async () => "second");

    expect(first.pool.end).toHaveBeenCalledOnce();
    expect(first.client.release).toHaveBeenCalledWith(true);
    expect(second.pool.end).toHaveBeenCalledOnce();
    expect(
      second.query.mock.calls.find(([text]) => text.includes("set_config"))?.[1],
    ).toEqual([
      JSON.stringify({
        iss: "https://auth.demo.invalid/neondb/auth",
        sub: "DEMO-SUBJECT-2",
      }),
    ]);
  });
});
