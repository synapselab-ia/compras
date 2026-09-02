export type SectorCentralRecord = {
  id: string;
  object: string;
  responsible: string;
  stage: string;
  status: string;
  waitingOn: string;
  nextAction: string;
  lastMovement: string;
};

export type SectorCentralSource = "demo" | "persistent";
