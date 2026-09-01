"use client";

import Link from "next/link";
import { useMemo, useState } from "react";
import { demoSectorRecords, type SectorCentralRecord } from "../demo-data";
import { filterSectorRecords, getSectorFilterOptions } from "../filtering";

const filterOptions = getSectorFilterOptions(demoSectorRecords);

function RecordTable({ records }: Readonly<{ records: SectorCentralRecord[] }>) {
  return (
    <div className="records-table-wrap">
      <table className="records-table">
        <caption className="sr-only">
          Registros fictícios da Central do Setor com valores provisórios de demonstração.
        </caption>
        <thead>
          <tr>
            <th scope="col">Identificador</th>
            <th scope="col">Objeto</th>
            <th scope="col">Responsável</th>
            <th scope="col">Etapa</th>
            <th scope="col">Status</th>
            <th scope="col">Aguardando</th>
            <th scope="col">Próxima ação</th>
            <th scope="col">Última movimentação</th>
          </tr>
        </thead>
        <tbody>
          {records.map((record) => (
            <tr key={record.id}>
              <td>
                <strong className="record-id">{record.id}</strong>
                <Link className="record-detail-link" href={`/contratacoes/${record.id}`}>
                  Ver detalhe<span className="sr-only"> de {record.id}</span>
                </Link>
              </td>
              <td className="object-cell">{record.object}</td>
              <td>{record.responsible}</td>
              <td>{record.stage}</td>
              <td>
                <span className="status-badge">{record.status}</span>
              </td>
              <td>{record.waitingOn}</td>
              <td className="next-action-cell">{record.nextAction}</td>
              <td>{record.lastMovement}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

function RecordCards({ records }: Readonly<{ records: SectorCentralRecord[] }>) {
  return (
    <div className="record-cards" aria-label="Registros fictícios em visualização compacta">
      {records.map((record) => (
        <article className="record-card" key={record.id}>
          <div className="record-card-heading">
            <div>
              <p className="record-id">{record.id}</p>
              <h3>{record.object}</h3>
            </div>
            <span className="status-badge">{record.status}</span>
          </div>

          <dl className="record-details">
            <div>
              <dt>Responsável</dt>
              <dd>{record.responsible}</dd>
            </div>
            <div>
              <dt>Etapa</dt>
              <dd>{record.stage}</dd>
            </div>
            <div>
              <dt>Aguardando</dt>
              <dd>{record.waitingOn}</dd>
            </div>
            <div>
              <dt>Última movimentação</dt>
              <dd>{record.lastMovement}</dd>
            </div>
            <div className="record-details-wide">
              <dt>Próxima ação</dt>
              <dd>{record.nextAction}</dd>
            </div>
          </dl>

          <Link className="record-detail-link card-detail-link" href={`/contratacoes/${record.id}`}>
            Abrir detalhe demonstrativo<span className="sr-only"> de {record.id}</span>
          </Link>
        </article>
      ))}
    </div>
  );
}

export function SectorCentral() {
  const [query, setQuery] = useState("");
  const [responsible, setResponsible] = useState("");
  const [stage, setStage] = useState("");
  const [status, setStatus] = useState("");

  const filteredRecords = useMemo(
    () =>
      filterSectorRecords(demoSectorRecords, {
        query,
        responsible,
        stage,
        status,
      }),
    [query, responsible, stage, status],
  );

  const hasActiveFilters = Boolean(query || responsible || stage || status);

  function clearFilters() {
    setQuery("");
    setResponsible("");
    setStage("");
    setStatus("");
  }

  return (
    <>
      <section className="filters-panel" aria-labelledby="filters-title">
        <div className="filters-heading">
          <div>
            <p className="section-kicker">Localizar e comparar</p>
            <h2 id="filters-title">Fila demonstrativa</h2>
          </div>
          <p className="result-count" aria-live="polite">
            {filteredRecords.length} de {demoSectorRecords.length} registros
          </p>
        </div>

        <div className="filters-grid">
          <label className="field field-search">
            <span>Buscar</span>
            <input
              type="search"
              value={query}
              onChange={(event) => setQuery(event.target.value)}
              placeholder="DEMO-001, objeto ou responsável"
              autoComplete="off"
            />
          </label>

          <label className="field">
            <span>Responsável</span>
            <select value={responsible} onChange={(event) => setResponsible(event.target.value)}>
              <option value="">Todos</option>
              {filterOptions.responsibles.map((option) => (
                <option value={option} key={option}>
                  {option}
                </option>
              ))}
            </select>
          </label>

          <label className="field">
            <span>Etapa provisória</span>
            <select value={stage} onChange={(event) => setStage(event.target.value)}>
              <option value="">Todas</option>
              {filterOptions.stages.map((option) => (
                <option value={option} key={option}>
                  {option}
                </option>
              ))}
            </select>
          </label>

          <label className="field">
            <span>Status provisório</span>
            <select value={status} onChange={(event) => setStatus(event.target.value)}>
              <option value="">Todos</option>
              {filterOptions.statuses.map((option) => (
                <option value={option} key={option}>
                  {option}
                </option>
              ))}
            </select>
          </label>

          <button
            type="button"
            className="clear-button"
            onClick={clearFilters}
            disabled={!hasActiveFilters}
          >
            Limpar filtros
          </button>
        </div>
      </section>

      <section className="records-section" aria-labelledby="records-title">
        <div className="records-heading">
          <div>
            <p className="section-kicker">Visão compartilhada</p>
            <h2 id="records-title">Trabalho do setor</h2>
          </div>
          <p className="provisional-note">Etapas e status abaixo são valores demo, não taxonomia final.</p>
        </div>

        {filteredRecords.length > 0 ? (
          <>
            <RecordTable records={filteredRecords} />
            <RecordCards records={filteredRecords} />
          </>
        ) : (
          <div className="empty-state" role="status">
            <strong>Nenhum registro demonstrativo encontrado.</strong>
            <p>Ajuste a busca ou limpe os filtros para restaurar a visão completa.</p>
            <button type="button" className="secondary-button" onClick={clearFilters}>
              Restaurar visão completa
            </button>
          </div>
        )}
      </section>
    </>
  );
}
