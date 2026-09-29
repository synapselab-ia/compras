import { beforeEach, describe, expect, it, vi } from "vitest";

const actionMocks = vi.hoisted(() => ({
  readPersistentReadMode: vi.fn(),
  isPersistentContractingId: vi.fn(),
  mutatePersistentContractingResponsible: vi.fn(),
  revalidatePath: vi.fn(),
  redirect: vi.fn((url: string) => {
    throw new Error(`REDIRECT:${url}`);
  }),
}));

vi.mock("next/cache", () => ({ revalidatePath: actionMocks.revalidatePath }));
vi.mock("next/navigation", () => ({ redirect: actionMocks.redirect }));
vi.mock("@/server/persistent-read-mode", () => ({
  readPersistentReadMode: actionMocks.readPersistentReadMode,
}));
vi.mock("./persistent-read", () => ({
  isPersistentContractingId: actionMocks.isPersistentContractingId,
}));
vi.mock("./persistent-mutation", () => ({
  mutatePersistentContractingNextAction: vi.fn(),
}));
vi.mock("./persistent-object-mutation", () => ({
  mutatePersistentContractingObject: vi.fn(),
}));
vi.mock("./persistent-responsible-mutation", () => ({
  mutatePersistentContractingResponsible:
    actionMocks.mutatePersistentContractingResponsible,
}));

import { updatePersistentResponsibleAction } from "./actions";

const ID = "48000000-0000-4000-8000-000000000001";
const CURRENT = "48000000-0000-4000-8000-000000000002";
const NEW = "48000000-0000-4000-8000-000000000003";
const PATH = `/contratacoes/${ID}`;
const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function membershipForm(): FormData {
  const form = new FormData();
  form.set("contractingId", ID);
  form.set("expectedResponsibleKind", "membership");
  form.set("expectedResponsibleMembershipId", CURRENT);
  form.set("newResponsibleKind", "membership");
  form.set("newResponsibleMembershipId", NEW);
  return form;
}

function nullForm(): FormData {
  const form = new FormData();
  form.set("contractingId", ID);
  form.set("expectedResponsibleKind", "null");
  form.set("newResponsibleKind", "null");
  return form;
}

