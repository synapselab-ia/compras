import "server-only";

export const SELF_HOSTED_AUTH_ISSUER =
  "urn:compras:better-auth:self-hosted:v1";
export const AUTH_SCHEMA_POOL_OPTIONS = "-c search_path=auth";

export type SelfHostedAuthConfiguration = Readonly<{
  authDatabaseUrl: string;
  baseUrl: string;
  secret: string;
}>;

function readExactEnvironmentValue(name: string): string | null {
  const value = process.env[name];

  if (!value || value.trim() !== value) {
    return null;
  }

  return value;
}

function readStrictHttpsOrigin(value: string): string | null {
  let url: URL;

  try {
    url = new URL(value);
  } catch {
    return null;
  }

  const hostname = url.hostname.toLowerCase();
  const isLoopback =
    hostname === "localhost" ||
    hostname.endsWith(".localhost") ||
    hostname === "127.0.0.1" ||
    hostname === "::1";

  if (
    url.protocol !== "https:" ||
    url.username ||
    url.password ||
    url.pathname !== "/" ||
    url.search ||
    url.hash ||
    hostname.includes("*") ||
    isLoopback ||
    value !== url.origin
  ) {
    return null;
  }

  return url.origin;
}

function readPostgresConnectionString(value: string): string | null {
  try {
    const url = new URL(value);
    return url.protocol === "postgres:" || url.protocol === "postgresql:"
      ? value
      : null;
  } catch {
    return null;
  }
}

/**
 * Reads only the server-side Better Auth configuration. Invalid or incomplete
 * configuration fails closed and never falls back to demo/provider auth.
 */
export function readSelfHostedAuthConfiguration(): SelfHostedAuthConfiguration | null {
  const rawAuthDatabaseUrl = readExactEnvironmentValue("AUTH_DATABASE_URL");
  const secret = readExactEnvironmentValue("BETTER_AUTH_SECRET");
  const rawBaseUrl = readExactEnvironmentValue("COMPRAS_AUTH_BASE_URL");

  if (!rawAuthDatabaseUrl || !secret || !rawBaseUrl || secret.length < 32) {
    return null;
  }

  const authDatabaseUrl = readPostgresConnectionString(rawAuthDatabaseUrl);
  const baseUrl = readStrictHttpsOrigin(rawBaseUrl);

  if (!authDatabaseUrl || !baseUrl) {
    return null;
  }

  const domainDatabaseUrl = readExactEnvironmentValue("DATABASE_URL");

  if (domainDatabaseUrl && domainDatabaseUrl === authDatabaseUrl) {
    return null;
  }

  return Object.freeze({ authDatabaseUrl, baseUrl, secret });
}
