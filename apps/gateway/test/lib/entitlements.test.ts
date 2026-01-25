import { describe, it, expect, vi, beforeEach } from "vitest";

// We can't easily test the internal functions (isTrialExpired, getEffectiveStatus)
// since they're not exported. Instead, we test through the public API.

// Mock Convex client
vi.mock("../../lib/convex", () => ({
  getConvexClient: vi.fn(() => ({
    mutation: vi.fn(),
  })),
  api: {
    users: { getOrCreate: "users:getOrCreate" },
    entitlements: { getOrCreateTrial: "entitlements:getOrCreateTrial" },
  },
}));

import { getEntitlement, requireEntitlement } from "../../lib/entitlements";
import { getConvexClient } from "../../lib/convex";

describe("lib/entitlements", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  describe("trial expiration", () => {
    it("returns expired status for trial past currentPeriodEnd", async () => {
      const mockClient = {
        mutation: vi
          .fn()
          .mockResolvedValueOnce("user_123") // users.getOrCreate
          .mockResolvedValueOnce({
            // entitlements.getOrCreateTrial
            plan: "trial",
            status: "active",
            currentPeriodEnd: Date.now() - 3600 * 1000, // 1 hour ago
          }),
      };
      vi.mocked(getConvexClient).mockReturnValue(mockClient as never);

      const result = await getEntitlement("subject_123");

      expect(result.ok).toBe(true);
      if (result.ok) {
        expect(result.status).toBe("expired");
        expect(result.features).toEqual([]); // No features for expired
      }
    });

    it("returns active status for trial with future currentPeriodEnd", async () => {
      const mockClient = {
        mutation: vi
          .fn()
          .mockResolvedValueOnce("user_123")
          .mockResolvedValueOnce({
            plan: "trial",
            status: "active",
            currentPeriodEnd: Date.now() + 3600 * 1000, // 1 hour from now
          }),
      };
      vi.mocked(getConvexClient).mockReturnValue(mockClient as never);

      const result = await getEntitlement("subject_123");

      expect(result.ok).toBe(true);
      if (result.ok) {
        expect(result.status).toBe("active");
        expect(result.features).toContain("stt");
        expect(result.features).toContain("rewrite");
      }
    });

    it("pro plan is not affected by currentPeriodEnd", async () => {
      const mockClient = {
        mutation: vi
          .fn()
          .mockResolvedValueOnce("user_123")
          .mockResolvedValueOnce({
            plan: "pro",
            status: "active",
            currentPeriodEnd: Date.now() - 3600 * 1000, // Past date
          }),
      };
      vi.mocked(getConvexClient).mockReturnValue(mockClient as never);

      const result = await getEntitlement("subject_123");

      expect(result.ok).toBe(true);
      if (result.ok) {
        expect(result.status).toBe("active"); // Pro ignores expiration check
        expect(result.features).toContain("unlimited");
      }
    });
  });

  describe("requireEntitlement", () => {
    it("returns 403 for expired trial", async () => {
      const mockClient = {
        mutation: vi
          .fn()
          .mockResolvedValueOnce("user_123")
          .mockResolvedValueOnce({
            plan: "trial",
            status: "active",
            currentPeriodEnd: Date.now() - 3600 * 1000, // Expired
          }),
      };
      vi.mocked(getConvexClient).mockReturnValue(mockClient as never);

      const result = await requireEntitlement("subject_123", undefined, "stt");

      expect(result.ok).toBe(false);
      if (!result.ok) {
        expect(result.statusCode).toBe(403);
        expect(result.error).toBe("subscription_inactive");
      }
    });

    it("allows access for active trial", async () => {
      const mockClient = {
        mutation: vi
          .fn()
          .mockResolvedValueOnce("user_123")
          .mockResolvedValueOnce({
            plan: "trial",
            status: "active",
            currentPeriodEnd: Date.now() + 3600 * 1000, // Future
          }),
      };
      vi.mocked(getConvexClient).mockReturnValue(mockClient as never);

      const result = await requireEntitlement("subject_123", undefined, "stt");

      expect(result.ok).toBe(true);
    });
  });
});
