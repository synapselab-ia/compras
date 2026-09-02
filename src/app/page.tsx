import Link from "next/link";
import { redirect } from "next/navigation";

import { SectorCentral } from "@/features/sector-central/components/sector-central";
import { loadSectorCentralViewData } from "@/features/sector-central/view-data";

export const dynamic = "force-dynamic";

export default async function Home() {
  const viewData = await loadSectorCentralViewData();

  if (viewData.kind === "sign-in-required") {
    redirect("/auth/sign-in");
  }

  const isDemo = viewData.kind === "demo";
  const isPersistent = viewData.kind === "persistent";

  return (
    <main className="sector-shell">
      <section className="prototype-banner" role="note" aria-label="Estado da fonte de dados">
        {isDemo ? (
          <>
            <strong>Protótipo com dados fictícios.</strong>
            <span>Persistência operacional desabilitada neste ambiente.</span>
          </>
        ) : isPersistent ? (
          <>
            <strong>Leitura persistente server-side habilitada.</strong>
            <span>Somente registros autorizados pela sessão e pelas policies do banco são apresentados.</span>
          </>
        ) : (
          <>
            <strong>Dados protegidos indisponíveis.</strong>
            <span>A Central não substitui falha de Auth, sessão, banco ou configuração por dados demonstrativos.</span>
          </>
        )}
      </section>

      <header className="page-header">
        <div>
          <p className="eyebrow">Central do Setor · {isDemo ? "demonstração" : "leitura server-side"}</p>
          <h1>Compras</h1>
          <p className="lead">
            Visão única para localizar o trabalho disponível, comparar estados operacionais e identificar
            rapidamente responsabilidade e próxima ação sem usar a interface como fronteira de autorização.
          </p>
        </div>

        <div className="prototype-card" aria-label="Limites desta etapa">
          <span>Ambiente</span>
          <strong>{isDemo ? "Somente demonstração" : isPersistent ? "Leitura persistente" : "Indisponível"}</strong>
          <p>Nenhuma ação nesta tela grava ou altera registros.</p>
          {isPersistent ? (
            <p>
              <Link href="/auth/sign-out">Encerrar sessão</Link>
            </p>
          ) : null}
        </div>
      </header>

      {viewData.kind === "unavailable" ? (
        <section className="records-section" aria-labelledby="unavailable-title">
          <div className="empty-state" role="status">
            <strong id="unavailable-title">Não foi possível carregar a Central protegida.</strong>
            <p>Revise autenticação e configuração server-side. Nenhum detalhe técnico ou dado substituto é exposto aqui.</p>
          </div>
        </section>
      ) : (
        <SectorCentral records={viewData.records} source={viewData.kind} />
      )}
    </main>
  );
}
