#!/bin/bash

# Скрипт установки и настройки проекта tg-bio на Debian 12
# Запуск: ./setup-tg-bio.sh

set -e # Завершить скрипт при ошибке

echo "=== Начало установки проекта tg-bio ==="

# --- 1. Проверка и установка зависимостей системы ---
echo "1. Проверка и установка системных зависимостей..."

# Обновление списка пакетов (опционально, но рекомендуется)
# sudo apt update

# Проверка и установка curl (для установки Node.js)
if ! command -v curl &> /dev/null; then
    echo "  Установка curl..."
    sudo apt install -y curl
else
    echo "  curl уже установлен."
fi

# Проверка и установка Node.js (рекомендуемая версия >= 18)
# Используем установку через NodeSource для получения актуальной версии
if ! command -v node &> /dev/null || [[ $(node -v | cut -d'.' -f1 | sed 's/v//') -lt 18 ]]; then
    echo "  Установка Node.js (версия 20)..."
    # Установка NodeSource setup script
    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
    # Установка Node.js
    sudo apt install -y nodejs
else
    echo "  Node.js >= 18 уже установлен ($(node -v))."
fi

# Проверка и установка Git (для клонирования, если потребуется, и общего использования)
if ! command -v git &> /dev/null; then
    echo "  Установка git..."
    sudo apt install -y git
else
    echo "  git уже установлен."
fi

echo "  Системные зависимости установлены."

# --- 2. Инициализация проекта Node.js ---
echo "2. Инициализация проекта Node.js..."
# Инициализируем package.json, если его нет, или просто устанавливаем зависимости
if [[ ! -f "package.json" ]]; then
    echo "  Создание package.json..."
    npm init -y
fi

# --- 3. Установка зависимостей проекта ---
echo "3. Установка зависимостей проекта..."
echo "  Установка основных зависимостей..."
npm install date-fns date-fns-tz dotenv telegram zod

echo "  Установка зависимостей для разработки (TypeScript, ESLint, Prettier, Jest)..."
npm install --save-dev typescript @types/node @types/jest eslint @typescript-eslint/eslint-plugin @typescript-eslint/parser prettier eslint-config-prettier eslint-plugin-prettier jest ts-jest

# --- 4. Создание структуры каталогов ---
echo "4. Создание структуры каталогов..."
mkdir -p src/config src/lib src/tests logs dist

# --- 5. Создание/Перезапись файлов конфигурации ---
echo "5. Создание файлов конфигурации..."

# --- tsconfig.json ---
cat > tsconfig.json << 'EOF'
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "NodeNext",
    "moduleResolution": "NodeNext",
    "outDir": "./dist",
    "rootDir": "./src",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "resolveJsonModule": true,
    "declaration": true
  },
  "include": [
    "src/**/*"
  ],
  "exclude": [
    "node_modules",
    "dist"
  ]
}
EOF
echo "  Создан tsconfig.json"

# --- jest.config.js ---
cat > jest.config.js << 'EOF'
// jest.config.js
export default {
  preset: 'ts-jest/presets/default-esm',
  testEnvironment: 'node',
  roots: ['<rootDir>/src'],
  testMatch: ['**/*.test.ts'],
  moduleNameMapper: {
    '^(\\.{1,2}/.*)\\.js$': '$1',
  },
  extensionsToTreatAsEsm: ['.ts'],
  transform: {
    '^.+\\.tsx?$': [
      'ts-jest',
      {
        useESM: true,
      },
    ],
  },
};
EOF
echo "  Создан jest.config.js"

# --- .eslintrc.cjs ---
cat > .eslintrc.cjs << 'EOF'
module.exports = {
  parser: '@typescript-eslint/parser',
  extends: [
    'eslint:recommended',
    'plugin:@typescript-eslint/recommended',
    'prettier', // Должен быть последним
  ],
  plugins: ['@typescript-eslint', 'prettier'],
  parserOptions: {
    ecmaVersion: 2022,
    sourceType: 'module',
  },
  env: {
    es2022: true,
    node: true,
    jest: true,
  },
  rules: {
    'prettier/prettier': 'error',
    // Добавьте или переопределите правила здесь
    '@typescript-eslint/no-unused-vars': ['error', { argsIgnorePattern: '^_' }],
    '@typescript-eslint/no-explicit-any': 'warn',
    // Избегаем дублирования импортов
    'no-duplicate-imports': 'error',
  },
  overrides: [
    {
      files: ['*.js'],
      rules: {
        '@typescript-eslint/no-var-requires': 'off',
      },
    },
  ],
};
EOF
echo "  Создан .eslintrc.cjs"

