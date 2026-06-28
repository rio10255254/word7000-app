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
  favoritedAt?: string;
  lastStudied?: string;
  statusUpdatedAt?: string;
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
    true,
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
    true,
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

function createRuntimeTimestamp(): string {
  return new Date().toISOString();
}
