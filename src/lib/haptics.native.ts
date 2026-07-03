import * as Haptics from 'expo-haptics';
import type { InteractionTone } from './interactionMotion';

const impactByTone: Record<InteractionTone, Haptics.ImpactFeedbackStyle> = {
  primary: Haptics.ImpactFeedbackStyle.Medium,
  secondary: Haptics.ImpactFeedbackStyle.Light,
  chip: Haptics.ImpactFeedbackStyle.Light,
  icon: Haptics.ImpactFeedbackStyle.Light,
  tab: Haptics.ImpactFeedbackStyle.Light,
  list: Haptics.ImpactFeedbackStyle.Light,
  libraryItem: Haptics.ImpactFeedbackStyle.Medium,
};

export function triggerPressHaptic(tone: InteractionTone): void {
  try {
    const feedback =
      tone === 'chip' || tone === 'tab'
        ? Haptics.selectionAsync()
        : Haptics.impactAsync(impactByTone[tone] ?? Haptics.ImpactFeedbackStyle.Light);

    feedback.catch(() => undefined);
  } catch {
    // Older test builds may not include the native haptics module yet.
  }
}
