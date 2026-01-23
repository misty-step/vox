import Stripe from "stripe";
import { getConvexClient, api } from "../../../../lib/convex";

export const runtime = "nodejs";

function getStripeClient(): Stripe {
  const key = process.env.STRIPE_SECRET_KEY;
  if (!key) {
    throw new Error("STRIPE_SECRET_KEY not configured");
  }
  return new Stripe(key);
}

export async function POST(request: Request) {
  const signature = request.headers.get("stripe-signature");
  if (!signature) {
    return Response.json({ error: "missing_signature" }, { status: 400 });
  }

  const webhookSecret = process.env.STRIPE_WEBHOOK_SECRET;
  if (!webhookSecret) {
    console.error("STRIPE_WEBHOOK_SECRET not configured");
    return Response.json({ error: "webhook_not_configured" }, { status: 501 });
  }

  const body = await request.text();
  if (!body) {
    return Response.json({ error: "empty_body" }, { status: 400 });
  }

  let event: Stripe.Event;
  try {
    event = getStripeClient().webhooks.constructEvent(body, signature, webhookSecret);
  } catch (err) {
    console.error("Webhook signature verification failed:", err);
    return Response.json({ error: "invalid_signature" }, { status: 400 });
  }

  const convex = getConvexClient();

  try {
    switch (event.type) {
      case "checkout.session.completed": {
        const session = event.data.object as Stripe.Checkout.Session;
        await handleCheckoutCompleted(convex, session);
        break;
      }

      case "customer.subscription.created":
      case "customer.subscription.updated": {
        const subscription = event.data.object as Stripe.Subscription;
        await handleSubscriptionUpdate(convex, subscription);
        break;
      }

      case "customer.subscription.deleted": {
        const subscription = event.data.object as Stripe.Subscription;
        await handleSubscriptionDeleted(convex, subscription);
        break;
      }

      default:
        console.log(`Unhandled event type: ${event.type}`);
    }
  } catch (err) {
    console.error(`Error handling ${event.type}:`, err);
    return Response.json({ error: "handler_failed" }, { status: 500 });
  }

  return Response.json({ received: true });
}

async function handleCheckoutCompleted(
  convex: ReturnType<typeof getConvexClient>,
  session: Stripe.Checkout.Session
) {
  const clerkId = session.client_reference_id;
  if (!clerkId) {
    console.error("No client_reference_id in checkout session");
    return;
  }

  const customerId = session.customer as string;
  const subscriptionId = session.subscription as string;

  if (!subscriptionId) {
    console.log("No subscription in checkout session (one-time payment?)");
    return;
  }

  // Get subscription details for period end
  const subscription = await getStripeClient().subscriptions.retrieve(subscriptionId);

  // Get or create user
  const userId = await convex.mutation(api.users.getOrCreate, {
    clerkId,
    email: session.customer_email || undefined,
  });

  // Activate subscription
  await convex.mutation(api.entitlements.activateSubscription, {
    userId,
    stripeCustomerId: customerId,
    stripeSubscriptionId: subscriptionId,
    currentPeriodEnd: subscription.current_period_end * 1000,
  });

  console.log(`Activated subscription for user ${clerkId}`);
}

async function handleSubscriptionUpdate(
  convex: ReturnType<typeof getConvexClient>,
  subscription: Stripe.Subscription
) {
  const status = mapSubscriptionStatus(subscription.status);

  try {
    await convex.mutation(api.entitlements.updateSubscription, {
      stripeSubscriptionId: subscription.id,
      status,
      currentPeriodEnd: subscription.current_period_end * 1000,
    });
    console.log(`Updated subscription ${subscription.id} to ${status}`);
  } catch (err) {
    // Subscription might not exist yet if this fires before checkout.session.completed
    console.log(`Could not update subscription ${subscription.id}:`, err);
  }
}

async function handleSubscriptionDeleted(
  convex: ReturnType<typeof getConvexClient>,
  subscription: Stripe.Subscription
) {
  try {
    await convex.mutation(api.entitlements.cancelSubscription, {
      stripeSubscriptionId: subscription.id,
    });
    console.log(`Cancelled subscription ${subscription.id}`);
  } catch (err) {
    console.error(`Could not cancel subscription ${subscription.id}:`, err);
  }
}

function mapSubscriptionStatus(
  stripeStatus: Stripe.Subscription.Status
): "active" | "past_due" | "cancelled" {
  switch (stripeStatus) {
    case "active":
    case "trialing":
      return "active";
    case "past_due":
      return "past_due";
    default:
      return "cancelled";
  }
}
