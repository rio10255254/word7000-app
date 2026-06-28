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
  test('shows the guide on first browser launch when the app is not installed', () => {
    const storage = new MemoryStorage();

    expect(shouldShowInstallGuide(storage, false)).toBe(true);
  });

  test('shows the guide on first installed launch too', () => {
    const storage = new MemoryStorage();

    expect(shouldShowInstallGuide(storage, true)).toBe(true);
  });

  test('stores browser and installed guide state separately', () => {
    const storage = new MemoryStorage();

    markInstallGuideSeen(storage, false);

    expect(storage.getItem(installGuideStorageKey(false))).toBe('seen');
    expect(shouldShowInstallGuide(storage, false)).toBe(false);
    expect(shouldShowInstallGuide(storage, true)).toBe(true);
  });

  test('does not show after the user has seen it in the current launch mode', () => {
    const storage = new MemoryStorage();

    markInstallGuideSeen(storage, true);

    expect(storage.getItem(INSTALL_GUIDE_STORAGE_KEY)).toBeNull();
    expect(storage.getItem(installGuideStorageKey(true))).toBe('seen');
    expect(shouldShowInstallGuide(storage, true)).toBe(false);
  });
});
