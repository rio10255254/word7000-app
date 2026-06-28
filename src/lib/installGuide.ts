import type { StorageLike } from './progressStorage';

export const INSTALL_GUIDE_STORAGE_KEY = 'word7000-install-guide-v1';

export function shouldShowInstallGuide(storage: StorageLike | undefined, installed: boolean): boolean {
  if (installed) {
    return false;
  }

  try {
    return storage?.getItem(INSTALL_GUIDE_STORAGE_KEY) !== 'seen';
  } catch {
    return false;
  }
}

export function markInstallGuideSeen(storage: StorageLike | undefined): void {
  try {
    storage?.setItem(INSTALL_GUIDE_STORAGE_KEY, 'seen');
  } catch {
    // Private browsing can block storage writes. Dismissing the guide should still work in memory.
  }
}
