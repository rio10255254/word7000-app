import type { WordEntry } from '../data/words';

export const CUSTOM_SETS_STORAGE_KEY = 'word7000-custom-sets-v1';

export type CustomSetSort = 'manual' | 'name' | 'recent';

export type CustomVocabSet = {
  color: string;
  createdAt: string;
  id: string;
  name: string;
  sortOrder: number;
  updatedAt: string;
  wordIds: string[];
};

export type CustomSetState = {
  customWords: WordEntry[];
  sets: CustomVocabSet[];
};

export type CustomWordsImportResult = {
  errors: string[];
  ok: boolean;
  rows: Record<string, string>[];
};

export type CustomWordsApplyResult = {
  errors: string[];
  words: WordEntry[];
};

type StorageLike = {
  getItem: (key: string) => string | null;
  removeItem?: (key: string) => void;
  setItem: (key: string, value: string) => void;
};

const setColors = ['#2563eb', '#0f766e', '#7c3aed', '#db2777', '#ea580c', '#16a34a'];

export const emptyCustomSetState: CustomSetState = {
  customWords: [],
  sets: [],
};

export function createCustomSet(
  state: CustomSetState,
  name: string,
  now = createRuntimeTimestamp(),
): CustomSetState {
  const cleanName = name.trim() || '我的單字集';
  const id = uniqueSetId(state.sets, cleanName, now);

  return {
    ...state,
    sets: [
      ...state.sets,
      {
        color: setColors[state.sets.length % setColors.length],
        createdAt: now,
        id,
        name: cleanName,
        sortOrder: state.sets.length + 1,
        updatedAt: now,
        wordIds: [],
      },
    ],
  };
}

export function addWordToSet(
  state: CustomSetState,
  setId: string,
  wordId: string,
  now = createRuntimeTimestamp(),
): CustomSetState {
  return {
    ...state,
    sets: state.sets.map((set) => {
      if (set.id !== setId) {
        return set;
      }

      const wordIds = set.wordIds.includes(wordId) ? set.wordIds : [wordId, ...set.wordIds];
      return {
        ...set,
        updatedAt: now,
        wordIds,
      };
    }),
  };
}

export function addCustomWordToSet(
  state: CustomSetState,
  setId: string,
  word: WordEntry,
  now = createRuntimeTimestamp(),
): CustomSetState {
  const existingIndex = state.customWords.findIndex((item) => item.id === word.id);
  const customWords =
    existingIndex >= 0
      ? state.customWords.map((item, index) => (index === existingIndex ? word : item))
      : [word, ...state.customWords];

  return addWordToSet({ ...state, customWords }, setId, word.id, now);
}

export function sortCustomSets(sets: CustomVocabSet[], sort: CustomSetSort): CustomVocabSet[] {
  return [...sets].sort((a, b) => {
    if (sort === 'name') {
      const nameOrder = a.name.localeCompare(b.name, undefined, { sensitivity: 'base' });
      if (nameOrder !== 0) {
        return nameOrder;
      }
    }

    if (sort === 'recent') {
      const recentOrder = Date.parse(b.updatedAt) - Date.parse(a.updatedAt);
      if (recentOrder !== 0) {
        return recentOrder;
      }
    }

    const manualOrder = a.sortOrder - b.sortOrder;
    return manualOrder !== 0 ? manualOrder : a.createdAt.localeCompare(b.createdAt);
  });
}

export function wordsForCustomSet(allWords: WordEntry[], set: CustomVocabSet | null | undefined): WordEntry[] {
  if (!set) {
    return [];
  }

  const byId = new Map(allWords.map((word) => [word.id, word]));
  return set.wordIds.flatMap((wordId) => {
    const word = byId.get(wordId);
    return word ? [word] : [];
  });
}

export function mergeCustomWords(baseWords: WordEntry[], customWords: WordEntry[]): WordEntry[] {
  const baseIds = new Set(baseWords.map((word) => word.id));
  const baseNames = new Set(baseWords.map((word) => word.word.toLowerCase()));
  const uniqueCustomWords = customWords.filter(
    (word) => !baseIds.has(word.id) && !baseNames.has(word.word.toLowerCase()),
  );
  return [...uniqueCustomWords, ...baseWords];
}

export function mergeCustomSetStates(...states: Array<CustomSetState | null | undefined>): CustomSetState {
  const customWords: WordEntry[] = [];
  const wordKeys = new Set<string>();
  const sets: CustomVocabSet[] = [];
  const setIndexById = new Map<string, number>();

  states.forEach((state) => {
    if (!state) {
      return;
    }

    state.customWords.forEach((word) => {
      const key = `${word.id}:${word.word.toLowerCase()}`;
      if (wordKeys.has(key)) {
        return;
      }

      wordKeys.add(key);
      customWords.push(word);
    });

    state.sets.forEach((set) => {
      const existingIndex = setIndexById.get(set.id);
      if (existingIndex === undefined) {
        setIndexById.set(set.id, sets.length);
        sets.push(set);
        return;
      }

      const existing = sets[existingIndex];
      const setIsNewer = Date.parse(set.updatedAt) >= Date.parse(existing.updatedAt);
      const base = setIsNewer ? set : existing;
      const secondary = setIsNewer ? existing : set;
      sets[existingIndex] = {
        ...base,
        wordIds: uniqueWordIds([...base.wordIds, ...secondary.wordIds]),
      };
    });
  });

  return {
    customWords,
    sets,
  };
}

