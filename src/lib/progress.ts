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
  favoriteUpdatedAt?: string;
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

type PreparedWord = {
  example: string;
  exampleZh: string;
  index: number;
  meaning: string;
  normalizedWord: string;
  word: WordEntry;
};

type PreparedVocabulary = {
  alphabeticalRecords: PreparedWord[];
  alphabeticalWords: WordEntry[];
  idSet: Set<string>;
  indexById: Map<string, number>;
  records: PreparedWord[];
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

  return {
    dailyProgressDate: dailySource.dailyProgressDate,
    dailyTarget: dailySource.dailyTarget,
    lastStudyDate: dailySource.lastStudyDate,
    streak: dailySource.streak,
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

export function computeStats(words: WordEntry[], state: ProgressState): ProgressStats {
  const { idSet } = prepareVocabulary(words);
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
  }

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

  const prepared = prepareVocabulary(words);
  if (queryTerms.length === 0 && filter === 'all' && !level && !initial) {
    return sort === 'alphabetical' ? prepared.alphabeticalWords : words;
  }

  const sourceRecords = sort === 'alphabetical' ? prepared.alphabeticalRecords : prepared.records;
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

  const records = words.map((word, index) => ({
    example: word.example.toLowerCase(),
    exampleZh: word.exampleZh.toLowerCase(),
    index,
    meaning: word.meaningZh.toLowerCase(),
    normalizedWord: word.word.toLowerCase(),
    word,
  }));
  const alphabeticalRecords = [...records].sort((a, b) => {
    const wordOrder = a.word.word.localeCompare(b.word.word, 'en', { sensitivity: 'base' });
    return wordOrder !== 0 ? wordOrder : a.index - b.index;
  });
  const prepared = {
    alphabeticalRecords,
    alphabeticalWords: alphabeticalRecords.map(({ word }) => word),
    idSet: new Set(words.map(({ id }) => id)),
    indexById: new Map(words.map(({ id }, index) => [id, index])),
    records,
  };

  preparedVocabularyCache.set(words, prepared);
  return prepared;
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

  return {
    ...nextState,
    streak: 0,
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

  const wrongOptions = sampleDistinctIndexes(words.length, Math.min(2, Math.max(0, words.length - 1)), `${seed}:wrong:${wordId}`, correctIndex)
    .map((index) => words[index])
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

function sampleDistinctIndexes(length: number, count: number, seed: string, excludedIndex = -1): number[] {
  if (length <= 0 || count <= 0) {
    return [];
  }

  const selected = new Set<number>();
  let randomState = hashText(seed || 'word7000');
  const targetCount = Math.min(count, length - (excludedIndex >= 0 ? 1 : 0));

  while (selected.size < targetCount) {
    randomState = nextRandomState(randomState);
    const index = randomState % length;
    if (index !== excludedIndex) {
      selected.add(index);
    }
  }

  return [...selected];
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
