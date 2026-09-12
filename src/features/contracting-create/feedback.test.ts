import { describe, expect, it } from "vitest";

import {
  getContractingCreateFeedback,
  readContractingCreateUiState,
} from "./feedback";

describe("contracting create feedback", () => {
  it("accepts only fixed public result states", () => {
    for (const state of [
      "created",
      "already-created",
      "not-available",
      "unavailable",
    ] as const) {
      expect(readContractingCreateUiState(state)).toBe(state);
    }

    expect(readContractingCreateUiState("postgresql://secret.invalid/db")).toBeNull();
    expect(readContractingCreateUiState(["created", "unavailable"])).toBeNull();
    expect(readContractingCreateUiState(undefined)).toBeNull();
  });

  it("returns only sanitized user-facing messages", () => {
    const serialized = JSON.stringify(
      ["created", "already-created", "not-available", "unavailable"].map((state) =>
        getContractingCreateFeedback(readContractingCreateUiState(state)),
      ),
    );

    expect(serialized).not.toContain("postgresql://");
    expect(serialized).not.toContain("membership");
    expect(serialized).not.toContain("claim");
    expect(serialized).not.toContain("connection");
  });
});
