import { describe, expect, test } from 'vitest';
import { interactionMotion, listEnterOffset, pressMotionFor } from './interactionMotion';

describe('interaction motion presets', () => {
  test('defines refined press motion for every interactive surface', () => {
    expect(interactionMotion.pressInMs).toBeLessThan(interactionMotion.releaseMs);

    for (const tone of ['primary', 'secondary', 'chip', 'icon', 'tab', 'list', 'libraryItem'] as const) {
      const motion = pressMotionFor(tone);
      expect(motion.pressedScale).toBeLessThan(1);
      expect(motion.pressedScale).toBeGreaterThan(0.95);
      expect(motion.pressedOpacity).toBeLessThan(1);
      expect(motion.pressedOpacity).toBeGreaterThan(0.86);
      expect(motion.pressedTranslateY).toBeLessThanOrEqual(2);
    }

    const libraryMotion = pressMotionFor('libraryItem');
    const listMotion = pressMotionFor('list');
    expect(libraryMotion.pressedScale).toBeLessThan(listMotion.pressedScale);
    expect(libraryMotion.pressedOpacity).toBeLessThan(listMotion.pressedOpacity);
    expect(libraryMotion.pressedTranslateY).toBeGreaterThan(listMotion.pressedTranslateY);
  });

  test('uses measured filter panel motion instead of large max-height collapsing', () => {
    expect(interactionMotion.panelCollapsedHeight).toBe(0);
    expect(interactionMotion.panelCloseMs).toBeGreaterThan(interactionMotion.panelMs);
    expect(interactionMotion.panelMeasureMs).toBeLessThan(interactionMotion.panelMs);
    expect(interactionMotion.panelFadeMs).toBeLessThanOrEqual(interactionMotion.panelMs);
  });

  test('defines panel-level motion for settings and tutorial transitions', () => {
    expect(interactionMotion.settingsPanelMs).toBeGreaterThan(interactionMotion.pressInMs);
    expect(interactionMotion.settingsPanelExitMs).toBeLessThan(interactionMotion.settingsPanelMs);
    expect(interactionMotion.guideStepMs).toBeGreaterThanOrEqual(interactionMotion.cardMs);
  });

  test('defines sticky word-detail motion close to the settings panel feel', () => {
    expect(interactionMotion.libraryDetailMs).toBeGreaterThan(interactionMotion.settingsPanelMs);
    expect(interactionMotion.libraryDetailExitMs).toBeGreaterThan(interactionMotion.settingsPanelExitMs);
    expect(interactionMotion.libraryDetailOvershootAt).toBeGreaterThan(0.55);
    expect(interactionMotion.libraryDetailOvershootAt).toBeLessThan(0.85);
  });

  test('staggers list entry movement without growing forever', () => {
    expect(listEnterOffset(0)).toBe(10);
    expect(listEnterOffset(3)).toBe(16);
    expect(listEnterOffset(20)).toBe(22);
    expect(listEnterOffset(-4)).toBe(10);
  });
});
