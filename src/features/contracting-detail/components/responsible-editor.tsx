"use client";

import { useState } from "react";

import { updatePersistentResponsibleAction } from "../actions";
import {
  getResponsibleMutationFeedback,
  type ResponsibleMutationUiState,
} from "../responsible-feedback";
import type { ContractingResponsibleOption } from "../types";
import { NextActionSubmitButton } from "./next-action-submit-button";

type Props = Readonly<{
  contractingId: string;
  currentLabel: string;
  expectedResponsibleMembershipId: string | null;
  options: ContractingResponsibleOption[];
  state?: ResponsibleMutationUiState | null;
}>;

const NONE_SELECTION = "__none__";

export function ResponsibleEditor({
  contractingId,
  currentLabel,
  expectedResponsibleMembershipId,
  options,
  state = null,
}: Props) {
  const expectedIsListed =
    expectedResponsibleMembershipId !== null &&
    options.some((option) => option.membershipId === expectedResponsibleMembershipId);
  const [selection, setSelection] = useState(
    expectedResponsibleMembershipId ?? NONE_SELECTION,
  );
  const feedback = getResponsibleMutationFeedback(state);
  const selectedMembershipId =
    selection === NONE_SELECTION ? null : selection;
  const editorId = "responsible-editor";
  const helpId = `${editorId}-help`;
  const feedbackId = `${editorId}-feedback`;

  return (
    <section
      className="detail-panel next-action-editor"
      aria-labelledby={`${editorId}-title`}
    >
      <div className="detail-section-heading compact-heading">
        <div>
          <p className="section-kicker">Edição restrita</p>
          <h2 id={`${editorId}-title`}>Responsável</h2>
        </div>
      </div>

      <p className="next-action-current">
        <strong>Valor atual:</strong> {currentLabel}
      </p>

      {feedback ? (
        <p
          id={feedbackId}
          className={`next-action-feedback next-action-feedback-${feedback.state}`}
          role={feedback.role}
          aria-live="polite"
        >
          {feedback.message}
        </p>
      ) : null}

      <form action={updatePersistentResponsibleAction} className="next-action-form">
        <input type="hidden" name="contractingId" value={contractingId} />
        <input
          type="hidden"
          name="expectedResponsibleKind"
          value={expectedResponsibleMembershipId === null ? "null" : "membership"}
        />
        {expectedResponsibleMembershipId !== null ? (
          <input
            type="hidden"
            name="expectedResponsibleMembershipId"
            value={expectedResponsibleMembershipId}
          />
        ) : null}

        <input
          type="hidden"
          name="newResponsibleKind"
          value={selectedMembershipId === null ? "null" : "membership"}
        />
        {selectedMembershipId !== null ? (
          <input
            type="hidden"
            name="newResponsibleMembershipId"
            value={selectedMembershipId}
          />
        ) : null}

        <label htmlFor={editorId}>Novo responsável</label>
        <select
          id={editorId}
          value={selection}
          onChange={(event) => setSelection(event.target.value)}
          aria-describedby={helpId}
        >
          <option value={NONE_SELECTION}>Sem responsável</option>
          {expectedResponsibleMembershipId !== null && !expectedIsListed ? (
            <option value={expectedResponsibleMembershipId}>
              Responsável atual não disponível
            </option>
          ) : null}
          {options.map((option) => (
            <option key={option.membershipId} value={option.membershipId}>
              {option.displayName}
            </option>
          ))}
        </select>

        <p id={helpId} className="next-action-help">
          As opções exibidas são somente apresentação. A autorização e a validação do responsável permanecem no servidor e no banco.
        </p>

        <div className="next-action-actions">
          <NextActionSubmitButton
            label="Salvar responsável"
            pendingLabel="Salvando…"
          />
        </div>
      </form>
    </section>
  );
}