export function parseCustomWordsCsv(text: string): CustomWordsImportResult {
  const table = parseCsvTable(text.trim());
  if (table.length < 2) {
    return { errors: ['CSV 至少需要標題列和一筆資料。'], ok: false, rows: [] };
  }

  const headers = table[0].map(normalizeHeader);
  if (!headers.includes('word') || !headers.some((header) => header === 'meaning' || header === 'meaningzh')) {
    return { errors: ['CSV 需要 word 和 meaning 欄位。'], ok: false, rows: [] };
  }

  const rows = table.slice(1).flatMap((cells) => {
    const row: Record<string, string> = {};
    headers.forEach((header, index) => {
      const value = cells[index]?.trim();
      if (value) {
        row[header] = value;
      }
    });
    return Object.keys(row).length > 0 ? [row] : [];
  });

  return { errors: [], ok: true, rows };
}

export function customWordsFromImportRows(
  rows: Record<string, string>[],
  existingWords: WordEntry[],
): CustomWordsApplyResult {
  const existingNames = new Set(existingWords.map((word) => word.word.toLowerCase()));
  const createdNames = new Set<string>();
  const words: WordEntry[] = [];
  const errors: string[] = [];

  rows.forEach((row, index) => {
    const word = row.word?.trim();
    const meaningZh = (row.meaningzh ?? row.meaning ?? '').trim();
    if (!word || !meaningZh) {
      errors.push(`第 ${index + 1} 筆缺少 word 或 meaning。`);
      return;
    }

    const key = word.toLowerCase();
    if (existingNames.has(key) || createdNames.has(key)) {
      errors.push(`${word} 已存在，已略過。`);
      return;
    }

    createdNames.add(key);
    words.push({
      example: row.example?.trim() || `I want to remember the word ${word}.`,
      exampleZh: row.examplezh?.trim() || `我想記住 ${word} 這個單字。`,
      group: row.group?.trim() || 'Custom',
      id: row.id?.trim() || `custom-${word.toLowerCase().replace(/[^a-z0-9]+/g, '-')}`,
      meaningZh,
      partOfSpeech: row.partofspeech?.trim() || row.pos?.trim() || 'n',
      pronunciation: row.pronunciation?.trim() || `/${word}/`,
      word,
    });
  });

  return { errors, words };
}

export function loadCustomSetState(storage: StorageLike | undefined, userId?: string | null): CustomSetState {
  if (!storage) {
    return emptyCustomSetState;
  }

  try {
    const stored = storage.getItem(customSetStorageKey(userId));
    if (!stored) {
      return emptyCustomSetState;
    }

    const parsed: unknown = JSON.parse(stored);
    return isCustomSetState(parsed) ? parsed : emptyCustomSetState;
  } catch {
    return emptyCustomSetState;
  }
}

export function saveCustomSetState(
  storage: StorageLike | undefined,
  state: CustomSetState,
  userId?: string | null,
): void {
  try {
    storage?.setItem(customSetStorageKey(userId), JSON.stringify(state));
  } catch {
    // Local custom sets should never block the rest of the app.
  }
}

export function customSetStorageKey(userId?: string | null): string {
  return userId ? `${CUSTOM_SETS_STORAGE_KEY}:user:${userId}` : CUSTOM_SETS_STORAGE_KEY;
}

function uniqueSetId(sets: CustomVocabSet[], name: string, now: string): string {
  const base = `set-${name.replace(/\s+/g, '-')}-${Date.parse(now) || Date.now()}`;
  const ids = new Set(sets.map((set) => set.id));
  if (!ids.has(base)) {
    return base;
  }

  let suffix = 2;
  while (ids.has(`${base}-${suffix}`)) {
    suffix += 1;
  }
  return `${base}-${suffix}`;
}

function parseCsvTable(text: string): string[][] {
  const rows: string[][] = [];
  let row: string[] = [];
  let cell = '';
  let quoted = false;

  for (let index = 0; index < text.length; index += 1) {
    const char = text[index];
    const next = text[index + 1];

    if (char === '"') {
      if (quoted && next === '"') {
        cell += '"';
        index += 1;
      } else {
        quoted = !quoted;
      }
      continue;
    }

    if (char === ',' && !quoted) {
      row.push(cell);
      cell = '';
      continue;
    }

    if ((char === '\n' || char === '\r') && !quoted) {
      if (char === '\r' && next === '\n') {
        index += 1;
      }
      row.push(cell);
      rows.push(row);
      row = [];
      cell = '';
      continue;
    }

    cell += char;
  }

  row.push(cell);
  rows.push(row);
  return rows.filter((item) => item.some((value) => value.trim().length > 0));
}

export function isCustomSetState(value: unknown): value is CustomSetState {
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    return false;
  }

  const state = value as Partial<CustomSetState>;
  return Array.isArray(state.sets) && state.sets.every(isCustomSet) && Array.isArray(state.customWords);
}

function isCustomSet(value: unknown): value is CustomVocabSet {
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    return false;
  }

  const set = value as Partial<CustomVocabSet>;
  return (
    typeof set.color === 'string' &&
    typeof set.createdAt === 'string' &&
    typeof set.id === 'string' &&
    typeof set.name === 'string' &&
    typeof set.sortOrder === 'number' &&
    typeof set.updatedAt === 'string' &&
    Array.isArray(set.wordIds) &&
    set.wordIds.every((wordId) => typeof wordId === 'string')
  );
}

function normalizeHeader(value: string): string {
  return value.trim().toLowerCase().replace(/[\s_-]+/g, '');
}

function uniqueWordIds(wordIds: string[]): string[] {
  return Array.from(new Set(wordIds));
}

function createRuntimeTimestamp(): string {
  return new Date().toISOString();
}
