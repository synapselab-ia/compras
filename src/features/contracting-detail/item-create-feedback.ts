export type ItemCreationUiState = "created" | "not-available" | "unavailable";

export type ItemCreationFeedback = Readonly<{
  state: ItemCreationUiState;
  message: string;
  role: "status" | "alert";
}>;

const FEEDBACK: Record<ItemCreationUiState, ItemCreationFeedback> = {
  created: {
    state: "created",
    message: "Item adicionado.",
    role: "status",
  },
  "not-available": {
    state: "not-available",
    message: "A criação de item não está disponível para este registro.",
    role: "alert",
  },
  unavailable: {
    state: "unavailable",
    message: "Não foi possível adicionar o item agora.",
    role: "alert",
  },
};

export function readItemCreationUiState(
  value: string | string[] | undefined,
): ItemCreationUiState | null {
  if (typeof value !== "string") {
    return null;
  }

  return Object.prototype.hasOwnProperty.call(FEEDBACK, value)
    ? (value as ItemCreationUiState)
    : null;
}

export function getItemCreationFeedback(
  state: ItemCreationUiState | null,
): ItemCreationFeedback | null {
  return state ? FEEDBACK[state] : null;
}
