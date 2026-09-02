import "server-only";

import {
  withTrustedDatabaseContext,
  type ScopedDatabaseClient,
} from "@/server/database/trusted-context";
import type { SectorCentralRecord } from "./types";

type PersistentSectorCentralRow = {
  id: string;
  object: string;
  responsible_membership_id: string | null;
  responsible_name: string | null;
  stage: string | null;
  status: string | null;
  waiting_type: string | null;
  waiting_reference: string | null;
  next_action: string | null;
  latest_event_at: Date | string | null;
};

const SECTOR_CENTRAL_READ_SQL = `
  SELECT
    c.id::text AS id,
    c.object,
    c.responsible_membership_id::text AS responsible_membership_id,
    responsible_directory.display_name AS responsible_name,
    c.stage_key AS stage,
    c.status_key AS status,
    c.waiting_type,
    c.waiting_reference,
    c.next_action,
    MAX(e.occurred_at) AS latest_event_at
  FROM public.contractings AS c
  LEFT JOIN public.team_member_directory AS responsible_directory
    ON responsible_directory.team_id = c.team_id
   AND responsible_directory.membership_id = c.responsible_membership_id
  LEFT JOIN public.contracting_events AS e
    ON e.team_id = c.team_id
   AND e.contracting_id = c.id
  WHERE c.archived_at IS NULL
    AND c.cancelled_at IS NULL
  GROUP BY
    c.id,
    c.object,
    c.responsible_membership_id,
    responsible_directory.display_name,
    c.stage_key,
    c.status_key,
    c.waiting_type,
    c.waiting_reference,
    c.next_action,
    c.created_at
  ORDER BY MAX(e.occurred_at) DESC NULLS LAST, c.created_at DESC, c.id ASC
`;

function nonEmptyOr(value: string | null, fallback: string): string {
  return typeof value === "string" && value.length > 0 ? value : fallback;
}

function formatLastMovement(value: Date | string | null): string {
  if (value instanceof Date && !Number.isNaN(value.valueOf())) {
    return value.toISOString();
  }

  if (typeof value === "string" && value.length > 0) {
    const parsed = new Date(value);

    if (!Number.isNaN(parsed.valueOf())) {
      return parsed.toISOString();
    }
  }

  return "Sem movimentação registrada";
}

function mapPersistentRow(row: PersistentSectorCentralRow): SectorCentralRecord {
  const responsible = row.responsible_membership_id
    ? nonEmptyOr(row.responsible_name, "Responsável não disponível")
    : "Sem responsável";

  return {
    id: row.id,
    object: row.object,
    responsible,
    stage: nonEmptyOr(row.stage, "Não informado"),
    status: nonEmptyOr(row.status, "Não informado"),
    waitingOn: nonEmptyOr(
      row.waiting_reference,
      nonEmptyOr(row.waiting_type, "Não informado"),
    ),
    nextAction: nonEmptyOr(row.next_action, "Não informada"),
    lastMovement: formatLastMovement(row.latest_event_at),
  };
}

async function queryPersistentSectorCentralRecords(
  db: ScopedDatabaseClient,
): Promise<SectorCentralRecord[]> {
  const result = await db.query<PersistentSectorCentralRow>(SECTOR_CENTRAL_READ_SQL);

  return result.rows.map(mapPersistentRow);
}

/**
 * Reads the Central only after F08 has established verified identity and
 * transaction-local PostgreSQL context. The caller cannot choose identity or team scope.
 */
export async function readPersistentSectorCentralRecords(): Promise<
  SectorCentralRecord[]
> {
  return withTrustedDatabaseContext(queryPersistentSectorCentralRecords);
}
