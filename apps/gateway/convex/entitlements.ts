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

export const createTrial = mutation({
  args: { userId: v.id("users") },
  handler: async (ctx, args) => {
    const existing = await ctx.db
      .query("entitlements")
      .withIndex("by_user_id", (q) => q.eq("userId", args.userId))
      .unique();

    if (existing) {
      return existing._id;
    }

    return await ctx.db.insert("entitlements", {
      userId: args.userId,
      plan: "trial",
      status: "active",
      createdAt: Date.now(),
      updatedAt: Date.now(),
    });
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
