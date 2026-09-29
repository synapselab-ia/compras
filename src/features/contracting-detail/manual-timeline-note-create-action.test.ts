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

function form(noteKind = "text", note = "  DEMO nota  "): FormData {
  const data = new FormData();
  data.set("contractingId", ID);
  data.set("eventId", EVENT);
  data.set("noteKind", noteKind);
  data.set("note", note);
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

  it("keeps NULL, empty and spaces-only distinct", async () => {
    await expect(createPersistentManualTimelineNoteAction(form("null", "ignored"))).rejects.toThrow();
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
  });

  it("fails closed on duplicate or forged fields before F44", async () => {
    for (const field of ["eventId", "noteKind", "note", "teamId", "actor", "event_type", "callback"]) {
      vi.clearAllMocks();
      actionMocks.readPersistentReadMode.mockReturnValue("persistent");
      actionMocks.isPersistentContractingId.mockReturnValue(true);
      const data = form();
      data.append(field, "FORGED");
      await expect(createPersistentManualTimelineNoteAction(data)).rejects.toThrow();
      expect(actionMocks.createPersistentManualTimelineNote).not.toHaveBeenCalled();
    }
  });

  it("preserves the candidate only for technical unavailable", async () => {
    actionMocks.createPersistentManualTimelineNote.mockResolvedValue("unavailable");
    await expect(createPersistentManualTimelineNoteAction(form())).rejects.toThrow(
      `REDIRECT:${PATH}?manualNoteCreation=unavailable&manualNoteCandidate=${EVENT}`,
    );

    actionMocks.createPersistentManualTimelineNote.mockResolvedValue("not-available");
    await expect(createPersistentManualTimelineNoteAction(form())).rejects.toThrow(
      `REDIRECT:${PATH}?manualNoteCreation=not-available`,
    );
  });

  it("does not expose impossible or thrown boundary results", async () => {
    actionMocks.createPersistentManualTimelineNote.mockResolvedValue("secret-result");
    await expect(createPersistentManualTimelineNoteAction(form())).rejects.toThrow(
      `REDIRECT:${PATH}?manualNoteCreation=unavailable&manualNoteCandidate=${EVENT}`,
    );
  });
});
