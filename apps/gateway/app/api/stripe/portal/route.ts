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
  if (!defaultAppUrl) {
    return Response.json({ error: "app_url_not_configured" }, { status: 501 });
  }

  let appOrigin: string;
  try {
    appOrigin = new URL(defaultAppUrl).origin;
  } catch (error) {
    console.error("Invalid VOX_APP_URL:", error);
    return Response.json({ error: "app_url_not_configured" }, { status: 501 });
  }

  const returnUrl = body.returnUrl?.trim() || defaultAppUrl;
  if (!returnUrl || !isAllowedRedirectUrl(returnUrl, appOrigin)) {
    return Response.json({ error: "invalid_return_url" }, { status: 400 });
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

function isAllowedRedirectUrl(candidate: string, appOrigin: string) {
  try {
    return new URL(candidate).origin === appOrigin;
  } catch {
    return false;
  }
}
