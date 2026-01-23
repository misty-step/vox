import { ConvexHttpClient } from "convex/browser";
import { api } from "../convex/_generated/api";

let client: ConvexHttpClient | null = null;

export function getConvexClient(): ConvexHttpClient {
  if (!client) {
    const url = process.env.CONVEX_URL;
    if (!url) {
      throw new Error("CONVEX_URL not configured");
    }
    client = new ConvexHttpClient(url);
  }
  return client;
}

export { api };
