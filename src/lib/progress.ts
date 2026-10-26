import type { WordEntry } from '../data/words';
import { mergeLearningAnalyticsStates, type LearningAnalyticsState } from './learningAnalyticsCore';

export type WordStatus = 'new' | 'mastered' | 'review';
export type LibraryFilter = 'all' | 'favorites' | 'review' | 'mastered' | 'new';
export type LibrarySort = 'default' | 'alphabetical';
export type LibraryFilterOptions = {
  initial?: string;
  level?: string;
  sort?: LibrarySort;
};

export type WordProgress = {
  status: WordStatus;
  favorite: boolean;
  difficult: boolean;
  reviewCount: number;
  /** Next date (YYYY-MM-DD) the word should come back for review. */
  dueDate?: string;
  favoritedAt?: string;
  favoriteUpdatedAt?: string;
  /** How many times a word that was already known slipped back to review. */
  lapses?: number;
  lastStudied?: string;
  /** Spaced-repetition box: 0 means "still learning", higher waits longer. */
  stage?: number;
  statusUpdatedAt?: string;
};

export type ProgressState = {
  analytics?: LearningAnalyticsState;
  dailyTarget: number;
  streak: number;
  studiedToday: number;
  dailyProgressDate?: string;
  lastStudyDate?: string;
  /** The last missed day covered by the shared seven-day streak protection. */
  streakFreezeDate?: string;
  words: Record<string, WordProgress>;
};

export type ProgressStats = {
  due: number;
  mastered: number;
  review: number;
  favorites: number;
  remaining: number;
  studiedToday: number;
};

export type QuizOption = {
  meaning: string;
  correct: boolean;
};
export type QuizAnswerMode = 'meaning' | 'word';

type PreparedWord = {
  example: string;
  exampleZh: string;
  index: number;
  meaning: string;
  normalizedWord: string;
  word: WordEntry;
};

type PreparedVocabulary = {
  alphabeticalRecords: PreparedWord[] | null;
  alphabeticalWords: WordEntry[];
  idSet: Set<string>;
  indexById: Map<string, number>;
  records: PreparedWord[] | null;
};

const preparedVocabularyCache = new WeakMap<WordEntry[], PreparedVocabulary>();

function currentProgress(state: ProgressState, wordId: string): WordProgress {
  return (
    state.words[wordId] ?? {
      status: 'new',
      favorite: false,
      difficult: false,
      reviewCount: 0,
    }
  );
}

function updateWord(
  state: ProgressState,
  wordId: string,
  update: (progress: WordProgress) => WordProgress,
  studiedDate?: string,
): ProgressState {
  const previous = currentProgress(state, wordId);
  // The daily goal counts distinct words. Marking the same card again (a
  // re-queued miss, an undo and redo) must not fill the goal by itself.
  const countsTowardToday = Boolean(studiedDate) && previous.lastStudied !== studiedDate;
  const baseState = studiedDate ? advanceDailyProgress(state, studiedDate, countsTowardToday ? 1 : 0) : state;

  return {
    ...baseState,
    words: {
      ...baseState.words,
      [wordId]: update(currentProgress(baseState, wordId)),
    },
  };
}

// Days to wait before a word comes back, indexed by stage. A word marked
// "still learning" drops to stage 0 and is due again the same day; every
// correct recall pushes it one stage further out.
export const REVIEW_INTERVAL_DAYS = [0, 1, 3, 7, 14, 30, 60, 120] as const;
export const MAX_REVIEW_STAGE = REVIEW_INTERVAL_DAYS.length - 1;
// A new word the learner already recognises on first sight skips the short
// intervals: re-showing it tomorrow would only be noise.
const KNOWN_ON_FIRST_SIGHT_STAGE = 3;
// Picking the right meaning out of four is recognition, not recall, so a
// first-time correct quiz answer earns a much shorter wait.
const RECOGNISED_IN_QUIZ_STAGE = 1;

export function reviewStage(progress: WordProgress | undefined): number {
  if (!progress || progress.status === 'new') {
    return 0;
  }
  if (typeof progress.stage === 'number' && Number.isFinite(progress.stage)) {
    return Math.max(0, Math.min(MAX_REVIEW_STAGE, Math.round(progress.stage)));
  }
  // Progress saved before scheduling existed: treat mastered words as a week
  // old and struggling words as due now.
  return progress.status === 'mastered' ? KNOWN_ON_FIRST_SIGHT_STAGE : 0;
}

