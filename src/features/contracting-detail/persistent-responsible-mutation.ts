import "server-only";

import { randomUUID } from "node:crypto";

import {
  withTrustedDatabaseMutationContext,
  type ScopedMutationDatabaseClient,
} from "@/server/database/trusted-mutation-context";

const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export type PersistentContractingResponsibleMutationInput = Readonly<{
  contractingId: string;
  expectedResponsibleMembershipId: string | null;
  newResponsibleMembershipId: string | null;
}>;

export type PersistentContractingResponsibleMutationResult =
  | "updated"
  | "unchanged"
  | "conflict"
  | "not-available"
  | "unavailable";

type MutationOutcomeRow = { outcome: string };

const MUTATION_SQL = `
  SELECT public.mutate_contracting_responsible(
    $1::uuid,
    $2::uuid,
    $3::uuid,
    $4::uuid
  ) AS outcome
`;

function isCandidateUuid(value: unknown): value is string {
  return typeof value === "string" && UUID_PATTERN.test(value);
}

function isNullableCandidateUuid(value: unknown): value is string | null {
  return value === null || isCandidateUuid(value);
}

async function executePersistentContractingResponsibleMutation(
  db: ScopedMutationDatabaseClient,
  input: PersistentContractingResponsibleMutationInput,
): Promise<PersistentContractingResponsibleMutationResult> {
  const result = await db.query<MutationOutcomeRow>(MUTATION_SQL, [
    input.contractingId,
    input.expectedResponsibleMembershipId,
    input.newResponsibleMembershipId,
    randomUUID(),
  ]);

  const outcome = result.rows[0]?.outcome;

  if (outcome === "updated" || outcome === "unchanged" || outcome === "conflict") {
    return outcome;
  }

  if (outcome === "denied") {
    return "not-available";
  }

  throw new Error("unexpected contracting responsible mutation outcome");
}

export async function mutatePersistentContractingResponsible(
  input: PersistentContractingResponsibleMutationInput,
): Promise<PersistentContractingResponsibleMutationResult> {
  if (!input || typeof input !== "object" || !isCandidateUuid(input.contractingId)) {
    return "not-available";
  }

  if (
    (input.expectedResponsibleMembershipId !== null &&
      typeof input.expectedResponsibleMembershipId !== "string") ||
    (input.newResponsibleMembershipId !== null &&
      typeof input.newResponsibleMembershipId !== "string")
  ) {
    return "unavailable";
  }

  if (
    !isNullableCandidateUuid(input.expectedResponsibleMembershipId) ||
    !isNullableCandidateUuid(input.newResponsibleMembershipId)
  ) {
    return "not-available";
  }

  try {
    return await withTrustedDatabaseMutationContext((db) =>
      executePersistentContractingResponsibleMutation(db, input),
    );
  } catch {
    return "unavailable";
  }
}
