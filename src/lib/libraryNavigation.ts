export function scrollTargetFromSlider(
  dragY: number,
  trackHeight: number,
  contentHeight: number,
  viewportHeight: number,
): number {
  const maxScroll = Math.max(0, contentHeight - viewportHeight);
  if (maxScroll === 0 || trackHeight <= 0) {
    return 0;
  }

  const ratio = clamp(dragY / trackHeight, 0, 1);
  return Math.round(maxScroll * ratio);
}

export function scrollThumbOffset(
  scrollY: number,
  contentHeight: number,
  viewportHeight: number,
  trackHeight: number,
  thumbHeight: number,
): number {
  const maxScroll = Math.max(0, contentHeight - viewportHeight);
  const maxThumbOffset = Math.max(0, trackHeight - thumbHeight);
  if (maxScroll === 0 || maxThumbOffset === 0) {
    return 0;
  }

  return Math.round(maxThumbOffset * clamp(scrollY / maxScroll, 0, 1));
}

export function wordWindowStartFromSlider(
  dragY: number,
  trackHeight: number,
  totalWords: number,
  windowSize: number,
  thumbHeight = 0,
): number {
  const maxStart = Math.max(0, totalWords - windowSize);
  const usableTrackHeight = Math.max(1, trackHeight - thumbHeight);
  if (maxStart === 0 || trackHeight <= 0) {
    return 0;
  }

  const ratio =
    thumbHeight > 0
      ? clamp((dragY - thumbHeight / 2) / usableTrackHeight, 0, 1)
      : clamp(dragY / trackHeight, 0, 1);
  return Math.round(maxStart * ratio);
}

function clamp(value: number, min: number, max: number): number {
  return Math.min(max, Math.max(min, value));
}
