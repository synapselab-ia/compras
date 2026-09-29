import { beforeEach, describe, expect, it, vi } from "vitest";

const actionMocks = vi.hoisted(() => ({
  readPersistentReadMode: vi.fn(),
  isPersistentContractingId: vi.fn(),
  createPersistentManualTimelineNote: vi.fn(),
  mutatePersistentContractingNextAction: vi.fn(),
  mutatePersistentContractingObject: vi.fn(),
  revalidatePath: vi.fn(),
  redirect: vi.fn((url: string) => { throw new Error(`REDIRECT:${url}`); }),
}));

vi.mock("next/cache", () => ({ revalidatePath: actionMocks.revalidatePath }));
vi.mock("next/navigation", () => ({ redirect: actionMocks.redirect }));
vi.mock("@/server/persistent-read-mode", () => ({ readPersistentReadMode: actionMocks.readPersistentReadMode }));
vi.mock("./persistent-read", () => ({ isPersistentContractingId: actionMocks.isPersistentContractingId }));
vi.mock("./persistent-manual-timeline-note-create", () => ({
  createPersistentManualTimelineNote: actionMocks.createPersistentManualTimelineNote,
}));
vi.mock("./persistent-mutation", () => ({ mutatePersistentContractingNextAction: actionMocks.mutatePersistentContractingNextAction }));
vi.mock("./persistent-object-mutation", () => ({ mutatePersistentContractingObject: actionMocks.mutatePersistentContractingObject }));

import { createPersistentManualTimelineNoteAction } from "./actions";

const ID = "45000000-0000-4000-8000-000000000001";
const EVENT = "45010000-0000-4000-8000-000000000001";
const PATH = `/contratacoes/${ID}`;

function form(noteKind = "text", note: string | undefined = "  DEMO nota  "): FormData {
  const data = new FormData();
  data.set("contractingId", ID);
  data.set("eventId", EVENT);
  data.set("noteKind", noteKind);
  if (note !== undefined) data.set("note", note);
  return data;
}

