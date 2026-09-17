import { describe, expect, it } from "vitest";

import {
  getItemMutationFeedback,
  readItemMutationUiState,
} from "./item-mutation-feedback";

describe("item mutation feedback", () => {
  it("accepts only the five fixed F38 browser states", () => {
    for (const state of [
      "updated",
      "unchanged",
      "conflict",
      "not-available",
      "unavailable",
    ] as const) {
      expect(readItemMutationUiState(state)).toBe(state);
      expect(getItemMutationFeedback(state)?.state).toBe(state);
    }
  });

  it("ignores arrays and unknown values instead of reflecting them", () => {
    expect(readItemMutationUiState(["updated", "unavailable"])).toBeNull();
    expect(readItemMutationUiState("postgresql://private.invalid/secret")).toBeNull();
    expect(readItemMutationUiState(undefined)).toBeNull();
    expect(getItemMutationFeedback(null)).toBeNull();
  });

  it("uses fixed generic conflict and availability messages", () => {
    expect(getItemMutationFeedback("conflict")?.message).toContain(
      "O item mudou desde sua leitura",
    );
    expect(getItemMutationFeedback("not-available")?.message).toBe(
      "A alteração do item não está disponível para este registro.",
    );
    expect(getItemMutationFeedback("unavailable")?.message).toBe(
      "Não foi possível salvar o item agora.",
    );
  });
});
