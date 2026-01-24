import { requireAuth } from "../../../lib/auth";
import { getEntitlement } from "../../../lib/entitlements";

export const runtime = "nodejs";

export async function GET(request: Request) {
  const auth = await requireAuth(request);
  if (!auth.ok) {
    return auth.response;
  }

  // Get entitlement (creates trial if none exists)
  // Always returns entitlement info regardless of status
  const entitlement = await getEntitlement(auth.subject, auth.email);

  if (!entitlement.ok) {
    return Response.json(
      { error: entitlement.error },
      { status: entitlement.statusCode }
    );
  }

  return Response.json({
    subject: auth.subject,
    plan: entitlement.plan,
    status: entitlement.status,
    features: entitlement.features,
    currentPeriodEnd: entitlement.currentPeriodEnd,
  });
}
