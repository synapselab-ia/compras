import Link from "next/link";

import { signOutAction } from "../actions";

export const dynamic = "force-dynamic";

export default function SignOutPage() {
  return (
    <main className="sector-shell">
      <section className="prototype-banner" role="note" aria-label="Encerramento de sessão">
        <strong>Encerrar sessão.</strong>
        <span>A operação usa somente o SDK server-side e retorna a um destino local fixo.</span>
      </section>

      <header className="page-header">
        <div>
          <p className="eyebrow">Autenticação</p>
          <h1>Sair</h1>
          <p className="lead">Encerre a sessão atual antes de deixar este ambiente privado.</p>
        </div>
      </header>

      <section className="records-section" aria-labelledby="sign-out-title">
        <div className="records-heading">
          <div>
            <p className="section-kicker">Sessão privada</p>
            <h2 id="sign-out-title">Confirmar encerramento</h2>
          </div>
        </div>
        <div style={{ padding: 20 }}>
          <form action={signOutAction}>
            <button className="clear-button" type="submit">
              Encerrar sessão
            </button>
          </form>
          <p className="lead" style={{ marginTop: 20 }}>
            <Link href="/">Cancelar e voltar para a Central</Link>
          </p>
        </div>
      </section>
    </main>
  );
}
