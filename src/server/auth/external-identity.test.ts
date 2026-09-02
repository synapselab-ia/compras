import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

const authMocks = vi.hoisted(() => ({
  createNeonAuth: vi.fn(),
  getSession: vi.fn(),
}));

vi.mock("server-only", () => ({}));
vi.mock("@neondatabase/auth/next/server", () => ({
  createNeonAuth: authMocks.createNeonAuth,
}));

import { getVerifiedExternalIdentity } from "./external-identity";

const VALID_BASE_URL = "https://auth.demo.invalid/neondb/auth";
const VALID_SECRET = "demo-cookie-secret-with-at-least-32-characters";

function setValidConfiguration() {
  process.env.NEON_AUTH_BASE_URL = VALID_BASE_URL;
  process.env.NEON_AUTH_COOKIE_SECRET = VALID_SECRET;
}

describe("getVerifiedExternalIdentity", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    setValidConfiguration();
    authMocks.createNeonAuth.mockReturnValue({
      getSession: authMocks.getSession,
    });
  });

  afterEach(() => {
    delete process.env.NEON_AUTH_BASE_URL;
    delete process.env.NEON_AUTH_COOKIE_SECRET;
  });

  it("returns issuer from trusted server configuration and subject from the validated session", async () => {
    authMocks.getSession.mockResolvedValue({
      data: {
        session: { id: "DEMO-SESSION" },
        user: { id: "DEMO-SUBJECT" },
      },
      error: null,
    });

    await expect(getVerifiedExternalIdentity()).resolves.toEqual({
      issuer: VALID_BASE_URL,
      subject: "DEMO-SUBJECT",
    });

    expect(authMocks.createNeonAuth).toHaveBeenCalledWith({
      baseUrl: VALID_BASE_URL,
      cookies: { secret: VALID_SECRET },
      logLevel: "silent",
    });
  });

  it("fails closed when there is no validated session", async () => {
    authMocks.getSession.mockResolvedValue({ data: null, error: null });

    await expect(getVerifiedExternalIdentity()).resolves.toBeNull();
  });

  it("fails closed when the SDK reports or throws a session error", async () => {
    authMocks.getSession.mockResolvedValueOnce({
      data: null,
      error: { message: "session unavailable" },
    });

    await expect(getVerifiedExternalIdentity()).resolves.toBeNull();

    authMocks.getSession.mockRejectedValueOnce(new Error("transport unavailable"));

    await expect(getVerifiedExternalIdentity()).resolves.toBeNull();
  });

  it("fails closed when the validated session does not contain a subject", async () => {
    authMocks.getSession.mockResolvedValue({
      data: { session: { id: "DEMO-SESSION" }, user: {} },
      error: null,
    });

    await expect(getVerifiedExternalIdentity()).resolves.toBeNull();
  });

  it("fails closed for missing, malformed, insecure, or padded server configuration", async () => {
    authMocks.getSession.mockResolvedValue({
      data: { session: {}, user: { id: "DEMO-SUBJECT" } },
      error: null,
    });

    delete process.env.NEON_AUTH_BASE_URL;
    await expect(getVerifiedExternalIdentity()).resolves.toBeNull();

    setValidConfiguration();
    process.env.NEON_AUTH_BASE_URL = "http://auth.demo.invalid/neondb/auth";
    await expect(getVerifiedExternalIdentity()).resolves.toBeNull();

    setValidConfiguration();
    process.env.NEON_AUTH_BASE_URL = ` ${VALID_BASE_URL}`;
    await expect(getVerifiedExternalIdentity()).resolves.toBeNull();

    setValidConfiguration();
    process.env.NEON_AUTH_COOKIE_SECRET = "too-short";
    await expect(getVerifiedExternalIdentity()).resolves.toBeNull();

    expect(authMocks.getSession).not.toHaveBeenCalled();
  });

  it("ignores browser-shaped identity and scope arguments because the production API accepts none", async () => {
    authMocks.getSession.mockResolvedValue({
      data: {
        session: { id: "DEMO-SESSION" },
        user: { id: "DEMO-SUBJECT" },
      },
      error: null,
    });

    const callWithUntrustedExtras = getVerifiedExternalIdentity as unknown as (
      extras: unknown,
    ) => ReturnType<typeof getVerifiedExternalIdentity>;

    const result = await callWithUntrustedExtras({
      headers: { host: "attacker.invalid" },
      query: { subject: "FORGED", team_id: "FORGED" },
      body: { app_user_id: "FORGED", membership_id: "FORGED" },
    });

    expect(result).toEqual({
      issuer: VALID_BASE_URL,
      subject: "DEMO-SUBJECT",
    });
  });
});
