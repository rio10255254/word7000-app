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
    expect(interactionMotion.libraryDetailMs).toBeGreaterThanOrEqual(600);
    expect(interactionMotion.libraryDetailMs).toBeGreaterThan(interactionMotion.settingsPanelMs);
    expect(interactionMotion.libraryDetailExitMs).toBeGreaterThanOrEqual(320);
    expect(interactionMotion.libraryDetailExitMs).toBeGreaterThan(interactionMotion.settingsPanelExitMs);
    expect(interactionMotion.panelSlideX).toBeGreaterThanOrEqual(18);
    expect(interactionMotion.panelSlideX).toBeLessThanOrEqual(28);
    expect(interactionMotion.panelPushScale).toBeGreaterThan(0.97);
    expect(interactionMotion.panelPushScale).toBeLessThan(0.99);
    expect(interactionMotion.libraryDetailWarmupAt).toBeGreaterThan(0.5);
    expect(interactionMotion.libraryDetailWarmupAt).toBeLessThan(0.65);
    expect(interactionMotion.libraryDetailSettleAt).toBeGreaterThan(0.88);
    expect(interactionMotion.libraryDetailSettleAt).toBeLessThan(0.98);
    expect(interactionMotion.libraryDetailWarmupAt).toBeLessThan(interactionMotion.libraryDetailSettleAt);
    expect(interactionMotion.libraryDetailOpenEasing[0]).toBeGreaterThanOrEqual(0.4);
    expect(interactionMotion.libraryDetailOpenEasing[1]).toBe(0);
    expect(interactionMotion.libraryDetailOpenEasing[2]).toBeLessThanOrEqual(0.24);
  });

  test('staggers list entry movement without growing forever', () => {
    expect(interactionMotion.staggeredListLimit).toBeGreaterThanOrEqual(12);
    expect(interactionMotion.staggeredListLimit).toBeLessThanOrEqual(24);
    expect(listEnterOffset(0)).toBe(10);
    expect(listEnterOffset(3)).toBe(16);
    expect(listEnterOffset(20)).toBe(22);
    expect(listEnterOffset(-4)).toBe(10);
  });
});
