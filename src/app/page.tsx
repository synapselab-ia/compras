import { SectorCentral } from "@/features/sector-central/components/sector-central";

export default function Home() {
  return (
    <main className="sector-shell">
      <section className="prototype-banner" role="note" aria-label="Aviso de protótipo">
        <strong>Protótipo com dados fictícios.</strong>
        <span>Sem persistência, sem base interna e sem conexão com sistemas oficiais.</span>
      </section>

      <header className="page-header">
        <div>
          <p className="eyebrow">Central do Setor · demonstração</p>
          <h1>Compras</h1>
          <p className="lead">
            Visão única para localizar o trabalho demonstrativo, comparar estados operacionais e identificar
            rapidamente quem está responsável e qual é a próxima ação.
          </p>
        </div>

        <div className="prototype-card" aria-label="Limites desta demonstração">
          <span>Ambiente</span>
          <strong>Somente demonstração</strong>
          <p>Nenhuma ação nesta tela grava ou altera registros.</p>
        </div>
      </header>

      <SectorCentral />
    </main>
  );
}
