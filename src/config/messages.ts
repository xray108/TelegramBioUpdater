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
    if (num % 10 >= 2 && num % 10 <= 4 && (num % 100 < 10 || num % 100 >= 20))
      return two;
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
    WEEK: ['✈️ Неделя+ — {days} {dayText}', '{days} {dayText} — и я в раю! 🏖️'],
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
    20: [
      '🕰️ 20 дней осталось! Чемоданы готовы? ✈️',
      'Двадцать дней до солнца и моря! ☀️',
    ],
    15: ['🚀 Полмесяца до отпуска! 🌊', '15 дней — и я в Паттайе! 🌺'],
    10: [
      '🔥 Осталось 10 дней! Набираю скорость!',
      'Десять дней до приключений! 🏄‍♂️',
    ],
    7: [
      '✈️ Неделя до отпуска! Готовимся к релаксу!',
      '7 дней — и привет, пляжи! 🏝️',
    ],
    5: [
      '🚀 Осталось 5 дней! Пора паковать чемодан!',
      'Пять пальцев — пять дней ✋',
    ],
    3: ['🎉 Уже пахнет морем! 3 дня!', 'Три дня до свободы! 🌅'],
    2: ['✌️ Два дня — и отпуск! 🛫', 'Послезавтра — взлёт! 🔜'],
    1: ['✈️ Завтра — отпуск! Ура!', 'Один день до рая! 😎'],
  },
};
