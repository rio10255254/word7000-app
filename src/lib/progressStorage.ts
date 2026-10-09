import type { ProgressState, WordProgress, WordStatus } from './progress';
import { isLearningAnalyticsState } from './learningAnalyticsCore';

export const PROGRESS_STORAGE_KEY = 'word7000-progress-v1';

export type StorageLike = {
  getItem: (key: string) => string | null;
  setItem: (key: string, value: string) => void;
  removeItem?: (key: string) => void;
};

const wordStatuses = new Set<WordStatus>(['new', 'mastered', 'review']);

export function isProgressState(value: unknown): value is ProgressState {
  if (!value || typeof value !== 'object') {
    return false;
  }

  const progress = value as Partial<ProgressState>;
  if (
    typeof progress.dailyTarget !== 'number' ||
    typeof progress.streak !== 'number' ||
    typeof progress.studiedToday !== 'number' ||
    (progress.dailyProgressDate !== undefined && typeof progress.dailyProgressDate !== 'string') ||
    (progress.lastStudyDate !== undefined && typeof progress.lastStudyDate !== 'string') ||
    (progress.analytics !== undefined && !isLearningAnalyticsState(progress.analytics)) ||
    !progress.words ||
    typeof progress.words !== 'object' ||
    Array.isArray(progress.words)
  ) {
    return false;
  }

  return Object.values(progress.words).every(isWordProgress);
}

export function progressStorageKey(userId?: string | null): string {
  return userId ? `${PROGRESS_STORAGE_KEY}:user:${userId}` : PROGRESS_STORAGE_KEY;
}

export function loadProgressFromStorage(
  storage: StorageLike | undefined,
  fallback: ProgressState,
  userId?: string | null,
): ProgressState {
  if (!storage) {
    return fallback;
  }

  try {
    const stored = storage.getItem(progressStorageKey(userId));
    if (!stored) {
      return fallback;
    }

    const parsed: unknown = JSON.parse(stored);
    return isProgressState(parsed) ? parsed : fallback;
  } catch {
    return fallback;
  }
}

export function saveProgressToStorage(
  storage: StorageLike | undefined,
  progress: ProgressState,
  userId?: string | null,
): void {
  if (!storage) {
    return;
  }

  try {
    storage.setItem(progressStorageKey(userId), JSON.stringify(progress));
  } catch {
    // Storage can fail in private mode or quota edge cases. The app still works in memory.
  }
}

function isWordProgress(value: unknown): value is WordProgress {
  if (!value || typeof value !== 'object') {
    return false;
  }

  const progress = value as Partial<WordProgress>;
  return (
    typeof progress.favorite === 'boolean' &&
    typeof progress.difficult === 'boolean' &&
    typeof progress.reviewCount === 'number' &&
    typeof progress.status === 'string' &&
    wordStatuses.has(progress.status as WordStatus) &&
    (progress.favoriteUpdatedAt === undefined || typeof progress.favoriteUpdatedAt === 'string') &&
    (progress.dueDate === undefined || typeof progress.dueDate === 'string') &&
    (progress.stage === undefined || typeof progress.stage === 'number') &&
    (progress.lastStudied === undefined || typeof progress.lastStudied === 'string')
  );
}
