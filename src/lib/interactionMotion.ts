export type InteractionTone = 'primary' | 'secondary' | 'chip' | 'icon' | 'tab' | 'list' | 'libraryItem';

type PressMotion = {
  pressedOpacity: number;
  pressedScale: number;
  pressedTranslateY: number;
};

const pressMotions: Record<InteractionTone, PressMotion> = {
  primary: { pressedOpacity: 0.95, pressedScale: 0.977, pressedTranslateY: 1 },
  secondary: { pressedOpacity: 0.95, pressedScale: 0.983, pressedTranslateY: 0.75 },
  chip: { pressedOpacity: 0.94, pressedScale: 0.972, pressedTranslateY: 0 },
  icon: { pressedOpacity: 0.92, pressedScale: 0.958, pressedTranslateY: 0 },
  tab: { pressedOpacity: 0.95, pressedScale: 0.975, pressedTranslateY: 0 },
  list: { pressedOpacity: 0.97, pressedScale: 0.992, pressedTranslateY: 0 },
  libraryItem: { pressedOpacity: 0.965, pressedScale: 0.987, pressedTranslateY: 0.75 },
};

export const interactionMotion = {
  cardMs: 260,
  glassFeedbackMaxOpacity: 0.18,
  glassMorphMs: 260,
  hoverMs: 160,
  listMs: 320,
  panelCloseMs: 290,
  panelCollapsedHeight: 0,
  panelFadeMs: 220,
  panelMeasureMs: 90,
  panelMs: 360,
  panelPushScale: 0.982,
  panelSlideX: 22,
  press: pressMotions,
  pressInMs: 110,
  pressReleaseDampingRatio: 0.84,
  releaseMs: 350,
  settingsPanelExitMs: 270,
  settingsPanelMs: 380,
  libraryDetailExitMs: 340,
  libraryDetailMs: 620,
  libraryDetailWarmupAt: 0.56,
  libraryDetailSettleAt: 0.93,
  libraryDetailOpenEasing: [0.45, 0, 0.2, 1] as const,
  libraryDetailCloseEasing: [0.38, 0, 0.22, 1] as const,
  guideStepMs: 340,
  staggeredListLimit: 18,
};

export function pressMotionFor(tone: InteractionTone): PressMotion {
  return pressMotions[tone];
}

export function listEnterOffset(index: number): number {
  return 10 + Math.min(Math.max(0, index), 6) * 2;
}