# --- .prettierrc ---
cat > .prettierrc << 'EOF'
{
  "semi": true,
  "trailingComma": "es5",
  "singleQuote": true,
  "printWidth": 80,
  "tabWidth": 2,
  "useTabs": false
}
EOF
echo "  Создан .prettierrc"

# --- .env.example ---
cat > .env.example << 'EOF'
API_ID=123456
API_HASH=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
SESSION_STRING=
OPENWEATHER_API_KEY=owm_xxxxx
LAT=12.9352
LON=100.8687
TARGET_DATETIME=2025-11-04T16:30:00

# Опции
TZ_OVERRIDE=Europe/Moscow
UPDATE_INTERVAL_MS=3600000
LOG_MAX_BYTES=1000000
LOG_BACKUPS=5
EOF
echo "  Создан .env.example"

# --- 6. Создание исходных файлов TypeScript ---
echo "6. Создание исходных файлов TypeScript..."

# --- src/config/messages.ts ---
mkdir -p src/config
cat > src/config/messages.ts << 'EOF'
// src/config/messages.ts
export interface MessageConfig {
  [key: string]: string[]; // Ключ - идентификатор или число дней, значение - массив сообщений
}

export interface Localization {
  locale: string;
  plurals: (n: number, one: string, two: string, many: string) => string;
  messages: MessageConfig;
  milestones: { [key: number]: string[] }; // Специальные сообщения для ключевых дней
}

export const DEFAULT_LOCALIZATION: Localization = {
  locale: 'ru-RU',
  plurals: (n: number, one: string, two: string, many: string): string => {
    const num = Math.abs(n);
    if (num % 10 === 1 && num % 100 !== 11) return one;
    if (num % 10 >= 2 && num % 10 <= 4 && (num % 100 < 10 || num % 100 >= 20)) return two;
    return many;
  },
  messages: {
    PAST_PREFIX: [
      'Отпуск был {days} {dayText} назад… 😢',
      'Уже {days} {dayText} после отпуска. Воспоминания греют!',
      'Прошло {days} {dayText} с отпуска. Когда следующий?',
      'Погружаюсь в фото — {days} {dayText} после рая 📸',
    ],
    FUTURE_PREFIX: [
      '🌍 Мечтаю о море… 120+ дней осталось',
      'Ещё далеко, но отпуск ждёт! ⏳',
    ],
    QUARTER: [
      '⏳ Квартал ожидания — {days} {dayText}',
      '{days} {dayText} до тропиков — держусь!',
    ],
    TWO_MONTHS: [
      '📆 Два месяца+ — {days} {dayText}',
      '{days} {dayText} — и я в тропиках! 🏝️',
    ],
    MONTH: [
      '📅 Месяц+ — {days} {dayText}',
      '{days} {dayText} до солнца и моря! ☀️',
    ],
    TWO_WEEKS: [
      '🌴 Две недели+ — {days} {dayText}',
      '{days} {dayText} — отпуск на подходе! 🚀',
    ],
    WEEK: [
      '✈️ Неделя+ — {days} {dayText}',
      '{days} {dayText} — и я в раю! 🏖️',
    ],
    DAYS_LEFT: [
      '🔥 Осталось {days} {dayText}',
      'Ещё {days} {dayText} до приключений! 🌴',
      '{days} {dayText} countdown! ⏰',
    ],
    TODAY: ['✈️ Сегодня — отпуск! Вперёд!', 'День отпуска настал! 🌞'],
    HOURS_LEFT: [
      '⏰ Почти там! {hoursTotal} {hourText}',
      'Финальный отсчёт: {hoursTotal} {hourText}! 🛫',
    ],
    HOURS_TODAY: [
      '⏰ Осталось {hoursTotal} {hourText}! Почти там!',
      'Тик-так: {hoursTotal} {hourText} до вылёта! 🛩️',
    ],
  },
  milestones: {
    120: ['⏳ 120 дней — держимся! 💼', '120 до солнца — планирую маршрут 🗺️'],
    100: ['💪 100 дней — сотка до моря!', '100 дней до тропиков 🌴'],
    90: ['🎯 90 дней — квартал ожидания!', 'Ещё 90 — и волны зовут 🌊'],
    60: ['📆 60 дней — два месяца!', 'Минус два месяца — 60 до вылета ✈️'],
    45: ['🧳 45 — начинаю чек-лист вещей', '45 дней — подготовка в разгаре'],
    30: ['📅 Ровно месяц до отпуска! 🌴', '30 дней до рая в Паттайе! 🏖️'],
    20: ['🕰️ 20 дней осталось! Чемоданы готовы? ✈️', 'Двадцать дней до солнца и моря! ☀️'],
    15: ['🚀 Полмесяца до отпуска! 🌊', '15 дней — и я в Паттайе! 🌺'],
    10: ['🔥 Осталось 10 дней! Набираю скорость!', 'Десять дней до приключений! 🏄‍♂️'],
    7: ['✈️ Неделя до отпуска! Готовимся к релаксу!', '7 дней — и привет, пляжи! 🏝️'],
    5: ['🚀 Осталось 5 дней! Пора паковать чемодан!', 'Пять пальцев — пять дней ✋'],
    3: ['🎉 Уже пахнет морем! 3 дня!', 'Три дня до свободы! 🌅'],
    2: ['✌️ Два дня — и отпуск! 🛫', 'Послезавтра — взлёт! 🔜'],
    1: ['✈️ Завтра — отпуск! Ура!', 'Один день до рая! 😎'],
  },
};
EOF
echo "  Создан src/config/messages.ts"

