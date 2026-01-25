import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";

vi.mock("../../lib/auth", () => ({
  requireAuth: vi.fn(),
}));

vi.mock("../../lib/entitlements", () => ({
  requireEntitlement: vi.fn(),
}));

const mockFetch = vi.fn();
global.fetch = mockFetch;

import { POST } from "../../app/v1/stt/transcribe/route";
import { requireAuth } from "../../lib/auth";
import { requireEntitlement } from "../../lib/entitlements";

describe("/v1/stt/transcribe", () => {
  const apiKey = "test-elevenlabs-key";
  let originalApiKey: string | undefined;

  beforeEach(() => {
    vi.clearAllMocks();
    originalApiKey = process.env.ELEVENLABS_API_KEY;
    process.env.ELEVENLABS_API_KEY = apiKey;

    vi.mocked(requireAuth).mockResolvedValue({
      ok: true,
      subject: "user_123",
      email: "user@example.com",
    });

    vi.mocked(requireEntitlement).mockResolvedValue({
      ok: true,
      plan: "trial",
      status: "active",
      features: ["stt", "rewrite"],
    });
  });

  afterEach(() => {
    if (originalApiKey === undefined) {
      delete process.env.ELEVENLABS_API_KEY;
    } else {
      process.env.ELEVENLABS_API_KEY = originalApiKey;
    }
  });

  it("returns 501 when API key is missing", async () => {
    delete process.env.ELEVENLABS_API_KEY;

    const form = new FormData();
    form.append("file", new File(["audio"], "audio.wav", { type: "audio/wav" }));

    const request = new Request("http://localhost/v1/stt/transcribe", {
      method: "POST",
      body: form,
    });
    const response = await POST(request);
    const data = await response.json();

    expect(response.status).toBe(501);
    expect(data.error).toBe("stt_provider_not_configured");
  });

  it("returns 413 when file exceeds size limit", async () => {
    // Create a file larger than 25MB
    const largeContent = new Uint8Array(26 * 1024 * 1024); // 26MB
    const form = new FormData();
    form.append(
      "file",
      new File([largeContent], "audio.wav", { type: "audio/wav" })
    );

    const request = new Request("http://localhost/v1/stt/transcribe", {
      method: "POST",
      body: form,
    });
    const response = await POST(request);
    const data = await response.json();

    expect(response.status).toBe(413);
    expect(data.error).toBe("payload_too_large");
  });

  it("returns 400 when no file provided", async () => {
    const form = new FormData();
    form.append("model_id", "scribe_v1");

    const request = new Request("http://localhost/v1/stt/transcribe", {
      method: "POST",
      body: form,
    });
    const response = await POST(request);
    const data = await response.json();

    expect(response.status).toBe(400);
    expect(data.error).toBe("missing_file");
  });

  it("returns 502 when ElevenLabs returns error", async () => {
    mockFetch.mockResolvedValue({
      ok: false,
      status: 500,
      text: async () => "upstream error",
    });

    const form = new FormData();
    form.append("file", new File(["audio"], "audio.wav", { type: "audio/wav" }));

    const request = new Request("http://localhost/v1/stt/transcribe", {
      method: "POST",
      body: form,
    });
    const response = await POST(request);
    const data = await response.json();

    expect(response.status).toBe(502);
    expect(data.error).toBe("stt_api_error");
  });

  it("proxies request and returns transcription", async () => {
    mockFetch.mockResolvedValue({
      ok: true,
      json: async () => ({
        text: "Hello world",
        language_code: "en",
      }),
    });

    const form = new FormData();
    form.append("file", new File(["audio"], "audio.wav", { type: "audio/wav" }));
    form.append("session_id", "session-123");
    form.append("model_id", "scribe_v1");

    const request = new Request("http://localhost/v1/stt/transcribe", {
      method: "POST",
      body: form,
    });
    const response = await POST(request);
    const data = await response.json();

    expect(response.status).toBe(200);
    expect(data.text).toBe("Hello world");
    expect(data.language_code).toBe("en");
    expect(data.session_id).toBe("session-123");

    const [url, options] = mockFetch.mock.calls[0];
    expect(url).toBe("https://api.elevenlabs.io/v1/speech-to-text");
    expect(options?.headers?.["xi-api-key"]).toBe(apiKey);
    expect(options?.body).toBeInstanceOf(FormData);
  });
});
