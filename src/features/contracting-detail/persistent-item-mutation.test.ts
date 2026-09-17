import { beforeEach, describe, expect, it, vi } from "vitest";

const contextMocks = vi.hoisted(() => ({
  withTrustedDatabaseMutationContext: vi.fn(),
}));

vi.mock("server-only", () => ({}));
vi.mock("@/server/database/trusted-mutation-context", () => ({
  withTrustedDatabaseMutationContext: contextMocks.withTrustedDatabaseMutationContext,
}));

import { mutatePersistentContractingItem } from "./persistent-item-mutation";

const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

const BASE_INPUT = {
  contractingId: "38040000-0000-4000-8000-000000000001",
  itemId: "38050000-0000-4000-8000-000000000001",
  expectedDescription: "  DEMO old  ",
  expectedQuantity: "12345678901234567890.12345678901234567890",
  expectedUnit: "  kg  ",
  expectedCatalogCode: "  OLD  ",
  newDescription: "  DEMO new  ",
  newQuantity: "-0.000000000000000000123456789",
  newUnit: "   ",
  newCatalogCode: "",
} as const;

const FORGED_EVENT_IDS = [
  "38070000-0000-4000-8000-000000009991",
  "38070000-0000-4000-8000-000000009992",
  "38070000-0000-4000-8000-000000009993",
  "38070000-0000-4000-8000-000000009994",
] as const;

