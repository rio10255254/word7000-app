import { describe, expect, test } from 'vitest';
import {
  INSTALL_GUIDE_STORAGE_KEY,
  installGuideStorageKey,
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
  test('shows the guide on every browser launch even after it was dismissed before', () => {
    const storage = new MemoryStorage();

    markInstallGuideSeen(storage, false);

    expect(shouldShowInstallGuide(storage, false)).toBe(true);
  });

  test('skips the automatic guide when launched as an installed app', () => {
    const storage = new MemoryStorage();

    expect(shouldShowInstallGuide(storage, true)).toBe(false);
  });

  test('dismissal still records browser guide state for compatibility', () => {
    const storage = new MemoryStorage();

    markInstallGuideSeen(storage, false);

    expect(storage.getItem(installGuideStorageKey(false))).toBe('seen');
    expect(shouldShowInstallGuide(storage, false)).toBe(true);
  });

  test('dismissal still records installed guide state without auto-showing it', () => {
    const storage = new MemoryStorage();

    markInstallGuideSeen(storage, true);

    expect(storage.getItem(INSTALL_GUIDE_STORAGE_KEY)).toBeNull();
    expect(storage.getItem(installGuideStorageKey(true))).toBe('seen');
    expect(shouldShowInstallGuide(storage, true)).toBe(false);
  });
});
