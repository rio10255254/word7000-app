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
  const writeQueues = new Map<string, Promise<void>>();
  let hydrated = false;
  let hydrationPromise: Promise<void> | null = null;

  function enqueueWrite(key: string, operation: () => Promise<unknown>): void {
    const previous = writeQueues.get(key) ?? Promise.resolve();
    const next = previous
      .catch(() => undefined)
      .then(operation)
      .then(() => undefined)
      .catch(() => undefined)
      .finally(() => {
        if (writeQueues.get(key) === next) {
          writeQueues.delete(key);
        }
      });
    writeQueues.set(key, next);
  }

  return {
    async hydrate() {
      if (hydrated) {
        return;
      }
      if (!hydrationPromise) {
        hydrationPromise = (async () => {
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
        })().finally(() => {
          hydrationPromise = null;
        });
      }
      await hydrationPromise;
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
        enqueueWrite(key, () => backing.removeItem(key));
      },
      setItem(key: string, value: string) {
        cache.set(key, value);
        enqueueWrite(key, () => backing.setItem(key, value));
      },
    },
  };
}
