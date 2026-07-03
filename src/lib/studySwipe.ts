export type StudySwipeDirection = 'known' | 'review';

export const STUDY_SWIPE_THRESHOLD = 58;
export const STUDY_SWIPE_FLING_DISTANCE = 36;
export const STUDY_SWIPE_FLING_VELOCITY = 0.58;
const STUDY_SWIPE_INTENT_X = 8;
const STUDY_SWIPE_INTENT_SLOPE = 0.65;
const STUDY_SWIPE_PREVIEW_X = 20;

export function shouldClaimStudySwipe(dx: number, dy: number): boolean {
  const absX = Math.abs(dx);
  const absY = Math.abs(dy);
  return absX >= STUDY_SWIPE_INTENT_X && absX >= absY * STUDY_SWIPE_INTENT_SLOPE;
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
