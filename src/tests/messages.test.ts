// src/tests/messages.test.ts
import { plural, generateMessage } from '../lib/messages.js';

test('plural works for Russian', () => {
  expect(plural(1, 'день', 'дня', 'дней')).toBe('день');
  expect(plural(2, 'день', 'дня', 'дней')).toBe('дня');
  expect(plural(5, 'день', 'дня', 'дней')).toBe('дней');
  expect(plural(21, 'день', 'дня', 'дней')).toBe('день');
});

test('generateMessage returns string for future date', () => {
  const future = new Date(Date.now() + 10 * 24 * 60 * 60 * 1000);
  const msg = generateMessage(future);
  expect(typeof msg).toBe('string');
  expect(msg.length).toBeGreaterThan(0);
});

test('generateMessage handles past date', () => {
  const past = new Date(Date.now() - 3 * 24 * 60 * 60 * 1000);
  const msg = generateMessage(past);
  expect(msg).toMatch(/день|дня|дней/);
});
