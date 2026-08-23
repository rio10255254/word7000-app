import type { ProgressState, ProgressStats } from './progress';
import {
  aggregateLearningDay,
  emptyDailyLearningCounters,
  goalLearningActions,
  totalLearningActions,
  type DailyLearningCounters,
  type LearningAnalyticsState,
} from './learningAnalyticsCore';

const ANALYTICS_RETENTION_DAYS = 400;

export type LearningEventType =
  | 'quizCorrect'
  | 'quizWrong'
  | 'speakingCompleted'
  | 'speakingSkipped'
  | 'studyKnown'
  | 'studyReview';

export type LearningEvent = {
  date: string;
  mode: 'chinese' | 'english';
  sourceId: string;
  type: LearningEventType;
};

export type LearningDurationEvent = {
  date: string;
  mode: 'chinese' | 'english';
  seconds: number;
  sourceId: string;
};

export type LearningChartPoint = {
  actions: number;
  date: string;
  goalActions: number;
};

export type PersonalLearningAnalytics = {
  activeDays30: number;
  activeDays7: number;
  averagePerActiveDay30: number;
  bestDay: LearningChartPoint | null;
  bestStreak: number;
  chart30: LearningChartPoint[];
  chart7: LearningChartPoint[];
  chineseActions: number;
  difficultWords: number;
  englishActions: number;
  focus: 'consistency' | 'momentum' | 'quiz' | 'review';
  goalDays30: number;
  mastered: number;
  masteryRate: number;
  quizAccuracy: number | null;
  quizAttempts: number;
  reviewWords: number;
  speakingCompleted: number;
  speakingSkipped: number;
  learningMinutes: number;
  sessions: number;
  studyActions: number;
  todayActions: number;
  totalActions: number;
  weeklyActions: number;
  weeklyChangePercent: number | null;
};

export function recordLearningEvent(
  before: ProgressState,
  after: ProgressState,
  event: LearningEvent,
): ProgressState {
  const analytics = cloneOrSeedAnalytics(before, event.date);
  const currentSources = analytics.days[event.date] ?? {};
  const current = currentSources[event.sourceId] ?? emptyDailyLearningCounters();
  const next: DailyLearningCounters = {
    ...current,
    [event.type]: current[event.type] + 1,
    [event.mode === 'chinese' ? 'chineseActions' : 'englishActions']:
      current[event.mode === 'chinese' ? 'chineseActions' : 'englishActions'] + 1,
  };
  const days = {
    ...analytics.days,
    [event.date]: {
      ...currentSources,
      [event.sourceId]: next,
    },
  };
  const retainedDays = retainRecentDays(days);

  return {
    ...after,
    analytics: {
      bestStreak: Math.max(analytics.bestStreak, after.streak),
      days: retainedDays,
      version: 1,
    },
  };
}

export function recordLearningDuration(
  progress: ProgressState,
  event: LearningDurationEvent,
): ProgressState {
  const seconds = Math.max(0, Math.min(6 * 60 * 60, Math.round(event.seconds)));
  if (seconds < 5) {
    return progress;
  }
  const analytics = cloneOrSeedAnalytics(progress, event.date);
  const currentSources = analytics.days[event.date] ?? {};
  const current = currentSources[event.sourceId] ?? emptyDailyLearningCounters();
  return {
    ...progress,
    analytics: {
      bestStreak: Math.max(analytics.bestStreak, progress.streak),
      days: retainRecentDays({
        ...analytics.days,
        [event.date]: {
          ...currentSources,
          [event.sourceId]: {
            ...current,
            activeSeconds: current.activeSeconds + seconds,
            sessions: current.sessions + 1,
          },
        },
      }),
      version: 1,
    },
  };
}

