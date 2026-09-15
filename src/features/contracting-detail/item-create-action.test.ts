import { beforeEach, describe, expect, it, vi } from "vitest";

const actionMocks = vi.hoisted(() => ({
  readPersistentReadMode: vi.fn(),
  isPersistentContractingId: vi.fn(),
  createPersistentContractingItem: vi.fn(),
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
vi.mock("./persistent-item-create", () => ({
  createPersistentContractingItem: actionMocks.createPersistentContractingItem,
}));
vi.mock("./persistent-mutation", () => ({
  mutatePersistentContractingNextAction: actionMocks.mutatePersistentContractingNextAction,
}));
vi.mock("./persistent-object-mutation", () => ({
  mutatePersistentContractingObject: actionMocks.mutatePersistentContractingObject,
}));

import { createPersistentContractingItemAction } from "./actions";

const ID = "27000000-0000-4000-8000-000000000001";
const PATH = `/contratacoes/${ID}`;

function baseItemForm(): FormData {
  const form = new FormData();
  form.set("contractingId", ID);
  form.set("description", "  DEMO descrição exata  ");
  form.set("quantity", "12.3400000000000000001");
  form.set("unit", "  UN  ");
  form.set("catalogCode", "  CAT-001  ");
  return form;
}

describe("createPersistentContractingItemAction", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    actionMocks.readPersistentReadMode.mockReturnValue("persistent");
    actionMocks.isPersistentContractingId.mockReturnValue(true);
    actionMocks.createPersistentContractingItem.mockResolvedValue("created");
  });

  it("forwards exactly the five F35 fields without textual or numeric normalization", async () => {
    const form = baseItemForm();

    await expect(createPersistentContractingItemAction(form)).rejects.toThrow(
      `REDIRECT:${PATH}?itemCreation=created`,
    );

    expect(actionMocks.createPersistentContractingItem).toHaveBeenCalledWith({
      contractingId: ID,
      description: "  DEMO descrição exata  ",
      quantity: "12.3400000000000000001",
      unit: "  UN  ",
      catalogCode: "  CAT-001  ",
    });
    expect(actionMocks.revalidatePath).toHaveBeenCalledTimes(1);
    expect(actionMocks.revalidatePath).toHaveBeenCalledWith(PATH);
  });

  it("preserves empty and whitespace text fields while encoding empty quantity as null", async () => {
    const form = baseItemForm();
    form.set("description", "   ");
    form.set("quantity", "");
    form.set("unit", "");
    form.set("catalogCode", "   ");

    await expect(createPersistentContractingItemAction(form)).rejects.toThrow(
      `REDIRECT:${PATH}?itemCreation=created`,
    );

    expect(actionMocks.createPersistentContractingItem).toHaveBeenCalledWith({
      contractingId: ID,
      description: "   ",
      quantity: null,
      unit: "",
      catalogCode: "   ",
    });
  });

  it("keeps zero, negative, fractional, high-precision and whitespace quantity as exact strings", async () => {
    for (const quantity of ["0", "-7", "0.125", "123456789.123456789123456789", "   5.5   "]) {
      vi.clearAllMocks();
      actionMocks.readPersistentReadMode.mockReturnValue("persistent");
      actionMocks.isPersistentContractingId.mockReturnValue(true);
      actionMocks.createPersistentContractingItem.mockResolvedValue("created");
      const form = baseItemForm();
      form.set("quantity", quantity);

      await expect(createPersistentContractingItemAction(form)).rejects.toThrow(
        `REDIRECT:${PATH}?itemCreation=created`,
      );
      expect(actionMocks.createPersistentContractingItem).toHaveBeenCalledWith(
        expect.objectContaining({ quantity }),
      );
    }
  });

  it("treats an absent quantity scalar as null", async () => {
    const form = baseItemForm();
    form.delete("quantity");

    await expect(createPersistentContractingItemAction(form)).rejects.toThrow(
      `REDIRECT:${PATH}?itemCreation=created`,
    );
    expect(actionMocks.createPersistentContractingItem).toHaveBeenCalledWith(
      expect.objectContaining({ quantity: null }),
    );
  });

  it("fails closed on duplicate expected scalars before F35", async () => {
    for (const field of ["contractingId", "description", "quantity", "unit", "catalogCode"]) {
      vi.clearAllMocks();
      actionMocks.readPersistentReadMode.mockReturnValue("persistent");
      actionMocks.isPersistentContractingId.mockReturnValue(true);
      const form = baseItemForm();
      form.append(field, "FORGED-DUPLICATE");

      const expectedRedirect = field === "contractingId"
        ? "REDIRECT:/"
        : `REDIRECT:${PATH}?itemCreation=unavailable`;
      await expect(createPersistentContractingItemAction(form)).rejects.toThrow(expectedRedirect);
      expect(actionMocks.createPersistentContractingItem).not.toHaveBeenCalled();
      expect(actionMocks.revalidatePath).not.toHaveBeenCalled();
    }
  });

  it("rejects forged authority and navigation fields instead of forwarding them", async () => {
    for (const field of [
      "teamId",
      "team_id",
      "actor",
      "actorMembershipId",
      "membershipId",
      "issuer",
      "subject",
      "ordinal",
      "itemId",
      "eventId",
      "callback",
      "callbackURL",
      "redirect",
    ]) {
      vi.clearAllMocks();
      actionMocks.readPersistentReadMode.mockReturnValue("persistent");
      actionMocks.isPersistentContractingId.mockReturnValue(true);
      const form = baseItemForm();
      form.set(field, "FORGED");

      await expect(createPersistentContractingItemAction(form)).rejects.toThrow(
        `REDIRECT:${PATH}?itemCreation=unavailable`,
      );
      expect(actionMocks.createPersistentContractingItem).not.toHaveBeenCalled();
      expect(actionMocks.revalidatePath).not.toHaveBeenCalled();
    }
  });

  it("permits framework action transport fields without treating them as authority", async () => {
    const form = baseItemForm();
    form.set("$ACTION_ID_FORGED", "framework-like-field");

    await expect(createPersistentContractingItemAction(form)).rejects.toThrow(
      `REDIRECT:${PATH}?itemCreation=created`,
    );
    expect(actionMocks.createPersistentContractingItem).toHaveBeenCalledTimes(1);
  });

  it("never reaches F35 in demo, invalid mode or with a malformed contracting ID", async () => {
    for (const mode of ["demo", "invalid"] as const) {
      vi.clearAllMocks();
      actionMocks.readPersistentReadMode.mockReturnValue(mode);
      await expect(createPersistentContractingItemAction(baseItemForm())).rejects.toThrow("REDIRECT:/");
      expect(actionMocks.createPersistentContractingItem).not.toHaveBeenCalled();
    }

    vi.clearAllMocks();
    actionMocks.readPersistentReadMode.mockReturnValue("persistent");
    actionMocks.isPersistentContractingId.mockReturnValue(false);
    await expect(createPersistentContractingItemAction(baseItemForm())).rejects.toThrow("REDIRECT:/");
    expect(actionMocks.createPersistentContractingItem).not.toHaveBeenCalled();
  });

  it("maps only F35 outcomes to fixed local feedback and revalidates only created", async () => {
    for (const [result, shouldRevalidate] of [
      ["created", true],
      ["not-available", false],
      ["unavailable", false],
    ] as const) {
      vi.clearAllMocks();
      actionMocks.readPersistentReadMode.mockReturnValue("persistent");
      actionMocks.isPersistentContractingId.mockReturnValue(true);
      actionMocks.createPersistentContractingItem.mockResolvedValue(result);

      await expect(createPersistentContractingItemAction(baseItemForm())).rejects.toThrow(
        `REDIRECT:${PATH}?itemCreation=${result}`,
      );

      if (shouldRevalidate) {
        expect(actionMocks.revalidatePath).toHaveBeenCalledTimes(1);
        expect(actionMocks.revalidatePath).toHaveBeenCalledWith(PATH);
      } else {
        expect(actionMocks.revalidatePath).not.toHaveBeenCalled();
      }
    }
  });

  it("sanitizes unexpected F35 failure without leaking technical details or client navigation", async () => {
    const form = baseItemForm();
    actionMocks.createPersistentContractingItem.mockRejectedValueOnce(
      new Error("postgresql://secret-user:secret-pass@private.invalid/database claims=FORGED"),
    );

    await expect(createPersistentContractingItemAction(form)).rejects.toThrow(
      `REDIRECT:${PATH}?itemCreation=unavailable`,
    );

    const serialized = JSON.stringify(actionMocks.redirect.mock.calls);
    expect(serialized).not.toContain("secret-user");
    expect(serialized).not.toContain("private.invalid");
    expect(serialized).not.toContain("claims=FORGED");
    expect(actionMocks.revalidatePath).not.toHaveBeenCalled();
  });
});
