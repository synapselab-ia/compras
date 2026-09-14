import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it, vi } from "vitest";

vi.mock("../actions", () => ({
  updatePersistentNextActionAction: "/f27-test-next-action",
  updatePersistentObjectAction: "/f33-test-object",
}));
vi.mock("./next-action-submit-button", () => ({
  NextActionSubmitButton: ({ label }: { label: string }) => (
    <button type="submit">{label}</button>
  ),
}));

import { getDemoContractingDetail } from "../demo-detail-data";
import { ContractingDetail } from "./contracting-detail";

const detail = getDemoContractingDetail("DEMO-001")!;

describe("ContractingDetail persistent editor boundaries", () => {
  it("keeps demo strictly read-only even when mutation query states are forged", () => {
    const html = renderToStaticMarkup(
      <ContractingDetail
        detail={detail}
        source="demo"
        mutationState="updated"
        objectMutationState="updated"
      />,
    );

    expect(html).toContain("Detalhe demonstrativo com dados fictícios.");
    expect(html).not.toContain("<form");
    expect(html).not.toContain("<textarea");
    expect(html).not.toContain("Salvar próxima ação");
    expect(html).not.toContain("Salvar objeto");
    expect(html).not.toContain("Próxima ação atualizada.");
    expect(html).not.toContain("Objeto atualizado.");
  });

  it("renders the narrow object editor alongside the existing next-action editor", () => {
    const html = renderToStaticMarkup(
      <ContractingDetail
        detail={detail}
        source="persistent"
        mutationState="conflict"
        objectMutationState="conflict"
      />,
    );

    expect(html).toContain("Edição restrita");
    expect(html).toContain("Salvar objeto");
    expect(html).toContain("Salvar próxima ação");
    expect(html).toContain("Limpar próxima ação");
    expect(html).toContain('name="contractingId"');
    expect(html).toContain('name="expectedObject"');
    expect(html).toContain('name="newObject"');
    expect(html).toContain('name="expectedNextAction"');
    expect(html).toContain('name="newNextAction"');
    expect(html).toContain("O objeto mudou desde sua leitura");
    expect(html).toContain("A próxima ação mudou desde sua leitura");
    expect(html).toContain('role="alert"');

    for (const forbiddenField of [
      "team_id",
      "actorMembershipId",
      "membershipId",
      "issuer",
      "subject",
      "eventId",
      "stage_key",
      "status_key",
      "responsible_membership_id",
      "waiting_type",
      "callbackURL",
    ]) {
      expect(html).not.toContain(`name="${forbiddenField}"`);
    }
  });

  it("uses the exact protected object value as expected value and textarea default", () => {
    const exactObject = "  DEMO objeto exato  ";
    const html = renderToStaticMarkup(
      <ContractingDetail
        detail={{ ...detail, object: exactObject }}
        source="persistent"
      />,
    );

    expect(html).toContain('name="expectedObject" value="  DEMO objeto exato  "');
    expect(html).toContain('name="newObject"');
    expect(html).toContain(">  DEMO objeto exato  </textarea>");
    expect(html).toContain("String vazia e espaços são mantidos sem trim ou normalização.");
  });

  it("keeps literal empty object representable without omitting the required expected scalar", () => {
    const html = renderToStaticMarkup(
      <ContractingDetail
        detail={{ ...detail, object: "" }}
        source="persistent"
      />,
    );

    expect(html).toContain('name="expectedObject" value=""');
    expect(html).toContain('name="newObject"');
    expect(html).toContain("Salvar objeto");
  });

  it("preserves the F27 NULL semantics for next action", () => {
    const nullDetail = { ...detail, nextAction: "Não informada", nextActionValue: null };
    const html = renderToStaticMarkup(
      <ContractingDetail detail={nullDetail} source="persistent" />,
    );

    expect(html).not.toContain('name="expectedNextAction"');
    expect(html).toContain('name="newNextAction"');
    expect(html).toContain("Limpar próxima ação");
    expect(html).toContain('name="expectedObject"');
  });
});
