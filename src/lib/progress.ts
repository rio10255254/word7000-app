import type { WordEntry } from '../data/words';

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
  favoritedAt?: string;
  lastStudied?: string;
  statusUpdatedAt?: string;
};

export type ProgressState = {
  dailyTarget: number;
  streak: number;
  studiedToday: number;
  dailyProgressDate?: string;
  lastStudyDate?: string;
  words: Record<string, WordProgress>;
};

export type ProgressStats = {
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
  const baseState = studiedDate ? advanceDailyProgress(state, studiedDate) : state;

  return {
    ...baseState,
    words: {
      ...baseState.words,
      [wordId]: update(currentProgress(baseState, wordId)),
    },
  };
}

export function markKnown(state: ProgressState, wordId: string, today: string, changedAt = createRuntimeTimestamp()): ProgressState {
  return updateWord(
    state,
    wordId,
    (progress) => ({
      ...progress,
      status: 'mastered',
      difficult: false,
      lastStudied: today,
      statusUpdatedAt: changedAt,
    }),
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
      reviewCount: progress.reviewCount + 1,
      lastStudied: today,
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
      favoritedAt: favorite ? changedAt : undefined,
    };
  });
}

export function computeStats(words: WordEntry[], state: ProgressState): ProgressStats {
  const values = words.map((word) => currentProgress(state, word.id));
  const mastered = values.filter((progress) => progress.status === 'mastered').length;
  const review = values.filter((progress) => progress.status === 'review').length;
  const favorites = values.filter((progress) => progress.favorite).length;

  return {
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

  return words
    .map((word, index) => ({ index, progress: currentProgress(state, word.id), score: searchScore(word, queryTerms), word }))
    .filter(({ progress, score, word }) => {
      const matchesQuery = queryTerms.length === 0 || score > 0;

      if (!matchesQuery) {
        return false;
      }

      if (level && word.group !== level) {
        return false;
      }

      if (initial && !word.word.toUpperCase().startsWith(initial)) {
        return false;
      }

      if (filter === 'favorites') {
        return progress.favorite;
      }
      if (filter === 'review') {
        return progress.status === 'review';
      }
      if (filter === 'mastered') {
        return progress.status === 'mastered';
      }
      if (filter === 'new') {
        return progress.status === 'new';
      }

      return true;
    })
    .sort((a, b) => {
      if (sort === 'alphabetical') {
        const wordOrder = a.word.word.localeCompare(b.word.word, 'en', { sensitivity: 'base' });
        if (wordOrder !== 0) {
          return wordOrder;
        }
      }

      if (queryTerms.length > 0 && b.score !== a.score) {
        return b.score - a.score;
      }

      const bTime = recencyTimeForFilter(b.progress, filter);
      const aTime = recencyTimeForFilter(a.progress, filter);
      if (bTime !== aTime) {
        return bTime - aTime;
      }

      return a.index - b.index;
    })
    .map(({ word }) => word);
}

function searchScore(word: WordEntry, terms: string[]): number {
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

function searchTermScore(word: WordEntry, term: string): number {
  const english = word.word.toLowerCase();
  const meaning = word.meaningZh.toLowerCase();
  const example = word.example.toLowerCase();
  const exampleZh = word.exampleZh.toLowerCase();

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

  return {
    ...nextState,
    streak: 0,
  };
}

export function buildQuizSession(words: WordEntry[], requestedCount: number, seed = createRuntimeSeed()): WordEntry[] {
  const count = Math.max(0, Math.min(requestedCount, words.length));
  return shuffleWithSeed(words, seed).slice(0, count);
}

export function buildQuizOptions(
  words: WordEntry[],
  wordId: string,
  seed = createRuntimeSeed(),
  answerMode: QuizAnswerMode = 'meaning',
): QuizOption[] {
  const correctWord = words.find((word) => word.id === wordId) ?? words[0];
  if (!correctWord) {
    return [];
  }

  const wrongOptions = shuffleWithSeed(
    words.filter((word) => word.id !== correctWord.id),
    `${seed}:wrong:${wordId}`,
  )
    .slice(0, 2)
    .map((word) => ({
      meaning: answerTextForMode(word, answerMode),
      correct: false,
    }));

  const correctOption = {
    meaning: answerTextForMode(correctWord, answerMode),
    correct: true,
  };

  return shuffleWithSeed([correctOption, ...wrongOptions], `${seed}:options:${wordId}`);
}

function answerTextForMode(word: WordEntry, answerMode: QuizAnswerMode): string {
  return answerMode === 'word' ? word.word : word.meaningZh;
}

function advanceDailyProgress(state: ProgressState, today: string): ProgressState {
  const normalized = normalizeProgressForDate(state, today);
  const alreadyStudiedToday = normalized.lastStudyDate === today;
  const nextStreak = alreadyStudiedToday
    ? normalized.streak
    : normalized.lastStudyDate && isPreviousDate(normalized.lastStudyDate, today)
      ? Math.max(1, normalized.streak + 1)
      : 1;

  return {
    ...normalized,
    dailyProgressDate: today,
    lastStudyDate: today,
    streak: nextStreak,
    studiedToday: normalized.studiedToday + 1,
  };
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
    const swapIndex = randomState % (index + 1);
    [shuffled[index], shuffled[swapIndex]] = [shuffled[swapIndex], shuffled[index]];
  }

  return shuffled;
}

function nextRandomState(value: number): number {
  return (value * 1664525 + 1013904223) >>> 0;
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
