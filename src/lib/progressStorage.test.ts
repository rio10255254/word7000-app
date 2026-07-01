import { describe, expect, test } from 'vitest';
import { loadProgressFromStorage, progressStorageKey, saveProgressToStorage } from './progressStorage';
import type { ProgressState } from './progress';

class MemoryStorage {
  private values = new Map<string, string>();

  getItem(key: string) {
    return this.values.get(key) ?? null;
  }

  setItem(key: string, value: string) {
    this.values.set(key, value);
  }

  removeItem(key: string) {
    this.values.delete(key);
  }
}

function fallbackProgress(): ProgressState {
  return {
    dailyTarget: 20,
    streak: 1,
    studiedToday: 0,
    words: {},
  };
}

describe('local progress storage', () => {
  test('saves and loads progress from browser storage', () => {
    const storage = new MemoryStorage();
    const progress: ProgressState = {
      dailyTarget: 25,
      streak: 3,
      studiedToday: 7,
      dailyProgressDate: '2026-06-29',
      lastStudyDate: '2026-06-29',
      words: {
        w001: {
          status: 'mastered',
          favorite: true,
          difficult: false,
          reviewCount: 0,
          lastStudied: '2026-06-28',
        },
      },
    };

    saveProgressToStorage(storage, progress);

    expect(loadProgressFromStorage(storage, fallbackProgress())).toEqual(progress);
  });

  test('keeps guest and signed-in account progress under separate keys', () => {
    const storage = new MemoryStorage();
    const guestProgress = { ...fallbackProgress(), studiedToday: 1 };
    const userAProgress = { ...fallbackProgress(), studiedToday: 7 };
    const userBProgress = { ...fallbackProgress(), studiedToday: 12 };

    saveProgressToStorage(storage, guestProgress);
    saveProgressToStorage(storage, userAProgress, 'google-user-a');
    saveProgressToStorage(storage, userBProgress, 'google-user-b');

    expect(progressStorageKey()).toBe('word7000-progress-v1');
    expect(progressStorageKey('google-user-a')).toBe('word7000-progress-v1:user:google-user-a');
    expect(loadProgressFromStorage(storage, fallbackProgress()).studiedToday).toBe(1);
    expect(loadProgressFromStorage(storage, fallbackProgress(), 'google-user-a').studiedToday).toBe(7);
    expect(loadProgressFromStorage(storage, fallbackProgress(), 'google-user-b').studiedToday).toBe(12);
  });

  test('falls back when stored progress is broken', () => {
    const storage = new MemoryStorage();
    storage.setItem('word7000-progress-v1', '{broken');

    expect(loadProgressFromStorage(storage, fallbackProgress())).toEqual(fallbackProgress());
  });

  test('falls back when stored streak dates are invalid', () => {
    const storage = new MemoryStorage();
    storage.setItem(
      'word7000-progress-v1',
      JSON.stringify({
        dailyTarget: 20,
        streak: 2,
        studiedToday: 4,
        dailyProgressDate: 123,
        lastStudyDate: false,
        words: {},
      }),
    );

    expect(loadProgressFromStorage(storage, fallbackProgress())).toEqual(fallbackProgress());
  });

  test('falls back when storage is unavailable', () => {
    expect(loadProgressFromStorage(undefined, fallbackProgress())).toEqual(fallbackProgress());
  });
});