describe("createPersistentManualTimelineNoteAction", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    actionMocks.readPersistentReadMode.mockReturnValue("persistent");
    actionMocks.isPersistentContractingId.mockReturnValue(true);
    actionMocks.createPersistentManualTimelineNote.mockResolvedValue("created");
  });

  it("forwards only the F44 boundary payload and preserves text exactly", async () => {
    await expect(createPersistentManualTimelineNoteAction(form())).rejects.toThrow(
      `REDIRECT:${PATH}?manualNoteCreation=created`,
    );
    expect(actionMocks.createPersistentManualTimelineNote).toHaveBeenCalledWith({
      contractingId: ID,
      eventId: EVENT,
      note: "  DEMO nota  ",
    });
    expect(actionMocks.revalidatePath).toHaveBeenCalledWith(PATH);
  });

  it("keeps NULL, empty, spaces-only and leading/trailing spaces distinct", async () => {
    await expect(createPersistentManualTimelineNoteAction(form("null", undefined))).rejects.toThrow(
      `REDIRECT:${PATH}?manualNoteCreation=created`,
    );
    expect(actionMocks.createPersistentManualTimelineNote).toHaveBeenLastCalledWith(
      expect.objectContaining({ note: null }),
    );

    vi.clearAllMocks();
    actionMocks.readPersistentReadMode.mockReturnValue("persistent");
    actionMocks.isPersistentContractingId.mockReturnValue(true);
    actionMocks.createPersistentManualTimelineNote.mockResolvedValue("created");
    await expect(createPersistentManualTimelineNoteAction(form("text", ""))).rejects.toThrow();
    expect(actionMocks.createPersistentManualTimelineNote).toHaveBeenLastCalledWith(
      expect.objectContaining({ note: "" }),
    );

    vi.clearAllMocks();
    actionMocks.readPersistentReadMode.mockReturnValue("persistent");
    actionMocks.isPersistentContractingId.mockReturnValue(true);
    actionMocks.createPersistentManualTimelineNote.mockResolvedValue("created");
    await expect(createPersistentManualTimelineNoteAction(form("text", "   "))).rejects.toThrow();
    expect(actionMocks.createPersistentManualTimelineNote).toHaveBeenLastCalledWith(
      expect.objectContaining({ note: "   " }),
    );

    vi.clearAllMocks();
    actionMocks.readPersistentReadMode.mockReturnValue("persistent");
    actionMocks.isPersistentContractingId.mockReturnValue(true);
    actionMocks.createPersistentManualTimelineNote.mockResolvedValue("created");
    await expect(createPersistentManualTimelineNoteAction(form("text", "  DEMO  "))).rejects.toThrow();
    expect(actionMocks.createPersistentManualTimelineNote).toHaveBeenLastCalledWith(
      expect.objectContaining({ note: "  DEMO  " }),
    );
  });

  it("accepts one ignored note scalar for explicit NULL without converting it to text", async () => {
    await expect(createPersistentManualTimelineNoteAction(form("null", "ignored"))).rejects.toThrow(
      `REDIRECT:${PATH}?manualNoteCreation=created`,
    );
    expect(actionMocks.createPersistentManualTimelineNote).toHaveBeenCalledWith({
      contractingId: ID,
      eventId: EVENT,
      note: null,
    });
  });

  it("fails closed on duplicate or forged fields before F44", async () => {
    for (const field of [
      "eventId",
      "noteKind",
      "note",
      "teamId",
      "actor",
      "membershipId",
      "issuer",
      "subject",
      "event_type",
      "occurredAt",
      "field_key",
      "old_value",
      "new_value",
      "itemId",
      "relatedIdentifierId",
      "callback",
      "redirect",
    ]) {
      vi.clearAllMocks();
      actionMocks.readPersistentReadMode.mockReturnValue("persistent");
      actionMocks.isPersistentContractingId.mockReturnValue(true);
      const data = form();
      data.append(field, "FORGED");
      await expect(createPersistentManualTimelineNoteAction(data)).rejects.toThrow();
      expect(actionMocks.createPersistentManualTimelineNote).not.toHaveBeenCalled();
    }
  });

  it("fails closed on invalid nullable transport before F44", async () => {
    await expect(createPersistentManualTimelineNoteAction(form("invalid", "DEMO"))).rejects.toThrow(
      `REDIRECT:${PATH}?manualNoteCreation=unavailable&manualNoteCandidate=${EVENT}`,
    );
    expect(actionMocks.createPersistentManualTimelineNote).not.toHaveBeenCalled();

    vi.clearAllMocks();
    actionMocks.readPersistentReadMode.mockReturnValue("persistent");
    actionMocks.isPersistentContractingId.mockReturnValue(true);
    await expect(createPersistentManualTimelineNoteAction(form("text", undefined))).rejects.toThrow(
      `REDIRECT:${PATH}?manualNoteCreation=unavailable&manualNoteCandidate=${EVENT}`,
    );
    expect(actionMocks.createPersistentManualTimelineNote).not.toHaveBeenCalled();
  });

  it("never calls F44 outside persistent mode", async () => {
    actionMocks.readPersistentReadMode.mockReturnValue("demo");
    await expect(createPersistentManualTimelineNoteAction(form())).rejects.toThrow("REDIRECT:/");
    expect(actionMocks.createPersistentManualTimelineNote).not.toHaveBeenCalled();
  });

  it("rejects malformed contracting and event candidates before F44", async () => {
    actionMocks.isPersistentContractingId.mockReturnValue(false);
    await expect(createPersistentManualTimelineNoteAction(form())).rejects.toThrow("REDIRECT:/");
    expect(actionMocks.createPersistentManualTimelineNote).not.toHaveBeenCalled();

    vi.clearAllMocks();
    actionMocks.readPersistentReadMode.mockReturnValue("persistent");
    actionMocks.isPersistentContractingId
      .mockReturnValueOnce(true)
      .mockReturnValueOnce(false);
    await expect(createPersistentManualTimelineNoteAction(form())).rejects.toThrow(
      `REDIRECT:${PATH}?manualNoteCreation=unavailable`,
    );
    expect(actionMocks.createPersistentManualTimelineNote).not.toHaveBeenCalled();
  });

  it("preserves the candidate only for technical unavailable", async () => {
    actionMocks.createPersistentManualTimelineNote.mockResolvedValue("unavailable");
    await expect(createPersistentManualTimelineNoteAction(form())).rejects.toThrow(
      `REDIRECT:${PATH}?manualNoteCreation=unavailable&manualNoteCandidate=${EVENT}`,
    );
    expect(actionMocks.revalidatePath).not.toHaveBeenCalled();

    vi.clearAllMocks();
    actionMocks.readPersistentReadMode.mockReturnValue("persistent");
    actionMocks.isPersistentContractingId.mockReturnValue(true);
    actionMocks.createPersistentManualTimelineNote.mockResolvedValue("not-available");
    await expect(createPersistentManualTimelineNoteAction(form())).rejects.toThrow(
      `REDIRECT:${PATH}?manualNoteCreation=not-available`,
    );
    expect(actionMocks.revalidatePath).not.toHaveBeenCalled();
  });

  it("treats already-added as completed idempotent success", async () => {
    actionMocks.createPersistentManualTimelineNote.mockResolvedValue("already-added");
    await expect(createPersistentManualTimelineNoteAction(form())).rejects.toThrow(
      `REDIRECT:${PATH}?manualNoteCreation=already-added`,
    );
    expect(actionMocks.revalidatePath).toHaveBeenCalledWith(PATH);
  });

  it("does not expose impossible or thrown boundary results", async () => {
    actionMocks.createPersistentManualTimelineNote.mockResolvedValue("secret-result");
    await expect(createPersistentManualTimelineNoteAction(form())).rejects.toThrow(
      `REDIRECT:${PATH}?manualNoteCreation=unavailable&manualNoteCandidate=${EVENT}`,
    );

    vi.clearAllMocks();
    actionMocks.readPersistentReadMode.mockReturnValue("persistent");
    actionMocks.isPersistentContractingId.mockReturnValue(true);
    actionMocks.createPersistentManualTimelineNote.mockRejectedValue(
      new Error("postgresql://secret@host/db SQL claims=secret"),
    );
    await expect(createPersistentManualTimelineNoteAction(form())).rejects.toThrow(
      `REDIRECT:${PATH}?manualNoteCreation=unavailable&manualNoteCandidate=${EVENT}`,
    );
  });
});
