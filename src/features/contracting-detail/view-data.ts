import "server-only";

import { readPersistentReadMode } from "@/server/persistent-read-mode";
import { getDemoContractingDetail } from "./demo-detail-data";
import {
  isPersistentContractingId,
  readPersistentContractingDetail,
} from "./persistent-read";
import type { ContractingDetailPresentation } from "./types";

export type ContractingDetailViewData =
  | Readonly<{ kind: "demo"; detail: ContractingDetailPresentation }>
  | Readonly<{ kind: "persistent"; detail: ContractingDetailPresentation }>
  | Readonly<{ kind: "not-found" }>
  | Readonly<{ kind: "unavailable" }>;

export async function loadContractingDetailViewData(
  id: string,
): Promise<ContractingDetailViewData> {
  const mode = readPersistentReadMode();

  if (mode === "demo") {
    const detail = getDemoContractingDetail(id);
    return detail ? { kind: "demo", detail } : { kind: "not-found" };
  }

  if (mode === "invalid") {
    return { kind: "unavailable" };
  }

  if (!isPersistentContractingId(id)) {
    return { kind: "not-found" };
  }

  try {
    const detail = await readPersistentContractingDetail(id);
    return detail ? { kind: "persistent", detail } : { kind: "not-found" };
  } catch {
    return { kind: "unavailable" };
  }
}
