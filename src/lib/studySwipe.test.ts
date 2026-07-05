import { describe, expect, test } from 'vitest';
import {
  resolveStudyGestureIntent,
  resolveStudySwipeDirection,
  resolveStudySwipeReleaseDirection,
  shouldClaimStudySwipe,
} from './studySwipe';

describe('study swipe gestures', () => {
  test('claims diagonal horizontal card drags without stealing vertical scrolls', () => {
    expect(shouldClaimStudySwipe(18, 12)).toBe(true);
    expect(shouldClaimStudySwipe(-26, 24)).toBe(true);
    expect(shouldClaimStudySwipe(8, 34)).toBe(false);
  });

  test('separates horizontal card swipes from vertical page scrolling', () => {
    expect(resolveStudyGestureIntent(5, 3)).toBe('card');
    expect(resolveStudyGestureIntent(-5, 3)).toBe('card');
    expect(resolveStudyGestureIntent(5, 6)).toBe(null);
    expect(resolveStudyGestureIntent(7, 4)).toBe('card');
    expect(resolveStudyGestureIntent(28, 24)).toBe('card');
    expect(resolveStudyGestureIntent(-34, 25)).toBe('card');
    expect(resolveStudyGestureIntent(30, 35)).toBe('scroll');
    expect(resolveStudyGestureIntent(-22, 26)).toBe('scroll');
    expect(resolveStudyGestureIntent(10, 24)).toBe('scroll');
    expect(resolveStudyGestureIntent(-12, 30)).toBe('scroll');
    expect(resolveStudyGestureIntent(4, 4)).toBe(null);
  });

  test('accepts easier distance and quick fling gestures in both directions', () => {
    expect(resolveStudySwipeDirection(58, 0)).toBe('known');
    expect(resolveStudySwipeDirection(-58, 0)).toBe('review');
    expect(resolveStudySwipeDirection(38, 0.72)).toBe('known');
    expect(resolveStudySwipeDirection(-38, -0.72)).toBe('review');
    expect(resolveStudySwipeDirection(30, 0.4)).toBe('known');
    expect(resolveStudySwipeDirection(-30, -0.4)).toBe('review');
    expect(resolveStudySwipeDirection(34, 0.12)).toBe(null);
  });

  test('commits a meaningful short release even when native velocity is missing', () => {
    expect(resolveStudySwipeReleaseDirection(44, 0)).toBe('known');
    expect(resolveStudySwipeReleaseDirection(-44, 0)).toBe('review');
    expect(resolveStudySwipeReleaseDirection(34, 0)).toBe(null);
    expect(resolveStudySwipeReleaseDirection(-34, 0)).toBe(null);
  });
});
