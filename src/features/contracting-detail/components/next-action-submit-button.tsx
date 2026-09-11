"use client";

import { useFormStatus } from "react-dom";

type NextActionSubmitButtonProps = Readonly<{
  label: string;
  pendingLabel: string;
  variant?: "primary" | "secondary";
}>;

export function NextActionSubmitButton({
  label,
  pendingLabel,
  variant = "primary",
}: NextActionSubmitButtonProps) {
  const { pending } = useFormStatus();

  return (
    <button
      className={`next-action-submit next-action-submit-${variant}`}
      type="submit"
      disabled={pending}
      aria-disabled={pending}
    >
      {pending ? pendingLabel : label}
    </button>
  );
}
