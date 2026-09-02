import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

const readMocks = vi.hoisted(() => ({
  readPersistentSectorCentralRecords: vi.fn(),
}));

vi.mock("server-only", () => ({}));
vi.mock("./persistent-read", () => ({
  readPersistentSectorCentralRecords: readMocks.readPersistentSectorCentralRecords,
}));

import { demoSectorRecords } from "./demo-data";
import { loadSectorCentralViewData } from "./view-data";

describe("loadSectorCentralViewData", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    delete process.env.COMPRAS_PERSISTENT_READ_ENABLED;
  });

  afterEach(() => {
    delete process.env.COMPRAS_PERSISTENT_READ_ENABLED;
  });

  it("uses the explicit demo source when the persistent flag is absent or false", async () => {
    await expect(loadSectorCentralViewData()).resolves.toEqual({
      kind: "demo",
      records: demoSectorRecords,
    });

    process.env.COMPRAS_PERSISTENT_READ_ENABLED = "false";
    await expect(loadSectorCentralViewData()).resolves.toEqual({
      kind: "demo",
      records: demoSectorRecords,
    });

    expect(readMocks.readPersistentSectorCentralRecords).not.toHaveBeenCalled();
  });

  it("uses the protected persistent reader only for the exact true value", async () => {
    const records = [
      {
        id: "00000000-0000-4000-8000-000000000911",
        object: "Persistente fictício",
        responsible: "Pessoa Demo",
        stage: "fase-demo",
        status: "status-demo",
        waitingOn: "Setor Demo",
        nextAction: "Ação demo",
        lastMovement: "2026-09-01T12:00:00.000Z",
      },
    ];

    process.env.COMPRAS_PERSISTENT_READ_ENABLED = "true";
    readMocks.readPersistentSectorCentralRecords.mockResolvedValue(records);

    await expect(loadSectorCentralViewData()).resolves.toEqual({
      kind: "persistent",
      records,
    });
    expect(readMocks.readPersistentSectorCentralRecords).toHaveBeenCalledTimes(1);
  });

  it("fails closed for malformed activation values instead of silently choosing a source", async () => {
    process.env.COMPRAS_PERSISTENT_READ_ENABLED = " true";

    await expect(loadSectorCentralViewData()).resolves.toEqual({
      kind: "unavailable",
      records: [],
    });
    expect(readMocks.readPersistentSectorCentralRecords).not.toHaveBeenCalled();
  });

  it("does not fall back to demo or expose error details when persistent reading fails", async () => {
    process.env.COMPRAS_PERSISTENT_READ_ENABLED = "true";
    readMocks.readPersistentSectorCentralRecords.mockRejectedValue(
      new Error("postgresql://secret-user:secret-pass@private.invalid/database"),
    );

    const result = await loadSectorCentralViewData();

    expect(result).toEqual({ kind: "unavailable", records: [] });
    expect(JSON.stringify(result)).not.toContain("secret-user");
    expect(JSON.stringify(result)).not.toContain("private.invalid");
    expect(result).not.toEqual({ kind: "demo", records: demoSectorRecords });
  });
});
