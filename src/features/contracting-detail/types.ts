import type { SectorCentralRecord } from "../sector-central/types";

export type ContractingDetailSource = "demo" | "persistent";

export type ContractingRelatedIdentifier = {
  id: string;
  label: string;
  value: string;
  note: string | null;
};

export type ContractingItemMutationSnapshot = Readonly<{
  description: string;
  quantity: string | null;
  unit: string | null;
  catalogCode: string | null;
}>;

export type ContractingItemPresentation = {
  id: string;
  label: string;
  note: string;
  /**
   * Raw values from the protected persistent read. This is only an optimistic
   * concurrency precondition for F38. It never defines team scope or actor
   * authority. Demo items deliberately carry null here.
   */
  mutationSnapshot: ContractingItemMutationSnapshot | null;
};

export type ContractingActivityPresentation = {
  id: string;
  label: string;
  moment: string;
  note: string | null;
};

export type ContractingDetailPresentation = SectorCentralRecord & {
  /**
   * Raw nullable value from the protected read model. `nextAction` remains the
   * human presentation string, while this field preserves NULL versus the
   * literal empty string for ADR-011 optimistic concurrency.
   */
  nextActionValue: string | null;
  waitingSince: string;
  waitingReason: string;
  createdAt: string;
  relatedIdentifiers: ContractingRelatedIdentifier[];
  items: ContractingItemPresentation[];
  activity: ContractingActivityPresentation[];
};
