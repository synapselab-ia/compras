import Link from "next/link";
import type { DemoContractingDetail } from "../demo-detail-data";

export function ContractingDetail({ detail }: Readonly<{ detail: DemoContractingDetail }>) {
  return (
    <main className="detail-shell">
      <section className="prototype-banner" role="note" aria-label="Aviso de protótipo">
        <strong>Detalhe demonstrativo com dados fictícios.</strong>
        <span>Sem persistência, sem base interna e sem conexão com sistemas oficiais.</span>
      </section>

      <nav className="detail-nav" aria-label="Navegação do detalhe">
        <Link className="back-link" href="/">
          ← Voltar para a Central do Setor
        </Link>
      </nav>

      <header className="detail-header">
        <div className="detail-heading-main">
          <p className="eyebrow">Contratação demo · estrutura provisória</p>
          <p className="detail-id">{detail.id}</p>
          <h1>{detail.object}</h1>
          <p className="lead">
            Esta tela existe somente para validar a divisão entre fila e detalhe. Labels e relacionamentos abaixo
            não constituem taxonomia ou modelo definitivo.
          </p>
        </div>
        <span className="status-badge detail-status">{detail.status}</span>
      </header>

      <section className="detail-summary" aria-labelledby="operational-context-title">
        <div className="detail-section-heading">
          <div>
            <p className="section-kicker">Contexto essencial</p>
            <h2 id="operational-context-title">Estado operacional demonstrativo</h2>
          </div>
          <p className="provisional-note">Etapa e status continuam sendo valores demo provisórios.</p>
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
            <dt>Última movimentação</dt>
            <dd>{detail.lastMovement}</dd>
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
              <p className="section-kicker">Relacionamentos demo</p>
              <h2 id="related-identifiers-title">Identificadores relacionados</h2>
            </div>
          </div>
          <p className="detail-panel-note">Tipos e significados são apenas exemplos de interface.</p>
          <dl className="demo-definition-list">
            {detail.relatedIdentifiers.map((identifier) => (
              <div key={`${identifier.label}-${identifier.value}`}>
                <dt>{identifier.label}</dt>
                <dd>{identifier.value}</dd>
              </div>
            ))}
          </dl>
        </section>

        <section className="detail-panel" aria-labelledby="items-title">
          <div className="detail-section-heading compact-heading">
            <div>
              <p className="section-kicker">Itens demo</p>
              <h2 id="items-title">Itens demonstrativos</h2>
            </div>
          </div>
          <ul className="demo-list">
            {detail.items.map((item) => (
              <li key={item.id}>
                <p className="demo-item-id">{item.id}</p>
                <strong>{item.label}</strong>
                <span>{item.note}</span>
              </li>
            ))}
          </ul>
        </section>

        <section className="detail-panel detail-panel-wide" aria-labelledby="activity-title">
          <div className="detail-section-heading compact-heading">
            <div>
              <p className="section-kicker">Atividade demo</p>
              <h2 id="activity-title">Atividade recente demonstrativa</h2>
            </div>
          </div>
          <ol className="activity-list">
            {detail.activity.map((activity) => (
              <li key={activity.id}>
                <div className="activity-marker" aria-hidden="true" />
                <div>
                  <p className="activity-moment">{activity.moment}</p>
                  <strong>{activity.label}</strong>
                  <span>{activity.id}</span>
                </div>
              </li>
            ))}
          </ol>
        </section>
      </div>
    </main>
  );
}
