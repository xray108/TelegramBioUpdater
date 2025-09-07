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

function rotateIfNeeded(
  filePath: string,
  maxBytes: number = MAX_BYTES,
  backups: number = BACKUPS
) {
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
  const detail =
    err && ((err as Error).stack || (err as Error).message)
      ? (err as Error).stack || (err as Error).message
      : String(err);
  logApp(`${context}: ${detail}`);
}

export { APP_LOG, WEATHER_LOG, TIMEZONE };
