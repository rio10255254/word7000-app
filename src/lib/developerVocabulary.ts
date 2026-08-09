import type { WordEntry } from '../data/words';
import type { StorageLike } from './progressStorage';

export const DEVELOPER_VOCABULARY_STORAGE_KEY = 'word7000-developer-vocabulary-v1';

export type VocabularyImportRow = Partial<WordEntry> & {
  word?: string;
};

export type VocabularyImportResult = {
  errors: string[];
  format: 'csv' | 'json';
  ok: boolean;
  rows: VocabularyImportRow[];
};

export type VocabularyApplyResult = {
  added: number;
  errors: string[];
  updated: number;
  words: WordEntry[];
};

export type DeveloperVocabularySnapshot = {
  importedAt: string;
  summary: string;
  words: WordEntry[];
};

const csvColumns: Array<keyof WordEntry> = [
  'id',
  'word',
  'pronunciation',
  'partOfSpeech',
  'meaningZh',
  'supplementalMeaningZh',
  'example',
  'exampleZh',
  'group',
];
const editableFields: Array<keyof WordEntry> = [
  'pronunciation',
  'partOfSpeech',
  'meaningZh',
  'supplementalMeaningZh',
  'example',
  'exampleZh',
  'group',
];
const headerAliases: Record<string, keyof WordEntry> = {
  example: 'example',
  examplezh: 'exampleZh',
  example_zh: 'exampleZh',
  group: 'group',
  id: 'id',
  meaning: 'meaningZh',
  meaningzh: 'meaningZh',
  meaning_zh: 'meaningZh',
  supplementalmeaning: 'supplementalMeaningZh',
  supplementalmeaningzh: 'supplementalMeaningZh',
  supplemental_meaning_zh: 'supplementalMeaningZh',
  partofspeech: 'partOfSpeech',
  part_of_speech: 'partOfSpeech',
  pos: 'partOfSpeech',
  pronunciation: 'pronunciation',
  word: 'word',
};

export function exportWordsToCsv(words: WordEntry[]): string {
  const rows = [csvColumns.join(',')];
  for (const word of words) {
    rows.push(csvColumns.map((column) => csvCell(word[column])).join(','));
  }
  return rows.join('\n');
}

export function parseVocabularyImport(text: string, fileName = ''): VocabularyImportResult {
  const trimmed = text.trim();
  if (!trimmed) {
    return { errors: ['匯入檔案是空的。'], format: fileName.toLowerCase().endsWith('.json') ? 'json' : 'csv', ok: false, rows: [] };
  }

  if (fileName.toLowerCase().endsWith('.json') || trimmed.startsWith('{') || trimmed.startsWith('[')) {
    return parseJsonImport(trimmed);
  }

  return parseCsvImport(trimmed);
}

export function applyVocabularyImportRows(baseWords: WordEntry[], rows: VocabularyImportRow[]): VocabularyApplyResult {
  const words = baseWords.map((word) => ({ ...word }));
  const idToIndex = new Map<string, number>();
  const wordToIndex = new Map<string, number>();
  const errors: string[] = [];
  let updated = 0;
  let added = 0;

  words.forEach((word, index) => {
    idToIndex.set(word.id, index);
    wordToIndex.set(word.word.toLowerCase(), index);
  });

  rows.forEach((row, index) => {
    const rowName = row.word?.trim() || row.id?.trim() || `第 ${index + 1} 筆`;
    const existingIndex =
      row.id && idToIndex.has(row.id)
        ? idToIndex.get(row.id)
        : row.word
          ? wordToIndex.get(row.word.trim().toLowerCase())
          : undefined;

    if (existingIndex !== undefined) {
      words[existingIndex] = mergeWord(words[existingIndex], row);
      updated += 1;
      return;
    }

    const newWord = normalizeCompleteWord(row);
    if (!newWord) {
      errors.push(`${rowName} 不是既有單字，也缺少新增單字需要的完整欄位。`);
      return;
    }

    if (idToIndex.has(newWord.id) || wordToIndex.has(newWord.word.toLowerCase())) {
      errors.push(`${rowName} 的 id 或單字重複。`);
      return;
    }

    idToIndex.set(newWord.id, words.length);
    wordToIndex.set(newWord.word.toLowerCase(), words.length);
    words.push(newWord);
    added += 1;
  });

  return { added, errors, updated, words };
}

export function saveDeveloperVocabulary(storage: StorageLike | undefined, snapshot: DeveloperVocabularySnapshot): void {
  if (!storage) {
    return;
  }

  try {
    storage.setItem(DEVELOPER_VOCABULARY_STORAGE_KEY, JSON.stringify(snapshot));
  } catch {
    // Developer preview storage is optional; the app can still use the imported words in memory.
  }
}

export function loadDeveloperVocabulary(storage: StorageLike | undefined): DeveloperVocabularySnapshot | null {
  if (!storage) {
    return null;
  }

  try {
    const stored = storage.getItem(DEVELOPER_VOCABULARY_STORAGE_KEY);
    if (!stored) {
      return null;
    }
    const parsed: unknown = JSON.parse(stored);
    return isDeveloperVocabularySnapshot(parsed) ? parsed : null;
  } catch {
    return null;
  }
}

