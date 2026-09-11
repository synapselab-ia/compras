import "server-only";

import { Pool, type PoolClient } from "@neondatabase/serverless";

import { getVerifiedExternalIdentity } from "@/server/auth/external-identity";
import {
  assertOperationalRoleSafety,
  readDatabaseConnectionString,
} from "./operational-safety";

export type ScopedDatabaseClient = Pick<PoolClient, "query">;

export class TrustedDatabaseContextError extends Error {
  constructor() {
    super("Trusted database context is unavailable.");
    this.name = "TrustedDatabaseContextError";
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

  let pool: Pool | null = null;
  let client: PoolClient | null = null;
  let transactionOpen = false;

  try {
    pool = new Pool({ connectionString });
    client = await pool.connect();
    await client.query("BEGIN READ ONLY");
    transactionOpen = true;

    await assertOperationalRoleSafety(client);

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
        // The connection is destroyed below; never reuse uncertain state.
      }
    }

    throw new TrustedDatabaseContextError();
  } finally {
    if (client) {
      try {
        client.release(true);
      } catch {
        // Pool shutdown below remains the final isolation boundary.
      }
    }

    if (pool) {
      try {
        await pool.end();
      } catch {
        // The adapter never reuses this pool after a protected operation.
      }
    }
  }
}
