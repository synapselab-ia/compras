import { renderToStaticMarkup } from "react-dom/server";
import { beforeEach, describe, expect, it, vi } from "vitest";

const pageMocks = vi.hoisted(() => ({
  readPersistentReadMode: vi.fn(),
  preparePersistentContractingCandidateId: vi.fn(),
  readContractingCreateUiState: vi.fn(),
  redirect: vi.fn((url: string) => {
    throw new Error(`REDIRECT:${url}`);
  }),
}));

vi.mock("next/navigation", () => ({ redirect: pageMocks.redirect }));
vi.mock("@/server/persistent-read-mode", () => ({
  readPersistentReadMode: pageMocks.readPersistentReadMode,
}));
vi.mock("@/features/contracting-create/persistent-create", () => ({
  preparePersistentContractingCandidateId: pageMocks.preparePersistentContractingCandidateId,
}));
vi.mock("@/features/contracting-create/feedback", () => ({
  readContractingCreateUiState: pageMocks.readContractingCreateUiState,
}));
vi.mock("@/features/contracting-create/components/contracting-create-form", () => ({
  ContractingCreateForm: ({
    contractingId,
    creationState,
  }: {
    contractingId: string;
    creationState?: string | null;
  }) => (
    <form data-contracting-id={contractingId} data-creation-state={creationState ?? "none"}>
      <textarea name="object" />
    </form>
  ),
}));

import ContractingCreatePage from "./page";

const ID = "30000000-0000-4000-8000-000000000001";
const RETRY_ID = "30000000-0000-4000-8000-000000000002";

describe("ContractingCreatePage", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    pageMocks.readPersistentReadMode.mockReturnValue("persistent");
    pageMocks.preparePersistentContractingCandidateId.mockReturnValue(ID);
    pageMocks.readContractingCreateUiState.mockReturnValue(null);
  });

  it("renders the minimal entry only in persistent mode with a server-prepared candidate", async () => {
    const element = await ContractingCreatePage({ searchParams: Promise.resolve({}) });
    const html = renderToStaticMarkup(element);

    expect(pageMocks.preparePersistentContractingCandidateId).toHaveBeenCalledTimes(1);
    expect(html).toContain(`data-contracting-id="${ID}"`);
    expect(html).toContain('name="object"');
    expect(html).not.toContain("teamId");
    expect(html).not.toContain("eventId");
  });

  it("fails closed in demo and invalid modes before preparing a candidate", async () => {
    for (const mode of ["demo", "invalid"] as const) {
      vi.clearAllMocks();
      pageMocks.readPersistentReadMode.mockReturnValue(mode);

      await expect(
        ContractingCreatePage({ searchParams: Promise.resolve({}) }),
      ).rejects.toThrow("REDIRECT:/");
      expect(pageMocks.preparePersistentContractingCandidateId).not.toHaveBeenCalled();
      expect(pageMocks.readContractingCreateUiState).not.toHaveBeenCalled();
    }
  });

  it("reuses only a validated opaque retry candidate and otherwise prepares a new one", async () => {
    const retryElement = await ContractingCreatePage({
      searchParams: Promise.resolve({ candidate: RETRY_ID }),
    });
    const retryHtml = renderToStaticMarkup(retryElement);

    expect(retryHtml).toContain(`data-contracting-id="${RETRY_ID}"`);
    expect(pageMocks.preparePersistentContractingCandidateId).not.toHaveBeenCalled();

    vi.clearAllMocks();
    pageMocks.readPersistentReadMode.mockReturnValue("persistent");
    pageMocks.preparePersistentContractingCandidateId.mockReturnValue(ID);
    pageMocks.readContractingCreateUiState.mockReturnValue(null);

    const malformedElement = await ContractingCreatePage({
      searchParams: Promise.resolve({ candidate: "not-a-uuid" }),
    });
    const malformedHtml = renderToStaticMarkup(malformedElement);

    expect(pageMocks.preparePersistentContractingCandidateId).toHaveBeenCalledTimes(1);
    expect(malformedHtml).toContain(`data-contracting-id="${ID}"`);
    expect(malformedHtml).not.toContain("not-a-uuid");
  });

  it("uses the feedback whitelist instead of echoing arbitrary query text", async () => {
    pageMocks.readContractingCreateUiState.mockReturnValue("unavailable");
    const element = await ContractingCreatePage({
      searchParams: Promise.resolve({ creation: "UNTRUSTED-DETAIL" }),
    });
    const html = renderToStaticMarkup(element);

    expect(pageMocks.readContractingCreateUiState).toHaveBeenCalledWith("UNTRUSTED-DETAIL");
    expect(html).toContain('data-creation-state="unavailable"');
    expect(html).not.toContain("UNTRUSTED-DETAIL");
  });
});
