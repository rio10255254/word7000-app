import type { StorageLike } from './progressStorage';

export const INSTALL_GUIDE_STORAGE_KEY = 'word7000-install-guide-v1';

export function installGuideStorageKey(installed: boolean): string {
  return `${INSTALL_GUIDE_STORAGE_KEY}-${installed ? 'installed' : 'browser'}`;
}

export function shouldShowInstallGuide(storage: StorageLike | undefined, installed: boolean): boolean {
  try {
    return storage?.getItem(installGuideStorageKey(installed)) !== 'seen';
  } catch {
    return false;
  }
}

export function markInstallGuideSeen(storage: StorageLike | undefined, installed = false): void {
  try {
    storage?.setItem(installGuideStorageKey(installed), 'seen');
  } catch {
    // Private browsing can block storage writes. Dismissing the guide should still work in memory.
  }
}
