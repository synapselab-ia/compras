import Link from "next/link";

import { signInAction } from "../actions";

type SignInPageProps = {
  searchParams: Promise<{ state?: string | string[] }>;
};

function readState(value: string | string[] | undefined): string | null {
  return typeof value === "string" ? value : null;
}

export const dynamic = "force-dynamic";

export default async function SignInPage({ searchParams }: SignInPageProps) {
  const { state: rawState } = await searchParams;
  const state = readState(rawState);

  return (
    <main className="sector-shell">
      <section className="prototype-banner" role="note" aria-label="Política de acesso">
        <strong>Acesso privado.</strong>
        <span>Somente identidades previamente admitidas podem iniciar sessão. Cadastro público não é oferecido.</span>
      </section>

      <header className="page-header">
        <div>
          <p className="eyebrow">Autenticação</p>
          <h1>Entrar</h1>
          <p className="lead">
            Use as credenciais previamente fornecidas para este ambiente. O login não cria usuário, equipe ou
            permissão no Compras; a autorização continua sendo verificada no PostgreSQL/RLS.
          </p>
        </div>

        <div className="prototype-card" aria-label="Limites de autenticação">
          <span>Admissão</span>
          <strong>Somente sign-in existente</strong>
          <p>Signup, OAuth, magic link, OTP e recuperação de senha não fazem parte desta superfície.</p>
        </div>
      </header>

      <section className="records-section" aria-labelledby="sign-in-title">
        <div className="records-heading">
          <div>
            <p className="section-kicker">Sessão privada</p>
            <h2 id="sign-in-title">Credenciais de acesso</h2>
          </div>
        </div>

        <div style={{ padding: 20 }}>
          {state === "rejected" ? (
            <div className="empty-state" role="status">
              <strong>Não foi possível iniciar a sessão.</strong>
              <p>Verifique as credenciais fornecidas para este ambiente.</p>
            </div>
          ) : state === "unavailable" ? (
            <div className="empty-state" role="status">
              <strong>Autenticação indisponível.</strong>
              <p>Tente novamente quando a configuração server-side estiver disponível.</p>
            </div>
          ) : state === "signed-out" ? (
            <div className="empty-state" role="status">
              <strong>Sessão encerrada.</strong>
              <p>Nenhum acesso persistente permanece ativo nesta experiência.</p>
            </div>
          ) : null}

          <form action={signInAction} className="filters-grid" style={{ gridTemplateColumns: "1fr 1fr auto" }}>
            <label className="field">
              <span>E-mail</span>
              <input
                name="email"
                type="email"
                autoComplete="username"
                required
                maxLength={320}
              />
            </label>

            <label className="field">
              <span>Senha</span>
              <input
                name="password"
                type="password"
                autoComplete="current-password"
                required
                maxLength={4096}
              />
            </label>

            <button className="clear-button" type="submit">
              Entrar
            </button>
          </form>

          <p className="lead" style={{ marginTop: 20 }}>
            <Link href="/">Voltar para a Central</Link>
          </p>
        </div>
      </section>
    </main>
  );
}
