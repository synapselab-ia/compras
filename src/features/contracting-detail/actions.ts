"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";

import { readPersistentReadMode } from "@/server/persistent-read-mode";
import { createPersistentContractingItem } from "./persistent-item-create";
import { mutatePersistentContractingNextAction } from "./persistent-mutation";
import { mutatePersistentContractingObject } from "./persistent-object-mutation";
import { isPersistentContractingId } from "./persistent-read";

type ParsedNullableField = Readonly<
  | { ok: true; value: string | null }
  | { ok: false; value: null }
>;

const ITEM_CREATE_FORM_FIELDS = new Set([
  "contractingId",
  "description",
  "quantity",
  "unit",
  "catalogCode",
]);

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

/**
 * Quantity is the only F36 form field where an empty UI control encodes the
 * nullable absence state. Non-empty text, including whitespace, is preserved
 * exactly and PostgreSQL remains responsible for the numeric cast.
 */
function readOptionalQuantityOnce(formData: FormData): ParsedNullableField {
  const values = formData.getAll("quantity");

  if (values.length === 0) {
    return { ok: true, value: null };
  }

  if (values.length !== 1 || typeof values[0] !== "string") {
    return { ok: false, value: null };
  }

  return { ok: true, value: values[0] === "" ? null : values[0] };
}

function hasOnlyExpectedItemCreateFields(formData: FormData): boolean {
  for (const name of formData.keys()) {
    if (!ITEM_CREATE_FORM_FIELDS.has(name) && !name.startsWith("$ACTION_")) {
      return false;
    }
  }

  return true;
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

/**
 * The only F33 browser-facing object edit entrypoint. `object` is NOT NULL, so
 * expected/new values must each be present exactly once as strings. Empty
 * strings and whitespace are valid values and are forwarded without changes.
 * Framework fields and unrelated forged authority fields are never forwarded.
 */
export async function updatePersistentObjectAction(formData: FormData): Promise<never> {
  if (readPersistentReadMode() !== "persistent") {
    redirect("/");
  }

  const contractingId = readRequiredStringOnce(formData, "contractingId");

  if (!contractingId || !isPersistentContractingId(contractingId)) {
    redirect("/");
  }

  const path = detailPath(contractingId);
  const expectedObject = readRequiredStringOnce(formData, "expectedObject");
  const newObject = readRequiredStringOnce(formData, "newObject");

  if (expectedObject === null || newObject === null) {
    redirect(`${path}?objectMutation=unavailable`);
  }

  let result: Awaited<ReturnType<typeof mutatePersistentContractingObject>>;

  try {
    result = await mutatePersistentContractingObject({
      contractingId,
      expectedObject,
      newObject,
    });
  } catch {
    result = "unavailable";
  }

  if (result === "updated" || result === "conflict") {
    revalidatePath(path);
  }

  redirect(`${path}?objectMutation=${result}`);
}

/**
 * The only F36 browser-facing item creation entrypoint. It accepts exactly the
 * five ADR-014 fields plus framework-internal `$ACTION_*` transport fields.
 * Any additional browser field fails closed before F35, so team, actor,
 * membership, ordinal, internal UUIDs and navigation targets cannot become
 * authority. The action performs no SQL or DML of its own.
 */
export async function createPersistentContractingItemAction(formData: FormData): Promise<never> {
  if (readPersistentReadMode() !== "persistent") {
    redirect("/");
  }

  const contractingId = readRequiredStringOnce(formData, "contractingId");

  if (!contractingId || !isPersistentContractingId(contractingId)) {
    redirect("/");
  }

  const path = detailPath(contractingId);

  if (!hasOnlyExpectedItemCreateFields(formData)) {
    redirect(`${path}?itemCreation=unavailable`);
  }

  const description = readRequiredStringOnce(formData, "description");
  const quantity = readOptionalQuantityOnce(formData);
  const unit = readRequiredStringOnce(formData, "unit");
  const catalogCode = readRequiredStringOnce(formData, "catalogCode");

  if (description === null || !quantity.ok || unit === null || catalogCode === null) {
    redirect(`${path}?itemCreation=unavailable`);
  }

  let result: Awaited<ReturnType<typeof createPersistentContractingItem>>;

  try {
    result = await createPersistentContractingItem({
      contractingId,
      description,
      quantity: quantity.value,
      unit,
      catalogCode,
    });
  } catch {
    result = "unavailable";
  }

  if (result === "created") {
    revalidatePath(path);
  }

  redirect(`${path}?itemCreation=${result}`);
}