# --- src/config/env.ts ---
cat > src/config/env.ts << 'EOF'
// src/config/env.ts
import dotenv from 'dotenv';
import { z } from 'zod';
import { logApp } from '../lib/logger.js';

dotenv.config();

const envSchema = z.object({
  API_ID: z.string().regex(/^\d+$/).transform(Number),
  API_HASH: z.string(),
  OPENWEATHER_API_KEY: z.string(),
  LAT: z.string().regex(/^-?\d+(\.\d+)?$/).transform(Number),
  LON: z.string().regex(/^-?\d+(\.\d+)?$/).transform(Number),
  TARGET_DATETIME: z.string().datetime(),
  SESSION_STRING: z.string().optional().default(''),
  TZ_OVERRIDE: z.string().optional(),
  UPDATE_INTERVAL_MS: z.string().regex(/^\d+$/).transform(Number).optional().default('3600000'),
  LOG_MAX_BYTES: z.string().regex(/^\d+$/).transform(Number).optional().default('1000000'),
  LOG_BACKUPS: z.string().regex(/^\d+$/).transform(Number).optional().default('5'),
});

export type Config = z.infer<typeof envSchema>;

export function loadConfig(): Config {
  try {
    const parsed = envSchema.safeParse(process.env);
    if (!parsed.success) {
      logApp(`❌ Ошибка конфигурации: ${parsed.error.errors.map(e => e.path.join('.') + ': ' + e.message).join(', ')}`);
      process.exit(1);
    }
    logApp('✅ Все переменные .env валидны');
    return parsed.data;
  } catch (err) {
    logApp(`❌ Неожиданная ошибка конфигурации: ${(err as Error).message}`);
    process.exit(1);
  }
}
EOF
echo "  Создан src/config/env.ts"

# --- src/lib/time.ts ---
mkdir -p src/lib
cat > src/lib/time.ts << 'EOF'
// src/lib/time.ts
import { toZonedTime, format } from 'date-fns-tz';
import { ru } from 'date-fns/locale/ru';

export const TIMEZONE: string = process.env.TZ_OVERRIDE || 'Europe/Moscow';
const LOCALE: string = 'ru-RU';
const DATE_FNS_LOCALE = ru;

export function nowZoned(): Date {
  return toZonedDate(new Date()); // Используем toZonedDate для избежания дублирования
}

export function toZonedDate(date: Date = new Date(), timeZone: string = TIMEZONE): Date {
  return toZonedTime(date, timeZone);
}

export interface FormatDateTimeOptions {
  dateStyle?: 'full' | 'long' | 'medium' | 'short';
  timeStyle?: 'full' | 'long' | 'medium' | 'short';
  timeZone?: string;
  locale?: string;
}

