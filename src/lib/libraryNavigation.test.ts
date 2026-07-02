import { describe, expect, test } from 'vitest';
import {
  libraryListScrollTarget,
  recenteredWordWindowFromScroll,
  scrollTargetFromSlider,
  scrollThumbOffset,
  shouldSyncLibraryWindowFromScroll,
  virtualListSpacerHeights,
  virtualWindowStartFromScroll,
  virtualWindowStartFromWordIndex,
  wordIndexFromLibraryScroll,
  wordWindowStartFromFullLibraryScroll,
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

  test('keeps fast upward flings inside the list when earlier virtual rows still exist', () => {
    expect(shouldSyncLibraryWindowFromScroll(40, 300, 320)).toBe(true);
    expect(shouldSyncLibraryWindowFromScroll(40, 300, 0)).toBe(false);

    expect(
      recenteredWordWindowFromScroll(320, 40, 300, 170, 7000, 260, {
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

  test('keeps the full virtual library height around the rendered word window', () => {
    expect(virtualListSpacerHeights(3700, 260, 7000, 170)).toEqual({
      bottom: 516800,
      top: 629000,
    });

    expect(virtualListSpacerHeights(6740, 260, 7000, 170)).toEqual({
      bottom: 0,
      top: 1145800,
    });
  });

  test('derives a buffered word window from absolute page scroll', () => {
    expect(virtualWindowStartFromScroll(300 + 3700 * 170, 300, 170, 7000, 260, 58)).toBe(3642);
    expect(virtualWindowStartFromScroll(300 + 30 * 170, 300, 170, 7000, 260, 58)).toBe(0);
    expect(virtualWindowStartFromScroll(300 + 6980 * 170, 300, 170, 7000, 260, 58)).toBe(6740);
  });

  test('keeps slider jumps and thumb position in the same absolute library coordinate space', () => {
    expect(virtualWindowStartFromWordIndex(3700, 7000, 260, 58)).toBe(3642);
    expect(wordWindowStartFromFullLibraryScroll(300 + 3700 * 170, 300, 170, 7000, 260)).toBe(3700);
    expect(wordWindowStartFromFullLibraryScroll(300 + 6980 * 170, 300, 170, 7000, 260)).toBe(6740);
  });
});
