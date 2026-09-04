import "server-only";

import { betterAuth } from "better-auth";
import { Pool } from "pg";

import {
  AUTH_SCHEMA_POOL_OPTIONS,
  readSelfHostedAuthConfiguration,
} from "./configuration";

const FICTITIOUS_BOOTSTRAP_MODE = "FICTITIOUS_ONE_SHOT";

export type FictitiousBootstrapCredentials = Readonly<{
  email: string;
  password: string;
  name: string;
}>;

export type FictitiousBootstrapResult =
  | Readonly<{ kind: "created"; subject: string }>
  | Readonly<{ kind: "disabled" }>
  | Readonly<{ kind: "rejected" }>
  | Readonly<{ kind: "unavailable" }>;

function normalizeFictitiousCredentials(
  credentials: FictitiousBootstrapCredentials,
): FictitiousBootstrapCredentials | null {
  const email = credentials.email.trim().toLowerCase();
  const password = credentials.password;
  const name = credentials.name.trim();
  const at = email.lastIndexOf("@");
  const domain = at === -1 ? "" : email.slice(at + 1);

  if (
    domain !== "example.invalid" ||
    email.length > 320 ||
    password.length === 0 ||
    password.length > 4096 ||
    name.length === 0 ||
    name.length > 120
  ) {
    return null;
  }

  return { email, password, name };
}

/**
 * Closed administrative bootstrap for local/ephemeral proof only. It is not
 * imported by any route/action, accepts only example.invalid identities, and
 * returns only the Better Auth subject. It never creates domain authorization.
 */
export async function bootstrapFictitiousIdentity(
  credentials: FictitiousBootstrapCredentials,
): Promise<FictitiousBootstrapResult> {
  if (process.env.COMPRAS_AUTH_BOOTSTRAP_MODE !== FICTITIOUS_BOOTSTRAP_MODE) {
    return { kind: "disabled" };
  }

  const normalized = normalizeFictitiousCredentials(credentials);

  if (!normalized) {
    return { kind: "rejected" };
  }

  const configuration = readSelfHostedAuthConfiguration();

  if (!configuration) {
    return { kind: "unavailable" };
  }

  const pool = new Pool({
    connectionString: configuration.authDatabaseUrl,
    options: AUTH_SCHEMA_POOL_OPTIONS,
    max: 1,
    application_name: "compras-auth-bootstrap",
  });

  pool.on("error", () => undefined);

  try {
    const bootstrapAuth = betterAuth({
      database: pool,
      baseURL: configuration.baseUrl,
      secret: configuration.secret,
      trustedOrigins: [configuration.baseUrl],
      emailAndPassword: {
        enabled: true,
        disableSignUp: false,
      },
      socialProviders: {},
      plugins: [],
    });
    const result = await bootstrapAuth.api.signUpEmail({ body: normalized });
    const subject = result?.user?.id;

    return typeof subject === "string" && subject.length > 0
      ? Object.freeze({ kind: "created" as const, subject })
      : { kind: "unavailable" };
  } catch {
    return { kind: "unavailable" };
  } finally {
    await pool.end().catch(() => undefined);
  }
}
