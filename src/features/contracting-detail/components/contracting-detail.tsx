import Link from "next/link";

import {
  createPersistentContractingItemAction,
  updatePersistentContractingItemAction,
  updatePersistentNextActionAction,
  updatePersistentObjectAction,
} from "../actions";
import {
  getItemCreationFeedback,
  type ItemCreationUiState,
} from "../item-create-feedback";
import {
  getItemMutationFeedback,
  type ItemMutationUiState,
} from "../item-mutation-feedback";
import {
  getNextActionMutationFeedback,
  type NextActionMutationUiState,
} from "../next-action-feedback";
import {
  getObjectMutationFeedback,
  type ObjectMutationUiState,
} from "../object-feedback";
import type {
  ContractingDetailPresentation,
  ContractingDetailSource,
  ContractingItemPresentation,
} from "../types";
import { NextActionSubmitButton } from "./next-action-submit-button";

type ContractingDetailProps = Readonly<{
  detail: ContractingDetailPresentation;
  source: ContractingDetailSource;
  mutationState?: NextActionMutationUiState | null;
  objectMutationState?: ObjectMutationUiState | null;
  itemCreationState?: ItemCreationUiState | null;
  itemMutationState?: ItemMutationUiState | null;
}>;

type ItemMutationEditorProps = Readonly<{
  contractingId: string;
  item: ContractingItemPresentation;
}>;

function ItemMutationEditor({ contractingId, item }: ItemMutationEditorProps) {
  const snapshot = item.mutationSnapshot;

  if (!snapshot) {
    return null;
  }

  const editorId = `item-mutation-${item.id}`;
  const descriptionId = `${editorId}-description`;
  const quantityId = `${editorId}-quantity`;
  const unitKindId = `${editorId}-unit-kind`;
  const unitId = `${editorId}-unit`;
  const catalogKindId = `${editorId}-catalog-kind`;
  const catalogId = `${editorId}-catalog`;
  const helpId = `${editorId}-help`;

  return (
    <div className="item-create-editor" aria-labelledby={`${editorId}-title`}>
      <h3 id={`${editorId}-title`} className="item-create-title">Editar item</h3>
      <form action={updatePersistentContractingItemAction} className="next-action-form">
        <input type="hidden" name="contractingId" value={contractingId} />
        <input type="hidden" name="itemId" value={item.id} />
        <input
          type="hidden"
          name="expectedDescription"
          value={snapshot.description}
        />
        {snapshot.quantity !== null ? (
          <input type="hidden" name="expectedQuantity" value={snapshot.quantity} />
        ) : null}
        <input
          type="hidden"
          name="expectedUnitKind"
          value={snapshot.unit === null ? "null" : "text"}
        />
        <input type="hidden" name="expectedUnit" value={snapshot.unit ?? ""} />
        <input
          type="hidden"
          name="expectedCatalogCodeKind"
          value={snapshot.catalogCode === null ? "null" : "text"}
        />
        <input
          type="hidden"
          name="expectedCatalogCode"
          value={snapshot.catalogCode ?? ""}
        />

        <label htmlFor={descriptionId}>Descrição</label>
        <textarea
          id={descriptionId}
          name="newDescription"
          rows={3}
          defaultValue={snapshot.description}
          aria-describedby={helpId}
        />

        <label htmlFor={quantityId}>Quantidade opcional</label>
        <input
          id={quantityId}
          name="newQuantity"
          type="text"
          inputMode="decimal"
          autoComplete="off"
          defaultValue={snapshot.quantity ?? ""}
        />

        <label htmlFor={unitKindId}>Estado da unidade</label>
        <select
          id={unitKindId}
          name="newUnitKind"
          defaultValue={snapshot.unit === null ? "null" : "text"}
        >
          <option value="text">Texto</option>
          <option value="null">Ausente (NULL)</option>
        </select>

        <label htmlFor={unitId}>Unidade</label>
        <input
          id={unitId}
          name="newUnit"
          type="text"
          autoComplete="off"
          defaultValue={snapshot.unit ?? ""}
        />

        <label htmlFor={catalogKindId}>Estado do código de catálogo</label>
        <select
          id={catalogKindId}
          name="newCatalogCodeKind"
          defaultValue={snapshot.catalogCode === null ? "null" : "text"}
        >
          <option value="text">Texto</option>
          <option value="null">Ausente (NULL)</option>
        </select>

        <label htmlFor={catalogId}>Código de catálogo</label>
        <input
          id={catalogId}
          name="newCatalogCode"
          type="text"
          autoComplete="off"
          defaultValue={snapshot.catalogCode ?? ""}
        />

        <p id={helpId} className="next-action-help">
          O snapshot completo é conferido antes da gravação. Texto e NULL são estados distintos para unidade e código; quantidade vazia representa ausência sem conversão numérica no navegador.
        </p>

        <div className="next-action-actions">
          <NextActionSubmitButton
            label="Salvar item"
            pendingLabel="Salvando item…"
          />
        </div>
      </form>
    </div>
  );
}

