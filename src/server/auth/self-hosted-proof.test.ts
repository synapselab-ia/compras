import { DatabaseSync } from "node:sqlite";

import { betterAuth } from "better-auth";
import { getMigrations } from "better-auth/db/migration";
import { describe, expect, it } from "vitest";

const TEST_ORIGIN = "https://f19-auth-proof.invalid";
const TEST_SECRET = "f19-fictitious-local-proof-secret-not-operational-0001";
const EXISTING_EMAIL = "existing-f19-proof@example.invalid";
const EXISTING_PASSWORD = "fictitious-proof-password-0001";

function createProofAuth(database: DatabaseSync, disableSignUp: boolean) {
  return betterAuth({
    database,
    baseURL: TEST_ORIGIN,
    secret: TEST_SECRET,
    trustedOrigins: [TEST_ORIGIN],
    emailAndPassword: {
      enabled: true,
      disableSignUp,
    },
    socialProviders: {},
    plugins: [],
  });
}

function cookieHeaderFromSetCookie(headers: Headers): string {
  return headers
    .getSetCookie()
    .map((value) => value.split(";", 1)[0])
    .filter(Boolean)
    .join("; ");
}

describe("F19 self-hosted Better Auth admission proof", () => {
  it("rejects email signup before creating any auth table when disableSignUp is true", async () => {
    const database = new DatabaseSync(":memory:");

    try {
      const auth = createProofAuth(database, true);
      let rejection: unknown;

      try {
        await auth.api.signUpEmail({
          body: {
            email: "f19-proof@example.invalid",
            password: EXISTING_PASSWORD,
            name: "F19 Proof User",
          },
        });
      } catch (error) {
        rejection = error;
      }

      expect(rejection).toBeDefined();
      expect(String(rejection).toLowerCase()).toMatch(/sign.?up|signup/);
      expect(String(rejection).toLowerCase()).toMatch(/disable|not enabled|forbidden/);

      const authTables = database
        .prepare(
          "select name from sqlite_master where type = 'table' and name not like 'sqlite_%' order by name",
        )
        .all();

      expect(authTables).toEqual([]);
    } finally {
      database.close();
    }
  });

  it("keeps lateral auth methods absent from the configured instance", () => {
    const database = new DatabaseSync(":memory:");

    try {
      const auth = createProofAuth(database, true);

      expect(auth.options.emailAndPassword?.enabled).toBe(true);
      expect(auth.options.emailAndPassword?.disableSignUp).toBe(true);
      expect(auth.options.trustedOrigins).toEqual([TEST_ORIGIN]);
      expect(auth.options.socialProviders ?? {}).toEqual({});
      expect(auth.options.plugins ?? []).toEqual([]);
    } finally {
      database.close();
    }
  });

  it("supports an offline one-shot bootstrap followed by existing-user server-side sign-in while signup stays closed", async () => {
    const database = new DatabaseSync(":memory:");

    try {
      const bootstrapAuth = createProofAuth(database, false);
      const { runMigrations } = await getMigrations(bootstrapAuth.options);
      await runMigrations();

      await bootstrapAuth.api.signUpEmail({
        body: {
          email: EXISTING_EMAIL,
          password: EXISTING_PASSWORD,
          name: "Existing F19 Proof User",
        },
      });

      const guardedAuth = createProofAuth(database, true);

      await expect(
        guardedAuth.api.signUpEmail({
          body: {
            email: "blocked-f19-proof@example.invalid",
            password: EXISTING_PASSWORD,
            name: "Blocked F19 Proof User",
          },
        }),
      ).rejects.toThrow(/sign.?up|signup/i);

      const signedIn = await guardedAuth.api.signInEmail({
        body: {
          email: EXISTING_EMAIL,
          password: EXISTING_PASSWORD,
        },
        returnHeaders: true,
      });

      expect(signedIn.response.user.email).toBe(EXISTING_EMAIL);
      const cookie = cookieHeaderFromSetCookie(signedIn.headers);
      expect(cookie).toContain("session_token");

      const session = await guardedAuth.api.getSession({
        headers: new Headers({ cookie }),
      });

      expect(session?.user.email).toBe(EXISTING_EMAIL);
      expect(typeof session?.user.id).toBe("string");

      const signedOut = await guardedAuth.api.signOut({
        headers: new Headers({ cookie }),
        returnHeaders: true,
      });

      const signOutSetCookie = signedOut.headers.getSetCookie().join("\n").toLowerCase();
      expect(signOutSetCookie).toContain("session_token=");
      expect(signOutSetCookie).toMatch(/max-age=0|expires=/);

      const revokedSession = await guardedAuth.api.getSession({
        headers: new Headers({ cookie }),
      });

      expect(revokedSession).toBeNull();
    } finally {
      database.close();
    }
  });
});
