import "server-only";

import { createHmac, hkdfSync } from "node:crypto";
import { isIP } from "node:net";

import { Pool } from "pg";

import {
  AUTH_SCHEMA_POOL_OPTIONS,
  readSelfHostedAuthConfiguration,
  type SelfHostedAuthConfiguration,
} from "./configuration";

const LIMITER_KDF_SALT = Buffer.from("compras/signin-limiter/v1", "utf8");
const LIMITER_KDF_INFO = Buffer.from("bucket-hmac-key", "utf8");

export type SignInLimiterDecision = "allowed" | "rejected" | "unavailable";

export type SignInLimiterDigests = Readonly<{
  source: string;
  identifier: string;
  pair: string;
}>;

type VercelRuntimeEnvironment = Readonly<{
  VERCEL?: string;
  VERCEL_ENV?: string;
}>;

type LimiterPoolCache = {
  authDatabaseUrl: string;
  pool: Pool;
};

let limiterPoolCache: LimiterPoolCache | null = null;

function isHostedVercelEnvironment(
  environment: VercelRuntimeEnvironment,
): boolean {
  return (
    environment.VERCEL === "1" &&
    (environment.VERCEL_ENV === "preview" ||
      environment.VERCEL_ENV === "production")
  );
}

function canonicalizeIp(value: string): string | null {
  const version = isIP(value);

  if (version === 4) {
    return value;
  }

  if (version !== 6) {
    return null;
  }

  try {
    const hostname = new URL(`http://[${value}]/`).hostname;

    if (!hostname.startsWith("[") || !hostname.endsWith("]")) {
      return null;
    }

    return hostname.slice(1, -1).toLowerCase();
  } catch {
    return null;
  }
}

/**
 * Resolves the only hosted source signal accepted by ADR-010. Alternate client
 * headers are intentionally ignored rather than used as fallback identity.
 */
export function resolveTrustedVercelSource(
  requestHeaders: Headers,
  environment: VercelRuntimeEnvironment,
): string | null {
  if (!isHostedVercelEnvironment(environment)) {
    return null;
  }

  const raw = requestHeaders.get("x-forwarded-for");

  if (
    !raw ||
    raw.trim() !== raw ||
    raw.includes(",") ||
    /\s/.test(raw)
  ) {
    return null;
  }

  return canonicalizeIp(raw);
}

export function normalizeSignInLimiterIdentifier(email: string): string | null {
  const normalized = email.trim().toLowerCase();

  if (normalized.length === 0 || normalized.length > 320) {
    return null;
  }

  return normalized;
}

function deriveLimiterHmacKey(secret: string): Buffer | null {
  if (secret.length < 32) {
    return null;
  }

  try {
    return Buffer.from(
      hkdfSync(
        "sha256",
        Buffer.from(secret, "utf8"),
        LIMITER_KDF_SALT,
        LIMITER_KDF_INFO,
        32,
      ),
    );
  } catch {
    return null;
  }
}

function digestBucket(kind: keyof SignInLimiterDigests, value: string, key: Buffer): string {
  return createHmac("sha256", key)
    .update(kind, "utf8")
    .update("\0", "utf8")
    .update(value, "utf8")
    .digest("hex");
}

/**
 * Converts source and identifier into opaque, domain-separated buckets before
 * any value reaches the limiter store. The raw email/source are never returned.
 */
export function deriveSignInLimiterDigests(input: Readonly<{
  source: string;
  email: string;
  secret: string;
}>): SignInLimiterDigests | null {
  const normalizedIdentifier = normalizeSignInLimiterIdentifier(input.email);
  const source = canonicalizeIp(input.source);
  const key = deriveLimiterHmacKey(input.secret);

  if (!normalizedIdentifier || !source || !key) {
    return null;
  }

  return Object.freeze({
    source: digestBucket("source", source, key),
    identifier: digestBucket("identifier", normalizedIdentifier, key),
    pair: digestBucket("pair", `${source}\0${normalizedIdentifier}`, key),
  });
}

function sameLimiterDatabase(
  cache: LimiterPoolCache,
  configuration: SelfHostedAuthConfiguration,
): boolean {
  return cache.authDatabaseUrl === configuration.authDatabaseUrl;
}

function getLimiterPool(configuration: SelfHostedAuthConfiguration): Pool {
  if (limiterPoolCache && sameLimiterDatabase(limiterPoolCache, configuration)) {
    return limiterPoolCache.pool;
  }

  if (limiterPoolCache) {
    void limiterPoolCache.pool.end().catch(() => undefined);
    limiterPoolCache = null;
  }

  const pool = new Pool({
    connectionString: configuration.authDatabaseUrl,
    options: AUTH_SCHEMA_POOL_OPTIONS,
    max: 5,
    application_name: "compras-signin-limiter",
    allowExitOnIdle: true,
  });

  // Driver errors are intentionally swallowed at the event boundary. The
  // request path maps store failure to a generic unavailable state and never
  // serializes connection/error details into logs.
  pool.on("error", () => undefined);
  limiterPoolCache = { authDatabaseUrl: configuration.authDatabaseUrl, pool };
  return pool;
}

/**
 * Executes the single database primitive that atomically consumes all three
 * fixed-policy buckets. This export also lets the PostgreSQL integration test
 * exercise the exact runtime query through a real non-privileged Pool.
 */
export async function consumeSignInLimiterDigests(
  pool: Pool,
  digests: SignInLimiterDigests,
): Promise<SignInLimiterDecision> {
  try {
    const result = await pool.query<{ allowed: boolean }>(
      `select auth_guard.consume_signin_attempt($1, $2, $3) as allowed`,
      [digests.source, digests.identifier, digests.pair],
    );
    const allowed = result.rows[0]?.allowed;

    return typeof allowed === "boolean"
      ? allowed
        ? "allowed"
        : "rejected"
      : "unavailable";
  } catch {
    return "unavailable";
  }
}

/**
 * Production composition: validate the Vercel source boundary, pseudonymize
 * buckets with the existing server-only Better Auth secret, then consume the
 * PostgreSQL limiter. Any missing/ambiguous configuration fails closed.
 */
export async function consumePrivateSignInAttempt(input: Readonly<{
  email: string;
  requestHeaders: Headers;
}>): Promise<SignInLimiterDecision> {
  const configuration = readSelfHostedAuthConfiguration();

  if (!configuration) {
    return "unavailable";
  }

  const source = resolveTrustedVercelSource(input.requestHeaders, {
    VERCEL: process.env.VERCEL,
    VERCEL_ENV: process.env.VERCEL_ENV,
  });

  if (!source) {
    return "unavailable";
  }

  const digests = deriveSignInLimiterDigests({
    source,
    email: input.email,
    secret: configuration.secret,
  });

  if (!digests) {
    return "unavailable";
  }

  return consumeSignInLimiterDigests(getLimiterPool(configuration), digests);
}
