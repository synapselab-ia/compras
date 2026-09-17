import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it, vi } from "vitest";

vi.mock("../actions", () => ({
  createPersistentContractingItemAction: "/f36-test-item-create",
  updatePersistentContractingItemAction: "/f39-test-item-mutation",
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
const persistentDetail = {
  ...detail,
  id: "39000000-0000-4000-8000-000000000001",
  items: [
    {
      id: "39000000-0000-4000-8000-000000000002",
      label: "77. FORMATTED label must not define expected values",
      note: "Quantidade: 999 · Código: FORMATTED-NOTE",
      mutationSnapshot: {
        description: "  DEMO raw description  ",
        quantity: "123456789.123456789123456789",
        unit: "  kg  ",
        catalogCode: "",
      },
    },
    {
      id: "39000000-0000-4000-8000-000000000003",
      label: "78. Item com nulls",
      note: "Apresentação sem authority",
      mutationSnapshot: {
        description: "",
        quantity: null,
        unit: null,
        catalogCode: "   ",
      },
    },
  ],
};

describe("ContractingDetail persistent editor boundaries", () => {
  it("keeps demo strictly read-only even when all mutation query states are forged", () => {
    const html = renderToStaticMarkup(
      <ContractingDetail
        detail={detail}
        source="demo"
        mutationState="updated"
        objectMutationState="updated"
        itemCreationState="created"
        itemMutationState="updated"
      />,
    );

    expect(html).toContain("Detalhe demonstrativo com dados fictícios.");
    expect(html).not.toContain("<form");
    expect(html).not.toContain("<textarea");
    expect(html).not.toContain("Salvar próxima ação");
    expect(html).not.toContain("Salvar objeto");
    expect(html).not.toContain("Adicionar item");
    expect(html).not.toContain("Salvar item");
    expect(html).not.toContain("expectedDescription");
    expect(html).not.toContain("expectedUnitKind");
    expect(html).not.toContain("Próxima ação atualizada.");
    expect(html).not.toContain("Objeto atualizado.");
    expect(html).not.toContain("Item adicionado.");
    expect(html).not.toContain("Item atualizado.");
  });

  it("renders existing editors plus F39 item editors only in persistent detail", () => {
    const html = renderToStaticMarkup(
      <ContractingDetail
        detail={persistentDetail}
        source="persistent"
        mutationState="conflict"
        objectMutationState="conflict"
        itemCreationState="not-available"
        itemMutationState="conflict"
      />,
    );

    expect(html).toContain("Edição restrita");
    expect(html).toContain("Salvar objeto");
    expect(html).toContain("Salvar próxima ação");
    expect(html).toContain("Limpar próxima ação");
    expect(html).toContain("Adicionar item");
    expect(html).toContain("Salvar item");
    expect(html).toContain('name="contractingId"');
    expect(html).toContain('name="expectedObject"');
    expect(html).toContain('name="newObject"');
    expect(html).toContain('name="expectedNextAction"');
    expect(html).toContain('name="newNextAction"');
    expect(html).toContain('name="description"');
    expect(html).toContain('name="quantity"');
    expect(html).toContain('name="unit"');
    expect(html).toContain('name="catalogCode"');
    expect(html).toContain('name="itemId"');
    expect(html).toContain('name="expectedDescription"');
    expect(html).toContain('name="expectedQuantity"');
    expect(html).toContain('name="expectedUnitKind"');
    expect(html).toContain('name="expectedUnit"');
    expect(html).toContain('name="expectedCatalogCodeKind"');
    expect(html).toContain('name="expectedCatalogCode"');
    expect(html).toContain('name="newDescription"');
    expect(html).toContain('name="newQuantity"');
    expect(html).toContain('name="newUnitKind"');
    expect(html).toContain('name="newUnit"');
    expect(html).toContain('name="newCatalogCodeKind"');
    expect(html).toContain('name="newCatalogCode"');
    expect(html).toContain('inputMode="decimal"');
    expect(html).not.toContain('required=""');
    expect(html).not.toContain('type="number"');
    expect(html).toContain("O objeto mudou desde sua leitura");
    expect(html).toContain("A próxima ação mudou desde sua leitura");
    expect(html).toContain("A criação de item não está disponível para este registro.");
    expect(html).toContain("O item mudou desde sua leitura");
    expect(html).toContain('role="alert"');

    for (const forbiddenField of [
      "team_id",
      "teamId",
      "actor",
      "actorMembershipId",
      "membershipId",
      "issuer",
      "subject",
      "ordinal",
      "retiredAt",
      "updatedAt",
      "eventId",
      "descriptionEventId",
      "quantityEventId",
      "unitEventId",
      "catalogCodeEventId",
      "stage_key",
      "status_key",
      "responsible_membership_id",
      "waiting_type",
      "callbackURL",
      "redirect",
    ]) {
      expect(html).not.toContain(`name="${forbiddenField}"`);
    }
  });

  it("uses the exact protected object value as expected value and textarea default", () => {
    const exactObject = "  DEMO objeto exato  ";
    const html = renderToStaticMarkup(
      <ContractingDetail
        detail={{ ...persistentDetail, object: exactObject }}
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
        detail={{ ...persistentDetail, object: "" }}
        source="persistent"
      />,
    );

    expect(html).toContain('name="expectedObject" value=""');
    expect(html).toContain('name="newObject"');
    expect(html).toContain("Salvar objeto");
  });

  it("preserves the F27 NULL semantics for next action", () => {
    const nullDetail = { ...persistentDetail, nextAction: "Não informada", nextActionValue: null };
    const html = renderToStaticMarkup(
      <ContractingDetail detail={nullDetail} source="persistent" />,
    );

    expect(html).not.toContain('name="expectedNextAction"');
    expect(html).toContain('name="newNextAction"');
    expect(html).toContain("Limpar próxima ação");
    expect(html).toContain('name="expectedObject"');
    expect(html).toContain('name="description"');
  });

  it("transports the F39 expected snapshot from raw fields instead of label or note", () => {
    const html = renderToStaticMarkup(
      <ContractingDetail detail={persistentDetail} source="persistent" />,
    );

    expect(html).toContain('name="expectedDescription" value="  DEMO raw description  "');
    expect(html).toContain(">  DEMO raw description  </textarea>");
    expect(html).toContain(
      'name="expectedQuantity" value="123456789.123456789123456789"',
    );
    expect(html).toContain('name="expectedUnit" value="  kg  "');
    expect(html).toContain('name="expectedCatalogCode" value=""');
    expect(html).not.toContain('name="expectedDescription" value="77. FORMATTED');
    expect(html).not.toContain('name="expectedQuantity" value="999"');
    expect(html).not.toContain('name="expectedCatalogCode" value="FORMATTED-NOTE"');
  });

  it("encodes NULL versus empty/spaced text explicitly for unit and catalog", () => {
    const html = renderToStaticMarkup(
      <ContractingDetail
        detail={{ ...persistentDetail, items: [persistentDetail.items[1]] }}
        source="persistent"
      />,
    );

    expect(html).toContain('name="expectedUnitKind" value="null"');
    expect(html).toContain('name="expectedUnit" value=""');
    expect(html).toContain('name="expectedCatalogCodeKind" value="text"');
    expect(html).toContain('name="expectedCatalogCode" value="   "');
    expect(html).not.toContain('name="expectedQuantity"');
    expect(html).toContain('name="newQuantity" type="text" inputMode="decimal"');
    expect(html).toContain('name="newUnitKind"');
    expect(html).toContain('value="null" selected=""');
    expect(html).toContain("Ausente (NULL)");
    expect(html).toContain("Texto");
  });

  it("does not render an item mutation editor when the protected snapshot is absent", () => {
    const html = renderToStaticMarkup(
      <ContractingDetail
        detail={{
          ...persistentDetail,
          items: [{
            ...persistentDetail.items[0],
            mutationSnapshot: null,
          }],
        }}
        source="persistent"
        itemMutationState="updated"
      />,
    );

    expect(html).not.toContain('name="itemId"');
    expect(html).not.toContain('name="expectedDescription"');
    expect(html).not.toContain("Salvar item");
    expect(html).toContain("Item atualizado.");
  });

  it("keeps current items visible alongside create and mutation forms", () => {
    const html = renderToStaticMarkup(
      <ContractingDetail
        detail={persistentDetail}
        source="persistent"
        itemCreationState="created"
        itemMutationState="updated"
      />,
    );

    for (const item of persistentDetail.items) {
      expect(html).toContain(item.id);
      expect(html).toContain(item.label);
    }
    expect(html).toContain("Item adicionado.");
    expect(html).toContain("Item atualizado.");
    expect(html).toContain("Descrição, unidade e código são preservados exatamente.");
    expect(html).toContain("O snapshot completo é conferido antes da gravação.");
  });
});
