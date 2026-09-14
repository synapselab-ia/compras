import "server-only";

import { randomUUID } from "node:crypto";

import {
  withTrustedDatabaseMutationContext,
  type ScopedMutationDatabaseClient,
} from "@/server/database/trusted-mutation-context";

const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export type PersistentContractingObjectMutationInput = Readonly<{
  contractingId: string;
  expectedObject: string;
  newObject: string;
}>;

export type PersistentContractingObjectMutationResult =
  | "updated"
  | "unchanged"
  | "conflict"
  | "not-available"
  | "unavailable";

type MutationOutcomeRow = {
  outcome: string;
};

const MUTATION_SQL = `
  SELECT public.mutate_contracting_object(
    $1::uuid,
    $2::text,
    $3::text,
    $4::uuid
  ) AS outcome
`;

function isCandidateContractingId(value: unknown): value is string {
  return typeof value === "string" && UUID_PATTERN.test(value);
}

async function executeContractingObjectMutation(
  db: ScopedMutationDatabaseClient,
  input: PersistentContractingObjectMutationInput,
): Promise<PersistentContractingObjectMutationResult> {
  const eventId = randomUUID();
  const result = await db.query<MutationOutcomeRow>(MUTATION_SQL, [
    input.contractingId,
    input.expectedObject,
    input.newObject,
    eventId,
  ]);

  const outcome = result.rows[0]?.outcome;

  if (outcome === "updated" || outcome === "unchanged" || outcome === "conflict") {
    return outcome;
  }

  if (outcome === "denied") {
    return "not-available";
  }

  throw new Error("unexpected contracting object mutation outcome");
}

/**
 * Persists only the ADR-013 object edit request.
 *
 * The caller supplies the candidate contracting UUID plus exact expected/new
 * object strings. Identity, team and actor are derived by the trusted
 * server/database boundary; the audit event UUID is generated here and cannot
 * be supplied by a form/browser payload. Strings are passed byte-for-byte with
 * no trim, normalization, size rule or empty-string coercion.
 */
export async function mutatePersistentContractingObject(
  input: PersistentContractingObjectMutationInput,
): Promise<PersistentContractingObjectMutationResult> {
  if (
    !input ||
    typeof input !== "object" ||
    !isCandidateContractingId(input.contractingId)
  ) {
    return "not-available";
  }

  if (
    typeof input.expectedObject !== "string" ||
    typeof input.newObject !== "string"
  ) {
    return "unavailable";
  }

  try {
    return await withTrustedDatabaseMutationContext((db) =>
      executeContractingObjectMutation(db, input),
    );
  } catch {
    return "unavailable";
  }
}
