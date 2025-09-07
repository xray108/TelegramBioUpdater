// src/lib/telegram.ts
import { Api, TelegramClient } from 'telegram';
import { StringSession } from 'telegram/sessions/index.js';
import readline from 'readline';
import fs from 'fs';
import { logApp } from './logger.js';
import { withRetries } from './retry.js';
import type { Config } from '../config/env.js';

function createRl() {
  return readline.createInterface({
    input: process.stdin,
    output: process.stdout,
  });
}
const ask = (rl: readline.Interface, q: string) =>
  new Promise<string>((r) => rl.question(q, r));

function parseFloodWait(err: any) {
  const msg = `${err?.message || ''}`;
  const m = msg.match(/FLOOD_WAIT_(\d+)/);
  if (m) return parseInt(m[1], 10) * 1000;
  return null;
}

/**
 * Обновляет или добавляет ключ=значение в файл .env.
 * Значение записывается без кавычек.
 * @param key Ключ для обновления
 * @param value Значение для записи
 * @returns true если успешно, false в случае ошибки
 */
function updateEnvKey(key: string, value: string): boolean {
  const envPath = '.env';

  try {
    // Шаг 1: Прочитать файл
    let content = '';
    try {
      content = fs.readFileSync(envPath, 'utf-8');
    } catch (readError) {
      // Явно указываем тип ошибки как Error
      if (readError instanceof Error) {
        console.log(
          `[DEBUG updateEnvKey] Файл .env не существует или ошибка чтения:`,
          readError.message
        );
      } else {
        console.log(
          `[DEBUG updateEnvKey] Файл .env не существует или ошибка чтения: Неизвестная ошибка`
        );
      }
      // Продолжаем с пустым content
    }

    // Шаг 2: Обновить содержимое
    let updatedContent = '';
    const lines = content.split('\n');
    let keyFound = false;

    for (const line of lines) {
      if (line.trim().startsWith(`${key}=`)) {
        // Заменяем строку с ключом
        updatedContent += `${key}=${value}\n`;
        keyFound = true;
      } else {
        // Оставляем строку без изменений
        updatedContent += line + '\n';
      }
    }

    if (!keyFound) {
      // Если ключ не найден, добавляем его в конец
      if (updatedContent && !updatedContent.endsWith('\n')) {
        updatedContent += '\n';
      }
      updatedContent += `${key}=${value}\n`;
    }

    // Шаг 3: Записать файл
    fs.writeFileSync(envPath, updatedContent, 'utf-8');

    // Явно возвращаем true
    return true;
  } catch (error) {
    // Явно указываем тип ошибки как Error
    if (error instanceof Error) {
      console.error(
        `[ERROR updateEnvKey] Ошибка при обновлении ${key} в .env:`,
        error.message
      );
    } else {
      console.error(
        `[ERROR updateEnvKey] Ошибка при обновлении ${key} в .env: Неизвестная ошибка`
      );
    }
    // Явно возвращаем false
    return false;
  }
}

export async function initTelegram(config: Config): Promise<TelegramClient> {
  const { API_ID, API_HASH, SESSION_STRING } = config;
  const session = new StringSession(SESSION_STRING || '');
  const client = new TelegramClient(session, API_ID, API_HASH, {
    connectionRetries: 5,
  });

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
        onError: (err, attempt) =>
          logApp(
            `[Попытка ${attempt + 1}] Ошибка connect в headless: ${(err as Error).message}`
          ),
        shouldRetry: (err) =>
          /TIMEOUT|ECONN|FLOOD/i.test((err as Error)?.message || ''),
      }
    );
  } else {
    // Интерактивный mode для генерации сессии
    logApp('⚠️ SESSION_STRING не указан — запускаю интерактивную авторизацию');
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
        onError: (err, attempt) =>
          logApp(
            `[Попытка ${attempt + 1}] Ошибка старта Telegram: ${(err as Error).message}`
          ),
        shouldRetry: (err) =>
          !/AUTH_KEY_DUPLICATED|PHONE_MIGRATE|PHONE_NUMBER_INVALID/i.test(
            (err as Error)?.message || ''
          ),
      }
    ).finally(() => rl.close());

    logApp('✅ Успешный вход в Telegram');
    const sessionStr = session.save();
    if (updateEnvKey('SESSION_STRING', sessionStr)) {
      logApp('🔐 SESSION_STRING сохранён в .env');
    } else {
      logApp(
        '⚠️ Не удалось записать SESSION_STRING в .env — скопируйте вручную:'
      );
      console.log(sessionStr);
    }
  }

  return client;
}

export async function ensureConnected(client: TelegramClient) {
  if (!client.connected) {
    logApp('🔌 Клиент не подключён — подключаюсь…');
    await withRetries(() => client.connect(), {
      retries: 5,
      baseDelayMs: 1500,
      maxDelayMs: 30_000,
      onError: (err, attempt) =>
        logApp(
          `[Попытка ${attempt + 1}] Ошибка connect(): ${(err as Error).message}`
        ),
    });
    logApp('✅ Клиент подключён');
  }
}

export async function updateBio(
  client: TelegramClient,
  text: string,
  retryCfg: any
) {
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
          logApp(
            `⏳ FLOOD_WAIT: ждём ${Math.ceil(wait / 1000)}с перед повтором (попытка ${attempt + 1})`
          );
        } else {
          logApp(
            `[Попытка ${attempt + 1}] Ошибка UpdateProfile: ${(err as Error).message}`
          );
        }
      },
      shouldRetry: (err) => {
        if (parseFloodWait(err)) return true;
        const msg = `${(err as Error)?.message || ''}`;
        if (/TIMEOUT|ECONN|FLOOD|RPC_CALL_FAIL|PHONE_MIGRATE/i.test(msg))
          return true;
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
  logApp(`[✔️] Bio обновлено: "${text}"`);
}
