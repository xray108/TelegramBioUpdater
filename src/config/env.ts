// src/config/env.ts
import dotenv from 'dotenv';
import { z } from 'zod';
import { logApp } from '../lib/logger.js';

dotenv.config();

// Помогаем Zod понять, что transform(Number) даёт number
const numericString = z.string().regex(/^\d+$/).transform(Number);

// Вспомогательная функция для проверки даты
const isValidISODate = (str: string): boolean => {
  const date = new Date(str);
  return !isNaN(date.getTime());
};

const envSchema = z.object({
  API_ID: numericString,
  API_HASH: z.string(),
  OPENWEATHER_API_KEY: z.string(),
  LAT: z.string().regex(/^-?\d+(\.\d+)?$/).transform(Number),
  LON: z.string().regex(/^-?\d+(\.\d+)?$/).transform(Number),
  // Используем refine для поддержки строк без временной зоны
  TARGET_DATETIME: z.string().refine(
    (str) => isValidISODate(str),
    { message: "Must be a valid ISO 8601 datetime string (e.g., '2025-11-04T16:30:00')" }
  ),
  SESSION_STRING: z.string().optional().default(''),
  TZ_OVERRIDE: z.string().optional(),
  UPDATE_INTERVAL_MS: numericString.default(3600000),
  WEATHER_CACHE_MS: numericString.default(3 * 60 * 60 * 1000),
  WEATHER_TIMEOUT_MS: numericString.default(10000),
});

// Тип для retry конфигурации
export interface RetryConfig {
  retries: number;
  baseDelayMs: number;
  maxDelayMs: number;
  maxTotalMs: number;
}

export type Config = z.infer<typeof envSchema> & {
  TARGET_DATE: Date;
  bioMaxLength: number;
  retry: RetryConfig;
  resetHour: number;
  resetMinute: number;
};

export function loadConfig(): Config {
  try {
    const parsed = envSchema.safeParse(process.env);
    if (!parsed.success) {
      const errorMessages = parsed.error.issues.map(e => `${e.path.join('.')}: ${e.message}`).join(', ');
      logApp(`❌ Ошибка конфигурации: ${errorMessages}`);
      process.exit(1);
    }

    const baseConfig = parsed.data;
    const targetDate = new Date(baseConfig.TARGET_DATETIME);
    const fullConfig: Config = {
      ...baseConfig,
      TARGET_DATE: targetDate,
      bioMaxLength: 140,
      retry: {
        retries: 5,
        baseDelayMs: 1500,
        maxDelayMs: 45_000,
        maxTotalMs: 5 * 60 * 1000,
      },
      resetHour: targetDate.getHours(),
      resetMinute: targetDate.getMinutes(),
    };

    logApp('✅ Все переменные .env валидны');
    return fullConfig;
  } catch (err) {
    logApp(`❌ Неожиданная ошибка конфигурации: ${(err as Error).message}`);
    process.exit(1);
  }
}