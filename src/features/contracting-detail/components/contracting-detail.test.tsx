import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it, vi } from "vitest";

vi.mock("../actions", () => ({
  updatePersistentNextActionAction: "/f27-test-next-action",
}));
vi.mock("./next-action-submit-button", () => ({
  NextActionSubmitButton: ({ label }: { label: string }) => (
    <button type="submit">{label}</button>
  ),
}));

import { getDemoContractingDetail } from "../demo-detail-data";
import { ContractingDetail } from "./contracting-detail";

const detail = getDemoContractingDetail("DEMO-001")!;

describe("ContractingDetail F27 editor boundary", () => {
  it("keeps demo strictly read-only even when a mutation query state is forged", () => {
    const html = renderToStaticMarkup(
      <ContractingDetail detail={detail} source="demo" mutationState="updated" />,
    );

    expect(html).toContain("Detalhe demonstrativo com dados fictícios.");
    expect(html).not.toContain("<form");
    expect(html).not.toContain("<textarea");
    expect(html).not.toContain("Salvar próxima ação");
    expect(html).not.toContain("Próxima ação atualizada.");
  });

  it("renders only the narrow next-action controls in persistent mode", () => {
    const html = renderToStaticMarkup(
      <ContractingDetail detail={detail} source="persistent" mutationState="conflict" />,
    );

    expect(html).toContain("Edição restrita");
    expect(html).toContain("Salvar próxima ação");
    expect(html).toContain("Limpar próxima ação");
    expect(html).toContain('name="contractingId"');
    expect(html).toContain('name="expectedNextAction"');
    expect(html).toContain('name="newNextAction"');
    expect(html).toContain("mudou desde sua leitura");
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
    ]) {
      expect(html).not.toContain(`name="${forbiddenField}"`);
    }
  });

  it("omits the expected hidden scalar when the protected read model says NULL", () => {
    const nullDetail = { ...detail, nextAction: "Não informada", nextActionValue: null };
    const html = renderToStaticMarkup(
      <ContractingDetail detail={nullDetail} source="persistent" />,
    );

    expect(html).not.toContain('name="expectedNextAction"');
    expect(html).toContain('name="newNextAction"');
    expect(html).toContain("Limpar próxima ação");
  });
});
