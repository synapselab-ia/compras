import { describe, expect, it } from "vitest";

import {
  getItemCreationFeedback,
  readItemCreationUiState,
} from "./item-create-feedback";

describe("item creation feedback", () => {
  it("accepts only the three sanitized F35 outcomes", () => {
    for (const state of ["created", "not-available", "unavailable"] as const) {
      expect(readItemCreationUiState(state)).toBe(state);
      expect(getItemCreationFeedback(state)?.state).toBe(state);
    }
  });

  it("rejects arrays and unexpected values", () => {
    expect(readItemCreationUiState(["created", "unavailable"])).toBeNull();
    expect(readItemCreationUiState("denied")).toBeNull();
    expect(readItemCreationUiState("postgresql://secret.invalid/db")).toBeNull();
    expect(readItemCreationUiState(undefined)).toBeNull();
    expect(getItemCreationFeedback(null)).toBeNull();
  });

  it("keeps denial and technical failure messages generic", () => {
    const serialized = JSON.stringify([
      getItemCreationFeedback("not-available"),
      getItemCreationFeedback("unavailable"),
    ]);

    expect(serialized).not.toContain("cross-team");
    expect(serialized).not.toContain("membership");
    expect(serialized).not.toContain("SQL");
    expect(serialized).not.toContain("postgresql://");
  });
});
