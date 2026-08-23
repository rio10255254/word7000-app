import { afterEach, describe, expect, test, vi } from 'vitest';
import type { CustomSetState } from './customSets';
import type { ProgressState } from './progress';
import type { StorageLike } from './progressStorage';
import { loadUserMemoryOutbox, UserMemorySyncQueue, userMemoryOutboxKey } from './userMemorySync';

function progress(studiedToday: number): ProgressState {
  return { dailyTarget: 20, streak: 1, studiedToday, words: {} };
}

const customSets: CustomSetState = { customWords: [], sets: [] };

function memoryStorage(): StorageLike & { values: Map<string, string> } {
  const values = new Map<string, string>();
  return {
    getItem: (key) => values.get(key) ?? null,
    removeItem: (key) => void values.delete(key),
    setItem: (key, value) => void values.set(key, value),
    values,
  };
}

afterEach(() => {
  vi.useRealTimers();
});

describe('local-first user memory queue', () => {
  test('coalesces rapid progress updates and sends only the newest snapshot', async () => {
    vi.useFakeTimers();
    const storage = memoryStorage();
    const saveProgress = vi.fn(async () => ({ message: 'Saved', ok: true }));
    const queue = new UserMemorySyncQueue({
      flushDelayMs: 100,
      persistDelayMs: 0,
      saveAll: vi.fn(async () => ({ message: 'Saved', ok: true })),
      saveCustomSets: vi.fn(async () => ({ message: 'Saved', ok: true })),
      saveProgress,
      storage,
      userId: 'user-1',
    });

    queue.enqueue({ customSets, progress: progress(1) }, { progress: true });
    queue.enqueue({ customSets, progress: progress(2) }, { progress: true });
    queue.enqueue({ customSets, progress: progress(3) }, { progress: true });

    expect(loadUserMemoryOutbox(storage, 'user-1')?.progress.studiedToday).toBe(3);
    await vi.advanceTimersByTimeAsync(100);

    expect(saveProgress).toHaveBeenCalledTimes(1);
    expect(saveProgress.mock.calls[0][0].studiedToday).toBe(3);
    expect(storage.getItem(userMemoryOutboxKey('user-1'))).toBeNull();
  });

  test('combines progress and custom-set changes into one account save', async () => {
    vi.useFakeTimers();
    const saveAll = vi.fn(async () => ({ message: 'Saved', ok: true }));
    const queue = new UserMemorySyncQueue({
      flushDelayMs: 50,
      persistDelayMs: 0,
      saveAll,
      saveCustomSets: vi.fn(async () => ({ message: 'Saved', ok: true })),
      saveProgress: vi.fn(async () => ({ message: 'Saved', ok: true })),
      storage: memoryStorage(),
      userId: 'user-1',
    });

    queue.enqueue({ customSets, progress: progress(1) }, { progress: true });
    queue.enqueue({ customSets, progress: progress(1) }, { customSets: true });
    await vi.advanceTimersByTimeAsync(50);

    expect(saveAll).toHaveBeenCalledTimes(1);
  });

  test('keeps newer progress queued while an earlier save is still in flight', async () => {
    vi.useFakeTimers();
    const storage = memoryStorage();
    let finishFirstSave: ((result: { message: string; ok: boolean }) => void) | undefined;
    const saveProgress = vi
      .fn()
      .mockImplementationOnce(
        () =>
          new Promise<{ message: string; ok: boolean }>((resolve) => {
            finishFirstSave = resolve;
          }),
      )
      .mockResolvedValue({ message: 'Saved', ok: true });
    const queue = new UserMemorySyncQueue({
      flushDelayMs: 50,
      persistDelayMs: 0,
      saveAll: vi.fn(async () => ({ message: 'Saved', ok: true })),
      saveCustomSets: vi.fn(async () => ({ message: 'Saved', ok: true })),
      saveProgress,
      storage,
      userId: 'user-1',
    });

    queue.enqueue({ customSets, progress: progress(1) }, { progress: true });
    const firstFlush = queue.flush();
    queue.enqueue({ customSets, progress: progress(2) }, { progress: true });
    finishFirstSave?.({ message: 'Saved', ok: true });
    await firstFlush;

    expect(loadUserMemoryOutbox(storage, 'user-1')?.progress.studiedToday).toBe(2);
    await vi.advanceTimersByTimeAsync(50);
    expect(saveProgress).toHaveBeenCalledTimes(2);
    expect(saveProgress.mock.calls[1][0].studiedToday).toBe(2);
    expect(loadUserMemoryOutbox(storage, 'user-1')).toBeNull();
  });

  test('keeps failed work on the device and retries later', async () => {
    vi.useFakeTimers();
    const storage = memoryStorage();
    const saveProgress = vi
      .fn()
      .mockResolvedValueOnce({ message: 'Offline', ok: false })
      .mockResolvedValueOnce({ message: 'Saved', ok: true });
    const queue = new UserMemorySyncQueue({
      flushDelayMs: 20,
      persistDelayMs: 0,
      retryDelayMs: 80,
      saveAll: vi.fn(async () => ({ message: 'Saved', ok: true })),
      saveCustomSets: vi.fn(async () => ({ message: 'Saved', ok: true })),
      saveProgress,
      storage,
      userId: 'user-1',
    });

    queue.enqueue({ customSets, progress: progress(4) }, { progress: true });
    await vi.advanceTimersByTimeAsync(20);

    expect(queue.getStatus()).toBe('error');
    expect(loadUserMemoryOutbox(storage, 'user-1')?.progress.studiedToday).toBe(4);

    await vi.advanceTimersByTimeAsync(80);
    expect(saveProgress).toHaveBeenCalledTimes(2);
    expect(queue.getStatus()).toBe('saved');
    expect(loadUserMemoryOutbox(storage, 'user-1')).toBeNull();
  });

  test('backs off repeated offline retries instead of waking the radio every few seconds forever', async () => {
    vi.useFakeTimers();
    const saveProgress = vi
      .fn()
      .mockResolvedValueOnce({ message: 'Offline', ok: false })
      .mockResolvedValueOnce({ message: 'Offline', ok: false })
      .mockResolvedValueOnce({ message: 'Saved', ok: true });
    const queue = new UserMemorySyncQueue({
      flushDelayMs: 10,
      maxRetryDelayMs: 1000,
      persistDelayMs: 0,
      retryDelayMs: 100,
      saveAll: vi.fn(async () => ({ message: 'Saved', ok: true })),
      saveCustomSets: vi.fn(async () => ({ message: 'Saved', ok: true })),
      saveProgress,
      storage: memoryStorage(),
      userId: 'user-1',
    });

    queue.enqueue({ customSets, progress: progress(5) }, { progress: true });
    await vi.advanceTimersByTimeAsync(10);
    expect(saveProgress).toHaveBeenCalledTimes(1);

    await vi.advanceTimersByTimeAsync(100);
    expect(saveProgress).toHaveBeenCalledTimes(2);
    await vi.advanceTimersByTimeAsync(199);
    expect(saveProgress).toHaveBeenCalledTimes(2);
    await vi.advanceTimersByTimeAsync(1);
    expect(saveProgress).toHaveBeenCalledTimes(3);
    expect(queue.getStatus()).toBe('saved');
  });
});
