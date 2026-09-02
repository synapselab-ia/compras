import "server-only";

import { readPersistentReadMode } from "../../server/persistent-read-mode";
import { demoSectorRecords } from "./demo-data";
import { readPersistentSectorCentralRecords } from "./persistent-read";
import type { SectorCentralRecord } from "./types";

export type SectorCentralViewData =
  | Readonly<{
      kind: "demo";
      records: SectorCentralRecord[];
    }>
  | Readonly<{
      kind: "persistent";
      records: SectorCentralRecord[];
    }>
  | Readonly<{
      kind: "unavailable";
      records: [];
    }>;

/**
 * Selects the server-side source. Persistent failures never fall back to demo,
 * avoiding a misleading success state when protected data is unavailable.
 */
export async function loadSectorCentralViewData(): Promise<SectorCentralViewData> {
  const mode = readPersistentReadMode();

  if (mode === "demo") {
    return { kind: "demo", records: demoSectorRecords };
  }

  if (mode === "invalid") {
    return { kind: "unavailable", records: [] };
  }

  try {
    const records = await readPersistentSectorCentralRecords();
    return { kind: "persistent", records };
  } catch {
    return { kind: "unavailable", records: [] };
  }
}
