import type { ProgressState } from './progress';
import type { StorageLike } from './progressStorage';

export const STREAK_REMINDER_STORAGE_KEY = 'word7000-streak-reminder-v1';
export const STREAK_REMINDER_WINDOW_MS = 60 * 60 * 1000;

export type StreakReminderPlan = {
  activeNow: boolean;
  expiresAt: Date | null;
  startsAt: Date | null;
  streak: number;
};

export type StreakLiveActivityProps = {
  countdownLabel: string;
  expiresAt: number;
  keepStreakLabel: string;
  startedAt: number;
  streak: number;
  streakLabel: string;
  title: string;
};

export function loadStreakReminderEnabled(storage: StorageLike | undefined): boolean {
  if (!storage) {
    return true;
  }

  try {
    return storage.getItem(STREAK_REMINDER_STORAGE_KEY) !== 'false';
  } catch {
    return true;
  }
}

export function saveStreakReminderEnabled(storage: StorageLike | undefined, enabled: boolean): void {
  try {
    storage?.setItem(STREAK_REMINDER_STORAGE_KEY, String(enabled));
  } catch {
    // A storage failure should not interrupt studying.
  }
}

export function localDateKey(date = new Date()): string {
  const localTime = date.getTime() - date.getTimezoneOffset() * 60_000;
  return new Date(localTime).toISOString().slice(0, 10);
}

export function buildStreakReminderPlan(
  progress: ProgressState,
  now = new Date(),
  enabled = true,
): StreakReminderPlan {
  const emptyPlan: StreakReminderPlan = {
    activeNow: false,
    expiresAt: null,
    startsAt: null,
    streak: Math.max(0, progress.streak),
  };

  if (!enabled || progress.streak <= 0 || !progress.lastStudyDate) {
    return emptyPlan;
  }

  const lastStudyDate = parseLocalDate(progress.lastStudyDate);
  if (!lastStudyDate) {
    return emptyPlan;
  }

  const todayStart = startOfLocalDay(now);
  const lastStudyStart = startOfLocalDay(lastStudyDate);
  const elapsedDays = Math.round((todayStart.getTime() - lastStudyStart.getTime()) / 86_400_000);
  if (elapsedDays < 0 || elapsedDays > 1) {
    return emptyPlan;
  }

  const expiresAt = new Date(lastStudyStart);
  expiresAt.setDate(expiresAt.getDate() + 2);
  const startsAt = new Date(expiresAt.getTime() - STREAK_REMINDER_WINDOW_MS);
  const nowMs = now.getTime();

  return {
    activeNow: nowMs >= startsAt.getTime() && nowMs < expiresAt.getTime(),
    expiresAt,
    startsAt,
    streak: progress.streak,
  };
}

export function buildStreakLiveActivityProps(
  plan: StreakReminderPlan,
  studyMode: 'english' | 'chinese',
): StreakLiveActivityProps | null {
  if (!plan.expiresAt || !plan.startsAt || plan.streak <= 0) {
    return null;
  }

  if (studyMode === 'chinese') {
    return {
      countdownLabel: 'Time left',
      expiresAt: plan.expiresAt.getTime(),
      keepStreakLabel: 'Study 1 word to keep it',
      startedAt: plan.startsAt.getTime(),
      streak: plan.streak,
      streakLabel: `${plan.streak}-day streak`,
      title: 'Your streak needs you',
    };
  }

  return {
    countdownLabel: '剩餘時間',
    expiresAt: plan.expiresAt.getTime(),
    keepStreakLabel: '完成 1 個單字即可保住連勝',
    startedAt: plan.startsAt.getTime(),
    streak: plan.streak,
    streakLabel: `連勝 ${plan.streak} 天`,
    title: '你的連勝快中斷了',
  };
}

function parseLocalDate(value: string): Date | null {
  const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(value);
  if (!match) {
    return null;
  }

  const date = new Date(Number(match[1]), Number(match[2]) - 1, Number(match[3]));
  return localDateKey(date) === value ? date : null;
}

function startOfLocalDay(date: Date): Date {
  return new Date(date.getFullYear(), date.getMonth(), date.getDate());
}
