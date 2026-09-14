import { beforeEach, describe, expect, it, vi } from "vitest";

const actionMocks = vi.hoisted(() => ({
  readPersistentReadMode: vi.fn(),
  isPersistentContractingId: vi.fn(),
  mutatePersistentContractingNextAction: vi.fn(),
  mutatePersistentContractingObject: vi.fn(),
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
vi.mock("./persistent-read", () => ({
  isPersistentContractingId: actionMocks.isPersistentContractingId,
}));
vi.mock("./persistent-mutation", () => ({
  mutatePersistentContractingNextAction: actionMocks.mutatePersistentContractingNextAction,
}));
vi.mock("./persistent-object-mutation", () => ({
  mutatePersistentContractingObject: actionMocks.mutatePersistentContractingObject,
}));

import {
  updatePersistentNextActionAction,
  updatePersistentObjectAction,
} from "./actions";

const ID = "27000000-0000-4000-8000-000000000001";
const PATH = `/contratacoes/${ID}`;

function baseForm(): FormData {
  const form = new FormData();
  form.set("contractingId", ID);
  form.set("expectedNextAction", "DEMO old");
  form.set("newNextAction", "DEMO new");
  return form;
}

function baseObjectForm(): FormData {
  const form = new FormData();
  form.set("contractingId", ID);
  form.set("expectedObject", "DEMO old object");
  form.set("newObject", "DEMO new object");
  return form;
}

describe("updatePersistentNextActionAction", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    actionMocks.readPersistentReadMode.mockReturnValue("persistent");
    actionMocks.isPersistentContractingId.mockReturnValue(true);
    actionMocks.mutatePersistentContractingNextAction.mockResolvedValue("updated");
  });

  it("forwards exactly candidate ID + expected + new and ignores forged authority fields", async () => {
    const form = baseForm();
    form.set("newNextAction", "  DEMO preserved verbatim  ");
    form.set("team_id", "FORGED-TEAM");
    form.set("actorMembershipId", "FORGED-ACTOR");
    form.set("membershipId", "FORGED-MEMBERSHIP");
    form.set("issuer", "https://attacker.invalid");
    form.set("subject", "FORGED-SUBJECT");
    form.set("eventId", "27000000-0000-4000-8000-000000009999");
    form.set("callbackURL", "https://attacker.invalid/collect");
    form.set("$ACTION_ID_FORGED", "framework-like-field");

    await expect(updatePersistentNextActionAction(form)).rejects.toThrow(
      `REDIRECT:${PATH}?mutation=updated`,
    );

    expect(actionMocks.mutatePersistentContractingNextAction).toHaveBeenCalledWith({
      contractingId: ID,
      expectedNextAction: "DEMO old",
      newNextAction: "  DEMO preserved verbatim  ",
    });
    expect(actionMocks.mutatePersistentContractingNextAction.mock.calls[0]?.[0]).toEqual({
      contractingId: ID,
      expectedNextAction: "DEMO old",
      newNextAction: "  DEMO preserved verbatim  ",
    });
    expect(actionMocks.revalidatePath).toHaveBeenCalledWith(PATH);
    expect(actionMocks.redirect).not.toHaveBeenCalledWith("https://attacker.invalid/collect");
  });

  it("preserves NULL separately from the literal empty string", async () => {
    const clearForm = new FormData();
    clearForm.set("contractingId", ID);
    actionMocks.mutatePersistentContractingNextAction.mockResolvedValueOnce("unchanged");

    await expect(updatePersistentNextActionAction(clearForm)).rejects.toThrow(
      `REDIRECT:${PATH}?mutation=unchanged`,
    );
    expect(actionMocks.mutatePersistentContractingNextAction).toHaveBeenLastCalledWith({
      contractingId: ID,
      expectedNextAction: null,
      newNextAction: null,
    });

    const emptyStringForm = new FormData();
    emptyStringForm.set("contractingId", ID);
    emptyStringForm.set("expectedNextAction", "");
    emptyStringForm.set("newNextAction", "");
    actionMocks.mutatePersistentContractingNextAction.mockResolvedValueOnce("unchanged");

    await expect(updatePersistentNextActionAction(emptyStringForm)).rejects.toThrow(
      `REDIRECT:${PATH}?mutation=unchanged`,
    );
    expect(actionMocks.mutatePersistentContractingNextAction).toHaveBeenLastCalledWith({
      contractingId: ID,
      expectedNextAction: "",
      newNextAction: "",
    });
  });

  it("maps every F26 result to a fixed local sanitized state and revalidates only writes/conflicts", async () => {
    for (const [result, shouldRevalidate] of [
      ["updated", true],
      ["unchanged", false],
      ["conflict", true],
      ["not-available", false],
      ["unavailable", false],
    ] as const) {
      vi.clearAllMocks();
      actionMocks.readPersistentReadMode.mockReturnValue("persistent");
      actionMocks.isPersistentContractingId.mockReturnValue(true);
      actionMocks.mutatePersistentContractingNextAction.mockResolvedValueOnce(result);

      await expect(updatePersistentNextActionAction(baseForm())).rejects.toThrow(
        `REDIRECT:${PATH}?mutation=${result}`,
      );

      if (shouldRevalidate) {
        expect(actionMocks.revalidatePath).toHaveBeenCalledWith(PATH);
      } else {
        expect(actionMocks.revalidatePath).not.toHaveBeenCalled();
      }
    }
  });

  it("cannot write in demo/invalid mode even when a caller forges a valid UUID", async () => {
    for (const mode of ["demo", "invalid"] as const) {
      vi.clearAllMocks();
      actionMocks.readPersistentReadMode.mockReturnValue(mode);

      await expect(updatePersistentNextActionAction(baseForm())).rejects.toThrow("REDIRECT:/");
      expect(actionMocks.isPersistentContractingId).not.toHaveBeenCalled();
      expect(actionMocks.mutatePersistentContractingNextAction).not.toHaveBeenCalled();
      expect(actionMocks.revalidatePath).not.toHaveBeenCalled();
    }
  });

  it("rejects malformed candidate IDs and duplicate trusted scalar fields before F26", async () => {
    actionMocks.isPersistentContractingId.mockReturnValueOnce(false);
    await expect(updatePersistentNextActionAction(baseForm())).rejects.toThrow("REDIRECT:/");
    expect(actionMocks.mutatePersistentContractingNextAction).not.toHaveBeenCalled();

    vi.clearAllMocks();
    actionMocks.readPersistentReadMode.mockReturnValue("persistent");
    actionMocks.isPersistentContractingId.mockReturnValue(true);
    const duplicate = baseForm();
    duplicate.append("newNextAction", "FORGED-DUPLICATE");

    await expect(updatePersistentNextActionAction(duplicate)).rejects.toThrow(
      `REDIRECT:${PATH}?mutation=unavailable`,
    );
    expect(actionMocks.mutatePersistentContractingNextAction).not.toHaveBeenCalled();
  });

  it("sanitizes unexpected boundary failure without exposing error details or falling back to demo", async () => {
    actionMocks.mutatePersistentContractingNextAction.mockRejectedValueOnce(
      new Error("postgresql://secret-user:secret-pass@private.invalid/database"),
    );

    await expect(updatePersistentNextActionAction(baseForm())).rejects.toThrow(
      `REDIRECT:${PATH}?mutation=unavailable`,
    );

    const serializedRedirects = JSON.stringify(actionMocks.redirect.mock.calls);
    expect(serializedRedirects).not.toContain("secret-user");
    expect(serializedRedirects).not.toContain("private.invalid");
    expect(actionMocks.revalidatePath).not.toHaveBeenCalled();
  });
});

