export type ContractingCreateUiState =
  | "created"
  | "already-created"
  | "not-available"
  | "unavailable";

export type ContractingCreateFeedback = Readonly<{
  state: ContractingCreateUiState;
  message: string;
  role: "status" | "alert";
}>;

const FEEDBACK: Record<ContractingCreateUiState, ContractingCreateFeedback> = {
  created: {
    state: "created",
    message: "Contratação cadastrada.",
    role: "status",
  },
  "already-created": {
    state: "already-created",
    message: "Esta solicitação de cadastro já havia sido concluída.",
    role: "status",
  },
  "not-available": {
    state: "not-available",
    message: "O cadastro não está disponível para esta solicitação.",
    role: "alert",
  },
  unavailable: {
    state: "unavailable",
    message: "Não foi possível cadastrar a contratação agora.",
    role: "alert",
  },
};

export function readContractingCreateUiState(
  value: string | string[] | undefined,
): ContractingCreateUiState | null {
  if (typeof value !== "string") {
    return null;
  }

  return Object.prototype.hasOwnProperty.call(FEEDBACK, value)
    ? (value as ContractingCreateUiState)
    : null;
}

export function getContractingCreateFeedback(
  state: ContractingCreateUiState | null,
): ContractingCreateFeedback | null {
  return state ? FEEDBACK[state] : null;
}
