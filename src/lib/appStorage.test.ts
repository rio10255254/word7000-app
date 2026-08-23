import { describe, expect, test, vi } from 'vitest';
import { createCachedAppStorage, shouldHydrateStorageKey } from './appStorageCore';

describe('cached app storage', () => {
  test('hydrates only Word7000 keys from async native storage', async () => {
    const backing = createAsyncBacking({
      'other-app': 'ignore me',
      'word7000-progress-v1': '{"dailyTarget":20}',
      'word7000-study-mode-v1': 'chinese',
    });
    const cached = createCachedAppStorage(backing);

    await cached.hydrate();

    expect(cached.storage.getItem('word7000-progress-v1')).toBe('{"dailyTarget":20}');
    expect(cached.storage.getItem('word7000-study-mode-v1')).toBe('chinese');
    expect(cached.storage.getItem('other-app')).toBeNull();
  });

  test('updates the in-memory value immediately while persisting through the async backing store', async () => {
    const backing = createAsyncBacking({});
    const cached = createCachedAppStorage(backing);

    cached.storage.setItem('word7000-theme-v1', 'dark');

    expect(cached.storage.getItem('word7000-theme-v1')).toBe('dark');
    await vi.waitFor(() => expect(backing.setItem).toHaveBeenCalledWith('word7000-theme-v1', 'dark'));

    cached.storage.removeItem?.('word7000-theme-v1');

    expect(cached.storage.getItem('word7000-theme-v1')).toBeNull();
    await vi.waitFor(() => expect(backing.removeItem).toHaveBeenCalledWith('word7000-theme-v1'));
  });

  test('serializes writes per key so a slower old value cannot overwrite the newest value', async () => {
    const writes: string[] = [];
    const backing = createAsyncBacking({});
    backing.setItem.mockImplementation(async (_key: string, value: string) => {
      if (value === 'old') {
        await new Promise((resolve) => setTimeout(resolve, 20));
      }
      writes.push(value);
    });
    const cached = createCachedAppStorage(backing);

    cached.storage.setItem('word7000-progress-v1', 'old');
    cached.storage.setItem('word7000-progress-v1', 'new');

    await vi.waitFor(() => expect(writes).toEqual(['old', 'new']));
    expect(cached.storage.getItem('word7000-progress-v1')).toBe('new');
  });

  test('recognizes user-scoped Word7000 keys for signed-in account memory', () => {
    expect(shouldHydrateStorageKey('word7000-progress-v1:user:abc')).toBe(true);
    expect(shouldHydrateStorageKey('word7000-custom-sets-v1:user:abc')).toBe(true);
    expect(shouldHydrateStorageKey('supabase.auth.token')).toBe(false);
  });
});

function createAsyncBacking(seed: Record<string, string>) {
  const data = new Map(Object.entries(seed));

  return {
    getAllKeys: vi.fn(async () => Array.from(data.keys())),
    multiGet: vi.fn(async (keys: string[]) => keys.map((key) => [key, data.get(key) ?? null] as [string, string | null])),
    removeItem: vi.fn(async (key: string) => {
      data.delete(key);
    }),
    setItem: vi.fn(async (key: string, value: string) => {
      data.set(key, value);
    }),
  };
}
