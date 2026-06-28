import type { WordEntry } from '../data/words';

export type WordStatus = 'new' | 'mastered' | 'review';
export type LibraryFilter = 'all' | 'favorites' | 'review' | 'mastered' | 'new';
export type LibraryFilterOptions = {
  initial?: string;
  level?: string;
};

export type WordProgress = {
  status: WordStatus;
  favorite: boolean;
  difficult: boolean;
  reviewCount: number;
  lastStudied?: string;
};

export type ProgressState = {
  dailyTarget: number;
  streak: number;
  studiedToday: number;
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
  countAsStudied = false,
): ProgressState {
  return {
    ...state,
    studiedToday: countAsStudied ? state.studiedToday + 1 : state.studiedToday,
    words: {
      ...state.words,
      [wordId]: update(currentProgress(state, wordId)),
    },
  };
}

export function markKnown(state: ProgressState, wordId: string, today: string): ProgressState {
  return updateWord(
    state,
    wordId,
    (progress) => ({
      ...progress,
      status: 'mastered',
      difficult: false,
      lastStudied: today,
    }),
    true,
  );
}

export function markReview(state: ProgressState, wordId: string, today: string): ProgressState {
  return updateWord(
    state,
    wordId,
    (progress) => ({
      ...progress,
      status: 'review',
      difficult: true,
      reviewCount: progress.reviewCount + 1,
      lastStudied: today,
    }),
    true,
  );
}

export function toggleFavorite(state: ProgressState, wordId: string): ProgressState {
  return updateWord(state, wordId, (progress) => ({
    ...progress,
    favorite: !progress.favorite,
  }));
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
  const level = options.level && options.level !== 'all' ? options.level : null;
  const initial = options.initial && options.initial !== 'all' ? options.initial.toUpperCase() : null;

  return words.filter((word) => {
    const progress = currentProgress(state, word.id);
    const matchesQuery =
      normalizedQuery.length === 0 ||
      word.word.toLowerCase().includes(normalizedQuery) ||
      word.meaningZh.toLowerCase().includes(normalizedQuery) ||
      word.example.toLowerCase().includes(normalizedQuery);

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
  });
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

export function buildQuizSession(words: WordEntry[], requestedCount: number, seed = createRuntimeSeed()): WordEntry[] {
  const count = Math.max(0, Math.min(requestedCount, words.length));
  return shuffleWithSeed(words, seed).slice(0, count);
}

export function buildQuizOptions(words: WordEntry[], wordId: string, seed = createRuntimeSeed()): QuizOption[] {
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
      meaning: word.meaningZh,
      correct: false,
    }));

  const correctOption = {
    meaning: correctWord.meaningZh,
    correct: true,
  };

  return shuffleWithSeed([correctOption, ...wrongOptions], `${seed}:options:${wordId}`);
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