describe("persistent contracting item mutation adapter", () => {
  const query = vi.fn();

  beforeEach(() => {
    vi.clearAllMocks();
    contextMocks.withTrustedDatabaseMutationContext.mockImplementation(
      async (operation: (db: { query: typeof query }) => Promise<unknown>) => operation({ query }),
    );
  });

  it("rejects malformed candidate contracting/item IDs before trusted execution", async () => {
    await expect(
      mutatePersistentContractingItem({ ...BASE_INPUT, contractingId: "not-a-uuid" }),
    ).resolves.toBe("not-available");
    await expect(
      mutatePersistentContractingItem({ ...BASE_INPUT, itemId: "not-a-uuid" }),
    ).resolves.toBe("not-available");

    expect(contextMocks.withTrustedDatabaseMutationContext).not.toHaveBeenCalled();
    expect(query).not.toHaveBeenCalled();
  });

  it("passes only selectors plus exact expected/new snapshots and generates four event UUIDs server-side", async () => {
    query.mockResolvedValueOnce({ rows: [{ outcome: "updated" }] });

    const forgedCall = mutatePersistentContractingItem as unknown as (
      input: Record<string, unknown>,
    ) => ReturnType<typeof mutatePersistentContractingItem>;

    await expect(
      forgedCall({
        ...BASE_INPUT,
        teamId: "38010000-0000-4000-8000-000000009999",
        actorMembershipId: "38030000-0000-4000-8000-000000009999",
        membershipId: "38030000-0000-4000-8000-000000009998",
        issuer: "https://attacker.invalid",
        subject: "FORGED-DEMO-SUBJECT",
        ordinal: 999,
        retiredAt: "2026-01-01T00:00:00Z",
        updatedAt: "2026-01-01T00:00:00Z",
        descriptionEventId: FORGED_EVENT_IDS[0],
        quantityEventId: FORGED_EVENT_IDS[1],
        unitEventId: FORGED_EVENT_IDS[2],
        catalogCodeEventId: FORGED_EVENT_IDS[3],
      }),
    ).resolves.toBe("updated");

    expect(query).toHaveBeenCalledTimes(1);
    const [sql, values] = query.mock.calls[0] as [string, unknown[]];
    expect(sql).toContain("public.mutate_contracting_item_fields");
    expect(sql).toContain("$4::numeric");
    expect(sql).toContain("$8::numeric");
    expect(sql).not.toContain(BASE_INPUT.contractingId);
    expect(sql).not.toContain("team_id");
    expect(sql).not.toContain("actor_membership_id");
    expect(values).toHaveLength(14);
    expect(values.slice(0, 10)).toEqual([
      BASE_INPUT.contractingId,
      BASE_INPUT.itemId,
      BASE_INPUT.expectedDescription,
      BASE_INPUT.expectedQuantity,
      BASE_INPUT.expectedUnit,
      BASE_INPUT.expectedCatalogCode,
      BASE_INPUT.newDescription,
      BASE_INPUT.newQuantity,
      BASE_INPUT.newUnit,
      BASE_INPUT.newCatalogCode,
    ]);

    const eventIds = values.slice(10);
    expect(eventIds).toHaveLength(4);
    for (const eventId of eventIds) {
      expect(eventId).toEqual(expect.stringMatching(UUID_PATTERN));
      expect(FORGED_EVENT_IDS).not.toContain(String(eventId));
    }
    expect(new Set(eventIds).size).toBe(4);
  });

  it("preserves null, empty and spaced values without normalization", async () => {
    query.mockResolvedValueOnce({ rows: [{ outcome: "updated" }] });

    await expect(
      mutatePersistentContractingItem({
        ...BASE_INPUT,
        expectedDescription: "",
        expectedQuantity: null,
        expectedUnit: "",
        expectedCatalogCode: "   ",
        newDescription: "   ",
        newQuantity: "0",
        newUnit: null,
        newCatalogCode: "",
      }),
    ).resolves.toBe("updated");

    const values = query.mock.calls[0]?.[1] as unknown[];
    expect(values.slice(2, 10)).toEqual(["", null, "", "   ", "   ", "0", null, ""]);
  });

  it("passes negative, fractional and high precision numeric strings without JavaScript coercion", async () => {
    for (const [index, numeric] of [
      "-2.500",
      "0.000000000000000000123456789",
      "123456789012345678901234567890.12345678901234567890",
    ].entries()) {
      query.mockResolvedValueOnce({ rows: [{ outcome: "updated" }] });
      await expect(
        mutatePersistentContractingItem({
          ...BASE_INPUT,
          itemId: `38050000-0000-4000-8000-${(index + 10).toString().padStart(12, "0")}`,
          expectedQuantity: numeric,
          newQuantity: numeric,
        }),
      ).resolves.toBe("updated");

      const values = query.mock.calls[index]?.[1] as unknown[];
      expect(values[3]).toBe(numeric);
      expect(values[7]).toBe(numeric);
    }
  });

  it("maps only approved primitive outcomes and sanitizes technical failures", async () => {
    for (const outcome of ["updated", "unchanged", "conflict"] as const) {
      query.mockResolvedValueOnce({ rows: [{ outcome }] });
      await expect(mutatePersistentContractingItem(BASE_INPUT)).resolves.toBe(outcome);
    }

    query.mockResolvedValueOnce({ rows: [{ outcome: "denied" }] });
    await expect(mutatePersistentContractingItem(BASE_INPUT)).resolves.toBe("not-available");

    query.mockResolvedValueOnce({ rows: [{ outcome: "internal-detail" }] });
    await expect(mutatePersistentContractingItem(BASE_INPUT)).resolves.toBe("unavailable");

    contextMocks.withTrustedDatabaseMutationContext.mockRejectedValueOnce(
      new Error("postgresql://secret-that-must-not-escape.example.invalid/private"),
    );
    await expect(mutatePersistentContractingItem(BASE_INPUT)).resolves.toBe("unavailable");
  });

  it("forwards invalid numeric text unchanged and sanitizes PostgreSQL cast failure", async () => {
    query.mockRejectedValueOnce(new Error('invalid input syntax for type numeric: "not-a-number"'));

    await expect(
      mutatePersistentContractingItem({
        ...BASE_INPUT,
        newQuantity: "not-a-number",
      }),
    ).resolves.toBe("unavailable");

    expect((query.mock.calls[0]?.[1] as unknown[])[7]).toBe("not-a-number");
  });

  it("fails closed on malformed snapshot field types before database execution", async () => {
    const invalidCall = mutatePersistentContractingItem as unknown as (
      input: Record<string, unknown>,
    ) => ReturnType<typeof mutatePersistentContractingItem>;

    for (const patch of [
      { expectedDescription: null },
      { expectedQuantity: 1.25 },
      { expectedUnit: 123 },
      { expectedCatalogCode: false },
      { newDescription: null },
      { newQuantity: 1 },
      { newUnit: {} },
      { newCatalogCode: [] },
    ]) {
      await expect(invalidCall({ ...BASE_INPUT, ...patch })).resolves.toBe("unavailable");
    }

    expect(contextMocks.withTrustedDatabaseMutationContext).not.toHaveBeenCalled();
    expect(query).not.toHaveBeenCalled();
  });
});
