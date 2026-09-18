import { beforeEach, describe, expect, it, vi } from "vitest";

const actionMocks = vi.hoisted(() => ({
  readPersistentReadMode: vi.fn(),
  isPersistentContractingId: vi.fn(),
  createPersistentRelatedIdentifier: vi.fn(),
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
vi.mock("./persistent-related-identifier-create", () => ({
  createPersistentRelatedIdentifier: actionMocks.createPersistentRelatedIdentifier,
}));
vi.mock("./persistent-mutation", () => ({
  mutatePersistentContractingNextAction: actionMocks.mutatePersistentContractingNextAction,
}));
vi.mock("./persistent-object-mutation", () => ({
  mutatePersistentContractingObject: actionMocks.mutatePersistentContractingObject,
}));

import { createPersistentRelatedIdentifierAction } from "./actions";

const ID = "42000000-0000-4000-8000-000000000001";
const CANDIDATE = "42010000-0000-4000-8000-000000000001";
const PATH = `/contratacoes/${ID}`;

function baseForm(): FormData {
  const form = new FormData();
  form.set("contractingId", ID);
  form.set("relatedIdentifierId", CANDIDATE);
  form.set("identifierKindKind", "text");
  form.set("identifierKind", "  DEMO tipo  ");
  form.set("identifierValue", "  DEMO identificador  ");
  form.set("sourceSystemKind", "text");
  form.set("sourceSystem", "  DEMO origem  ");
  form.set("noteKind", "text");
  form.set("note", "  DEMO nota  ");
  return form;
}

describe("createPersistentRelatedIdentifierAction", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    actionMocks.readPersistentReadMode.mockReturnValue("persistent");
    actionMocks.isPersistentContractingId.mockReturnValue(true);
    actionMocks.createPersistentRelatedIdentifier.mockResolvedValue("created");
  });

  it("forwards exactly the six F41 fields after explicit nullable transport decoding", async () => {
    await expect(createPersistentRelatedIdentifierAction(baseForm())).rejects.toThrow(
      `REDIRECT:${PATH}?relatedIdentifierCreation=created`,
    );

    expect(actionMocks.createPersistentRelatedIdentifier).toHaveBeenCalledWith({
      contractingId: ID,
      relatedIdentifierId: CANDIDATE,
      identifierKind: "  DEMO tipo  ",
      identifierValue: "  DEMO identificador  ",
      sourceSystem: "  DEMO origem  ",
      note: "  DEMO nota  ",
    });
    expect(actionMocks.revalidatePath).toHaveBeenCalledTimes(1);
    expect(actionMocks.revalidatePath).toHaveBeenCalledWith(PATH);
  });

  it("preserves NULL, empty, spaces-only and surrounding spaces as distinct values", async () => {
    const form = baseForm();
    form.set("identifierKindKind", "null");
    form.set("identifierKind", "IGNORED-WHEN-NULL");
    form.set("identifierValue", "");
    form.set("sourceSystemKind", "text");
    form.set("sourceSystem", "   ");
    form.set("noteKind", "text");
    form.set("note", "  nota  ");

    await expect(createPersistentRelatedIdentifierAction(form)).rejects.toThrow(
      `REDIRECT:${PATH}?relatedIdentifierCreation=created`,
    );

    expect(actionMocks.createPersistentRelatedIdentifier).toHaveBeenCalledWith({
      contractingId: ID,
      relatedIdentifierId: CANDIDATE,
      identifierKind: null,
      identifierValue: "",
      sourceSystem: "   ",
      note: "  nota  ",
    });
  });

  it("requires explicit null/text kinds and never infers NULL from an empty text scalar", async () => {
    const emptyText = baseForm();
    emptyText.set("identifierKindKind", "text");
    emptyText.set("identifierKind", "");
    emptyText.set("sourceSystemKind", "text");
    emptyText.set("sourceSystem", "");
    emptyText.set("noteKind", "text");
    emptyText.set("note", "");

    await expect(createPersistentRelatedIdentifierAction(emptyText)).rejects.toThrow(
      `REDIRECT:${PATH}?relatedIdentifierCreation=created`,
    );
    expect(actionMocks.createPersistentRelatedIdentifier).toHaveBeenCalledWith(
      expect.objectContaining({
        identifierKind: "",
        sourceSystem: "",
        note: "",
      }),
    );

    vi.clearAllMocks();
    actionMocks.readPersistentReadMode.mockReturnValue("persistent");
    actionMocks.isPersistentContractingId.mockReturnValue(true);
    const invalidKind = baseForm();
    invalidKind.set("noteKind", "missing");

    await expect(createPersistentRelatedIdentifierAction(invalidKind)).rejects.toThrow(
      `REDIRECT:${PATH}?relatedIdentifierCreation=unavailable&relatedIdentifierCandidate=${CANDIDATE}`,
    );
    expect(actionMocks.createPersistentRelatedIdentifier).not.toHaveBeenCalled();
  });

  it("fails closed on every duplicated approved scalar before F41", async () => {
    for (const field of [
      "contractingId",
      "relatedIdentifierId",
      "identifierKindKind",
      "identifierKind",
      "identifierValue",
      "sourceSystemKind",
      "sourceSystem",
      "noteKind",
      "note",
    ]) {
      vi.clearAllMocks();
      actionMocks.readPersistentReadMode.mockReturnValue("persistent");
      actionMocks.isPersistentContractingId.mockReturnValue(true);
      const form = baseForm();
      form.append(field, "FORGED-DUPLICATE");

      const expected =
        field === "contractingId"
          ? "REDIRECT:/"
          : field === "relatedIdentifierId"
            ? `REDIRECT:${PATH}?relatedIdentifierCreation=unavailable`
            : `REDIRECT:${PATH}?relatedIdentifierCreation=unavailable&relatedIdentifierCandidate=${CANDIDATE}`;

      await expect(createPersistentRelatedIdentifierAction(form)).rejects.toThrow(expected);
      expect(actionMocks.createPersistentRelatedIdentifier).not.toHaveBeenCalled();
      expect(actionMocks.revalidatePath).not.toHaveBeenCalled();
    }
  });

  it("rejects forged authority, lifecycle, timestamp and navigation fields", async () => {
    for (const field of [
      "teamId",
      "team_id",
      "actor",
      "actorMembershipId",
      "membershipId",
      "issuer",
      "subject",
      "eventId",
      "linkedAt",
      "unlinkedAt",
      "createdAt",
      "updatedAt",
      "callback",
      "callbackURL",
      "redirect",
      "url",
    ]) {
      vi.clearAllMocks();
      actionMocks.readPersistentReadMode.mockReturnValue("persistent");
      actionMocks.isPersistentContractingId.mockReturnValue(true);
      const form = baseForm();
      form.set(field, "FORGED");

      await expect(createPersistentRelatedIdentifierAction(form)).rejects.toThrow(
        `REDIRECT:${PATH}?relatedIdentifierCreation=unavailable&relatedIdentifierCandidate=${CANDIDATE}`,
      );
      expect(actionMocks.createPersistentRelatedIdentifier).not.toHaveBeenCalled();
      expect(actionMocks.revalidatePath).not.toHaveBeenCalled();
    }
  });

  it("allows only framework internal action fields in addition to the approved transport", async () => {
    const form = baseForm();
    form.set("$ACTION_ID_TEST", "framework-only");

    await expect(createPersistentRelatedIdentifierAction(form)).rejects.toThrow(
      `REDIRECT:${PATH}?relatedIdentifierCreation=created`,
    );
    expect(actionMocks.createPersistentRelatedIdentifier).toHaveBeenCalledTimes(1);
  });

  it("never reaches F41 in demo, invalid mode or with malformed UUID candidates", async () => {
    for (const mode of ["demo", "invalid"] as const) {
      vi.clearAllMocks();
      actionMocks.readPersistentReadMode.mockReturnValue(mode);
      await expect(createPersistentRelatedIdentifierAction(baseForm())).rejects.toThrow(
        "REDIRECT:/",
      );
      expect(actionMocks.createPersistentRelatedIdentifier).not.toHaveBeenCalled();
    }

    vi.clearAllMocks();
    actionMocks.readPersistentReadMode.mockReturnValue("persistent");
    actionMocks.isPersistentContractingId.mockImplementation(
      (value: string) => value === ID,
    );
    await expect(createPersistentRelatedIdentifierAction(baseForm())).rejects.toThrow(
      `REDIRECT:${PATH}?relatedIdentifierCreation=unavailable`,
    );
    expect(actionMocks.createPersistentRelatedIdentifier).not.toHaveBeenCalled();

    vi.clearAllMocks();
    actionMocks.readPersistentReadMode.mockReturnValue("persistent");
    actionMocks.isPersistentContractingId.mockReturnValue(false);
    await expect(createPersistentRelatedIdentifierAction(baseForm())).rejects.toThrow(
      "REDIRECT:/",
    );
    expect(actionMocks.createPersistentRelatedIdentifier).not.toHaveBeenCalled();
  });

  it("passes a valid browser-echoed candidate only as the F41 idempotency selector", async () => {
    actionMocks.createPersistentRelatedIdentifier.mockResolvedValue("not-available");

    await expect(createPersistentRelatedIdentifierAction(baseForm())).rejects.toThrow(
      `REDIRECT:${PATH}?relatedIdentifierCreation=not-available`,
    );

    expect(actionMocks.createPersistentRelatedIdentifier).toHaveBeenCalledWith(
      expect.objectContaining({
        contractingId: ID,
        relatedIdentifierId: CANDIDATE,
      }),
    );
    expect(actionMocks.revalidatePath).not.toHaveBeenCalled();
  });

  it("revalidates created and exact replay, starts a new intent after success, and preserves the candidate only for unavailable retry", async () => {
    for (const [result, expectedRedirect, shouldRevalidate] of [
      [
        "created",
        `REDIRECT:${PATH}?relatedIdentifierCreation=created`,
        true,
      ],
      [
        "already-linked",
        `REDIRECT:${PATH}?relatedIdentifierCreation=already-linked`,
        true,
      ],
      [
        "not-available",
        `REDIRECT:${PATH}?relatedIdentifierCreation=not-available`,
        false,
      ],
      [
        "unavailable",
        `REDIRECT:${PATH}?relatedIdentifierCreation=unavailable&relatedIdentifierCandidate=${CANDIDATE}`,
        false,
      ],
    ] as const) {
      vi.clearAllMocks();
      actionMocks.readPersistentReadMode.mockReturnValue("persistent");
      actionMocks.isPersistentContractingId.mockReturnValue(true);
      actionMocks.createPersistentRelatedIdentifier.mockResolvedValue(result);

      await expect(createPersistentRelatedIdentifierAction(baseForm())).rejects.toThrow(
        expectedRedirect,
      );

      if (shouldRevalidate) {
        expect(actionMocks.revalidatePath).toHaveBeenCalledTimes(1);
        expect(actionMocks.revalidatePath).toHaveBeenCalledWith(PATH);
      } else {
        expect(actionMocks.revalidatePath).not.toHaveBeenCalled();
      }
    }
  });

  it("sanitizes impossible outcomes and technical failures without leaking protected details", async () => {
    actionMocks.createPersistentRelatedIdentifier.mockResolvedValueOnce(
      "postgresql://private.invalid/claims=FORGED",
    );

    await expect(createPersistentRelatedIdentifierAction(baseForm())).rejects.toThrow(
      `REDIRECT:${PATH}?relatedIdentifierCreation=unavailable&relatedIdentifierCandidate=${CANDIDATE}`,
    );

    vi.clearAllMocks();
    actionMocks.readPersistentReadMode.mockReturnValue("persistent");
    actionMocks.isPersistentContractingId.mockReturnValue(true);
    actionMocks.createPersistentRelatedIdentifier.mockRejectedValueOnce(
      new Error("postgresql://secret-user:secret-pass@private.invalid/db claims=FORGED"),
    );

    await expect(createPersistentRelatedIdentifierAction(baseForm())).rejects.toThrow(
      `REDIRECT:${PATH}?relatedIdentifierCreation=unavailable&relatedIdentifierCandidate=${CANDIDATE}`,
    );

    const serialized = JSON.stringify(actionMocks.redirect.mock.calls);
    expect(serialized).not.toContain("secret-user");
    expect(serialized).not.toContain("private.invalid");
    expect(serialized).not.toContain("claims=FORGED");
    expect(actionMocks.revalidatePath).not.toHaveBeenCalled();
  });
});
