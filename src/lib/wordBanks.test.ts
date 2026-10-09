import { describe, expect, test } from 'vitest';
import type { WordEntry } from '../data/words';
import {
  ACTIVE_BANK_STORAGE_KEY,
  buildScannedWords,
  CORE_BANK_ID,
  defaultScanBankName,
  isScannedWordId,
  loadActiveBankId,
  saveActiveBankId,
} from './wordBanks';

const core: WordEntry[] = [
  {
    example: 'They had to abandon the car.',
    exampleZh: '他們不得不棄車。',
    group: 'Core 4',
    id: 'w0100',
    meaningZh: '遺棄',
    partOfSpeech: 'vt',
    pronunciation: "/ə'bændən/",
    word: 'abandon',
  },
];

class MemoryStorage {
  values = new Map<string, string>();
  getItem(key: string) {
    return this.values.get(key) ?? null;
  }
  setItem(key: string, value: string) {
    this.values.set(key, value);
  }
}

describe('word banks', () => {
  test('keeps the printed meaning and borrows the rest from the built-in word', () => {
    const [word] = buildScannedWords([{ meaningZh: '放棄', partOfSpeech: '', word: 'Abandon' }], core, 'x');

    expect(word).toMatchObject({
      example: 'They had to abandon the car.',
      group: 'Scan',
      meaningZh: '放棄',
      partOfSpeech: 'vt',
      pronunciation: "/ə'bændən/",
      word: 'Abandon',
    });
    expect(isScannedWordId(word.id)).toBe(true);
  });

  test('leaves examples empty for words the built-in list does not have', () => {
    const [word] = buildScannedWords([{ meaningZh: '光合作用', partOfSpeech: 'n', word: 'photosynthesis' }], core, 'x');

    expect(word).toMatchObject({ example: '', exampleZh: '', partOfSpeech: 'n', pronunciation: '' });
  });

  test('drops empty rows and duplicate words, and gives every word its own id', () => {
    const words = buildScannedWords(
      [
        { meaningZh: '桌子', partOfSpeech: 'n', word: 'table' },
        { meaningZh: '', partOfSpeech: 'n', word: 'chair' },
        { meaningZh: '表格', partOfSpeech: 'n', word: 'Table' },
        { meaningZh: '展望', partOfSpeech: '', word: 'look  forward to' },
      ],
      core,
      'x',
    );

    expect(words.map((word) => word.word)).toEqual(['table', 'look forward to']);
    expect(new Set(words.map((word) => word.id)).size).toBe(2);
  });

  test('remembers the chosen bank and falls back to the built-in list', () => {
    const storage = new MemoryStorage();
    expect(loadActiveBankId(storage)).toBe(CORE_BANK_ID);

    saveActiveBankId(storage, 'set-abc');

    expect(storage.getItem(ACTIVE_BANK_STORAGE_KEY)).toBe('set-abc');
    expect(loadActiveBankId(storage)).toBe('set-abc');
    expect(loadActiveBankId(undefined)).toBe(CORE_BANK_ID);
  });

  test('names a new scan bank after the date', () => {
    expect(defaultScanBankName(new Date(2026, 9, 9))).toBe('掃描 10/9');
    expect(defaultScanBankName(new Date(2026, 9, 9), 'chinese')).toBe('Scan 10/9');
  });
});
