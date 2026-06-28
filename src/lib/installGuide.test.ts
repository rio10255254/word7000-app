import { describe, expect, test } from 'vitest';
import {
  INSTALL_GUIDE_STORAGE_KEY,
  markInstallGuideSeen,
  shouldShowInstallGuide,
} from './installGuide';

class MemoryStorage {
  private values = new Map<string, string>();

  getItem(key: string) {
    return this.values.get(key) ?? null;
  }

  setItem(key: string, value: string) {
    this.values.set(key, value);
  }
}

describe('install guide storage', () => {
  test('shows the guide on first browser launch when the app is not installed', () => {
    const storage = new MemoryStorage();

    expect(shouldShowInstallGuide(storage, false)).toBe(true);
  });

  test('does not show after the user has seen it once', () => {
    const storage = new MemoryStorage();

    markInstallGuideSeen(storage);

    expect(storage.getItem(INSTALL_GUIDE_STORAGE_KEY)).toBe('seen');
    expect(shouldShowInstallGuide(storage, false)).toBe(false);
  });

  test('does not show when already running as a home-screen app', () => {
    const storage = new MemoryStorage();

    expect(shouldShowInstallGuide(storage, true)).toBe(false);
  });
});
