import { describe, expect, test } from 'vitest';
import { sampleWords } from '../data/words';
import {
  buildQuizOptions,
  computeStats,
  filterWords,
  markKnown,
  markReview,
  selectStudyWords,
  selectQuizWords,
  toggleFavorite,
  type ProgressState,
} from './progress';

const today = '2026-06-28';

function emptyProgress(): ProgressState {
  return {
    dailyTarget: 20,
    streak: 1,
    studiedToday: 0,
    words: {},
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

  test('buildQuizOptions returns three choices with the correct meaning included once', () => {
    const options = buildQuizOptions(sampleWords, sampleWords[0].id);

    expect(options).toHaveLength(3);
    expect(options.filter((option) => option.correct)).toHaveLength(1);
    expect(options.some((option) => option.meaning === sampleWords[0].meaningZh)).toBe(true);
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
});
