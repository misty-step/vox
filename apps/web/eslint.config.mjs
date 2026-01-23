import nextPlugin from "eslint-config-next";

const config = [
  ...nextPlugin,
  {
    ignores: [".next/*", "node_modules/*"],
  },
  {
    rules: {
      // Allow setState in useEffect for hydration patterns
      "react-hooks/set-state-in-effect": "off",
    },
  },
];

export default config;
