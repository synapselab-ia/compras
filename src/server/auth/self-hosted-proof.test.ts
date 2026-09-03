import { DatabaseSync } from "node:sqlite";

import { betterAuth } from "better-auth";
import { describe, expect, it } from "vitest";

const TEST_ORIGIN = "https://f19-auth-proof.invalid";
const TEST_SECRET = "f19-fictitious-local-proof-secret-not-operational-0001";

describe("F19 self-hosted Better Auth admission proof", () => {
  it("rejects email signup before creating any auth table when disableSignUp is true", async () => {
    const database = new DatabaseSync(":memory:");

    try {
      const auth = betterAuth({
        database,
        baseURL: TEST_ORIGIN,
        secret: TEST_SECRET,
        trustedOrigins: [TEST_ORIGIN],
        emailAndPassword: {
          enabled: true,
          disableSignUp: true,
        },
        socialProviders: {},
        plugins: [],
      });

      let rejection: unknown;

      try {
        await auth.api.signUpEmail({
          body: {
            email: "f19-proof@example.invalid",
            password: "fictitious-proof-password-0001",
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
      const auth = betterAuth({
        database,
        baseURL: TEST_ORIGIN,
        secret: TEST_SECRET,
        trustedOrigins: [TEST_ORIGIN],
        emailAndPassword: {
          enabled: true,
          disableSignUp: true,
        },
        socialProviders: {},
        plugins: [],
      });

      expect(auth.options.emailAndPassword?.enabled).toBe(true);
      expect(auth.options.emailAndPassword?.disableSignUp).toBe(true);
      expect(auth.options.trustedOrigins).toEqual([TEST_ORIGIN]);
      expect(auth.options.socialProviders ?? {}).toEqual({});
      expect(auth.options.plugins ?? []).toEqual([]);
    } finally {
      database.close();
    }
  });
});
