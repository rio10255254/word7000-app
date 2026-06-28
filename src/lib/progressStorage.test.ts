import { describe, expect, test } from 'vitest';
import { loadProgressFromStorage, saveProgressToStorage } from './progressStorage';
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

  test('falls back when stored progress is broken', () => {
    const storage = new MemoryStorage();
    storage.setItem('word7000-progress-v1', '{broken');

    expect(loadProgressFromStorage(storage, fallbackProgress())).toEqual(fallbackProgress());
  });

  test('falls back when storage is unavailable', () => {
    expect(loadProgressFromStorage(undefined, fallbackProgress())).toEqual(fallbackProgress());
  });
});

