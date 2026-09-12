"use client";

import { useFormStatus } from "react-dom";

export function ContractingCreateSubmitButton() {
  const { pending } = useFormStatus();

  return (
    <button
      className="next-action-submit next-action-submit-primary"
      type="submit"
      disabled={pending}
      aria-disabled={pending}
    >
      {pending ? "Cadastrando…" : "Cadastrar contratação"}
    </button>
  );
}
