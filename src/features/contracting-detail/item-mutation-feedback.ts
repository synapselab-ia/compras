export type ItemMutationUiState =
  | "updated"
  | "unchanged"
  | "conflict"
  | "not-available"
  | "unavailable";

export type ItemMutationFeedback = Readonly<{
  state: ItemMutationUiState;
  message: string;
  role: "status" | "alert";
}>;

const FEEDBACK: Record<ItemMutationUiState, ItemMutationFeedback> = {
  updated: {
    state: "updated",
    message: "Item atualizado.",
    role: "status",
  },
  unchanged: {
    state: "unchanged",
    message: "Nenhuma alteração no item foi necessária.",
    role: "status",
  },
  conflict: {
    state: "conflict",
    message: "O item mudou desde sua leitura. Os valores atuais foram recarregados; revise antes de salvar novamente.",
    role: "alert",
  },
  "not-available": {
    state: "not-available",
    message: "A alteração do item não está disponível para este registro.",
    role: "alert",
  },
  unavailable: {
    state: "unavailable",
    message: "Não foi possível salvar o item agora.",
    role: "alert",
  },
};

export function readItemMutationUiState(
  value: string | string[] | undefined,
): ItemMutationUiState | null {
  if (typeof value !== "string") {
    return null;
  }

  return Object.prototype.hasOwnProperty.call(FEEDBACK, value)
    ? (value as ItemMutationUiState)
    : null;
}

export function getItemMutationFeedback(
  state: ItemMutationUiState | null,
): ItemMutationFeedback | null {
  return state ? FEEDBACK[state] : null;
}
