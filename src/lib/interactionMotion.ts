export type InteractionTone = 'primary' | 'secondary' | 'chip' | 'icon' | 'tab' | 'list' | 'libraryItem';

type PressMotion = {
  pressedOpacity: number;
  pressedScale: number;
  pressedTranslateY: number;
};

const pressMotions: Record<InteractionTone, PressMotion> = {
  primary: { pressedOpacity: 0.92, pressedScale: 0.972, pressedTranslateY: 1 },
  secondary: { pressedOpacity: 0.94, pressedScale: 0.976, pressedTranslateY: 1 },
  chip: { pressedOpacity: 0.92, pressedScale: 0.965, pressedTranslateY: 0 },
  icon: { pressedOpacity: 0.9, pressedScale: 0.955, pressedTranslateY: 0 },
  tab: { pressedOpacity: 0.92, pressedScale: 0.96, pressedTranslateY: 1 },
  list: { pressedOpacity: 0.96, pressedScale: 0.985, pressedTranslateY: 1 },
  libraryItem: { pressedOpacity: 0.93, pressedScale: 0.972, pressedTranslateY: 2 },
};

export const interactionMotion = {
  cardMs: 260,
  hoverMs: 150,
  listMs: 280,
  panelCloseMs: 380,
  panelCollapsedHeight: 0,
  panelFadeMs: 180,
  panelMeasureMs: 80,
  panelMs: 260,
  panelPushScale: 0.982,
  panelSlideX: 22,
  press: pressMotions,
  pressInMs: 88,
  releaseMs: 180,
  screenMs: 280,
  settingsPanelExitMs: 170,
  settingsPanelMs: 310,
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
