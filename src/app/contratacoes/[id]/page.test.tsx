import { renderToStaticMarkup } from "react-dom/server";
import { beforeEach, describe, expect, it, vi } from "vitest";

const pageMocks = vi.hoisted(() => ({
  loadContractingDetailViewData: vi.fn(),
  preparePersistentRelatedIdentifierCandidateId: vi.fn(),
  preparePersistentManualTimelineNoteEventId: vi.fn(),
  redirect: vi.fn((url: string) => {
    throw new Error(`REDIRECT:${url}`);
  }),
  notFound: vi.fn(() => {
    throw new Error("NOT_FOUND");
  }),
}));

vi.mock("next/navigation", () => ({
  redirect: pageMocks.redirect,
  notFound: pageMocks.notFound,
}));
vi.mock("@/features/contracting-create/feedback", () => ({
  getContractingCreateFeedback: () => null,
  readContractingCreateUiState: () => null,
}));
vi.mock("@/features/contracting-detail/item-create-feedback", () => ({
  readItemCreationUiState: () => null,
}));
vi.mock("@/features/contracting-detail/item-mutation-feedback", () => ({
  readItemMutationUiState: () => null,
}));
vi.mock("@/features/contracting-detail/manual-timeline-note-create-feedback", () => ({
  readManualTimelineNoteCreationUiState: (value: string | string[] | undefined) =>
    typeof value === "string" &&
    ["created", "already-added", "not-available", "unavailable"].includes(value)
      ? value
      : null,
}));
vi.mock("@/features/contracting-detail/next-action-feedback", () => ({
  readNextActionMutationUiState: () => null,
}));
vi.mock("@/features/contracting-detail/object-feedback", () => ({
  readObjectMutationUiState: () => null,
}));
vi.mock("@/features/contracting-detail/related-identifier-create-feedback", () => ({
  readRelatedIdentifierCreationUiState: (
    value: string | string[] | undefined,
  ) =>
    typeof value === "string" &&
    ["created", "already-linked", "not-available", "unavailable"].includes(value)
      ? value
      : null,
}));
vi.mock("@/features/contracting-detail/view-data", () => ({
  loadContractingDetailViewData: pageMocks.loadContractingDetailViewData,
}));
vi.mock(
  "@/features/contracting-detail/persistent-manual-timeline-note-create",
  () => ({
    preparePersistentManualTimelineNoteEventId:
      pageMocks.preparePersistentManualTimelineNoteEventId,
  }),
);
vi.mock(
  "@/features/contracting-detail/persistent-related-identifier-create",
  () => ({
    preparePersistentRelatedIdentifierCandidateId:
      pageMocks.preparePersistentRelatedIdentifierCandidateId,
  }),
);
vi.mock("@/features/contracting-detail/components/contracting-detail", () => ({
  ContractingDetail: ({
    source,
    relatedIdentifierCandidateId,
    relatedIdentifierCreationState,
    manualNoteCandidateId,
    manualNoteCreationState,
  }: {
    source: string;
    relatedIdentifierCandidateId?: string | null;
    relatedIdentifierCreationState?: string | null;
    manualNoteCandidateId?: string | null;
    manualNoteCreationState?: string | null;
  }) => (
    <section
      data-detail-source={source}
      data-related-candidate={relatedIdentifierCandidateId ?? "none"}
      data-related-state={relatedIdentifierCreationState ?? "none"}
      data-manual-note-candidate={manualNoteCandidateId ?? "none"}
      data-manual-note-state={manualNoteCreationState ?? "none"}
    />
  ),
}));

import ContractingDetailPage from "./page";

const ID = "42000000-0000-4000-8000-000000000001";
const GENERATED = "42010000-0000-4000-8000-000000000001";
const RETRY = "42010000-0000-4000-8000-000000000002";
const MANUAL_GENERATED = "45010000-0000-4000-8000-000000000001";
const MANUAL_RETRY = "45010000-0000-4000-8000-000000000002";

function renderPage(
  query: Record<string, string | string[] | undefined> = {},
): Promise<string> {
  return ContractingDetailPage({
    params: Promise.resolve({ id: ID }),
    searchParams: Promise.resolve(query),
  }).then((element) => renderToStaticMarkup(element));
}

