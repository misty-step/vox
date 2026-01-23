import nextPlugin from "eslint-config-next";

const config = [
  ...nextPlugin,
  {
    ignores: [".next/*", "node_modules/*", "convex/_generated/*"],
  },
];

export default config;
