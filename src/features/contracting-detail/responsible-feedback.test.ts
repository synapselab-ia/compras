import { describe, expect, it } from "vitest";

import {
  getResponsibleMutationFeedback,
  readResponsibleMutationUiState,
} from "./responsible-feedback";

describe("responsible mutation feedback", () => {
  it.each([
    "updated",
    "unchanged",
    "conflict",
    "not-available",
    "unavailable",
  ] as const)("accepts only the fixed state %s", (state) => {
    expect(readResponsibleMutationUiState(state)).toBe(state);
    expect(getResponsibleMutationFeedback(state)?.message).not.toContain("uuid");
  });

  it("rejects duplicated or attacker-controlled query values", () => {
    expect(readResponsibleMutationUiState(["updated", "updated"])).toBeNull();
    expect(readResponsibleMutationUiState("cross-team")).toBeNull();
    expect(readResponsibleMutationUiState(undefined)).toBeNull();
  });
});
