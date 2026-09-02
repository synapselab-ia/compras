import "server-only";

import { Pool, type PoolClient } from "@neondatabase/serverless";

import { getVerifiedExternalIdentity } from "@/server/auth/external-identity";

const PROTECTED_TABLES = [
  "app_users",
  "memberships",
  "teams",
  "contractings",
  "related_identifiers",
  "contracting_items",
  "contracting_events",
] as const;

export type ScopedDatabaseClient = Pick<PoolClient, "query">;

type RoleSafetyRow = {
  rolname: string;
  rolsuper: boolean;
  rolbypassrls: boolean;
  owns_protected_tables: boolean;
};

export class TrustedDatabaseContextError extends Error {
  constructor() {
    super("Trusted database context is unavailable.");
    this.name = "TrustedDatabaseContextError";
  }
}

function readDatabaseConnectionString(): string | null {
  const value = process.env.DATABASE_URL;

  if (!value || value !== value.trim()) {
    return null;
  }

  try {
    const protocol = new URL(value).protocol;

    if (protocol !== "postgres:" && protocol !== "postgresql:") {
      return null;
    }
  } catch {
    return null;
  }

  return value;
}

async function assertOperationalRole(client: PoolClient): Promise<void> {
  const result = await client.query<RoleSafetyRow>(
    `SELECT
       r.rolname,
       r.rolsuper,
       r.rolbypassrls,
       EXISTS (
         SELECT 1
         FROM pg_catalog.pg_class AS c
         JOIN pg_catalog.pg_namespace AS n ON n.oid = c.relnamespace
         WHERE n.nspname = 'public'
           AND c.relname = ANY($1::text[])
           AND c.relowner = r.oid
       ) AS owns_protected_tables
     FROM pg_catalog.pg_roles AS r
     WHERE r.rolname = current_user`,
    [[...PROTECTED_TABLES]],
  );

  const role = result.rows[0];

  if (
    !role ||
    role.rolsuper ||
    role.rolbypassrls ||
    role.owns_protected_tables ||
    role.rolname === "neondb_owner"
  ) {
    throw new TrustedDatabaseContextError();
  }
}

/**
 * Runs one protected read operation inside the exact transaction that carries
 * the verified external identity. The caller cannot provide identity or scope.
 */
export async function withTrustedDatabaseContext<T>(
  operation: (db: ScopedDatabaseClient) => Promise<T>,
): Promise<T> {
  const identity = await getVerifiedExternalIdentity();
  const connectionString = readDatabaseConnectionString();

  if (!identity || !connectionString) {
    throw new TrustedDatabaseContextError();
  }

  const pool = new Pool({ connectionString });
  let client: PoolClient | null = null;
  let transactionOpen = false;

  try {
    client = await pool.connect();
    await client.query("BEGIN READ ONLY");
    transactionOpen = true;

    await assertOperationalRole(client);

    const claims = JSON.stringify({
      iss: identity.issuer,
      sub: identity.subject,
    });

    await client.query(
      "SELECT set_config('request.jwt.claims', $1, true)",
      [claims],
    );

    const result = await operation(client);

    await client.query("COMMIT");
    transactionOpen = false;

    return result;
  } catch {
    if (client && transactionOpen) {
      try {
        await client.query("ROLLBACK");
      } catch {
        // The connection is closed immediately below; never reuse uncertain state.
      }
    }

    throw new TrustedDatabaseContextError();
  } finally {
    client?.release(true);

    try {
      await pool.end();
    } catch {
      // No connection is reused by this adapter after a protected operation.
    }
  }
}
