import { beforeEach, describe, expect, it, vi } from "vitest";

const contextMocks = vi.hoisted(() => ({
  withTrustedDatabaseMutationContext: vi.fn(),
}));

vi.mock("server-only", () => ({}));
vi.mock("@/server/database/trusted-mutation-context", () => ({
  withTrustedDatabaseMutationContext: contextMocks.withTrustedDatabaseMutationContext,
}));

import { mutatePersistentContractingResponsible } from "./persistent-responsible-mutation";

const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

const BASE_INPUT = {
  contractingId: "47040000-0000-4000-8000-000000000001",
  expectedResponsibleMembershipId: null,
  newResponsibleMembershipId: "47030000-0000-4000-8000-000000000001",
} as const;

describe("persistent contracting responsible mutation adapter", () => {
  const query = vi.fn();

  beforeEach(() => {
    vi.clearAllMocks();
    contextMocks.withTrustedDatabaseMutationContext.mockImplementation(
      async (operation: (db: { query: typeof query }) => Promise<unknown>) =>
        operation({ query }),
    );
  });

  it("rejects malformed selector and candidate UUIDs before trusted execution", async () => {
    await expect(
      mutatePersistentContractingResponsible({ ...BASE_INPUT, contractingId: "bad" }),
    ).resolves.toBe("not-available");
    await expect(
      mutatePersistentContractingResponsible({
        ...BASE_INPUT,
        expectedResponsibleMembershipId: "bad",
      }),
    ).resolves.toBe("not-available");
    await expect(
      mutatePersistentContractingResponsible({
        ...BASE_INPUT,
        newResponsibleMembershipId: "bad",
      }),
    ).resolves.toBe("not-available");

    expect(contextMocks.withTrustedDatabaseMutationContext).not.toHaveBeenCalled();
    expect(query).not.toHaveBeenCalled();
  });

  it("passes only candidate values and generates event UUID server-side", async () => {
    query.mockResolvedValueOnce({ rows: [{ outcome: "updated" }] });

    const forgedCall = mutatePersistentContractingResponsible as unknown as (
      input: Record<string, unknown>,
    ) => ReturnType<typeof mutatePersistentContractingResponsible>;

    await expect(
      forgedCall({
        ...BASE_INPUT,
        teamId: "47010000-0000-4000-8000-000000009999",
        actorMembershipId: "47030000-0000-4000-8000-000000009999",
        issuer: "FORGED-DEMO",
        subject: "FORGED-DEMO",
        eventId: "47050000-0000-4000-8000-000000009999",
      }),
    ).resolves.toBe("updated");

    const [sql, values] = query.mock.calls[0] as [string, unknown[]];
    expect(sql).toContain("public.mutate_contracting_responsible");
    expect(sql).not.toContain("team_id");
    expect(sql).not.toContain("actor_membership_id");
    expect(values.slice(0, 3)).toEqual([
      BASE_INPUT.contractingId,
      BASE_INPUT.expectedResponsibleMembershipId,
      BASE_INPUT.newResponsibleMembershipId,
    ]);
    expect(values[3]).toEqual(expect.stringMatching(UUID_PATTERN));
    expect(values[3]).not.toBe("47050000-0000-4000-8000-000000009999");
    expect(values).toHaveLength(4);
  });

  it("preserves null as a real expected and new state", async () => {
    query.mockResolvedValueOnce({ rows: [{ outcome: "updated" }] });
    await expect(
      mutatePersistentContractingResponsible({
        contractingId: BASE_INPUT.contractingId,
        expectedResponsibleMembershipId:
          "47030000-0000-4000-8000-000000000001",
        newResponsibleMembershipId: null,
      }),
    ).resolves.toBe("updated");

    const values = query.mock.calls[0]?.[1] as unknown[];
    expect(values[1]).toBe("47030000-0000-4000-8000-000000000001");
    expect(values[2]).toBeNull();
  });

  it("maps approved outcomes and hides denied state", async () => {
    for (const outcome of ["updated", "unchanged", "conflict"] as const) {
      query.mockResolvedValueOnce({ rows: [{ outcome }] });
      await expect(mutatePersistentContractingResponsible(BASE_INPUT)).resolves.toBe(outcome);
    }

    query.mockResolvedValueOnce({ rows: [{ outcome: "denied" }] });
    await expect(mutatePersistentContractingResponsible(BASE_INPUT)).resolves.toBe("not-available");

    query.mockResolvedValueOnce({ rows: [{ outcome: "unexpected" }] });
    await expect(mutatePersistentContractingResponsible(BASE_INPUT)).resolves.toBe("unavailable");
  });

  it("fails closed on non-string IDs and technical failure", async () => {
    const invalidCall = mutatePersistentContractingResponsible as unknown as (
      input: Record<string, unknown>,
    ) => ReturnType<typeof mutatePersistentContractingResponsible>;

    await expect(
      invalidCall({ ...BASE_INPUT, newResponsibleMembershipId: 123 }),
    ).resolves.toBe("unavailable");
    expect(contextMocks.withTrustedDatabaseMutationContext).not.toHaveBeenCalled();

    contextMocks.withTrustedDatabaseMutationContext.mockRejectedValueOnce(
      new Error("protected database failure"),
    );
    await expect(mutatePersistentContractingResponsible(BASE_INPUT)).resolves.toBe("unavailable");
  });
});
