import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

vi.mock("server-only", () => ({}));

import {
  SELF_HOSTED_AUTH_ISSUER,
  readSelfHostedAuthConfiguration,
} from "./configuration";

const AUTH_KEYS = [
  "AUTH_DATABASE_URL",
  "BETTER_AUTH_SECRET",
  "COMPRAS_AUTH_BASE_URL",
  "DATABASE_URL",
] as const;

function configureValidEnvironment() {
  process.env.AUTH_DATABASE_URL =
    "postgresql://auth_runtime:fictitious@db.example.invalid/compras";
  process.env.DATABASE_URL =
    "postgresql://domain_runtime:fictitious@db.example.invalid/compras";
  process.env.BETTER_AUTH_SECRET =
    "f20-fictitious-runtime-secret-not-operational-0000001";
  process.env.COMPRAS_AUTH_BASE_URL = "https://private-preview.example.invalid";
}

describe("self-hosted auth configuration", () => {
  beforeEach(() => {
    configureValidEnvironment();
  });

  afterEach(() => {
    for (const key of AUTH_KEYS) delete process.env[key];
  });

  it("accepts separate Postgres credentials and one strict HTTPS origin", () => {
    expect(readSelfHostedAuthConfiguration()).toEqual({
      authDatabaseUrl:
        "postgresql://auth_runtime:fictitious@db.example.invalid/compras",
      baseUrl: "https://private-preview.example.invalid",
      secret: "f20-fictitious-runtime-secret-not-operational-0000001",
    });
    expect(SELF_HOSTED_AUTH_ISSUER).toBe(
      "urn:compras:better-auth:self-hosted:v1",
    );
  });

  it.each([
    "http://private-preview.example.invalid",
    "https://localhost",
    "https://127.0.0.1",
    "https://*.example.invalid",
    "https://private-preview.example.invalid/path",
    "https://private-preview.example.invalid?x=1",
    "https://private-preview.example.invalid/",
  ])("rejects non-exact trusted origin %s", (baseUrl) => {
    process.env.COMPRAS_AUTH_BASE_URL = baseUrl;
    expect(readSelfHostedAuthConfiguration()).toBeNull();
  });

  it("rejects missing/short secrets and non-Postgres auth databases", () => {
    process.env.BETTER_AUTH_SECRET = "too-short";
    expect(readSelfHostedAuthConfiguration()).toBeNull();

    configureValidEnvironment();
    process.env.AUTH_DATABASE_URL = "https://db.example.invalid/compras";
    expect(readSelfHostedAuthConfiguration()).toBeNull();
  });

  it("rejects reuse of the exact domain database credential", () => {
    process.env.DATABASE_URL = process.env.AUTH_DATABASE_URL;
    expect(readSelfHostedAuthConfiguration()).toBeNull();
  });
});
