import { describe, expect, test } from 'vitest';
import { sampleWords } from '../data/words';
import {
  buildQuizOptions,
  buildQuizSession,
  buildStudySession,
  computeStats,
  filterWords,
  markKnown,
  markReview,
  mergeProgressStates,
  normalizeProgressForDate,
  selectStudyWords,
  selectQuizWords,
  toggleFavorite,
  type ProgressState,
} from './progress';
import type { WordEntry } from '../data/words';

const today = '2026-06-28';

function emptyProgress(): ProgressState {
  return {
    dailyTarget: 20,
    streak: 1,
    studiedToday: 0,
    words: {},
  };
}

function wordFixture(id: string, values: Partial<WordEntry> = {}): WordEntry {
  return {
    id,
    word: id,
    pronunciation: `/${id}/`,
    partOfSpeech: 'n',
    meaningZh: `${id} 的意思`,
    example: `This example uses ${id}.`,
    exampleZh: `這個例句使用 ${id}。`,
    group: 'Core 1',
    ...values,
  };
}

describe('progress state', () => {
  test('markKnown records a mastered word and advances daily progress', () => {
    const state = markKnown(emptyProgress(), sampleWords[0].id, today);

    expect(state.words[sampleWords[0].id]).toMatchObject({
      status: 'mastered',
      lastStudied: today,
    });
    expect(state.studiedToday).toBe(1);
  });

  test('markKnown starts a real daily streak on the first studied word of the day', () => {
    const state = markKnown(emptyProgress(), sampleWords[0].id, today);

    expect(state).toMatchObject({
      dailyProgressDate: today,
      lastStudyDate: today,
      streak: 1,
      studiedToday: 1,
    });
  });

  test('same-day study increments today count without inflating streak', () => {
    const state = markReview(markKnown(emptyProgress(), sampleWords[0].id, today), sampleWords[1].id, today);

    expect(state.streak).toBe(1);
    expect(state.studiedToday).toBe(2);
    expect(state.lastStudyDate).toBe(today);
  });

  test('consecutive-day study resets the daily count and extends streak once', () => {
    const dayOne = markKnown(emptyProgress(), sampleWords[0].id, '2026-06-28');
    const dayTwo = markReview(dayOne, sampleWords[1].id, '2026-06-29');

    expect(dayTwo.streak).toBe(2);
    expect(dayTwo.studiedToday).toBe(1);
    expect(dayTwo.dailyProgressDate).toBe('2026-06-29');
    expect(dayTwo.lastStudyDate).toBe('2026-06-29');
  });

  test('study after a missed day starts a new streak', () => {
    const dayOne = markKnown(emptyProgress(), sampleWords[0].id, '2026-06-28');
    const dayFour = markReview(dayOne, sampleWords[1].id, '2026-07-01');

    expect(dayFour.streak).toBe(1);
    expect(dayFour.studiedToday).toBe(1);
    expect(dayFour.lastStudyDate).toBe('2026-07-01');
  });

  test('normalizing progress for a new date resets today count and expires stale streaks', () => {
    const current = normalizeProgressForDate(
      {
        ...emptyProgress(),
        dailyProgressDate: '2026-06-28',
        lastStudyDate: '2026-06-28',
        streak: 3,
        studiedToday: 8,
      },
      '2026-06-30',
    );

    expect(current.studiedToday).toBe(0);
    expect(current.streak).toBe(0);
    expect(current.dailyProgressDate).toBe('2026-06-30');
  });

  test('markReview records a difficult word without counting it as mastered', () => {
    const state = markReview(emptyProgress(), sampleWords[1].id, today);

    expect(state.words[sampleWords[1].id]).toMatchObject({
      status: 'review',
      difficult: true,
      reviewCount: 1,
      lastStudied: today,
    });
    expect(computeStats(sampleWords, state).review).toBe(1);
  });

  test('toggleFavorite switches the favorite flag for a word', () => {
    const favorited = toggleFavorite(emptyProgress(), sampleWords[2].id);
    const unfavorited = toggleFavorite(favorited, sampleWords[2].id);

    expect(favorited.words[sampleWords[2].id].favorite).toBe(true);
    expect(unfavorited.words[sampleWords[2].id].favorite).toBe(false);
    expect(unfavorited.words[sampleWords[2].id].favoriteUpdatedAt).toBeTruthy();
  });

  test('merges independent word changes without replacing the whole account history', () => {
    const cloud = markKnown(emptyProgress(), 'cloud-word', today, '2026-07-10T08:00:00.000Z');
    const local = toggleFavorite(emptyProgress(), 'local-word', '2026-07-10T09:00:00.000Z');

    const merged = mergeProgressStates(cloud, local);

    expect(merged.words['cloud-word'].status).toBe('mastered');
    expect(merged.words['local-word'].favorite).toBe(true);
  });

  test('keeps the newest status and favorite decisions for the same word', () => {
    const older = toggleFavorite(
      markKnown(emptyProgress(), 'shared-word', today, '2026-07-10T08:00:00.000Z'),
      'shared-word',
      '2026-07-10T08:10:00.000Z',
    );
    const newerStatus = markReview(older, 'shared-word', today, '2026-07-10T09:00:00.000Z');
    const newerFavorite = toggleFavorite(newerStatus, 'shared-word', '2026-07-10T09:10:00.000Z');

    const merged = mergeProgressStates(older, newerFavorite);

    expect(merged.words['shared-word']).toMatchObject({
      favorite: false,
      status: 'review',
      statusUpdatedAt: '2026-07-10T09:00:00.000Z',
    });
  });

  test('computeStats summarizes mastered, review, favorite, and remaining words', () => {
    const state = toggleFavorite(
      markReview(markKnown(emptyProgress(), sampleWords[0].id, today), sampleWords[1].id, today),
      sampleWords[0].id,
    );

    expect(computeStats(sampleWords, state)).toMatchObject({
      mastered: 1,
      review: 1,
      favorites: 1,
      remaining: sampleWords.length - 2,
      studiedToday: 2,
    });
  });

  test('computeStats ignores progress left behind by words outside the active vocabulary', () => {
    const state = markKnown(emptyProgress(), 'removed-word', today);

    expect(computeStats(sampleWords.slice(0, 3), state)).toMatchObject({
      mastered: 0,
      review: 0,
      favorites: 0,
      remaining: 3,
    });
  });
});

