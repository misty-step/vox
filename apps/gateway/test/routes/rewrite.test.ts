import { describe, it, expect, vi, beforeEach } from "vitest";

// Mock the auth module
vi.mock("../../lib/auth", () => ({
  requireAuth: vi.fn(),
}));

// Mock the entitlements module
vi.mock("../../lib/entitlements", () => ({
  requireEntitlement: vi.fn(),
}));

// Mock global fetch for Gemini API calls
const mockFetch = vi.fn();
global.fetch = mockFetch;

import { POST } from "../../app/v1/rewrite/route";
import { requireAuth } from "../../lib/auth";
import { requireEntitlement } from "../../lib/entitlements";

describe("/v1/rewrite", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it("returns 401 when auth fails", async () => {
    vi.mocked(requireAuth).mockResolvedValue({
      ok: false,
      response: Response.json({ error: "unauthorized" }, { status: 401 }),
    });

    const request = new Request("http://localhost/v1/rewrite", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({}),
    });
    const response = await POST(request);

    expect(response.status).toBe(401);
  });

  it("returns 403 when entitlement check fails", async () => {
    vi.mocked(requireAuth).mockResolvedValue({
      ok: true,
      subject: "user_123",
    });

    vi.mocked(requireEntitlement).mockResolvedValue({
      ok: false,
      error: "subscription_inactive",
      statusCode: 403,
    });

    const request = new Request("http://localhost/v1/rewrite", {
      method: "POST",
      headers: {
        Authorization: "Bearer test-token",
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        sessionId: "test",
        locale: "en",
        transcript: { text: "test" },
        context: "",
        processingLevel: "light",
      }),
    });
    const response = await POST(request);
    const data = await response.json();

    expect(response.status).toBe(403);
    expect(data.error).toBe("subscription_inactive");
  });

  it("returns 400 for invalid JSON body", async () => {
    vi.mocked(requireAuth).mockResolvedValue({
      ok: true,
      subject: "user_123",
    });

    vi.mocked(requireEntitlement).mockResolvedValue({
      ok: true,
      plan: "trial",
      status: "active",
      features: ["stt", "rewrite"],
    });

    const request = new Request("http://localhost/v1/rewrite", {
      method: "POST",
      headers: {
        Authorization: "Bearer test-token",
        "Content-Type": "application/json",
      },
      body: "not json",
    });
    const response = await POST(request);
    const data = await response.json();

    expect(response.status).toBe(400);
    expect(data.error).toBe("invalid_json");
  });

  it("returns 400 for missing transcript", async () => {
    vi.mocked(requireAuth).mockResolvedValue({
      ok: true,
      subject: "user_123",
    });

    vi.mocked(requireEntitlement).mockResolvedValue({
      ok: true,
      plan: "trial",
      status: "active",
      features: ["stt", "rewrite"],
    });

    const request = new Request("http://localhost/v1/rewrite", {
      method: "POST",
      headers: {
        Authorization: "Bearer test-token",
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ sessionId: "test" }), // missing transcript
    });
    const response = await POST(request);
    const data = await response.json();

    expect(response.status).toBe(400);
    expect(data.error).toBe("missing_transcript");
  });

  it("calls Gemini API and returns rewritten text", async () => {
    vi.mocked(requireAuth).mockResolvedValue({
      ok: true,
      subject: "user_123",
    });

    vi.mocked(requireEntitlement).mockResolvedValue({
      ok: true,
      plan: "trial",
      status: "active",
      features: ["stt", "rewrite"],
    });

    mockFetch.mockResolvedValue({
      ok: true,
      json: async () => ({
        candidates: [
          {
            content: {
              parts: [{ text: "Hello, this is the cleaned text." }],
            },
          },
        ],
      }),
    });

    const request = new Request("http://localhost/v1/rewrite", {
      method: "POST",
      headers: {
        Authorization: "Bearer test-token",
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        sessionId: "test-session",
        locale: "en",
        transcript: { text: "um hello uh this is the uh cleaned text" },
        context: "",
        processingLevel: "light",
      }),
    });
    const response = await POST(request);
    const data = await response.json();

    expect(response.status).toBe(200);
    expect(data.finalText).toBe("Hello, this is the cleaned text.");
    expect(data.sessionId).toBe("test-session");
    expect(mockFetch).toHaveBeenCalledTimes(1);

    // Verify Gemini API was called with correct endpoint
    const [url] = mockFetch.mock.calls[0];
    expect(url).toContain("generativelanguage.googleapis.com");
    expect(url).toContain("generateContent");
  });

  it("handles Gemini API errors gracefully", async () => {
    vi.mocked(requireAuth).mockResolvedValue({
      ok: true,
      subject: "user_123",
    });

    vi.mocked(requireEntitlement).mockResolvedValue({
      ok: true,
      plan: "trial",
      status: "active",
      features: ["stt", "rewrite"],
    });

    mockFetch.mockResolvedValue({
      ok: false,
      status: 500,
      text: async () => "Internal Server Error",
    });

    const request = new Request("http://localhost/v1/rewrite", {
      method: "POST",
      headers: {
        Authorization: "Bearer test-token",
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        sessionId: "test-session",
        locale: "en",
        transcript: { text: "test text" },
        context: "",
        processingLevel: "light",
      }),
    });
    const response = await POST(request);
    const data = await response.json();

    expect(response.status).toBe(502);
    expect(data.error).toBe("gemini_api_error");
    expect(data.status).toBe(500);
  });

  it("uses correct prompt for aggressive processing level", async () => {
    vi.mocked(requireAuth).mockResolvedValue({
      ok: true,
      subject: "user_123",
    });

    vi.mocked(requireEntitlement).mockResolvedValue({
      ok: true,
      plan: "trial",
      status: "active",
      features: ["stt", "rewrite"],
    });

    mockFetch.mockResolvedValue({
      ok: true,
      json: async () => ({
        candidates: [{ content: { parts: [{ text: "Polished text." }] } }],
      }),
    });

    const request = new Request("http://localhost/v1/rewrite", {
      method: "POST",
      headers: {
        Authorization: "Bearer test-token",
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        sessionId: "test",
        locale: "en",
        transcript: { text: "some text" },
        context: "coding context",
        processingLevel: "aggressive",
      }),
    });
    await POST(request);

    // Verify the system instruction contains aggressive-specific keywords
    const [, options] = mockFetch.mock.calls[0];
    const body = JSON.parse(options.body);
    expect(body.systemInstruction.parts[0].text).toContain("executive editor");
    expect(body.systemInstruction.parts[0].text).toContain("high-impact");
  });

  it("uses default prompt for 'off' processing level", async () => {
    vi.mocked(requireAuth).mockResolvedValue({
      ok: true,
      subject: "user_123",
    });

    vi.mocked(requireEntitlement).mockResolvedValue({
      ok: true,
      plan: "trial",
      status: "active",
      features: ["stt", "rewrite"],
    });

    mockFetch.mockResolvedValue({
      ok: true,
      json: async () => ({
        candidates: [{ content: { parts: [{ text: "Clean text." }] } }],
      }),
    });

    const request = new Request("http://localhost/v1/rewrite", {
      method: "POST",
      headers: {
        Authorization: "Bearer test-token",
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        sessionId: "test",
        locale: "en",
        transcript: { text: "some text" },
        context: "",
        processingLevel: "off",
      }),
    });
    await POST(request);

    const [, options] = mockFetch.mock.calls[0];
    const body = JSON.parse(options.body);
    expect(body.systemInstruction.parts[0].text).toContain("expert editor");
  });

  it("passes required feature to entitlement check", async () => {
    vi.mocked(requireAuth).mockResolvedValue({
      ok: true,
      subject: "user_123",
      email: "test@example.com",
    });

    vi.mocked(requireEntitlement).mockResolvedValue({
      ok: true,
      plan: "trial",
      status: "active",
      features: ["stt", "rewrite"],
    });

    mockFetch.mockResolvedValue({
      ok: true,
      json: async () => ({
        candidates: [{ content: { parts: [{ text: "Result." }] } }],
      }),
    });

    const request = new Request("http://localhost/v1/rewrite", {
      method: "POST",
      headers: {
        Authorization: "Bearer test-token",
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        sessionId: "test",
        locale: "en",
        transcript: { text: "text" },
        context: "",
        processingLevel: "light",
      }),
    });
    await POST(request);

    expect(requireEntitlement).toHaveBeenCalledWith("user_123", "test@example.com", "rewrite");
  });
});