export function reviewDueDate(progress: WordProgress | undefined): string | null {
  if (!progress || progress.status === 'new') {
    return null;
  }
  if (progress.dueDate) {
    return progress.dueDate;
  }
  const anchor = progress.lastStudied ?? progress.statusUpdatedAt?.slice(0, 10);
  if (!anchor) {
    return '0000-00-00';
  }
  return addDays(anchor, REVIEW_INTERVAL_DAYS[reviewStage(progress)]) ?? anchor;
}

export function isWordDue(progress: WordProgress | undefined, today: string): boolean {
  const due = reviewDueDate(progress);
  return due !== null && due <= today;
}

export function markKnown(state: ProgressState, wordId: string, today: string, changedAt = createRuntimeTimestamp()): ProgressState {
  return gradeWord(state, wordId, today, changedAt, KNOWN_ON_FIRST_SIGHT_STAGE);
}

export function markQuizCorrect(state: ProgressState, wordId: string, today: string, changedAt = createRuntimeTimestamp()): ProgressState {
  return gradeWord(state, wordId, today, changedAt, RECOGNISED_IN_QUIZ_STAGE);
}

function gradeWord(
  state: ProgressState,
  wordId: string,
  today: string,
  changedAt: string,
  firstSightStage: number,
): ProgressState {
  return updateWord(
    state,
    wordId,
    (progress) => {
      // Seeing a word twice in one day is not spaced practice: keep the stage
      // it earned earlier today instead of climbing several boxes in a row.
      const alreadyGradedToday = progress.lastStudied === today && progress.status === 'mastered';
      const stage = progress.status === 'new'
        ? firstSightStage
        : alreadyGradedToday
          ? reviewStage(progress)
          : Math.min(MAX_REVIEW_STAGE, Math.max(1, reviewStage(progress) + 1));
      return {
        ...progress,
        status: 'mastered',
        difficult: false,
        dueDate: addDays(today, REVIEW_INTERVAL_DAYS[stage]) ?? today,
        lastStudied: today,
        stage,
        statusUpdatedAt: changedAt,
      };
    },
    today,
  );
}

export function markReview(state: ProgressState, wordId: string, today: string, changedAt = createRuntimeTimestamp()): ProgressState {
  return updateWord(
    state,
    wordId,
    (progress) => ({
      ...progress,
      status: 'review',
      difficult: true,
      dueDate: today,
      lapses: (progress.lapses ?? 0) + (progress.status === 'mastered' ? 1 : 0),
      reviewCount: progress.reviewCount + 1,
      lastStudied: today,
      stage: 0,
      statusUpdatedAt: changedAt,
    }),
    today,
  );
}

export function toggleFavorite(state: ProgressState, wordId: string, changedAt = createRuntimeTimestamp()): ProgressState {
  return updateWord(state, wordId, (progress) => {
    const favorite = !progress.favorite;
    return {
      ...progress,
      favorite,
      favoriteUpdatedAt: changedAt,
      favoritedAt: favorite ? changedAt : undefined,
    };
  });
}

export function mergeProgressStates(...states: Array<ProgressState | null | undefined>): ProgressState {
  const available = states.filter((state): state is ProgressState => Boolean(state));
  if (available.length === 0) {
    return {
      dailyTarget: 20,
      streak: 0,
      studiedToday: 0,
      words: {},
    };
  }

  const dailySource = available.reduce((latest, candidate) => {
    const latestDate = latest.dailyProgressDate ?? latest.lastStudyDate ?? '';
    const candidateDate = candidate.dailyProgressDate ?? candidate.lastStudyDate ?? '';
    if (candidateDate > latestDate) {
      return candidate;
    }
    if (candidateDate === latestDate && candidate.studiedToday > latest.studiedToday) {
      return candidate;
    }
    return latest;
  });

  const words: Record<string, WordProgress> = {};
  available.forEach((state) => {
    Object.entries(state.words).forEach(([wordId, wordProgress]) => {
      words[wordId] = words[wordId] ? mergeWordProgress(words[wordId], wordProgress) : wordProgress;
    });
  });

  const analytics = mergeLearningAnalyticsStates(...available.map((state) => state.analytics));
  const streak = reconcileStreakProtection(available, dailySource);
  return {
    ...(analytics ? { analytics } : {}),
    dailyProgressDate: dailySource.dailyProgressDate,
    dailyTarget: dailySource.dailyTarget,
    ...streak,
    studiedToday: dailySource.studiedToday,
    words,
  };
}

