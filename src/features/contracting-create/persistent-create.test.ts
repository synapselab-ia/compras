import { beforeEach, describe, expect, it, vi } from "vitest";

const contextMocks = vi.hoisted(() => ({
  withTrustedDatabaseMutationContext: vi.fn(),
}));

vi.mock("server-only", () => ({}));
vi.mock("@/server/database/trusted-mutation-context", () => ({
  withTrustedDatabaseMutationContext: contextMocks.withTrustedDatabaseMutationContext,
}));

import {
  createPersistentContracting,
  preparePersistentContractingCandidateId,
} from "./persistent-create";

const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

describe("persistent contracting create adapter", () => {
  const query = vi.fn();

  beforeEach(() => {
    vi.clearAllMocks();
    contextMocks.withTrustedDatabaseMutationContext.mockImplementation(
      async (operation: (db: { query: typeof query }) => Promise<unknown>) => operation({ query }),
    );
  });

  it("prepares opaque UUID candidates without treating them as authorization tokens", () => {
    const first = preparePersistentContractingCandidateId();
    const second = preparePersistentContractingCandidateId();

    expect(first).toMatch(UUID_PATTERN);
    expect(second).toMatch(UUID_PATTERN);
    expect(second).not.toBe(first);
  });

  it("rejects malformed candidate IDs before entering the trusted mutation context", async () => {
    await expect(
      createPersistentContracting({
        contractingId: "not-a-uuid",
        object: "DEMO object",
      }),
    ).resolves.toBe("not-available");

    expect(contextMocks.withTrustedDatabaseMutationContext).not.toHaveBeenCalled();
    expect(query).not.toHaveBeenCalled();
  });

  it("passes only candidate/object and generates the event UUID server-side", async () => {
    const contractingId = "29000000-0000-4000-8000-000000000001";
    query.mockResolvedValueOnce({ rows: [{ outcome: "created" }] });

    const forgedCall = createPersistentContracting as unknown as (
      input: Record<string, unknown>,
    ) => ReturnType<typeof createPersistentContracting>;

    await expect(
      forgedCall({
        contractingId,
        object: "  DEMO object preserved exactly  ",
        eventId: "29000000-0000-4000-8000-000000009999",
        teamId: "29000000-0000-4000-8000-000000009998",
        actorMembershipId: "29000000-0000-4000-8000-000000009997",
        createdByMembershipId: "29000000-0000-4000-8000-000000009996",
        issuer: "https://attacker.invalid",
        subject: "FORGED-DEMO-SUBJECT",
      }),
    ).resolves.toBe("created");

    expect(contextMocks.withTrustedDatabaseMutationContext).toHaveBeenCalledTimes(1);
    expect(query).toHaveBeenCalledTimes(1);

    const [sql, values] = query.mock.calls[0] as [string, unknown[]];
    expect(sql).toContain("public.create_contracting_minimal");
    expect(sql).toContain("$1::uuid");
    expect(sql).toContain("$2::text");
    expect(sql).toContain("$3::uuid");
    expect(sql).not.toContain(contractingId);
    expect(sql).not.toContain("team_id");
    expect(sql).not.toContain("actor_membership_id");
    expect(values[0]).toBe(contractingId);
    expect(values[1]).toBe("  DEMO object preserved exactly  ");
    expect(values[2]).toEqual(expect.stringMatching(UUID_PATTERN));
    expect(values[2]).not.toBe("29000000-0000-4000-8000-000000009999");
    expect(values).toHaveLength(3);
  });

  it("preserves the empty string exactly instead of inventing a non-empty rule", async () => {
    query.mockResolvedValueOnce({ rows: [{ outcome: "created" }] });

    await expect(
      createPersistentContracting({
        contractingId: "29000000-0000-4000-8000-000000000002",
        object: "",
      }),
    ).resolves.toBe("created");

    expect((query.mock.calls[0]?.[1] as unknown[] | undefined)?.[1]).toBe("");
  });

  it("maps exact replay and denied outcomes to sanitized application states", async () => {
    const input = {
      contractingId: "29000000-0000-4000-8000-000000000003",
      object: "DEMO create",
    } as const;

    query.mockResolvedValueOnce({ rows: [{ outcome: "already-created" }] });
    await expect(createPersistentContracting(input)).resolves.toBe("already-created");

    query.mockResolvedValueOnce({ rows: [{ outcome: "denied" }] });
    await expect(createPersistentContracting(input)).resolves.toBe("not-available");
  });

  it("fails closed on malformed object input or database/primitive failure", async () => {
    const invalidCall = createPersistentContracting as unknown as (
      input: Record<string, unknown>,
    ) => ReturnType<typeof createPersistentContracting>;

    await expect(
      invalidCall({
        contractingId: "29000000-0000-4000-8000-000000000004",
        object: null,
      }),
    ).resolves.toBe("unavailable");
    expect(contextMocks.withTrustedDatabaseMutationContext).not.toHaveBeenCalled();

    contextMocks.withTrustedDatabaseMutationContext.mockRejectedValueOnce(
      new Error("postgresql://detail-that-must-not-escape.example.invalid/private"),
    );

    await expect(
      createPersistentContracting({
        contractingId: "29000000-0000-4000-8000-000000000005",
        object: "DEMO",
      }),
    ).resolves.toBe("unavailable");

    contextMocks.withTrustedDatabaseMutationContext.mockImplementationOnce(
      async (operation: (db: { query: typeof query }) => Promise<unknown>) => operation({ query }),
    );
    query.mockResolvedValueOnce({ rows: [{ outcome: "unexpected-internal-detail" }] });

    await expect(
      createPersistentContracting({
        contractingId: "29000000-0000-4000-8000-000000000006",
        object: "DEMO",
      }),
    ).resolves.toBe("unavailable");
  });
});
