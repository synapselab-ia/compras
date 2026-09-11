import { renderToStaticMarkup } from "react-dom/server";
import { beforeEach, describe, expect, it, vi } from "vitest";

const formMocks = vi.hoisted(() => ({
  useFormStatus: vi.fn(),
}));

vi.mock("react-dom", async (importOriginal) => {
  const original = await importOriginal<typeof import("react-dom")>();
  return { ...original, useFormStatus: formMocks.useFormStatus };
});

import { NextActionSubmitButton } from "./next-action-submit-button";

describe("NextActionSubmitButton", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    formMocks.useFormStatus.mockReturnValue({ pending: false });
  });

  it("is keyboard-native and enabled when no Server Action is pending", () => {
    const html = renderToStaticMarkup(
      <NextActionSubmitButton label="Salvar próxima ação" pendingLabel="Salvando…" />,
    );

    expect(html).toContain('type="submit"');
    expect(html).toContain("Salvar próxima ação");
    expect(html).not.toContain(" disabled=");
    expect(html).toContain('aria-disabled="false"');
  });

  it("disables repeated submission and exposes pending text while the form is pending", () => {
    formMocks.useFormStatus.mockReturnValue({ pending: true });
    const html = renderToStaticMarkup(
      <NextActionSubmitButton label="Salvar próxima ação" pendingLabel="Salvando…" />,
    );

    expect(html).toContain("disabled");
    expect(html).toContain('aria-disabled="true"');
    expect(html).toContain("Salvando…");
    expect(html).not.toContain(">Salvar próxima ação<");
  });
});
