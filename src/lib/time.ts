// src/lib/time.ts
import { toZonedTime, format } from 'date-fns-tz';
import { ru } from 'date-fns/locale/ru';

export const TIMEZONE: string = process.env.TZ_OVERRIDE || 'Europe/Moscow';
const LOCALE: string = 'ru-RU';
const DATE_FNS_LOCALE = ru;

export function nowZoned(): Date {
  return toZonedDate(new Date()); // Используем toZonedDate для избежания дублирования
}

export function toZonedDate(
  date: Date = new Date(),
  timeZone: string = TIMEZONE
): Date {
  return toZonedTime(date, timeZone);
}

export interface FormatDateTimeOptions {
  dateStyle?: 'full' | 'long' | 'medium' | 'short';
  timeStyle?: 'full' | 'long' | 'medium' | 'short';
  timeZone?: string;
  locale?: string;
}

export function formatDateTime(
  date: Date = nowZoned(),
  opts: FormatDateTimeOptions = {}
): string {
  const {
    dateStyle = 'medium',
    timeStyle = 'medium',
    timeZone = TIMEZONE,
    locale = LOCALE,
  } = opts;
  return new Intl.DateTimeFormat(locale, {
    dateStyle,
    timeStyle,
    timeZone,
  }).format(date);
}

// Уточнение formatStamp с использованием Intl.DateTimeFormat
export function formatStamp(
  date: Date = nowZoned(),
  timeZone: string = TIMEZONE,
  locale: string = LOCALE
): string {
  // ISO-подобная метка для логов
  return new Intl.DateTimeFormat(locale, {
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
    timeZone: timeZone,
  })
    .format(date)
    .replace(/,/g, '');
  // Пример вывода: "01.01.2025 12:00:00"
}

export function getZonedDayOfWeek(
  date: Date = nowZoned(),
  timeZone: string = TIMEZONE
): number {
  return toZonedDate(date, timeZone).getDay(); // 0..6
}

export function diffMs(targetDate: Date, baseDate: Date = nowZoned()): number {
  return targetDate.getTime() - baseDate.getTime();
}
export function diffHoursCeil(
  targetDate: Date,
  baseDate: Date = nowZoned()
): number {
  return Math.ceil(diffMs(targetDate, baseDate) / (1000 * 60 * 60));
}
export function diffDaysFloor(
  targetDate: Date,
  baseDate: Date = nowZoned()
): number {
  return Math.floor(diffMs(targetDate, baseDate) / (1000 * 60 * 60 * 24));
}
