import { describe, expect, test } from 'vitest';
import { mergeProgressStates, type ProgressState, type ProgressStats } from './progress';
import { buildPersonalLearningAnalytics, recordLearningDuration, recordLearningEvent } from './learningAnalytics';
import { mergeLearningAnalyticsStates } from './learningAnalyticsCore';

const stats: ProgressStats = { favorites: 3, mastered: 70, remaining: 20, review: 10, studiedToday: 4 };
const base: ProgressState = {
  dailyProgressDate: '2026-08-24',
  dailyTarget: 20,
  lastStudyDate: '2026-08-24',
  streak: 4,
  studiedToday: 4,
  words: {},
};

describe('personal learning analytics', () => {
  test('records exact source, mode, and learning outcome without losing legacy totals', () => {
    const after = { ...base, studiedToday: 5 };
    const recorded = recordLearningEvent(base, after, {
      date: '2026-08-24',
      mode: 'english',
      sourceId: 'iphone-a',
      type: 'studyKnown',
    });

    expect(recorded.analytics?.days['2026-08-24'].legacy.otherActions).toBe(4);
    expect(recorded.analytics?.days['2026-08-24']['iphone-a']).toMatchObject({
      englishActions: 1,
      studyKnown: 1,
    });
    expect(recorded.analytics?.bestStreak).toBe(4);
  });

  test('merges the same device by maximum and different devices add through aggregation', () => {
    const first = recordLearningEvent(base, { ...base, studiedToday: 5 }, {
      date: '2026-08-24', mode: 'english', sourceId: 'iphone-a', type: 'quizCorrect',
    }).analytics!;
    const second = recordLearningEvent(base, { ...base, studiedToday: 5 }, {
      date: '2026-08-24', mode: 'chinese', sourceId: 'iphone-b', type: 'quizWrong',
    }).analytics!;
    const merged = mergeLearningAnalyticsStates(first, first, second)!;
    const progress = mergeProgressStates(
      { ...base, analytics: first },
      { ...base, analytics: second },
      { ...base, analytics: merged },
    );
    const analytics = buildPersonalLearningAnalytics(progress, stats, 100, '2026-08-24');
    expect(analytics.quizAttempts).toBe(2);
    expect(analytics.quizAccuracy).toBe(50);
  });

  test('builds seven and thirty day trends, goals, mastery, and a personalized focus', () => {
    let progress = base;
    for (let index = 0; index < 5; index += 1) {
      progress = recordLearningEvent(progress, progress, {
        date: '2026-08-24', mode: 'english', sourceId: 'iphone-a', type: 'quizWrong',
      });
    }
    const analytics = buildPersonalLearningAnalytics(progress, stats, 100, '2026-08-24');

    expect(analytics.chart7).toHaveLength(7);
    expect(analytics.chart30).toHaveLength(30);
    expect(analytics.masteryRate).toBe(70);
    expect(analytics.activeDays7).toBe(1);
    expect(analytics.focus).toBe('quiz');
  });

  test('bounds retained history so long-term analytics cannot grow storage forever', () => {
    let progress: ProgressState = { ...base, studiedToday: 0 };
    const start = new Date(2025, 0, 1);
    for (let index = 0; index < 410; index += 1) {
      const date = new Date(start);
      date.setDate(start.getDate() + index);
      const key = localDateKey(date);
      progress = recordLearningEvent(progress, progress, {
        date: key,
        mode: 'english',
        sourceId: 'iphone-a',
        type: 'studyKnown',
      });
    }

    expect(Object.keys(progress.analytics?.days ?? {})).toHaveLength(400);
  });

  test('records learning time in one bounded session without per-second updates', () => {
    const progress = recordLearningDuration(base, {
      date: '2026-08-24',
      mode: 'english',
      seconds: 125,
      sourceId: 'iphone-a',
    });
    const analytics = buildPersonalLearningAnalytics(progress, stats, 100, '2026-08-24');

    expect(analytics.learningMinutes).toBe(2);
    expect(analytics.sessions).toBe(1);
    expect(recordLearningDuration(progress, {
      date: '2026-08-24', mode: 'english', seconds: 2, sourceId: 'iphone-a',
    })).toBe(progress);
  });
});

function localDateKey(date: Date): string {
  const localTime = date.getTime() - date.getTimezoneOffset() * 60_000;
  return new Date(localTime).toISOString().slice(0, 10);
}
