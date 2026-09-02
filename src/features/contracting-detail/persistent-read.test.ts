import { beforeEach, describe, expect, it, vi } from "vitest";

const contextMocks = vi.hoisted(() => ({
  withTrustedDatabaseContext: vi.fn(),
}));

vi.mock("server-only", () => ({}));
vi.mock("@/server/database/trusted-context", () => ({
  withTrustedDatabaseContext: contextMocks.withTrustedDatabaseContext,
}));

import {
  isPersistentContractingId,
  readPersistentContractingDetail,
} from "./persistent-read";

describe("readPersistentContractingDetail", () => {
  const query = vi.fn();

  beforeEach(() => {
    vi.clearAllMocks();
    contextMocks.withTrustedDatabaseContext.mockImplementation(
      async (operation: (db: { query: typeof query }) => Promise<unknown>) => operation({ query }),
    );
  });

  it("rejects malformed persistent IDs before entering trusted context", async () => {
    expect(isPersistentContractingId("DEMO-001")).toBe(false);
    expect(isPersistentContractingId("00000000-0000-4000-8000-000000000901")).toBe(true);

    await expect(readPersistentContractingDetail("not-a-uuid")).resolves.toBeUndefined();
    expect(contextMocks.withTrustedDatabaseContext).not.toHaveBeenCalled();
    expect(query).not.toHaveBeenCalled();
  });

  it("uses the route UUID only as a bind parameter and reads teammates through the directory", async () => {
    const id = "00000000-0000-4000-8000-000000000901";
    query
      .mockResolvedValueOnce({
        rows: [{
          id,
          object: "Contratação fictícia persistente",
          responsible_membership_id: "00000000-0000-4000-8000-000000000902",
          responsible_name: "Pessoa Demo Colega",
          stage: "analise-demo",
          status: "em-andamento-demo",
          waiting_type: "setor",
          waiting_reference: "Setor Demo",
          waiting_since: new Date("2026-09-01T10:00:00.000Z"),
          waiting_reason: "Validação fictícia",
          next_action: "Validar registro fictício",
          created_at: new Date("2026-08-31T10:00:00.000Z"),
        }],
      })
      .mockResolvedValueOnce({
        rows: [{
          id: "00000000-0000-4000-8000-000000000903",
          identifier_kind: "processo-demo",
          identifier_value: "REF-DEMO-901",
          source_system: "Sistema Demo",
          note: null,
        }],
      })
      .mockResolvedValueOnce({
        rows: [{
          id: "00000000-0000-4000-8000-000000000904",
          ordinal: 1,
          description: "Item fictício",
          quantity: "3",
          unit: "UN",
          catalog_code: null,
        }],
      })
      .mockResolvedValueOnce({
        rows: [{
          id: "00000000-0000-4000-8000-000000000905",
          event_type: "evento-demo",
          occurred_at: new Date("2026-09-01T12:30:00.000Z"),
          field_key: null,
          old_value: null,
          new_value: null,
          note: "Movimentação fictícia",
        }],
      });

    await expect(readPersistentContractingDetail(id)).resolves.toMatchObject({
      id,
      responsible: "Pessoa Demo Colega",
      lastMovement: "2026-09-01T12:30:00.000Z",
      relatedIdentifiers: [{ value: "REF-DEMO-901" }],
      items: [{ label: "1. Item fictício" }],
      activity: [{ label: "evento-demo" }],
    });

    expect(contextMocks.withTrustedDatabaseContext).toHaveBeenCalledTimes(1);
    expect(query).toHaveBeenCalledTimes(4);

    for (const [sql, values] of query.mock.calls) {
      expect(sql).toContain("$1::uuid");
      expect(sql).not.toContain(id);
      expect(sql).not.toContain("public.app_users");
      expect(sql).not.toContain("public.memberships");
      expect(sql).not.toContain("updated_at");
      expect(values).toEqual([id]);
    }

    const baseSql = query.mock.calls[0][0] as string;
    expect(baseSql).toContain("LEFT JOIN public.team_member_directory");
    expect(baseSql).not.toContain("team_id = $1");
  });

  it("returns not found without child queries when RLS exposes no contracting row", async () => {
    query.mockResolvedValueOnce({ rows: [] });

    await expect(
      readPersistentContractingDetail("00000000-0000-4000-8000-000000000911"),
    ).resolves.toBeUndefined();
    expect(query).toHaveBeenCalledTimes(1);
  });

  it("ignores forged scope arguments and preserves generic responsible fallbacks", async () => {
    query
      .mockResolvedValueOnce({
        rows: [{
          id: "00000000-0000-4000-8000-000000000921",
          object: "Registro fictício",
          responsible_membership_id: "00000000-0000-4000-8000-000000000922",
          responsible_name: null,
          stage: null,
          status: null,
          waiting_type: null,
          waiting_reference: null,
          waiting_since: null,
          waiting_reason: null,
          next_action: null,
          created_at: "2026-09-01T00:00:00.000Z",
        }],
      })
      .mockResolvedValueOnce({ rows: [] })
      .mockResolvedValueOnce({ rows: [] })
      .mockResolvedValueOnce({ rows: [] });

    const forgedCall = readPersistentContractingDetail as unknown as (
      id: string,
      scope: unknown,
    ) => ReturnType<typeof readPersistentContractingDetail>;

    const result = await forgedCall("00000000-0000-4000-8000-000000000921", {
      team_id: "FORGED-TEAM",
      membership_id: "FORGED-MEMBERSHIP",
      app_user_id: "FORGED-USER",
    });

    expect(result?.responsible).toBe("Responsável não disponível");
    expect(query.mock.calls.every(([, values]) => values.length === 1)).toBe(true);
  });
});
