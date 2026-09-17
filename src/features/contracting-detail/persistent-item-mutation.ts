import "server-only";

import { randomUUID } from "node:crypto";

import {
  withTrustedDatabaseMutationContext,
  type ScopedMutationDatabaseClient,
} from "@/server/database/trusted-mutation-context";

const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export type PersistentContractingItemMutationInput = Readonly<{
  contractingId: string;
  itemId: string;
  expectedDescription: string;
  expectedQuantity: string | null;
  expectedUnit: string | null;
  expectedCatalogCode: string | null;
  newDescription: string;
  newQuantity: string | null;
  newUnit: string | null;
  newCatalogCode: string | null;
}>;

export type PersistentContractingItemMutationResult =
  | "updated"
  | "unchanged"
  | "conflict"
  | "not-available"
  | "unavailable";

type MutationOutcomeRow = {
  outcome: string;
};

const MUTATION_SQL = `
  SELECT public.mutate_contracting_item_fields(
    $1::uuid,
    $2::uuid,
    $3::text,
    $4::numeric,
    $5::text,
    $6::text,
    $7::text,
    $8::numeric,
    $9::text,
    $10::text,
    $11::uuid,
    $12::uuid,
    $13::uuid,
    $14::uuid
  ) AS outcome
`;

function isCandidateUuid(value: unknown): value is string {
  return typeof value === "string" && UUID_PATTERN.test(value);
}

function isNullableString(value: unknown): value is string | null {
  return value === null || typeof value === "string";
}

async function executePersistentContractingItemMutation(
  db: ScopedMutationDatabaseClient,
  input: PersistentContractingItemMutationInput,
): Promise<PersistentContractingItemMutationResult> {
  const descriptionEventId = randomUUID();
  const quantityEventId = randomUUID();
  const unitEventId = randomUUID();
  const catalogCodeEventId = randomUUID();

  const result = await db.query<MutationOutcomeRow>(MUTATION_SQL, [
    input.contractingId,
    input.itemId,
    input.expectedDescription,
    input.expectedQuantity,
    input.expectedUnit,
    input.expectedCatalogCode,
    input.newDescription,
    input.newQuantity,
    input.newUnit,
    input.newCatalogCode,
    descriptionEventId,
    quantityEventId,
    unitEventId,
    catalogCodeEventId,
  ]);

  const outcome = result.rows[0]?.outcome;

  if (outcome === "updated" || outcome === "unchanged" || outcome === "conflict") {
    return outcome;
  }

  if (outcome === "denied") {
    return "not-available";
  }

  throw new Error("unexpected contracting item mutation outcome");
}

/**
 * Persists only the ADR-015 four-field item snapshot mutation.
 *
 * The caller supplies candidate contracting/item UUIDs and exact expected/new
 * field values. Team, actor, membership, scope, ordinal, retired state,
 * timestamps and audit UUIDs are derived or generated inside trusted server and
 * database boundaries. Numeric text reaches PostgreSQL without JavaScript
 * floating-point conversion, and text is never trimmed or normalized here.
 */
export async function mutatePersistentContractingItem(
  input: PersistentContractingItemMutationInput,
): Promise<PersistentContractingItemMutationResult> {
  if (
    !input ||
    typeof input !== "object" ||
    !isCandidateUuid(input.contractingId) ||
    !isCandidateUuid(input.itemId)
  ) {
    return "not-available";
  }

  if (
    typeof input.expectedDescription !== "string" ||
    !isNullableString(input.expectedQuantity) ||
    !isNullableString(input.expectedUnit) ||
    !isNullableString(input.expectedCatalogCode) ||
    typeof input.newDescription !== "string" ||
    !isNullableString(input.newQuantity) ||
    !isNullableString(input.newUnit) ||
    !isNullableString(input.newCatalogCode)
  ) {
    return "unavailable";
  }

  try {
    return await withTrustedDatabaseMutationContext((db) =>
      executePersistentContractingItemMutation(db, input),
    );
  } catch {
    return "unavailable";
  }
}
