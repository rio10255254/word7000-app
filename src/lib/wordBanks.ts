import type { WordEntry } from '../data/words';
import type { StorageLike } from './progressStorage';

/** The built-in 7000-word list (plus words added by hand) is always a bank. */
export const CORE_BANK_ID = 'core';
export const ACTIVE_BANK_STORAGE_KEY = 'word7000-active-bank-v1';
/**
 * Words saved from a scanned sheet carry the meaning printed on that sheet,
 * so they live only in their own bank. The prefix keeps them out of the core
 * library, where a second "abandon" with a different meaning would only
 * confuse.
 */
export const SCANNED_WORD_ID_PREFIX = 'scan-';
export const SCANNED_WORD_GROUP = 'Scan';

export type ReviewedScanWord = {
  meaningZh: string;
  partOfSpeech: string;
  word: string;
};

export function isScannedWordId(wordId: string): boolean {
  return wordId.startsWith(SCANNED_WORD_ID_PREFIX);
}

export function loadActiveBankId(storage: StorageLike | undefined): string {
  try {
    return storage?.getItem(ACTIVE_BANK_STORAGE_KEY) || CORE_BANK_ID;
  } catch {
    return CORE_BANK_ID;
  }
}

export function saveActiveBankId(storage: StorageLike | undefined, bankId: string): void {
  try {
    storage?.setItem(ACTIVE_BANK_STORAGE_KEY, bankId);
  } catch {
    // The chosen bank is a convenience; studying still works without storage.
  }
}

/**
 * Turns reviewed scan rows into vocabulary entries. The printed meaning always
 * wins. When the word is also in the built-in list, its pronunciation and
 * example sentence are borrowed so the card is not left half empty.
 */
export function buildScannedWords(
  rows: ReviewedScanWord[],
  coreWords: WordEntry[],
  stamp = Date.now().toString(36),
): WordEntry[] {
  const coreByName = new Map(coreWords.map((word) => [word.word.toLowerCase(), word]));
  const seen = new Set<string>();

  return rows.flatMap((row, index) => {
    const word = row.word.trim().replace(/\s+/g, ' ');
    const meaningZh = row.meaningZh.trim();
    const key = word.toLowerCase();
    if (!word || !meaningZh || seen.has(key)) {
      return [];
    }
    seen.add(key);

    const core = coreByName.get(key);
    const slug = key.replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '') || 'word';
    return [{
      example: core?.example ?? '',
      exampleZh: core?.exampleZh ?? '',
      group: SCANNED_WORD_GROUP,
      id: `${SCANNED_WORD_ID_PREFIX}${slug}-${stamp}-${index}`,
      meaningZh,
      partOfSpeech: row.partOfSpeech.trim() || core?.partOfSpeech || '',
      pronunciation: core?.pronunciation ?? '',
      supplementalMeaningZh: '',
      word,
    }];
  });
}

export function defaultScanBankName(date = new Date(), mode: 'chinese' | 'english' = 'english'): string {
  const month = date.getMonth() + 1;
  const day = date.getDate();
  return mode === 'chinese' ? `Scan ${month}/${day}` : `掃描 ${month}/${day}`;
}
