export type InteractionTone = 'primary' | 'secondary' | 'chip' | 'icon' | 'tab' | 'list';

type PressMotion = {
  pressedScale: number;
  pressedTranslateY: number;
};

const pressMotions: Record<InteractionTone, PressMotion> = {
  primary: { pressedScale: 0.972, pressedTranslateY: 1 },
  secondary: { pressedScale: 0.976, pressedTranslateY: 1 },
  chip: { pressedScale: 0.965, pressedTranslateY: 0 },
  icon: { pressedScale: 0.955, pressedTranslateY: 0 },
  tab: { pressedScale: 0.96, pressedTranslateY: 1 },
  list: { pressedScale: 0.985, pressedTranslateY: 1 },
};

export const interactionMotion = {
  cardMs: 260,
  hoverMs: 130,
  listMs: 280,
  panelMaxHeight: 360,
  panelMs: 230,
  press: pressMotions,
  pressInMs: 88,
  releaseMs: 180,
  screenMs: 280,
};

export function pressMotionFor(tone: InteractionTone): PressMotion {
  return pressMotions[tone];
}

export function listEnterOffset(index: number): number {
  return 10 + Math.min(Math.max(0, index), 6) * 2;
}
