import { beforeEach, describe, expect, it, vi } from "vitest";

const runtimeMocks = vi.hoisted(() => ({
  readPrivateAuthSessionState: vi.fn(),
}));

vi.mock("server-only", () => ({}));
vi.mock("./runtime", () => ({
  readPrivateAuthSessionState: runtimeMocks.readPrivateAuthSessionState,
}));

import { getVerifiedExternalIdentity } from "./external-identity";

describe("getVerifiedExternalIdentity", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it("returns only issuer and subject from an authenticated server-side session", async () => {
    runtimeMocks.readPrivateAuthSessionState.mockResolvedValue({
      kind: "authenticated",
      identity: {
        issuer: "https://auth.demo.invalid/neondb/auth",
        subject: "DEMO-SUBJECT",
      },
    });

    await expect(getVerifiedExternalIdentity()).resolves.toEqual({
      issuer: "https://auth.demo.invalid/neondb/auth",
      subject: "DEMO-SUBJECT",
    });
  });

  it("fails closed for unauthenticated and unavailable states", async () => {
    runtimeMocks.readPrivateAuthSessionState.mockResolvedValueOnce({ kind: "unauthenticated" });
    await expect(getVerifiedExternalIdentity()).resolves.toBeNull();

    runtimeMocks.readPrivateAuthSessionState.mockResolvedValueOnce({ kind: "unavailable" });
    await expect(getVerifiedExternalIdentity()).resolves.toBeNull();
  });

  it("ignores browser-shaped identity and scope arguments because the production API accepts none", async () => {
    runtimeMocks.readPrivateAuthSessionState.mockResolvedValue({
      kind: "authenticated",
      identity: {
        issuer: "https://auth.demo.invalid/neondb/auth",
        subject: "DEMO-SUBJECT",
      },
    });

    const callWithUntrustedExtras = getVerifiedExternalIdentity as unknown as (
      extras: unknown,
    ) => ReturnType<typeof getVerifiedExternalIdentity>;

    const result = await callWithUntrustedExtras({
      headers: { host: "attacker.invalid", subject: "FORGED" },
      query: { issuer: "https://attacker.invalid", team_id: "FORGED" },
      body: {
        email: "known@example.invalid",
        app_user_id: "FORGED",
        membership_id: "FORGED",
      },
    });

    expect(result).toEqual({
      issuer: "https://auth.demo.invalid/neondb/auth",
      subject: "DEMO-SUBJECT",
    });
  });
});
