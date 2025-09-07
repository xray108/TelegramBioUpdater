// src/config/env.ts
import dotenv from 'dotenv';
import { z } from 'zod';
import { logApp } from '../lib/logger.js';

dotenv.config();

// Помогаем Zod понять, что transform(Number) даёт number, а не string
const numericString = z.string().regex(/^\d+$/).transform(Number);

const envSchema = z.object({
  API_ID: numericString,
  API_HASH: z.string(),
  OPENWEATHER_API_KEY: z.string(),
  LAT: z
    .string()
    .regex(/^-?\d+(\.\d+)?$/)
    .transform(Number),
  LON: z
    .string()
    .regex(/^-?\d+(\.\d+)?$/)
    .transform(Number),
  TARGET_DATETIME: z.string().datetime(), // Останется строкой, преобразуем позже
  SESSION_STRING: z.string().optional().default(''),
  TZ_OVERRIDE: z.string().optional(),
  // Явно указываем тип после transform
  UPDATE_INTERVAL_MS: numericString.default(3600000), // 1 hour
  LOG_MAX_BYTES: numericString.default(1000000), // 1 MB
  LOG_BACKUPS: numericString.default(5),
  // Добавляем недостающие поля конфигурации
  WEATHER_CACHE_MS: numericString.default(3 * 60 * 60 * 1000), // 3 hours
  WEATHER_TIMEOUT_MS: numericString.default(10000), // 10 seconds
});

// Тип для retry конфигурации
export interface RetryConfig {
  retries: number;
  baseDelayMs: number;
  maxDelayMs: number;
  maxTotalMs: number;
}

export type Config = z.infer<typeof envSchema> & {
  // Добавляем поля, которые вычисляются или добавляются после валидации
  TARGET_DATE: Date; // Преобразованная дата
  bioMaxLength: number;
  retry: RetryConfig;
};

export function loadConfig(): Config {
  try {
    const parsed = envSchema.safeParse(process.env);
    if (!parsed.success) {
      // Исправляем доступ к ошибке валидации
      const errorMessages = parsed.error.issues
        .map((e) => `${e.path.join('.')}: ${e.message}`)
        .join(', ');
      logApp(`❌ Ошибка конфигурации: ${errorMessages}`);
      process.exit(1);
    }

    // Преобразуем и добавляем недостающие поля
    const baseConfig = parsed.data;
    const fullConfig: Config = {
      ...baseConfig,
      TARGET_DATE: new Date(baseConfig.TARGET_DATETIME),
      bioMaxLength: 140,
      retry: {
        retries: 5,
        baseDelayMs: 1500,
        maxDelayMs: 45_000,
        maxTotalMs: 5 * 60 * 1000,
      },
      // weatherCacheMs и weatherTimeoutMs уже есть благодаря WEATHER_CACHE_MS и WEATHER_TIMEOUT_MS
    };

    logApp('✅ Все переменные .env валидны');
    return fullConfig;
  } catch (err) {
    logApp(`❌ Неожиданная ошибка конфигурации: ${(err as Error).message}`);
    process.exit(1);
  }
}