function mergeWordProgress(first: WordProgress, second: WordProgress): WordProgress {
  const firstStatusTime = first.statusUpdatedAt ?? first.lastStudied ?? '';
  const secondStatusTime = second.statusUpdatedAt ?? second.lastStudied ?? '';
  const statusSource = secondStatusTime > firstStatusTime ? second : first;
  const firstFavoriteTime = first.favoriteUpdatedAt ?? first.favoritedAt ?? '';
  const secondFavoriteTime = second.favoriteUpdatedAt ?? second.favoritedAt ?? '';
  const favoriteSource = secondFavoriteTime > firstFavoriteTime ? second : first;
  const lastStudied = [first.lastStudied, second.lastStudied].filter((value): value is string => Boolean(value)).sort().at(-1);

  return {
    ...(statusSource.dueDate ? { dueDate: statusSource.dueDate } : {}),
    ...(typeof statusSource.stage === 'number' ? { stage: statusSource.stage } : {}),
    ...(first.lapses || second.lapses ? { lapses: Math.max(first.lapses ?? 0, second.lapses ?? 0) } : {}),
    difficult: statusSource.difficult,
    favorite: favoriteSource.favorite,
    favoriteUpdatedAt: favoriteSource.favoriteUpdatedAt,
    favoritedAt: favoriteSource.favorite ? favoriteSource.favoritedAt : undefined,
    lastStudied,
    reviewCount: Math.max(first.reviewCount, second.reviewCount),
    status: statusSource.status,
    statusUpdatedAt: statusSource.statusUpdatedAt,
  };
}

export function computeStats(words: WordEntry[], state: ProgressState, today?: string): ProgressStats {
  const { idSet } = prepareVocabulary(words);
  let due = 0;
  let mastered = 0;
  let review = 0;
  let favorites = 0;

  for (const [wordId, wordProgress] of Object.entries(state.words)) {
    if (!idSet.has(wordId)) {
      continue;
    }
    if (wordProgress.status === 'mastered') {
      mastered += 1;
    } else if (wordProgress.status === 'review') {
      review += 1;
    }
    if (wordProgress.favorite) {
      favorites += 1;
    }
    if (today && isWordDue(wordProgress, today)) {
      due += 1;
    }
  }

  return {
    due,
    mastered,
    review,
    favorites,
    remaining: words.length - mastered - review,
    studiedToday: state.studiedToday,
  };
}

export function filterWords(
  words: WordEntry[],
  state: ProgressState,
  query: string,
  filter: LibraryFilter,
  options: LibraryFilterOptions = {},
): WordEntry[] {
  const normalizedQuery = query.trim().toLowerCase();
  const queryTerms = normalizedQuery.length > 0 ? normalizedQuery.split(/\s+/).filter(Boolean) : [];
  const level = options.level && options.level !== 'all' ? options.level : null;
  const initial = options.initial && options.initial !== 'all' ? options.initial.toUpperCase() : null;
  const sort = options.sort ?? 'default';

  const prepared = prepareVocabulary(words);
  if (queryTerms.length === 0 && filter === 'all' && !level && !initial) {
    return sort === 'alphabetical' ? prepared.alphabeticalWords : words;
  }

  const searchable = prepareSearchRecords(prepared, words);
  const sourceRecords = sort === 'alphabetical' ? searchable.alphabeticalRecords : searchable.records;
  const matches: Array<{ preparedWord: PreparedWord; progress: WordProgress; score: number }> = [];

  for (const preparedWord of sourceRecords) {
    const { word } = preparedWord;
    if (level && word.group !== level) {
      continue;
    }
    if (initial && !preparedWord.normalizedWord.toUpperCase().startsWith(initial)) {
      continue;
    }

    const score = searchScore(preparedWord, queryTerms);
    if (queryTerms.length > 0 && score === 0) {
      continue;
    }

    const progress = currentProgress(state, word.id);
    if (filter === 'favorites' && !progress.favorite) {
      continue;
    }
    if (filter === 'review' && progress.status !== 'review') {
      continue;
    }
    if (filter === 'mastered' && progress.status !== 'mastered') {
      continue;
    }
    if (filter === 'new' && progress.status !== 'new') {
      continue;
    }

    matches.push({ preparedWord, progress, score });
  }

  if (sort !== 'alphabetical' && (queryTerms.length > 0 || filter === 'favorites' || filter === 'review' || filter === 'mastered')) {
    matches.sort((a, b) => {
      if (queryTerms.length > 0 && b.score !== a.score) {
        return b.score - a.score;
      }

      const bTime = recencyTimeForFilter(b.progress, filter);
      const aTime = recencyTimeForFilter(a.progress, filter);
      if (bTime !== aTime) {
        return bTime - aTime;
      }

      return a.preparedWord.index - b.preparedWord.index;
    });
  }

  return matches.map(({ preparedWord }) => preparedWord.word);
}

