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

export function wordIndexFromLibraryScroll(
  windowStart: number,
  scrollY: number,
  listTopY: number,
  itemExtent: number,
  totalWords: number,
  windowSize: number,
): number {
  const maxStart = Math.max(0, totalWords - windowSize);
  const boundedWindowStart = clamp(windowStart, 0, maxStart);
  const safeItemExtent = Math.max(1, itemExtent);
  const localRows = Math.floor(Math.max(0, scrollY - listTopY) / safeItemExtent);
  const boundedLocalRows = clamp(localRows, 0, Math.max(0, windowSize - 1));

  return clamp(boundedWindowStart + boundedLocalRows, 0, maxStart);
}

export function wordWindowStartFromFullLibraryScroll(
  scrollY: number,
  listTopY: number,
  itemExtent: number,
  totalWords: number,
  windowSize: number,
): number {
  const maxStart = Math.max(0, totalWords - windowSize);
  const safeItemExtent = Math.max(1, itemExtent);
  const localRows = Math.floor(Math.max(0, scrollY - listTopY) / safeItemExtent);

  return clamp(localRows, 0, maxStart);
}

export function virtualWindowStartFromWordIndex(
  wordIndex: number,
  totalWords: number,
  windowSize: number,
  leadingBuffer: number,
): number {
  const maxStart = Math.max(0, totalWords - windowSize);
  const boundedWordIndex = clamp(Math.floor(Math.max(0, wordIndex)), 0, Math.max(0, totalWords - 1));

  if (boundedWordIndex >= maxStart) {
    return maxStart;
  }

  return clamp(boundedWordIndex - Math.max(0, Math.floor(leadingBuffer)), 0, maxStart);
}

export function virtualWindowStartFromScroll(
  scrollY: number,
  listTopY: number,
  itemExtent: number,
  totalWords: number,
  windowSize: number,
  leadingBuffer: number,
): number {
  const safeItemExtent = Math.max(1, itemExtent);
  const localRows = Math.floor(Math.max(0, scrollY - listTopY) / safeItemExtent);

  return virtualWindowStartFromWordIndex(localRows, totalWords, windowSize, leadingBuffer);
}

export function virtualListSpacerHeights(
  windowStart: number,
  visibleCount: number,
  totalWords: number,
  itemExtent: number,
): { top: number; bottom: number } {
  const safeItemExtent = Math.max(1, itemExtent);
  const boundedStart = clamp(Math.floor(Math.max(0, windowStart)), 0, Math.max(0, totalWords));
  const boundedVisibleCount = clamp(Math.floor(Math.max(0, visibleCount)), 0, Math.max(0, totalWords - boundedStart));

  return {
    top: Math.round(boundedStart * safeItemExtent),
    bottom: Math.round(Math.max(0, totalWords - boundedStart - boundedVisibleCount) * safeItemExtent),
  };
}

export function shouldSyncLibraryWindowFromScroll(scrollY: number, listTopY: number, windowStart: number): boolean {
  return scrollY >= listTopY || windowStart > 0;
}

export function recenteredWordWindowFromScroll(
  windowStart: number,
  scrollY: number,
  listTopY: number,
  itemExtent: number,
  totalWords: number,
  windowSize: number,
  options: { forwardAnchor?: number; backwardAnchor?: number } = {},
): { scrollY: number; windowStart: number } {
  const maxStart = Math.max(0, totalWords - windowSize);
  const boundedWindowStart = clamp(windowStart, 0, maxStart);
  const safeItemExtent = Math.max(1, itemExtent);
  const forwardAnchor = clamp(options.forwardAnchor ?? Math.floor(windowSize * 0.58), 1, Math.max(1, windowSize - 1));
  const backwardAnchor = clamp(options.backwardAnchor ?? Math.floor(windowSize * 0.22), 0, forwardAnchor - 1);
  const localRows = Math.floor(Math.max(0, scrollY - listTopY) / safeItemExtent);

  if (localRows > forwardAnchor && boundedWindowStart < maxStart) {
    const shift = Math.min(localRows - forwardAnchor, maxStart - boundedWindowStart);
    return {
      scrollY: Math.max(listTopY, Math.round(scrollY - shift * safeItemExtent)),
      windowStart: boundedWindowStart + shift,
    };
  }

  if (localRows < backwardAnchor && boundedWindowStart > 0) {
    const shift = Math.min(backwardAnchor - localRows, boundedWindowStart);
    const anchoredScrollY = Math.max(scrollY, listTopY);
    return {
      scrollY: Math.round(anchoredScrollY + shift * safeItemExtent),
      windowStart: boundedWindowStart - shift,
    };
  }

  return {
    scrollY,
    windowStart: boundedWindowStart,
  };
}

export function libraryListScrollTarget(listTopY: number, offsetY: number): number {
  return Math.max(0, Math.round(listTopY + offsetY));
}

function clamp(value: number, min: number, max: number): number {
  return Math.min(max, Math.max(min, value));
}
