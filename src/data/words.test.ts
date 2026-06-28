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

  test('uses sentence examples instead of dictionary placeholder text', () => {
    const placeholderExamples = sampleWords.filter(
      (word) =>
        word.example.startsWith(`Review "${word.word}" with this meaning:`) ||
        word.exampleZh === `「${word.word}」：${word.meaningZh}`,
    );

    expect(placeholderExamples.slice(0, 20).map((word) => word.word)).toEqual([]);
  });

  test('uses contextual examples instead of meta-learning templates', () => {
    const metaPatterns = [
      /\bthe word\b/i,
      /\bsimple (sentence|example)\b/i,
      /\blearner/i,
      /\bcan show how\b/i,
      /\bpractical context\b/i,
      /\bmeaning clearer\b/i,
      /\bcomplete sentence\b/i,
      /\blong definition\b/i,
      /\bfamiliar idea\b/i,
    ];
    const metaExamples = sampleWords.filter((word) =>
      metaPatterns.some((pattern) => pattern.test(`${word.example} ${word.exampleZh}`)),
    );

    expect(metaExamples.slice(0, 20).map((word) => word.word)).toEqual([]);
  });

  test('keeps generated example frames varied across the full dataset', () => {
    const frameCounts = new Map<string, number>();

    for (const word of sampleWords) {
      const frame = word.example.toLowerCase().replaceAll(word.word.toLowerCase(), '{word}');
      frameCounts.set(frame, (frameCounts.get(frame) ?? 0) + 1);
    }

    const repeatedFrames = Array.from(frameCounts.entries())
      .filter(([, count]) => count > 35)
      .sort((a, b) => b[1] - a[1]);

    expect(repeatedFrames.slice(0, 10)).toEqual([]);
  });

  test('uses each word directly inside its English example', () => {
    const missingWordExamples = sampleWords.filter((word) => {
      const pattern = new RegExp(`(^|[^a-z])${word.word.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}([^a-z]|$)`, 'i');
      return !pattern.test(word.example);
    });

    expect(missingWordExamples.slice(0, 20).map((word) => word.word)).toEqual([]);
  });

  test('keeps examples free of obvious grammar artifacts', () => {
    const grammarArtifacts = sampleWords.filter(
      (word) =>
        /^[a-z]/.test(word.example) ||
        /\b[Aa] [aeiou]/.test(word.example) ||
        /\b[Aa]n [^aeiou\s]/.test(word.example) ||
        /的的/.test(word.exampleZh),
    );

    expect(grammarArtifacts.slice(0, 20).map((word) => `${word.word}: ${word.example} / ${word.exampleZh}`)).toEqual([]);
  });

  test('keeps English example sentences in English', () => {
    const mixedLanguageExamples = sampleWords.filter((word) => /[\u4e00-\u9fff]/.test(word.example));

    expect(mixedLanguageExamples.slice(0, 20).map((word) => word.word)).toEqual([]);
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
