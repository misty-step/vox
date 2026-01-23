import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    environment: "node",
    include: ["**/*.test.ts"],
    coverage: {
      provider: "v8",
      reporter: ["text", "json", "html"],
      include: ["app/**/*.ts", "lib/**/*.ts"],
      exclude: ["**/*.test.ts", "**/node_modules/**"],
    },
    setupFiles: ["./test/setup.ts"],
  },
});
