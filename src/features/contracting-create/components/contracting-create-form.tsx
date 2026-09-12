import { createPersistentContractingAction } from "../actions";
import {
  getContractingCreateFeedback,
  type ContractingCreateUiState,
} from "../feedback";
import { ContractingCreateSubmitButton } from "./contracting-create-submit-button";

type ContractingCreateFormProps = Readonly<{
  contractingId: string;
  creationState?: ContractingCreateUiState | null;
}>;

export function ContractingCreateForm({
  contractingId,
  creationState = null,
}: ContractingCreateFormProps) {
  const feedback = getContractingCreateFeedback(creationState);
  const objectId = `contracting-object-${contractingId}`;
  const helpId = `${objectId}-help`;
  const feedbackId = `${objectId}-feedback`;
  const describedBy = feedback ? `${helpId} ${feedbackId}` : helpId;

  return (
    <section className="detail-panel contracting-create-panel" aria-labelledby="contracting-create-title">
      <div className="detail-section-heading compact-heading">
        <div>
          <p className="section-kicker">Cadastro mínimo</p>
          <h2 id="contracting-create-title">Nova contratação</h2>
        </div>
      </div>

      <p className="detail-panel-note">
        Nesta etapa, somente o objeto é informado. Equipe, autoria e escopo são derivados no servidor e no banco.
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

      <form action={createPersistentContractingAction} className="next-action-form">
        <input type="hidden" name="contractingId" value={contractingId} />

        <label htmlFor={objectId}>Objeto</label>
        <textarea
          id={objectId}
          name="object"
          rows={5}
          aria-describedby={describedBy}
        />
        <p id={helpId} className="next-action-help">
          O texto é preservado exatamente como informado. Demais campos operacionais serão tratados em etapas próprias.
        </p>

        <div className="next-action-actions">
          <ContractingCreateSubmitButton />
        </div>
      </form>
    </section>
  );
}
