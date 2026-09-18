export type RelatedIdentifierCreationUiState =
  | "created"
  | "already-linked"
  | "not-available"
  | "unavailable";

export type RelatedIdentifierCreationFeedback = Readonly<{
  state: RelatedIdentifierCreationUiState;
  message: string;
  role: "status" | "alert";
}>;

const FEEDBACK: Record<
  RelatedIdentifierCreationUiState,
  RelatedIdentifierCreationFeedback
> = {
  created: {
    state: "created",
    message: "Identificador relacionado vinculado.",
    role: "status",
  },
  "already-linked": {
    state: "already-linked",
    message: "A mesma solicitação de vínculo já foi concluída.",
    role: "status",
  },
  "not-available": {
    state: "not-available",
    message: "O vínculo de identificador não está disponível para este registro.",
    role: "alert",
  },
  unavailable: {
    state: "unavailable",
    message: "Não foi possível vincular o identificador agora. Tente novamente.",
    role: "alert",
  },
};

export function readRelatedIdentifierCreationUiState(
  value: string | string[] | undefined,
): RelatedIdentifierCreationUiState | null {
  if (typeof value !== "string") {
    return null;
  }

  return Object.prototype.hasOwnProperty.call(FEEDBACK, value)
    ? (value as RelatedIdentifierCreationUiState)
    : null;
}

export function getRelatedIdentifierCreationFeedback(
  state: RelatedIdentifierCreationUiState | null,
): RelatedIdentifierCreationFeedback | null {
  return state ? FEEDBACK[state] : null;
}
