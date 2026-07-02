import type { StorageLike } from './progressStorage';

export type AsyncStorageLike = {
  getAllKeys: () => Promise<readonly string[]>;
  multiGet: (keys: readonly string[]) => Promise<readonly [string, string | null][]>;
  removeItem: (key: string) => Promise<unknown>;
  setItem: (key: string, value: string) => Promise<unknown>;
};

const WORD7000_STORAGE_PREFIX = 'word7000-';

type CachedAppStorage = {
  hydrate: () => Promise<void>;
  isHydrated: () => boolean;
  storage: StorageLike;
};

export function shouldHydrateStorageKey(key: string): boolean {
  return key.startsWith(WORD7000_STORAGE_PREFIX);
}

export function createCachedAppStorage(backing: AsyncStorageLike): CachedAppStorage {
  const cache = new Map<string, string>();
  let hydrated = false;

  return {
    async hydrate() {
      if (hydrated) {
        return;
      }

      const keys = (await backing.getAllKeys()).filter(shouldHydrateStorageKey);
      if (keys.length > 0) {
        const pairs = await backing.multiGet(keys);
        pairs.forEach(([key, value]) => {
          if (value !== null) {
            cache.set(key, value);
          }
        });
      }

      hydrated = true;
    },
    isHydrated() {
      return hydrated;
    },
    storage: {
      getItem(key: string) {
        return cache.get(key) ?? null;
      },
      removeItem(key: string) {
        cache.delete(key);
        backing.removeItem(key).catch(() => undefined);
      },
      setItem(key: string, value: string) {
        cache.set(key, value);
        backing.setItem(key, value).catch(() => undefined);
      },
    },
  };
}
