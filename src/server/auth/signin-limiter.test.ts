import { describe, expect, it, vi } from "vitest";

vi.mock("server-only", () => ({}));

import {
  deriveSignInLimiterDigests,
  normalizeSignInLimiterIdentifier,
  resolveTrustedVercelSource,
} from "./signin-limiter";

const TEST_SECRET = "f24-fictitious-limiter-secret-not-operational-0000000001";

describe("private sign-in limiter core", () => {
  it("normalizes only the defensive identifier bucket input", () => {
    expect(normalizeSignInLimiterIdentifier("  Existing@Example.Invalid  ")).toBe(
      "existing@example.invalid",
    );
    expect(normalizeSignInLimiterIdentifier("   ")).toBeNull();
    expect(normalizeSignInLimiterIdentifier("x".repeat(321))).toBeNull();
  });

  it("accepts only a strict Vercel-hosted x-forwarded-for IPv4 or IPv6 value", () => {
    const hosted = { VERCEL: "1", VERCEL_ENV: "preview" } as const;

    expect(
      resolveTrustedVercelSource(
        new Headers({ "x-forwarded-for": "203.0.113.25" }),
        hosted,
      ),
    ).toBe("203.0.113.25");
    expect(
      resolveTrustedVercelSource(
        new Headers({ "x-forwarded-for": "2001:0DB8:0:0:0:0:0:25" }),
        hosted,
      ),
    ).toBe("2001:db8::25");
  });

  it("fails closed for forwarded chains, invalid sources, alternate headers, or non-hosted runtime", () => {
    const hosted = { VERCEL: "1", VERCEL_ENV: "production" } as const;

    expect(
      resolveTrustedVercelSource(
        new Headers({ "x-forwarded-for": "203.0.113.1, 198.51.100.2" }),
        hosted,
      ),
    ).toBeNull();
    expect(
      resolveTrustedVercelSource(
        new Headers({ "x-forwarded-for": "client.example.invalid" }),
        hosted,
      ),
    ).toBeNull();
    expect(
      resolveTrustedVercelSource(
        new Headers({ "x-forwarded-for": "203.0.113.1 198.51.100.2" }),
        hosted,
      ),
    ).toBeNull();
    expect(
      resolveTrustedVercelSource(
        new Headers({ "true-client-ip": "203.0.113.1" }),
        hosted,
      ),
    ).toBeNull();
    expect(
      resolveTrustedVercelSource(
        new Headers({ "x-forwarded-for": "203.0.113.1" }),
        { VERCEL: "0", VERCEL_ENV: "preview" },
      ),
    ).toBeNull();
    expect(
      resolveTrustedVercelSource(
        new Headers({ "x-forwarded-for": "203.0.113.1" }),
        { VERCEL: "1", VERCEL_ENV: "development" },
      ),
    ).toBeNull();
  });

  it("derives deterministic domain-separated opaque digests without returning raw inputs", () => {
    const first = deriveSignInLimiterDigests({
      source: "203.0.113.45",
      email: " Existing@Example.Invalid ",
      secret: TEST_SECRET,
    });
    const second = deriveSignInLimiterDigests({
      source: "203.0.113.45",
      email: "existing@example.invalid",
      secret: TEST_SECRET,
    });

    expect(first).not.toBeNull();
    expect(first).toEqual(second);
    if (!first) return;

    expect(first.source).toMatch(/^[0-9a-f]{64}$/);
    expect(first.identifier).toMatch(/^[0-9a-f]{64}$/);
    expect(first.pair).toMatch(/^[0-9a-f]{64}$/);
    expect(new Set([first.source, first.identifier, first.pair]).size).toBe(3);

    const serialized = JSON.stringify(first);
    expect(serialized).not.toContain("203.0.113.45");
    expect(serialized).not.toContain("existing@example.invalid");
    expect(serialized).not.toContain(TEST_SECRET);
  });

  it("canonicalizes equivalent IPv6 source forms into the same defensive buckets", () => {
    const expanded = deriveSignInLimiterDigests({
      source: "2001:0DB8:0:0:0:0:0:99",
      email: "existing@example.invalid",
      secret: TEST_SECRET,
    });
    const compressed = deriveSignInLimiterDigests({
      source: "2001:db8::99",
      email: "existing@example.invalid",
      secret: TEST_SECRET,
    });

    expect(expanded).toEqual(compressed);
  });

  it("changes digests when the source or secret changes and rejects unsafe derivation input", () => {
    const baseline = deriveSignInLimiterDigests({
      source: "203.0.113.10",
      email: "existing@example.invalid",
      secret: TEST_SECRET,
    });
    const otherSource = deriveSignInLimiterDigests({
      source: "203.0.113.11",
      email: "existing@example.invalid",
      secret: TEST_SECRET,
    });
    const otherSecret = deriveSignInLimiterDigests({
      source: "203.0.113.10",
      email: "existing@example.invalid",
      secret: `${TEST_SECRET}-rotated`,
    });

    expect(baseline).not.toEqual(otherSource);
    expect(baseline).not.toEqual(otherSecret);
    expect(
      deriveSignInLimiterDigests({
        source: "not-an-ip",
        email: "existing@example.invalid",
        secret: TEST_SECRET,
      }),
    ).toBeNull();
    expect(
      deriveSignInLimiterDigests({
        source: "203.0.113.10",
        email: "existing@example.invalid",
        secret: "too-short",
      }),
    ).toBeNull();
  });
});
