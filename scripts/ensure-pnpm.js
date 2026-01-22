const userAgent = process.env.npm_config_user_agent ?? "";

if (!userAgent.includes("pnpm/")) {
  // Keep it short; prevent npm/yarn installs.
  console.error("pnpm required (use corepack if needed).");
  process.exit(1);
}
