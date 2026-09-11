import { beforeEach, describe, expect, it, vi } from "vitest";

const contextMocks = vi.hoisted(() => ({
  withTrustedDatabaseMutationContext: vi.fn(),
}));

vi.mock("server-only", () => ({}));
vi.mock("@/server/database/trusted-mutation-context", () => ({
  withTrustedDatabaseMutationContext: contextMocks.withTrustedDatabaseMutationContext,
}));

import { mutatePersistentContractingNextAction } from "./persistent-mutation";

const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

describe("mutatePersistentContractingNextAction", () => {
  const query = vi.fn();

  beforeEach(() => {
    vi.clearAllMocks();
    contextMocks.withTrustedDatabaseMutationContext.mockImplementation(
      async (operation: (db: { query: typeof query }) => Promise<unknown>) => operation({ query }),
    );
  });

  it("collapses malformed candidate IDs without entering the trusted mutation context", async () => {
    await expect(
      mutatePersistentContractingNextAction({
        contractingId: "not-a-uuid",
        expectedNextAction: null,
        newNextAction: "DEMO next",
      }),
    ).resolves.toBe("not-available");

    expect(contextMocks.withTrustedDatabaseMutationContext).not.toHaveBeenCalled();
    expect(query).not.toHaveBeenCalled();
  });

  it("passes only candidate/expected/new values and generates the event UUID server-side", async () => {
    const contractingId = "26000000-0000-4000-8000-000000000001";
    query.mockResolvedValueOnce({ rows: [{ outcome: "updated" }] });

    const forgedCall = mutatePersistentContractingNextAction as unknown as (
      input: Record<string, unknown>,
    ) => ReturnType<typeof mutatePersistentContractingNextAction>;

    await expect(
      forgedCall({
        contractingId,
        expectedNextAction: null,
        newNextAction: "  DEMO next action preserved verbatim  ",
        eventId: "26000000-0000-4000-8000-000000009999",
        teamId: "26000000-0000-4000-8000-000000009998",
        actorMembershipId: "26000000-0000-4000-8000-000000009997",
        subject: "FORGED-DEMO-SUBJECT",
      }),
    ).resolves.toBe("updated");

    expect(contextMocks.withTrustedDatabaseMutationContext).toHaveBeenCalledTimes(1);
    expect(query).toHaveBeenCalledTimes(1);

    const [sql, values] = query.mock.calls[0] as [string, unknown[]];
    expect(sql).toContain("public.mutate_contracting_next_action");
    expect(sql).toContain("$1::uuid");
    expect(sql).toContain("$2::text");
    expect(sql).toContain("$3::text");
    expect(sql).toContain("$4::uuid");
    expect(sql).not.toContain(contractingId);
    expect(sql).not.toContain("team_id");
    expect(sql).not.toContain("actor_membership_id");
    expect(values.slice(0, 3)).toEqual([
      contractingId,
      null,
      "  DEMO next action preserved verbatim  ",
    ]);
    expect(values[3]).toEqual(expect.stringMatching(UUID_PATTERN));
    expect(values[3]).not.toBe("26000000-0000-4000-8000-000000009999");
    expect(values).toHaveLength(4);
  });

  it("preserves authorized no-op/conflict semantics and hides denied existence", async () => {
    const baseInput = {
      contractingId: "26000000-0000-4000-8000-000000000011",
      expectedNextAction: "DEMO expected",
      newNextAction: "DEMO new",
    } as const;

    query.mockResolvedValueOnce({ rows: [{ outcome: "unchanged" }] });
    await expect(mutatePersistentContractingNextAction(baseInput)).resolves.toBe("unchanged");

    query.mockResolvedValueOnce({ rows: [{ outcome: "conflict" }] });
    await expect(mutatePersistentContractingNextAction(baseInput)).resolves.toBe("conflict");

    query.mockResolvedValueOnce({ rows: [{ outcome: "denied" }] });
    await expect(mutatePersistentContractingNextAction(baseInput)).resolves.toBe("not-available");
  });

  it("fails closed on malformed scalar input or database/primitive failure", async () => {
    const invalidCall = mutatePersistentContractingNextAction as unknown as (
      input: Record<string, unknown>,
    ) => ReturnType<typeof mutatePersistentContractingNextAction>;

    await expect(
      invalidCall({
        contractingId: "26000000-0000-4000-8000-000000000021",
        expectedNextAction: undefined,
        newNextAction: "DEMO",
      }),
    ).resolves.toBe("unavailable");
    expect(contextMocks.withTrustedDatabaseMutationContext).not.toHaveBeenCalled();

    contextMocks.withTrustedDatabaseMutationContext.mockRejectedValueOnce(
      new Error("postgresql://detail-that-must-not-escape.example.invalid/private"),
    );

    await expect(
      mutatePersistentContractingNextAction({
        contractingId: "26000000-0000-4000-8000-000000000022",
        expectedNextAction: "DEMO old",
        newNextAction: "DEMO new",
      }),
    ).resolves.toBe("unavailable");
  });
});
