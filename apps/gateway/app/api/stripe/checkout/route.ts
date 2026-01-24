import { requireAuth } from "../../../../lib/auth";
import { getEntitlement } from "../../../../lib/entitlements";
import {
  getStripeConfig,
  validateRedirectUrl,
} from "../../../../lib/stripe-route";

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

  const defaultPriceId = process.env.STRIPE_PRICE_ID?.trim();
  if (!defaultPriceId) {
    return Response.json({ error: "price_not_configured" }, { status: 501 });
  }

  const clientPriceId = body.priceId?.trim();
  if (clientPriceId && clientPriceId !== defaultPriceId) {
    return Response.json({ error: "invalid_price_id" }, { status: 400 });
  }

  let stripe: ReturnType<typeof getStripeConfig>["stripe"];
  let appOrigin: string;
  try {
    ({ stripe, appOrigin } = getStripeConfig());
  } catch (error) {
    const response = stripeConfigErrorResponse(error);
    if (response) {
      return response;
    }
    throw error;
  }

  const defaultAppUrl = process.env.VOX_APP_URL!.trim();
  const successCandidate = body.successUrl;
  const cancelCandidate = body.cancelUrl;
  const successUrl = successCandidate?.trim()
    ? validateRedirectUrl(successCandidate, appOrigin)
    : defaultAppUrl;
  const cancelUrl = cancelCandidate?.trim()
    ? validateRedirectUrl(cancelCandidate, appOrigin)
    : defaultAppUrl;
  if (!successUrl || !cancelUrl) {
    return Response.json({ error: "invalid_redirect_url" }, { status: 400 });
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
    const session = await stripe.checkout.sessions.create({
      mode: "subscription",
      line_items: [{ price: defaultPriceId, quantity: 1 }],
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

function stripeConfigErrorResponse(error: unknown): Response | null {
  const code =
    typeof error === "object" && error && "code" in error
      ? (error as { code?: string }).code
      : undefined;
  if (code === "stripe_not_configured" || code === "app_url_not_configured") {
    return Response.json({ error: code }, { status: 501 });
  }
  return null;
}
