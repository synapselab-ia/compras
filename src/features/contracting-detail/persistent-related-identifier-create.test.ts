import { beforeEach, describe, expect, it, vi } from "vitest";

const contextMocks = vi.hoisted(() => ({
  withTrustedDatabaseMutationContext: vi.fn(),
}));

vi.mock("server-only", () => ({}));
vi.mock("@/server/database/trusted-mutation-context", () => ({
  withTrustedDatabaseMutationContext: contextMocks.withTrustedDatabaseMutationContext,
}));

import {
  createPersistentRelatedIdentifier,
  preparePersistentRelatedIdentifierCandidateId,
} from "./persistent-related-identifier-create";

const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

const BASE_INPUT = {
  contractingId: "41040000-0000-4000-8000-000000000001",
  relatedIdentifierId: "41050000-0000-4000-8000-000000000001",
  identifierKind: "  DEMO kind  ",
  identifierValue: "  DEMO identifier  ",
  sourceSystem: "  DEMO source  ",
  note: "  DEMO note  ",
} as const;

describe("persistent related identifier create adapter", () => {
  const query = vi.fn();

  beforeEach(() => {
    vi.clearAllMocks();
    contextMocks.withTrustedDatabaseMutationContext.mockImplementation(
      async (operation: (db: { query: typeof query }) => Promise<unknown>) => operation({ query }),
    );
  });

  it("prepares stable-format opaque UUID candidates without granting authority", () => {
    const first = preparePersistentRelatedIdentifierCandidateId();
    const second = preparePersistentRelatedIdentifierCandidateId();

    expect(first).toMatch(UUID_PATTERN);
    expect(second).toMatch(UUID_PATTERN);
    expect(second).not.toBe(first);
  });

  it("rejects malformed technical UUID candidates before trusted execution", async () => {
    await expect(
      createPersistentRelatedIdentifier({
        ...BASE_INPUT,
        contractingId: "not-a-uuid",
      }),
    ).resolves.toBe("unavailable");

    await expect(
      createPersistentRelatedIdentifier({
        ...BASE_INPUT,
        relatedIdentifierId: "not-a-uuid",
      }),
    ).resolves.toBe("unavailable");

    expect(contextMocks.withTrustedDatabaseMutationContext).not.toHaveBeenCalled();
    expect(query).not.toHaveBeenCalled();
  });

  it("passes only the six approved request fields and generates event UUID server-side", async () => {
    query.mockResolvedValueOnce({ rows: [{ outcome: "created" }] });

    const forgedCall = createPersistentRelatedIdentifier as unknown as (
      input: Record<string, unknown>,
    ) => ReturnType<typeof createPersistentRelatedIdentifier>;

    await expect(
      forgedCall({
        ...BASE_INPUT,
        teamId: "41010000-0000-4000-8000-000000009999",
        actorMembershipId: "41030000-0000-4000-8000-000000009999",
        membershipId: "41030000-0000-4000-8000-000000009998",
        issuer: "https://attacker.invalid",
        subject: "FORGED-DEMO-SUBJECT",
        linkedAt: "2026-01-01T00:00:00Z",
        unlinkedAt: "2026-01-02T00:00:00Z",
        eventId: "41060000-0000-4000-8000-000000009999",
      }),
    ).resolves.toBe("created");

    expect(contextMocks.withTrustedDatabaseMutationContext).toHaveBeenCalledTimes(1);
    expect(query).toHaveBeenCalledTimes(1);

    const [sql, values] = query.mock.calls[0] as [string, unknown[]];

    expect(sql).toContain("public.create_related_identifier");
    expect(sql).toContain("$1::uuid");
    expect(sql).toContain("$7::uuid");
    expect(sql).not.toContain(BASE_INPUT.contractingId);
    expect(sql).not.toContain("team_id");
    expect(sql).not.toContain("actor_membership_id");

    expect(values.slice(0, 6)).toEqual([
      BASE_INPUT.contractingId,
      BASE_INPUT.relatedIdentifierId,
      BASE_INPUT.identifierKind,
      BASE_INPUT.identifierValue,
      BASE_INPUT.sourceSystem,
      BASE_INPUT.note,
    ]);
    expect(values[6]).toEqual(expect.stringMatching(UUID_PATTERN));
    expect(values[6]).not.toBe("41060000-0000-4000-8000-000000009999");
    expect(values).toHaveLength(7);
  });

  it("preserves null, empty, spaces-only and leading or trailing spaces exactly", async () => {
    query.mockResolvedValueOnce({ rows: [{ outcome: "created" }] });

    await expect(
      createPersistentRelatedIdentifier({
        contractingId: BASE_INPUT.contractingId,
        relatedIdentifierId: BASE_INPUT.relatedIdentifierId,
        identifierKind: null,
        identifierValue: "",
        sourceSystem: "   ",
        note: "  note  ",
      }),
    ).resolves.toBe("created");

    const values = query.mock.calls[0]?.[1] as unknown[];
    expect(values.slice(2, 6)).toEqual([null, "", "   ", "  note  "]);
  });

  it("maps created, exact replay and protected denial to approved external outcomes", async () => {
    query.mockResolvedValueOnce({ rows: [{ outcome: "created" }] });
    await expect(createPersistentRelatedIdentifier(BASE_INPUT)).resolves.toBe("created");

    query.mockResolvedValueOnce({ rows: [{ outcome: "already-linked" }] });
    await expect(createPersistentRelatedIdentifier(BASE_INPUT)).resolves.toBe("already-linked");

    query.mockResolvedValueOnce({ rows: [{ outcome: "denied" }] });
    await expect(createPersistentRelatedIdentifier(BASE_INPUT)).resolves.toBe("not-available");
  });

  it("sanitizes impossible outcomes and technical failures without demo fallback", async () => {
    query.mockResolvedValueOnce({ rows: [{ outcome: "internal-detail" }] });
    await expect(createPersistentRelatedIdentifier(BASE_INPUT)).resolves.toBe("unavailable");

    contextMocks.withTrustedDatabaseMutationContext.mockRejectedValueOnce(
      new Error("postgresql://secret-that-must-not-escape.example.invalid/private"),
    );
    await expect(createPersistentRelatedIdentifier(BASE_INPUT)).resolves.toBe("unavailable");
  });

  it("fails closed on malformed text/nullability types before database execution", async () => {
    const invalidCall = createPersistentRelatedIdentifier as unknown as (
      input: Record<string, unknown>,
    ) => ReturnType<typeof createPersistentRelatedIdentifier>;

    for (const patch of [
      { identifierKind: 7 },
      { identifierValue: null },
      { identifierValue: 42 },
      { sourceSystem: false },
      { note: [] },
    ]) {
      await expect(invalidCall({ ...BASE_INPUT, ...patch })).resolves.toBe("unavailable");
    }

    expect(contextMocks.withTrustedDatabaseMutationContext).not.toHaveBeenCalled();
    expect(query).not.toHaveBeenCalled();
  });
});
