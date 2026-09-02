import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

const readMocks = vi.hoisted(() => ({
  isPersistentContractingId: vi.fn(),
  readPersistentContractingDetail: vi.fn(),
}));

vi.mock("server-only", () => ({}));
vi.mock("./persistent-read", () => ({
  isPersistentContractingId: readMocks.isPersistentContractingId,
  readPersistentContractingDetail: readMocks.readPersistentContractingDetail,
}));

import { getDemoContractingDetail } from "./demo-detail-data";
import { loadContractingDetailViewData } from "./view-data";

describe("loadContractingDetailViewData", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    delete process.env.COMPRAS_PERSISTENT_READ_ENABLED;
    readMocks.isPersistentContractingId.mockReturnValue(true);
  });

  afterEach(() => {
    delete process.env.COMPRAS_PERSISTENT_READ_ENABLED;
  });

  it("keeps demo lookup for an absent or false persistent flag", async () => {
    await expect(loadContractingDetailViewData(" demo-001 ")).resolves.toEqual({
      kind: "demo",
      detail: getDemoContractingDetail("DEMO-001"),
    });

    process.env.COMPRAS_PERSISTENT_READ_ENABLED = "false";
    await expect(loadContractingDetailViewData("DEMO-999")).resolves.toEqual({ kind: "not-found" });
    expect(readMocks.readPersistentContractingDetail).not.toHaveBeenCalled();
  });

  it("returns persistent detail only for exact true mode and an authorized result", async () => {
    process.env.COMPRAS_PERSISTENT_READ_ENABLED = "true";
    const detail = getDemoContractingDetail("DEMO-001")!;
    readMocks.readPersistentContractingDetail.mockResolvedValue(detail);

    await expect(
      loadContractingDetailViewData("00000000-0000-4000-8000-000000000901"),
    ).resolves.toEqual({ kind: "persistent", detail });
  });

  it("keeps nonexistent and cross-team persistent UUIDs externally identical", async () => {
    process.env.COMPRAS_PERSISTENT_READ_ENABLED = "true";
    readMocks.readPersistentContractingDetail.mockResolvedValue(undefined);

    await expect(
      loadContractingDetailViewData("00000000-0000-4000-8000-000000000901"),
    ).resolves.toEqual({ kind: "not-found" });
  });

  it("rejects malformed persistent IDs before the domain reader", async () => {
    process.env.COMPRAS_PERSISTENT_READ_ENABLED = "true";
    readMocks.isPersistentContractingId.mockReturnValue(false);

    await expect(loadContractingDetailViewData("DEMO-001")).resolves.toEqual({ kind: "not-found" });
    expect(readMocks.readPersistentContractingDetail).not.toHaveBeenCalled();
  });

  it("fails closed for invalid activation or protected read failure without demo fallback", async () => {
    process.env.COMPRAS_PERSISTENT_READ_ENABLED = " true";
    await expect(loadContractingDetailViewData("DEMO-001")).resolves.toEqual({ kind: "unavailable" });

    process.env.COMPRAS_PERSISTENT_READ_ENABLED = "true";
    readMocks.readPersistentContractingDetail.mockRejectedValue(
      new Error("postgresql://secret-user:secret-pass@private.invalid/database"),
    );

    const result = await loadContractingDetailViewData("00000000-0000-4000-8000-000000000901");
    expect(result).toEqual({ kind: "unavailable" });
    expect(JSON.stringify(result)).not.toContain("secret-user");
    expect(JSON.stringify(result)).not.toContain("private.invalid");
  });
});
