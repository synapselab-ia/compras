import { renderToStaticMarkup } from "react-dom/server";
import { beforeEach, describe, expect, it, vi } from "vitest";

const homeMocks = vi.hoisted(() => ({
  loadSectorCentralViewData: vi.fn(),
  redirect: vi.fn((url: string) => {
    throw new Error(`REDIRECT:${url}`);
  }),
}));

vi.mock("next/navigation", () => ({ redirect: homeMocks.redirect }));
vi.mock("@/features/sector-central/view-data", () => ({
  loadSectorCentralViewData: homeMocks.loadSectorCentralViewData,
}));
vi.mock("@/features/sector-central/components/sector-central", () => ({
  SectorCentral: () => <section data-sector-central="true" />,
}));

import Home from "./page";

describe("Home F30 creation entry", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it("shows the create journey only for persistent view data", async () => {
    homeMocks.loadSectorCentralViewData.mockResolvedValueOnce({
      kind: "persistent",
      records: [],
    });

    const persistentHtml = renderToStaticMarkup(await Home());
    expect(persistentHtml).toContain('href="/contratacoes/nova"');
    expect(persistentHtml).toContain("Cadastrar nova contratação");

    homeMocks.loadSectorCentralViewData.mockResolvedValueOnce({
      kind: "demo",
      records: [],
    });

    const demoHtml = renderToStaticMarkup(await Home());
    expect(demoHtml).not.toContain('href="/contratacoes/nova"');
    expect(demoHtml).not.toContain("Cadastrar nova contratação");
  });

  it("does not expose a create entry when protected data is unavailable", async () => {
    homeMocks.loadSectorCentralViewData.mockResolvedValueOnce({ kind: "unavailable" });

    const html = renderToStaticMarkup(await Home());
    expect(html).not.toContain('href="/contratacoes/nova"');
    expect(html).toContain("Dados protegidos indisponíveis.");
  });
});
