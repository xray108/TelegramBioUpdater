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
  // Используем преобразованную дату
  const message = generateMessage(config.TARGET_DATE);
  const weather = await getWeatherCached(config);
  let bio = `${message} | ${weather}`;
  // Используем поле из конфига
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
        // Используем retry конфиг из объекта config
        await updateBio(client, bio, config.retry);
      } catch (err) {
        logApp(`🚨 Ошибка обновления bio: ${(err as Error).stack || (err as Error).message}`);
      }
    };

    // Первое обновление и далее по интервалу
    await refresh();
    // Используем интервал из конфига
    const timer = setInterval(refresh, config.UPDATE_INTERVAL_MS);

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