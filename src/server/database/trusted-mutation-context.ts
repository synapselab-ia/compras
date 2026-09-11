import "server-only";

import { Pool, type PoolClient } from "@neondatabase/serverless";

import { getVerifiedExternalIdentity } from "@/server/auth/external-identity";
import {
  assertOperationalRoleSafety,
  readDatabaseConnectionString,
} from "./operational-safety";

export type ScopedMutationDatabaseClient = Pick<PoolClient, "query">;

export class TrustedDatabaseMutationContextError extends Error {
  constructor() {
    super("Trusted database mutation context is unavailable.");
    this.name = "TrustedDatabaseMutationContextError";
  }
}

/**
 * Runs one protected mutation inside a normal transaction carrying only the
 * verified external issuer + subject. The caller cannot provide trusted scope,
 * actor, membership or internal user identifiers.
 */
export async function withTrustedDatabaseMutationContext<T>(
  operation: (db: ScopedMutationDatabaseClient) => Promise<T>,
): Promise<T> {
  const identity = await getVerifiedExternalIdentity();
  const connectionString = readDatabaseConnectionString();

  if (!identity || !connectionString) {
    throw new TrustedDatabaseMutationContextError();
  }

  let pool: Pool | null = null;
  let client: PoolClient | null = null;
  let transactionOpen = false;

  try {
    pool = new Pool({ connectionString });
    client = await pool.connect();
    await client.query("BEGIN");
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

    throw new TrustedDatabaseMutationContextError();
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
        // The adapter never reuses this pool after a protected mutation.
      }
    }
  }
}
