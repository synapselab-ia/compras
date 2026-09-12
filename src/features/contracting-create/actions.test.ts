import { beforeEach, describe, expect, it, vi } from "vitest";

const actionMocks = vi.hoisted(() => ({
  readPersistentReadMode: vi.fn(),
  createPersistentContracting: vi.fn(),
  revalidatePath: vi.fn(),
  redirect: vi.fn((url: string) => {
    throw new Error(`REDIRECT:${url}`);
  }),
}));

vi.mock("next/cache", () => ({ revalidatePath: actionMocks.revalidatePath }));
vi.mock("next/navigation", () => ({ redirect: actionMocks.redirect }));
vi.mock("@/server/persistent-read-mode", () => ({
  readPersistentReadMode: actionMocks.readPersistentReadMode,
}));
vi.mock("./persistent-create", () => ({
  createPersistentContracting: actionMocks.createPersistentContracting,
}));

import { createPersistentContractingAction } from "./actions";

const ID = "30000000-0000-4000-8000-000000000001";
const DETAIL_PATH = `/contratacoes/${ID}`;
const CREATE_PATH = "/contratacoes/nova";

function baseForm(): FormData {
  const form = new FormData();
  form.set("contractingId", ID);
  form.set("object", "  DEMO object preserved exactly  ");
  return form;
}

describe("createPersistentContractingAction", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    actionMocks.readPersistentReadMode.mockReturnValue("persistent");
    actionMocks.createPersistentContracting.mockResolvedValue("created");
  });

  it("forwards exactly contractingId + object and never trusts forged authority or redirect fields", async () => {
    const form = baseForm();
    form.set("teamId", "FORGED-TEAM");
    form.set("actorMembershipId", "FORGED-ACTOR");
    form.set("membershipId", "FORGED-MEMBERSHIP");
    form.set("createdByMembershipId", "FORGED-CREATOR");
    form.set("issuer", "https://attacker.invalid");
    form.set("subject", "FORGED-SUBJECT");
    form.set("eventId", "30000000-0000-4000-8000-000000009999");
    form.set("callback", "https://attacker.invalid/collect");
    form.set("redirect", "https://attacker.invalid/redirect");
    form.set("$ACTION_ID_FORGED", "framework-like-field");

    await expect(createPersistentContractingAction(form)).rejects.toThrow(
      `REDIRECT:${DETAIL_PATH}?creation=created`,
    );

    expect(actionMocks.createPersistentContracting).toHaveBeenCalledTimes(1);
    expect(actionMocks.createPersistentContracting).toHaveBeenCalledWith({
      contractingId: ID,
      object: "  DEMO object preserved exactly  ",
    });
    expect(actionMocks.createPersistentContracting.mock.calls[0]?.[0]).toEqual({
      contractingId: ID,
      object: "  DEMO object preserved exactly  ",
    });
    expect(actionMocks.redirect).not.toHaveBeenCalledWith("https://attacker.invalid/collect");
    expect(actionMocks.redirect).not.toHaveBeenCalledWith("https://attacker.invalid/redirect");
  });

  it("preserves an empty object string instead of inventing a non-empty rule", async () => {
    const form = baseForm();
    form.set("object", "");

    await expect(createPersistentContractingAction(form)).rejects.toThrow(
      `REDIRECT:${DETAIL_PATH}?creation=created`,
    );

    expect(actionMocks.createPersistentContracting).toHaveBeenCalledWith({
      contractingId: ID,
      object: "",
    });
  });

  it("rejects demo and invalid modes before touching F29", async () => {
    for (const mode of ["demo", "invalid"] as const) {
      vi.clearAllMocks();
      actionMocks.readPersistentReadMode.mockReturnValue(mode);

      await expect(createPersistentContractingAction(baseForm())).rejects.toThrow("REDIRECT:/");
      expect(actionMocks.createPersistentContracting).not.toHaveBeenCalled();
      expect(actionMocks.revalidatePath).not.toHaveBeenCalled();
    }
  });

  it("fails closed on malformed candidate IDs and duplicate trusted scalars before F29", async () => {
    const malformed = baseForm();
    malformed.set("contractingId", "not-a-uuid");

    await expect(createPersistentContractingAction(malformed)).rejects.toThrow(
      `REDIRECT:${CREATE_PATH}?creation=unavailable`,
    );
    expect(actionMocks.createPersistentContracting).not.toHaveBeenCalled();

    vi.clearAllMocks();
    actionMocks.readPersistentReadMode.mockReturnValue("persistent");
    const duplicateId = baseForm();
    duplicateId.append("contractingId", "30000000-0000-4000-8000-000000000002");

    await expect(createPersistentContractingAction(duplicateId)).rejects.toThrow(
      `REDIRECT:${CREATE_PATH}?creation=unavailable`,
    );
    expect(actionMocks.createPersistentContracting).not.toHaveBeenCalled();

    vi.clearAllMocks();
    actionMocks.readPersistentReadMode.mockReturnValue("persistent");
    const duplicateObject = baseForm();
    duplicateObject.append("object", "FORGED-DUPLICATE");

    await expect(createPersistentContractingAction(duplicateObject)).rejects.toThrow(
      `REDIRECT:${CREATE_PATH}?creation=unavailable`,
    );
    expect(actionMocks.createPersistentContracting).not.toHaveBeenCalled();
  });

  it("maps successful create/replay and sanitized failures to fixed local routes", async () => {
    for (const result of ["created", "already-created"] as const) {
      vi.clearAllMocks();
      actionMocks.readPersistentReadMode.mockReturnValue("persistent");
      actionMocks.createPersistentContracting.mockResolvedValueOnce(result);

      await expect(createPersistentContractingAction(baseForm())).rejects.toThrow(
        `REDIRECT:${DETAIL_PATH}?creation=${result}`,
      );
      expect(actionMocks.revalidatePath).toHaveBeenCalledWith("/");
      expect(actionMocks.revalidatePath).toHaveBeenCalledWith(DETAIL_PATH);
    }

    for (const result of ["not-available", "unavailable"] as const) {
      vi.clearAllMocks();
      actionMocks.readPersistentReadMode.mockReturnValue("persistent");
      actionMocks.createPersistentContracting.mockResolvedValueOnce(result);

      await expect(createPersistentContractingAction(baseForm())).rejects.toThrow(
        `REDIRECT:${CREATE_PATH}?creation=${result}`,
      );
      expect(actionMocks.revalidatePath).not.toHaveBeenCalled();
    }
  });

  it("sanitizes unexpected boundary errors without exposing details", async () => {
    actionMocks.createPersistentContracting.mockRejectedValueOnce(
      new Error("postgresql://secret-user:secret-pass@private.invalid/database?claim=FORGED"),
    );

    await expect(createPersistentContractingAction(baseForm())).rejects.toThrow(
      `REDIRECT:${CREATE_PATH}?creation=unavailable`,
    );

    const serializedRedirects = JSON.stringify(actionMocks.redirect.mock.calls);
    expect(serializedRedirects).not.toContain("secret-user");
    expect(serializedRedirects).not.toContain("private.invalid");
    expect(serializedRedirects).not.toContain("FORGED");
    expect(actionMocks.revalidatePath).not.toHaveBeenCalled();
  });
});
