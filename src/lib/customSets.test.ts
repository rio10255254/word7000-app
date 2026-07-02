import { describe, expect, test } from 'vitest';
import type { WordEntry } from '../data/words';
import {
  addCustomWordToSet,
  addWordToSet,
  createCustomSet,
  customWordsFromImportRows,
  deleteCustomSet,
  mergeCustomSetStates,
  parseCustomWordsCsv,
  removeWordFromSet,
  renameCustomSet,
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

const secondCustomWord: WordEntry = {
  id: 'custom-lounge',
  word: 'lounge',
  pronunciation: '/lounge/',
  partOfSpeech: 'n',
  meaningZh: '休息室',
  example: 'The airport lounge was quiet.',
  exampleZh: '機場休息室很安靜。',
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

  test('renames a set after it has been created', () => {
    const created = createCustomSet(baseState, '舊名稱', '2026-07-02T06:00:00.000Z');
    const renamed = renameCustomSet(created, created.sets[0].id, '  旅行片語  ', '2026-07-02T06:08:00.000Z');

    expect(renamed.sets[0]).toMatchObject({
      id: created.sets[0].id,
      name: '旅行片語',
      updatedAt: '2026-07-02T06:08:00.000Z',
      wordIds: [],
    });
  });

  test('removes a word from an existing set without changing other sets', () => {
    const created = createCustomSet(baseState, '混合單字', '2026-07-02T06:00:00.000Z');
    const second = createCustomSet(created, '保留單字', '2026-07-02T06:01:00.000Z');
    const firstSetId = second.sets[0].id;
    const secondSetId = second.sets[1].id;
    const withWords = addWordToSet(addWordToSet(addWordToSet(second, firstSetId, 'word-1'), firstSetId, 'word-2'), secondSetId, 'word-1');
    const removed = removeWordFromSet(withWords, firstSetId, 'word-1', '2026-07-02T06:09:00.000Z');

    expect(removed.sets[0]).toMatchObject({
      updatedAt: '2026-07-02T06:09:00.000Z',
      wordIds: ['word-2'],
    });
    expect(removed.sets[1].wordIds).toEqual(['word-1']);
  });

  test('deletes a set without deleting the remaining sets', () => {
    const first = createCustomSet(baseState, '要刪除', '2026-07-02T06:00:00.000Z');
    const second = createCustomSet(first, '保留', '2026-07-02T06:01:00.000Z');
    const deleted = deleteCustomSet(second, second.sets[0].id);

    expect(deleted.sets.map((set) => set.name)).toEqual(['保留']);
    expect(deleted.sets[0].sortOrder).toBe(1);
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

  test('merges cloud and local sets without dropping newer local words', () => {
    const cloudState: CustomSetState = {
      customWords: [customWord],
      sets: [
        {
          color: '#2563eb',
          createdAt: '2026-07-01T01:00:00.000Z',
          id: 'set-travel',
          name: 'Travel',
          sortOrder: 1,
          updatedAt: '2026-07-01T01:00:00.000Z',
          wordIds: ['custom-ocean'],
        },
      ],
    };
    const localState: CustomSetState = {
      customWords: [customWord, secondCustomWord],
      sets: [
        {
          color: '#0f766e',
          createdAt: '2026-07-01T01:00:00.000Z',
          id: 'set-travel',
          name: 'Travel 2026',
          sortOrder: 1,
          updatedAt: '2026-07-02T01:00:00.000Z',
          wordIds: ['custom-lounge', 'custom-ocean'],
        },
        {
          color: '#7c3aed',
          createdAt: '2026-07-02T01:05:00.000Z',
          id: 'set-food',
          name: 'Food',
          sortOrder: 2,
          updatedAt: '2026-07-02T01:05:00.000Z',
          wordIds: ['menu'],
        },
      ],
    };

    const merged = mergeCustomSetStates(cloudState, localState);

    expect(merged.customWords.map((word) => word.id)).toEqual(['custom-ocean', 'custom-lounge']);
    expect(merged.sets).toHaveLength(2);
    expect(merged.sets.find((set) => set.id === 'set-travel')).toMatchObject({
      name: 'Travel 2026',
      updatedAt: '2026-07-02T01:00:00.000Z',
      wordIds: ['custom-lounge', 'custom-ocean'],
    });
    expect(merged.sets.find((set) => set.id === 'set-food')?.wordIds).toEqual(['menu']);
  });
});
