import { describe, expect, test } from 'vitest';
import type { WordEntry } from '../data/words';
import {
  addCustomWordToSet,
  addWordToSet,
  createCustomSet,
  customWordsFromImportRows,
  parseCustomWordsCsv,
  sortCustomSets,
  type CustomSetState,
} from './customSets';

const baseState: CustomSetState = {
  sets: [],
  customWords: [],
};

const customWord: WordEntry = {
  id: 'custom-ocean',
  word: 'ocean',
  pronunciation: '/ocean/',
  partOfSpeech: 'n',
  meaningZh: '海洋',
  example: 'The ocean looked calm in the morning.',
  exampleZh: '早晨的海洋看起來很平靜。',
  group: 'Custom',
};

describe('custom vocabulary sets', () => {
  test('creates a named set with stable metadata', () => {
    const state = createCustomSet(baseState, '旅行英文', '2026-07-02T06:00:00.000Z');

    expect(state.sets).toHaveLength(1);
    expect(state.sets[0]).toMatchObject({
      createdAt: '2026-07-02T06:00:00.000Z',
      name: '旅行英文',
      updatedAt: '2026-07-02T06:00:00.000Z',
      wordIds: [],
    });
    expect(state.sets[0].id).toBe('set-旅行英文-1782972000000');
  });

  test('adds an existing word to a set without duplicating it', () => {
    const created = createCustomSet(baseState, '常錯單字', '2026-07-02T06:00:00.000Z');
    const setId = created.sets[0].id;
    const added = addWordToSet(created, setId, 'word-1', '2026-07-02T06:03:00.000Z');
    const addedAgain = addWordToSet(added, setId, 'word-1', '2026-07-02T06:04:00.000Z');

    expect(addedAgain.sets[0].wordIds).toEqual(['word-1']);
    expect(addedAgain.sets[0].updatedAt).toBe('2026-07-02T06:04:00.000Z');
  });

  test('adds custom words and attaches them to a set', () => {
    const created = createCustomSet(baseState, '我的單字', '2026-07-02T06:00:00.000Z');
    const state = addCustomWordToSet(created, created.sets[0].id, customWord, '2026-07-02T06:05:00.000Z');

    expect(state.customWords).toEqual([customWord]);
    expect(state.sets[0].wordIds).toEqual(['custom-ocean']);
  });

  test('sorts sets by recent update, name, or custom order', () => {
    const first = createCustomSet(baseState, 'B set', '2026-07-02T06:00:00.000Z');
    const second = createCustomSet(first, 'A set', '2026-07-02T06:10:00.000Z');
    const orderedState = {
      ...second,
      sets: second.sets.map((set, index) => ({ ...set, sortOrder: index === 0 ? 2 : 1 })),
    };

    expect(sortCustomSets(orderedState.sets, 'recent').map((set) => set.name)).toEqual(['A set', 'B set']);
    expect(sortCustomSets(orderedState.sets, 'name').map((set) => set.name)).toEqual(['A set', 'B set']);
    expect(sortCustomSets(orderedState.sets, 'manual').map((set) => set.name)).toEqual(['A set', 'B set']);
  });

  test('parses custom words from CSV upload rows', () => {
    const parsed = parseCustomWordsCsv(
      [
        'word,meaning,pronunciation,partOfSpeech,example,exampleZh,group',
        'harbor,港口,/harbor/,n,"The harbor was full of boats.","港口停滿了船。",Custom',
      ].join('\n'),
    );
    const words = customWordsFromImportRows(parsed.rows, []);

    expect(parsed.ok).toBe(true);
    expect(words.errors).toEqual([]);
    expect(words.words[0]).toMatchObject({
      id: 'custom-harbor',
      word: 'harbor',
      meaningZh: '港口',
      group: 'Custom',
    });
  });
});
