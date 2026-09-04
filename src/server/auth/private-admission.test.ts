import { beforeEach, describe, expect, it, vi } from "vitest";

const mocks = vi.hoisted(() => {
  const signInEmail = vi.fn();
  const getSession = vi.fn();
  const signOut = vi.fn();

  return {
    signInEmail,
    getSession,
    signOut,
    cookieSet: vi.fn(),
    cookies: vi.fn(),
    headers: vi.fn(),
    getConfiguredPrivateAuth: vi.fn(() => ({
      issuer: "urn:compras:better-auth:self-hosted:v1",
      auth: { api: { signInEmail, getSession, signOut } },
    })),
    isAuthProviderUnavailableError: vi.fn(() => false),
  };
});

vi.mock("server-only", () => ({}));
vi.mock("next/headers", () => ({
  cookies: mocks.cookies,
  headers: mocks.headers,
}));
vi.mock("./runtime", () => ({
  getConfiguredPrivateAuth: mocks.getConfiguredPrivateAuth,
  isAuthProviderUnavailableError: mocks.isAuthProviderUnavailableError,
}));

import {
  signInExistingIdentity,
  signOutCurrentIdentity,
} from "./private-admission";

function setCookieHeaders(value: string): Headers {
  const result = new Headers();
  result.append("set-cookie", value);
  return result;
}

const ACTIVE_SESSION_COOKIE =
  "__Secure-better-auth.session_token=fictitious-token; Path=/; HttpOnly; Secure; SameSite=Lax";
const INVALIDATED_SESSION_COOKIE =
  "__Secure-better-auth.session_token=; Path=/; HttpOnly; Secure; SameSite=Lax; Max-Age=0";

describe("private Better Auth admission", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    mocks.getConfiguredPrivateAuth.mockReturnValue({
      issuer: "urn:compras:better-auth:self-hosted:v1",
      auth: {
        api: {
          signInEmail: mocks.signInEmail,
          getSession: mocks.getSession,
          signOut: mocks.signOut,
        },
      },
    });
    mocks.isAuthProviderUnavailableError.mockReturnValue(false);
    mocks.cookies.mockResolvedValue({ set: mocks.cookieSet });
    mocks.headers.mockResolvedValue(
      new Headers({ cookie: "__Secure-better-auth.session_token=fictitious-token" }),
    );
  });

  it("signs in an existing identity only after server session readback and cookie persistence", async () => {
    mocks.signInEmail.mockResolvedValue({
      response: { user: { id: "subject-1" } },
      headers: setCookieHeaders(ACTIVE_SESSION_COOKIE),
    });
    mocks.getSession.mockResolvedValue({
      user: { id: "subject-1" },
      session: { id: "session-1" },
    });

    await expect(
      signInExistingIdentity({
        email: "  existing@example.invalid  ",
        password: "fictitious-password",
      }),
    ).resolves.toBe("signed-in");

    expect(mocks.signInEmail).toHaveBeenCalledWith({
      body: {
        email: "existing@example.invalid",
        password: "fictitious-password",
      },
      returnHeaders: true,
    });
    expect(mocks.getSession).toHaveBeenCalledWith({
      headers: expect.objectContaining({}),
    });
    expect(mocks.cookieSet).toHaveBeenCalledWith(
      "__Secure-better-auth.session_token",
      "fictitious-token",
      expect.objectContaining({
        path: "/",
        httpOnly: true,
        secure: true,
        sameSite: "lax",
      }),
    );
  });

  it("fails closed when the session cookie or server readback cannot prove sign-in", async () => {
    mocks.signInEmail.mockResolvedValueOnce({
      response: { user: { id: "subject-1" } },
      headers: new Headers(),
    });
    await expect(
      signInExistingIdentity({ email: "existing@example.invalid", password: "x" }),
    ).resolves.toBe("unavailable");

    mocks.signInEmail.mockResolvedValueOnce({
      response: { user: { id: "subject-1" } },
      headers: setCookieHeaders(ACTIVE_SESSION_COOKIE),
    });
    mocks.getSession.mockResolvedValueOnce({
      user: { id: "different-subject" },
      session: { id: "session-2" },
    });
    await expect(
      signInExistingIdentity({ email: "existing@example.invalid", password: "x" }),
    ).resolves.toBe("unavailable");

    expect(mocks.cookieSet).not.toHaveBeenCalled();
  });

  it("maps rejected credentials separately from provider failure", async () => {
    mocks.signInEmail.mockRejectedValueOnce({ statusCode: 401 });
    await expect(
      signInExistingIdentity({ email: "existing@example.invalid", password: "wrong" }),
    ).resolves.toBe("rejected");

    mocks.signInEmail.mockRejectedValueOnce(new Error("provider failure"));
    mocks.isAuthProviderUnavailableError.mockReturnValueOnce(true);
    await expect(
      signInExistingIdentity({ email: "existing@example.invalid", password: "wrong" }),
    ).resolves.toBe("unavailable");
  });

  it("reports sign-out only after an invalidation cookie and revoked server session", async () => {
    mocks.signOut.mockResolvedValue({
      response: { success: true },
      headers: setCookieHeaders(INVALIDATED_SESSION_COOKIE),
    });
    mocks.getSession.mockResolvedValue(null);

    await expect(signOutCurrentIdentity()).resolves.toBe("signed-out");
    expect(mocks.signOut).toHaveBeenCalledWith({
      headers: expect.any(Headers),
      returnHeaders: true,
    });
    expect(mocks.cookieSet).toHaveBeenCalledWith(
      "__Secure-better-auth.session_token",
      "",
      expect.objectContaining({ maxAge: 0, httpOnly: true, secure: true }),
    );
  });

  it("does not claim sign-out when invalidation or revocation cannot be confirmed", async () => {
    mocks.signOut.mockResolvedValueOnce({
      response: { success: true },
      headers: new Headers(),
    });
    await expect(signOutCurrentIdentity()).resolves.toBe("unavailable");

    mocks.signOut.mockResolvedValueOnce({
      response: { success: true },
      headers: setCookieHeaders(INVALIDATED_SESSION_COOKIE),
    });
    mocks.getSession.mockResolvedValueOnce({
      user: { id: "still-active" },
      session: { id: "session" },
    });
    await expect(signOutCurrentIdentity()).resolves.toBe("unavailable");
  });
});