export function clearDeveloperVocabulary(storage: StorageLike | undefined): void {
  try {
    storage?.removeItem?.(DEVELOPER_VOCABULARY_STORAGE_KEY);
  } catch {
    // Ignore storage edge cases.
  }
}

function parseJsonImport(text: string): VocabularyImportResult {
  try {
    const parsed: unknown = JSON.parse(text);
    const source = Array.isArray(parsed)
      ? parsed
      : parsed && typeof parsed === 'object' && Array.isArray((parsed as { words?: unknown[] }).words)
        ? (parsed as { words: unknown[] }).words
        : null;

    if (!source) {
      return { errors: ['JSON 需要是陣列，或包含 words 陣列。'], format: 'json', ok: false, rows: [] };
    }

    const rows = source.map((item) => normalizeImportRow(item)).filter((row): row is VocabularyImportRow => Boolean(row));
    return { errors: [], format: 'json', ok: true, rows };
  } catch {
    return { errors: ['JSON 格式無法讀取。'], format: 'json', ok: false, rows: [] };
  }
}

function parseCsvImport(text: string): VocabularyImportResult {
  const table = parseCsvTable(text);
  if (table.length < 2) {
    return { errors: ['CSV 至少需要標題列和一筆資料。'], format: 'csv', ok: false, rows: [] };
  }

  const headers = table[0].map((header) => headerAliases[normalizeHeader(header)]);
  if (!headers.includes('word') && !headers.includes('id')) {
    return { errors: ['CSV 需要 word 或 id 欄位，才能對應要修改的單字。'], format: 'csv', ok: false, rows: [] };
  }

  const rows = table.slice(1).flatMap((cells) => {
    const row: VocabularyImportRow = {};
    headers.forEach((header, index) => {
      const value = cells[index]?.trim();
      if (header && value) {
        row[header] = value;
      }
    });
    return Object.keys(row).length > 0 ? [row] : [];
  });

  return { errors: [], format: 'csv', ok: true, rows };
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

function normalizeImportRow(item: unknown): VocabularyImportRow | null {
  if (!item || typeof item !== 'object' || Array.isArray(item)) {
    return null;
  }

  const source = item as Record<string, unknown>;
  const row: VocabularyImportRow = {};
  for (const [key, value] of Object.entries(source)) {
    const mappedKey = headerAliases[normalizeHeader(key)];
    if (mappedKey && typeof value === 'string' && value.trim()) {
      row[mappedKey] = value.trim();
    }
  }

  return Object.keys(row).length > 0 ? row : null;
}

function mergeWord(base: WordEntry, row: VocabularyImportRow): WordEntry {
  const merged = { ...base };
  for (const field of editableFields) {
    const value = row[field];
    if (typeof value === 'string' && value.trim()) {
      merged[field] = value.trim();
    }
  }
  return merged;
}

function normalizeCompleteWord(row: VocabularyImportRow): WordEntry | null {
  const word = row.word?.trim();
  const pronunciation = row.pronunciation?.trim();
  const partOfSpeech = row.partOfSpeech?.trim();
  const meaningZh = row.meaningZh?.trim();
  const supplementalMeaningZh = row.supplementalMeaningZh?.trim() ?? '';
  const example = row.example?.trim();
  const exampleZh = row.exampleZh?.trim();
  const group = row.group?.trim();

  if (!word || !pronunciation || !partOfSpeech || !meaningZh || !example || !exampleZh || !group) {
    return null;
  }

  return {
    id: row.id?.trim() || `custom-${word.toLowerCase().replace(/[^a-z0-9]+/g, '-')}`,
    word,
    pronunciation,
    partOfSpeech,
    meaningZh,
    supplementalMeaningZh,
    example,
    exampleZh,
    group,
  };
}

function isDeveloperVocabularySnapshot(value: unknown): value is DeveloperVocabularySnapshot {
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    return false;
  }

  const snapshot = value as Partial<DeveloperVocabularySnapshot>;
  return (
    typeof snapshot.importedAt === 'string' &&
    typeof snapshot.summary === 'string' &&
    Array.isArray(snapshot.words) &&
    snapshot.words.every(isWordEntry)
  );
}

function isWordEntry(value: unknown): value is WordEntry {
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    return false;
  }

  const word = value as Partial<WordEntry>;
  const requiredColumns = csvColumns.filter((column) => column !== 'supplementalMeaningZh');
  return (
    requiredColumns.every((column) => typeof word[column] === 'string' && word[column]?.trim()) &&
    (word.supplementalMeaningZh === undefined || typeof word.supplementalMeaningZh === 'string')
  );
}

function normalizeHeader(value: string): string {
  return value.trim().toLowerCase().replace(/[\s-]+/g, '_');
}

function csvCell(value: string | undefined): string {
  if (!value) {
    return '';
  }
  if (/[",\n\r]/.test(value)) {
    return `"${value.replaceAll('"', '""')}"`;
  }
  return value;
}
