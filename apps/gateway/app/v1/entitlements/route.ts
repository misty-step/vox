import { requireAuth } from "../../../lib/auth";
import { getConvexClient, api } from "../../../lib/convex";

export const runtime = "nodejs";

export async function GET(request: Request) {
  const auth = await requireAuth(request);
  if (!auth.ok) {
    return auth.response;
  }

  const convex = getConvexClient();

  // Get or create user
  const userId = await convex.mutation(api.users.getOrCreate, {
    clerkId: auth.subject,
    email: auth.email,
  });

  // Get entitlement, create trial if none exists
  let entitlement = await convex.query(api.entitlements.getByUserId, { userId });

  if (!entitlement) {
    await convex.mutation(api.entitlements.createTrial, { userId });
    entitlement = await convex.query(api.entitlements.getByUserId, { userId });
  }

  if (!entitlement) {
    return Response.json({ error: "entitlement_creation_failed" }, { status: 500 });
  }

  return Response.json({
    subject: auth.subject,
    plan: entitlement.plan,
    status: entitlement.status,
    features: getFeatures(entitlement.plan, entitlement.status),
    currentPeriodEnd: entitlement.currentPeriodEnd,
  });
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
