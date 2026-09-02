import "server-only";

import {
  createNeonAuth,
  NEON_AUTH_NETWORK_ERROR_CODES,
  type NeonAuthServerApiError,
} from "@neondatabase/auth/next/server";

export type ExternalIdentity = Readonly<{
  issuer: string;
  subject: string;
}>;

export type PrivateAuthSessionState =
  | Readonly<{ kind: "authenticated"; identity: ExternalIdentity }>
  | Readonly<{ kind: "unauthenticated" }>
  | Readonly<{ kind: "unavailable" }>;

export type ConfiguredPrivateAuth = Readonly<{
  issuer: string;
  auth: ReturnType<typeof createNeonAuth>;
}>;

type AuthConfiguration = Readonly<{
  baseUrl: string;
  cookieSecret: string;
}>;

function readExactEnvironmentValue(name: string): string | null {
  const value = process.env[name];

  if (!value || value !== value.trim()) {
    return null;
  }

  return value;
}

function readAuthConfiguration(): AuthConfiguration | null {
  const baseUrl = readExactEnvironmentValue("NEON_AUTH_BASE_URL");
  const cookieSecret = readExactEnvironmentValue("NEON_AUTH_COOKIE_SECRET");

  if (!baseUrl || !cookieSecret || cookieSecret.length < 32) {
    return null;
  }

  try {
    if (new URL(baseUrl).protocol !== "https:") {
      return null;
    }
  } catch {
    return null;
  }

  return { baseUrl, cookieSecret };
}

export function getConfiguredPrivateAuth(): ConfiguredPrivateAuth | null {
  const configuration = readAuthConfiguration();

  if (!configuration) {
    return null;
  }

  try {
    return {
      issuer: configuration.baseUrl,
      auth: createNeonAuth({
        baseUrl: configuration.baseUrl,
        cookies: {
          secret: configuration.cookieSecret,
        },
        logLevel: "silent",
      }),
    };
  } catch {
    return null;
  }
}

function readAuthApiError(error: unknown): Partial<NeonAuthServerApiError> | null {
  if (!error || typeof error !== "object") {
    return null;
  }

  return error as Partial<NeonAuthServerApiError>;
}

export function isAuthProviderUnavailableError(error: unknown): boolean {
  const apiError = readAuthApiError(error);

  if (!apiError) {
    return true;
  }

  if (
    typeof apiError.code === "string" &&
    (NEON_AUTH_NETWORK_ERROR_CODES as readonly string[]).includes(apiError.code)
  ) {
    return true;
  }

  if (apiError.code === "INTERNAL_ERROR") {
    return true;
  }

  return typeof apiError.status === "number" ? apiError.status >= 500 : true;
}

function isUnauthenticatedSessionError(error: unknown): boolean {
  const apiError = readAuthApiError(error);
  return apiError?.status === 401 || apiError?.status === 403;
}

/**
 * Resolves session state without accepting request-supplied identity or scope.
 * Missing/expired sessions are distinct from provider/configuration failure so
 * operational routes can request sign-in before attempting protected reads.
 */
export async function readPrivateAuthSessionState(): Promise<PrivateAuthSessionState> {
  const configured = getConfiguredPrivateAuth();

  if (!configured) {
    return { kind: "unavailable" };
  }

  try {
    const { data, error } = await configured.auth.getSession();

    if (error) {
      return isUnauthenticatedSessionError(error)
        ? { kind: "unauthenticated" }
        : { kind: "unavailable" };
    }

    if (!data || (data.session === null && data.user === null)) {
      return { kind: "unauthenticated" };
    }

    const subject = data.user?.id;

    if (!data.session || typeof subject !== "string" || subject.length === 0) {
      return { kind: "unavailable" };
    }

    return {
      kind: "authenticated",
      identity: Object.freeze({
        issuer: configured.issuer,
        subject,
      }),
    };
  } catch {
    return { kind: "unavailable" };
  }
}
