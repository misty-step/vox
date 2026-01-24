import Stripe from "stripe";

type StripeRouteErrorCode = "stripe_not_configured" | "app_url_not_configured";

type StripeRouteError = Error & { code: StripeRouteErrorCode };

function stripeRouteError(code: StripeRouteErrorCode, message: string): StripeRouteError {
  const error = new Error(message) as StripeRouteError;
  error.code = code;
  return error;
}

export function getStripeConfig(): { stripe: Stripe; appOrigin: string } {
  const stripeKey = process.env.STRIPE_SECRET_KEY?.trim();
  if (!stripeKey) {
    throw stripeRouteError(
      "stripe_not_configured",
      "STRIPE_SECRET_KEY not configured"
    );
  }

  const appUrl = process.env.VOX_APP_URL?.trim();
  if (!appUrl) {
    throw stripeRouteError("app_url_not_configured", "VOX_APP_URL not configured");
  }

  let appOrigin: string;
  try {
    appOrigin = new URL(appUrl).origin;
  } catch {
    throw stripeRouteError("app_url_not_configured", "VOX_APP_URL invalid");
  }

  return { stripe: new Stripe(stripeKey), appOrigin };
}

export function validateRedirectUrl(
  url: string | undefined,
  appOrigin: string
): string | null {
  const candidate = url?.trim();
  if (!candidate) {
    return null;
  }

  try {
    return new URL(candidate).origin === appOrigin ? candidate : null;
  } catch {
    return null;
  }
}