function prepareVocabulary(words: WordEntry[]): PreparedVocabulary {
  const cached = preparedVocabularyCache.get(words);
  if (cached) {
    return cached;
  }

  const indexById = new Map(words.map(({ id }, index) => [id, index]));
  const alphabeticalWords = [...words].sort((a, b) => {
    const wordOrder = a.word.localeCompare(b.word, 'en', { sensitivity: 'base' });
    return wordOrder !== 0 ? wordOrder : (indexById.get(a.id) ?? 0) - (indexById.get(b.id) ?? 0);
  });
  const prepared = {
    alphabeticalRecords: null,
    alphabeticalWords,
    idSet: new Set(words.map(({ id }) => id)),
    indexById,
    records: null,
  };

  preparedVocabularyCache.set(words, prepared);
  return prepared;
}

function prepareSearchRecords(
  prepared: PreparedVocabulary,
  words: WordEntry[],
): { alphabeticalRecords: PreparedWord[]; records: PreparedWord[] } {
  if (prepared.records && prepared.alphabeticalRecords) {
    return {
      alphabeticalRecords: prepared.alphabeticalRecords,
      records: prepared.records,
    };
  }

  const records = words.map((word, index) => ({
    example: word.example.toLowerCase(),
    exampleZh: word.exampleZh.toLowerCase(),
    index,
    meaning: `${word.meaningZh} ${word.supplementalMeaningZh ?? ''}`.trim().toLowerCase(),
    normalizedWord: word.word.toLowerCase(),
    word,
  }));
  const alphabeticalRecords = prepared.alphabeticalWords
    .map((word) => records[prepared.indexById.get(word.id) ?? -1])
    .filter((record): record is PreparedWord => Boolean(record));
  prepared.records = records;
  prepared.alphabeticalRecords = alphabeticalRecords;
  return { alphabeticalRecords, records };
}

function searchScore(word: PreparedWord, terms: string[]): number {
  if (terms.length === 0) {
    return 0;
  }

  let total = 0;
  for (const term of terms) {
    const score = searchTermScore(word, term);
    if (score === 0) {
      return 0;
    }
    total += score;
  }
  return total;
}

function searchTermScore(word: PreparedWord, term: string): number {
  const english = word.normalizedWord;
  const meaning = word.meaning;
  const example = word.example;
  const exampleZh = word.exampleZh;

  if (english === term) {
    return 1000;
  }
  if (english.startsWith(term)) {
    return 900;
  }
  if (english.includes(term)) {
    return 760;
  }
  if (meaning.includes(term)) {
    return 680;
  }
  if (example.includes(term)) {
    return 540;
  }
  if (exampleZh.includes(term)) {
    return 520;
  }
  return 0;
}

function recencyTimeForFilter(progress: WordProgress, filter: LibraryFilter): number {
  const value =
    filter === 'favorites'
      ? progress.favoritedAt
      : filter === 'review' || filter === 'mastered'
        ? progress.statusUpdatedAt ?? progress.lastStudied
        : undefined;

  if (!value) {
    return 0;
  }

  const parsed = Date.parse(value);
  return Number.isFinite(parsed) ? parsed : 0;
}

export function selectQuizWords(
  words: WordEntry[],
  state: ProgressState,
  filter: LibraryFilter,
  options: LibraryFilterOptions = {},
): WordEntry[] {
  return filterWords(words, state, '', filter, options);
}

