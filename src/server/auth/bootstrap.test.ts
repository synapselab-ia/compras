import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

const mocks = vi.hoisted(() => {
  const pool = {
    on: vi.fn(),
    end: vi.fn().mockResolvedValue(undefined),
  };
  const signUpEmail = vi.fn();

  return {
    pool,
    signUpEmail,
    betterAuth: vi.fn(() => ({ api: { signUpEmail } })),
    Pool: vi.fn(function Pool() {
      return pool;
    }),
  };
});

vi.mock("server-only", () => ({}));
vi.mock("better-auth", () => ({ betterAuth: mocks.betterAuth }));
vi.mock("pg", () => ({ Pool: mocks.Pool }));

import { bootstrapFictitiousIdentity } from "./bootstrap";

const ENV_KEYS = [
  "AUTH_DATABASE_URL",
  "DATABASE_URL",
  "BETTER_AUTH_SECRET",
  "COMPRAS_AUTH_BASE_URL",
  "COMPRAS_AUTH_BOOTSTRAP_MODE",
] as const;

function configure() {
  process.env.AUTH_DATABASE_URL =
    "postgresql://auth:fictitious@db.example.invalid/compras";
  process.env.DATABASE_URL =
    "postgresql://domain:fictitious@db.example.invalid/compras";
  process.env.BETTER_AUTH_SECRET =
    "f20-fictitious-bootstrap-test-secret-not-operational-0001";
  process.env.COMPRAS_AUTH_BASE_URL = "https://bootstrap.example.invalid";
}

describe("fictitious one-shot auth bootstrap", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    mocks.pool.end.mockResolvedValue(undefined);
    configure();
  });

  afterEach(() => {
    for (const key of ENV_KEYS) delete process.env[key];
  });

  it("is disabled unless the explicit one-shot gate is present", async () => {
    await expect(
      bootstrapFictitiousIdentity({
        email: "existing@example.invalid",
        password: "fictitious-password",
        name: "Fictitious User",
      }),
    ).resolves.toEqual({ kind: "disabled" });
    expect(mocks.Pool).not.toHaveBeenCalled();
  });

  it("rejects any bootstrap identity outside example.invalid before touching the database", async () => {
    process.env.COMPRAS_AUTH_BOOTSTRAP_MODE = "FICTITIOUS_ONE_SHOT";

    await expect(
      bootstrapFictitiousIdentity({
        email: "someone@real.example.com",
        password: "fictitious-password",
        name: "Rejected User",
      }),
    ).resolves.toEqual({ kind: "rejected" });
    expect(mocks.Pool).not.toHaveBeenCalled();
  });

  it("temporarily opens only Better Auth signup and returns only its subject", async () => {
    process.env.COMPRAS_AUTH_BOOTSTRAP_MODE = "FICTITIOUS_ONE_SHOT";
    mocks.signUpEmail.mockResolvedValue({
      user: { id: "better-auth-subject", email: "existing@example.invalid" },
    });

    await expect(
      bootstrapFictitiousIdentity({
        email: "EXISTING@example.invalid",
        password: "fictitious-password",
        name: " Fictitious User ",
      }),
    ).resolves.toEqual({
      kind: "created",
      subject: "better-auth-subject",
    });

    expect(mocks.Pool).toHaveBeenCalledWith(
      expect.objectContaining({
        connectionString: process.env.AUTH_DATABASE_URL,
        options: "-c search_path=auth",
        max: 1,
      }),
    );
    expect(mocks.betterAuth).toHaveBeenCalledWith(
      expect.objectContaining({
        emailAndPassword: { enabled: true, disableSignUp: false },
        socialProviders: {},
        plugins: [],
      }),
    );
    expect(mocks.signUpEmail).toHaveBeenCalledWith({
      body: {
        email: "existing@example.invalid",
        password: "fictitious-password",
        name: "Fictitious User",
      },
    });
  });
});
