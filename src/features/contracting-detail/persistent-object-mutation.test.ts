import { beforeEach, describe, expect, it, vi } from "vitest";

const contextMocks = vi.hoisted(() => ({
  withTrustedDatabaseMutationContext: vi.fn(),
}));

vi.mock("server-only", () => ({}));
vi.mock("@/server/database/trusted-mutation-context", () => ({
  withTrustedDatabaseMutationContext: contextMocks.withTrustedDatabaseMutationContext,
}));

import { mutatePersistentContractingObject } from "./persistent-object-mutation";

const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

describe("mutatePersistentContractingObject", () => {
  const query = vi.fn();

  beforeEach(() => {
    vi.clearAllMocks();
    contextMocks.withTrustedDatabaseMutationContext.mockImplementation(
      async (operation: (db: { query: typeof query }) => Promise<unknown>) => operation({ query }),
    );
  });

  it("collapses malformed candidate IDs without entering trusted mutation context", async () => {
    await expect(
      mutatePersistentContractingObject({
        contractingId: "not-a-uuid",
        expectedObject: "DEMO old",
        newObject: "DEMO new",
      }),
    ).resolves.toBe("not-available");

    expect(contextMocks.withTrustedDatabaseMutationContext).not.toHaveBeenCalled();
    expect(query).not.toHaveBeenCalled();
  });

  it("passes only candidate/expected/new values verbatim and generates event UUID server-side", async () => {
    const contractingId = "32000000-0000-4000-8000-000000000001";
    const expectedObject = "  DEMO expected object  ";
    const newObject = "";
    query.mockResolvedValueOnce({ rows: [{ outcome: "updated" }] });

    const forgedCall = mutatePersistentContractingObject as unknown as (
      input: Record<string, unknown>,
    ) => ReturnType<typeof mutatePersistentContractingObject>;

    await expect(
      forgedCall({
        contractingId,
        expectedObject,
        newObject,
        eventId: "32000000-0000-4000-8000-000000009999",
        teamId: "32000000-0000-4000-8000-000000009998",
        actorMembershipId: "32000000-0000-4000-8000-000000009997",
        issuer: "FORGED-DEMO-ISSUER",
        subject: "FORGED-DEMO-SUBJECT",
      }),
    ).resolves.toBe("updated");

    expect(contextMocks.withTrustedDatabaseMutationContext).toHaveBeenCalledTimes(1);
    expect(query).toHaveBeenCalledTimes(1);

    const [sql, values] = query.mock.calls[0] as [string, unknown[]];
    expect(sql).toContain("public.mutate_contracting_object");
    expect(sql).toContain("$1::uuid");
    expect(sql).toContain("$2::text");
    expect(sql).toContain("$3::text");
    expect(sql).toContain("$4::uuid");
    expect(sql).not.toContain(contractingId);
    expect(sql).not.toContain("team_id");
    expect(sql).not.toContain("actor_membership_id");
    expect(values.slice(0, 3)).toEqual([contractingId, expectedObject, newObject]);
    expect(values[3]).toEqual(expect.stringMatching(UUID_PATTERN));
    expect(values[3]).not.toBe("32000000-0000-4000-8000-000000009999");
    expect(values).toHaveLength(4);
  });

  it("preserves updated/unchanged/conflict and hides denied existence", async () => {
    const input = {
      contractingId: "32000000-0000-4000-8000-000000000011",
      expectedObject: "DEMO expected",
      newObject: "DEMO new",
    } as const;

    query.mockResolvedValueOnce({ rows: [{ outcome: "updated" }] });
    await expect(mutatePersistentContractingObject(input)).resolves.toBe("updated");

    query.mockResolvedValueOnce({ rows: [{ outcome: "unchanged" }] });
    await expect(mutatePersistentContractingObject(input)).resolves.toBe("unchanged");

    query.mockResolvedValueOnce({ rows: [{ outcome: "conflict" }] });
    await expect(mutatePersistentContractingObject(input)).resolves.toBe("conflict");

    query.mockResolvedValueOnce({ rows: [{ outcome: "denied" }] });
    await expect(mutatePersistentContractingObject(input)).resolves.toBe("not-available");
  });

  it("fails closed on non-string scalar input or database/primitive failure", async () => {
    const invalidCall = mutatePersistentContractingObject as unknown as (
      input: Record<string, unknown>,
    ) => ReturnType<typeof mutatePersistentContractingObject>;

    await expect(
      invalidCall({
        contractingId: "32000000-0000-4000-8000-000000000021",
        expectedObject: null,
        newObject: "DEMO",
      }),
    ).resolves.toBe("unavailable");
    expect(contextMocks.withTrustedDatabaseMutationContext).not.toHaveBeenCalled();

    contextMocks.withTrustedDatabaseMutationContext.mockRejectedValueOnce(
      new Error("postgresql://detail-that-must-not-escape.example.invalid/private"),
    );

    await expect(
      mutatePersistentContractingObject({
        contractingId: "32000000-0000-4000-8000-000000000022",
        expectedObject: "DEMO old",
        newObject: "DEMO new",
      }),
    ).resolves.toBe("unavailable");
  });
});
