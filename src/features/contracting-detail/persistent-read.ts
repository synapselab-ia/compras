import "server-only";

import {
  withTrustedDatabaseContext,
  type ScopedDatabaseClient,
} from "@/server/database/trusted-context";
import type { ContractingDetailPresentation } from "./types";

const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

type PersistentContractingRow = {
  id: string;
  object: string;
  responsible_membership_id: string | null;
  responsible_name: string | null;
  stage: string | null;
  status: string | null;
  waiting_type: string | null;
  waiting_reference: string | null;
  waiting_since: Date | string | null;
  waiting_reason: string | null;
  next_action: string | null;
  created_at: Date | string;
};

type PersistentIdentifierRow = {
  id: string;
  identifier_kind: string | null;
  identifier_value: string;
  source_system: string | null;
  note: string | null;
};

type PersistentItemRow = {
  id: string;
  ordinal: number;
  description: string;
  quantity: string | null;
  unit: string | null;
  catalog_code: string | null;
};

type PersistentEventRow = {
  id: string;
  event_type: string;
  occurred_at: Date | string;
  field_key: string | null;
  old_value: string | null;
  new_value: string | null;
  note: string | null;
};

const CONTRACTING_SQL = `
  SELECT
    c.id::text AS id,
    c.object,
    c.responsible_membership_id::text AS responsible_membership_id,
    responsible_directory.display_name AS responsible_name,
    c.stage_key AS stage,
    c.status_key AS status,
    c.waiting_type,
    c.waiting_reference,
    c.waiting_since,
    c.waiting_reason,
    c.next_action,
    c.created_at
  FROM public.contractings AS c
  LEFT JOIN public.team_member_directory AS responsible_directory
    ON responsible_directory.team_id = c.team_id
   AND responsible_directory.membership_id = c.responsible_membership_id
  WHERE c.id = $1::uuid
    AND c.archived_at IS NULL
    AND c.cancelled_at IS NULL
  LIMIT 1
`;

const IDENTIFIERS_SQL = `
  SELECT
    id::text AS id,
    identifier_kind,
    identifier_value,
    source_system,
    note
  FROM public.related_identifiers
  WHERE contracting_id = $1::uuid
    AND unlinked_at IS NULL
  ORDER BY linked_at ASC, id ASC
`;

const ITEMS_SQL = `
  SELECT
    id::text AS id,
    ordinal,
    description,
    quantity::text AS quantity,
    unit,
    catalog_code
  FROM public.contracting_items
  WHERE contracting_id = $1::uuid
    AND retired_at IS NULL
  ORDER BY ordinal ASC, id ASC
`;

const EVENTS_SQL = `
  SELECT
    id::text AS id,
    event_type,
    occurred_at,
    field_key,
    old_value,
    new_value,
    note
  FROM public.contracting_events
  WHERE contracting_id = $1::uuid
  ORDER BY occurred_at DESC, id ASC
`;

function nonEmptyOr(value: string | null, fallback: string): string {
  return typeof value === "string" && value.length > 0 ? value : fallback;
}

function formatInstant(value: Date | string | null, fallback: string): string {
  if (value instanceof Date && !Number.isNaN(value.valueOf())) {
    return value.toISOString();
  }

  if (typeof value === "string" && value.length > 0) {
    const parsed = new Date(value);

    if (!Number.isNaN(parsed.valueOf())) {
      return parsed.toISOString();
    }
  }

  return fallback;
}

function formatItemNote(row: PersistentItemRow): string {
  const parts = [
    row.quantity ? `Quantidade: ${row.quantity}${row.unit ? ` ${row.unit}` : ""}` : null,
    row.catalog_code ? `Código: ${row.catalog_code}` : null,
  ].filter((part): part is string => Boolean(part));

  return parts.length > 0 ? parts.join(" · ") : "Sem quantidade, unidade ou código informados.";
}

function formatEventNote(row: PersistentEventRow): string | null {
  const parts = [
    row.field_key ? `Campo: ${row.field_key}` : null,
    row.old_value !== null || row.new_value !== null
      ? `Alteração: ${row.old_value ?? "∅"} → ${row.new_value ?? "∅"}`
      : null,
    row.note,
  ].filter((part): part is string => Boolean(part));

  return parts.length > 0 ? parts.join(" · ") : null;
}

export function isPersistentContractingId(id: string): boolean {
  return UUID_PATTERN.test(id);
}

async function queryPersistentContractingDetail(
  db: ScopedDatabaseClient,
  id: string,
): Promise<ContractingDetailPresentation | undefined> {
  const contractingResult = await db.query<PersistentContractingRow>(CONTRACTING_SQL, [id]);
  const contracting = contractingResult.rows[0];

  if (!contracting) {
    return undefined;
  }

  const identifiersResult = await db.query<PersistentIdentifierRow>(IDENTIFIERS_SQL, [id]);
  const itemsResult = await db.query<PersistentItemRow>(ITEMS_SQL, [id]);
  const eventsResult = await db.query<PersistentEventRow>(EVENTS_SQL, [id]);

  const responsible = contracting.responsible_membership_id
    ? nonEmptyOr(contracting.responsible_name, "Responsável não disponível")
    : "Sem responsável";
  const latestEvent = eventsResult.rows[0];

  return {
    id: contracting.id,
    object: contracting.object,
    responsible,
    stage: nonEmptyOr(contracting.stage, "Não informado"),
    status: nonEmptyOr(contracting.status, "Não informado"),
    waitingOn: nonEmptyOr(
      contracting.waiting_reference,
      nonEmptyOr(contracting.waiting_type, "Não informado"),
    ),
    waitingSince: formatInstant(contracting.waiting_since, "Não informado"),
    waitingReason: nonEmptyOr(contracting.waiting_reason, "Não informado"),
    nextAction: nonEmptyOr(contracting.next_action, "Não informada"),
    lastMovement: latestEvent
      ? formatInstant(latestEvent.occurred_at, "Sem movimentação registrada")
      : "Sem movimentação registrada",
    createdAt: formatInstant(contracting.created_at, "Não informado"),
    relatedIdentifiers: identifiersResult.rows.map((row) => ({
      id: row.id,
      label: nonEmptyOr(row.identifier_kind, "Tipo não informado"),
      value: row.identifier_value,
      note: row.note ?? row.source_system,
    })),
    items: itemsResult.rows.map((row) => ({
      id: row.id,
      label: `${row.ordinal}. ${row.description}`,
      note: formatItemNote(row),
    })),
    activity: eventsResult.rows.map((row) => ({
      id: row.id,
      label: row.event_type,
      moment: formatInstant(row.occurred_at, "Momento não informado"),
      note: formatEventNote(row),
    })),
  };
}

/**
 * The route ID only selects a candidate resource. Identity and team scope are
 * established independently by F08 and enforced by PostgreSQL RLS.
 */
export async function readPersistentContractingDetail(
  id: string,
): Promise<ContractingDetailPresentation | undefined> {
  if (!isPersistentContractingId(id)) {
    return undefined;
  }

  return withTrustedDatabaseContext((db) => queryPersistentContractingDetail(db, id));
}
