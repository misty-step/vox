import { describe, it, expect } from "vitest";
import { GET } from "../../app/v1/health/route";

describe("/v1/health", () => {
  it("returns ok status with service name", async () => {
    const response = await GET();
    const data = await response.json();

    expect(response.status).toBe(200);
    expect(data.ok).toBe(true);
    expect(data.service).toBe("vox-gateway");
    expect(data.time).toBeDefined();
  });

  it("returns valid ISO timestamp", async () => {
    const response = await GET();
    const data = await response.json();

    const timestamp = new Date(data.time);
    expect(timestamp.toISOString()).toBe(data.time);
  });
});
