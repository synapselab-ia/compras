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

  it("uses the route UUID only as a bind parameter and exposes the raw protected item snapshot", async () => {
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
          description: "  Item fictício exato  ",
          quantity: "3.1250000000000000001",
          unit: "  UN  ",
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
      nextAction: "Validar registro fictício",
      nextActionValue: "Validar registro fictício",
      lastMovement: "2026-09-01T12:30:00.000Z",
      relatedIdentifiers: [{ value: "REF-DEMO-901" }],
      items: [{
        label: "1.   Item fictício exato  ",
        mutationSnapshot: {
          description: "  Item fictício exato  ",
          quantity: "3.1250000000000000001",
          unit: "  UN  ",
          catalogCode: null,
        },
      }],
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

    const itemSql = query.mock.calls[2][0] as string;
    expect(itemSql).toContain("quantity::text AS quantity");
    expect(itemSql).toContain("description");
    expect(itemSql).toContain("unit");
    expect(itemSql).toContain("catalog_code");
    expect(itemSql).not.toContain("label");
    expect(itemSql).not.toContain("note");

    const baseSql = query.mock.calls[0][0] as string;
    expect(baseSql).toContain("LEFT JOIN public.team_member_directory");
    expect(baseSql).not.toContain("team_id = $1");
  });

  it("keeps item NULL, empty string and spaces distinct in the mutation snapshot", async () => {
    const id = "00000000-0000-4000-8000-000000000931";
    query
      .mockResolvedValueOnce({
        rows: [{
          id,
          object: "Registro fictício",
          responsible_membership_id: null,
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
      .mockResolvedValueOnce({
        rows: [{
          id: "00000000-0000-4000-8000-000000000932",
          ordinal: 4,
          description: "   ",
          quantity: null,
          unit: "",
          catalog_code: "   ",
        }],
      })
      .mockResolvedValueOnce({ rows: [] });

    const result = await readPersistentContractingDetail(id);

    expect(result?.items[0]?.mutationSnapshot).toEqual({
      description: "   ",
      quantity: null,
      unit: "",
      catalogCode: "   ",
    });
  });

  it("returns not found without child queries when RLS exposes no contracting row", async () => {
    query.mockResolvedValueOnce({ rows: [] });

    await expect(
      readPersistentContractingDetail("00000000-0000-4000-8000-000000000911"),
    ).resolves.toBeUndefined();
    expect(query).toHaveBeenCalledTimes(1);
  });

  it("keeps SQL NULL distinct from the human fallback and ignores forged scope arguments", async () => {
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
    expect(result?.nextAction).toBe("Não informada");
    expect(result?.nextActionValue).toBeNull();
    expect(query.mock.calls.every(([, values]) => values.length === 1)).toBe(true);
  });
});
