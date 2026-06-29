import { describe, expect, test } from 'vitest';
import {
  DEFAULT_FILTER_PREFERENCES,
  FILTER_PREFERENCES_STORAGE_KEY,
  loadFilterPreferences,
  saveFilterPreferences,
  type FilterPreferences,
} from './filterPreferences';

function memoryStorage(initial?: string) {
  const values = new Map<string, string>();
  if (initial) {
    values.set(FILTER_PREFERENCES_STORAGE_KEY, initial);
  }

  return {
    getItem: (key: string) => values.get(key) ?? null,
    setItem: (key: string, value: string) => values.set(key, value),
    removeItem: (key: string) => values.delete(key),
  };
}

describe('filter preferences', () => {
  test('defaults the library sort to alphabetical while leaving filters open-ended', () => {
    expect(DEFAULT_FILTER_PREFERENCES).toMatchObject({
      library: { filter: 'all', initial: 'all', level: 'all', sort: 'alphabetical' },
      quiz: { filter: 'all', initial: 'all', level: 'all', questionCount: 10 },
      study: { filter: 'all', initial: 'all', level: 'all' },
    });
  });

  test('loads saved filter and sort preferences for every app area', () => {
    const saved: FilterPreferences = {
      library: { filter: 'favorites', initial: 'B', level: 'Core 2', sort: 'default' },
      quiz: { filter: 'review', initial: 'C', level: 'Core 3', questionCount: 20 },
      study: { filter: 'mastered', initial: 'D', level: 'Core 4' },
    };

    expect(loadFilterPreferences(memoryStorage(JSON.stringify(saved)))).toEqual(saved);
  });

  test('saves filter and sort preferences under a dedicated key', () => {
    const storage = memoryStorage();
    const preferences: FilterPreferences = {
      library: { filter: 'new', initial: 'A', level: 'Core 1', sort: 'alphabetical' },
      quiz: { filter: 'favorites', initial: 'B', level: 'Core 2', questionCount: 50 },
      study: { filter: 'review', initial: 'C', level: 'Core 3' },
    };

    saveFilterPreferences(storage, preferences);

    expect(JSON.parse(storage.getItem(FILTER_PREFERENCES_STORAGE_KEY) ?? '')).toEqual(preferences);
  });

  test('falls back to the alphabetical defaults when saved data is invalid', () => {
    expect(loadFilterPreferences(memoryStorage('{"library":{"sort":"recent"}}'))).toEqual(DEFAULT_FILTER_PREFERENCES);
    expect(loadFilterPreferences(undefined)).toEqual(DEFAULT_FILTER_PREFERENCES);
  });
});
