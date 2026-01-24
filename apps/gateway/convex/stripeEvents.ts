import { v } from "convex/values";
import { mutation, query } from "./_generated/server";

export const isEventProcessed = query({
  args: { eventId: v.string() },
  handler: async (ctx, args) => {
    const existing = await ctx.db
      .query("processedStripeEvents")
      .withIndex("by_event_id", (q) => q.eq("eventId", args.eventId))
      .unique();

    return Boolean(existing);
  },
});

export const markEventProcessed = mutation({
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
