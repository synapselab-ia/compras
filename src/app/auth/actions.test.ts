import { beforeEach, describe, expect, it, vi } from "vitest";

const actionMocks = vi.hoisted(() => ({
  redirect: vi.fn((url: string) => {
    throw new Error(`REDIRECT:${url}`);
  }),
  signInExistingIdentity: vi.fn(),
  signOutCurrentIdentity: vi.fn(),
}));

vi.mock("next/navigation", () => ({ redirect: actionMocks.redirect }));
vi.mock("../../server/auth/private-admission", () => ({
  signInExistingIdentity: actionMocks.signInExistingIdentity,
  signOutCurrentIdentity: actionMocks.signOutCurrentIdentity,
}));

import { signInAction, signOutAction } from "./actions";

describe("private auth server actions", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it("ignores forged callback and identity/scope fields and uses a fixed success redirect", async () => {
    actionMocks.signInExistingIdentity.mockResolvedValue("signed-in");
    const form = new FormData();
    form.set("email", "admitted@example.invalid");
    form.set("password", "demo-password");
    form.set("callbackURL", "https://attacker.invalid/collect");
    form.set("issuer", "https://attacker.invalid");
    form.set("subject", "FORGED");
    form.set("team_id", "FORGED");
    form.set("membership_id", "FORGED");

    await expect(signInAction(form)).rejects.toThrow("REDIRECT:/");
    expect(actionMocks.signInExistingIdentity).toHaveBeenCalledWith({
      email: "admitted@example.invalid",
      password: "demo-password",
    });
    expect(actionMocks.redirect).toHaveBeenCalledWith("/");
  });

  it("maps bad credentials and provider failure to fixed local generic states", async () => {
    const form = new FormData();
    form.set("email", "admitted@example.invalid");
    form.set("password", "wrong");

    actionMocks.signInExistingIdentity.mockResolvedValueOnce("rejected");
    await expect(signInAction(form)).rejects.toThrow(
      "REDIRECT:/auth/sign-in?state=rejected",
    );

    actionMocks.signInExistingIdentity.mockResolvedValueOnce("unavailable");
    await expect(signInAction(form)).rejects.toThrow(
      "REDIRECT:/auth/sign-in?state=unavailable",
    );

    expect(actionMocks.redirect).not.toHaveBeenCalledWith("https://attacker.invalid/collect");
  });

  it("rejects non-string or missing credential fields before provider sign-in", async () => {
    const form = new FormData();
    form.set("email", "admitted@example.invalid");

    await expect(signInAction(form)).rejects.toThrow(
      "REDIRECT:/auth/sign-in?state=rejected",
    );
    expect(actionMocks.signInExistingIdentity).not.toHaveBeenCalled();
  });

  it("uses fixed local sign-out redirects without accepting a callback", async () => {
    actionMocks.signOutCurrentIdentity.mockResolvedValueOnce("signed-out");
    await expect(signOutAction()).rejects.toThrow(
      "REDIRECT:/auth/sign-in?state=signed-out",
    );

    actionMocks.signOutCurrentIdentity.mockResolvedValueOnce("unavailable");
    await expect(signOutAction()).rejects.toThrow(
      "REDIRECT:/auth/sign-in?state=unavailable",
    );
  });
});
