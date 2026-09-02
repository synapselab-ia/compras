import { beforeEach, describe, expect, it, vi } from "vitest";

const runtimeMocks = vi.hoisted(() => ({
  getConfiguredPrivateAuth: vi.fn(),
  isAuthProviderUnavailableError: vi.fn(),
  signInEmail: vi.fn(),
  signOut: vi.fn(),
}));

vi.mock("server-only", () => ({}));
vi.mock("./runtime", () => ({
  getConfiguredPrivateAuth: runtimeMocks.getConfiguredPrivateAuth,
  isAuthProviderUnavailableError: runtimeMocks.isAuthProviderUnavailableError,
}));

import {
  signInExistingIdentity,
  signOutCurrentIdentity,
} from "./private-admission";

describe("private auth admission", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    runtimeMocks.getConfiguredPrivateAuth.mockReturnValue({
      issuer: "https://auth.demo.invalid/neondb/auth",
      auth: {
        signIn: { email: runtimeMocks.signInEmail },
        signOut: runtimeMocks.signOut,
      },
    });
    runtimeMocks.isAuthProviderUnavailableError.mockReturnValue(false);
  });

  it("uses only email/password sign-in for an already admitted provider identity", async () => {
    runtimeMocks.signInEmail.mockResolvedValue({ data: { ok: true }, error: null });

    await expect(
      signInExistingIdentity({
        email: "  admitted@example.invalid  ",
        password: " Demo password with spaces ",
      }),
    ).resolves.toBe("signed-in");

    expect(runtimeMocks.signInEmail).toHaveBeenCalledWith({
      email: "admitted@example.invalid",
      password: " Demo password with spaces ",
    });
  });

  it("rejects malformed credentials before contacting the provider", async () => {
    await expect(signInExistingIdentity({ email: "   ", password: "x" })).resolves.toBe("rejected");
    await expect(signInExistingIdentity({ email: "a@example.invalid", password: "" })).resolves.toBe("rejected");
    expect(runtimeMocks.signInEmail).not.toHaveBeenCalled();
  });

  it("keeps credential rejection generic and separates provider failure", async () => {
    runtimeMocks.signInEmail.mockResolvedValueOnce({
      data: null,
      error: { status: 401, code: "INVALID_EMAIL_OR_PASSWORD", message: "do not expose" },
    });
    runtimeMocks.isAuthProviderUnavailableError.mockReturnValueOnce(false);
    await expect(
      signInExistingIdentity({ email: "admitted@example.invalid", password: "wrong" }),
    ).resolves.toBe("rejected");

    runtimeMocks.signInEmail.mockResolvedValueOnce({
      data: null,
      error: { status: 502, code: "NETWORK_TIMEOUT", message: "private endpoint" },
    });
    runtimeMocks.isAuthProviderUnavailableError.mockReturnValueOnce(true);
    await expect(
      signInExistingIdentity({ email: "admitted@example.invalid", password: "demo" }),
    ).resolves.toBe("unavailable");
  });

  it("fails closed when auth configuration is unavailable or the provider throws", async () => {
    runtimeMocks.getConfiguredPrivateAuth.mockReturnValueOnce(null);
    await expect(
      signInExistingIdentity({ email: "admitted@example.invalid", password: "demo" }),
    ).resolves.toBe("unavailable");

    runtimeMocks.signInEmail.mockRejectedValueOnce(new Error("provider transport detail"));
    await expect(
      signInExistingIdentity({ email: "admitted@example.invalid", password: "demo" }),
    ).resolves.toBe("unavailable");
  });

  it("signs out through the server SDK and treats an already-invalid session as signed out", async () => {
    runtimeMocks.signOut.mockResolvedValueOnce({ data: { ok: true }, error: null });
    await expect(signOutCurrentIdentity()).resolves.toBe("signed-out");

    runtimeMocks.signOut.mockResolvedValueOnce({
      data: null,
      error: { status: 401, code: "UNAUTHORIZED", message: "expired" },
    });
    runtimeMocks.isAuthProviderUnavailableError.mockReturnValueOnce(false);
    await expect(signOutCurrentIdentity()).resolves.toBe("signed-out");
  });

  it("does not claim sign-out success when provider failure prevents confirmation", async () => {
    runtimeMocks.signOut.mockResolvedValueOnce({
      data: null,
      error: { status: 502, code: "NETWORK_RESET", message: "private detail" },
    });
    runtimeMocks.isAuthProviderUnavailableError.mockReturnValueOnce(true);
    await expect(signOutCurrentIdentity()).resolves.toBe("unavailable");
  });
});
