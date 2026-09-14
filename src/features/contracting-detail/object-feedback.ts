export type ObjectMutationUiState =
  | "updated"
  | "unchanged"
  | "conflict"
  | "not-available"
  | "unavailable";

export type ObjectMutationFeedback = Readonly<{
  state: ObjectMutationUiState;
  message: string;
  role: "status" | "alert";
}>;

const FEEDBACK: Record<ObjectMutationUiState, ObjectMutationFeedback> = {
  updated: {
    state: "updated",
    message: "Objeto atualizado.",
    role: "status",
  },
  unchanged: {
    state: "unchanged",
    message: "Nenhuma alteração no objeto foi necessária.",
    role: "status",
  },
  conflict: {
    state: "conflict",
    message: "O objeto mudou desde sua leitura. O estado atual foi recarregado; revise antes de salvar novamente.",
    role: "alert",
  },
  "not-available": {
    state: "not-available",
    message: "A alteração do objeto não está disponível para este registro.",
    role: "alert",
  },
  unavailable: {
    state: "unavailable",
    message: "Não foi possível salvar o objeto agora.",
    role: "alert",
  },
};

export function readObjectMutationUiState(
  value: string | string[] | undefined,
): ObjectMutationUiState | null {
  if (typeof value !== "string") {
    return null;
  }

  return Object.prototype.hasOwnProperty.call(FEEDBACK, value)
    ? (value as ObjectMutationUiState)
    : null;
}

export function getObjectMutationFeedback(
  state: ObjectMutationUiState | null,
): ObjectMutationFeedback | null {
  return state ? FEEDBACK[state] : null;
}
