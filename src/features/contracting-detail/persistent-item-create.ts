import "server-only";

import { randomUUID } from "node:crypto";

import {
  withTrustedDatabaseMutationContext,
  type ScopedMutationDatabaseClient,
} from "@/server/database/trusted-mutation-context";

const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export type PersistentContractingItemCreateInput = Readonly<{
  contractingId: string;
  description: string;
  quantity: string | null;
  unit: string | null;
  catalogCode: string | null;
}>;

export type PersistentContractingItemCreateResult =
  | "created"
  | "not-available"
  | "unavailable";

type CreateOutcomeRow = {
  outcome: string;
};

const CREATE_SQL = `
  SELECT public.create_contracting_item(
    $1::uuid,
    $2::text,
    $3::numeric,
    $4::text,
    $5::text,
    $6::uuid,
    $7::uuid
  ) AS outcome
`;

function isCandidateContractingId(value: unknown): value is string {
  return typeof value === "string" && UUID_PATTERN.test(value);
}

async function executePersistentContractingItemCreate(
  db: ScopedMutationDatabaseClient,
  input: PersistentContractingItemCreateInput,
): Promise<PersistentContractingItemCreateResult> {
  const itemId = randomUUID();
  const eventId = randomUUID();

  const result = await db.query<CreateOutcomeRow>(CREATE_SQL, [
    input.contractingId,
    input.description,
    input.quantity,
    input.unit,
    input.catalogCode,
    itemId,
    eventId,
  ]);

  const outcome = result.rows[0]?.outcome;

  if (outcome === "created") {
    return "created";
  }

  if (outcome === "denied") {
    return "not-available";
  }

  throw new Error("unexpected contracting item create outcome");
}

/**
 * Persists only the ADR-014 minimal item creation request.
 *
 * The caller supplies the candidate contracting UUID and exact item fields.
 * Identity, team, actor, membership and ordinal are derived by the trusted
 * server/database boundary. Item and audit-event UUIDs are generated here and
 * cannot be supplied by browser input. Text values are not trimmed or
 * normalized and quantity remains a string until PostgreSQL casts it to
 * numeric.
 */
export async function createPersistentContractingItem(
  input: PersistentContractingItemCreateInput,
): Promise<PersistentContractingItemCreateResult> {
  if (
    !input ||
    typeof input !== "object" ||
    !isCandidateContractingId(input.contractingId)
  ) {
    return "not-available";
  }

  if (
    typeof input.description !== "string" ||
    (input.quantity !== null && typeof input.quantity !== "string") ||
    (input.unit !== null && typeof input.unit !== "string") ||
    (input.catalogCode !== null && typeof input.catalogCode !== "string")
  ) {
    return "unavailable";
  }

  try {
    return await withTrustedDatabaseMutationContext((db) =>
      executePersistentContractingItemCreate(db, input),
    );
  } catch {
    return "unavailable";
  }
}