export function ContractingDetail({
  detail,
  source,
  mutationState = null,
  objectMutationState = null,
  itemCreationState = null,
  itemMutationState = null,
}: ContractingDetailProps) {
  const isDemo = source === "demo";
  const feedback = isDemo ? null : getNextActionMutationFeedback(mutationState);
  const objectFeedback = isDemo ? null : getObjectMutationFeedback(objectMutationState);
  const itemCreationFeedback = isDemo ? null : getItemCreationFeedback(itemCreationState);
  const itemMutationFeedback = isDemo ? null : getItemMutationFeedback(itemMutationState);
  const editorId = `next-action-${detail.id}`;
  const editorHelpId = `${editorId}-help`;
  const feedbackId = `${editorId}-feedback`;
  const describedBy = feedback ? `${editorHelpId} ${feedbackId}` : editorHelpId;
  const objectEditorId = `object-${detail.id}`;
  const objectEditorHelpId = `${objectEditorId}-help`;
  const objectFeedbackId = `${objectEditorId}-feedback`;
  const objectDescribedBy = objectFeedback
    ? `${objectEditorHelpId} ${objectFeedbackId}`
    : objectEditorHelpId;
  const itemEditorId = `item-create-${detail.id}`;
  const itemDescriptionId = `${itemEditorId}-description`;
  const itemQuantityId = `${itemEditorId}-quantity`;
  const itemUnitId = `${itemEditorId}-unit`;
  const itemCatalogCodeId = `${itemEditorId}-catalog-code`;
  const itemHelpId = `${itemEditorId}-help`;
  const itemFeedbackId = `${itemEditorId}-feedback`;
  const itemMutationFeedbackId = `item-mutation-${detail.id}-feedback`;
  const itemDescriptionDescribedBy = itemCreationFeedback
    ? `${itemHelpId} ${itemFeedbackId}`
    : itemHelpId;

  return (
    <main className="detail-shell">
      <section className="prototype-banner" role="note" aria-label="Estado da fonte de dados">
        {isDemo ? (
          <>
            <strong>Detalhe demonstrativo com dados fictícios.</strong>
            <span>Persistência operacional desabilitada neste ambiente.</span>
          </>
        ) : (
          <>
            <strong>Dados persistentes autorizados.</strong>
            <span>Objeto, próxima ação, inclusão e edição de item possuem operações restritas; autorização e histórico permanecem no servidor e no banco.</span>
          </>
        )}
      </section>

      <nav className="detail-nav" aria-label="Navegação do detalhe">
        <Link className="back-link" href="/">
          ← Voltar para a Central do Setor
        </Link>
      </nav>

      <header className="detail-header">
        <div className="detail-heading-main">
          <p className="eyebrow">Contratação · {isDemo ? "demonstração" : "dados persistentes"}</p>
          <p className="detail-id">{detail.id}</p>
          <h1>{detail.object}</h1>
          <p className="lead">
            Etapa, status e tipos relacionados continuam provisórios enquanto as taxonomias finais permanecem em aberto.
          </p>
        </div>
        <span className="status-badge detail-status">{detail.status}</span>
      </header>

      <section className="detail-summary" aria-labelledby="operational-context-title">
        <div className="detail-section-heading">
          <div>
            <p className="section-kicker">Contexto essencial</p>
            <h2 id="operational-context-title">Estado operacional</h2>
          </div>
          <p className="provisional-note">O identificador da rota localiza o recurso; a autorização permanece no servidor e no RLS.</p>
        </div>

        <dl className="detail-meta-grid">
          <div>
            <dt>Responsável</dt>
            <dd>{detail.responsible}</dd>
          </div>
          <div>
            <dt>Etapa provisória</dt>
            <dd>{detail.stage}</dd>
          </div>
          <div>
            <dt>Aguardando</dt>
            <dd>{detail.waitingOn}</dd>
          </div>
          <div>
            <dt>Desde</dt>
            <dd>{detail.waitingSince}</dd>
          </div>
          <div>
            <dt>Motivo</dt>
            <dd>{detail.waitingReason}</dd>
          </div>
          <div>
            <dt>Última movimentação</dt>
            <dd>{detail.lastMovement}</dd>
          </div>
          <div>
            <dt>Criada em</dt>
            <dd>{detail.createdAt}</dd>
          </div>
          <div className="detail-meta-wide">
            <dt>Próxima ação</dt>
            <dd>{detail.nextAction}</dd>
          </div>
        </dl>
      </section>

      {!isDemo ? (
        <section className="detail-panel next-action-editor" aria-labelledby={`${objectEditorId}-title`}>
          <div className="detail-section-heading compact-heading">
            <div>
              <p className="section-kicker">Edição restrita</p>
              <h2 id={`${objectEditorId}-title`}>Objeto</h2>
            </div>
          </div>

          <p className="next-action-current">
            <strong>Valor atual:</strong>{" "}
            <span style={{ whiteSpace: "pre-wrap" }}>{detail.object}</span>
          </p>

          {objectFeedback ? (
            <p
              id={objectFeedbackId}
              className={`next-action-feedback next-action-feedback-${objectFeedback.state}`}
              role={objectFeedback.role}
              aria-live="polite"
            >
              {objectFeedback.message}
            </p>
          ) : null}

          <form action={updatePersistentObjectAction} className="next-action-form">
            <input type="hidden" name="contractingId" value={detail.id} />
            <input type="hidden" name="expectedObject" value={detail.object} />

            <label htmlFor={objectEditorId}>Objeto</label>
            <textarea
              id={objectEditorId}
              name="newObject"
              rows={4}
              defaultValue={detail.object}
              aria-describedby={objectDescribedBy}
            />
            <p id={objectEditorHelpId} className="next-action-help">
              O texto é preservado exatamente como informado. String vazia e espaços são mantidos sem trim ou normalização.
            </p>

            <div className="next-action-actions">
              <NextActionSubmitButton
                label="Salvar objeto"
                pendingLabel="Salvando…"
              />
            </div>
          </form>
        </section>
      ) : null}

      {!isDemo ? (
        <section className="detail-panel next-action-editor" aria-labelledby={`${editorId}-title`}>
          <div className="detail-section-heading compact-heading">
            <div>
              <p className="section-kicker">Edição restrita</p>
              <h2 id={`${editorId}-title`}>Próxima ação</h2>
            </div>
          </div>

          <p className="next-action-current">
            <strong>Valor atual:</strong> {detail.nextAction}
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

          <form action={updatePersistentNextActionAction} className="next-action-form">
            <input type="hidden" name="contractingId" value={detail.id} />
            {detail.nextActionValue !== null ? (
              <input type="hidden" name="expectedNextAction" value={detail.nextActionValue} />
            ) : null}

            <label htmlFor={editorId}>Próxima ação</label>
            <textarea
              id={editorId}
              name="newNextAction"
              rows={4}
              defaultValue={detail.nextActionValue ?? ""}
              aria-describedby={describedBy}
            />
            <p id={editorHelpId} className="next-action-help">
              O texto é preservado como informado. Para remover o valor, use “Limpar próxima ação”.
            </p>

            <div className="next-action-actions">
              <NextActionSubmitButton
                label="Salvar próxima ação"
                pendingLabel="Salvando…"
              />
            </div>
          </form>

          <form action={updatePersistentNextActionAction} className="next-action-clear-form">
            <input type="hidden" name="contractingId" value={detail.id} />
            {detail.nextActionValue !== null ? (
              <input type="hidden" name="expectedNextAction" value={detail.nextActionValue} />
            ) : null}
            <NextActionSubmitButton
              label="Limpar próxima ação"
              pendingLabel="Limpando…"
              variant="secondary"
            />
          </form>
        </section>
      ) : null}

      <div className="detail-content-grid">
        <section className="detail-panel" aria-labelledby="related-identifiers-title">
          <div className="detail-section-heading compact-heading">
            <div>
              <p className="section-kicker">Relacionamentos</p>
              <h2 id="related-identifiers-title">Identificadores relacionados</h2>
            </div>
          </div>
          <p className="detail-panel-note">Tipos permanecem extensíveis e não constituem catálogo definitivo.</p>
          {detail.relatedIdentifiers.length > 0 ? (
            <dl className="demo-definition-list">
              {detail.relatedIdentifiers.map((identifier) => (
                <div key={identifier.id}>
                  <dt>{identifier.label}</dt>
                  <dd>{identifier.value}</dd>
                  {identifier.note ? <dd>{identifier.note}</dd> : null}
                </div>
              ))}
            </dl>
          ) : (
            <p className="detail-panel-note">Nenhum identificador ativo disponível.</p>
          )}
        </section>

        <section className="detail-panel" aria-labelledby="items-title">
          <div className="detail-section-heading compact-heading">
            <div>
              <p className="section-kicker">Itens</p>
              <h2 id="items-title">Itens ativos</h2>
            </div>
          </div>

          {itemMutationFeedback ? (
            <p
              id={itemMutationFeedbackId}
              className={`next-action-feedback next-action-feedback-${itemMutationFeedback.state}`}
              role={itemMutationFeedback.role}
              aria-live="polite"
            >
              {itemMutationFeedback.message}
            </p>
          ) : null}

          {!isDemo ? (
            <div className="item-create-editor" aria-labelledby={`${itemEditorId}-title`}>
              <h3 id={`${itemEditorId}-title`} className="item-create-title">Adicionar item</h3>

              {itemCreationFeedback ? (
                <p
                  id={itemFeedbackId}
                  className={`next-action-feedback next-action-feedback-${itemCreationFeedback.state}`}
                  role={itemCreationFeedback.role}
                  aria-live="polite"
                >
                  {itemCreationFeedback.message}
                </p>
              ) : null}

              <form action={createPersistentContractingItemAction} className="next-action-form">
                <input type="hidden" name="contractingId" value={detail.id} />

                <label htmlFor={itemDescriptionId}>Descrição</label>
                <textarea
                  id={itemDescriptionId}
                  name="description"
                  rows={3}
                  aria-describedby={itemDescriptionDescribedBy}
                />

                <label htmlFor={itemQuantityId}>Quantidade opcional</label>
                <input
                  id={itemQuantityId}
                  name="quantity"
                  type="text"
                  inputMode="decimal"
                  autoComplete="off"
                />

                <label htmlFor={itemUnitId}>Unidade opcional</label>
                <input
                  id={itemUnitId}
                  name="unit"
                  type="text"
                  autoComplete="off"
                />

                <label htmlFor={itemCatalogCodeId}>Código de catálogo opcional</label>
                <input
                  id={itemCatalogCodeId}
                  name="catalogCode"
                  type="text"
                  autoComplete="off"
                />

                <p id={itemHelpId} className="next-action-help">
                  Descrição, unidade e código são preservados exatamente. Quantidade vazia representa ausência; qualquer texto informado segue sem conversão numérica no navegador.
                </p>

                <div className="next-action-actions">
                  <NextActionSubmitButton
                    label="Adicionar item"
                    pendingLabel="Adicionando…"
                  />
                </div>
              </form>
            </div>
          ) : null}

          {detail.items.length > 0 ? (
            <ul className="demo-list">
              {detail.items.map((item) => (
                <li key={item.id}>
                  <p className="demo-item-id">{item.id}</p>
                  <strong>{item.label}</strong>
                  <span>{item.note}</span>
                  {!isDemo && item.mutationSnapshot ? (
                    <ItemMutationEditor contractingId={detail.id} item={item} />
                  ) : null}
                </li>
              ))}
            </ul>
          ) : (
            <p className="detail-panel-note">Nenhum item ativo disponível.</p>
          )}
        </section>

        <section className="detail-panel detail-panel-wide" aria-labelledby="activity-title">
          <div className="detail-section-heading compact-heading">
            <div>
              <p className="section-kicker">Histórico</p>
              <h2 id="activity-title">Atividade recente</h2>
            </div>
          </div>
          {detail.activity.length > 0 ? (
            <ol className="activity-list">
              {detail.activity.map((activity) => (
                <li key={activity.id}>
                  <div className="activity-marker" aria-hidden="true" />
                  <div>
                    <p className="activity-moment">{activity.moment}</p>
                    <strong>{activity.label}</strong>
                    <span>{activity.note ?? activity.id}</span>
                  </div>
                </li>
              ))}
            </ol>
          ) : (
            <p className="detail-panel-note">Nenhuma movimentação registrada.</p>
          )}
        </section>
      </div>
    </main>
  );
}
