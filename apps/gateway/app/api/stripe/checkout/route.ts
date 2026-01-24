import Stripe from "stripe";
import { requireAuth } from "../../../../lib/auth";
import { getEntitlement } from "../../../../lib/entitlements";

export const runtime = "nodejs";

type CheckoutBody = {
  priceId?: string;
  successUrl?: string;
  cancelUrl?: string;
};

export async function POST(request: Request) {
  const auth = await requireAuth(request);
  if (!auth.ok) {
    return auth.response;
  }

  let body: CheckoutBody = {};
  try {
    const rawBody = await request.text();
    if (rawBody) {
      body = JSON.parse(rawBody) as CheckoutBody;
    }
  } catch (error) {
    console.error("Invalid checkout body:", error);
    return Response.json({ error: "invalid_body" }, { status: 400 });
  }

  const stripeKey = process.env.STRIPE_SECRET_KEY?.trim();
  if (!stripeKey) {
    return Response.json({ error: "stripe_not_configured" }, { status: 501 });
  }

  const defaultPriceId = process.env.STRIPE_PRICE_ID?.trim();
  const priceId = body.priceId?.trim() || defaultPriceId;
  if (!priceId) {
    return Response.json({ error: "price_not_configured" }, { status: 501 });
  }

  const defaultAppUrl = process.env.VOX_APP_URL?.trim();
  const successUrl = body.successUrl?.trim() || defaultAppUrl;
  const cancelUrl = body.cancelUrl?.trim() || defaultAppUrl;
  if (!successUrl || !cancelUrl) {
    return Response.json({ error: "app_url_not_configured" }, { status: 501 });
  }

  const entitlement = await getEntitlement(auth.subject, auth.email);
  if (!entitlement.ok) {
    return Response.json(
      { error: entitlement.error },
      { status: entitlement.statusCode }
    );
  }

  let trialEnd: number | undefined;
  if (entitlement.plan === "trial" && entitlement.status === "active") {
    const candidate = entitlement.currentPeriodEnd;
    if (candidate && candidate > Date.now()) {
      trialEnd = Math.floor(candidate / 1000);
    }
  }

  try {
    const stripe = new Stripe(stripeKey);
    const session = await stripe.checkout.sessions.create({
      mode: "subscription",
      line_items: [{ price: priceId, quantity: 1 }],
      client_reference_id: auth.subject,
      success_url: successUrl,
      cancel_url: cancelUrl,
      ...(trialEnd ? { subscription_data: { trial_end: trialEnd } } : {}),
    });

    if (!session.url) {
      console.error("Stripe checkout session missing URL");
      return Response.json({ error: "checkout_url_missing" }, { status: 502 });
    }

    return Response.json({ checkoutUrl: session.url });
  } catch (error) {
    console.error("Stripe checkout session failed:", error);
    return Response.json({ error: "stripe_checkout_failed" }, { status: 502 });
  }
}
