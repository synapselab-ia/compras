"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";

import { readPersistentReadMode } from "@/server/persistent-read-mode";
import { mutatePersistentContractingNextAction } from "./persistent-mutation";
import { mutatePersistentContractingObject } from "./persistent-object-mutation";
import { isPersistentContractingId } from "./persistent-read";

type ParsedNullableField = Readonly<
  | { ok: true; value: string | null }
  | { ok: false; value: null }
>;

type ItemMutationBrowserResult =
  | "updated"
  | "unchanged"
  | "conflict"
  | "not-available"
  | "unavailable";

type RelatedIdentifierCreateBrowserResult =
  | "created"
  | "already-linked"
  | "not-available"
  | "unavailable";

const ITEM_CREATE_FORM_FIELDS = new Set([
  "contractingId",
  "description",
  "quantity",
  "unit",
  "catalogCode",
]);

const ITEM_MUTATION_FORM_FIELDS = new Set([
  "contractingId",
  "itemId",
  "expectedDescription",
  "expectedQuantity",
  "expectedUnitKind",
  "expectedUnit",
  "expectedCatalogCodeKind",
  "expectedCatalogCode",
  "newDescription",
  "newQuantity",
  "newUnitKind",
  "newUnit",
  "newCatalogCodeKind",
  "newCatalogCode",
]);

