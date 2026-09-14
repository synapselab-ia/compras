import { describe, expect, it } from "vitest";

import {
  getObjectMutationFeedback,
  readObjectMutationUiState,
} from "./object-feedback";

describe("object mutation feedback", () => {
  it("accepts only the five explicit sanitized UI states", () => {
    for (const state of [
      "updated",
      "unchanged",
      "conflict",
      "not-available",
      "unavailable",
    ] as const) {
      expect(readObjectMutationUiState(state)).toBe(state);
    }

    expect(readObjectMutationUiState("postgresql://secret.invalid/private")).toBeNull();
    expect(readObjectMutationUiState(["updated", "conflict"])).toBeNull();
    expect(readObjectMutationUiState(undefined)).toBeNull();
  });

  it("keeps denial feedback generic and technical failures sanitized", () => {
    expect(getObjectMutationFeedback("not-available")?.message).toBe(
      "A alteração do objeto não está disponível para este registro.",
    );
    expect(getObjectMutationFeedback("unavailable")?.message).toBe(
      "Não foi possível salvar o objeto agora.",
    );

    const serialized = JSON.stringify([
      getObjectMutationFeedback("not-available"),
      getObjectMutationFeedback("unavailable"),
    ]);
    expect(serialized).not.toContain("SQL");
    expect(serialized).not.toContain("connection");
    expect(serialized).not.toContain("team");
  });

  it("tells stale writers to review the reloaded object instead of implying overwrite", () => {
    const feedback = getObjectMutationFeedback("conflict");
    expect(feedback?.role).toBe("alert");
    expect(feedback?.message).toContain("mudou desde sua leitura");
    expect(feedback?.message).toContain("recarregado");
  });
});
