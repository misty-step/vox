import { describe, it, expect } from "vitest";
import { GET } from "../../app/v1/config/route";

describe("/v1/config", () => {
  it("returns STT provider configuration", async () => {
    const response = await GET();
    const data = await response.json();

    expect(response.status).toBe(200);
    expect(data.stt).toBeDefined();
    expect(data.stt.provider).toBe("elevenlabs");
    expect(data.stt.directUpload).toBe(true);
  });

  it("returns rewrite provider configuration", async () => {
    const response = await GET();
    const data = await response.json();

    expect(data.rewrite).toBeDefined();
    expect(data.rewrite.provider).toBe("gemini");
  });

  it("returns available processing levels", async () => {
    const response = await GET();
    const data = await response.json();

    expect(data.processingLevels).toEqual(["off", "light", "aggressive"]);
  });
});
