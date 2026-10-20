import { describe, expect, it } from 'vitest';
import { buildLibrary, validateRecords } from './build-native-speaking-library.mjs';

const library = buildLibrary();
const first = library.records[0];
const vocabulary = [{ id: first.id.replace('-reviewed-1', ''), word: first.word }];
const check = record => validateRecords([record], vocabulary, 1);

describe('native speaking editorial sources', () => {
  it('builds 600 distinct paired questions across fourteen levels', () => {
    expect(library.records).toHaveLength(600);
    expect(new Set(library.records.map(row => row.word)).size).toBe(600);
    expect(Object.keys(library.coverage.levels)).toHaveLength(14);
    expect(library.sources).toHaveLength(21);
  });
  it('rejects missing reference translations', () => {
    expect(() => check({ ...first, answerZh: '' })).toThrow('Missing answerZh');
  });
  it('rejects a reference answer that omits the target', () => {
    expect(() => check({ ...first, answerEn: 'I would talk to my friend about the available choices. Then we could pick a reasonable plan together.' })).toThrow('Missing English target');
  });
  it('rejects duplicated headwords even under another question', () => {
    expect(() => validateRecords([first, { ...first, question: 'Which option would you choose next time?' }], vocabulary, 2)).toThrow('Duplicate id');
  });
  it('rejects an answer that is only a short definition', () => {
    expect(() => check({ ...first, answerEn: `I can ${first.word}.` })).toThrow('Answer length');
  });
  it('rejects mixed-language filler questions', () => {
    expect(() => check({ ...first, question: 'How would you use 這個單字 today?' })).toThrow('Mixed English text');
  });
  it('rejects a reference translation without its selected sense', () => {
    expect(() => check({ ...first, answerZh: '這份示範沒有正確對應要練習的意思。' })).toThrow('Missing Chinese target');
  });
  it('rejects mismatched vocabulary identifiers', () => {
    expect(() => check({ ...first, id: 'w9999-reviewed-1' })).toThrow('Vocabulary identity mismatch');
  });
});