export function selectStudyWords(
  words: WordEntry[],
  state: ProgressState,
  filter: LibraryFilter,
  options: LibraryFilterOptions = {},
): WordEntry[] {
  return filterWords(words, state, '', filter, options);
}

export function buildStudySession(words: WordEntry[], seed = createRuntimeSeed()): WordEntry[] {
  return shuffleWithSeed(words, seed);
}

export function normalizeProgressForDate(state: ProgressState, today: string): ProgressState {
  const nextState =
    state.dailyProgressDate === today
      ? state
      : {
          ...state,
          dailyProgressDate: today,
          studiedToday: 0,
        };

  if (!nextState.lastStudyDate || nextState.lastStudyDate === today || isPreviousDate(nextState.lastStudyDate, today)) {
    return nextState;
  }

  const missed = addDays(today, -1);
  if (nextState.streak > 0 && missed && isPreviousDate(nextState.lastStudyDate, missed)
      && streakProtectionCovers(missed, nextState.streakFreezeDate)) {
    return { ...nextState, streakFreezeDate: missed };
  }

  return {
    ...nextState,
    streak: 0,
  };
}

export const STREAK_PROTECTION_COOLDOWN_DAYS = 7;

function streakProtectionCovers(missed: string, freezeDate?: string): boolean {
  const missedDay = dateOnlyToDayNumber(missed);
  if (missedDay === null) return false;
  const usedDay = freezeDate ? dateOnlyToDayNumber(freezeDate) : null;
  return usedDay === null || usedDay === missedDay || missedDay - usedDay >= STREAK_PROTECTION_COOLDOWN_DAYS;
}

/** Reconcile only evidenced study-day continuity, then expire at the latest observed day. */
export function reconcileStreakProtection(
  states: ProgressState[],
  fallback: ProgressState,
): Pick<ProgressState, 'streak' | 'lastStudyDate' | 'streakFreezeDate'> {
  const latestValidDate = (dates: Array<string | undefined>) => dates
    .filter((date): date is string => typeof date === 'string' && dateOnlyToDayNumber(date) !== null)
    .sort().at(-1);
  let streakFreezeDate = latestValidDate(states.map((state) => state.streakFreezeDate));
  const lastStudyDate = latestValidDate(states.map((state) => state.lastStudyDate));
  if (!lastStudyDate) {
    return { streak: fallback.streak, lastStudyDate: fallback.lastStudyDate, ...(streakFreezeDate ? { streakFreezeDate } : {}) };
  }

  let streak = 0;
  let protectedStreak = 0;
  const lastDay = dateOnlyToDayNumber(lastStudyDate)!;
  for (const state of states) {
    const sourceDay = state.lastStudyDate ? dateOnlyToDayNumber(state.lastStudyDate) : null;
    if (sourceDay === null || state.streak <= 0) continue;
    const gap = lastDay - sourceDay;
    if (gap === 0 || gap === 1) {
      streak = Math.max(streak, state.streak + gap);
    } else if (gap === 2) {
      protectedStreak = Math.max(protectedStreak, state.streak + 1);
    }
  }
  // A newer count may already include study on the intervening day. Do not
  // spend protection on a stale snapshot that cannot improve that count.
  const missed = addDays(lastStudyDate, -1)!;
  if (protectedStreak > streak && streakProtectionCovers(missed, streakFreezeDate)) {
    streak = protectedStreak;
    streakFreezeDate = missed;
  }

  const observedDay = latestValidDate(states.flatMap((state) => [state.dailyProgressDate, state.lastStudyDate]))!;
  const normalized = normalizeProgressForDate({ ...fallback, streak, lastStudyDate, streakFreezeDate }, observedDay);
  return {
    streak: normalized.streak,
    lastStudyDate,
    ...(normalized.streakFreezeDate ? { streakFreezeDate: normalized.streakFreezeDate } : {}),
  };
}

export function buildQuizSession(words: WordEntry[], requestedCount: number, seed = createRuntimeSeed()): WordEntry[] {
  const count = Math.max(0, Math.min(requestedCount, words.length));
  if (count === 0) {
    return [];
  }
  if (count === words.length || count > words.length / 3) {
    return shuffleWithSeed(words, seed).slice(0, count);
  }

  const selectedIndexes = sampleDistinctIndexes(words.length, count, `${seed}:session`);
  return selectedIndexes.map((index) => words[index]);
}

