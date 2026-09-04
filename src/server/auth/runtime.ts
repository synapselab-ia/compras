import "server-only";

import { betterAuth } from "better-auth";
import { headers } from "next/headers";
import { Pool } from "pg";

import {
  AUTH_SCHEMA_POOL_OPTIONS,
  SELF_HOSTED_AUTH_ISSUER,
  readSelfHostedAuthConfiguration,
  type SelfHostedAuthConfiguration,
} from "./configuration";

export type ExternalIdentity = Readonly<{
  issuer: string;
  subject: string;
}>;

export type PrivateAuthSessionState =
  | Readonly<{ kind: "authenticated"; identity: ExternalIdentity }>
  | Readonly<{ kind: "unauthenticated" }>
  | Readonly<{ kind: "unavailable" }>;

type BetterAuthInstance = ReturnType<typeof betterAuth>;

export type ConfiguredPrivateAuth = Readonly<{
  issuer: string;
  auth: BetterAuthInstance;
}>;

type RuntimeCache = {
  configuration: SelfHostedAuthConfiguration;
  configured: ConfiguredPrivateAuth;
  pool: Pool;
};

let runtimeCache: RuntimeCache | null = null;

function sameConfiguration(
  left: SelfHostedAuthConfiguration,
  right: SelfHostedAuthConfiguration,
): boolean {
  return (
    left.authDatabaseUrl === right.authDatabaseUrl &&
    left.baseUrl === right.baseUrl &&
    left.secret === right.secret
  );
}

function readErrorStatusCode(error: unknown): number | null {
  if (!error || typeof error !== "object") {
    return null;
  }

  const record = error as Record<string, unknown>;
  const body =
    record.body && typeof record.body === "object"
      ? (record.body as Record<string, unknown>)
      : null;
  const candidates = [
    record.statusCode,
    record.status,
    body?.statusCode,
    body?.status,
  ];

  for (const candidate of candidates) {
    if (typeof candidate === "number" && Number.isInteger(candidate)) {
      return candidate;
    }

    if (typeof candidate === "string") {
      const numeric = Number(candidate);
      if (Number.isInteger(numeric) && numeric >= 100 && numeric <= 599) {
        return numeric;
      }

      switch (candidate.toUpperCase()) {
        case "BAD_REQUEST":
          return 400;
        case "UNAUTHORIZED":
          return 401;
        case "FORBIDDEN":
          return 403;
        case "NOT_FOUND":
          return 404;
        case "CONFLICT":
          return 409;
        case "UNPROCESSABLE_ENTITY":
          return 422;
        case "TOO_MANY_REQUESTS":
          return 429;
        case "INTERNAL_SERVER_ERROR":
          return 500;
        case "SERVICE_UNAVAILABLE":
          return 503;
      }
    }
  }

  return null;
}

export function isAuthProviderUnavailableError(error: unknown): boolean {
  const status = readErrorStatusCode(error);
  return status === null || status < 400 || status >= 500;
}

export function getConfiguredPrivateAuth(): ConfiguredPrivateAuth | null {
  const configuration = readSelfHostedAuthConfiguration();

  if (!configuration) {
    return null;
  }

  if (
    runtimeCache &&
    sameConfiguration(runtimeCache.configuration, configuration)
  ) {
    return runtimeCache.configured;
  }

  if (runtimeCache) {
    void runtimeCache.pool.end().catch(() => undefined);
    runtimeCache = null;
  }

  const pool = new Pool({
    connectionString: configuration.authDatabaseUrl,
    options: AUTH_SCHEMA_POOL_OPTIONS,
    max: 5,
    application_name: "compras-auth-runtime",
  });

  // Pool errors are surfaced by the auth operation that depends on the pool.
  // Keep the event listener silent so no connection string/error detail reaches logs.
  pool.on("error", () => undefined);

  try {
    const auth = betterAuth({
      database: pool,
      baseURL: configuration.baseUrl,
      secret: configuration.secret,
      trustedOrigins: [configuration.baseUrl],
      emailAndPassword: {
        enabled: true,
        disableSignUp: true,
      },
      socialProviders: {},
      plugins: [],
    });

    const configured = Object.freeze({
      issuer: SELF_HOSTED_AUTH_ISSUER,
      auth,
    });

    runtimeCache = { configuration, configured, pool };
    return configured;
  } catch {
    void pool.end().catch(() => undefined);
    return null;
  }
}

/**
 * Resolves the external identity exclusively from a Better Auth session that
 * was validated server-side. Request/client supplied issuer or subject values
 * never participate in this function.
 */
export async function readPrivateAuthSessionState(): Promise<PrivateAuthSessionState> {
  const configured = getConfiguredPrivateAuth();

  if (!configured) {
    return { kind: "unavailable" };
  }

  try {
    const session = await configured.auth.api.getSession({
      headers: await headers(),
    });

    if (session === null) {
      return { kind: "unauthenticated" };
    }

    const subject = session?.user?.id;

    if (
      !session?.session ||
      typeof subject !== "string" ||
      subject.length === 0
    ) {
      return { kind: "unavailable" };
    }

    return {
      kind: "authenticated",
      identity: Object.freeze({
        issuer: configured.issuer,
        subject,
      }),
    };
  } catch (error) {
    const status = readErrorStatusCode(error);

    if (status === 401 || status === 403) {
      return { kind: "unauthenticated" };
    }

    return { kind: "unavailable" };
  }
}
