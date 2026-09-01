import { describe, expect, it } from "vitest";
import { demoSectorRecords } from "./demo-data";
import {
  filterSectorRecords,
  getSectorFilterOptions,
  normalizeSearchText,
  type SectorCentralFilters,
} from "./filtering";

const emptyFilters: SectorCentralFilters = {
  query: "",
  responsible: "",
  stage: "",
  status: "",
};

describe("sector central filtering", () => {
  it("normalizes accents, case and surrounding whitespace", () => {
    expect(normalizeSearchText("  AQUISIÇÃO  ")).toBe("aquisicao");
  });

  it("searches by demonstration identifier", () => {
    const result = filterSectorRecords(demoSectorRecords, {
      ...emptyFilters,
      query: "demo-004",
    });

    expect(result.map((record) => record.id)).toEqual(["DEMO-004"]);
  });

  it("searches object text without requiring accents", () => {
    const result = filterSectorRecords(demoSectorRecords, {
      ...emptyFilters,
      query: "aquisicao demonstrativa e",
    });

    expect(result.map((record) => record.id)).toEqual(["DEMO-005"]);
  });

  it("searches by responsible person", () => {
    const result = filterSectorRecords(demoSectorRecords, {
      ...emptyFilters,
      query: "pessoa c",
    });

    expect(result.map((record) => record.id)).toEqual(["DEMO-003", "DEMO-006"]);
  });

  it("combines responsible, stage and status filters", () => {
    const result = filterSectorRecords(demoSectorRecords, {
      query: "",
      responsible: "Pessoa B",
      stage: "Pesquisa demo",
      status: "Aguardando demo",
    });

    expect(result.map((record) => record.id)).toEqual(["DEMO-002"]);
  });

  it("returns the complete dataset when filters are cleared", () => {
    expect(filterSectorRecords(demoSectorRecords, emptyFilters)).toHaveLength(
      demoSectorRecords.length,
    );
  });

  it("derives unique filter options from the dataset", () => {
    const options = getSectorFilterOptions(demoSectorRecords);

    expect(options.responsibles).toEqual(["Pessoa A", "Pessoa B", "Pessoa C"]);
    expect(options.stages).toHaveLength(4);
    expect(options.statuses).toHaveLength(3);
  });
});
