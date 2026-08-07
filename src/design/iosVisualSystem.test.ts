import { describe, expect, test } from 'vitest';
import { iosVisual } from './iosVisualSystem';

function relativeLuminance(hex: string) {
  const channels = hex
    .match(/[0-9a-f]{2}/gi)!
    .map((value) => Number.parseInt(value, 16) / 255)
    .map((value) => (value <= 0.04045 ? value / 12.92 : ((value + 0.055) / 1.055) ** 2.4));

  return (0.2126 * channels[0]) + (0.7152 * channels[1]) + (0.0722 * channels[2]);
}

function contrastRatio(foreground: string, background: string) {
  const foregroundLuminance = relativeLuminance(foreground);
  const backgroundLuminance = relativeLuminance(background);
  const lighter = Math.max(foregroundLuminance, backgroundLuminance);
  const darker = Math.min(foregroundLuminance, backgroundLuminance);

  return (lighter + 0.05) / (darker + 0.05);
}

describe('iOS visual system', () => {
  test.each([
    ['light primary on page', iosVisual.light.label, iosVisual.light.background, 7],
    ['light secondary on page', iosVisual.light.labelSecondary, iosVisual.light.background, 4.5],
    ['light primary on surface', iosVisual.light.label, iosVisual.light.surface, 7],
    ['light secondary on surface', iosVisual.light.labelSecondary, iosVisual.light.surface, 4.5],
    ['light secondary on tinted control', iosVisual.light.labelSecondary, iosVisual.light.surfaceSecondary, 4.5],
    ['dark primary on page', iosVisual.dark.label, iosVisual.dark.background, 7],
    ['dark secondary on page', iosVisual.dark.labelSecondary, iosVisual.dark.background, 4.5],
    ['dark primary on surface', iosVisual.dark.label, iosVisual.dark.surface, 7],
    ['dark secondary on surface', iosVisual.dark.labelSecondary, iosVisual.dark.surface, 4.5],
    ['dark secondary on tinted control', iosVisual.dark.labelSecondary, iosVisual.dark.surfaceSecondary, 4.5],
  ])('%s stays readable', (_name, foreground, background, minimum) => {
    expect(contrastRatio(foreground, background)).toBeGreaterThanOrEqual(minimum);
  });

  test.each([
    ['light accent', iosVisual.light.accent, iosVisual.light.surface],
    ['dark accent', iosVisual.dark.accent, iosVisual.dark.surface],
  ])('%s remains visible as an interactive control', (_name, foreground, background) => {
    expect(contrastRatio(foreground, background)).toBeGreaterThanOrEqual(3);
  });

  test('uses lightly tinted controls instead of neutral gray blocks', () => {
    expect(iosVisual.light.surfaceSecondary).toBe('#F7FAFF');
    expect(iosVisual.light.surfaceTertiary).toBe('#EDF5FF');
    expect(iosVisual.dark.surfaceSecondary).toBe('#111A26');
    expect(iosVisual.dark.surfaceTertiary).toBe('#182538');
  });
});