describe("updatePersistentObjectAction", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    actionMocks.readPersistentReadMode.mockReturnValue("persistent");
    actionMocks.isPersistentContractingId.mockReturnValue(true);
    actionMocks.mutatePersistentContractingObject.mockResolvedValue("updated");
  });

  it("forwards only candidate ID + exact expected/new object strings", async () => {
    const form = baseObjectForm();
    form.set("expectedObject", "  DEMO old object  ");
    form.set("newObject", "  DEMO new object  ");
    form.set("team_id", "FORGED-TEAM");
    form.set("actorMembershipId", "FORGED-ACTOR");
    form.set("membershipId", "FORGED-MEMBERSHIP");
    form.set("issuer", "https://attacker.invalid");
    form.set("subject", "FORGED-SUBJECT");
    form.set("eventId", "27000000-0000-4000-8000-000000009999");
    form.set("callbackURL", "https://attacker.invalid/collect");
    form.set("$ACTION_ID_FORGED", "framework-like-field");

    await expect(updatePersistentObjectAction(form)).rejects.toThrow(
      `REDIRECT:${PATH}?objectMutation=updated`,
    );

    expect(actionMocks.mutatePersistentContractingObject).toHaveBeenCalledWith({
      contractingId: ID,
      expectedObject: "  DEMO old object  ",
      newObject: "  DEMO new object  ",
    });
    expect(actionMocks.mutatePersistentContractingObject.mock.calls[0]?.[0]).toEqual({
      contractingId: ID,
      expectedObject: "  DEMO old object  ",
      newObject: "  DEMO new object  ",
    });
    expect(actionMocks.revalidatePath).toHaveBeenCalledWith(PATH);
    expect(actionMocks.redirect).not.toHaveBeenCalledWith("https://attacker.invalid/collect");
  });

  it("preserves the literal empty string and whitespace-only values", async () => {
    const form = baseObjectForm();
    form.set("expectedObject", "");
    form.set("newObject", "   ");
    actionMocks.mutatePersistentContractingObject.mockResolvedValueOnce("unchanged");

    await expect(updatePersistentObjectAction(form)).rejects.toThrow(
      `REDIRECT:${PATH}?objectMutation=unchanged`,
    );

    expect(actionMocks.mutatePersistentContractingObject).toHaveBeenCalledWith({
      contractingId: ID,
      expectedObject: "",
      newObject: "   ",
    });
  });

  it("maps every F32 result to a fixed local sanitized state and revalidates only writes/conflicts", async () => {
    for (const [result, shouldRevalidate] of [
      ["updated", true],
      ["unchanged", false],
      ["conflict", true],
      ["not-available", false],
      ["unavailable", false],
    ] as const) {
      vi.clearAllMocks();
      actionMocks.readPersistentReadMode.mockReturnValue("persistent");
      actionMocks.isPersistentContractingId.mockReturnValue(true);
      actionMocks.mutatePersistentContractingObject.mockResolvedValueOnce(result);

      await expect(updatePersistentObjectAction(baseObjectForm())).rejects.toThrow(
        `REDIRECT:${PATH}?objectMutation=${result}`,
      );

      if (shouldRevalidate) {
        expect(actionMocks.revalidatePath).toHaveBeenCalledWith(PATH);
      } else {
        expect(actionMocks.revalidatePath).not.toHaveBeenCalled();
      }
    }
  });

  it("cannot reach F32 in demo or invalid mode", async () => {
    for (const mode of ["demo", "invalid"] as const) {
      vi.clearAllMocks();
      actionMocks.readPersistentReadMode.mockReturnValue(mode);

      await expect(updatePersistentObjectAction(baseObjectForm())).rejects.toThrow("REDIRECT:/");
      expect(actionMocks.isPersistentContractingId).not.toHaveBeenCalled();
      expect(actionMocks.mutatePersistentContractingObject).not.toHaveBeenCalled();
      expect(actionMocks.revalidatePath).not.toHaveBeenCalled();
    }
  });

  it("fails closed on malformed IDs, missing required values and duplicate scalars", async () => {
    actionMocks.isPersistentContractingId.mockReturnValueOnce(false);
    await expect(updatePersistentObjectAction(baseObjectForm())).rejects.toThrow("REDIRECT:/");
    expect(actionMocks.mutatePersistentContractingObject).not.toHaveBeenCalled();

    vi.clearAllMocks();
    actionMocks.readPersistentReadMode.mockReturnValue("persistent");
    actionMocks.isPersistentContractingId.mockReturnValue(true);
    const missingExpected = baseObjectForm();
    missingExpected.delete("expectedObject");
    await expect(updatePersistentObjectAction(missingExpected)).rejects.toThrow(
      `REDIRECT:${PATH}?objectMutation=unavailable`,
    );
    expect(actionMocks.mutatePersistentContractingObject).not.toHaveBeenCalled();

    vi.clearAllMocks();
    actionMocks.readPersistentReadMode.mockReturnValue("persistent");
    actionMocks.isPersistentContractingId.mockReturnValue(true);
    const duplicate = baseObjectForm();
    duplicate.append("newObject", "FORGED-DUPLICATE");
    await expect(updatePersistentObjectAction(duplicate)).rejects.toThrow(
      `REDIRECT:${PATH}?objectMutation=unavailable`,
    );
    expect(actionMocks.mutatePersistentContractingObject).not.toHaveBeenCalled();
  });

  it("sanitizes unexpected F32 failure without exposing details or using client redirects", async () => {
    const form = baseObjectForm();
    form.set("callbackURL", "https://attacker.invalid/collect");
    actionMocks.mutatePersistentContractingObject.mockRejectedValueOnce(
      new Error("postgresql://secret-user:secret-pass@private.invalid/database"),
    );

    await expect(updatePersistentObjectAction(form)).rejects.toThrow(
      `REDIRECT:${PATH}?objectMutation=unavailable`,
    );

    const serializedRedirects = JSON.stringify(actionMocks.redirect.mock.calls);
    expect(serializedRedirects).not.toContain("secret-user");
    expect(serializedRedirects).not.toContain("private.invalid");
    expect(actionMocks.redirect).not.toHaveBeenCalledWith("https://attacker.invalid/collect");
    expect(actionMocks.revalidatePath).not.toHaveBeenCalled();
  });
});
