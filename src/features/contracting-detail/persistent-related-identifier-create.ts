import "server-only";

import { randomUUID } from "node:crypto";

import {
  withTrustedDatabaseMutationContext,
  type ScopedMutationDatabaseClient,
} from "@/server/database/trusted-mutation-context";

const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export type PersistentRelatedIdentifierCreateInput = Readonly<{
  contractingId: string;
  relatedIdentifierId: string;
  identifierKind: string | null;
  identifierValue: string;
  sourceSystem: string | null;
  note: string | null;
}>;

export type PersistentRelatedIdentifierCreateResult =
  | "created"
  | "already-linked"
  | "not-available"
  | "unavailable";

type CreateOutcomeRow = {
  outcome: string;
};

const CREATE_SQL = `
  SELECT public.create_related_identifier(
    $1::uuid,
    $2::uuid,
    $3::text,
    $4::text,
    $5::text,
    $6::text,
    $7::uuid
  ) AS outcome
`;

function isCandidateUuid(value: unknown): value is string {
  return typeof value === "string" && UUID_PATTERN.test(value);
}

function isNullableString(value: unknown): value is string | null {
  return value === null || typeof value === "string";
}

async function executePersistentRelatedIdentifierCreate(
  db: ScopedMutationDatabaseClient,
  input: PersistentRelatedIdentifierCreateInput,
): Promise<PersistentRelatedIdentifierCreateResult> {
  const eventId = randomUUID();

  const result = await db.query<CreateOutcomeRow>(CREATE_SQL, [
    input.contractingId,
    input.relatedIdentifierId,
    input.identifierKind,
    input.identifierValue,
    input.sourceSystem,
    input.note,
    eventId,
  ]);

  const outcome = result.rows[0]?.outcome;

  if (outcome === "created" || outcome === "already-linked") {
    return outcome;
  }

  if (outcome === "denied") {
    return "not-available";
  }

  throw new Error("unexpected related identifier create outcome");
}

/**
 * Prepares the stable row UUID used as the idempotency key for one creation
 * intent. It is opaque, non-secret and never grants authorization.
 */
export function preparePersistentRelatedIdentifierCandidateId(): string {
  return randomUUID();
}

/**
 * Persists only the ADR-016 minimal related identifier creation request.
 *
 * Team, actor, membership, trusted identity and timestamps are derived inside
 * trusted server/database boundaries. The audit event UUID is generated for
 * each attempt here. Text is forwarded exactly, including null, empty and
 * whitespace-only values where the physical schema permits them.
 */
export async function createPersistentRelatedIdentifier(
  input: PersistentRelatedIdentifierCreateInput,
): Promise<PersistentRelatedIdentifierCreateResult> {
  if (
    !input ||
    typeof input !== "object" ||
    !isCandidateUuid(input.contractingId) ||
    !isCandidateUuid(input.relatedIdentifierId)
  ) {
    return "unavailable";
  }

  if (
    !isNullableString(input.identifierKind) ||
    typeof input.identifierValue !== "string" ||
    !isNullableString(input.sourceSystem) ||
    !isNullableString(input.note)
  ) {
    return "unavailable";
  }

  try {
    return await withTrustedDatabaseMutationContext((db) =>
      executePersistentRelatedIdentifierCreate(db, input),
    );
  } catch {
    return "unavailable";
  }
}
