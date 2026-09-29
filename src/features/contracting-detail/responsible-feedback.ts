export type ResponsibleMutationUiState =
  | "updated"
  | "unchanged"
  | "conflict"
  | "not-available"
  | "unavailable";

export type ResponsibleMutationFeedback = Readonly<{
  state: ResponsibleMutationUiState;
  message: string;
  role: "status" | "alert";
}>;

const FEEDBACK: Record<ResponsibleMutationUiState, ResponsibleMutationFeedback> = {
  updated: {
    state: "updated",
    message: "Responsável atualizado.",
    role: "status",
  },
  unchanged: {
    state: "unchanged",
    message: "Nenhuma alteração de responsável foi necessária.",
    role: "status",
  },
  conflict: {
    state: "conflict",
    message: "O responsável mudou desde sua leitura. O estado atual foi recarregado; revise antes de salvar novamente.",
    role: "alert",
  },
  "not-available": {
    state: "not-available",
    message: "A alteração de responsável não está disponível para este registro.",
    role: "alert",
  },
  unavailable: {
    state: "unavailable",
    message: "Não foi possível salvar o responsável agora.",
    role: "alert",
  },
};

export function readResponsibleMutationUiState(
  value: string | string[] | undefined,
): ResponsibleMutationUiState | null {
  if (typeof value !== "string") {
    return null;
  }

  return Object.prototype.hasOwnProperty.call(FEEDBACK, value)
    ? (value as ResponsibleMutationUiState)
    : null;
}

export function getResponsibleMutationFeedback(
  state: ResponsibleMutationUiState | null,
): ResponsibleMutationFeedback | null {
  return state ? FEEDBACK[state] : null;
}
