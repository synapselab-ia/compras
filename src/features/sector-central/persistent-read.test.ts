import { beforeEach, describe, expect, it, vi } from "vitest";

const contextMocks = vi.hoisted(() => ({
  withTrustedDatabaseContext: vi.fn(),
}));

vi.mock("server-only", () => ({}));
vi.mock("@/server/database/trusted-context", () => ({
  withTrustedDatabaseContext: contextMocks.withTrustedDatabaseContext,
}));

import { readPersistentSectorCentralRecords } from "./persistent-read";

describe("readPersistentSectorCentralRecords", () => {
  const query = vi.fn();

  beforeEach(() => {
    vi.clearAllMocks();
    query.mockResolvedValue({ rows: [] });
    contextMocks.withTrustedDatabaseContext.mockImplementation(
      async (operation: (db: { query: typeof query }) => Promise<unknown>) =>
        operation({ query }),
    );
  });

  it("executes the domain query only through trusted context and the minimal directory view", async () => {
    query.mockResolvedValue({
      rows: [
        {
          id: "00000000-0000-4000-8000-000000000901",
          object: "Contratação fictícia persistente",
          responsible_membership_id: "00000000-0000-4000-8000-000000000902",
          responsible_name: "Pessoa Demo Colega",
          stage: "analise-demo",
          status: "em-andamento-demo",
          waiting_type: "setor",
          waiting_reference: "Setor Demo",
          next_action: "Validar registro fictício",
          latest_event_at: new Date("2026-09-01T12:30:00.000Z"),
        },
      ],
    });

    await expect(readPersistentSectorCentralRecords()).resolves.toEqual([
      {
        id: "00000000-0000-4000-8000-000000000901",
        object: "Contratação fictícia persistente",
        responsible: "Pessoa Demo Colega",
        stage: "analise-demo",
        status: "em-andamento-demo",
        waitingOn: "Setor Demo",
        nextAction: "Validar registro fictício",
        lastMovement: "2026-09-01T12:30:00.000Z",
      },
    ]);

    expect(contextMocks.withTrustedDatabaseContext).toHaveBeenCalledTimes(1);
    expect(query).toHaveBeenCalledTimes(1);

    const [sql, values] = query.mock.calls[0];
    expect(sql).toContain("FROM public.contractings AS c");
    expect(sql).toContain("LEFT JOIN public.team_member_directory");
    expect(sql).toContain("responsible_directory.display_name AS responsible_name");
    expect(sql).toContain("MAX(e.occurred_at) AS latest_event_at");
    expect(sql).not.toContain("public.memberships");
    expect(sql).not.toContain("public.app_users");
    expect(sql).not.toContain("updated_at");
    expect(values).toBeUndefined();
  });

  it("does not accept client scope and cannot use forged team or membership inputs", async () => {
    const callWithForgedScope = readPersistentSectorCentralRecords as unknown as (
      input: unknown,
    ) => ReturnType<typeof readPersistentSectorCentralRecords>;

    await callWithForgedScope({
      team_id: "FORGED-TEAM",
      membership_id: "FORGED-MEMBERSHIP",
      app_user_id: "FORGED-USER",
    });

    const [, values] = query.mock.calls[0];
    expect(values).toBeUndefined();
  });

  it("keeps a non-exposed membership generic and preserves the null-responsible state", async () => {
    query.mockResolvedValue({
      rows: [
        {
          id: "00000000-0000-4000-8000-000000000903",
          object: "Registro fictício inconsistente",
          responsible_membership_id: "00000000-0000-4000-8000-000000000904",
          responsible_name: null,
          stage: null,
          status: null,
          waiting_type: "entidade-demo",
          waiting_reference: null,
          next_action: null,
          latest_event_at: null,
        },
        {
          id: "00000000-0000-4000-8000-000000000905",
          object: "Registro fictício sem responsável",
          responsible_membership_id: null,
          responsible_name: null,
          stage: "",
          status: "",
          waiting_type: null,
          waiting_reference: null,
          next_action: "",
          latest_event_at: "invalid-date",
        },
      ],
    });

    await expect(readPersistentSectorCentralRecords()).resolves.toEqual([
      {
        id: "00000000-0000-4000-8000-000000000903",
        object: "Registro fictício inconsistente",
        responsible: "Responsável não disponível",
        stage: "Não informado",
        status: "Não informado",
        waitingOn: "entidade-demo",
        nextAction: "Não informada",
        lastMovement: "Sem movimentação registrada",
      },
      {
        id: "00000000-0000-4000-8000-000000000905",
        object: "Registro fictício sem responsável",
        responsible: "Sem responsável",
        stage: "Não informado",
        status: "Não informado",
        waitingOn: "Não informado",
        nextAction: "Não informada",
        lastMovement: "Sem movimentação registrada",
      },
    ]);
  });
});
