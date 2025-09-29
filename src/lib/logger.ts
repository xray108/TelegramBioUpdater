// src/lib/logger.ts
import fs from 'fs';
import path from 'path';
import pino from 'pino';
import { formatStamp, TIMEZONE } from './time.js';

const LOG_DIR = 'logs';
fs.mkdirSync(LOG_DIR, { recursive: true });

const appFileStream = pino.destination({ dest: path.join(LOG_DIR, 'app.log'), sync: true });
const weatherFileStream = pino.destination({ dest: path.join(LOG_DIR, 'weather.log'), sync: true });

const pretty = (await import('pino-pretty')).default;
const prettyStream = pretty({
  colorize: true,
  translateTime: 'yyyy-mm-dd HH:MM:ss',
  ignore: 'pid,hostname,component'
});

const appLogger = pino({
  timestamp: () => `,"time":"${formatStamp()} ${TIMEZONE}"`,
}, pino.multistream([
  { stream: appFileStream },
  { stream: prettyStream }
])).child({ component: 'app' });

const weatherLogger = pino({
  timestamp: () => `,"time":"${formatStamp()} ${TIMEZONE}"`,
}, pino.multistream([
  { stream: weatherFileStream },
  { stream: prettyStream }
])).child({ component: 'weather' });

export const logApp = (msg: string) => {
  if (/\b(Ошибка|ERROR|🚨|❌)\b/i.test(msg)) {
    appLogger.error(msg);
  } else {
    appLogger.info(msg);
  }
};

export const logWeather = (msg: string) => {
  if (/\b(Ошибка|ERROR|🚨|❌)\b/i.test(msg)) {
    weatherLogger.error(msg);
  } else {
    weatherLogger.info(msg);
  }
};

export function logError(context: string, err: unknown) {
  const detail = (err && ((err as Error).stack || (err as Error).message)) ? ((err as Error).stack || (err as Error).message) : String(err);
  appLogger.error(`${context}: ${detail}`);
}

export { TIMEZONE };