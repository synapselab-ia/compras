import Link from "next/link";
import { redirect } from "next/navigation";

import { ContractingCreateForm } from "@/features/contracting-create/components/contracting-create-form";
import { readContractingCreateUiState } from "@/features/contracting-create/feedback";
import { preparePersistentContractingCandidateId } from "@/features/contracting-create/persistent-create";
import { readPersistentReadMode } from "@/server/persistent-read-mode";

type ContractingCreatePageProps = {
  searchParams: Promise<{ creation?: string | string[] }>;
};

export const dynamic = "force-dynamic";

export default async function ContractingCreatePage({
  searchParams,
}: ContractingCreatePageProps) {
  if (readPersistentReadMode() !== "persistent") {
    redirect("/");
  }

  const query = await searchParams;
  const contractingId = preparePersistentContractingCandidateId();
  const creationState = readContractingCreateUiState(query.creation);

  return (
    <main className="detail-shell contracting-create-shell">
      <section className="prototype-banner" role="note" aria-label="Estado da fonte de dados">
        <strong>Cadastro persistente mínimo habilitado.</strong>
        <span>Autorização, equipe, autoria e evento de criação permanecem sob enforcement do servidor e do banco.</span>
      </section>

      <nav className="detail-nav" aria-label="Navegação do cadastro">
        <Link className="back-link" href="/">
          ← Voltar para a Central do Setor
        </Link>
      </nav>

      <header className="detail-header contracting-create-header">
        <div className="detail-heading-main">
          <p className="eyebrow">Contratação · cadastro persistente</p>
          <h1>Nova contratação</h1>
          <p className="lead">
            Informe apenas o objeto. O identificador candidato foi preparado no servidor e funciona como seletor idempotente, não como autorização.
          </p>
        </div>
      </header>

      <ContractingCreateForm
        contractingId={contractingId}
        creationState={creationState}
      />
    </main>
  );
}