const QUIZ_OPTION_COUNT = 4;
const QUIZ_DISTRACTOR_SAMPLE = 48;

export function buildQuizOptions(
  words: WordEntry[],
  wordId: string,
  seed = createRuntimeSeed(),
  answerMode: QuizAnswerMode = 'meaning',
): QuizOption[] {
  const prepared = prepareVocabulary(words);
  const correctIndex = prepared.indexById.get(wordId) ?? 0;
  const correctWord = words[correctIndex];
  if (!correctWord) {
    return [];
  }

  const correctText = answerTextForMode(correctWord, answerMode);
  // Distractors are drawn from a random sample and then ranked by how
  // plausible they are next to the answer: same part of speech first, then the
  // same level. Random unrelated words made most questions guessable from the
  // grammar alone. Duplicate answer texts are dropped so two words that share
  // a meaning can never both look correct.
  const correctPos = primaryPartOfSpeech(correctWord.partOfSpeech);
  const candidates = sampleDistinctIndexes(
    words.length,
    Math.min(QUIZ_DISTRACTOR_SAMPLE, Math.max(0, words.length - 1)),
    `${seed}:wrong:${wordId}`,
    correctIndex,
  ).map((index, order) => {
    const word = words[index];
    const score = (primaryPartOfSpeech(word.partOfSpeech) === correctPos ? 2 : 0) + (word.group === correctWord.group ? 1 : 0);
    return { order, score, word };
  });
  candidates.sort((left, right) => right.score - left.score || left.order - right.order);

  const usedTexts = new Set([correctText]);
  const wrongOptions: QuizOption[] = [];
  for (const candidate of candidates) {
    if (wrongOptions.length >= QUIZ_OPTION_COUNT - 1) {
      break;
    }
    const text = answerTextForMode(candidate.word, answerMode);
    if (!text || usedTexts.has(text)) {
      continue;
    }
    usedTexts.add(text);
    wrongOptions.push({ correct: false, meaning: text });
  }

  return shuffleWithSeed([{ correct: true, meaning: correctText }, ...wrongOptions], `${seed}:options:${wordId}`);
}

function primaryPartOfSpeech(partOfSpeech: string): string {
  const first = partOfSpeech.split(/[\s/,.]+/).find(Boolean)?.toLowerCase() ?? '';
  // vt, vi and v are all verbs as far as a plausible wrong answer goes.
  return first.startsWith('v') ? 'v' : first;
}

export type StudyQueueOptions = {
  limit: number;
  seed?: string;
};

/**
 * Picks the cards for one study session. Words that are due for review come
 * first (oldest due date first), then words never seen before picked at
 * random from the whole pool, and only when both run out does it pull known
 * words ahead of their schedule. New words used to come in library order, so
 * with "all levels" every session was Core 1. The chosen cards are then
 * shuffled so reviews and new words mix.
 */
export function buildStudyQueue(
  words: WordEntry[],
  state: ProgressState,
  today: string,
  { limit, seed = createRuntimeSeed() }: StudyQueueOptions,
): WordEntry[] {
  const size = Math.max(0, Math.floor(limit));
  if (size === 0 || words.length === 0) {
    return [];
  }

  const due: Array<{ date: string; word: WordEntry; struggling: boolean }> = [];
  const fresh: WordEntry[] = [];
  const ahead: Array<{ date: string; word: WordEntry }> = [];
  for (const word of words) {
    const progress = state.words[word.id];
    const dueDate = reviewDueDate(progress);
    if (dueDate === null) {
      fresh.push(word);
    } else if (dueDate <= today) {
      due.push({ date: dueDate, struggling: progress?.status === 'review', word });
    } else {
      ahead.push({ date: dueDate, word });
    }
  }

  due.sort((left, right) => left.date.localeCompare(right.date) || Number(right.struggling) - Number(left.struggling));
  ahead.sort((left, right) => left.date.localeCompare(right.date));
  const chosen = [
    ...due.map((entry) => entry.word),
    ...shuffleWithSeed(fresh, `${seed}:fresh`),
    ...ahead.map((entry) => entry.word),
  ].slice(0, size);

  return shuffleWithSeed(chosen, `${seed}:queue`);
}

export function countDueWords(words: WordEntry[], state: ProgressState, today: string): number {
  return computeStats(words, state, today).due;
}

