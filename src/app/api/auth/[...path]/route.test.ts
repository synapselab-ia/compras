import { describe, expect, it } from "vitest";

import { DELETE, GET, PATCH, POST, PUT } from "./route";

describe("private auth HTTP boundary", () => {
  it.each([
    ["GET", GET],
    ["POST", POST],
    ["PUT", PUT],
    ["PATCH", PATCH],
    ["DELETE", DELETE],
  ])("rejects %s before any generic auth handler can expose signup or lateral endpoints", async (_method, handler) => {
    const response = handler();

    expect(response.status).toBe(404);
    expect(response.headers.get("cache-control")).toBe("no-store");
    await expect(response.text()).resolves.toBe("");
  });
});
