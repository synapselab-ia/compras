import "server-only";

import {
  readPrivateAuthSessionState,
  type ExternalIdentity,
} from "./runtime";

export type { ExternalIdentity } from "./runtime";

/**
 * Resolves the only external identity that may cross the server trust boundary.
 * No request-supplied issuer, subject, internal user, membership, or team ID is accepted.
 */
export async function getVerifiedExternalIdentity(): Promise<ExternalIdentity | null> {
  const session = await readPrivateAuthSessionState();
  return session.kind === "authenticated" ? session.identity : null;
}
