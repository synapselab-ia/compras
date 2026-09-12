import { renderToStaticMarkup } from "react-dom/server";
import { beforeEach, describe, expect, it, vi } from "vitest";

const formMocks = vi.hoisted(() => ({
  useFormStatus: vi.fn(),
}));

vi.mock("react-dom", async (importOriginal) => {
  const original = await importOriginal<typeof import("react-dom")>();
  return { ...original, useFormStatus: formMocks.useFormStatus };
});

import { ContractingCreateSubmitButton } from "./contracting-create-submit-button";

describe("ContractingCreateSubmitButton", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    formMocks.useFormStatus.mockReturnValue({ pending: false });
  });

  it("is an enabled native submit button when idle", () => {
    const html = renderToStaticMarkup(<ContractingCreateSubmitButton />);

    expect(html).toContain('type="submit"');
    expect(html).toContain("Cadastrar contratação");
    expect(html).not.toContain(" disabled=");
    expect(html).toContain('aria-disabled="false"');
  });

  it("disables accidental repeated submission while pending", () => {
    formMocks.useFormStatus.mockReturnValue({ pending: true });
    const html = renderToStaticMarkup(<ContractingCreateSubmitButton />);

    expect(html).toContain("disabled");
    expect(html).toContain('aria-disabled="true"');
    expect(html).toContain("Cadastrando…");
    expect(html).not.toContain(">Cadastrar contratação<");
  });
});