const RELATED_IDENTIFIER_CREATE_FORM_FIELDS = new Set([
  "contractingId",
  "relatedIdentifierId",
  "identifierKindKind",
  "identifierKind",
  "identifierValue",
  "sourceSystemKind",
  "sourceSystem",
  "noteKind",
  "note",
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

/**
 * F39 new quantity must be an explicit scalar. Literal empty means SQL NULL;
 * every non-empty string is forwarded exactly for PostgreSQL numeric parsing.
 */
function readNewItemQuantityOnce(formData: FormData): ParsedNullableField {
  const values = formData.getAll("newQuantity");

  if (values.length !== 1 || typeof values[0] !== "string") {
    return { ok: false, value: null };
  }

  return { ok: true, value: values[0] === "" ? null : values[0] };
}

/**
 * Nullable text fields use an explicit transport kind so SQL NULL never gets
 * inferred from an empty string. A text scalar is required only for kind=text.
 * For kind=null, an optional single text scalar is ignored by design.
 */
function readNullableTextTransportOnce(
  formData: FormData,
  kindName: string,
  valueName: string,
): ParsedNullableField {
  const kind = readRequiredStringOnce(formData, kindName);
  const values = formData.getAll(valueName);

  if (values.length > 1 || (values.length === 1 && typeof values[0] !== "string")) {
    return { ok: false, value: null };
  }

  if (kind === "null") {
    return { ok: true, value: null };
  }

  if (kind === "text" && values.length === 1) {
    return { ok: true, value: values[0] as string };
  }

  return { ok: false, value: null };
}

function hasOnlyExpectedItemCreateFields(formData: FormData): boolean {
  for (const name of formData.keys()) {
    if (!ITEM_CREATE_FORM_FIELDS.has(name) && !name.startsWith("$ACTION_")) {
      return false;
    }
  }

  return true;
}

function hasOnlyExpectedItemMutationFields(formData: FormData): boolean {
  for (const name of formData.keys()) {
    if (!ITEM_MUTATION_FORM_FIELDS.has(name) && !name.startsWith("$ACTION_")) {
      return false;
    }
  }

  return true;
}

function hasOnlyExpectedRelatedIdentifierCreateFields(formData: FormData): boolean {
  for (const name of formData.keys()) {
    if (
      !RELATED_IDENTIFIER_CREATE_FORM_FIELDS.has(name) &&
      !name.startsWith("$ACTION_")
    ) {
      return false;
    }
  }

  return true;
}

function isItemMutationBrowserResult(value: unknown): value is ItemMutationBrowserResult {
  return (
    value === "updated" ||
    value === "unchanged" ||
    value === "conflict" ||
    value === "not-available" ||
    value === "unavailable"
  );
}

function isRelatedIdentifierCreateBrowserResult(
  value: unknown,
): value is RelatedIdentifierCreateBrowserResult {
  return (
    value === "created" ||
    value === "already-linked" ||
    value === "not-available" ||
    value === "unavailable"
  );
}

function detailPath(contractingId: string): string {
  return `/contratacoes/${encodeURIComponent(contractingId)}`;
}

function relatedIdentifierCreateFeedbackPath(
  path: string,
  result: RelatedIdentifierCreateBrowserResult,
  retryCandidate?: string,
): string {
  const base = `${path}?relatedIdentifierCreation=${result}`;

  return result === "unavailable" &&
    retryCandidate &&
    isPersistentContractingId(retryCandidate)
    ? `${base}&relatedIdentifierCandidate=${encodeURIComponent(retryCandidate)}`
    : base;
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

  let result: "created" | "not-available" | "unavailable";

  try {
    const { createPersistentContractingItem } = await import("./persistent-item-create");
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

/**
 * The only F42 browser-facing related identifier creation entrypoint. The
 * prepared UUID is an opaque idempotency key, never scope or authorization.
 * Only the nine approved transport scalars can reach F41; nullable text uses
 * an explicit null/text discriminator and the action performs no SQL itself.
 */
export async function createPersistentRelatedIdentifierAction(
  formData: FormData,
): Promise<never> {
  if (readPersistentReadMode() !== "persistent") {
    redirect("/");
  }

  const contractingId = readRequiredStringOnce(formData, "contractingId");

  if (!contractingId || !isPersistentContractingId(contractingId)) {
    redirect("/");
  }

  const path = detailPath(contractingId);
  const relatedIdentifierId = readRequiredStringOnce(
    formData,
    "relatedIdentifierId",
  );
  const retryCandidate =
    relatedIdentifierId && isPersistentContractingId(relatedIdentifierId)
      ? relatedIdentifierId
      : undefined;

  if (
    !hasOnlyExpectedRelatedIdentifierCreateFields(formData) ||
    !retryCandidate
  ) {
    redirect(
      relatedIdentifierCreateFeedbackPath(
        path,
        "unavailable",
        retryCandidate,
      ),
    );
  }

  const identifierKind = readNullableTextTransportOnce(
    formData,
    "identifierKindKind",
    "identifierKind",
  );
  const identifierValue = readRequiredStringOnce(formData, "identifierValue");
  const sourceSystem = readNullableTextTransportOnce(
    formData,
    "sourceSystemKind",
    "sourceSystem",
  );
  const note = readNullableTextTransportOnce(formData, "noteKind", "note");

  if (
    !identifierKind.ok ||
    identifierValue === null ||
    !sourceSystem.ok ||
    !note.ok
  ) {
    redirect(
      relatedIdentifierCreateFeedbackPath(
        path,
        "unavailable",
        retryCandidate,
      ),
    );
  }

  let result: RelatedIdentifierCreateBrowserResult = "unavailable";

  try {
    const { createPersistentRelatedIdentifier } = await import(
      "./persistent-related-identifier-create"
    );
    const boundaryResult: unknown = await createPersistentRelatedIdentifier({
      contractingId,
      relatedIdentifierId: retryCandidate,
      identifierKind: identifierKind.value,
      identifierValue,
      sourceSystem: sourceSystem.value,
      note: note.value,
    });

    if (isRelatedIdentifierCreateBrowserResult(boundaryResult)) {
      result = boundaryResult;
    }
  } catch {
    result = "unavailable";
  }

  if (result === "created" || result === "already-linked") {
    revalidatePath(path);
  }

  redirect(
    relatedIdentifierCreateFeedbackPath(
      path,
      result,
      result === "unavailable" ? retryCandidate : undefined,
    ),
  );
}

/**
 * The only F39 browser-facing item edit entrypoint. It carries the complete
 * protected four-field snapshot plus the complete requested four-field state
 * to F38. It owns no SQL/DML and accepts no browser authority for team, actor,
 * membership, event IDs, ordinal, retired state, timestamps or navigation.
 */
export async function updatePersistentContractingItemAction(formData: FormData): Promise<never> {
  if (readPersistentReadMode() !== "persistent") {
    redirect("/");
  }

  const contractingId = readRequiredStringOnce(formData, "contractingId");

  if (!contractingId || !isPersistentContractingId(contractingId)) {
    redirect("/");
  }

  const path = detailPath(contractingId);

  if (!hasOnlyExpectedItemMutationFields(formData)) {
    redirect(`${path}?itemMutation=unavailable`);
  }

  const itemId = readRequiredStringOnce(formData, "itemId");

  if (!itemId || !isPersistentContractingId(itemId)) {
    redirect(`${path}?itemMutation=unavailable`);
  }

  const expectedDescription = readRequiredStringOnce(formData, "expectedDescription");
  const expectedQuantity = readNullableStringOnce(formData, "expectedQuantity");
  const expectedUnit = readNullableTextTransportOnce(
    formData,
    "expectedUnitKind",
    "expectedUnit",
  );
  const expectedCatalogCode = readNullableTextTransportOnce(
    formData,
    "expectedCatalogCodeKind",
    "expectedCatalogCode",
  );
  const newDescription = readRequiredStringOnce(formData, "newDescription");
  const newQuantity = readNewItemQuantityOnce(formData);
  const newUnit = readNullableTextTransportOnce(formData, "newUnitKind", "newUnit");
  const newCatalogCode = readNullableTextTransportOnce(
    formData,
    "newCatalogCodeKind",
    "newCatalogCode",
  );

  if (
    expectedDescription === null ||
    !expectedQuantity.ok ||
    !expectedUnit.ok ||
    !expectedCatalogCode.ok ||
    newDescription === null ||
    !newQuantity.ok ||
    !newUnit.ok ||
    !newCatalogCode.ok
  ) {
    redirect(`${path}?itemMutation=unavailable`);
  }

  let result: ItemMutationBrowserResult = "unavailable";

  try {
    const { mutatePersistentContractingItem } = await import("./persistent-item-mutation");
    const boundaryResult: unknown = await mutatePersistentContractingItem({
      contractingId,
      itemId,
      expectedDescription,
      expectedQuantity: expectedQuantity.value,
      expectedUnit: expectedUnit.value,
      expectedCatalogCode: expectedCatalogCode.value,
      newDescription,
      newQuantity: newQuantity.value,
      newUnit: newUnit.value,
      newCatalogCode: newCatalogCode.value,
    });

    if (isItemMutationBrowserResult(boundaryResult)) {
      result = boundaryResult;
    }
  } catch {
    result = "unavailable";
  }

  if (result === "updated") {
    revalidatePath(path);
  }

  redirect(`${path}?itemMutation=${result}`);
}
