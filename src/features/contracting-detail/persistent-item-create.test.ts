import { beforeEach, describe, expect, it, vi } from "vitest";

const contextMocks = vi.hoisted(() => ({
  withTrustedDatabaseMutationContext: vi.fn(),
}));

vi.mock("server-only", () => ({}));
vi.mock("@/server/database/trusted-mutation-context", () => ({
  withTrustedDatabaseMutationContext: contextMocks.withTrustedDatabaseMutationContext,
}));

import { createPersistentContractingItem } from "./persistent-item-create";

const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

describe("persistent contracting item create adapter", () => {
  const query = vi.fn();

  beforeEach(() => {
    vi.clearAllMocks();
    contextMocks.withTrustedDatabaseMutationContext.mockImplementation(
      async (operation: (db: { query: typeof query }) => Promise<unknown>) => operation({ query }),
    );
  });

  it("rejects malformed candidate IDs before entering the trusted mutation context", async () => {
    await expect(
      createPersistentContractingItem({
        contractingId: "not-a-uuid",
        description: "DEMO item",
        quantity: null,
        unit: null,
        catalogCode: null,
      }),
    ).resolves.toBe("not-available");

    expect(contextMocks.withTrustedDatabaseMutationContext).not.toHaveBeenCalled();
    expect(query).not.toHaveBeenCalled();
  });

  it("passes only the five approved fields and generates item/event UUIDs server-side", async () => {
    const contractingId = "35040000-0000-4000-8000-000000000001";
    query.mockResolvedValueOnce({ rows: [{ outcome: "created" }] });

    const forgedCall = createPersistentContractingItem as unknown as (
      input: Record<string, unknown>,
    ) => ReturnType<typeof createPersistentContractingItem>;

    await expect(
      forgedCall({
        contractingId,
        description: "  DEMO item preserved exactly  ",
        quantity: "12345678901234567890.12345678901234567890",
        unit: "  kg  ",
        catalogCode: "  CAT-DEMO  ",
        ordinal: 999,
        itemId: "35060000-0000-4000-8000-000000009999",
        eventId: "35070000-0000-4000-8000-000000009999",
        teamId: "35010000-0000-4000-8000-000000009999",
        actorMembershipId: "35030000-0000-4000-8000-000000009999",
        issuer: "https://attacker.invalid",
        subject: "FORGED-DEMO-SUBJECT",
      }),
    ).resolves.toBe("created");

    expect(contextMocks.withTrustedDatabaseMutationContext).toHaveBeenCalledTimes(1);
    expect(query).toHaveBeenCalledTimes(1);

    const [sql, values] = query.mock.calls[0] as [string, unknown[]];
    expect(sql).toContain("public.create_contracting_item");
    expect(sql).toContain("$3::numeric");
    expect(sql).not.toContain(contractingId);
    expect(sql).not.toContain("team_id");
    expect(sql).not.toContain("actor_membership_id");
    expect(values).toHaveLength(7);
    expect(values[0]).toBe(contractingId);
    expect(values[1]).toBe("  DEMO item preserved exactly  ");
    expect(values[2]).toBe("12345678901234567890.12345678901234567890");
    expect(values[3]).toBe("  kg  ");
    expect(values[4]).toBe("  CAT-DEMO  ");
    expect(values[5]).toEqual(expect.stringMatching(UUID_PATTERN));
    expect(values[6]).toEqual(expect.stringMatching(UUID_PATTERN));
    expect(values[5]).not.toBe("35060000-0000-4000-8000-000000009999");
    expect(values[6]).not.toBe("35070000-0000-4000-8000-000000009999");
    expect(values[5]).not.toBe(values[6]);
  });

  it("preserves empty and spaced text while keeping nullable fields distinct", async () => {
    query.mockResolvedValueOnce({ rows: [{ outcome: "created" }] });

    await expect(
      createPersistentContractingItem({
        contractingId: "35040000-0000-4000-8000-000000000002",
        description: "",
        quantity: null,
        unit: "   ",
        catalogCode: "",
      }),
    ).resolves.toBe("created");

    const values = query.mock.calls[0]?.[1] as unknown[];
    expect(values[1]).toBe("");
    expect(values[2]).toBeNull();
    expect(values[3]).toBe("   ");
    expect(values[4]).toBe("");
  });

  it("passes zero, negative and fractional quantity strings without JavaScript numeric coercion", async () => {
    for (const [index, quantity] of [
      "0",
      "-2.500",
      "0.000000000000000000123456789",
    ].entries()) {
      query.mockResolvedValueOnce({ rows: [{ outcome: "created" }] });

      await expect(
        createPersistentContractingItem({
          contractingId: `35040000-0000-4000-8000-${(index + 10).toString().padStart(12, "0")}`,
          description: "DEMO quantity",
          quantity,
          unit: null,
          catalogCode: null,
        }),
      ).resolves.toBe("created");

      expect((query.mock.calls[index]?.[1] as unknown[] | undefined)?.[2]).toBe(quantity);
    }
  });

  it("maps denied to not-available and sanitizes technical or impossible outcomes", async () => {
    const input = {
      contractingId: "35040000-0000-4000-8000-000000000020",
      description: "DEMO",
      quantity: null,
      unit: null,
      catalogCode: null,
    } as const;

    query.mockResolvedValueOnce({ rows: [{ outcome: "denied" }] });
    await expect(createPersistentContractingItem(input)).resolves.toBe("not-available");

    query.mockResolvedValueOnce({ rows: [{ outcome: "unexpected-internal-detail" }] });
    await expect(createPersistentContractingItem(input)).resolves.toBe("unavailable");

    contextMocks.withTrustedDatabaseMutationContext.mockRejectedValueOnce(
      new Error("postgresql://detail-that-must-not-escape.example.invalid/private"),
    );
    await expect(createPersistentContractingItem(input)).resolves.toBe("unavailable");
  });

  it("fails closed on malformed item field types before database execution", async () => {
    const invalidCall = createPersistentContractingItem as unknown as (
      input: Record<string, unknown>,
    ) => ReturnType<typeof createPersistentContractingItem>;

    const contractingId = "35040000-0000-4000-8000-000000000030";

    await expect(
      invalidCall({
        contractingId,
        description: null,
        quantity: null,
        unit: null,
        catalogCode: null,
      }),
    ).resolves.toBe("unavailable");

    await expect(
      invalidCall({
        contractingId,
        description: "DEMO",
        quantity: 1.25,
        unit: null,
        catalogCode: null,
      }),
    ).resolves.toBe("unavailable");

    await expect(
      invalidCall({
        contractingId,
        description: "DEMO",
        quantity: null,
        unit: 123,
        catalogCode: null,
      }),
    ).resolves.toBe("unavailable");

    expect(contextMocks.withTrustedDatabaseMutationContext).not.toHaveBeenCalled();
    expect(query).not.toHaveBeenCalled();
  });
});
