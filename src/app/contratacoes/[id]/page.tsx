import Link from "next/link";
import { notFound, redirect } from "next/navigation";

import { ContractingDetail } from "@/features/contracting-detail/components/contracting-detail";
import { loadContractingDetailViewData } from "@/features/contracting-detail/view-data";

type ContractingDetailPageProps = {
  params: Promise<{ id: string }>;
};

export const dynamic = "force-dynamic";

export default async function ContractingDetailPage({ params }: ContractingDetailPageProps) {
  const { id } = await params;
  const viewData = await loadContractingDetailViewData(id);

  if (viewData.kind === "sign-in-required") {
    redirect("/auth/sign-in");
  }

  if (viewData.kind === "not-found") {
    notFound();
  }

  if (viewData.kind === "unavailable") {
    return (
      <main className="detail-shell">
        <section className="prototype-banner" role="note" aria-label="Estado da fonte de dados">
          <strong>Dados protegidos indisponíveis.</strong>
          <span>Falhas de Auth, sessão, configuração ou banco não são substituídas por dados demonstrativos.</span>
        </section>
        <section className="detail-not-found" aria-labelledby="unavailable-title">
          <p className="eyebrow">Leitura protegida indisponível</p>
          <h1 id="unavailable-title">Não foi possível carregar o detalhe.</h1>
          <p className="lead">Nenhum detalhe técnico, sessão, claim ou dado substituto é exposto nesta página.</p>
          <Link className="back-link not-found-link" href="/">
            ← Voltar para a Central do Setor
          </Link>
        </section>
      </main>
    );
  }

  return <ContractingDetail detail={viewData.detail} source={viewData.kind} />;
}
