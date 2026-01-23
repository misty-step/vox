import { describe, it, expect, vi, beforeEach } from "vitest";

// Mock the auth module
vi.mock("../../lib/auth", () => ({
  requireAuth: vi.fn(),
}));

import { POST } from "../../app/v1/stt/token/route";
import { requireAuth } from "../../lib/auth";

describe("/v1/stt/token", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it("returns 401 when auth fails", async () => {
    vi.mocked(requireAuth).mockResolvedValue({
      ok: false,
      response: Response.json({ error: "unauthorized" }, { status: 401 }),
    });

    const request = new Request("http://localhost/v1/stt/token", {
      method: "POST",
    });
    const response = await POST(request);

    expect(response.status).toBe(401);
  });

  it("returns token response when auth succeeds", async () => {
    vi.mocked(requireAuth).mockResolvedValue({
      ok: true,
      subject: "user_123",
    });

    const request = new Request("http://localhost/v1/stt/token", {
      method: "POST",
      headers: { Authorization: "Bearer test-token" },
    });
    const response = await POST(request);
    const data = await response.json();

    expect(response.status).toBe(200);
    expect(data.token).toBeDefined();
    expect(data.provider).toBe("elevenlabs");
    expect(data.expiresAt).toBeDefined();
  });

  it("returns valid expiration timestamp", async () => {
    vi.mocked(requireAuth).mockResolvedValue({
      ok: true,
      subject: "user_123",
    });

    const request = new Request("http://localhost/v1/stt/token", {
      method: "POST",
      headers: { Authorization: "Bearer test-token" },
    });
    const response = await POST(request);
    const data = await response.json();

    const expiresAt = new Date(data.expiresAt);
    const now = new Date();
    // Token should expire in the future (within 1 hour typically)
    expect(expiresAt.getTime()).toBeGreaterThan(now.getTime());
  });
});