export function formatDateTime(date: Date = nowZoned(), opts: FormatDateTimeOptions = {}): string {
  const {
    dateStyle = 'medium',
    timeStyle = 'medium',
    timeZone = TIMEZONE,
    locale = LOCALE,
  } = opts;
  return new Intl.DateTimeFormat(locale, { dateStyle, timeStyle, timeZone }).format(date);
}

// Уточнение formatStamp с использованием Intl.DateTimeFormat
export function formatStamp(date: Date = nowZoned(), timeZone: string = TIMEZONE, locale: string = LOCALE): string {
  // ISO-подобная метка для логов
  return new Intl.DateTimeFormat(locale, {
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
    timeZone: timeZone,
  }).format(date).replace(/,/g, '');
  // Пример вывода: "01.01.2025 12:00:00"
}

export function getZonedDayOfWeek(date: Date = nowZoned(), timeZone: string = TIMEZONE): number {
  return toZonedDate(date, timeZone).getDay(); // 0..6
}

export function diffMs(targetDate: Date, baseDate: Date = nowZoned()): number {
  return targetDate.getTime() - baseDate.getTime();
}
export function diffHoursCeil(targetDate: Date, baseDate: Date = nowZoned()): number {
  return Math.ceil(diffMs(targetDate, baseDate) / (1000 * 60 * 60));
}
export function diffDaysFloor(targetDate: Date, baseDate: Date = nowZoned()): number {
  return Math.floor(diffMs(targetDate, baseDate) / (1000 * 60 * 60 * 24));
}
EOF
echo "  Создан src/lib/time.ts"

# --- src/lib/logger.ts ---
cat > src/lib/logger.ts << 'EOF'
// src/lib/logger.ts
import fs from 'fs';
import path from 'path';
import { formatStamp, TIMEZONE } from './time.js';

const LOG_DIR = 'logs';
const APP_LOG = path.join(LOG_DIR, 'app.log');
const WEATHER_LOG = path.join(LOG_DIR, 'weather.log');

const MAX_BYTES = parseInt(process.env.LOG_MAX_BYTES || '1000000', 10);
const BACKUPS = parseInt(process.env.LOG_BACKUPS || '5', 10);

function ensureLogDir() {
  if (!fs.existsSync(LOG_DIR)) {
    fs.mkdirSync(LOG_DIR, { recursive: true });
  }
}
ensureLogDir();

function rotateIfNeeded(filePath: string, maxBytes: number = MAX_BYTES, backups: number = BACKUPS) {
  try {
    if (!fs.existsSync(filePath)) return;
    const { size } = fs.statSync(filePath);
    if (size < maxBytes) return;

    const oldest = `${filePath}.${backups}`;
    if (fs.existsSync(oldest)) fs.unlinkSync(oldest);
    for (let i = backups - 1; i >= 1; i--) {
      const src = `${filePath}.${i}`;
      const dst = `${filePath}.${i + 1}`;
      if (fs.existsSync(src)) fs.renameSync(src, dst);
    }
    fs.renameSync(filePath, `${filePath}.1`);
  } catch (e) {
    console.error('[log-rotate]', (e as Error).stack || (e as Error).message);
  }
}

function writeLine(filePath: string, line: string) {
  rotateIfNeeded(filePath);
  fs.appendFileSync(filePath, line, 'utf-8');
}

function log(filePath: string, message: string) {
  const ts = formatStamp(); // строго в timezone
  const line = `[${ts} ${TIMEZONE}] ${message}\n`;
  writeLine(filePath, line);
  // Дублируем в консоль с timestamp
  const isErr = /\b(Ошибка|ERROR|🚨|❌)\b/i.test(message);
  (isErr ? console.error : console.log)(line.trim());
}

export const logApp = (msg: string) => log(APP_LOG, msg);
export const logWeather = (msg: string) => log(WEATHER_LOG, msg);

export function logError(context: string, err: unknown) {
  const detail = (err && ((err as Error).stack || (err as Error).message)) ? ((err as Error).stack || (err as Error).message) : String(err);
  logApp(`${context}: ${detail}`);
}

export { APP_LOG, WEATHER_LOG, TIMEZONE };
EOF
echo "  Создан src/lib/logger.ts"

