import "server-only";

import type { Pool } from "pg";

import { SELF_HOSTED_AUTH_ISSUER } from "../auth/configuration";

export const FICTITIOUS_PRIVATE_PREVIEW_MODE = "FICTITIOUS_EPHEMERAL";

export const FICTITIOUS_PRIVATE_PREVIEW_FIXTURE = Object.freeze({
  appUserId: "00000000-0000-4000-8000-000000000001",
  membershipId: "00000000-0000-4000-8000-000000000002",
  teamAlphaId: "00000000-0000-4000-8000-000000000101",
  teamBetaId: "00000000-0000-4000-8000-000000000102",
  contractingAlphaId: "00000000-0000-4000-8000-000000000201",
  contractingBetaId: "00000000-0000-4000-8000-000000000202",
  email: "preview-f22@example.invalid",
  displayName: "Fictitious Preview User",
  teamAlphaName: "Fictitious Team Alpha",
  teamBetaName: "Fictitious Team Beta",
  contractingAlphaObject: "FICTITIOUS PRIVATE PREVIEW CONTRACTING ALPHA",
  contractingBetaObject: "FICTITIOUS PRIVATE PREVIEW CONTRACTING BETA",
  timestamp: "2026-01-01T00:00:00.000Z",
});

export type FictitiousPrivatePreviewSeedResult = Readonly<{
  kind: "seeded";
}>;

export class FictitiousPrivatePreviewSeedError extends Error {
  constructor() {
    super("Fictitious private preview seed is unavailable.");
    this.name = "FictitiousPrivatePreviewSeedError";
  }
}

type AdministrativeDatabase = Pick<Pool, "query">;

type AdministrativeRoleRow = {
  rolname: string;
  rolsuper: boolean;
  rolbypassrls: boolean;
};

type AuthIdentityRow = {
  email: string;
};

type SeedProofRow = {
  app_user_ok: boolean;
  membership_ok: boolean;
  team_alpha_ok: boolean;
  team_beta_ok: boolean;
  contracting_alpha_ok: boolean;
  contracting_beta_ok: boolean;
  cross_membership_absent: boolean;
};

function isExampleInvalidEmail(value: string): boolean {
  const normalized = value.trim().toLowerCase();
  const at = normalized.lastIndexOf("@");

  return at > 0 && normalized.slice(at + 1) === "example.invalid";
}

function assertFictitiousSeedInput(subject: string): void {
  if (
    process.env.COMPRAS_PRIVATE_PREVIEW_PREFLIGHT_MODE !==
      FICTITIOUS_PRIVATE_PREVIEW_MODE ||
    subject.length === 0 ||
    subject.length > 255 ||
    subject.trim() !== subject
  ) {
    throw new FictitiousPrivatePreviewSeedError();
  }
}

/**
 * One-shot administrative seed for an explicitly fictitious disposable
 * environment. The caller supplies only the subject returned by the closed
 * Better Auth bootstrap. This function verifies that subject against the Auth
 * schema and never creates or mutates Auth identities.
 *
 * Domain tables use FORCE RLS and intentionally expose no INSERT policy, so a
 * privileged administrative connection is required for this seed. That
 * connection is never a runtime credential and is never used as evidence that
 * application authorization works; all runtime proof must use the ordinary
 * non-BYPASSRLS domain role.
 */
