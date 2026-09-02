import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

const authMocks = vi.hoisted(() => ({
  createNeonAuth: vi.fn(),
  getSession: vi.fn(),
}));

vi.mock("server-only", () => ({}));
vi.mock("@neondatabase/auth/next/server", () => ({
  createNeonAuth: authMocks.createNeonAuth,
  NEON_AUTH_NETWORK_ERROR_CODES: [
    "NETWORK_ERROR",
    "NETWORK_DNS",
    "NETWORK_REFUSED",
    "NETWORK_TIMEOUT",
    "NETWORK_TLS",
    "NETWORK_RESET",
    "NETWORK_ABORT",
  ],
}));

import {
  getConfiguredPrivateAuth,
  isAuthProviderUnavailableError,
  readPrivateAuthSessionState,
} from "./runtime";

const VALID_BASE_URL = "https://auth.demo.invalid/neondb/auth";
const VALID_SECRET = "demo-cookie-secret-with-at-least-32-characters";

function setValidConfiguration() {
  process.env.NEON_AUTH_BASE_URL = VALID_BASE_URL;
  process.env.NEON_AUTH_COOKIE_SECRET = VALID_SECRET;
}

describe("private auth runtime", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    setValidConfiguration();
    authMocks.createNeonAuth.mockReturnValue({ getSession: authMocks.getSession });
  });

  afterEach(() => {
    delete process.env.NEON_AUTH_BASE_URL;
    delete process.env.NEON_AUTH_COOKIE_SECRET;
  });

  it("creates the server-only SDK instance only from exact trusted configuration", () => {
    expect(getConfiguredPrivateAuth()).toMatchObject({ issuer: VALID_BASE_URL });
    expect(authMocks.createNeonAuth).toHaveBeenCalledWith({
      baseUrl: VALID_BASE_URL,
      cookies: { secret: VALID_SECRET },
      logLevel: "silent",
    });

    authMocks.createNeonAuth.mockClear();
    process.env.NEON_AUTH_BASE_URL = "http://auth.demo.invalid/neondb/auth";
    expect(getConfiguredPrivateAuth()).toBeNull();

    setValidConfiguration();
    process.env.NEON_AUTH_BASE_URL = ` ${VALID_BASE_URL}`;
    expect(getConfiguredPrivateAuth()).toBeNull();

    setValidConfiguration();
    process.env.NEON_AUTH_COOKIE_SECRET = "too-short";
    expect(getConfiguredPrivateAuth()).toBeNull();
    expect(authMocks.createNeonAuth).not.toHaveBeenCalled();
  });

  it("distinguishes an authenticated session from no session", async () => {
    authMocks.getSession.mockResolvedValueOnce({
      data: {
        session: { id: "DEMO-SESSION" },
        user: { id: "DEMO-SUBJECT" },
      },
      error: null,
    });

    await expect(readPrivateAuthSessionState()).resolves.toEqual({
      kind: "authenticated",
      identity: { issuer: VALID_BASE_URL, subject: "DEMO-SUBJECT" },
    });

    authMocks.getSession.mockResolvedValueOnce({ data: null, error: null });
    await expect(readPrivateAuthSessionState()).resolves.toEqual({ kind: "unauthenticated" });

    authMocks.getSession.mockResolvedValueOnce({
      data: { session: null, user: null },
      error: null,
    });
    await expect(readPrivateAuthSessionState()).resolves.toEqual({ kind: "unauthenticated" });
  });

  it("treats expired or rejected session responses as unauthenticated", async () => {
    authMocks.getSession.mockResolvedValueOnce({
      data: null,
      error: { status: 401, code: "UNAUTHORIZED", message: "expired" },
    });
    await expect(readPrivateAuthSessionState()).resolves.toEqual({ kind: "unauthenticated" });

    authMocks.getSession.mockResolvedValueOnce({
      data: null,
      error: { status: 403, code: "FORBIDDEN", message: "rejected" },
    });
    await expect(readPrivateAuthSessionState()).resolves.toEqual({ kind: "unauthenticated" });
  });

  it("fails closed as unavailable for malformed configuration, provider failure, or malformed session data", async () => {
    delete process.env.NEON_AUTH_COOKIE_SECRET;
    await expect(readPrivateAuthSessionState()).resolves.toEqual({ kind: "unavailable" });

    setValidConfiguration();
    authMocks.getSession.mockResolvedValueOnce({
      data: null,
      error: { status: 502, code: "NETWORK_TIMEOUT", message: "private details" },
    });
    await expect(readPrivateAuthSessionState()).resolves.toEqual({ kind: "unavailable" });

    authMocks.getSession.mockRejectedValueOnce(new Error("provider transport details"));
    await expect(readPrivateAuthSessionState()).resolves.toEqual({ kind: "unavailable" });

    authMocks.getSession.mockResolvedValueOnce({
      data: { session: { id: "DEMO-SESSION" }, user: {} },
      error: null,
    });
    await expect(readPrivateAuthSessionState()).resolves.toEqual({ kind: "unavailable" });
  });

  it("classifies only provider/transport failures as unavailable for sign-in decisions", () => {
    expect(
      isAuthProviderUnavailableError({ status: 401, code: "INVALID_EMAIL_OR_PASSWORD" }),
    ).toBe(false);
    expect(isAuthProviderUnavailableError({ status: 429, code: "RATE_LIMITED" })).toBe(false);
    expect(isAuthProviderUnavailableError({ status: 500, code: "SERVER_ERROR" })).toBe(true);
    expect(isAuthProviderUnavailableError({ status: 502, code: "NETWORK_DNS" })).toBe(true);
    expect(isAuthProviderUnavailableError({ status: 500, code: "INTERNAL_ERROR" })).toBe(true);
    expect(isAuthProviderUnavailableError(new Error("unknown shape"))).toBe(true);
  });
});
