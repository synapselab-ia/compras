import { describe, expect, it } from "vitest";

import {
  getRelatedIdentifierCreationFeedback,
  readRelatedIdentifierCreationUiState,
} from "./related-identifier-create-feedback";

describe("related identifier creation feedback", () => {
  it("accepts only the four sanitized F41 outcomes", () => {
    for (const state of [
      "created",
      "already-linked",
      "not-available",
      "unavailable",
    ] as const) {
      expect(readRelatedIdentifierCreationUiState(state)).toBe(state);
      expect(getRelatedIdentifierCreationFeedback(state)?.state).toBe(state);
    }
  });

  it("rejects arrays, internal outcomes and arbitrary technical strings", () => {
    expect(
      readRelatedIdentifierCreationUiState(["created", "unavailable"]),
    ).toBeNull();
    expect(readRelatedIdentifierCreationUiState("denied")).toBeNull();
    expect(
      readRelatedIdentifierCreationUiState("postgresql://secret.invalid/db"),
    ).toBeNull();
    expect(readRelatedIdentifierCreationUiState(undefined)).toBeNull();
    expect(getRelatedIdentifierCreationFeedback(null)).toBeNull();
  });

  it("keeps protected denial and technical failure feedback generic", () => {
    const serialized = JSON.stringify([
      getRelatedIdentifierCreationFeedback("not-available"),
      getRelatedIdentifierCreationFeedback("unavailable"),
    ]);

    expect(serialized).not.toContain("cross-team");
    expect(serialized).not.toContain("membership");
    expect(serialized).not.toContain("SQL");
    expect(serialized).not.toContain("claims");
    expect(serialized).not.toContain("postgresql://");
  });
});
