import "server-only";

import { randomUUID } from "node:crypto";

import {
  withTrustedDatabaseMutationContext,
  type ScopedMutationDatabaseClient,
} from "@/server/database/trusted-mutation-context";

const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export type PersistentContractingCreateInput = Readonly<{
  contractingId: string;
  object: string;
}>;

export type PersistentContractingCreateResult =
  | "created"
  | "already-created"
  | "not-available"
  | "unavailable";

type CreateOutcomeRow = {
  outcome: string;
};

const CREATE_SQL = `
  SELECT public.create_contracting_minimal(
    $1::uuid,
    $2::text,
    $3::uuid
  ) AS outcome
`;

function isCandidateContractingId(value: unknown): value is string {
  return typeof value === "string" && UUID_PATTERN.test(value);
}

async function executePersistentContractingCreate(
  db: ScopedMutationDatabaseClient,
  input: PersistentContractingCreateInput,
): Promise<PersistentContractingCreateResult> {
  const eventId = randomUUID();
  const result = await db.query<CreateOutcomeRow>(CREATE_SQL, [
    input.contractingId,
    input.object,
    eventId,
  ]);

  const outcome = result.rows[0]?.outcome;

  if (outcome === "created" || outcome === "already-created") {
    return outcome;
  }

  if (outcome === "denied") {
    return "not-available";
  }

  throw new Error("unexpected contracting create outcome");
}

/**
 * Generates the opaque candidate UUID that a future trusted server-rendered
 * creation journey can place in its form. It is an idempotency selector, not
 * an authorization token.
 */
export function preparePersistentContractingCandidateId(): string {
  return randomUUID();
}

/**
 * Persists only the minimal ADR-012 creation request.
 *
 * The caller supplies a candidate UUID plus the object text. Identity, team,
 * actor and created_by are derived by the trusted server/database boundary;
 * the audit event UUID is generated here and is never accepted from browser
 * input. Protected failures never fall back to demo data.
 */
export async function createPersistentContracting(
  input: PersistentContractingCreateInput,
): Promise<PersistentContractingCreateResult> {
  if (
    !input ||
    typeof input !== "object" ||
    !isCandidateContractingId(input.contractingId)
  ) {
    return "not-available";
  }

  if (typeof input.object !== "string") {
    return "unavailable";
  }

  try {
    return await withTrustedDatabaseMutationContext((db) =>
      executePersistentContractingCreate(db, input),
    );
  } catch {
    return "unavailable";
  }
}
