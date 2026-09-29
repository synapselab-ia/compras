import { describe, expect, it } from "vitest";

import {
  getManualTimelineNoteCreationFeedback,
  readManualTimelineNoteCreationUiState,
} from "./manual-timeline-note-create-feedback";

describe("manual timeline note feedback", () => {
  it("accepts only fixed public states", () => {
    expect(readManualTimelineNoteCreationUiState("created")).toBe("created");
    expect(readManualTimelineNoteCreationUiState("already-added")).toBe("already-added");
    expect(readManualTimelineNoteCreationUiState("not-available")).toBe("not-available");
    expect(readManualTimelineNoteCreationUiState("unavailable")).toBe("unavailable");
    expect(readManualTimelineNoteCreationUiState("sql: secret")).toBeNull();
    expect(readManualTimelineNoteCreationUiState(["created"])).toBeNull();
  });

  it("returns fixed sanitized messages", () => {
    expect(getManualTimelineNoteCreationFeedback("unavailable")?.message).toBe(
      "Não foi possível adicionar a nota agora. Tente novamente.",
    );
  });
});
