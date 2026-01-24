import Stripe from "stripe";
import { requireAuth } from "../../../../lib/auth";
import { getEntitlement } from "../../../../lib/entitlements";

export const runtime = "nodejs";

type PortalBody = {
  returnUrl?: string;
};

export async function POST(request: Request) {
  const auth = await requireAuth(request);
  if (!auth.ok) {
    return auth.response;
  }

  let body: PortalBody = {};
  try {
    const rawBody = await request.text();
    if (rawBody) {
      body = JSON.parse(rawBody) as PortalBody;
    }
  } catch (error) {
    console.error("Invalid portal body:", error);
    return Response.json({ error: "invalid_body" }, { status: 400 });
  }

  const stripeKey = process.env.STRIPE_SECRET_KEY?.trim();
  if (!stripeKey) {
    return Response.json({ error: "stripe_not_configured" }, { status: 501 });
  }

  const defaultAppUrl = process.env.VOX_APP_URL?.trim();
  const returnUrl = body.returnUrl?.trim() || defaultAppUrl;
  if (!returnUrl) {
    return Response.json({ error: "app_url_not_configured" }, { status: 501 });
  }

  const entitlement = await getEntitlement(auth.subject, auth.email);
  if (!entitlement.ok) {
    return Response.json(
      { error: entitlement.error },
      { status: entitlement.statusCode }
    );
  }

  const stripeCustomerId = entitlement.stripeCustomerId?.trim();
  if (!stripeCustomerId) {
    return Response.json({ error: "no_subscription" }, { status: 400 });
  }

  try {
    const stripe = new Stripe(stripeKey);
    const session = await stripe.billingPortal.sessions.create({
      customer: stripeCustomerId,
      return_url: returnUrl,
    });

    if (!session.url) {
      console.error("Stripe portal session missing URL");
      return Response.json({ error: "portal_url_missing" }, { status: 502 });
    }

    return Response.json({ portalUrl: session.url });
  } catch (error) {
    console.error("Stripe portal session failed:", error);
    return Response.json({ error: "stripe_portal_failed" }, { status: 502 });
  }
}
