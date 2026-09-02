import { demoSectorRecords } from "../sector-central/demo-data";
import type {
  ContractingActivityPresentation,
  ContractingDetailPresentation,
  ContractingItemPresentation,
  ContractingRelatedIdentifier,
} from "./types";

export type DemoRelatedIdentifier = ContractingRelatedIdentifier;
export type DemoContractingItem = ContractingItemPresentation;
export type DemoActivity = ContractingActivityPresentation;
export type DemoContractingDetail = ContractingDetailPresentation;

type DemoDetailExtra = Pick<
  DemoContractingDetail,
  "relatedIdentifiers" | "items" | "activity"
>;

const demoDetailExtras: Record<string, DemoDetailExtra> = {
  "DEMO-001": {
    relatedIdentifiers: [
      { id: "REF-ID-DEMO-A1", label: "Identificador demo A", value: "REF-DEMO-A1", note: null },
      { id: "REF-ID-DEMO-A2", label: "Identificador demo B", value: "REF-DEMO-A2", note: null },
    ],
    items: [
      { id: "ITEM-DEMO-01", label: "Item demonstrativo 01", note: "Descrição fictícia para validar organização." },
      { id: "ITEM-DEMO-02", label: "Item demonstrativo 02", note: "Sem quantidade, preço ou referência operacional real." },
    ],
    activity: [
      { id: "EVENT-DEMO-01", label: "Evento demonstrativo 01", moment: "Momento demo A1", note: null },
      { id: "EVENT-DEMO-02", label: "Evento demonstrativo 02", moment: "Momento demo A2", note: null },
    ],
  },
  "DEMO-002": {
    relatedIdentifiers: [{ id: "REF-ID-DEMO-B1", label: "Identificador demo A", value: "REF-DEMO-B1", note: null }],
    items: [
      { id: "ITEM-DEMO-03", label: "Item demonstrativo 03", note: "Conteúdo estático e exclusivamente demonstrativo." },
    ],
    activity: [
      { id: "EVENT-DEMO-03", label: "Evento demonstrativo 03", moment: "Momento demo B1", note: null },
      { id: "EVENT-DEMO-04", label: "Evento demonstrativo 04", moment: "Momento demo B2", note: null },
    ],
  },
  "DEMO-003": {
    relatedIdentifiers: [{ id: "REF-ID-DEMO-C1", label: "Identificador demo A", value: "REF-DEMO-C1", note: null }],
    items: [
      { id: "ITEM-DEMO-04", label: "Item demonstrativo 04", note: "Exemplo genérico sem semântica definitiva de domínio." },
      { id: "ITEM-DEMO-05", label: "Item demonstrativo 05", note: "Usado somente para avaliar densidade da tela." },
    ],
    activity: [{ id: "EVENT-DEMO-05", label: "Evento demonstrativo 05", moment: "Momento demo C1", note: null }],
  },
  "DEMO-004": {
    relatedIdentifiers: [
      { id: "REF-ID-DEMO-D1", label: "Identificador demo A", value: "REF-DEMO-D1", note: null },
      { id: "REF-ID-DEMO-D2", label: "Identificador demo B", value: "REF-DEMO-D2", note: null },
    ],
    items: [{ id: "ITEM-DEMO-06", label: "Item demonstrativo 06", note: "Registro fictício para teste de navegação." }],
    activity: [{ id: "EVENT-DEMO-06", label: "Evento demonstrativo 06", moment: "Momento demo D1", note: null }],
  },
  "DEMO-005": {
    relatedIdentifiers: [{ id: "REF-ID-DEMO-E1", label: "Identificador demo A", value: "REF-DEMO-E1", note: null }],
    items: [{ id: "ITEM-DEMO-07", label: "Item demonstrativo 07", note: "Nenhum dado foi derivado de contratação real." }],
    activity: [
      { id: "EVENT-DEMO-07", label: "Evento demonstrativo 07", moment: "Momento demo E1", note: null },
      { id: "EVENT-DEMO-08", label: "Evento demonstrativo 08", moment: "Momento demo E2", note: null },
    ],
  },
  "DEMO-006": {
    relatedIdentifiers: [{ id: "REF-ID-DEMO-F1", label: "Identificador demo A", value: "REF-DEMO-F1", note: null }],
    items: [
      { id: "ITEM-DEMO-08", label: "Item demonstrativo 08", note: "Descrição genérica para validar agrupamento." },
      { id: "ITEM-DEMO-09", label: "Item demonstrativo 09", note: "Sem vínculo com sistema, setor ou processo real." },
    ],
    activity: [{ id: "EVENT-DEMO-09", label: "Evento demonstrativo 09", moment: "Momento demo F1", note: null }],
  },
};

export function getDemoContractingDetail(id: string): DemoContractingDetail | undefined {
  const normalizedId = id.trim().toUpperCase();
  const centralRecord = demoSectorRecords.find((record) => record.id === normalizedId);
  const extra = demoDetailExtras[normalizedId];

  if (!centralRecord || !extra) {
    return undefined;
  }

  return {
    ...centralRecord,
    waitingSince: "Não informado",
    waitingReason: "Não informado",
    createdAt: "Momento demo de criação",
    ...extra,
  };
}
