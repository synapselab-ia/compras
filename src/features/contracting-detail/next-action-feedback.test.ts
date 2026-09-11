import { describe, expect, it } from "vitest";

import {
  getNextActionMutationFeedback,
  readNextActionMutationUiState,
} from "./next-action-feedback";

describe("next-action mutation feedback", () => {
  it("accepts only the five explicit sanitized UI states", () => {
    for (const state of [
      "updated",
      "unchanged",
      "conflict",
      "not-available",
      "unavailable",
    ] as const) {
      expect(readNextActionMutationUiState(state)).toBe(state);
    }

    expect(readNextActionMutationUiState("postgresql://secret.invalid/private")).toBeNull();
    expect(readNextActionMutationUiState(["updated", "conflict"])).toBeNull();
    expect(readNextActionMutationUiState(undefined)).toBeNull();
  });

  it("keeps cross-team/not-found feedback generic and technical failures sanitized", () => {
    expect(getNextActionMutationFeedback("not-available")?.message).toBe(
      "A alteração não está disponível para este registro.",
    );
    expect(getNextActionMutationFeedback("unavailable")?.message).toBe(
      "Não foi possível salvar a próxima ação agora.",
    );

    const serialized = JSON.stringify([
      getNextActionMutationFeedback("not-available"),
      getNextActionMutationFeedback("unavailable"),
    ]);
    expect(serialized).not.toContain("SQL");
    expect(serialized).not.toContain("connection");
    expect(serialized).not.toContain("team");
  });

  it("tells stale writers to review the reloaded value instead of implying overwrite", () => {
    const feedback = getNextActionMutationFeedback("conflict");
    expect(feedback?.role).toBe("alert");
    expect(feedback?.message).toContain("mudou desde sua leitura");
    expect(feedback?.message).toContain("recarregado");
  });
});
