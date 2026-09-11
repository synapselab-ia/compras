export type NextActionMutationUiState =
  | "updated"
  | "unchanged"
  | "conflict"
  | "not-available"
  | "unavailable";

export type NextActionMutationFeedback = Readonly<{
  state: NextActionMutationUiState;
  message: string;
  role: "status" | "alert";
}>;

const FEEDBACK: Record<NextActionMutationUiState, NextActionMutationFeedback> = {
  updated: {
    state: "updated",
    message: "Próxima ação atualizada.",
    role: "status",
  },
  unchanged: {
    state: "unchanged",
    message: "Nenhuma alteração foi necessária.",
    role: "status",
  },
  conflict: {
    state: "conflict",
    message: "A próxima ação mudou desde sua leitura. O estado atual foi recarregado; revise antes de salvar novamente.",
    role: "alert",
  },
  "not-available": {
    state: "not-available",
    message: "A alteração não está disponível para este registro.",
    role: "alert",
  },
  unavailable: {
    state: "unavailable",
    message: "Não foi possível salvar a próxima ação agora.",
    role: "alert",
  },
};

export function readNextActionMutationUiState(
  value: string | string[] | undefined,
): NextActionMutationUiState | null {
  if (typeof value !== "string") {
    return null;
  }

  return Object.prototype.hasOwnProperty.call(FEEDBACK, value)
    ? (value as NextActionMutationUiState)
    : null;
}

export function getNextActionMutationFeedback(
  state: NextActionMutationUiState | null,
): NextActionMutationFeedback | null {
  return state ? FEEDBACK[state] : null;
}
