import { v } from "convex/values";
import { internalMutation, internalQuery, mutation } from "./_generated/server";

export const isEventProcessed = internalQuery({
  args: { eventId: v.string() },
  handler: async (ctx, args) => {
    const existing = await ctx.db
      .query("processedStripeEvents")
      .withIndex("by_event_id", (q) => q.eq("eventId", args.eventId))
      .unique();

    return Boolean(existing);
  },
});

/** Atomically claim a Stripe event for processing. Returns true if successfully claimed, false if already processed. This prevents TOCTOU race conditions with concurrent webhook deliveries. */
export const claimEvent = mutation({
  args: {
    eventId: v.string(),
    eventType: v.string(),
  },
  handler: async (ctx, args) => {
    const existing = await ctx.db
      .query("processedStripeEvents")
      .withIndex("by_event_id", (q) => q.eq("eventId", args.eventId))
      .first();

    if (existing) {
      return false;
    }

    await ctx.db.insert("processedStripeEvents", {
      eventId: args.eventId,
      eventType: args.eventType,
      processedAt: Date.now(),
    });

    return true;
  },
});

export const markEventProcessed = internalMutation({
  args: {
    eventId: v.string(),
    eventType: v.string(),
  },
  handler: async (ctx, args) => {
    return await ctx.db.insert("processedStripeEvents", {
      eventId: args.eventId,
      eventType: args.eventType,
      processedAt: Date.now(),
    });
  },
});
