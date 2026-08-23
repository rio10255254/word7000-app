import { afterEach, describe, expect, test, vi } from 'vitest';
import {
  StreakReminderRegistrationQueue,
  type StreakReminderRegistration,
} from './streakReminderRegistration';

const registration: StreakReminderRegistration = {
  activityPushToken: null,
  dailyTarget: 20,
  deviceId: 'device-1',
  enabled: true,
  expiresAt: null,
  locale: 'zh-TW',
  progressDate: '2026-08-24',
  pushToStartToken: 'token',
  startedForExpiresAt: null,
  streak: 8,
  studiedToday: 1,
  timeZone: 'Asia/Taipei',
};

afterEach(() => vi.useRealTimers());

describe('streak reminder registration queue', () => {
  test('collapses a rapid study run into one backend registration', async () => {
    vi.useFakeTimers();
    const save = vi.fn(async () => true);
    const queue = new StreakReminderRegistrationQueue({ delayMs: 100, save });

    queue.enqueue(registration);
    queue.enqueue({ ...registration, studiedToday: 2 });
    queue.enqueue({ ...registration, studiedToday: 3 });
    await vi.advanceTimersByTimeAsync(100);

    expect(save).toHaveBeenCalledTimes(1);
    expect(save.mock.calls[0][0].studiedToday).toBe(3);
  });

  test('does not upload an unchanged registration twice', async () => {
    vi.useFakeTimers();
    const save = vi.fn(async () => true);
    const queue = new StreakReminderRegistrationQueue({ delayMs: 20, save });

    queue.enqueue(registration);
    await vi.advanceTimersByTimeAsync(20);
    queue.enqueue(registration);
    await vi.advanceTimersByTimeAsync(20);

    expect(save).toHaveBeenCalledTimes(1);
  });

  test('flushes the latest registration when the app enters the background', async () => {
    vi.useFakeTimers();
    const save = vi.fn(async () => true);
    const queue = new StreakReminderRegistrationQueue({ delayMs: 10_000, save });

    queue.enqueue({ ...registration, studiedToday: 9 });
    await queue.flush();

    expect(save).toHaveBeenCalledWith(expect.objectContaining({ studiedToday: 9 }));
  });
});
