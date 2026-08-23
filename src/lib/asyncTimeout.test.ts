import { afterEach, describe, expect, test, vi } from 'vitest';
import { AsyncTimeoutError, withTimeout } from './asyncTimeout';

afterEach(() => vi.useRealTimers());

describe('async timeout guard', () => {
  test('returns a completed operation normally', async () => {
    await expect(withTimeout(Promise.resolve('ok'), 100, 'test')).resolves.toBe('ok');
  });

  test('turns a stuck native or network operation into a recoverable failure', async () => {
    vi.useFakeTimers();
    const result = withTimeout(new Promise<string>(() => undefined), 100, 'startup');
    const expectation = expect(result).rejects.toBeInstanceOf(AsyncTimeoutError);
    await vi.advanceTimersByTimeAsync(100);
    await expectation;
  });
});
