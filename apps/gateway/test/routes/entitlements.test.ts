import { describe, it, expect, vi, beforeEach } from "vitest";

// Mock the auth module
vi.mock("../../lib/auth", () => ({
  requireAuth: vi.fn(),
}));

// Mock the entitlements module
vi.mock("../../lib/entitlements", () => ({
  getEntitlement: vi.fn(),
}));

import { GET } from "../../app/v1/entitlements/route";
import { requireAuth } from "../../lib/auth";
import { getEntitlement } from "../../lib/entitlements";

describe("/v1/entitlements", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it("returns 401 when auth fails", async () => {
    vi.mocked(requireAuth).mockResolvedValue({
      ok: false,
      response: Response.json({ error: "unauthorized" }, { status: 401 }),
    });

    const request = new Request("http://localhost/v1/entitlements");
    const response = await GET(request);

    expect(response.status).toBe(401);
  });

  it("returns trial entitlement for new user", async () => {
    vi.mocked(requireAuth).mockResolvedValue({
      ok: true,
      subject: "user_123",
      email: "test@example.com",
    });

    vi.mocked(getEntitlement).mockResolvedValue({
      ok: true,
      plan: "trial",
      status: "active",
      features: ["rewrite", "stt"],
    });

    const request = new Request("http://localhost/v1/entitlements", {
      headers: { Authorization: "Bearer test-token" },
    });
    const response = await GET(request);
    const data = await response.json();

    expect(response.status).toBe(200);
    expect(data.plan).toBe("trial");
    expect(data.status).toBe("active");
    expect(data.features).toContain("rewrite");
    expect(data.features).toContain("stt");
  });

  it("returns pro entitlement for subscribed user", async () => {
    vi.mocked(requireAuth).mockResolvedValue({
      ok: true,
      subject: "user_456",
      email: "pro@example.com",
    });

    const periodEnd = Date.now() + 30 * 24 * 60 * 60 * 1000;
    vi.mocked(getEntitlement).mockResolvedValue({
      ok: true,
      plan: "pro",
      status: "active",
      features: ["rewrite", "stt", "unlimited"],
      currentPeriodEnd: periodEnd,
    });

    const request = new Request("http://localhost/v1/entitlements", {
      headers: { Authorization: "Bearer test-token" },
    });
    const response = await GET(request);
    const data = await response.json();

    expect(response.status).toBe(200);
    expect(data.plan).toBe("pro");
    expect(data.status).toBe("active");
    expect(data.features).toContain("unlimited");
    expect(data.currentPeriodEnd).toBe(periodEnd);
  });

  it("returns cancelled entitlement info (does not block)", async () => {
    vi.mocked(requireAuth).mockResolvedValue({
      ok: true,
      subject: "user_789",
      email: "cancelled@example.com",
    });

    vi.mocked(getEntitlement).mockResolvedValue({
      ok: true,
      plan: "cancelled",
      status: "cancelled",
      features: [],
    });

    const request = new Request("http://localhost/v1/entitlements", {
      headers: { Authorization: "Bearer test-token" },
    });
    const response = await GET(request);
    const data = await response.json();

    // Entitlements endpoint returns info even for cancelled users
    expect(response.status).toBe(200);
    expect(data.plan).toBe("cancelled");
    expect(data.status).toBe("cancelled");
    expect(data.features).toEqual([]);
  });

  it("returns error when entitlement fetch fails", async () => {
    vi.mocked(requireAuth).mockResolvedValue({
      ok: true,
      subject: "user_error",
      email: "error@example.com",
    });

    vi.mocked(getEntitlement).mockResolvedValue({
      ok: false,
      error: "entitlement_creation_failed",
      statusCode: 500,
    });

    const request = new Request("http://localhost/v1/entitlements", {
      headers: { Authorization: "Bearer test-token" },
    });
    const response = await GET(request);
    const data = await response.json();

    expect(response.status).toBe(500);
    expect(data.error).toBe("entitlement_creation_failed");
  });
});
