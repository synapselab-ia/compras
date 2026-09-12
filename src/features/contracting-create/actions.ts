"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";

import { readPersistentReadMode } from "@/server/persistent-read-mode";
import { createPersistentContracting } from "./persistent-create";

const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const CREATE_PATH = "/contratacoes/nova";

type ParsedRequiredField = Readonly<
  | { ok: true; value: string }
  | { ok: false; value: null }
>;

function readRequiredStringOnce(formData: FormData, name: string): ParsedRequiredField {
  const values = formData.getAll(name);

  if (values.length !== 1 || typeof values[0] !== "string") {
    return { ok: false, value: null };
  }

  return { ok: true, value: values[0] };
}

function isCandidateContractingId(value: string): boolean {
  return UUID_PATTERN.test(value);
}

function detailPath(contractingId: string): string {
  return `/contratacoes/${encodeURIComponent(contractingId)}`;
}

function createFeedbackPath(result: "not-available" | "unavailable"): string {
  return `${CREATE_PATH}?creation=${result}`;
}

/**
 * The only F30 browser-facing creation entrypoint. Framework fields and forged
 * unrelated authority fields can arrive in FormData, but only the two explicit
 * scalars below are read and forwarded to the F29 server/database boundary.
 */
export async function createPersistentContractingAction(formData: FormData): Promise<never> {
  if (readPersistentReadMode() !== "persistent") {
    redirect("/");
  }

  const contractingId = readRequiredStringOnce(formData, "contractingId");
  const object = readRequiredStringOnce(formData, "object");

  if (!contractingId.ok || !isCandidateContractingId(contractingId.value)) {
    redirect(createFeedbackPath("unavailable"));
  }

  if (!object.ok) {
    redirect(createFeedbackPath("unavailable"));
  }

  let result: Awaited<ReturnType<typeof createPersistentContracting>>;

  try {
    result = await createPersistentContracting({
      contractingId: contractingId.value,
      object: object.value,
    });
  } catch {
    result = "unavailable";
  }

  if (result === "created" || result === "already-created") {
    const path = detailPath(contractingId.value);
    revalidatePath("/");
    revalidatePath(path);
    redirect(`${path}?creation=${result}`);
  }

  redirect(createFeedbackPath(result));
}
