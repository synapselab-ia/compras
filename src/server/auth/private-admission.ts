import "server-only";

import {
  getConfiguredPrivateAuth,
  isAuthProviderUnavailableError,
} from "./runtime";

export type ExistingIdentityCredentials = Readonly<{
  email: string;
  password: string;
}>;

export type PrivateSignInResult = "signed-in" | "rejected" | "unavailable";
export type PrivateSignOutResult = "signed-out" | "unavailable";

function normalizeCredentials(
  credentials: ExistingIdentityCredentials,
): ExistingIdentityCredentials | null {
  const email = credentials.email.trim();
  const password = credentials.password;

  if (
    email.length === 0 ||
    email.length > 320 ||
    password.length === 0 ||
    password.length > 4096
  ) {
    return null;
  }

  return { email, password };
}

/**
 * Signs in only an identity that already exists in the provider. This function
 * never calls sign-up, admin APIs, OAuth, OTP, password reset, or product DB writes.
 */
export async function signInExistingIdentity(
  credentials: ExistingIdentityCredentials,
): Promise<PrivateSignInResult> {
  const normalized = normalizeCredentials(credentials);

  if (!normalized) {
    return "rejected";
  }

  const configured = getConfiguredPrivateAuth();

  if (!configured) {
    return "unavailable";
  }

  try {
    const { error } = await configured.auth.signIn.email(normalized);

    if (!error) {
      return "signed-in";
    }

    return isAuthProviderUnavailableError(error) ? "unavailable" : "rejected";
  } catch {
    return "unavailable";
  }
}

export async function signOutCurrentIdentity(): Promise<PrivateSignOutResult> {
  const configured = getConfiguredPrivateAuth();

  if (!configured) {
    return "unavailable";
  }

  try {
    const { error } = await configured.auth.signOut();

    if (!error) {
      return "signed-out";
    }

    // A rejected/expired session is already effectively signed out. Provider
    // failures remain unavailable because cookie invalidation was not confirmed.
    return isAuthProviderUnavailableError(error) ? "unavailable" : "signed-out";
  } catch {
    return "unavailable";
  }
}
