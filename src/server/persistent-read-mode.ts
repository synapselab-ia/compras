import "server-only";

export type PersistentReadMode = "demo" | "persistent" | "invalid";

export function readPersistentReadMode(): PersistentReadMode {
  const value = process.env.COMPRAS_PERSISTENT_READ_ENABLED;

  if (value === undefined || value === "false") {
    return "demo";
  }

  if (value === "true") {
    return "persistent";
  }

  return "invalid";
}
