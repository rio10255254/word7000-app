import { describe, expect, test } from 'vitest';
import { interactionMotion, listEnterOffset, pressMotionFor } from './interactionMotion';

describe('interaction motion presets', () => {
  test('defines refined press motion for every interactive surface', () => {
    expect(interactionMotion.pressInMs).toBeLessThan(interactionMotion.releaseMs);

    for (const tone of ['primary', 'secondary', 'chip', 'icon', 'tab', 'list'] as const) {
      const motion = pressMotionFor(tone);
      expect(motion.pressedScale).toBeLessThan(1);
      expect(motion.pressedScale).toBeGreaterThan(0.95);
      expect(motion.pressedTranslateY).toBeLessThanOrEqual(1);
    }
  });

  test('staggers list entry movement without growing forever', () => {
    expect(listEnterOffset(0)).toBe(10);
    expect(listEnterOffset(3)).toBe(16);
    expect(listEnterOffset(20)).toBe(22);
    expect(listEnterOffset(-4)).toBe(10);
  });
});
