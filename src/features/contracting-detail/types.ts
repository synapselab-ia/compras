import type { SectorCentralRecord } from "../sector-central/types";

export type ContractingDetailSource = "demo" | "persistent";

export type ContractingRelatedIdentifier = {
  id: string;
  label: string;
  value: string;
  note: string | null;
};

export type ContractingItemPresentation = {
  id: string;
  label: string;
  note: string;
};

export type ContractingActivityPresentation = {
  id: string;
  label: string;
  moment: string;
  note: string | null;
};

export type ContractingDetailPresentation = SectorCentralRecord & {
  waitingSince: string;
  waitingReason: string;
  createdAt: string;
  relatedIdentifiers: ContractingRelatedIdentifier[];
  items: ContractingItemPresentation[];
  activity: ContractingActivityPresentation[];
};