function answerTextForMode(word: WordEntry, answerMode: QuizAnswerMode): string {
  return answerMode === 'word' ? word.word : word.meaningZh;
}

function advanceDailyProgress(state: ProgressState, today: string, increment = 1): ProgressState {
  const normalized = normalizeProgressForDate(state, today);
  const alreadyStudiedToday = normalized.lastStudyDate === today;
  const nextStreak = alreadyStudiedToday
    ? normalized.streak
    : normalized.lastStudyDate && (isPreviousDate(normalized.lastStudyDate, today)
      || (normalized.streakFreezeDate && isPreviousDate(normalized.lastStudyDate, normalized.streakFreezeDate)
        && isPreviousDate(normalized.streakFreezeDate, today)))
      ? Math.max(1, normalized.streak + 1)
      : 1;

  return {
    ...normalized,
    dailyProgressDate: today,
    lastStudyDate: today,
    streak: nextStreak,
    studiedToday: normalized.studiedToday + increment,
  };
}

export function addDays(date: string, days: number): string | null {
  const dayNumber = dateOnlyToDayNumber(date);
  if (dayNumber === null) {
    return null;
  }
  return new Date((dayNumber + days) * 86_400_000).toISOString().slice(0, 10);
}

function isPreviousDate(previousDate: string, today: string): boolean {
  const previous = dateOnlyToDayNumber(previousDate);
  const current = dateOnlyToDayNumber(today);
  return previous !== null && current !== null && current - previous === 1;
}

function dateOnlyToDayNumber(value: string): number | null {
  const match = value.match(/^(\d{4})-(\d{2})-(\d{2})$/);
  if (!match) {
    return null;
  }

  const year = Number(match[1]);
  const month = Number(match[2]);
  const day = Number(match[3]);
  const time = Date.UTC(year, month - 1, day);
  const date = new Date(time);

  if (date.getUTCFullYear() !== year || date.getUTCMonth() !== month - 1 || date.getUTCDate() !== day) {
    return null;
  }

  return Math.floor(time / 86_400_000);
}

function shuffleWithSeed<T>(values: T[], seed: string): T[] {
  const shuffled = [...values];
  let randomState = hashText(seed || 'word7000');

  for (let index = shuffled.length - 1; index > 0; index -= 1) {
    randomState = nextRandomState(randomState);
    const swapIndex = scrambleRandomState(randomState) % (index + 1);
    [shuffled[index], shuffled[swapIndex]] = [shuffled[swapIndex], shuffled[index]];
  }

  return shuffled;
}

function sampleDistinctIndexes(length: number, count: number, seed: string, excludedIndex = -1): number[] {
  if (length <= 0 || count <= 0) {
    return [];
  }

  const selected = new Set<number>();
  let randomState = hashText(seed || 'word7000');
  const targetCount = Math.min(count, length - (excludedIndex >= 0 ? 1 : 0));

  while (selected.size < targetCount) {
    randomState = nextRandomState(randomState);
    const index = scrambleRandomState(randomState) % length;
    if (index !== excludedIndex) {
      selected.add(index);
    }
  }

  return [...selected];
}

function nextRandomState(value: number): number {
  return (value * 1664525 + 1013904223) >>> 0;
}

// The low bits of a power-of-two LCG barely change (bit 0 just alternates), so
// taking `state % n` directly left whole orderings unreachable: four quiz
// options only ever came out in 12 of their 24 orders, with the answer first a
// third of the time. Mixing the high bits down (murmur3's finalizer) fixes that.
function scrambleRandomState(value: number): number {
  let mixed = value;
  mixed ^= mixed >>> 16;
  mixed = Math.imul(mixed, 0x85ebca6b);
  mixed ^= mixed >>> 13;
  mixed = Math.imul(mixed, 0xc2b2ae35);
  mixed ^= mixed >>> 16;
  return mixed >>> 0;
}

function hashText(value: string): number {
  let hash = 2166136261;
  for (let index = 0; index < value.length; index += 1) {
    hash ^= value.charCodeAt(index);
    hash = Math.imul(hash, 16777619);
  }
  return hash >>> 0;
}

function createRuntimeSeed(): string {
  return `${Date.now()}:${Math.random()}`;
}

function createRuntimeTimestamp(): string {
  return new Date().toISOString();
}
