import type { StorageLike } from './progressStorage';
import type { LibraryFilter, LibrarySort } from './progress';

export const FILTER_PREFERENCES_STORAGE_KEY = 'word7000-filter-preferences-v1';

export type QuizQuestionCountPreference = 10 | 20 | 50;

export type FilterPreferences = {
  library: {
    filter: LibraryFilter;
    initial: string;
    level: string;
    sort: LibrarySort;
  };
  quiz: {
    filter: LibraryFilter;
    initial: string;
    level: string;
    questionCount: QuizQuestionCountPreference;
  };
  study: {
    filter: LibraryFilter;
    initial: string;
    level: string;
  };
};

export const DEFAULT_FILTER_PREFERENCES: FilterPreferences = {
  library: { filter: 'all', initial: 'all', level: 'all', sort: 'alphabetical' },
  quiz: { filter: 'all', initial: 'all', level: 'all', questionCount: 10 },
  study: { filter: 'all', initial: 'all', level: 'all' },
};

const filters = new Set<LibraryFilter>(['all', 'favorites', 'review', 'mastered', 'new']);
const sorts = new Set<LibrarySort>(['default', 'alphabetical']);
const questionCounts = new Set<QuizQuestionCountPreference>([10, 20, 50]);

export function loadFilterPreferences(storage: StorageLike | undefined): FilterPreferences {
  if (!storage) {
    return DEFAULT_FILTER_PREFERENCES;
  }

  try {
    const stored = storage.getItem(FILTER_PREFERENCES_STORAGE_KEY);
    if (!stored) {
      return DEFAULT_FILTER_PREFERENCES;
    }

    const parsed: unknown = JSON.parse(stored);
    return isFilterPreferences(parsed) ? parsed : DEFAULT_FILTER_PREFERENCES;
  } catch {
    return DEFAULT_FILTER_PREFERENCES;
  }
}

export function saveFilterPreferences(storage: StorageLike | undefined, preferences: FilterPreferences): void {
  if (!storage) {
    return;
  }

  try {
    storage.setItem(FILTER_PREFERENCES_STORAGE_KEY, JSON.stringify(preferences));
  } catch {
    // Preferences should not block the app if local storage is unavailable.
  }
}

function isFilterPreferences(value: unknown): value is FilterPreferences {
  if (!value || typeof value !== 'object') {
    return false;
  }

  const preferences = value as Partial<FilterPreferences>;
  return Boolean(
    preferences.library &&
      isLibraryPreferences(preferences.library) &&
      preferences.quiz &&
      isQuizPreferences(preferences.quiz) &&
      preferences.study &&
      isBasicFilterPreferences(preferences.study),
  );
}

function isLibraryPreferences(value: unknown): value is FilterPreferences['library'] {
  return isBasicFilterPreferences(value) && sorts.has((value as FilterPreferences['library']).sort);
}

function isQuizPreferences(value: unknown): value is FilterPreferences['quiz'] {
  return isBasicFilterPreferences(value) && questionCounts.has((value as FilterPreferences['quiz']).questionCount);
}

function isBasicFilterPreferences(value: unknown): value is FilterPreferences['study'] {
  if (!value || typeof value !== 'object') {
    return false;
  }

  const preferences = value as Partial<FilterPreferences['study']>;
  return (
    typeof preferences.filter === 'string' &&
    filters.has(preferences.filter as LibraryFilter) &&
    typeof preferences.initial === 'string' &&
    typeof preferences.level === 'string'
  );
}