# --- src/lib/retry.ts ---
cat > src/lib/retry.ts << 'EOF'
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

      if (!allow || nextAttempt >= totalAttempts || totalElapsed >= maxTotalMs) {
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
EOF
echo "  Создан src/lib/retry.ts"

# --- src/lib/weather.ts ---
cat > src/lib/weather.ts << 'EOF'
// src/lib/weather.ts
// Используем встроенный fetch в Node.js >= 18
import { logWeather, logError } from './logger.js';
import { withRetries } from './retry.js';
import { formatStamp } from './time.js';
import type { Config } from '../config/env.js'; // Импортируем тип

// Простой emoji-мап
function getWeatherEmoji(main: string | undefined): string {
  const map: { [key: string]: string } = {
    Thunderstorm: '⛈️',
    Drizzle: '🌧️',
    Rain: '🌦️',
    Snow: '❄️',
    Clear: '☀️',
    Clouds: '☁️',
    Mist: '🌫️',
    Fog: '🌫️',
    Haze: '🌫️',
    Dust: '💨',
    Smoke: '💨',
    Sand: '💨',
    Squall: '🌬️',
    Tornado: '🌪️',
  };
  return map[main || ''] || '🌤️';
}

// Тип для данных погоды из API
interface WeatherData {
  dt: number;
  temp: number;
  weather?: { main: string }[];
}

// Тип для кэша
interface WeatherCache {
  at: number;
  hourly: WeatherData[] | null;
  fallback: string | null;
}

// Кэшируем не строку, а весь hourly-массив
let cache: WeatherCache = { at: 0, hourly: null, fallback: null };

// Выбрать ближайший к текущему моменту прогноз
function pickNearestHourly(hourly: WeatherData[]): WeatherData | null {
  if (!hourly || hourly.length === 0) return null;
  const nowSec = Math.floor(Date.now() / 1000);
  // Найти прогноз с минимальной разницей по времени
  let chosen = hourly[0];
  let minDiff = Math.abs(chosen.dt - nowSec);
  for (let i = 1; i < hourly.length; i++) {
    const diff = Math.abs(hourly[i].dt - nowSec);
    if (diff < minDiff) {
      minDiff = diff;
      chosen = hourly[i];
    }
    // Если нашли прогноз в будущем, можно остановиться, если он ближе
    // Но логика поиска минимума точнее
  }
  return chosen;
}

export async function getWeatherCached(config: Config): Promise<string> {
  const now = Date.now();
  if (cache.hourly && now - cache.at < config.weatherCacheMs) { // Исправлено: config.weatherCacheMs
    const h = pickNearestHourly(cache.hourly);
    const out = h ? `${getWeatherEmoji(h.weather?.[0]?.main)}${Math.round(h.temp)}°C` : cache.fallback || '🌍?';
    logWeather(`♻️ Погода из кэша (${formatStamp()}): ${out}`);
    return out;
  }

  const { LAT, LON, OPENWEATHER_API_KEY, weatherTimeoutMs, retry } = config; // Исправлено: weatherTimeoutMs ?
  // Исправлен URL: убраны пробелы
  const url = `https://api.openweathermap.org/data/3.0/onecall?lat=${LAT}&lon=${LON}&exclude=current,minutely,daily,alerts&appid=${OPENWEATHER_API_KEY}&units=metric&lang=ru`;

  try {
    const data = await withRetries(
      async () => {
        const controller = new AbortController();
        const timeout = setTimeout(() => controller.abort(), weatherTimeoutMs); // Исправлено: weatherTimeoutMs

        logWeather(`📡 Запрос hourly: ${url.replace(OPENWEATHER_API_KEY, '***')}`);
        try {
          const res = await fetch(url, { signal: controller.signal });
          logWeather(`📡 Статус: ${res.status} ${res.statusText}`);
          if (!res.ok) {
            const text = await res.text();
            throw new Error(`HTTP ${res.status}: ${text}`);
          }
          return (await res.json()) as { hourly: WeatherData[] };
        } catch (err) {
          logError('[Погода] Ошибка запроса', err);
          throw err;
        } finally {
          clearTimeout(timeout);
        }
      },
      {
        ...retry,
        onError: (err, attempt) => logWeather(`[Попытка ${attempt + 1}] Ошибка погоды: ${(err && (err as Error).message) || String(err)}`),
        shouldRetry: (err) => {
          const msg = `${(err as Error)?.name || ''} ${(err as Error)?.message || ''}`;
          if (/aborted/i.test(msg)) return true;
          if (/ECONN|ENOTFOUND|EAI_AGAIN|ECONNRESET/i.test(msg)) return true;
          if (/HTTP\s(5\d\d)/.test(msg)) return true;
          if (/HTTP\s429/.test(msg)) return true;
          return false;
        },
      }
    );

    if (!data.hourly?.length) {
      throw new Error('Нет данных hourly');
    }

    cache = { at: Date.now(), hourly: data.hourly, fallback: cache.fallback };
    const h = pickNearestHourly(data.hourly);
    const result = h ? `${getWeatherEmoji(h.weather?.[0]?.main)}${Math.round(h.temp)}°C` : '🌍?';
    cache.fallback = result; // Сохраняем результат как fallback

    logWeather(`✅ Hourly (кэшировано в ${formatStamp()}): ${result}`);
    return result;
  } catch (error) {
    // Если ошибка и есть fallback, используем его
    if (cache.fallback) {
      logWeather(`⚠️ Ошибка получения погоды, использую fallback: ${cache.fallback}`);
      return cache.fallback;
    }
    // Если fallback'а нет, пробрасываем ошибку
    throw error;
  }
}
EOF
echo "  Создан src/lib/weather.ts"

# --- src/lib/messages.ts ---
cat > src/lib/messages.ts << 'EOF'
// src/lib/messages.ts
import { nowZoned, diffMs, diffHoursCeil, diffDaysFloor } from './time.js';
import { Localization, DEFAULT_LOCALIZATION } from '../config/messages.js';

// Предполагаем, что локализация будет передаваться или загружаться глобально
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

export function generateMessage(TARGET_DATE: Date): string {
  const now = nowZoned();
  const diff = diffMs(TARGET_DATE, now);

  if (diff < 0) {
    const daysAgo = Math.ceil(Math.abs(diff) / (1000 * 60 * 60 * 24));
    const dayText = plural(daysAgo, 'день', 'дня', 'дней');
    const messageTemplate = rnd(currentLocalization.messages.PAST_PREFIX);
    return interpolate(messageTemplate, { days: daysAgo, dayText });
  }

  const days = diffDaysFloor(TARGET_DATE, now);
  const hoursTotal = diffHoursCeil(TARGET_DATE, now);
  // const dow = getZonedDayOfWeek(now); // Не используется, можно удалить

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
EOF
echo "  Создан src/lib/messages.ts"

# --- src/lib/telegram.ts ---
cat > src/lib/telegram.ts << 'EOF'
// src/lib/telegram.ts
import { Api, TelegramClient } from 'telegram';
import { StringSession } from 'telegram/sessions/index.js';
import readline from 'readline';
import fs from 'fs';
import { logApp } from './logger.js';
import { withRetries } from './retry.js';
import type { Config } from '../config/env.js'; // Импортируем тип

function createRl() {
  return readline.createInterface({ input: process.stdin, output: process.stdout }); // Исправлена опечатка
}
const ask = (rl: readline.Interface, q: string) => new Promise<string>((r) => rl.question(q, r));

function parseFloodWait(err: any) {
  const msg = `${err?.message || ''}`;
  const m = msg.match(/FLOOD_WAIT_(\d+)/);
  if (m) return parseInt(m[1], 10) * 1000;
  return null;
}

function updateEnvKey(key: string, value: string) {
  try {
    const envPath = '.env';
    let content = '';
    try {
      content = fs.readFileSync(envPath, 'utf-8');
    } catch {}
    if (content.includes(`${key}=`)) {
      // Убираем кавычки при замене
      content = content.replace(new RegExp(`^${key}=.*$`, 'm'), `${key}=${value}`);
    } else {
      if (content && !content.endsWith('\n')) content += '\n';
      // Убираем кавычки при добавлении
      content += `${key}=${value}\n`;
    }
    fs.writeFileSync(envPath, content, 'utf-8');
    return true;
  } catch {
    return false;
  }
}

export async function initTelegram(config: Config): Promise<TelegramClient> {
  const { API_ID, API_HASH, SESSION_STRING } = config;
  const session = new StringSession(SESSION_STRING || '');
  const client = new TelegramClient(session, API_ID, API_HASH, { connectionRetries: 5 });

  if (SESSION_STRING) {
    // Headless mode: Просто connect, без start callbacks
    await withRetries(
      async () => {
        await client.connect();
        // Проверить авторизацию
        const me = await client.getMe();
        if (!me) throw new Error('Сессия невалидна, требуется регенерация');
        logApp('✅ Headless: Успешно подключено с существующей сессией');
      },
      {
        retries: 3,
        baseDelayMs: 2000,
        maxDelayMs: 20_000,
        onError: (err, attempt) => logApp(`[Попытка ${attempt + 1}] Ошибка connect в headless: ${(err as Error).message}`),
        shouldRetry: (err) => /TIMEOUT|ECONN|FLOOD/i.test((err as Error)?.message || ''),
      }
    );
  } else {
    // Интерактивный mode для генерации сессии
    logApp('⚠️ SESSION_STRING не указан — запускаю интерактивную авторизацию'); // Исправлена опечатка
    const rl = createRl();
    await withRetries(
      async () => {
        await client.start({
          phoneNumber: async () => ask(rl, '📞 Номер телефона: '),
          password: async () => ask(rl, '🔑 2FA пароль (если есть): '),
          phoneCode: async () => ask(rl, '📩 Код из Telegram: '),
          onError: (err) => logApp(`[Ошибка входа] ${(err as Error).message}`),
        });
      },
      {
        retries: 3,
        baseDelayMs: 2000,
        maxDelayMs: 20_000,
        onError: (err, attempt) => logApp(`[Попытка ${attempt + 1}] Ошибка старта Telegram: ${(err as Error).message}`),
        shouldRetry: (err) => !/AUTH_KEY_DUPLICATED|PHONE_MIGRATE|PHONE_NUMBER_INVALID/i.test((err as Error)?.message || ''),
      }
    ).finally(() => rl.close());

    logApp('✅ Успешный вход в Telegram');
    const sessionStr = client.session.save();
    // Не добавляем кавычки вокруг значения
    if (updateEnvKey('SESSION_STRING', sessionStr)) {
      logApp('🔐 SESSION_STRING сохранён в .env');
    } else {
      logApp('⚠️ Не удалось записать SESSION_STRING в .env — скопируйте вручную:');
      console.log(sessionStr);
    }
  }

  return client; // Исправлена опечатка
}

export async function ensureConnected(client: TelegramClient) {
  if (!client.connected) {
    logApp('🔌 Клиент не подключён — подключаюсь…');
    await withRetries(
      () => client.connect(),
      {
        retries: 5,
        baseDelayMs: 1500,
        maxDelayMs: 30_000,
        onError: (err, attempt) => logApp(`[Попытка ${attempt + 1}] Ошибка connect(): ${(err as Error).message}`),
      }
    );
    logApp('✅ Клиент подключён');
  }
}

export async function updateBio(client: TelegramClient, text: string, retryCfg: any) {
  await withRetries(
    async () => {
      await ensureConnected(client);
      await client.invoke(new Api.account.UpdateProfile({ about: text }));
    },
    {
      ...retryCfg,
      onError: (err, attempt) => {
        const wait = parseFloodWait(err);
        if (wait) {
          logApp(`⏳ FLOOD_WAIT: ждём ${Math.ceil(wait / 1000)}с перед повтором (попытка ${attempt + 1})`);
        } else {
          logApp(`[Попытка ${attempt + 1}] Ошибка UpdateProfile: ${(err as Error).message}`);
        }
      },
      shouldRetry: (err) => {
        if (parseFloodWait(err)) return true;
        const msg = `${(err as Error)?.message || ''}`;
        if (/TIMEOUT|ECONN|FLOOD|RPC_CALL_FAIL|PHONE_MIGRATE/i.test(msg)) return true;
        return false;
      },
      beforeRetry: async (err) => {
        const wait = parseFloodWait(err);
        if (wait) await new Promise((r) => setTimeout(r, wait));
        try {
          await ensureConnected(client);
        } catch {}
      },
    }
  );
  logApp(`[✔️] Bio обновлено: "${text}"`); // Исправлены кавычки
}
EOF
echo "  Создан src/lib/telegram.ts"

# --- src/index.ts ---
cat > src/index.ts << 'EOF'
// src/index.ts
import { loadConfig, type Config } from './config/env.js';
import { logApp, TIMEZONE } from './lib/logger.js';
import { getWeatherCached } from './lib/weather.js';
import { generateMessage } from './lib/messages.js';
import { initTelegram, updateBio } from './lib/telegram.js';
import { formatStamp } from './lib/time.js';
import type { TelegramClient } from 'telegram';

function truncateWithEllipsis(str: string, maxLen: number): string {
  if (str.length <= maxLen) return str;
  return str.slice(0, Math.max(0, maxLen - 1)) + '…';
}

async function buildBio(config: Config): Promise<string> {
  const message = generateMessage(config.TARGET_DATETIME); // Исправлено: TARGET_DATE -> TARGET_DATETIME
  const weather = await getWeatherCached(config);
  let bio = `${message} | ${weather}`;
  if (bio.length > config.bioMaxLength) {
    const reserve = ` | ${weather}`.length;
    bio = truncateWithEllipsis(message, config.bioMaxLength - reserve) + ` | ${weather}`;
  }
  return bio;
}

async function run() {
  try {
    const config: Config = loadConfig();
    logApp(`🚀 Старт бота. Часовой пояс: ${TIMEZONE}. Время: ${formatStamp()}`);

    const client: TelegramClient = await initTelegram(config);

    const refresh = async () => {
      try {
        const bio = await buildBio(config);
        await updateBio(client, bio, config.retry);
      } catch (err) {
        logApp(`🚨 Ошибка обновления bio: ${(err as Error).stack || (err as Error).message}`);
      }
    };

    // Первое обновление и далее по интервалу
    await refresh();
    const timer = setInterval(refresh, config.UPDATE_INTERVAL_MS); // Исправлено: updateIntervalMs -> UPDATE_INTERVAL_MS

    const shutdown = async (sig: string) => {
      logApp(`🛑 Получен сигнал ${sig}, завершаю работу…`);
      clearInterval(timer);
      try {
        await client.disconnect();
      } catch {}
      process.exit(0);
    };
    ['SIGINT', 'SIGTERM'].forEach((sig) => process.on(sig, () => shutdown(sig)));
  } catch (err) {
    logApp(`🚨 Фатальная ошибка запуска: ${(err as Error).stack || (err as Error).message}`);
    process.exit(1);
  }
}

run();
EOF
echo "  Создан src/index.ts"

# --- src/tests/time.test.ts ---
mkdir -p src/tests
cat > src/tests/time.test.ts << 'EOF'
// src/tests/time.test.ts
import { diffMs, diffHoursCeil, diffDaysFloor, toZonedDate } from '../lib/time.js';

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
EOF
echo "  Создан src/tests/time.test.ts"

# --- src/tests/messages.test.ts ---
cat > src/tests/messages.test.ts << 'EOF'
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
EOF
echo "  Создан src/tests/messages.test.ts"

# --- src/tests/retry.test.ts ---
cat > src/tests/retry.test.ts << 'EOF'
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
EOF
echo "  Создан src/tests/retry.test.ts"

# --- 7. Обновление package.json с новыми скриптами ---
echo "7. Обновление package.json с новыми скриптами..."
# Используем jq для безопасного обновления JSON
if ! command -v jq &> /dev/null; then
    echo "  Установка jq для обновления package.json..."
    sudo apt install -y jq
fi

# Обновляем package.json
tmp_package=$(mktemp)
jq '.type = "module" |
    .main = "dist/index.js" |
    .types = "dist/index.d.ts" |
    .files = ["dist/"] |
    .scripts = {
      "build": "tsc",
      "start": "node dist/index.js",
      "dev": "npm run build && npm run start",
      "lint": "eslint src/**/*.ts",
      "lint:fix": "eslint src/**/*.ts --fix",
      "format": "prettier --write src/**/*.ts",
      "test": "node --experimental-vm-modules node_modules/jest/bin/jest.js --runInBand"
    }' package.json > "$tmp_package" && mv "$tmp_package" package.json

echo "  package.json обновлён."

# --- 8. Создание README.md ---
echo "8. Создание README.md..."
cat > README.md << 'EOF_README'
# tg-bio

Telegram бот для автоматического обновления био (о себе) с обратным отсчётом до события и погодой.

## Возможности

- Обратный отсчёт до заданной даты и времени.
- Отображение текущей погоды в заданной точке.
- Настраиваемые сообщения и поддержка локализации.
- Автоматическое обновление био по расписанию.
- Устойчивость к ошибкам и повторные попытки.
- Логирование с ротацией.

## Установка

1. Клонируйте репозиторий:
   ```bash
   git clone <URL_репозитория>
   cd tg-bio