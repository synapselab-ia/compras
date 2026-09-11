import "server-only";

import { randomUUID } from "node:crypto";

import {
  withTrustedDatabaseMutationContext,
  type ScopedMutationDatabaseClient,
} from "@/server/database/trusted-mutation-context";

const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export type PersistentNextActionMutationInput = Readonly<{
  contractingId: string;
  expectedNextAction: string | null;
  newNextAction: string | null;
}>;

export type PersistentNextActionMutationResult =
  | "updated"
  | "unchanged"
  | "conflict"
  | "not-available"
  | "unavailable";

type MutationOutcomeRow = {
  outcome: string;
};

const MUTATION_SQL = `
  SELECT public.mutate_contracting_next_action(
    $1::uuid,
    $2::text,
    $3::text,
    $4::uuid
  ) AS outcome
`;

function isNullableString(value: unknown): value is string | null {
  return value === null || typeof value === "string";
}

function isCandidateContractingId(value: unknown): value is string {
  return typeof value === "string" && UUID_PATTERN.test(value);
}

async function executeNextActionMutation(
  db: ScopedMutationDatabaseClient,
  input: PersistentNextActionMutationInput,
): Promise<PersistentNextActionMutationResult> {
  const eventId = randomUUID();
  const result = await db.query<MutationOutcomeRow>(MUTATION_SQL, [
    input.contractingId,
    input.expectedNextAction,
    input.newNextAction,
    eventId,
  ]);

  const outcome = result.rows[0]?.outcome;

  if (outcome === "updated" || outcome === "unchanged" || outcome === "conflict") {
    return outcome;
  }

  if (outcome === "denied") {
    return "not-available";
  }

  throw new Error("unexpected next-action mutation outcome");
}

/**
 * First persistent domain write from ADR-011.
 *
 * The caller supplies only the candidate contracting UUID and old/new scalar
 * values. Trusted identity, team, actor and membership are derived by the
 * server/database boundary; the audit event UUID is generated here and cannot
 * be supplied by a form/browser payload.
 */
export async function mutatePersistentContractingNextAction(
  input: PersistentNextActionMutationInput,
): Promise<PersistentNextActionMutationResult> {
  if (
    !input ||
    typeof input !== "object" ||
    !isCandidateContractingId(input.contractingId)
  ) {
    return "not-available";
  }

  if (
    !isNullableString(input.expectedNextAction) ||
    !isNullableString(input.newNextAction)
  ) {
    return "unavailable";
  }

  try {
    return await withTrustedDatabaseMutationContext((db) =>
      executeNextActionMutation(db, input),
    );
  } catch {
    return "unavailable";
  }
}
