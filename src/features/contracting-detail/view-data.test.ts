import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

const readMocks = vi.hoisted(() => ({
  isPersistentContractingId: vi.fn(),
  readPersistentContractingDetail: vi.fn(),
  readPrivateAuthSessionState: vi.fn(),
}));

vi.mock("server-only", () => ({}));
vi.mock("../../server/auth/runtime", () => ({
  readPrivateAuthSessionState: readMocks.readPrivateAuthSessionState,
}));
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
    readMocks.readPrivateAuthSessionState.mockResolvedValue({
      kind: "authenticated",
      identity: {
        issuer: "https://auth.demo.invalid/neondb/auth",
        subject: "DEMO-SUBJECT",
      },
    });
  });

  afterEach(() => {
    delete process.env.COMPRAS_PERSISTENT_READ_ENABLED;
  });

  it("keeps demo lookup for an absent or false persistent flag without requiring auth", async () => {
    await expect(loadContractingDetailViewData(" demo-001 ")).resolves.toEqual({
      kind: "demo",
      detail: getDemoContractingDetail("DEMO-001"),
    });

    process.env.COMPRAS_PERSISTENT_READ_ENABLED = "false";
    await expect(loadContractingDetailViewData("DEMO-999")).resolves.toEqual({ kind: "not-found" });
    expect(readMocks.readPrivateAuthSessionState).not.toHaveBeenCalled();
    expect(readMocks.readPersistentContractingDetail).not.toHaveBeenCalled();
  });

  it("rejects malformed persistent IDs before auth or the domain reader", async () => {
    process.env.COMPRAS_PERSISTENT_READ_ENABLED = "true";
    readMocks.isPersistentContractingId.mockReturnValue(false);

    await expect(loadContractingDetailViewData("DEMO-001")).resolves.toEqual({ kind: "not-found" });
    expect(readMocks.readPrivateAuthSessionState).not.toHaveBeenCalled();
    expect(readMocks.readPersistentContractingDetail).not.toHaveBeenCalled();
  });

  it("requests sign-in before protected detail access when there is no session", async () => {
    process.env.COMPRAS_PERSISTENT_READ_ENABLED = "true";
    readMocks.readPrivateAuthSessionState.mockResolvedValue({ kind: "unauthenticated" });

    await expect(
      loadContractingDetailViewData("00000000-0000-4000-8000-000000000901"),
    ).resolves.toEqual({ kind: "sign-in-required" });
    expect(readMocks.readPersistentContractingDetail).not.toHaveBeenCalled();
  });

  it("keeps provider/configuration failure unavailable and does not attempt the database read", async () => {
    process.env.COMPRAS_PERSISTENT_READ_ENABLED = "true";
    readMocks.readPrivateAuthSessionState.mockResolvedValue({ kind: "unavailable" });

    await expect(
      loadContractingDetailViewData("00000000-0000-4000-8000-000000000901"),
    ).resolves.toEqual({ kind: "unavailable" });
    expect(readMocks.readPersistentContractingDetail).not.toHaveBeenCalled();
  });

  it("returns persistent detail only for exact true mode, authenticated session, and an authorized result", async () => {
    process.env.COMPRAS_PERSISTENT_READ_ENABLED = "true";
    const detail = getDemoContractingDetail("DEMO-001")!;
    readMocks.readPersistentContractingDetail.mockResolvedValue(detail);

    await expect(
      loadContractingDetailViewData("00000000-0000-4000-8000-000000000901"),
    ).resolves.toEqual({ kind: "persistent", detail });
  });

  it("keeps nonexistent, cross-team, and authenticated-but-unauthorized persistent UUIDs externally identical", async () => {
    process.env.COMPRAS_PERSISTENT_READ_ENABLED = "true";
    readMocks.readPersistentContractingDetail.mockResolvedValue(undefined);

    await expect(
      loadContractingDetailViewData("00000000-0000-4000-8000-000000000901"),
    ).resolves.toEqual({ kind: "not-found" });
  });

  it("fails closed for invalid activation or protected read failure without demo fallback", async () => {
    process.env.COMPRAS_PERSISTENT_READ_ENABLED = " true";
    await expect(loadContractingDetailViewData("DEMO-001")).resolves.toEqual({ kind: "unavailable" });
    expect(readMocks.readPrivateAuthSessionState).not.toHaveBeenCalled();

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
