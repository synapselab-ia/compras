import "server-only";

import { randomUUID } from "node:crypto";

import {
  withTrustedDatabaseMutationContext,
  type ScopedMutationDatabaseClient,
} from "@/server/database/trusted-mutation-context";

const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export type PersistentManualTimelineNoteCreateInput = Readonly<{
  contractingId: string;
  eventId: string;
  note: string | null;
}>;

export type PersistentManualTimelineNoteCreateResult =
  | "created"
  | "already-added"
  | "not-available"
  | "unavailable";

type CreateOutcomeRow = {
  outcome: string;
};

const CREATE_SQL = `
  SELECT public.create_manual_timeline_note(
    $1::uuid,
    $2::uuid,
    $3::text
  ) AS outcome
`;

function isCandidateUuid(value: unknown): value is string {
  return typeof value === "string" && UUID_PATTERN.test(value);
}

function isNullableString(value: unknown): value is string | null {
  return value === null || typeof value === "string";
}

async function executePersistentManualTimelineNoteCreate(
  db: ScopedMutationDatabaseClient,
  input: PersistentManualTimelineNoteCreateInput,
): Promise<PersistentManualTimelineNoteCreateResult> {
  const result = await db.query<CreateOutcomeRow>(CREATE_SQL, [
    input.contractingId,
    input.eventId,
    input.note,
  ]);

  const outcome = result.rows[0]?.outcome;

  if (outcome === "created" || outcome === "already-added") {
    return outcome;
  }

  if (outcome === "denied") {
    return "not-available";
  }

  throw new Error("unexpected manual timeline note create outcome");
}

/**
 * Prepares the stable event UUID for one manual-note intent.
 * The caller must retain this value across retries of that same intent.
 * It is opaque, non-secret and never grants authorization.
 */
export function preparePersistentManualTimelineNoteEventId(): string {
  return randomUUID();
}

/**
 * Persists only the ADR-017 manual timeline note boundary.
 *
 * Team, actor, membership, event type and timestamps are derived or fixed
 * inside trusted server/database boundaries. Note text is forwarded exactly,
 * including null, empty and whitespace-only values.
 */
export async function createPersistentManualTimelineNote(
  input: PersistentManualTimelineNoteCreateInput,
): Promise<PersistentManualTimelineNoteCreateResult> {
  if (
    !input ||
    typeof input !== "object" ||
    !isCandidateUuid(input.contractingId) ||
    !isCandidateUuid(input.eventId) ||
    !isNullableString(input.note)
  ) {
    return "unavailable";
  }

  try {
    return await withTrustedDatabaseMutationContext((db) =>
      executePersistentManualTimelineNoteCreate(db, input),
    );
  } catch {
    return "unavailable";
  }
}
