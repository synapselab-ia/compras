import "server-only";

import type { PoolClient } from "@neondatabase/serverless";

const PROTECTED_TABLES = [
  "app_users",
  "memberships",
  "teams",
  "contractings",
  "related_identifiers",
  "contracting_items",
  "contracting_events",
] as const;

const FORBIDDEN_OPERATIONAL_ROLES = new Set([
  "neondb_owner",
  "compras_team_directory_view_owner",
  "compras_next_action_mutation_owner",
  "compras_contracting_create_owner",
]);

type RoleSafetyRow = {
  rolname: string;
  rolsuper: boolean;
  rolbypassrls: boolean;
  rolcreatedb: boolean;
  rolcreaterole: boolean;
  rolreplication: boolean;
  owns_protected_tables: boolean;
};

export function readDatabaseConnectionString(): string | null {
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

/**
 * Rejects administrative or capability principals before any request identity
 * is installed. Throw details are intentionally internal; public adapters map
 * every failure to their own sanitized unavailable error.
 */
export async function assertOperationalRoleSafety(client: PoolClient): Promise<void> {
  const result = await client.query<RoleSafetyRow>(
    `SELECT
       r.rolname,
       r.rolsuper,
       r.rolbypassrls,
       r.rolcreatedb,
       r.rolcreaterole,
       r.rolreplication,
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
    role.rolcreatedb ||
    role.rolcreaterole ||
    role.rolreplication ||
    role.owns_protected_tables ||
    FORBIDDEN_OPERATIONAL_ROLES.has(role.rolname)
  ) {
    throw new Error("unsafe operational database role");
  }
}
