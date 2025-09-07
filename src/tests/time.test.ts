// src/tests/time.test.ts
import {
  diffMs,
  diffHoursCeil,
  diffDaysFloor,
  toZonedDate,
} from '../lib/time.js';

test('diff calculations are consistent', () => {
  const base = toZonedDate(new Date('2025-01-01T00:00:00Z'));
  const next = toZonedDate(new Date('2025-01-02T03:30:00Z'));

  const ms = diffMs(next, base);
  expect(ms).toBeGreaterThan(0);

  const hours = diffHoursCeil(next, base);
  // 27.5h -> ceil -> 28
  expect(hours).toBe(28);

  const days = diffDaysFloor(next, base);
  // 1.1458d -> floor -> 1
  expect(days).toBe(1);
});