describe("updatePersistentResponsibleAction", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    actionMocks.readPersistentReadMode.mockReturnValue("persistent");
    actionMocks.isPersistentContractingId.mockImplementation(
      (value: unknown) => typeof value === "string" && UUID_PATTERN.test(value),
    );
    actionMocks.mutatePersistentContractingResponsible.mockResolvedValue("updated");
  });

  it("forwards only contractingId plus exact nullable expected/new candidates", async () => {
    const form = membershipForm();
    form.set("$ACTION_ID_TEST", "framework-field");

    await expect(updatePersistentResponsibleAction(form)).rejects.toThrow(
      `REDIRECT:${PATH}?responsibleMutation=updated`,
    );

    expect(actionMocks.mutatePersistentContractingResponsible).toHaveBeenCalledTimes(1);
    expect(actionMocks.mutatePersistentContractingResponsible).toHaveBeenCalledWith({
      contractingId: ID,
      expectedResponsibleMembershipId: CURRENT,
      newResponsibleMembershipId: NEW,
    });
    expect(actionMocks.revalidatePath).toHaveBeenCalledWith(PATH);
  });

  it("transports SQL NULL explicitly without a sentinel membership scalar", async () => {
    actionMocks.mutatePersistentContractingResponsible.mockResolvedValueOnce("unchanged");

    await expect(updatePersistentResponsibleAction(nullForm())).rejects.toThrow(
      `REDIRECT:${PATH}?responsibleMutation=unchanged`,
    );

    expect(actionMocks.mutatePersistentContractingResponsible).toHaveBeenCalledWith({
      contractingId: ID,
      expectedResponsibleMembershipId: null,
      newResponsibleMembershipId: null,
    });
    expect(actionMocks.revalidatePath).not.toHaveBeenCalled();
  });

  it("fails closed on extra authority fields before F47", async () => {
    for (const field of [
      "teamId",
      "team_id",
      "actor",
      "actorMembershipId",
      "userId",
      "issuer",
      "subject",
      "eventId",
      "timestamp",
      "stage",
      "status",
      "waiting",
      "callbackURL",
      "redirect",
    ]) {
      vi.clearAllMocks();
      actionMocks.readPersistentReadMode.mockReturnValue("persistent");
      actionMocks.isPersistentContractingId.mockImplementation(
        (value: unknown) => typeof value === "string" && UUID_PATTERN.test(value),
      );
      const form = membershipForm();
      form.set(field, "FORGED");

      await expect(updatePersistentResponsibleAction(form)).rejects.toThrow(
        `REDIRECT:${PATH}?responsibleMutation=unavailable`,
      );
      expect(actionMocks.mutatePersistentContractingResponsible).not.toHaveBeenCalled();
    }
  });

  it("rejects duplicate, malformed and ambiguous nullable transport before F47", async () => {
    const cases: FormData[] = [];

    const duplicate = membershipForm();
    duplicate.append("newResponsibleMembershipId", NEW);
    cases.push(duplicate);

    const malformed = membershipForm();
    malformed.set("newResponsibleMembershipId", "not-a-uuid");
    cases.push(malformed);

    const invalidKind = membershipForm();
    invalidKind.set("newResponsibleKind", "text");
    cases.push(invalidKind);

    const missingMembership = membershipForm();
    missingMembership.delete("newResponsibleMembershipId");
    cases.push(missingMembership);

    const nullWithScalar = nullForm();
    nullWithScalar.set("newResponsibleMembershipId", NEW);
    cases.push(nullWithScalar);

    for (const form of cases) {
      vi.clearAllMocks();
      actionMocks.readPersistentReadMode.mockReturnValue("persistent");
      actionMocks.isPersistentContractingId.mockImplementation(
        (value: unknown) => typeof value === "string" && UUID_PATTERN.test(value),
      );

      await expect(updatePersistentResponsibleAction(form)).rejects.toThrow(
        `REDIRECT:${PATH}?responsibleMutation=unavailable`,
      );
      expect(actionMocks.mutatePersistentContractingResponsible).not.toHaveBeenCalled();
    }
  });

  it("lets a syntactically valid forged candidate reach F47 without turning it into authority", async () => {
    const crossTeamCandidate = "48000000-0000-4000-8000-000000000099";
    const form = membershipForm();
    form.set("newResponsibleMembershipId", crossTeamCandidate);
    actionMocks.mutatePersistentContractingResponsible.mockResolvedValueOnce("not-available");

    await expect(updatePersistentResponsibleAction(form)).rejects.toThrow(
      `REDIRECT:${PATH}?responsibleMutation=not-available`,
    );

    expect(actionMocks.mutatePersistentContractingResponsible).toHaveBeenCalledWith({
      contractingId: ID,
      expectedResponsibleMembershipId: CURRENT,
      newResponsibleMembershipId: crossTeamCandidate,
    });
    expect(actionMocks.revalidatePath).not.toHaveBeenCalled();
  });

  it("revalidates writes and conflicts, while every other result stays local and sanitized", async () => {
    for (const [result, shouldRevalidate] of [
      ["updated", true],
      ["unchanged", false],
      ["conflict", true],
      ["not-available", false],
      ["unavailable", false],
    ] as const) {
      vi.clearAllMocks();
      actionMocks.readPersistentReadMode.mockReturnValue("persistent");
      actionMocks.isPersistentContractingId.mockImplementation(
        (value: unknown) => typeof value === "string" && UUID_PATTERN.test(value),
      );
      actionMocks.mutatePersistentContractingResponsible.mockResolvedValueOnce(result);

      await expect(updatePersistentResponsibleAction(membershipForm())).rejects.toThrow(
        `REDIRECT:${PATH}?responsibleMutation=${result}`,
      );

      if (shouldRevalidate) {
        expect(actionMocks.revalidatePath).toHaveBeenCalledWith(PATH);
      } else {
        expect(actionMocks.revalidatePath).not.toHaveBeenCalled();
      }
    }
  });

  it("sanitizes impossible outcomes and thrown technical details", async () => {
    actionMocks.mutatePersistentContractingResponsible.mockResolvedValueOnce(
      "impossible-result",
    );

    await expect(updatePersistentResponsibleAction(membershipForm())).rejects.toThrow(
      `REDIRECT:${PATH}?responsibleMutation=unavailable`,
    );

    vi.clearAllMocks();
    actionMocks.readPersistentReadMode.mockReturnValue("persistent");
    actionMocks.isPersistentContractingId.mockImplementation(
      (value: unknown) => typeof value === "string" && UUID_PATTERN.test(value),
    );
    actionMocks.mutatePersistentContractingResponsible.mockRejectedValueOnce(
      new Error("postgresql://secret-user:secret-pass@private.invalid/database"),
    );

    await expect(updatePersistentResponsibleAction(membershipForm())).rejects.toThrow(
      `REDIRECT:${PATH}?responsibleMutation=unavailable`,
    );

    expect(JSON.stringify(actionMocks.redirect.mock.calls)).not.toContain("secret-user");
    expect(JSON.stringify(actionMocks.redirect.mock.calls)).not.toContain("private.invalid");
  });

  it("never reaches F47 in demo/invalid mode or with a malformed contracting id", async () => {
    for (const mode of ["demo", "invalid"] as const) {
      vi.clearAllMocks();
      actionMocks.readPersistentReadMode.mockReturnValue(mode);

      await expect(updatePersistentResponsibleAction(membershipForm())).rejects.toThrow(
        "REDIRECT:/",
      );
      expect(actionMocks.mutatePersistentContractingResponsible).not.toHaveBeenCalled();
    }

    vi.clearAllMocks();
    actionMocks.readPersistentReadMode.mockReturnValue("persistent");
    actionMocks.isPersistentContractingId.mockReturnValue(false);

    await expect(updatePersistentResponsibleAction(membershipForm())).rejects.toThrow(
      "REDIRECT:/",
    );
    expect(actionMocks.mutatePersistentContractingResponsible).not.toHaveBeenCalled();
  });
});
