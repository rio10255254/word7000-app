import { afterEach, describe, expect, test, vi } from 'vitest';
import { DeferredStorageWriter } from './deferredStorageWriter';

afterEach(() => vi.useRealTimers());

describe('deferred storage writer', () => {
  test('collapses rapid updates into the newest value', async () => {
    vi.useFakeTimers();
    const write = vi.fn();
    const writer = new DeferredStorageWriter(write, 100);

    writer.enqueue(1);
    writer.enqueue(2);
    writer.enqueue(3);
    await vi.advanceTimersByTimeAsync(100);

    expect(write).toHaveBeenCalledTimes(1);
    expect(write).toHaveBeenCalledWith(3);
  });

  test('flushes pending work before the app is suspended', () => {
    vi.useFakeTimers();
    const write = vi.fn();
    const writer = new DeferredStorageWriter(write, 1000);

    writer.enqueue('latest');
    writer.flush();

    expect(write).toHaveBeenCalledWith('latest');
  });
});
