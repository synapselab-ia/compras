import type { Pool } from "pg";
import { afterEach, describe, expect, it, vi } from "vitest";

vi.mock("server-only", () => ({}));

import {
  FICTITIOUS_PRIVATE_PREVIEW_FIXTURE,
  FICTITIOUS_PRIVATE_PREVIEW_MODE,
  FictitiousPrivatePreviewSeedError,
  seedFictitiousPrivatePreviewAuthorization,
} from "./fictitious-private-preview";

const SUBJECT = "f22-fictitious-auth-subject";

type FakeAdminOptions = Readonly<{
  email?: string;
  privileged?: boolean;
  proof?: boolean;
}>;

function createFakeAdmin(options: FakeAdminOptions = {}) {
  const email = options.email ?? FICTITIOUS_PRIVATE_PREVIEW_FIXTURE.email;
  const privileged = options.privileged ?? true;
  const proof = options.proof ?? true;

  const query = vi.fn(async (text: string) => {
    if (text.includes("FROM pg_catalog.pg_roles")) {
      return {
        rows: [
          {
            rolname: "compras_f22_seed_admin",
            rolsuper: false,
            rolbypassrls: privileged,
          },
        ],
      };
    }

    if (text.includes('FROM auth."user"')) {
      return { rows: [{ email }] };
    }

    if (text.includes("AS app_user_ok")) {
      return {
        rows: [
          {
            app_user_ok: proof,
            membership_ok: proof,
            team_alpha_ok: proof,
            team_beta_ok: proof,
            contracting_alpha_ok: proof,
            contracting_beta_ok: proof,
            cross_membership_absent: proof,
          },
        ],
      };
    }

    return { rows: [] };
  });

  return {
    database: { query } as unknown as Pick<Pool, "query">,
    query,
  };
}

afterEach(() => {
  delete process.env.COMPRAS_PRIVATE_PREVIEW_PREFLIGHT_MODE;
});

describe("F22 fictitious private preview seed", () => {
  it("is disabled unless the exact fictitious ephemeral mode is enabled", async () => {
    const { database, query } = createFakeAdmin();

    await expect(
      seedFictitiousPrivatePreviewAuthorization(database, SUBJECT),
    ).rejects.toBeInstanceOf(FictitiousPrivatePreviewSeedError);
    expect(query).not.toHaveBeenCalled();
  });

  it("rejects malformed subjects before opening a transaction", async () => {
    process.env.COMPRAS_PRIVATE_PREVIEW_PREFLIGHT_MODE =
      FICTITIOUS_PRIVATE_PREVIEW_MODE;
    const { database, query } = createFakeAdmin();

    await expect(
      seedFictitiousPrivatePreviewAuthorization(database, ` ${SUBJECT}`),
    ).rejects.toBeInstanceOf(FictitiousPrivatePreviewSeedError);
    expect(query).not.toHaveBeenCalled();
  });

  it("requires an explicitly administrative seed connection", async () => {
    process.env.COMPRAS_PRIVATE_PREVIEW_PREFLIGHT_MODE =
      FICTITIOUS_PRIVATE_PREVIEW_MODE;
    const { database, query } = createFakeAdmin({ privileged: false });

    await expect(
      seedFictitiousPrivatePreviewAuthorization(database, SUBJECT),
    ).rejects.toBeInstanceOf(FictitiousPrivatePreviewSeedError);

    expect(query.mock.calls.map(([text]) => text)).toContain("ROLLBACK");
    expect(
      query.mock.calls.some(([text]) => String(text).includes('FROM auth."user"')),
    ).toBe(false);
  });

  it("rejects an Auth subject whose persisted email is not example.invalid", async () => {
    process.env.COMPRAS_PRIVATE_PREVIEW_PREFLIGHT_MODE =
      FICTITIOUS_PRIVATE_PREVIEW_MODE;
    const { database, query } = createFakeAdmin({
      email: "not-fictitious@example.com",
    });

    await expect(
      seedFictitiousPrivatePreviewAuthorization(database, SUBJECT),
    ).rejects.toBeInstanceOf(FictitiousPrivatePreviewSeedError);

    expect(query.mock.calls.map(([text]) => text)).toContain("ROLLBACK");
  });

  it("returns only a sanitized status after the deterministic fixture proves itself", async () => {
    process.env.COMPRAS_PRIVATE_PREVIEW_PREFLIGHT_MODE =
      FICTITIOUS_PRIVATE_PREVIEW_MODE;
    const { database, query } = createFakeAdmin();

    await expect(
      seedFictitiousPrivatePreviewAuthorization(database, SUBJECT),
    ).resolves.toEqual({ kind: "seeded" });

    expect(query.mock.calls.map(([text]) => text)).toContain("COMMIT");
    expect(FICTITIOUS_PRIVATE_PREVIEW_FIXTURE.email.endsWith("@example.invalid")).toBe(
      true,
    );
    expect(FICTITIOUS_PRIVATE_PREVIEW_FIXTURE.teamAlphaId).toMatch(
      /^00000000-0000-4000-8000-/,
    );
    expect(FICTITIOUS_PRIVATE_PREVIEW_FIXTURE.teamBetaId).toMatch(
      /^00000000-0000-4000-8000-/,
    );
  });

  it("fails closed when deterministic fixture postflight does not match", async () => {
    process.env.COMPRAS_PRIVATE_PREVIEW_PREFLIGHT_MODE =
      FICTITIOUS_PRIVATE_PREVIEW_MODE;
    const { database, query } = createFakeAdmin({ proof: false });

    await expect(
      seedFictitiousPrivatePreviewAuthorization(database, SUBJECT),
    ).rejects.toBeInstanceOf(FictitiousPrivatePreviewSeedError);

    expect(query.mock.calls.map(([text]) => text)).toContain("ROLLBACK");
  });
});
