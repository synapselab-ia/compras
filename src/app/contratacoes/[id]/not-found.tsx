import Link from "next/link";

export default function ContractingDetailNotFound() {
  return (
    <main className="detail-shell">
      <section className="prototype-banner" role="note" aria-label="Estado do detalhe">
        <strong>Contratação não disponível.</strong>
        <span>Um identificador inexistente e um registro fora do escopo autorizado recebem o mesmo tratamento.</span>
      </section>

      <section className="detail-not-found" aria-labelledby="not-found-title">
        <p className="eyebrow">Registro não disponível</p>
        <h1 id="not-found-title">Contratação não encontrada</h1>
        <p className="lead">
          O identificador informado não corresponde a um registro disponível para esta visualização. Nenhum outro registro é aberto como fallback.
        </p>
        <Link className="back-link not-found-link" href="/">
          ← Voltar para a Central do Setor
        </Link>
      </section>
    </main>
  );
}
