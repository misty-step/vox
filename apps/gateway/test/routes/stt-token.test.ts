import { describe, it, expect } from "vitest";

import { POST } from "../../app/v1/stt/token/route";

describe("/v1/stt/token", () => {
  it("returns 410 with deprecation message", async () => {
    const request = new Request("http://localhost/v1/stt/token", {
      method: "POST",
    });
    const response = await POST(request);
    const data = await response.json();

    expect(response.status).toBe(410);
    expect(data.error).toBe("endpoint_deprecated");
    expect(data.message).toBe("Use /v1/stt/transcribe instead");
  });
});
