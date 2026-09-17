import { beforeEach, describe, expect, it, vi } from "vitest";

const actionMocks = vi.hoisted(() => ({
  readPersistentReadMode: vi.fn(),
  isPersistentContractingId: vi.fn(),
  mutatePersistentContractingItem: vi.fn(),
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
vi.mock("./persistent-item-mutation", () => ({
  mutatePersistentContractingItem: actionMocks.mutatePersistentContractingItem,
}));

import { updatePersistentContractingItemAction } from "./actions";

const CONTRACTING_ID = "39000000-0000-4000-8000-000000000001";
const ITEM_ID = "39000000-0000-4000-8000-000000000002";
const PATH = `/contratacoes/${CONTRACTING_ID}`;

function baseItemMutationForm(): FormData {
  const form = new FormData();
  form.set("contractingId", CONTRACTING_ID);
  form.set("itemId", ITEM_ID);
  form.set("expectedDescription", "  DEMO old description  ");
  form.set("expectedQuantity", "123456789.123456789123456789");
  form.set("expectedUnitKind", "text");
  form.set("expectedUnit", "  kg  ");
  form.set("expectedCatalogCodeKind", "text");
  form.set("expectedCatalogCode", "  OLD-CAT  ");
  form.set("newDescription", "  DEMO new description  ");
  form.set("newQuantity", "-0.000000000000000000123456789");
  form.set("newUnitKind", "text");
  form.set("newUnit", "   ");
  form.set("newCatalogCodeKind", "text");
  form.set("newCatalogCode", "");
  return form;
}

describe("updatePersistentContractingItemAction", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    actionMocks.readPersistentReadMode.mockReturnValue("persistent");
    actionMocks.isPersistentContractingId.mockReturnValue(true);
    actionMocks.mutatePersistentContractingItem.mockResolvedValue("updated");
  });

  it("forwards the complete exact expected/new snapshot to F38 without normalization", async () => {
    await expect(updatePersistentContractingItemAction(baseItemMutationForm())).rejects.toThrow(
      `REDIRECT:${PATH}?itemMutation=updated`,
    );

    expect(actionMocks.mutatePersistentContractingItem).toHaveBeenCalledWith({
      contractingId: CONTRACTING_ID,
      itemId: ITEM_ID,
      expectedDescription: "  DEMO old description  ",
      expectedQuantity: "123456789.123456789123456789",
      expectedUnit: "  kg  ",
      expectedCatalogCode: "  OLD-CAT  ",
      newDescription: "  DEMO new description  ",
      newQuantity: "-0.000000000000000000123456789",
      newUnit: "   ",
      newCatalogCode: "",
    });
    expect(actionMocks.revalidatePath).toHaveBeenCalledTimes(1);
    expect(actionMocks.revalidatePath).toHaveBeenCalledWith(PATH);
  });

  it("preserves explicit NULL separately from empty and spaced text", async () => {
    const form = baseItemMutationForm();
    form.delete("expectedQuantity");
    form.set("expectedUnitKind", "null");
    form.set("expectedUnit", "IGNORED-FORGED-TEXT");
    form.set("expectedCatalogCodeKind", "text");
    form.set("expectedCatalogCode", "");
    form.set("newQuantity", "");
    form.set("newUnitKind", "text");
    form.set("newUnit", "");
    form.set("newCatalogCodeKind", "null");
    form.set("newCatalogCode", "IGNORED-FORGED-TEXT");

    await expect(updatePersistentContractingItemAction(form)).rejects.toThrow(
      `REDIRECT:${PATH}?itemMutation=updated`,
    );

    expect(actionMocks.mutatePersistentContractingItem).toHaveBeenCalledWith(
      expect.objectContaining({
        expectedQuantity: null,
        expectedUnit: null,
        expectedCatalogCode: "",
        newQuantity: null,
        newUnit: "",
        newCatalogCode: null,
      }),
    );
  });

  it("keeps zero, negative, fractional, high precision and whitespace quantity as strings", async () => {
    for (const quantity of [
      "0",
      "-7",
      "0.125",
      "123456789.123456789123456789",
      "   5.5   ",
    ]) {
      vi.clearAllMocks();
      actionMocks.readPersistentReadMode.mockReturnValue("persistent");
      actionMocks.isPersistentContractingId.mockReturnValue(true);
      actionMocks.mutatePersistentContractingItem.mockResolvedValue("updated");
      const form = baseItemMutationForm();
      form.set("newQuantity", quantity);

      await expect(updatePersistentContractingItemAction(form)).rejects.toThrow(
        `REDIRECT:${PATH}?itemMutation=updated`,
      );
      expect(actionMocks.mutatePersistentContractingItem).toHaveBeenCalledWith(
        expect.objectContaining({ newQuantity: quantity }),
      );
    }
  });

  it("fails closed on duplicate transport scalars before F38", async () => {
    for (const field of [
      "contractingId",
      "itemId",
      "expectedDescription",
      "expectedQuantity",
      "expectedUnitKind",
      "expectedUnit",
      "expectedCatalogCodeKind",
      "expectedCatalogCode",
      "newDescription",
      "newQuantity",
      "newUnitKind",
      "newUnit",
      "newCatalogCodeKind",
      "newCatalogCode",
    ]) {
      vi.clearAllMocks();
      actionMocks.readPersistentReadMode.mockReturnValue("persistent");
      actionMocks.isPersistentContractingId.mockReturnValue(true);
      const form = baseItemMutationForm();
      form.append(field, "FORGED-DUPLICATE");

      const expectedRedirect = field === "contractingId"
        ? "REDIRECT:/"
        : `REDIRECT:${PATH}?itemMutation=unavailable`;
      await expect(updatePersistentContractingItemAction(form)).rejects.toThrow(expectedRedirect);
      expect(actionMocks.mutatePersistentContractingItem).not.toHaveBeenCalled();
      expect(actionMocks.revalidatePath).not.toHaveBeenCalled();
    }
  });

  it("rejects invalid nullable kind encodings before F38", async () => {
    for (const field of [
      "expectedUnitKind",
      "expectedCatalogCodeKind",
      "newUnitKind",
      "newCatalogCodeKind",
    ]) {
      vi.clearAllMocks();
      actionMocks.readPersistentReadMode.mockReturnValue("persistent");
      actionMocks.isPersistentContractingId.mockReturnValue(true);
      const form = baseItemMutationForm();
      form.set(field, "auto");

      await expect(updatePersistentContractingItemAction(form)).rejects.toThrow(
        `REDIRECT:${PATH}?itemMutation=unavailable`,
      );
      expect(actionMocks.mutatePersistentContractingItem).not.toHaveBeenCalled();
    }

    const missingTextValue = baseItemMutationForm();
    missingTextValue.delete("newUnit");
    await expect(updatePersistentContractingItemAction(missingTextValue)).rejects.toThrow(
      `REDIRECT:${PATH}?itemMutation=unavailable`,
    );
    expect(actionMocks.mutatePersistentContractingItem).not.toHaveBeenCalled();
  });

  it("rejects forged authority, lifecycle and navigation fields instead of forwarding them", async () => {
    for (const field of [
      "teamId",
      "team_id",
      "actor",
      "actorMembershipId",
      "membershipId",
      "issuer",
      "subject",
      "ordinal",
      "retiredAt",
      "updatedAt",
      "eventId",
      "descriptionEventId",
      "quantityEventId",
      "unitEventId",
      "catalogCodeEventId",
      "callback",
      "callbackURL",
      "redirect",
    ]) {
      vi.clearAllMocks();
      actionMocks.readPersistentReadMode.mockReturnValue("persistent");
      actionMocks.isPersistentContractingId.mockReturnValue(true);
      const form = baseItemMutationForm();
      form.set(field, "FORGED");

      await expect(updatePersistentContractingItemAction(form)).rejects.toThrow(
        `REDIRECT:${PATH}?itemMutation=unavailable`,
      );
      expect(actionMocks.mutatePersistentContractingItem).not.toHaveBeenCalled();
      expect(actionMocks.revalidatePath).not.toHaveBeenCalled();
    }
  });

  it("permits framework action fields without treating them as browser authority", async () => {
    const form = baseItemMutationForm();
    form.set("$ACTION_ID_FORGED", "framework-like-field");

    await expect(updatePersistentContractingItemAction(form)).rejects.toThrow(
      `REDIRECT:${PATH}?itemMutation=updated`,
    );
    expect(actionMocks.mutatePersistentContractingItem).toHaveBeenCalledTimes(1);
  });

  it("never reaches F38 outside persistent mode or with malformed candidate IDs", async () => {
    for (const mode of ["demo", "invalid"] as const) {
      vi.clearAllMocks();
      actionMocks.readPersistentReadMode.mockReturnValue(mode);
      await expect(updatePersistentContractingItemAction(baseItemMutationForm())).rejects.toThrow(
        "REDIRECT:/",
      );
      expect(actionMocks.mutatePersistentContractingItem).not.toHaveBeenCalled();
      expect(actionMocks.revalidatePath).not.toHaveBeenCalled();
    }

    vi.clearAllMocks();
    actionMocks.readPersistentReadMode.mockReturnValue("persistent");
    actionMocks.isPersistentContractingId.mockReturnValueOnce(false);
    await expect(updatePersistentContractingItemAction(baseItemMutationForm())).rejects.toThrow(
      "REDIRECT:/",
    );
    expect(actionMocks.mutatePersistentContractingItem).not.toHaveBeenCalled();

    vi.clearAllMocks();
    actionMocks.readPersistentReadMode.mockReturnValue("persistent");
    actionMocks.isPersistentContractingId
      .mockReturnValueOnce(true)
      .mockReturnValueOnce(false);
    await expect(updatePersistentContractingItemAction(baseItemMutationForm())).rejects.toThrow(
      `REDIRECT:${PATH}?itemMutation=unavailable`,
    );
    expect(actionMocks.mutatePersistentContractingItem).not.toHaveBeenCalled();
  });

  it("maps only approved F38 outcomes and revalidates only a real update", async () => {
    for (const [result, shouldRevalidate] of [
      ["updated", true],
      ["unchanged", false],
      ["conflict", false],
      ["not-available", false],
      ["unavailable", false],
    ] as const) {
      vi.clearAllMocks();
      actionMocks.readPersistentReadMode.mockReturnValue("persistent");
      actionMocks.isPersistentContractingId.mockReturnValue(true);
      actionMocks.mutatePersistentContractingItem.mockResolvedValue(result);

      await expect(updatePersistentContractingItemAction(baseItemMutationForm())).rejects.toThrow(
        `REDIRECT:${PATH}?itemMutation=${result}`,
      );

      if (shouldRevalidate) {
        expect(actionMocks.revalidatePath).toHaveBeenCalledWith(PATH);
      } else {
        expect(actionMocks.revalidatePath).not.toHaveBeenCalled();
      }
    }
  });

  it("sanitizes impossible outcomes and thrown technical details", async () => {
    actionMocks.mutatePersistentContractingItem.mockResolvedValueOnce("internal-detail");
    await expect(updatePersistentContractingItemAction(baseItemMutationForm())).rejects.toThrow(
      `REDIRECT:${PATH}?itemMutation=unavailable`,
    );
    expect(actionMocks.revalidatePath).not.toHaveBeenCalled();

    vi.clearAllMocks();
    actionMocks.readPersistentReadMode.mockReturnValue("persistent");
    actionMocks.isPersistentContractingId.mockReturnValue(true);
    actionMocks.mutatePersistentContractingItem.mockRejectedValueOnce(
      new Error("postgresql://secret-user:secret-pass@private.invalid/database claim=FORGED"),
    );

    await expect(updatePersistentContractingItemAction(baseItemMutationForm())).rejects.toThrow(
      `REDIRECT:${PATH}?itemMutation=unavailable`,
    );

    const serialized = JSON.stringify(actionMocks.redirect.mock.calls);
    expect(serialized).not.toContain("secret-user");
    expect(serialized).not.toContain("private.invalid");
    expect(serialized).not.toContain("claim=FORGED");
    expect(actionMocks.revalidatePath).not.toHaveBeenCalled();
  });
});
