import { getFoundationState } from "@/shared/foundation";

export default function Home() {
  const foundation = getFoundationState();

  return (
    <main className="shell">
      <section className="hero" aria-labelledby="page-title">
        <p className="eyebrow">Fundação executável</p>
        <h1 id="page-title">Compras</h1>
        <p className="lead">
          Estrutura técnica inicial do projeto. Nenhum dado operacional, banco,
          autenticação ou integração externa está conectado nesta fase.
        </p>
      </section>

      <section className="status-grid" aria-label="Estado técnico atual">
        {foundation.map((item) => (
          <article className="status-card" key={item.label}>
            <span>{item.label}</span>
            <strong>{item.value}</strong>
          </article>
        ))}
      </section>
    </main>
  );
}
