import "server-only";

import { createNeonAuth } from "@neondatabase/auth/next/server";

export type ExternalIdentity = Readonly<{
  issuer: string;
  subject: string;
}>;

type AuthConfiguration = Readonly<{
  baseUrl: string;
  cookieSecret: string;
}>;

function readExactEnvironmentValue(name: string): string | null {
  const value = process.env[name];

  if (!value || value !== value.trim()) {
    return null;
  }

  return value;
}

function readAuthConfiguration(): AuthConfiguration | null {
  const baseUrl = readExactEnvironmentValue("NEON_AUTH_BASE_URL");
  const cookieSecret = readExactEnvironmentValue("NEON_AUTH_COOKIE_SECRET");

  if (!baseUrl || !cookieSecret || cookieSecret.length < 32) {
    return null;
  }

  try {
    if (new URL(baseUrl).protocol !== "https:") {
      return null;
    }
  } catch {
    return null;
  }

  return { baseUrl, cookieSecret };
}

/**
 * Resolves the only external identity that may cross the server trust boundary.
 * No request-supplied issuer, subject, internal user, membership, or team ID is accepted.
 */
export async function getVerifiedExternalIdentity(): Promise<ExternalIdentity | null> {
  const configuration = readAuthConfiguration();

  if (!configuration) {
    return null;
  }

  try {
    const auth = createNeonAuth({
      baseUrl: configuration.baseUrl,
      cookies: {
        secret: configuration.cookieSecret,
      },
      logLevel: "silent",
    });

    const { data, error } = await auth.getSession();
    const subject = data?.user?.id;

    if (error || typeof subject !== "string" || subject.length === 0) {
      return null;
    }

    return Object.freeze({
      issuer: configuration.baseUrl,
      subject,
    });
  } catch {
    return null;
  }
}
