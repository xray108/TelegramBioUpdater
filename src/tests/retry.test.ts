// src/tests/retry.test.ts
import { withRetries } from '../lib/retry.js';

test('withRetries resolves after transient failures', async () => {
  let attempts = 0;
  const result = await withRetries(
    async () => {
      attempts++;
      if (attempts < 3) throw new Error('transient');
      return 42;
    },
    { retries: 5, baseDelayMs: 1, maxDelayMs: 2 }
  );
  expect(result).toBe(42);
  expect(attempts).toBe(3);
});

test('withRetries respects shouldRetry=false', async () => {
  let attempts = 0;
  await expect(
    withRetries(
      async () => {
        attempts++;
        throw new Error('fatal');
      },
      {
        retries: 5,
        shouldRetry: () => false,
        baseDelayMs: 1,
        maxDelayMs: 2,
      }
    )
  ).rejects.toThrow('fatal');
  expect(attempts).toBe(1);
});
