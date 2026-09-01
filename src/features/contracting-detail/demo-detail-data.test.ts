import { describe, expect, it } from "vitest";
import { getDemoContractingDetail } from "./demo-detail-data";

describe("demo contracting detail lookup", () => {
  it("returns a detail using the same operational fields as the Central", () => {
    const detail = getDemoContractingDetail("DEMO-001");

    expect(detail).toMatchObject({
      id: "DEMO-001",
      object: "Aquisição demonstrativa A",
      responsible: "Pessoa A",
      stage: "Triagem demo",
      status: "Em andamento demo",
    });
    expect(detail?.relatedIdentifiers.length).toBeGreaterThan(0);
    expect(detail?.items.length).toBeGreaterThan(0);
    expect(detail?.activity.length).toBeGreaterThan(0);
  });

  it("normalizes demonstration identifiers for lookup", () => {
    expect(getDemoContractingDetail(" demo-002 ")?.id).toBe("DEMO-002");
  });

  it("returns undefined for an unknown demonstration identifier", () => {
    expect(getDemoContractingDetail("DEMO-999")).toBeUndefined();
  });
});
