import Link from "next/link";
import { redirect } from "next/navigation";

import { ContractingCreateForm } from "@/features/contracting-create/components/contracting-create-form";
import { readContractingCreateUiState } from "@/features/contracting-create/feedback";
import { preparePersistentContractingCandidateId } from "@/features/contracting-create/persistent-create";
import { readPersistentReadMode } from "@/server/persistent-read-mode";

const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

type ContractingCreatePageProps = {
  searchParams: Promise<{
    creation?: string | string[];
    candidate?: string | string[];
  }>;
};

function readRetryCandidate(value: string | string[] | undefined): string | null {
  return typeof value === "string" && UUID_PATTERN.test(value) ? value : null;
}

export const dynamic = "force-dynamic";

export default async function ContractingCreatePage({
  searchParams,
}: ContractingCreatePageProps) {
  if (readPersistentReadMode() !== "persistent") {
    redirect("/");
  }

  const query = await searchParams;
  const contractingId =
    readRetryCandidate(query.candidate) ?? preparePersistentContractingCandidateId();
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
            Informe apenas o objeto. O identificador candidato opaco permite retry idempotente e não concede autorização.
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