describe("contracting detail F42 candidate preparation", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    pageMocks.preparePersistentRelatedIdentifierCandidateId.mockReturnValue(
      GENERATED,
    );
    pageMocks.preparePersistentManualTimelineNoteEventId.mockReturnValue(
      MANUAL_GENERATED,
    );
    pageMocks.loadContractingDetailViewData.mockResolvedValue({
      kind: "persistent",
      detail: { id: ID },
    });
  });

  it("prepares the initial candidate on the server only for persistent detail", async () => {
    const html = await renderPage();

    expect(
      pageMocks.preparePersistentRelatedIdentifierCandidateId,
    ).toHaveBeenCalledTimes(1);
    expect(html).toContain('data-detail-source="persistent"');
    expect(html).toContain(`data-related-candidate="${GENERATED}"`);
    expect(html).toContain('data-related-state="none"');
  });

  it("reuses a validated candidate after unavailable so a technical retry keeps one intention", async () => {
    const html = await renderPage({
      relatedIdentifierCreation: "unavailable",
      relatedIdentifierCandidate: RETRY,
    });

    expect(
      pageMocks.preparePersistentRelatedIdentifierCandidateId,
    ).not.toHaveBeenCalled();
    expect(html).toContain(`data-related-candidate="${RETRY}"`);
    expect(html).toContain('data-related-state="unavailable"');
  });

  it("starts a fresh server-prepared candidate after a completed intention", async () => {
    const html = await renderPage({
      relatedIdentifierCreation: "created",
      relatedIdentifierCandidate: RETRY,
    });

    expect(
      pageMocks.preparePersistentRelatedIdentifierCandidateId,
    ).toHaveBeenCalledTimes(1);
    expect(html).toContain(`data-related-candidate="${GENERATED}"`);
    expect(html).not.toContain(`data-related-candidate="${RETRY}"`);
    expect(html).toContain('data-related-state="created"');
  });

  it("discards a malformed unavailable retry candidate and prepares a new server candidate", async () => {
    const html = await renderPage({
      relatedIdentifierCreation: "unavailable",
      relatedIdentifierCandidate: "not-a-uuid",
    });

    expect(
      pageMocks.preparePersistentRelatedIdentifierCandidateId,
    ).toHaveBeenCalledTimes(1);
    expect(html).toContain(`data-related-candidate="${GENERATED}"`);
    expect(html).not.toContain("not-a-uuid");
  });

  it("keeps demo read-only even when F42 query state and a valid candidate are forged", async () => {
    pageMocks.loadContractingDetailViewData.mockResolvedValueOnce({
      kind: "demo",
      detail: { id: "DEMO-001" },
    });

    const html = await renderPage({
      relatedIdentifierCreation: "unavailable",
      relatedIdentifierCandidate: RETRY,
    });

    expect(
      pageMocks.preparePersistentRelatedIdentifierCandidateId,
    ).not.toHaveBeenCalled();
    expect(html).toContain('data-detail-source="demo"');
    expect(html).toContain('data-related-candidate="none"');
    expect(html).toContain('data-related-state="none"');
    expect(html).not.toContain(RETRY);
  });

  it("never prepares or exposes a write candidate when protected detail is unavailable", async () => {
    pageMocks.loadContractingDetailViewData.mockResolvedValueOnce({
      kind: "unavailable",
    });

    const html = await renderPage({
      relatedIdentifierCreation: "unavailable",
      relatedIdentifierCandidate: RETRY,
    });

    expect(
      pageMocks.preparePersistentRelatedIdentifierCandidateId,
    ).not.toHaveBeenCalled();
    expect(html).toContain("Dados protegidos indisponíveis.");
    expect(html).not.toContain(RETRY);
    expect(html).not.toContain("data-related-candidate");
  });
});


describe("contracting detail F45 manual note candidate preparation", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    pageMocks.preparePersistentRelatedIdentifierCandidateId.mockReturnValue(GENERATED);
    pageMocks.preparePersistentManualTimelineNoteEventId.mockReturnValue(MANUAL_GENERATED);
    pageMocks.loadContractingDetailViewData.mockResolvedValue({
      kind: "persistent",
      detail: { id: ID },
    });
  });

  it("prepares a server candidate for a fresh intent", async () => {
    const html = await renderPage();
    expect(html).toContain(`data-manual-note-candidate="${MANUAL_GENERATED}"`);
    expect(pageMocks.preparePersistentManualTimelineNoteEventId).toHaveBeenCalledTimes(1);
  });

  it("reuses only a valid candidate for technical unavailable", async () => {
    const html = await renderPage({
      manualNoteCreation: "unavailable",
      manualNoteCandidate: MANUAL_RETRY,
    });
    expect(html).toContain(`data-manual-note-candidate="${MANUAL_RETRY}"`);
    expect(pageMocks.preparePersistentManualTimelineNoteEventId).not.toHaveBeenCalled();
  });

  it("does not expose a manual-note candidate in demo", async () => {
    pageMocks.loadContractingDetailViewData.mockResolvedValue({
      kind: "demo",
      detail: { id: "DEMO-001" },
    });
    const html = await renderPage({
      manualNoteCreation: "unavailable",
      manualNoteCandidate: MANUAL_RETRY,
    });
    expect(html).toContain('data-manual-note-candidate="none"');
    expect(html).toContain('data-manual-note-state="none"');
    expect(pageMocks.preparePersistentManualTimelineNoteEventId).not.toHaveBeenCalled();
  });
});
