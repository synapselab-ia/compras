import "server-only";

import { cookies, headers } from "next/headers";

import {
  getConfiguredPrivateAuth,
  isAuthProviderUnavailableError,
} from "./runtime";

export type ExistingIdentityCredentials = Readonly<{
  email: string;
  password: string;
}>;

export type PrivateSignInResult = "signed-in" | "rejected" | "unavailable";
export type PrivateSignOutResult = "signed-out" | "unavailable";

type CookieOptions = {
  domain?: string;
  path?: string;
  expires?: Date;
  httpOnly?: boolean;
  secure?: boolean;
  sameSite?: "lax" | "strict" | "none";
  maxAge?: number;
  priority?: "low" | "medium" | "high";
  partitioned?: boolean;
};

type ParsedSetCookie = Readonly<{
  name: string;
  value: string;
  options: CookieOptions;
}>;

function normalizeCredentials(
  credentials: ExistingIdentityCredentials,
): ExistingIdentityCredentials | null {
  const email = credentials.email.trim();
  const password = credentials.password;

  if (
    email.length === 0 ||
    email.length > 320 ||
    password.length === 0 ||
    password.length > 4096
  ) {
    return null;
  }

  return { email, password };
}

function parseSetCookie(value: string): ParsedSetCookie | null {
  const [nameValue, ...attributes] = value.split(";");
  const separator = nameValue.indexOf("=");

  if (separator <= 0) {
    return null;
  }

  const name = nameValue.slice(0, separator).trim();
  const cookieValue = nameValue.slice(separator + 1).trim();

  if (!/^[!#$%&'*+.^_`|~0-9A-Za-z-]+$/.test(name)) {
    return null;
  }

  const options: CookieOptions = {};

  for (const rawAttribute of attributes) {
    const attribute = rawAttribute.trim();
    const attributeSeparator = attribute.indexOf("=");
    const key = (
      attributeSeparator === -1
        ? attribute
        : attribute.slice(0, attributeSeparator)
    ).toLowerCase();
    const attributeValue =
      attributeSeparator === -1
        ? ""
        : attribute.slice(attributeSeparator + 1).trim();

    switch (key) {
      case "domain":
        if (attributeValue) options.domain = attributeValue;
        break;
      case "path":
        if (attributeValue.startsWith("/")) options.path = attributeValue;
        break;
      case "expires": {
        const expires = new Date(attributeValue);
        if (!Number.isNaN(expires.valueOf())) options.expires = expires;
        break;
      }
      case "max-age": {
        const maxAge = Number(attributeValue);
        if (Number.isInteger(maxAge)) options.maxAge = maxAge;
        break;
      }
      case "httponly":
        options.httpOnly = true;
        break;
      case "secure":
        options.secure = true;
        break;
      case "partitioned":
        options.partitioned = true;
        break;
      case "samesite": {
        const sameSite = attributeValue.toLowerCase();
        if (sameSite === "lax" || sameSite === "strict" || sameSite === "none") {
          options.sameSite = sameSite;
        }
        break;
      }
      case "priority": {
        const priority = attributeValue.toLowerCase();
        if (priority === "low" || priority === "medium" || priority === "high") {
          options.priority = priority;
        }
        break;
      }
    }
  }

  return Object.freeze({ name, value: cookieValue, options });
}

function readSetCookies(responseHeaders: Headers): ParsedSetCookie[] | null {
  const values = responseHeaders.getSetCookie();

  if (values.length === 0) {
    return null;
  }

  const parsed = values.map(parseSetCookie);

  if (parsed.some((cookie) => cookie === null)) {
    return null;
  }

  return parsed as ParsedSetCookie[];
}

function isSessionCookie(cookie: ParsedSetCookie): boolean {
  return cookie.name.toLowerCase().includes("session_token");
}

function isActiveSessionCookie(cookie: ParsedSetCookie): boolean {
  return (
    isSessionCookie(cookie) &&
    cookie.value.length > 0 &&
    cookie.options.httpOnly === true &&
    (cookie.options.maxAge === undefined || cookie.options.maxAge > 0) &&
    (cookie.options.expires === undefined || cookie.options.expires > new Date())
  );
}

function isSessionInvalidationCookie(cookie: ParsedSetCookie): boolean {
  return (
    isSessionCookie(cookie) &&
    (cookie.value.length === 0 ||
      (cookie.options.maxAge !== undefined && cookie.options.maxAge <= 0) ||
      (cookie.options.expires !== undefined && cookie.options.expires <= new Date()))
  );
}

function buildCookieRequestHeader(cookiesToSend: ParsedSetCookie[]): string {
  return cookiesToSend
    .filter((cookie) => cookie.value.length > 0)
    .map((cookie) => `${cookie.name}=${cookie.value}`)
    .join("; ");
}

async function persistSetCookies(cookiesToPersist: ParsedSetCookie[]): Promise<void> {
  const cookieStore = await cookies();

  for (const cookie of cookiesToPersist) {
    cookieStore.set(cookie.name, cookie.value, cookie.options);
  }
}

function readUserId(value: unknown): string | null {
  if (!value || typeof value !== "object") {
    return null;
  }

  const user = (value as { user?: unknown }).user;

  if (!user || typeof user !== "object") {
    return null;
  }

  const id = (user as { id?: unknown }).id;
  return typeof id === "string" && id.length > 0 ? id : null;
}

/**
 * Signs in only an identity that already exists. Better Auth stays closed to
 * signup and this Server Action path explicitly persists only cookies emitted
 * by a session that can be read back server-side.
 */
export async function signInExistingIdentity(
  credentials: ExistingIdentityCredentials,
): Promise<PrivateSignInResult> {
  const normalized = normalizeCredentials(credentials);

  if (!normalized) {
    return "rejected";
  }

  const configured = getConfiguredPrivateAuth();

  if (!configured) {
    return "unavailable";
  }

  try {
    const signedIn = await configured.auth.api.signInEmail({
      body: normalized,
      returnHeaders: true,
    });
    const setCookies = readSetCookies(signedIn.headers);
    const signedInUserId = readUserId(signedIn.response);

    if (
      !setCookies ||
      !signedInUserId ||
      !setCookies.some(isActiveSessionCookie)
    ) {
      return "unavailable";
    }

    const cookieHeader = buildCookieRequestHeader(setCookies);
    const session = await configured.auth.api.getSession({
      headers: new Headers({ cookie: cookieHeader }),
    });

    if (readUserId(session) !== signedInUserId) {
      return "unavailable";
    }

    await persistSetCookies(setCookies);
    return "signed-in";
  } catch (error) {
    return isAuthProviderUnavailableError(error) ? "unavailable" : "rejected";
  }
}

export async function signOutCurrentIdentity(): Promise<PrivateSignOutResult> {
  const configured = getConfiguredPrivateAuth();

  if (!configured) {
    return "unavailable";
  }

  try {
    const requestHeaders = await headers();
    const signedOut = await configured.auth.api.signOut({
      headers: requestHeaders,
      returnHeaders: true,
    });
    const setCookies = readSetCookies(signedOut.headers);

    if (!setCookies || !setCookies.some(isSessionInvalidationCookie)) {
      return "unavailable";
    }

    const revokedSession = await configured.auth.api.getSession({
      headers: requestHeaders,
    });

    if (revokedSession !== null) {
      return "unavailable";
    }

    await persistSetCookies(setCookies);
    return "signed-out";
  } catch {
    return "unavailable";
  }
}
