// src/lib/retry.ts
const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

// Универсальная обёртка с экспоненциальной задержкой и jitter.
// Добавлен maxTotalMs — ограничение общей длительности.
export async function withRetries<T>(
  fn: () => Promise<T>,
  {
    retries = 3,
    baseDelayMs = 1000,
    maxDelayMs = 30_000,
    maxTotalMs = Infinity,
    onError = null,
    shouldRetry = null,
    beforeRetry = null,
  }: {
    retries?: number;
    baseDelayMs?: number;
    maxDelayMs?: number;
    maxTotalMs?: number;
    onError?: ((err: unknown, attempt: number) => void) | null;
    shouldRetry?: ((err: unknown, attempt: number) => boolean) | null;
    beforeRetry?: ((err: unknown, attempt: number) => Promise<void>) | null;
  } = {}
): Promise<T> {
  let attempt = 0;
  let lastErr: unknown;
  const startedAt = Date.now();
  const totalAttempts = retries + 1;

  while (attempt < totalAttempts) {
    try {
      return await fn();
    } catch (err) {
      lastErr = err;
      if (onError) {
        try {
          onError(err, attempt);
        } catch {}
      }

      const allow = shouldRetry ? shouldRetry(err, attempt) : true;
      const nextAttempt = attempt + 1;
      const totalElapsed = Date.now() - startedAt;

      if (
        !allow ||
        nextAttempt >= totalAttempts ||
        totalElapsed >= maxTotalMs
      ) {
        break;
      }

      const expo = Math.min(maxDelayMs, baseDelayMs * Math.pow(2, attempt));
      const jitter = Math.floor(Math.random() * (expo / 2));
      const delay = expo + jitter;

      if (beforeRetry) {
        try {
          await beforeRetry(err, attempt);
        } catch {}
      }
      // Можно логировать в onError: `Попытка ${nextAttempt + 1} из ${totalAttempts}`
      await sleep(delay);
      attempt = nextAttempt;
    }
  }
  throw lastErr;
}
