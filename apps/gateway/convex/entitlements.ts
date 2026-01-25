import { v } from "convex/values";
import { mutation, query } from "./_generated/server";

export const getByUserId = query({
  args: { userId: v.id("users") },
  handler: async (ctx, args) => {
    return await ctx.db
      .query("entitlements")
      .withIndex("by_user_id", (q) => q.eq("userId", args.userId))
      .unique();
  },
});

export const getByStripeCustomer = query({
  args: { stripeCustomerId: v.string() },
  handler: async (ctx, args) => {
    return await ctx.db
      .query("entitlements")
      .withIndex("by_stripe_customer", (q) => q.eq("stripeCustomerId", args.stripeCustomerId))
      .unique();
  },
});

export const getByStripeSubscription = query({
  args: { stripeSubscriptionId: v.string() },
  handler: async (ctx, args) => {
    return await ctx.db
      .query("entitlements")
      .withIndex("by_stripe_subscription", (q) => q.eq("stripeSubscriptionId", args.stripeSubscriptionId))
      .unique();
  },
});

/** Trial duration: 14 days in milliseconds */
const TRIAL_DURATION_MS = 14 * 24 * 60 * 60 * 1000;

export const getOrCreateTrial = mutation({
  args: { userId: v.id("users") },
  handler: async (ctx, args) => {
    const existing = await ctx.db
      .query("entitlements")
      .withIndex("by_user_id", (q) => q.eq("userId", args.userId))
      .unique();

    if (existing) {
      return existing;
    }

    const now = Date.now();
    const entitlementId = await ctx.db.insert("entitlements", {
      userId: args.userId,
      plan: "trial",
      status: "active",
      currentPeriodEnd: now + TRIAL_DURATION_MS,
      createdAt: now,
      updatedAt: now,
    });
    const entitlement = await ctx.db.get(entitlementId);
    if (!entitlement) {
      throw new Error(`Entitlement insert failed for user ${args.userId}`);
    }
    return entitlement;
  },
});

export const activateSubscription = mutation({
  args: {
    userId: v.id("users"),
    stripeCustomerId: v.string(),
    stripeSubscriptionId: v.string(),
    currentPeriodEnd: v.number(),
  },
  handler: async (ctx, args) => {
    const existing = await ctx.db
      .query("entitlements")
      .withIndex("by_user_id", (q) => q.eq("userId", args.userId))
      .unique();

    const now = Date.now();

    if (existing) {
      await ctx.db.patch(existing._id, {
        plan: "pro",
        status: "active",
        stripeCustomerId: args.stripeCustomerId,
        stripeSubscriptionId: args.stripeSubscriptionId,
        currentPeriodEnd: args.currentPeriodEnd,
        updatedAt: now,
      });
      return existing._id;
    }

    return await ctx.db.insert("entitlements", {
      userId: args.userId,
      plan: "pro",
      status: "active",
      stripeCustomerId: args.stripeCustomerId,
      stripeSubscriptionId: args.stripeSubscriptionId,
      currentPeriodEnd: args.currentPeriodEnd,
      createdAt: now,
      updatedAt: now,
    });
  },
});

export const updateSubscription = mutation({
  args: {
    stripeSubscriptionId: v.string(),
    status: v.union(v.literal("active"), v.literal("past_due"), v.literal("cancelled")),
    currentPeriodEnd: v.optional(v.number()),
  },
  handler: async (ctx, args) => {
    const entitlement = await ctx.db
      .query("entitlements")
      .withIndex("by_stripe_subscription", (q) => q.eq("stripeSubscriptionId", args.stripeSubscriptionId))
      .unique();

    if (!entitlement) {
      throw new Error(`No entitlement found for subscription ${args.stripeSubscriptionId}`);
    }

    await ctx.db.patch(entitlement._id, {
      status: args.status,
      plan: args.status === "cancelled" ? "cancelled" : entitlement.plan,
      ...(args.currentPeriodEnd && { currentPeriodEnd: args.currentPeriodEnd }),
      updatedAt: Date.now(),
    });

    return entitlement._id;
  },
});

export const cancelSubscription = mutation({
  args: { stripeSubscriptionId: v.string() },
  handler: async (ctx, args) => {
    const entitlement = await ctx.db
      .query("entitlements")
      .withIndex("by_stripe_subscription", (q) => q.eq("stripeSubscriptionId", args.stripeSubscriptionId))
      .unique();

    if (!entitlement) {
      throw new Error(`No entitlement found for subscription ${args.stripeSubscriptionId}`);
    }

    await ctx.db.patch(entitlement._id, {
      plan: "cancelled",
      status: "cancelled",
      updatedAt: Date.now(),
    });

    return entitlement._id;
  },
});

/**
 * One-time migration: backfill currentPeriodEnd for existing trials.
 * Sets expiration to createdAt + 14 days.
 * Run via: npx convex run entitlements:migrateTrialExpirations
 */
export const migrateTrialExpirations = mutation({
  args: {},
  handler: async (ctx) => {
    const trials = await ctx.db
      .query("entitlements")
      .filter((q) => q.eq(q.field("plan"), "trial"))
      .collect();

    let migrated = 0;
    for (const trial of trials) {
      if (trial.currentPeriodEnd === undefined) {
        await ctx.db.patch(trial._id, {
          currentPeriodEnd: trial.createdAt + TRIAL_DURATION_MS,
          updatedAt: Date.now(),
        });
        migrated++;
      }
    }

    return { total: trials.length, migrated };
  },
});
