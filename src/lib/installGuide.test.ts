import { describe, expect, test } from 'vitest';
import {
  INSTALL_GUIDE_STORAGE_KEY,
  isIosBrowser,
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

const iphone = 'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 Version/18.0 Mobile/15E148 Safari/604.1';
const desktopChrome = 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0 Safari/537.36';
const macSafari = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 Version/18.0 Safari/605.1.15';

describe('install guide storage', () => {
  test('only offers the Safari home-screen guide on iPhone and iPad browsers', () => {
    expect(shouldShowInstallGuide(new MemoryStorage(), false, desktopChrome)).toBe(false);
    expect(shouldShowInstallGuide(new MemoryStorage(), false, macSafari)).toBe(false);
    expect(isIosBrowser(macSafari, 5)).toBe(true);
    expect(isIosBrowser(iphone)).toBe(true);
  });

  test('shows the guide on every browser launch even after it was dismissed before', () => {
    const storage = new MemoryStorage();

    markInstallGuideSeen(storage, false);

    expect(shouldShowInstallGuide(storage, false, iphone)).toBe(true);
  });

  test('skips the automatic guide when launched as an installed app', () => {
    const storage = new MemoryStorage();

    expect(shouldShowInstallGuide(storage, true, iphone)).toBe(false);
  });

  test('dismissal still records browser guide state for compatibility', () => {
    const storage = new MemoryStorage();

    markInstallGuideSeen(storage, false);

    expect(storage.getItem(installGuideStorageKey(false))).toBe('seen');
    expect(shouldShowInstallGuide(storage, false, iphone)).toBe(true);
  });

  test('dismissal still records installed guide state without auto-showing it', () => {
    const storage = new MemoryStorage();

    markInstallGuideSeen(storage, true);

    expect(storage.getItem(INSTALL_GUIDE_STORAGE_KEY)).toBeNull();
    expect(storage.getItem(installGuideStorageKey(true))).toBe('seen');
    expect(shouldShowInstallGuide(storage, true, iphone)).toBe(false);
  });
});
