import { describe, expect, test } from 'vitest';
import { sampleWords } from './words';

describe('full vocabulary dataset', () => {
  test('contains exactly 7000 app-ready words', () => {
    expect(sampleWords).toHaveLength(7000);
  });

  test('is split into 14 complete 500-word levels', () => {
    const groupCounts = sampleWords.reduce<Record<string, number>>((counts, word) => {
      counts[word.group] = (counts[word.group] ?? 0) + 1;
      return counts;
    }, {});

    expect(Object.keys(groupCounts)).toHaveLength(14);
    for (let level = 1; level <= 14; level += 1) {
      expect(groupCounts[`Core ${level}`]).toBe(500);
    }
  });

  test('uses unique ids and unique lowercase words', () => {
    const ids = new Set(sampleWords.map((word) => word.id));
    const words = new Set(sampleWords.map((word) => word.word.toLowerCase()));

    expect(ids.size).toBe(sampleWords.length);
    expect(words.size).toBe(sampleWords.length);
  });

  test('has complete fields for every word', () => {
    const incomplete = sampleWords.filter(
      (word) =>
        !word.id.trim() ||
        !word.word.trim() ||
        !word.partOfSpeech.trim() ||
        !word.pronunciation.trim() ||
        !word.meaningZh.trim() ||
        !word.example.trim() ||
        !word.exampleZh.trim() ||
        !word.group.trim(),
    );

    expect(incomplete).toEqual([]);
  });

  test('contains single-word English entries only', () => {
    const invalid = sampleWords.filter((word) => !/^[a-z]{2,18}$/.test(word.word));

    expect(invalid).toEqual([]);
  });

  test('keeps common words free of dictionary-domain noise', () => {
    const commonWords = sampleWords.filter((word) => ['be', 'for', 'it'].includes(word.word));
    const noisyPattern = /DOS|信息論|輸入終端|後端|總線|批處理/;

    expect(commonWords.map((word) => `${word.word}: ${word.meaningZh}`)).not.toEqual(
      expect.arrayContaining([expect.stringMatching(noisyPattern)]),
    );
  });

  test('keeps the first learning words stable for the home and study flow', () => {
    expect(sampleWords.slice(0, 5).map((word) => word.word)).toEqual([
      'adapt',
      'brief',
      'contrast',
      'expand',
      'precise',
    ]);
  });
});
