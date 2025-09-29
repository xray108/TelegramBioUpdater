// src/lib/messages.ts
import { nowZoned, diffMs, diffHoursCeil, diffDaysFloor } from './time.js';
import { Localization, DEFAULT_LOCALIZATION } from '../config/messages.js';

let currentLocalization: Localization = DEFAULT_LOCALIZATION;

export function setLocalization(loc: Localization) {
  currentLocalization = loc;
}

export function plural(n: number, one: string, two: string, many: string): string {
  return currentLocalization.plurals(n, one, two, many);
}

function rnd(arr: string[]): string {
  return arr[Math.floor(Math.random() * arr.length)];
}

function interpolate(template: string, params: Record<string, any>): string {
  return template.replace(/\{(\w+)\}/g, (_, key) => params[key]);
}

export function generateMessage(TARGET_DATE: Date, base: Date = nowZoned()): string {
  const diff = diffMs(TARGET_DATE, base);

  if (diff < 0) {
    const daysAgo = Math.ceil(Math.abs(diff) / (1000 * 60 * 60 * 24));
    const dayText = plural(daysAgo, 'день', 'дня', 'дней');
    const messageTemplate = rnd(currentLocalization.messages.PAST_PREFIX);
    return interpolate(messageTemplate, { days: daysAgo, dayText });
  }

  const days = diffDaysFloor(TARGET_DATE, base);
  const hoursTotal = diffHoursCeil(TARGET_DATE, base);

  if (currentLocalization.milestones[days]) {
    return rnd(currentLocalization.milestones[days]);
  }

  if (days === 0) {
    if (hoursTotal <= 24) {
      const hourText = plural(hoursTotal, 'час', 'часа', 'часов');
      const messageTemplate = rnd(currentLocalization.messages.HOURS_TODAY);
      return interpolate(messageTemplate, { hoursTotal, hourText });
    }
    return rnd(currentLocalization.messages.TODAY);
  }

  const dayText = plural(days, 'день', 'дня', 'дней');

  if (days >= 120) return rnd(currentLocalization.messages.FUTURE_PREFIX);
  if (days >= 90) {
    const messageTemplate = rnd(currentLocalization.messages.QUARTER);
    return interpolate(messageTemplate, { days, dayText });
  }
  if (days >= 60) {
    const messageTemplate = rnd(currentLocalization.messages.TWO_MONTHS);
    return interpolate(messageTemplate, { days, dayText });
  }
  if (days >= 30) {
    const messageTemplate = rnd(currentLocalization.messages.MONTH);
    return interpolate(messageTemplate, { days, dayText });
  }
  if (days >= 14) {
    const messageTemplate = rnd(currentLocalization.messages.TWO_WEEKS);
    return interpolate(messageTemplate, { days, dayText });
  }
  if (days >= 7) {
    const messageTemplate = rnd(currentLocalization.messages.WEEK);
    return interpolate(messageTemplate, { days, dayText });
  }
  if (days > 0) {
    const messageTemplate = rnd(currentLocalization.messages.DAYS_LEFT);
    return interpolate(messageTemplate, { days, dayText });
  }

  const hourText = plural(hoursTotal, 'час', 'часа', 'часов');
  const messageTemplate = rnd(currentLocalization.messages.HOURS_LEFT);
  return interpolate(messageTemplate, { hoursTotal, hourText });
}