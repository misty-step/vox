import { describe, it, expect, vi, beforeEach } from "vitest";

// Mock the auth module
vi.mock("../../lib/auth", () => ({
  requireAuth: vi.fn(),
}));

// Mock the convex module
vi.mock("../../lib/convex", () => ({
  getConvexClient: vi.fn(),
  api: {
    users: { getOrCreate: "users:getOrCreate" },
    entitlements: { getByUserId: "entitlements:getByUserId", createTrial: "entitlements:createTrial" },
  },
}));

import { GET } from "../../app/v1/entitlements/route";
import { requireAuth } from "../../lib/auth";
import { getConvexClient } from "../../lib/convex";

describe("/v1/entitlements", () => {
  const mockConvexClient = {
    query: vi.fn(),
    mutation: vi.fn(),
  };

  beforeEach(() => {
    vi.clearAllMocks();
    vi.mocked(getConvexClient).mockReturnValue(mockConvexClient as any);
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

    mockConvexClient.mutation.mockResolvedValue("user_id_123");
    mockConvexClient.query.mockResolvedValue({
      plan: "trial",
      status: "active",
      currentPeriodEnd: null,
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
    mockConvexClient.mutation.mockResolvedValue("user_id_456");
    mockConvexClient.query.mockResolvedValue({
      plan: "pro",
      status: "active",
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
    expect(data.currentPeriodEnd).toBe(periodEnd);
    expect(data.features).toContain("unlimited");
  });
});
