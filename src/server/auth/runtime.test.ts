import { beforeEach, describe, expect, it, vi } from "vitest";

const mocks = vi.hoisted(() => {
  const pool = {
    on: vi.fn(),
    end: vi.fn().mockResolvedValue(undefined),
  };
  const api = {
    getSession: vi.fn(),
  };

  return {
    pool,
    api,
    betterAuth: vi.fn(() => ({ api })),
    Pool: vi.fn(function Pool() {
      return pool;
    }),
    headers: vi.fn(),
  };
});

vi.mock("server-only", () => ({}));
vi.mock("better-auth", () => ({ betterAuth: mocks.betterAuth }));
vi.mock("pg", () => ({ Pool: mocks.Pool }));
vi.mock("next/headers", () => ({ headers: mocks.headers }));

import {
  getConfiguredPrivateAuth,
  isAuthProviderUnavailableError,
  readPrivateAuthSessionState,
} from "./runtime";

let sequence = 0;

function configureRuntime() {
  sequence += 1;
  process.env.AUTH_DATABASE_URL =
    `postgresql://auth:fictitious@db.example.invalid/compras?run=${sequence}`;
  process.env.DATABASE_URL =
    `postgresql://domain:fictitious@db.example.invalid/compras?run=${sequence}`;
  process.env.BETTER_AUTH_SECRET =
    "f20-fictitious-runtime-test-secret-not-operational-0001";
  process.env.COMPRAS_AUTH_BASE_URL = `https://auth-${sequence}.example.invalid`;
}

describe("self-hosted private auth runtime", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    mocks.pool.end.mockResolvedValue(undefined);
    configureRuntime();
    mocks.headers.mockResolvedValue(new Headers({ cookie: "session=fictitious" }));
  });

  it("constructs Better Auth with closed admission and a dedicated auth search_path", () => {
    const configured = getConfiguredPrivateAuth();
    const baseUrl = process.env.COMPRAS_AUTH_BASE_URL;

    expect(configured?.issuer).toBe("urn:compras:better-auth:self-hosted:v1");
    expect(mocks.Pool).toHaveBeenCalledWith(
      expect.objectContaining({
        connectionString: process.env.AUTH_DATABASE_URL,
        options: "-c search_path=auth",
        application_name: "compras-auth-runtime",
      }),
    );
    expect(mocks.betterAuth).toHaveBeenCalledWith(
      expect.objectContaining({
        database: mocks.pool,
        baseURL: baseUrl,
        secret: process.env.BETTER_AUTH_SECRET,
        trustedOrigins: [baseUrl],
        emailAndPassword: { enabled: true, disableSignUp: true },
        socialProviders: {},
        plugins: [],
      }),
    );
  });

  it("returns only the stable issuer and server-validated Better Auth user id", async () => {
    mocks.api.getSession.mockResolvedValue({
      user: { id: "better-auth-subject" },
      session: { id: "session-id" },
    });

    await expect(readPrivateAuthSessionState()).resolves.toEqual({
      kind: "authenticated",
      identity: {
        issuer: "urn:compras:better-auth:self-hosted:v1",
        subject: "better-auth-subject",
      },
    });
    expect(mocks.api.getSession).toHaveBeenCalledWith({
      headers: expect.any(Headers),
    });
  });

  it("distinguishes no session from malformed/provider-unavailable state", async () => {
    mocks.api.getSession.mockResolvedValueOnce(null);
    await expect(readPrivateAuthSessionState()).resolves.toEqual({
      kind: "unauthenticated",
    });

    configureRuntime();
    mocks.api.getSession.mockResolvedValueOnce({ user: { id: "missing-session" } });
    await expect(readPrivateAuthSessionState()).resolves.toEqual({
      kind: "unavailable",
    });

    configureRuntime();
    mocks.api.getSession.mockRejectedValueOnce({ statusCode: 401 });
    await expect(readPrivateAuthSessionState()).resolves.toEqual({
      kind: "unauthenticated",
    });

    configureRuntime();
    mocks.api.getSession.mockRejectedValueOnce(new Error("fictitious db failure"));
    await expect(readPrivateAuthSessionState()).resolves.toEqual({
      kind: "unavailable",
    });
  });

  it("treats only client/API rejections as non-provider failures", () => {
    expect(isAuthProviderUnavailableError({ statusCode: 401 })).toBe(false);
    expect(isAuthProviderUnavailableError({ status: "FORBIDDEN" })).toBe(false);
    expect(isAuthProviderUnavailableError({ statusCode: 429 })).toBe(false);
    expect(isAuthProviderUnavailableError({ statusCode: 503 })).toBe(true);
    expect(isAuthProviderUnavailableError(new Error("network"))).toBe(true);
  });
});
