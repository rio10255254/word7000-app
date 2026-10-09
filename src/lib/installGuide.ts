import type { StorageLike } from './progressStorage';

export const INSTALL_GUIDE_STORAGE_KEY = 'word7000-install-guide-v1';

export function installGuideStorageKey(installed: boolean): string {
  return `${INSTALL_GUIDE_STORAGE_KEY}-${installed ? 'installed' : 'browser'}`;
}

// The guide walks through Safari's Share > Add to Home Screen, so it only
// makes sense on an iPhone or iPad. iPadOS Safari reports itself as a Mac, so
// a touch-capable "Macintosh" counts too.
export function isIosBrowser(userAgent: string, maxTouchPoints = 0): boolean {
  if (/iPhone|iPad|iPod/i.test(userAgent)) {
    return true;
  }
  return /Macintosh/i.test(userAgent) && maxTouchPoints > 1;
}

export function shouldShowInstallGuide(
  _storage: StorageLike | undefined,
  installed: boolean,
  userAgent = '',
  maxTouchPoints = 0,
): boolean {
  // Still shown on every browser launch on iOS: until the app is on the Home
  // Screen it keeps losing storage and its own full-screen layout.
  return !installed && isIosBrowser(userAgent, maxTouchPoints);
}

export function markInstallGuideSeen(storage: StorageLike | undefined, installed = false): void {
  try {
    storage?.setItem(installGuideStorageKey(installed), 'seen');
  } catch {
    // Private browsing can block storage writes. Dismissing the guide should still work in memory.
  }
}
