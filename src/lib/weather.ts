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
  }
  return chosen;
}

export async function getWeatherCached(config: Config): Promise<string> {
  const now = Date.now();
  // Используем правильное имя поля из конфига
  if (cache.hourly && now - cache.at < config.WEATHER_CACHE_MS) {
    const h = pickNearestHourly(cache.hourly);
    const out = h
      ? `${getWeatherEmoji(h.weather?.[0]?.main)}${Math.round(h.temp)}°C`
      : cache.fallback || '🌍?';
    logWeather(`♻️ Погода из кэша (${formatStamp()}): ${out}`);
    return out;
  }

  // Используем правильные имена полей из конфига
  const {
    LAT,
    LON,
    OPENWEATHER_API_KEY,
    WEATHER_TIMEOUT_MS: weatherTimeoutMs,
    retry,
  } = config;
  // Исправлен URL: убраны пробелы
  const url = `https://api.openweathermap.org/data/3.0/onecall?lat=${LAT}&lon=${LON}&exclude=current,minutely,daily,alerts&appid=${OPENWEATHER_API_KEY}&units=metric&lang=ru`;

  try {
    const data = await withRetries(
      async () => {
        const controller = new AbortController();
        const timeout = setTimeout(() => controller.abort(), weatherTimeoutMs);

        logWeather(
          `📡 Запрос hourly: ${url.replace(OPENWEATHER_API_KEY, '***')}`
        );
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
        ...retry, // Используем retry конфиг из config
        onError: (err, attempt) =>
          logWeather(
            `[Попытка ${attempt + 1}] Ошибка погоды: ${(err && (err as Error).message) || String(err)}`
          ),
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
    const result = h
      ? `${getWeatherEmoji(h.weather?.[0]?.main)}${Math.round(h.temp)}°C`
      : '🌍?';
    cache.fallback = result; // Сохраняем результат как fallback

    logWeather(`✅ Hourly (кэшировано в ${formatStamp()}): ${result}`);
    return result;
  } catch (error) {
    // Если ошибка и есть fallback, используем его
    if (cache.fallback) {
      logWeather(
        `⚠️ Ошибка получения погоды, использую fallback: ${cache.fallback}`
      );
      return cache.fallback;
    }
    // Если fallback'а нет, пробрасываем ошибку
    throw error;
  }
}
