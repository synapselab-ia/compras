import type { SectorCentralRecord } from "./demo-data";

export type SectorCentralFilters = {
  query: string;
  responsible: string;
  stage: string;
  status: string;
};

export type SectorCentralFilterOptions = {
  responsibles: string[];
  stages: string[];
  statuses: string[];
};

export function normalizeSearchText(value: string): string {
  return value
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLocaleLowerCase("pt-BR")
    .trim();
}

export function filterSectorRecords(
  records: SectorCentralRecord[],
  filters: SectorCentralFilters,
): SectorCentralRecord[] {
  const normalizedQuery = normalizeSearchText(filters.query);

  return records.filter((record) => {
    const matchesQuery =
      normalizedQuery.length === 0 ||
      [record.id, record.object, record.responsible].some((value) =>
        normalizeSearchText(value).includes(normalizedQuery),
      );

    const matchesResponsible =
      filters.responsible.length === 0 || record.responsible === filters.responsible;
    const matchesStage = filters.stage.length === 0 || record.stage === filters.stage;
    const matchesStatus = filters.status.length === 0 || record.status === filters.status;

    return matchesQuery && matchesResponsible && matchesStage && matchesStatus;
  });
}

export function getSectorFilterOptions(
  records: SectorCentralRecord[],
): SectorCentralFilterOptions {
  const uniqueSorted = (values: string[]) => [...new Set(values)].sort((a, b) => a.localeCompare(b, "pt-BR"));

  return {
    responsibles: uniqueSorted(records.map((record) => record.responsible)),
    stages: uniqueSorted(records.map((record) => record.stage)),
    statuses: uniqueSorted(records.map((record) => record.status)),
  };
}
