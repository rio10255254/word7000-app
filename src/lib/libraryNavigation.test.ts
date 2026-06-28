import { describe, expect, test } from 'vitest';
import { scrollTargetFromSlider, scrollThumbOffset, wordWindowStartFromSlider } from './libraryNavigation';

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
});
