export type StudySwipeDirection = 'known' | 'review';
export type StudyGestureIntent = 'card' | 'scroll';

export const STUDY_SWIPE_THRESHOLD = 58;
export const STUDY_SWIPE_FLING_DISTANCE = 36;
export const STUDY_SWIPE_FLING_VELOCITY = 0.58;
const STUDY_SWIPE_INTENT_X = 7;
const STUDY_SWIPE_INTENT_SLOPE = 0.92;
const STUDY_SCROLL_INTENT_Y = 14;
const STUDY_SCROLL_INTENT_SLOPE = 1.08;
const STUDY_SWIPE_PREVIEW_X = 20;

export function resolveStudyGestureIntent(dx: number, dy: number): StudyGestureIntent | null {
  const absX = Math.abs(dx);
  const absY = Math.abs(dy);

  if (absY >= STUDY_SCROLL_INTENT_Y && absY >= absX * STUDY_SCROLL_INTENT_SLOPE) {
    return 'scroll';
  }

  if (absX >= STUDY_SWIPE_INTENT_X && absX >= absY * STUDY_SWIPE_INTENT_SLOPE) {
    return 'card';
  }

  return null;
}

export function shouldClaimStudySwipe(dx: number, dy: number): boolean {
  return resolveStudyGestureIntent(dx, dy) === 'card';
}

export function previewStudySwipeDirection(dx: number): StudySwipeDirection | null {
  if (dx >= STUDY_SWIPE_PREVIEW_X) {
    return 'known';
  }

  if (dx <= -STUDY_SWIPE_PREVIEW_X) {
    return 'review';
  }

  return null;
}

export function resolveStudySwipeDirection(dx: number, vx = 0): StudySwipeDirection | null {
  if (dx >= STUDY_SWIPE_THRESHOLD || (dx >= STUDY_SWIPE_FLING_DISTANCE && vx >= STUDY_SWIPE_FLING_VELOCITY)) {
    return 'known';
  }

  if (dx <= -STUDY_SWIPE_THRESHOLD || (dx <= -STUDY_SWIPE_FLING_DISTANCE && vx <= -STUDY_SWIPE_FLING_VELOCITY)) {
    return 'review';
  }

  return null;
}
