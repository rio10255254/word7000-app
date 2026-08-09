import { describe, expect, test } from 'vitest';
import type { WordEntry } from '../data/words';
import {
  applyVocabularyImportRows,
  exportWordsToCsv,
  loadDeveloperVocabulary,
  parseVocabularyImport,
  saveDeveloperVocabulary,
} from './developerVocabulary';

class MemoryStorage {
  private values = new Map<string, string>();

  getItem(key: string) {
    return this.values.get(key) ?? null;
  }

  setItem(key: string, value: string) {
    this.values.set(key, value);
  }

  removeItem(key: string) {
    this.values.delete(key);
  }
}

function wordFixture(word: string, values: Partial<WordEntry> = {}): WordEntry {
  return {
    id: word,
    word,
    pronunciation: `/${word}/`,
    partOfSpeech: 'n',
    meaningZh: `${word} 的意思`,
    example: `This sentence uses ${word}.`,
    exampleZh: `這個句子使用 ${word}。`,
    group: 'Core 1',
    ...values,
  };
}

describe('developer vocabulary import and export', () => {
  test('exports app words as an editable CSV table', () => {
    const csv = exportWordsToCsv([
      wordFixture('adapt', {
        meaningZh: '適應；調整',
        example: 'Students adapt quickly.',
        exampleZh: '學生很快適應。',
      }),
    ]);

    expect(csv.split('\n')[0]).toBe(
      'id,word,pronunciation,partOfSpeech,meaningZh,supplementalMeaningZh,example,exampleZh,group',
    );
    expect(csv).toContain('adapt');
    expect(csv).toContain('Students adapt quickly.');
    expect(csv).toContain('學生很快適應。');
  });

  test('parses a partial CSV revision table for existing words', () => {
    const parsed = parseVocabularyImport(
      'word,example,exampleZh\nadapt,"Students adapt quickly to a new routine.","學生很快適應新的作息。"',
      'revision.csv',
    );

    expect(parsed.ok).toBe(true);
    expect(parsed.rows).toEqual([
      {
        word: 'adapt',
        example: 'Students adapt quickly to a new routine.',
        exampleZh: '學生很快適應新的作息。',
      },
    ]);
  });

  test('preserves supplemental meanings during import and export', () => {
    const csv = exportWordsToCsv([
      wordFixture('bank', {
        meaningZh: '銀行',
        supplementalMeaningZh: '河岸',
      }),
    ]);
    const parsed = parseVocabularyImport(csv, 'vocabulary.csv');

    expect(parsed.ok).toBe(true);
    expect(parsed.rows[0]).toMatchObject({
      meaningZh: '銀行',
      supplementalMeaningZh: '河岸',
    });
  });

  test('ignores extra CSV columns without shifting known fields', () => {
    const parsed = parseVocabularyImport(
      'word,notes,example,exampleZh\nadapt,needs review,"Students adapt quickly.","學生很快適應。"',
      'revision.csv',
    );

    expect(parsed.ok).toBe(true);
    expect(parsed.rows[0]).toEqual({
      word: 'adapt',
      example: 'Students adapt quickly.',
      exampleZh: '學生很快適應。',
    });
  });

  test('parses JSON tables exported from other tools', () => {
    const parsed = parseVocabularyImport(
      JSON.stringify({
        words: [
          {
            word: 'brief',
            meaningZh: '簡短的',
            example: 'The brief note saved time.',
            exampleZh: '那張簡短的便條節省了時間。',
          },
        ],
      }),
      'revision.json',
    );

    expect(parsed.ok).toBe(true);
    expect(parsed.rows[0]).toMatchObject({
      word: 'brief',
      example: 'The brief note saved time.',
      exampleZh: '那張簡短的便條節省了時間。',
    });
  });

  test('updates existing words and appends complete new words', () => {
    const baseWords = [wordFixture('adapt'), wordFixture('brief')];
    const result = applyVocabularyImportRows(baseWords, [
      {
        word: 'adapt',
        example: 'Students adapt quickly to a new routine.',
        exampleZh: '學生很快適應新的作息。',
      },
      {
        id: 'custom-mentor',
        word: 'mentor',
        pronunciation: '/mentor/',
        partOfSpeech: 'n',
        meaningZh: '導師；良師',
        example: 'A mentor helped her choose a path.',
        exampleZh: '一位導師幫她選擇方向。',
        group: 'Custom',
      },
    ]);

    expect(result.errors).toEqual([]);
    expect(result.updated).toBe(1);
    expect(result.added).toBe(1);
    expect(result.words.map((word) => word.word)).toEqual(['adapt', 'brief', 'mentor']);
    expect(result.words[0].example).toBe('Students adapt quickly to a new routine.');
    expect(result.words[2]).toMatchObject({ id: 'custom-mentor', group: 'Custom' });
  });

  test('rejects incomplete unknown words instead of creating broken entries', () => {
    const result = applyVocabularyImportRows([wordFixture('adapt')], [
      {
        word: 'unknown',
        example: 'This row is missing required fields.',
      },
    ]);

    expect(result.added).toBe(0);
    expect(result.errors[0]).toContain('unknown');
  });

  test('saves and loads a local developer preview vocabulary', () => {
    const storage = new MemoryStorage();
    const words = [wordFixture('adapt')];

    saveDeveloperVocabulary(storage, {
      importedAt: '2026-06-29T00:00:00.000Z',
      summary: '匯入 1 筆',
      words,
    });

    expect(loadDeveloperVocabulary(storage)).toEqual({
      importedAt: '2026-06-29T00:00:00.000Z',
      summary: '匯入 1 筆',
      words,
    });
  });
});