export function buildPersonalLearningAnalytics(
  progress: ProgressState,
  stats: ProgressStats,
  vocabularyCount: number,
  today: string,
): PersonalLearningAnalytics {
  const analytics = cloneOrSeedAnalytics(progress, today);
  const chart30 = buildChart(analytics, today, 30);
  const chart7 = chart30.slice(-7);
  const previous7 = chart30.slice(-14, -7);
  const dayTotals = Object.entries(analytics.days).map(([date, sources]) => {
    const counters = aggregateLearningDay(sources);
    return { actions: totalLearningActions(counters), counters, date, goalActions: goalLearningActions(counters) };
  });
  const totals = dayTotals.reduce((sum, day) => addCounters(sum, day.counters), emptyDailyLearningCounters());
  const quizAttempts = totals.quizCorrect + totals.quizWrong;
  const weeklyActions = chart7.reduce((sum, day) => sum + day.actions, 0);
  const previousWeeklyActions = previous7.reduce((sum, day) => sum + day.actions, 0);
  const activeDays30 = chart30.filter((day) => day.actions > 0).length;
  const quizAccuracy = quizAttempts > 0 ? Math.round((totals.quizCorrect / quizAttempts) * 100) : null;
  const difficultWords = stats.review;
  const focus = chooseFocus({ activeDays7: chart7.filter((day) => day.actions > 0).length, quizAccuracy, quizAttempts, reviewWords: stats.review });

  return {
    activeDays30,
    activeDays7: chart7.filter((day) => day.actions > 0).length,
    averagePerActiveDay30: activeDays30 > 0
      ? Math.round(chart30.reduce((sum, day) => sum + day.actions, 0) / activeDays30)
      : 0,
    bestDay: dayTotals.sort((left, right) => right.actions - left.actions || right.date.localeCompare(left.date))[0] ?? null,
    bestStreak: Math.max(progress.streak, analytics.bestStreak),
    chart30,
    chart7,
    chineseActions: totals.chineseActions,
    difficultWords,
    englishActions: totals.englishActions,
    focus,
    goalDays30: chart30.filter((day) => day.goalActions >= progress.dailyTarget).length,
    mastered: stats.mastered,
    masteryRate: vocabularyCount > 0 ? Math.round((stats.mastered / vocabularyCount) * 100) : 0,
    quizAccuracy,
    quizAttempts,
    learningMinutes: Math.round(totals.activeSeconds / 60),
    reviewWords: stats.review,
    speakingCompleted: totals.speakingCompleted,
    speakingSkipped: totals.speakingSkipped,
    sessions: totals.sessions,
    studyActions: totals.studyKnown + totals.studyReview + totals.otherActions,
    todayActions: chart30.at(-1)?.actions ?? 0,
    totalActions: dayTotals.reduce((sum, day) => sum + day.actions, 0),
    weeklyActions,
    weeklyChangePercent: previousWeeklyActions > 0
      ? Math.round(((weeklyActions - previousWeeklyActions) / previousWeeklyActions) * 100)
      : weeklyActions > 0 ? 100 : null,
  };
}

function cloneOrSeedAnalytics(progress: ProgressState, today: string): LearningAnalyticsState {
  if (progress.analytics) {
    const progressDate = progress.dailyProgressDate ?? progress.lastStudyDate;
    const currentSources = progress.analytics.days[today] ?? {};
    const trackedGoalActions = goalLearningActions(aggregateLearningDay(currentSources));
    const missingLegacyActions = progressDate === today
      ? Math.max(0, progress.studiedToday - trackedGoalActions)
      : 0;
    const days = missingLegacyActions > 0
      ? {
          ...progress.analytics.days,
          [today]: {
            ...currentSources,
            legacy: {
              ...(currentSources.legacy ?? emptyDailyLearningCounters()),
              otherActions: (currentSources.legacy?.otherActions ?? 0) + missingLegacyActions,
            },
          },
        }
      : progress.analytics.days;
    return {
      bestStreak: Math.max(progress.analytics.bestStreak, progress.streak),
      days,
      version: 1,
    };
  }

  const progressDate = progress.dailyProgressDate ?? progress.lastStudyDate;
  const days: LearningAnalyticsState['days'] = {};
  if (progressDate === today && progress.studiedToday > 0) {
    days[today] = {
      legacy: {
        ...emptyDailyLearningCounters(),
        otherActions: progress.studiedToday,
      },
    };
  }
  return { bestStreak: progress.streak, days, version: 1 };
}

function retainRecentDays(days: LearningAnalyticsState['days']): LearningAnalyticsState['days'] {
  return Object.fromEntries(
    Object.entries(days).sort(([left], [right]) => right.localeCompare(left)).slice(0, ANALYTICS_RETENTION_DAYS),
  );
}

function buildChart(analytics: LearningAnalyticsState, today: string, dayCount: number): LearningChartPoint[] {
  const end = parseDate(today);
  if (!end) {
    return [];
  }
  return Array.from({ length: dayCount }, (_, index) => {
    const date = new Date(end);
    date.setDate(end.getDate() - (dayCount - 1 - index));
    const key = localDateKey(date);
    const counters = aggregateLearningDay(analytics.days[key]);
    return { actions: totalLearningActions(counters), date: key, goalActions: goalLearningActions(counters) };
  });
}

function addCounters(left: DailyLearningCounters, right: DailyLearningCounters): DailyLearningCounters {
  const next = emptyDailyLearningCounters();
  (Object.keys(next) as Array<keyof DailyLearningCounters>).forEach((key) => {
    next[key] = left[key] + right[key];
  });
  return next;
}

function chooseFocus({
  activeDays7,
  quizAccuracy,
  quizAttempts,
  reviewWords,
}: {
  activeDays7: number;
  quizAccuracy: number | null;
  quizAttempts: number;
  reviewWords: number;
}): PersonalLearningAnalytics['focus'] {
  if (quizAttempts >= 5 && quizAccuracy !== null && quizAccuracy < 70) {
    return 'quiz';
  }
  if (reviewWords >= 8) {
    return 'review';
  }
  if (activeDays7 < 3) {
    return 'consistency';
  }
  return 'momentum';
}

function parseDate(value: string): Date | null {
  const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(value);
  if (!match) {
    return null;
  }
  const date = new Date(Number(match[1]), Number(match[2]) - 1, Number(match[3]));
  return localDateKey(date) === value ? date : null;
}

function localDateKey(date: Date): string {
  const localTime = date.getTime() - date.getTimezoneOffset() * 60_000;
  return new Date(localTime).toISOString().slice(0, 10);
}
