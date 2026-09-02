import Link from "next/link";
import type {
  ContractingDetailPresentation,
  ContractingDetailSource,
} from "../types";

type ContractingDetailProps = Readonly<{
  detail: ContractingDetailPresentation;
  source: ContractingDetailSource;
}>;

export function ContractingDetail({ detail, source }: ContractingDetailProps) {
  const isDemo = source === "demo";

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
            <strong>Leitura persistente autorizada, somente leitura.</strong>
            <span>O detalhe usa a sessão server-side e as policies do banco; nenhuma ação nesta tela grava dados.</span>
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
          <p className="eyebrow">Contratação · {isDemo ? "demonstração" : "leitura server-side"}</p>
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
          {detail.items.length > 0 ? (
            <ul className="demo-list">
              {detail.items.map((item) => (
                <li key={item.id}>
                  <p className="demo-item-id">{item.id}</p>
                  <strong>{item.label}</strong>
                  <span>{item.note}</span>
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
