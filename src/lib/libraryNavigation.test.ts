import { describe, expect, test } from 'vitest';
import {
  libraryListScrollTarget,
  recenteredWordWindowFromScroll,
  scrollTargetFromSlider,
  scrollThumbOffset,
  wordIndexFromLibraryScroll,
  wordWindowStartFromSlider,
} from './libraryNavigation';

describe('library slider navigation', () => {
  test('maps drag position to a bounded scroll target', () => {
    expect(scrollTargetFromSlider(0, 400, 2000, 500)).toBe(0);
    expect(scrollTargetFromSlider(200, 400, 2000, 500)).toBe(750);
    expect(scrollTargetFromSlider(900, 400, 2000, 500)).toBe(1500);
    expect(scrollTargetFromSlider(-20, 400, 2000, 500)).toBe(0);
  });

  test('maps current scroll position to a bounded thumb offset', () => {
    expect(scrollThumbOffset(0, 2000, 500, 400, 36)).toBe(0);
    expect(scrollThumbOffset(750, 2000, 500, 400, 36)).toBe(182);
    expect(scrollThumbOffset(2000, 2000, 500, 400, 36)).toBe(364);
  });

  test('maps slider drag to a bounded word window start', () => {
    expect(wordWindowStartFromSlider(0, 400, 7000, 260)).toBe(0);
    expect(wordWindowStartFromSlider(200, 400, 7000, 260)).toBe(3370);
    expect(wordWindowStartFromSlider(900, 400, 7000, 260)).toBe(6740);
    expect(wordWindowStartFromSlider(-20, 400, 7000, 260)).toBe(0);
  });

  test('maps a dragged thumb center at the bottom to the last word window', () => {
    expect(wordWindowStartFromSlider(496, 500, 7000, 260, 42)).toBe(6740);
  });

  test('moves the slider thumb with regular page scrolling inside the current word window', () => {
    expect(wordIndexFromLibraryScroll(1200, 980, 300, 170, 7000, 260)).toBe(1204);
    expect(wordIndexFromLibraryScroll(6680, 70000, 300, 170, 7000, 260)).toBe(6740);
    expect(wordIndexFromLibraryScroll(0, 80, 300, 170, 7000, 260)).toBe(0);
  });

  test('recenters the virtual word window while preserving the visible row during long scrolls', () => {
    expect(
      recenteredWordWindowFromScroll(0, 300 + 190 * 170, 300, 170, 7000, 260, {
        forwardAnchor: 150,
        backwardAnchor: 58,
      }),
    ).toEqual({ scrollY: 300 + 150 * 170, windowStart: 40 });

    expect(
      recenteredWordWindowFromScroll(300, 300 + 20 * 170, 300, 170, 7000, 260, {
        forwardAnchor: 150,
        backwardAnchor: 58,
      }),
    ).toEqual({ scrollY: 300 + 58 * 170, windowStart: 262 });
  });

  test('scrolls slider jumps into the list body instead of back to the search controls', () => {
    expect(libraryListScrollTarget(420, -12)).toBe(408);
    expect(libraryListScrollTarget(8, -12)).toBe(0);
    expect(libraryListScrollTarget(420, 168)).toBe(588);
  });
});
