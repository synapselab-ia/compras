import { describe, expect, it } from "vitest";
import { getFoundationState } from "./foundation";

describe("getFoundationState", () => {
  it("expõe apenas o estado técnico neutro da fundação", () => {
    const state = getFoundationState();

    expect(state).toHaveLength(3);
    expect(state.map((item) => item.label)).toEqual([
      "Aplicação",
      "Dados",
      "Integrações",
    ]);
    expect(state.some((item) => item.value.includes("Não configuradas"))).toBe(true);
  });
});
