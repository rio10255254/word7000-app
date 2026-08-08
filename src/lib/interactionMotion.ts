export type InteractionTone = 'primary' | 'secondary' | 'chip' | 'icon' | 'tab' | 'list' | 'libraryItem';

type PressMotion = {
  pressedOpacity: number;
  pressedScale: number;
  pressedTranslateY: number;
};

const pressMotions: Record<InteractionTone, PressMotion> = {
  primary: { pressedOpacity: 0.92, pressedScale: 0.984, pressedTranslateY: 0.5 },
  secondary: { pressedOpacity: 0.93, pressedScale: 0.988, pressedTranslateY: 0.5 },
  chip: { pressedOpacity: 0.91, pressedScale: 0.976, pressedTranslateY: 0 },
  icon: { pressedOpacity: 0.9, pressedScale: 0.966, pressedTranslateY: 0 },
  tab: { pressedOpacity: 0.93, pressedScale: 0.978, pressedTranslateY: 0 },
  list: { pressedOpacity: 0.96, pressedScale: 0.994, pressedTranslateY: 0 },
  libraryItem: { pressedOpacity: 0.95, pressedScale: 0.99, pressedTranslateY: 0.5 },
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
  pressInMs: 92,
  pressReleaseDampingRatio: 0.88,
  releaseMs: 310,
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
