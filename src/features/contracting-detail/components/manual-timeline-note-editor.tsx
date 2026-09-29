import { createPersistentManualTimelineNoteAction } from "../actions";
import {
  getManualTimelineNoteCreationFeedback,
  type ManualTimelineNoteCreationUiState,
} from "../manual-timeline-note-create-feedback";
import { NextActionSubmitButton } from "./next-action-submit-button";

type Props = Readonly<{
  contractingId: string;
  eventId: string;
  state?: ManualTimelineNoteCreationUiState | null;
}>;

export function ManualTimelineNoteEditor({ contractingId, eventId, state = null }: Props) {
  const feedback = getManualTimelineNoteCreationFeedback(state);
  const baseId = "manual-timeline-note";
  const helpId = `${baseId}-help`;

  return (
    <div className="item-create-editor" aria-labelledby={`${baseId}-title`}>
      <h3 id={`${baseId}-title`} className="item-create-title">Adicionar nota</h3>
      {feedback ? (
        <p
          className={`next-action-feedback next-action-feedback-${feedback.state}`}
          role={feedback.role}
          aria-live="polite"
        >
          {feedback.message}
        </p>
      ) : null}
      <form action={createPersistentManualTimelineNoteAction} className="next-action-form">
        <input type="hidden" name="contractingId" value={contractingId} />
        <input type="hidden" name="eventId" value={eventId} />

        <label htmlFor={`${baseId}-kind`}>Estado da nota</label>
        <select id={`${baseId}-kind`} name="noteKind" defaultValue="text">
          <option value="text">Texto</option>
          <option value="null">Ausente (NULL)</option>
        </select>

        <label htmlFor={`${baseId}-text`}>Nota</label>
        <textarea
          id={`${baseId}-text`}
          name="note"
          rows={4}
          autoComplete="off"
          aria-describedby={helpId}
        />
        <p id={helpId} className="next-action-help">
          NULL e texto são estados distintos. Texto vazio e espaços são preservados exatamente.
        </p>
        <div className="next-action-actions">
          <NextActionSubmitButton label="Adicionar nota" pendingLabel="Adicionando…" />
        </div>
      </form>
    </div>
  );
}
