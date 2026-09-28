import { beforeEach, describe, expect, it, vi } from "vitest";

const contextMocks = vi.hoisted(() => ({
  withTrustedDatabaseMutationContext: vi.fn(),
}));

vi.mock("server-only", () => ({}));
vi.mock("@/server/database/trusted-mutation-context", () => ({
  withTrustedDatabaseMutationContext: contextMocks.withTrustedDatabaseMutationContext,
}));

import {
  createPersistentManualTimelineNote,
  preparePersistentManualTimelineNoteEventId,
} from "./persistent-manual-timeline-note-create";

const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

const BASE_INPUT = {
  contractingId: "44040000-0000-4000-8000-000000000001",
  eventId: "44060000-0000-4000-8000-000000000001",
  note: "  DEMO manual timeline note  ",
} as const;

describe("persistent manual timeline note create adapter", () => {
  const query = vi.fn();

  beforeEach(() => {
    vi.clearAllMocks();
    contextMocks.withTrustedDatabaseMutationContext.mockImplementation(
      async (operation: (db: { query: typeof query }) => Promise<unknown>) => operation({ query }),
    );
  });

  it("prepares stable-format opaque event UUIDs without granting authority", () => {
    const first = preparePersistentManualTimelineNoteEventId();
    const second = preparePersistentManualTimelineNoteEventId();

    expect(first).toMatch(UUID_PATTERN);
    expect(second).toMatch(UUID_PATTERN);
    expect(second).not.toBe(first);
  });

  it("rejects malformed technical UUID candidates before trusted execution", async () => {
    await expect(
      createPersistentManualTimelineNote({
        ...BASE_INPUT,
        contractingId: "not-a-uuid",
      }),
    ).resolves.toBe("unavailable");

    await expect(
      createPersistentManualTimelineNote({
        ...BASE_INPUT,
        eventId: "not-a-uuid",
      }),
    ).resolves.toBe("unavailable");

    expect(contextMocks.withTrustedDatabaseMutationContext).not.toHaveBeenCalled();
    expect(query).not.toHaveBeenCalled();
  });

  it("passes only contractingId, prepared eventId and note", async () => {
    query.mockResolvedValueOnce({ rows: [{ outcome: "created" }] });

    const forgedCall = createPersistentManualTimelineNote as unknown as (
      input: Record<string, unknown>,
    ) => ReturnType<typeof createPersistentManualTimelineNote>;

    await expect(
      forgedCall({
        ...BASE_INPUT,
        teamId: "44010000-0000-4000-8000-000000009999",
        actorMembershipId: "44030000-0000-4000-8000-000000009999",
        membershipId: "44030000-0000-4000-8000-000000009998",
        issuer: "https://attacker.invalid",
        subject: "FORGED-DEMO-SUBJECT",
        eventType: "forged",
        occurredAt: "2026-01-01T00:00:00Z",
        createdAt: "2026-01-01T00:00:00Z",
        fieldKey: "forged",
        oldValue: "forged",
        newValue: "forged",
        relatedIdentifierId: "44050000-0000-4000-8000-000000009999",
        itemId: "44070000-0000-4000-8000-000000009999",
      }),
    ).resolves.toBe("created");

    expect(contextMocks.withTrustedDatabaseMutationContext).toHaveBeenCalledTimes(1);
    expect(query).toHaveBeenCalledTimes(1);

    const [sql, values] = query.mock.calls[0] as [string, unknown[]];

    expect(sql).toContain("public.create_manual_timeline_note");
    expect(sql).toContain("$1::uuid");
    expect(sql).toContain("$2::uuid");
    expect(sql).toContain("$3::text");
    expect(sql).not.toContain(BASE_INPUT.contractingId);
    expect(sql).not.toContain("team_id");
    expect(sql).not.toContain("actor_membership_id");

    expect(values).toEqual([
      BASE_INPUT.contractingId,
      BASE_INPUT.eventId,
      BASE_INPUT.note,
    ]);
  });

  it("preserves null, empty, spaces-only and leading or trailing spaces exactly", async () => {
    for (const note of [null, "", "   ", "  note  "] as const) {
      query.mockResolvedValueOnce({ rows: [{ outcome: "created" }] });

      await expect(
        createPersistentManualTimelineNote({
          contractingId: BASE_INPUT.contractingId,
          eventId: BASE_INPUT.eventId,
          note,
        }),
      ).resolves.toBe("created");

      const values = query.mock.calls.at(-1)?.[1] as unknown[];
      expect(values[2]).toBe(note);
    }
  });

  it("maps created, exact replay and protected denial to approved external outcomes", async () => {
    query.mockResolvedValueOnce({ rows: [{ outcome: "created" }] });
    await expect(createPersistentManualTimelineNote(BASE_INPUT)).resolves.toBe("created");

    query.mockResolvedValueOnce({ rows: [{ outcome: "already-added" }] });
    await expect(createPersistentManualTimelineNote(BASE_INPUT)).resolves.toBe("already-added");

    query.mockResolvedValueOnce({ rows: [{ outcome: "denied" }] });
    await expect(createPersistentManualTimelineNote(BASE_INPUT)).resolves.toBe("not-available");
  });

  it("sanitizes impossible outcomes and technical failures without demo fallback", async () => {
    query.mockResolvedValueOnce({ rows: [{ outcome: "internal-detail" }] });
    await expect(createPersistentManualTimelineNote(BASE_INPUT)).resolves.toBe("unavailable");

    contextMocks.withTrustedDatabaseMutationContext.mockRejectedValueOnce(
      new Error("postgresql://secret-that-must-not-escape.example.invalid/private"),
    );
    await expect(createPersistentManualTimelineNote(BASE_INPUT)).resolves.toBe("unavailable");
  });

  it("fails closed on malformed note type before database execution", async () => {
    const invalidCall = createPersistentManualTimelineNote as unknown as (
      input: Record<string, unknown>,
    ) => ReturnType<typeof createPersistentManualTimelineNote>;

    for (const note of [7, false, [], {}]) {
      await expect(invalidCall({ ...BASE_INPUT, note })).resolves.toBe("unavailable");
    }

    expect(contextMocks.withTrustedDatabaseMutationContext).not.toHaveBeenCalled();
    expect(query).not.toHaveBeenCalled();
  });
});
