export type FoundationStatus = Readonly<{
  label: string;
  value: string;
}>;

const FOUNDATION_STATE: readonly FoundationStatus[] = [
  { label: "Aplicação", value: "Fundação executável" },
  { label: "Dados", value: "Somente conteúdo neutro" },
  { label: "Integrações", value: "Não configuradas" },
];

export function getFoundationState(): readonly FoundationStatus[] {
  return FOUNDATION_STATE;
}
