import "server-only";

import { readPrivateAuthSessionState } from "../../server/auth/runtime";
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
      kind: "sign-in-required";
      records: [];
    }>
  | Readonly<{
      kind: "unavailable";
      records: [];
    }>;

/**
 * Selects the server-side source. Persistent mode verifies that an authenticated
 * provider session exists before attempting the RLS-protected database read.
 * Protected failures never fall back to demo.
 */
export async function loadSectorCentralViewData(): Promise<SectorCentralViewData> {
  const mode = readPersistentReadMode();

  if (mode === "demo") {
    return { kind: "demo", records: demoSectorRecords };
  }

  if (mode === "invalid") {
    return { kind: "unavailable", records: [] };
  }

  const session = await readPrivateAuthSessionState();

  if (session.kind === "unauthenticated") {
    return { kind: "sign-in-required", records: [] };
  }

  if (session.kind === "unavailable") {
    return { kind: "unavailable", records: [] };
  }

  try {
    const records = await readPersistentSectorCentralRecords();
    return { kind: "persistent", records };
  } catch {
    return { kind: "unavailable", records: [] };
  }
}
