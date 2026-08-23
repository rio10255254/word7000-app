export type DailyLearningCounters = {
  activeSeconds: number;
  chineseActions: number;
  englishActions: number;
  otherActions: number;
  quizCorrect: number;
  quizWrong: number;
  speakingCompleted: number;
  speakingSkipped: number;
  sessions: number;
  studyKnown: number;
  studyReview: number;
};

export type LearningAnalyticsState = {
  bestStreak: number;
  days: Record<string, Record<string, DailyLearningCounters>>;
  version: 1;
};

export const emptyDailyLearningCounters = (): DailyLearningCounters => ({
  activeSeconds: 0,
  chineseActions: 0,
  englishActions: 0,
  otherActions: 0,
  quizCorrect: 0,
  quizWrong: 0,
  speakingCompleted: 0,
  speakingSkipped: 0,
  sessions: 0,
  studyKnown: 0,
  studyReview: 0,
});

export function isLearningAnalyticsState(value: unknown): value is LearningAnalyticsState {
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    return false;
  }
  const analytics = value as Partial<LearningAnalyticsState>;
  if (analytics.version !== 1 || !isNonNegativeInteger(analytics.bestStreak) || !analytics.days || typeof analytics.days !== 'object') {
    return false;
  }
  return Object.entries(analytics.days).every(([date, sources]) =>
    /^\d{4}-\d{2}-\d{2}$/.test(date) &&
    Boolean(sources) &&
    typeof sources === 'object' &&
    !Array.isArray(sources) &&
    Object.values(sources).every(isDailyLearningCounters),
  );
}

export function mergeLearningAnalyticsStates(
  ...states: Array<LearningAnalyticsState | null | undefined>
): LearningAnalyticsState | null {
  const available = states.filter((state): state is LearningAnalyticsState => Boolean(state));
  if (available.length === 0) {
    return null;
  }

  const days: LearningAnalyticsState['days'] = {};
  let bestStreak = 0;
  available.forEach((state) => {
    bestStreak = Math.max(bestStreak, state.bestStreak);
    Object.entries(state.days).forEach(([date, sources]) => {
      const mergedSources = days[date] ?? {};
      Object.entries(sources).forEach(([sourceId, counters]) => {
        mergedSources[sourceId] = mergedSources[sourceId]
          ? mergeCountersByMaximum(mergedSources[sourceId], counters)
          : counters;
      });
      days[date] = mergedSources;
    });
  });

  return { bestStreak, days, version: 1 };
}

export function aggregateLearningDay(
  sources: Record<string, DailyLearningCounters> | null | undefined,
): DailyLearningCounters {
  const total = emptyDailyLearningCounters();
  Object.values(sources ?? {}).forEach((counters) => {
    (Object.keys(total) as Array<keyof DailyLearningCounters>).forEach((key) => {
      total[key] += counters[key];
    });
  });
  return total;
}

export function totalLearningActions(counters: DailyLearningCounters): number {
  return counters.otherActions + counters.quizCorrect + counters.quizWrong + counters.speakingCompleted + counters.speakingSkipped + counters.studyKnown + counters.studyReview;
}

export function goalLearningActions(counters: DailyLearningCounters): number {
  return counters.otherActions + counters.quizCorrect + counters.quizWrong + counters.studyKnown + counters.studyReview;
}

function isDailyLearningCounters(value: unknown): value is DailyLearningCounters {
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    return false;
  }
  const counters = value as Partial<DailyLearningCounters>;
  return (
    isNonNegativeInteger(counters.chineseActions) &&
    isNonNegativeInteger(counters.activeSeconds) &&
    isNonNegativeInteger(counters.englishActions) &&
    isNonNegativeInteger(counters.otherActions) &&
    isNonNegativeInteger(counters.quizCorrect) &&
    isNonNegativeInteger(counters.quizWrong) &&
    isNonNegativeInteger(counters.speakingCompleted) &&
    isNonNegativeInteger(counters.speakingSkipped) &&
    isNonNegativeInteger(counters.sessions) &&
    isNonNegativeInteger(counters.studyKnown) &&
    isNonNegativeInteger(counters.studyReview)
  );
}

function mergeCountersByMaximum(
  first: DailyLearningCounters,
  second: DailyLearningCounters,
): DailyLearningCounters {
  const merged = emptyDailyLearningCounters();
  (Object.keys(merged) as Array<keyof DailyLearningCounters>).forEach((key) => {
    merged[key] = Math.max(first[key], second[key]);
  });
  return merged;
}

function isNonNegativeInteger(value: unknown): value is number {
  return typeof value === 'number' && Number.isSafeInteger(value) && value >= 0;
}
