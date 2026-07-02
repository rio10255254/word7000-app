import AsyncStorage from '@react-native-async-storage/async-storage';
import { Platform } from 'react-native';
import type { StorageLike } from './progressStorage';
export { createCachedAppStorage, shouldHydrateStorageKey, type AsyncStorageLike } from './appStorageCore';
import { createCachedAppStorage } from './appStorageCore';

const nativeStorage = createCachedAppStorage(AsyncStorage);

export function getAppStorage(): StorageLike | undefined {
  if (Platform.OS === 'web') {
    return (globalThis as { localStorage?: StorageLike }).localStorage;
  }

  return nativeStorage.storage;
}

export async function hydrateAppStorage(): Promise<void> {
  if (Platform.OS === 'web') {
    return;
  }

  await nativeStorage.hydrate();
}

export function isAppStorageHydrated(): boolean {
  return Platform.OS === 'web' || nativeStorage.isHydrated();
}
