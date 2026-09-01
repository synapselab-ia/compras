import Link from "next/link";

export default function ContractingDetailNotFound() {
  return (
    <main className="detail-shell">
      <section className="prototype-banner" role="note" aria-label="Aviso de protótipo">
        <strong>Protótipo com dados fictícios.</strong>
        <span>Nenhum dado interno é consultado nesta rota.</span>
      </section>

      <section className="detail-not-found" aria-labelledby="not-found-title">
        <p className="eyebrow">Registro demonstrativo inexistente</p>
        <h1 id="not-found-title">Contratação demo não encontrada</h1>
        <p className="lead">
          O identificador informado não corresponde a nenhum registro DEMO disponível. Nenhum outro registro foi
          aberto como fallback.
        </p>
        <Link className="back-link not-found-link" href="/">
          ← Voltar para a Central do Setor
        </Link>
      </section>
    </main>
  );
}
