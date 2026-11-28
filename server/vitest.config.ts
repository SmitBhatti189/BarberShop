import { existsSync } from 'node:fs';
import { defineConfig } from 'vitest/config';

if (existsSync('.env')) process.loadEnvFile('.env');

export default defineConfig({
  test: {
    include: ['test/**/*.test.ts'],
    // Database-backed suites share one test database; run files one at a time.
    fileParallelism: false,
    // Generous: each file rebuilds the test database, which takes well over
    // 30 s on the salon PC when it is also busy (e.g. a Flutter build).
    testTimeout: 30_000,
    hookTimeout: 120_000,
  },
});
