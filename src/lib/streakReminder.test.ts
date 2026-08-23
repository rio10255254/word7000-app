import { describe, expect, it } from 'vitest';
import type { ProgressState } from './progress';
import {
  buildStreakLiveActivityProps,
  buildStreakReminderPlan,
  loadStreakReminderEnabled,
  saveStreakReminderEnabled,
} from './streakReminder';

const baseProgress: ProgressState = {
  dailyTarget: 20,
  lastStudyDate: '2026-08-12',
  streak: 8,
  studiedToday: 0,
  words: {},
};

describe('streak reminder planning', () => {
  it('starts the countdown during the final hour before local midnight', () => {
    const plan = buildStreakReminderPlan(baseProgress, new Date(2026, 7, 13, 23, 15));

    expect(plan.activeNow).toBe(true);
    expect(plan.startsAt).toEqual(new Date(2026, 7, 13, 23, 0));
    expect(plan.expiresAt).toEqual(new Date(2026, 7, 14, 0, 0));
  });

  it('keeps tomorrow scheduled after the user studies today', () => {
    const plan = buildStreakReminderPlan(
      { ...baseProgress, lastStudyDate: '2026-08-13', studiedToday: 1 },
      new Date(2026, 7, 13, 23, 15),
    );

    expect(plan.activeNow).toBe(false);
    expect(plan.startsAt).toEqual(new Date(2026, 7, 14, 23, 0));
    expect(plan.expiresAt).toEqual(new Date(2026, 7, 15, 0, 0));
  });

  it('does not schedule an already broken streak', () => {
    const plan = buildStreakReminderPlan(
      { ...baseProgress, lastStudyDate: '2026-08-10' },
      new Date(2026, 7, 13, 20, 0),
    );

    expect(plan.expiresAt).toBeNull();
    expect(plan.activeNow).toBe(false);
  });

  it('builds fully localized activity copy', () => {
    const plan = buildStreakReminderPlan(baseProgress, new Date(2026, 7, 13, 23, 15));

    expect(buildStreakLiveActivityProps(plan, 'english')).toMatchObject({
      activityKind: 'streak',
      progressCurrent: 0,
      progressTarget: 1,
      streakLabel: '連勝 8 天',
      title: '你的連勝快中斷了',
    });
    expect(buildStreakLiveActivityProps(plan, 'chinese')).toMatchObject({
      activityKind: 'streak',
      progressCurrent: 0,
      progressTarget: 1,
      streakLabel: '8-day streak',
      title: 'Your streak needs you',
    });
  });
});

describe('streak reminder preference', () => {
  it('defaults to enabled and persists an explicit choice', () => {
    const values = new Map<string, string>();
    const storage = {
      getItem: (key: string) => values.get(key) ?? null,
      setItem: (key: string, value: string) => values.set(key, value),
    };

    expect(loadStreakReminderEnabled(storage)).toBe(true);
    saveStreakReminderEnabled(storage, false);
    expect(loadStreakReminderEnabled(storage)).toBe(false);
  });
});
