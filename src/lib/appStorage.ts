import { Platform } from 'react-native';
import type { StorageLike } from './progressStorage';
export { createCachedAppStorage, shouldHydrateStorageKey, type AsyncStorageLike } from './appStorageCore';
import { getNativeAppStorage } from './nativeAppStorage';

export function getAppStorage(): StorageLike | undefined {
  if (Platform.OS === 'web') {
    return (globalThis as { localStorage?: StorageLike }).localStorage;
  }

  return getNativeAppStorage()?.storage;
}

export async function hydrateAppStorage(): Promise<void> {
  if (Platform.OS === 'web') {
    return;
  }

  await getNativeAppStorage()?.hydrate();
}

export function isAppStorageHydrated(): boolean {
  return Platform.OS === 'web' || Boolean(getNativeAppStorage()?.isHydrated());
}
