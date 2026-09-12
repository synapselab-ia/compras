import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it, vi } from "vitest";

vi.mock("../actions", () => ({
  createPersistentContractingAction: vi.fn(),
}));
vi.mock("./contracting-create-submit-button", () => ({
  ContractingCreateSubmitButton: () => <button type="submit">Cadastrar contratação</button>,
}));

import { ContractingCreateForm } from "./contracting-create-form";

const ID = "30000000-0000-4000-8000-000000000001";

describe("ContractingCreateForm", () => {
  it("renders only the approved candidate UUID and object controls", () => {
    const html = renderToStaticMarkup(<ContractingCreateForm contractingId={ID} />);

    expect(html).toContain(`name="contractingId" value="${ID}"`);
    expect(html).toContain('name="object"');
    expect(html).not.toContain('name="team');
    expect(html).not.toContain('name="actor');
    expect(html).not.toContain('name="membership');
    expect(html).not.toContain('name="createdBy');
    expect(html).not.toContain('name="eventId"');
    expect(html).not.toContain('name="nextAction"');
    expect(html).not.toContain('name="stage');
    expect(html).not.toContain('name="status');
    expect(html).not.toContain('name="responsible');
    expect(html).not.toContain('name="waiting');
  });

  it("does not invent a required/non-empty HTML rule for object", () => {
    const html = renderToStaticMarkup(<ContractingCreateForm contractingId={ID} />);

    expect(html).toContain('<textarea id="contracting-object-');
    expect(html).toContain('name="object"');
    expect(html).not.toContain(" required");
    expect(html).not.toContain("maxlength=");
  });

  it("renders only sanitized fixed failure feedback", () => {
    const html = renderToStaticMarkup(
      <ContractingCreateForm contractingId={ID} creationState="unavailable" />,
    );

    expect(html).toContain("Não foi possível cadastrar a contratação agora.");
    expect(html).not.toContain("postgresql://");
    expect(html).not.toContain("claim");
    expect(html).not.toContain("membership");
  });
});
