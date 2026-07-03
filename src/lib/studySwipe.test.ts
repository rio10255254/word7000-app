import { describe, expect, test } from 'vitest';
import { resolveStudySwipeDirection, shouldClaimStudySwipe } from './studySwipe';

describe('study swipe gestures', () => {
  test('claims diagonal horizontal card drags without stealing vertical scrolls', () => {
    expect(shouldClaimStudySwipe(18, 12)).toBe(true);
    expect(shouldClaimStudySwipe(-26, 24)).toBe(true);
    expect(shouldClaimStudySwipe(8, 34)).toBe(false);
  });

  test('accepts easier distance and quick fling gestures in both directions', () => {
    expect(resolveStudySwipeDirection(58, 0)).toBe('known');
    expect(resolveStudySwipeDirection(-58, 0)).toBe('review');
    expect(resolveStudySwipeDirection(38, 0.72)).toBe('known');
    expect(resolveStudySwipeDirection(-38, -0.72)).toBe('review');
    expect(resolveStudySwipeDirection(34, 0.12)).toBe(null);
  });
});
