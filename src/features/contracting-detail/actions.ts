"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";

import { readPersistentReadMode } from "@/server/persistent-read-mode";
import { mutatePersistentContractingNextAction } from "./persistent-mutation";
import { isPersistentContractingId } from "./persistent-read";

type ParsedNullableField = Readonly<
  | { ok: true; value: string | null }
  | { ok: false; value: null }
>;

function readRequiredStringOnce(formData: FormData, name: string): string | null {
  const values = formData.getAll(name);

  if (values.length !== 1 || typeof values[0] !== "string") {
    return null;
  }

  return values[0];
}

/**
 * Absence deliberately represents SQL NULL. A present empty string remains the
 * literal empty string; F27 does not invent empty-to-null business semantics.
 */
function readNullableStringOnce(formData: FormData, name: string): ParsedNullableField {
  const values = formData.getAll(name);

  if (values.length === 0) {
    return { ok: true, value: null };
  }

  if (values.length !== 1 || typeof values[0] !== "string") {
    return { ok: false, value: null };
  }

  return { ok: true, value: values[0] };
}

function detailPath(contractingId: string): string {
  return `/contratacoes/${encodeURIComponent(contractingId)}`;
}

/**
 * The only F27 write entrypoint. React/Next may add internal `$ACTION_*` form
 * fields, and forged unrelated fields may also arrive; neither is trusted or
 * forwarded. Only the three explicitly parsed values reach the F26 boundary.
 */
export async function updatePersistentNextActionAction(formData: FormData): Promise<never> {
  if (readPersistentReadMode() !== "persistent") {
    redirect("/");
  }

  const contractingId = readRequiredStringOnce(formData, "contractingId");

  if (!contractingId || !isPersistentContractingId(contractingId)) {
    redirect("/");
  }

  const path = detailPath(contractingId);
  const expectedNextAction = readNullableStringOnce(formData, "expectedNextAction");
  const newNextAction = readNullableStringOnce(formData, "newNextAction");

  if (!expectedNextAction.ok || !newNextAction.ok) {
    redirect(`${path}?mutation=unavailable`);
  }

  let result: Awaited<ReturnType<typeof mutatePersistentContractingNextAction>>;

  try {
    result = await mutatePersistentContractingNextAction({
      contractingId,
      expectedNextAction: expectedNextAction.value,
      newNextAction: newNextAction.value,
    });
  } catch {
    result = "unavailable";
  }

  if (result === "updated" || result === "conflict") {
    revalidatePath(path);
  }

  redirect(`${path}?mutation=${result}`);
}
