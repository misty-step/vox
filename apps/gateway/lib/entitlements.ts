import { getConvexClient, api } from "./convex";

export type EntitlementInfo = {
  plan: string;
  status: string;
  features: string[];
  currentPeriodEnd?: number;
  stripeCustomerId?: string;
};

export type RequireEntitlementResult =
  | { ok: true } & EntitlementInfo
  | { ok: false; error: string; statusCode: number };

export type GetEntitlementResult =
  | { ok: true } & EntitlementInfo
  | { ok: false; error: string; statusCode: number };

/**
 * Fetch user's entitlement info. Always returns the entitlement state,
 * even if inactive. Use this for the /v1/entitlements endpoint.
 */
export async function getEntitlement(
  subject: string,
  email?: string
): Promise<GetEntitlementResult> {
  const convex = getConvexClient();

  // Get or create user
  const userId = await convex.mutation(api.users.getOrCreate, {
    clerkId: subject,
    email,
  });

  const entitlement = await convex.mutation(api.entitlements.getOrCreateTrial, {
    userId,
  });

  if (!entitlement) {
    return { ok: false, error: "entitlement_creation_failed", statusCode: 500 };
  }

  const features = getFeatures(entitlement.plan, entitlement.status);

  return {
    ok: true,
    plan: entitlement.plan,
    status: entitlement.status,
    features,
    currentPeriodEnd: entitlement.currentPeriodEnd,
    stripeCustomerId: entitlement.stripeCustomerId,
  };
}

/**
 * Require an active entitlement with optional feature check.
 * Returns error if subscription is inactive or feature not available.
 * Use this for gating access to STT/rewrite endpoints.
 */
export async function requireEntitlement(
  subject: string,
  email?: string,
  requiredFeature?: string
): Promise<RequireEntitlementResult> {
  const result = await getEntitlement(subject, email);

  if (!result.ok) {
    return result;
  }

  // Check subscription status
  if (result.status !== "active") {
    return {
      ok: false,
      error: "subscription_inactive",
      statusCode: 403,
    };
  }

  // Check required feature if specified
  if (requiredFeature && !result.features.includes(requiredFeature)) {
    return {
      ok: false,
      error: "feature_not_available",
      statusCode: 403,
    };
  }

  return result;
}

function getFeatures(plan: string, status: string): string[] {
  if (status !== "active") {
    return [];
  }

  switch (plan) {
    case "pro":
      return ["rewrite", "stt", "unlimited"];
    case "trial":
      return ["rewrite", "stt"];
    default:
      return [];
  }
}
