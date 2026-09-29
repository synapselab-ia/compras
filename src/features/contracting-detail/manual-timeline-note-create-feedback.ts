export type ManualTimelineNoteCreationUiState =
  | "created"
  | "already-added"
  | "not-available"
  | "unavailable";

export type ManualTimelineNoteCreationFeedback = Readonly<{
  state: ManualTimelineNoteCreationUiState;
  message: string;
  role: "status" | "alert";
}>;

const FEEDBACK: Record<
  ManualTimelineNoteCreationUiState,
  ManualTimelineNoteCreationFeedback
> = {
  created: {
    state: "created",
    message: "Nota adicionada à atividade.",
    role: "status",
  },
  "already-added": {
    state: "already-added",
    message: "A mesma solicitação de nota já foi concluída.",
    role: "status",
  },
  "not-available": {
    state: "not-available",
    message: "A inclusão de nota não está disponível para este registro.",
    role: "alert",
  },
  unavailable: {
    state: "unavailable",
    message: "Não foi possível adicionar a nota agora. Tente novamente.",
    role: "alert",
  },
};

export function readManualTimelineNoteCreationUiState(
  value: string | string[] | undefined,
): ManualTimelineNoteCreationUiState | null {
  if (typeof value !== "string") return null;
  return Object.prototype.hasOwnProperty.call(FEEDBACK, value)
    ? (value as ManualTimelineNoteCreationUiState)
    : null;
}

export function getManualTimelineNoteCreationFeedback(
  state: ManualTimelineNoteCreationUiState | null,
): ManualTimelineNoteCreationFeedback | null {
  return state ? FEEDBACK[state] : null;
}
