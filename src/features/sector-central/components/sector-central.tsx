"use client";

import Link from "next/link";
import { useMemo, useState } from "react";
import { filterSectorRecords, getSectorFilterOptions } from "../filtering";
import type { SectorCentralRecord, SectorCentralSource } from "../types";

type SectorCentralProps = Readonly<{
  records: SectorCentralRecord[];
  source: SectorCentralSource;
}>;

function DetailLink({ record, source }: Readonly<{
  record: SectorCentralRecord;
  source: SectorCentralSource;
}>) {
  return (
    <Link className="record-detail-link" href={`/contratacoes/${record.id}`}>
      {source === "demo" ? "Ver detalhe" : "Ver detalhe protegido"}
      <span className="sr-only"> de {record.id}</span>
    </Link>
  );
}

function RecordTable({ records, source }: SectorCentralProps) {
  return (
    <div className="records-table-wrap">
      <table className="records-table">
        <caption className="sr-only">
          {source === "demo" ? "Registros fictícios da Central." : "Contratações autorizadas da Central."}
        </caption>
        <thead>
          <tr>
            <th>Identificador</th><th>Objeto</th><th>Responsável</th><th>Etapa</th>
            <th>Status</th><th>Aguardando</th><th>Próxima ação</th><th>Última movimentação</th>
          </tr>
        </thead>
        <tbody>
          {records.map((record) => (
            <tr key={record.id}>
              <td><strong className="record-id">{record.id}</strong><DetailLink record={record} source={source} /></td>
              <td className="object-cell">{record.object}</td>
              <td>{record.responsible}</td><td>{record.stage}</td>
              <td><span className="status-badge">{record.status}</span></td>
              <td>{record.waitingOn}</td><td className="next-action-cell">{record.nextAction}</td><td>{record.lastMovement}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

function RecordCards({ records, source }: SectorCentralProps) {
  return (
    <div className="record-cards" aria-label="Registros da Central em visualização compacta">
      {records.map((record) => (
        <article className="record-card" key={record.id}>
          <div className="record-card-heading">
            <div><p className="record-id">{record.id}</p><h3>{record.object}</h3></div>
            <span className="status-badge">{record.status}</span>
          </div>
          <dl className="record-details">
            <div><dt>Responsável</dt><dd>{record.responsible}</dd></div>
            <div><dt>Etapa</dt><dd>{record.stage}</dd></div>
            <div><dt>Aguardando</dt><dd>{record.waitingOn}</dd></div>
            <div><dt>Última movimentação</dt><dd>{record.lastMovement}</dd></div>
            <div className="record-details-wide"><dt>Próxima ação</dt><dd>{record.nextAction}</dd></div>
          </dl>
          <DetailLink record={record} source={source} />
        </article>
      ))}
    </div>
  );
}

export function SectorCentral({ records, source }: SectorCentralProps) {
  const [query, setQuery] = useState("");
  const [responsible, setResponsible] = useState("");
  const [stage, setStage] = useState("");
  const [status, setStatus] = useState("");
  const options = useMemo(() => getSectorFilterOptions(records), [records]);
  const filtered = useMemo(
    () => filterSectorRecords(records, { query, responsible, stage, status }),
    [query, records, responsible, stage, status],
  );
  const hasFilters = Boolean(query || responsible || stage || status);

  function clearFilters() {
    setQuery(""); setResponsible(""); setStage(""); setStatus("");
  }

  return (
    <>
      <section className="filters-panel" aria-labelledby="filters-title">
        <div className="filters-heading">
          <div><p className="section-kicker">Localizar e comparar</p><h2 id="filters-title">{source === "demo" ? "Fila demonstrativa" : "Fila autorizada"}</h2></div>
          <p className="result-count" aria-live="polite">{filtered.length} de {records.length} registros</p>
        </div>
        <div className="filters-grid">
          <label className="field field-search"><span>Buscar</span><input type="search" value={query} onChange={(event) => setQuery(event.target.value)} placeholder={source === "demo" ? "DEMO-001, objeto ou responsável" : "Identificador, objeto ou responsável"} autoComplete="off" /></label>
          <label className="field"><span>Responsável</span><select value={responsible} onChange={(event) => setResponsible(event.target.value)}><option value="">Todos</option>{options.responsibles.map((value) => <option value={value} key={value}>{value}</option>)}</select></label>
          <label className="field"><span>Etapa provisória</span><select value={stage} onChange={(event) => setStage(event.target.value)}><option value="">Todas</option>{options.stages.map((value) => <option value={value} key={value}>{value}</option>)}</select></label>
          <label className="field"><span>Status provisório</span><select value={status} onChange={(event) => setStatus(event.target.value)}><option value="">Todos</option>{options.statuses.map((value) => <option value={value} key={value}>{value}</option>)}</select></label>
          <button type="button" className="clear-button" onClick={clearFilters} disabled={!hasFilters}>Limpar filtros</button>
        </div>
      </section>

      <section className="records-section" aria-labelledby="records-title">
        <div className="records-heading">
          <div><p className="section-kicker">Visão compartilhada</p><h2 id="records-title">Trabalho do setor</h2></div>
          <p className="provisional-note">{source === "demo" ? "Etapas e status são valores demo." : "Leitura autorizada; taxonomias finais seguem em aberto."}</p>
        </div>
        {filtered.length > 0 ? <><RecordTable records={filtered} source={source} /><RecordCards records={filtered} source={source} /></> : (
          <div className="empty-state" role="status">
            <strong>{records.length > 0 ? "Nenhum registro encontrado com os filtros atuais." : source === "persistent" ? "Nenhuma contratação ativa está visível para esta sessão." : "Nenhum registro demonstrativo encontrado."}</strong>
            <p>{records.length > 0 ? "Ajuste a busca ou limpe os filtros." : "A Central não recebeu registros para apresentar neste modo."}</p>
            {records.length > 0 && hasFilters ? <button type="button" className="secondary-button" onClick={clearFilters}>Restaurar visão completa</button> : null}
          </div>
        )}
      </section>
    </>
  );
}
