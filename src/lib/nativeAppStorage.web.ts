import { createCachedAppStorage } from './appStorageCore';

export function getNativeAppStorage(): ReturnType<typeof createCachedAppStorage> | null {
  return null;
}