export async function seedFictitiousPrivatePreviewAuthorization(
  adminDatabase: AdministrativeDatabase,
  subject: string,
): Promise<FictitiousPrivatePreviewSeedResult> {
  assertFictitiousSeedInput(subject);

  const fixture = FICTITIOUS_PRIVATE_PREVIEW_FIXTURE;
  let transactionOpen = false;

  try {
    await adminDatabase.query("BEGIN");
    transactionOpen = true;

    const roleResult = await adminDatabase.query<AdministrativeRoleRow>(
      `SELECT r.rolname, r.rolsuper, r.rolbypassrls
         FROM pg_catalog.pg_roles AS r
        WHERE r.rolname = current_user`,
    );
    const role = roleResult.rows[0];

    if (!role || (!role.rolsuper && !role.rolbypassrls)) {
      throw new FictitiousPrivatePreviewSeedError();
    }

    const authIdentityResult = await adminDatabase.query<AuthIdentityRow>(
      `SELECT email
         FROM auth."user"
        WHERE id = $1`,
      [subject],
    );
    const authIdentity = authIdentityResult.rows[0];

    if (
      authIdentityResult.rows.length !== 1 ||
      !authIdentity ||
      !isExampleInvalidEmail(authIdentity.email)
    ) {
      throw new FictitiousPrivatePreviewSeedError();
    }

    await adminDatabase.query(
      `INSERT INTO public.teams (id, name, created_at, archived_at)
       VALUES
         ($1, $2, $3, NULL),
         ($4, $5, $3, NULL)
       ON CONFLICT (id) DO NOTHING`,
      [
        fixture.teamAlphaId,
        fixture.teamAlphaName,
        fixture.timestamp,
        fixture.teamBetaId,
        fixture.teamBetaName,
      ],
    );

    await adminDatabase.query(
      `INSERT INTO public.app_users
         (id, auth_issuer, auth_subject, display_name, created_at, disabled_at)
       VALUES ($1, $2, $3, $4, $5, NULL)
       ON CONFLICT (id) DO NOTHING`,
      [
        fixture.appUserId,
        SELF_HOSTED_AUTH_ISSUER,
        subject,
        fixture.displayName,
        fixture.timestamp,
      ],
    );

    await adminDatabase.query(
      `INSERT INTO public.memberships
         (id, team_id, user_id, joined_at, revoked_at)
       VALUES ($1, $2, $3, $4, NULL)
       ON CONFLICT (id) DO NOTHING`,
      [
        fixture.membershipId,
        fixture.teamAlphaId,
        fixture.appUserId,
        fixture.timestamp,
      ],
    );

    await adminDatabase.query(
      `INSERT INTO public.contractings
         (id, team_id, object, responsible_membership_id, created_by_membership_id,
          created_at, updated_at)
       VALUES
         ($1, $2, $3, $4, $4, $5, $5),
         ($6, $7, $8, NULL, NULL, $5, $5)
       ON CONFLICT (id) DO NOTHING`,
      [
        fixture.contractingAlphaId,
        fixture.teamAlphaId,
        fixture.contractingAlphaObject,
        fixture.membershipId,
        fixture.timestamp,
        fixture.contractingBetaId,
        fixture.teamBetaId,
        fixture.contractingBetaObject,
      ],
    );

    const proofResult = await adminDatabase.query<SeedProofRow>(
      `SELECT
         EXISTS (
           SELECT 1 FROM public.app_users
            WHERE id = $1
              AND auth_issuer = $2
              AND auth_subject = $3
              AND display_name = $4
              AND disabled_at IS NULL
         ) AS app_user_ok,
         EXISTS (
           SELECT 1 FROM public.memberships
            WHERE id = $5
              AND team_id = $6
              AND user_id = $1
              AND revoked_at IS NULL
         ) AS membership_ok,
         EXISTS (
           SELECT 1 FROM public.teams
            WHERE id = $6 AND name = $7 AND archived_at IS NULL
         ) AS team_alpha_ok,
         EXISTS (
           SELECT 1 FROM public.teams
            WHERE id = $8 AND name = $9 AND archived_at IS NULL
         ) AS team_beta_ok,
         EXISTS (
           SELECT 1 FROM public.contractings
            WHERE id = $10 AND team_id = $6 AND object = $11
         ) AS contracting_alpha_ok,
         EXISTS (
           SELECT 1 FROM public.contractings
            WHERE id = $12 AND team_id = $8 AND object = $13
         ) AS contracting_beta_ok,
         NOT EXISTS (
           SELECT 1 FROM public.memberships
            WHERE user_id = $1
              AND team_id = $8
              AND revoked_at IS NULL
         ) AS cross_membership_absent`,
      [
        fixture.appUserId,
        SELF_HOSTED_AUTH_ISSUER,
        subject,
        fixture.displayName,
        fixture.membershipId,
        fixture.teamAlphaId,
        fixture.teamAlphaName,
        fixture.teamBetaId,
        fixture.teamBetaName,
        fixture.contractingAlphaId,
        fixture.contractingAlphaObject,
        fixture.contractingBetaId,
        fixture.contractingBetaObject,
      ],
    );
    const proof = proofResult.rows[0];

    if (
      !proof ||
      !proof.app_user_ok ||
      !proof.membership_ok ||
      !proof.team_alpha_ok ||
      !proof.team_beta_ok ||
      !proof.contracting_alpha_ok ||
      !proof.contracting_beta_ok ||
      !proof.cross_membership_absent
    ) {
      throw new FictitiousPrivatePreviewSeedError();
    }

    await adminDatabase.query("COMMIT");
    transactionOpen = false;

    return Object.freeze({ kind: "seeded" as const });
  } catch {
    if (transactionOpen) {
      await adminDatabase.query("ROLLBACK").catch(() => undefined);
    }

    throw new FictitiousPrivatePreviewSeedError();
  }
}
