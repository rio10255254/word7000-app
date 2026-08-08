export type InteractionTone = 'primary' | 'secondary' | 'chip' | 'icon' | 'tab' | 'list' | 'libraryItem';

type PressMotion = {
  pressedOpacity: number;
  pressedScale: number;
  pressedTranslateY: number;
};

const pressMotions: Record<InteractionTone, PressMotion> = {
  primary: { pressedOpacity: 0.94, pressedScale: 0.98, pressedTranslateY: 0.5 },
  secondary: { pressedOpacity: 0.95, pressedScale: 0.984, pressedTranslateY: 0.5 },
  chip: { pressedOpacity: 0.93, pressedScale: 0.97, pressedTranslateY: 0 },
  icon: { pressedOpacity: 0.9, pressedScale: 0.955, pressedTranslateY: 0 },
  tab: { pressedOpacity: 0.94, pressedScale: 0.97, pressedTranslateY: 0 },
  list: { pressedOpacity: 0.97, pressedScale: 0.992, pressedTranslateY: 0 },
  libraryItem: { pressedOpacity: 0.96, pressedScale: 0.988, pressedTranslateY: 0.5 },
};

export const interactionMotion = {
  cardMs: 210,
  hoverMs: 130,
  listMs: 280,
  panelCloseMs: 250,
  panelCollapsedHeight: 0,
  panelFadeMs: 180,
  panelMeasureMs: 80,
  panelMs: 300,
  panelPushScale: 0.982,
  panelSlideX: 22,
  press: pressMotions,
  pressInMs: 70,
  pressReleaseDampingRatio: 0.9,
  releaseMs: 220,
  settingsPanelExitMs: 220,
  settingsPanelMs: 320,
  libraryDetailExitMs: 340,
  libraryDetailMs: 620,
  libraryDetailWarmupAt: 0.56,
  libraryDetailSettleAt: 0.93,
  libraryDetailOpenEasing: [0.45, 0, 0.2, 1] as const,
  libraryDetailCloseEasing: [0.38, 0, 0.22, 1] as const,
  guideStepMs: 280,
  staggeredListLimit: 18,
};

export function pressMotionFor(tone: InteractionTone): PressMotion {
  return pressMotions[tone];
}

export function listEnterOffset(index: number): number {
  return 10 + Math.min(Math.max(0, index), 6) * 2;
}