describe('library and quiz helpers', () => {
  test('filterWords searches text and narrows by favorite, review, mastered, and new states', () => {
    const state = toggleFavorite(
      markReview(markKnown(emptyProgress(), sampleWords[0].id, today), sampleWords[1].id, today),
      sampleWords[0].id,
    );

    const adaptResults = filterWords(sampleWords, state, 'adapt', 'all').map((word) => word.word);

    expect(adaptResults).toContain('adapt');
    expect(adaptResults.every((word) => word.includes('adapt'))).toBe(true);
    expect(filterWords(sampleWords, state, '', 'favorites').map((word) => word.id)).toEqual([sampleWords[0].id]);
    expect(filterWords(sampleWords, state, '', 'review').map((word) => word.id)).toEqual([sampleWords[1].id]);
    expect(filterWords(sampleWords, state, '', 'mastered').map((word) => word.id)).toEqual([sampleWords[0].id]);
    expect(filterWords(sampleWords, state, '', 'new')).not.toContain(sampleWords[0]);
  });

  test('filterWords narrows by level and first letter together', () => {
    const coreTwoBWords = filterWords(sampleWords, emptyProgress(), '', 'all', {
      initial: 'B',
      level: 'Core 2',
    });

    expect(coreTwoBWords.length).toBeGreaterThan(0);
    expect(coreTwoBWords.every((word) => word.group === 'Core 2')).toBe(true);
    expect(coreTwoBWords.every((word) => word.word.toUpperCase().startsWith('B'))).toBe(true);
  });

  test('filterWords searches supplemental meanings without showing them as the main answer', () => {
    const words = [
      wordFixture('bank', {
        meaningZh: '銀行',
        supplementalMeaningZh: '河岸',
      }),
    ];

    expect(filterWords(words, emptyProgress(), '河岸', 'all').map((word) => word.word)).toEqual(['bank']);
  });

  test('filterWords keeps the full library in its stable vocabulary order when not searching or filtering', () => {
    const words = [
      wordFixture('mastered-word'),
      wordFixture('review-word'),
      wordFixture('fresh-word'),
    ];
    const state = markReview(markKnown(emptyProgress(), 'mastered-word', today), 'review-word', today);

    const filtered = filterWords(words, state, '', 'all');

    expect(filtered.map((word) => word.id)).toEqual(['mastered-word', 'review-word', 'fresh-word']);
    expect(filtered).toBe(words);
  });

  test('filterWords can sort the library alphabetically by English word when requested', () => {
    const words = [
      wordFixture('zebra-word', { word: 'zebra' }),
      wordFixture('apple-word', { word: 'apple' }),
      wordFixture('banana-word', { word: 'banana' }),
    ];

    const firstResult = filterWords(words, emptyProgress(), '', 'all', { sort: 'alphabetical' });
    const secondResult = filterWords(words, emptyProgress(), '', 'all', { sort: 'alphabetical' });

    expect(firstResult.map((word) => word.word)).toEqual([
      'apple',
      'banana',
      'zebra',
    ]);
    expect(secondResult).toBe(firstResult);
  });

  test('filterWords puts newly favorited words first in the favorites list', () => {
    const words = [wordFixture('old-favorite'), wordFixture('new-favorite')];
    const state = toggleFavorite(
      toggleFavorite(emptyProgress(), 'old-favorite', '2026-06-28T08:00:00.000Z'),
      'new-favorite',
      '2026-06-28T09:00:00.000Z',
    );

    expect(filterWords(words, state, '', 'favorites').map((word) => word.id)).toEqual(['new-favorite', 'old-favorite']);
  });

  test('filterWords puts newly reviewed words first in the review list', () => {
    const words = [wordFixture('old-review'), wordFixture('new-review')];
    const state = markReview(
      markReview(emptyProgress(), 'old-review', today, '2026-06-28T08:00:00.000Z'),
      'new-review',
      today,
      '2026-06-28T09:00:00.000Z',
    );

    expect(filterWords(words, state, '', 'review').map((word) => word.id)).toEqual(['new-review', 'old-review']);
  });

  test('filterWords puts newly mastered words first in the mastered list', () => {
    const words = [wordFixture('old-mastered'), wordFixture('new-mastered')];
    const state = markKnown(
      markKnown(emptyProgress(), 'old-mastered', today, '2026-06-28T08:00:00.000Z'),
      'new-mastered',
      today,
      '2026-06-28T09:00:00.000Z',
    );

    expect(filterWords(words, state, '', 'mastered').map((word) => word.id)).toEqual(['new-mastered', 'old-mastered']);
  });

  test('filterWords ranks exact and prefix English matches above looser matches while searching', () => {
    const words = [
      wordFixture('contains-match', {
        word: 'cartoon',
        meaningZh: '卡通',
        example: 'The cartoon stayed on the table.',
      }),
      wordFixture('prefix-match', {
        word: 'artist',
        meaningZh: '藝術家',
        example: 'The artist arrived early.',
      }),
      wordFixture('exact-match', {
        word: 'art',
        meaningZh: '藝術',
        example: 'Art can change a quiet room.',
      }),
      wordFixture('example-match', {
        word: 'museum',
        meaningZh: '博物館',
        example: 'The guide explained art history.',
      }),
    ];

    expect(filterWords(words, emptyProgress(), 'art', 'all').map((word) => word.id)).toEqual([
      'exact-match',
      'prefix-match',
      'contains-match',
      'example-match',
    ]);
  });

  test('filterWords searches Chinese translations and supports multiple query terms', () => {
    const words = [
      wordFixture('clear', {
        word: 'clear',
        meaningZh: '清楚的；明確的',
        example: 'A clear routine helped the class.',
        exampleZh: '清楚的規律幫助了班級。',
      }),
      wordFixture('routine', {
        word: 'routine',
        meaningZh: '常規；例行程序',
        example: 'The routine changed on Monday.',
        exampleZh: '這個例行程序在星期一改變了。',
      }),
    ];

    expect(filterWords(words, emptyProgress(), '清楚 規律', 'all').map((word) => word.id)).toEqual(['clear']);
  });

  test('buildQuizOptions returns three choices with the correct meaning included once', () => {
    const options = buildQuizOptions(sampleWords, sampleWords[0].id, 'seed-a');

    expect(options).toHaveLength(3);
    expect(options.filter((option) => option.correct)).toHaveLength(1);
    expect(options.some((option) => option.meaning === sampleWords[0].meaningZh)).toBe(true);
  });

  test('buildQuizOptions uses only the primary meaning and never exposes supplemental meanings', () => {
    const words = [
      wordFixture('bank', { meaningZh: '銀行', supplementalMeaningZh: '河岸' }),
      wordFixture('cut', { meaningZh: '傷口', supplementalMeaningZh: '切；削減；剪' }),
      wordFixture('run', { meaningZh: '跑步', supplementalMeaningZh: '經營；運轉；流動' }),
    ];

    const options = buildQuizOptions(words, 'bank', 'primary-only');

    expect(options.map((option) => option.meaning)).toEqual(expect.arrayContaining(['銀行', '傷口', '跑步']));
    expect(options.some((option) => /河岸|切|削減|剪|經營|運轉|流動/.test(option.meaning))).toBe(false);
  });

  test('buildQuizOptions can switch to English answers for Chinese study mode', () => {
    const options = buildQuizOptions(sampleWords, sampleWords[0].id, 'seed-a', 'word');

    expect(options).toHaveLength(3);
    expect(options.filter((option) => option.correct)).toHaveLength(1);
    expect(options.some((option) => option.meaning === sampleWords[0].word)).toBe(true);
    expect(options.every((option) => !option.meaning.includes('；'))).toBe(true);
  });

  test('buildQuizOptions does not keep the correct answer in one fixed position', () => {
    const correctIndexes = new Set(
      Array.from({ length: 12 }, (_, index) =>
        buildQuizOptions(sampleWords, sampleWords[0].id, `seed-${index}`).findIndex((option) => option.correct),
      ),
    );

    expect(correctIndexes.size).toBeGreaterThan(1);
    expect(correctIndexes.has(1)).toBe(true);
  });

  test('buildQuizSession creates a distinct shuffled question bank with the requested count', () => {
    const session = buildQuizSession(sampleWords.slice(0, 50), 10, 'quiz-seed');

    expect(session).toHaveLength(10);
    expect(new Set(session.map((word) => word.id)).size).toBe(10);
    expect(session.map((word) => word.id)).not.toEqual(sampleWords.slice(0, 10).map((word) => word.id));
  });

  test('buildQuizSession caps the count when the filtered bank is smaller than requested', () => {
    const session = buildQuizSession(sampleWords.slice(0, 6), 10, 'small-bank');

    expect(session).toHaveLength(6);
  });

  test('selectQuizWords uses status, level, and first-letter filters for quiz targets', () => {
    const state = toggleFavorite(
      markReview(markKnown(emptyProgress(), sampleWords[0].id, today), sampleWords[1].id, today),
      sampleWords[0].id,
    );

    expect(selectQuizWords(sampleWords, state, 'favorites').map((word) => word.id)).toEqual([sampleWords[0].id]);
    expect(selectQuizWords(sampleWords, state, 'review').map((word) => word.id)).toEqual([sampleWords[1].id]);
    expect(
      selectQuizWords(sampleWords, state, 'all', {
        initial: 'B',
        level: 'Core 1',
      }).every((word) => word.group === 'Core 1' && word.word.toUpperCase().startsWith('B')),
    ).toBe(true);
  });

  test('selectStudyWords uses the same filters for the learning flow', () => {
    const state = toggleFavorite(
      markReview(markKnown(emptyProgress(), sampleWords[0].id, today), sampleWords[1].id, today),
      sampleWords[0].id,
    );

    expect(selectStudyWords(sampleWords, state, 'mastered').map((word) => word.id)).toEqual([sampleWords[0].id]);
    expect(selectStudyWords(sampleWords, state, 'review').map((word) => word.id)).toEqual([sampleWords[1].id]);
    expect(
      selectStudyWords(sampleWords, state, 'all', {
        initial: 'C',
        level: 'Core 1',
      }).every((word) => word.group === 'Core 1' && word.word.toUpperCase().startsWith('C')),
    ).toBe(true);
  });

  test('buildStudySession gives learning cards a stable randomized order', () => {
    const words = sampleWords.slice(0, 12);
    const firstSession = buildStudySession(words, 'study-seed-one');
    const sameSession = buildStudySession(words, 'study-seed-one');
    const otherSession = buildStudySession(words, 'study-seed-two');

    expect(firstSession.map((word) => word.id)).toEqual(sameSession.map((word) => word.id));
    expect(firstSession.map((word) => word.id).sort()).toEqual(words.map((word) => word.id).sort());
    expect(firstSession.map((word) => word.id)).not.toEqual(words.map((word) => word.id));
    expect(firstSession.map((word) => word.id)).not.toEqual(otherSession.map((word) => word.id));
  });
});
