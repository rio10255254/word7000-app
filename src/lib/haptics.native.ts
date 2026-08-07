import * as Haptics from 'expo-haptics';
import type { InteractionTone } from './interactionMotion';

const impactByTone: Record<InteractionTone, Haptics.ImpactFeedbackStyle> = {
  primary: Haptics.ImpactFeedbackStyle.Heavy,
  secondary: Haptics.ImpactFeedbackStyle.Medium,
  chip: Haptics.ImpactFeedbackStyle.Light,
  icon: Haptics.ImpactFeedbackStyle.Light,
  tab: Haptics.ImpactFeedbackStyle.Medium,
  list: Haptics.ImpactFeedbackStyle.Light,
  libraryItem: Haptics.ImpactFeedbackStyle.Medium,
};

export function triggerPressHaptic(tone: InteractionTone): void {
  try {
    const feedback =
      tone === 'icon'
        ? Haptics.selectionAsync()
        : Haptics.impactAsync(impactByTone[tone] ?? Haptics.ImpactFeedbackStyle.Light);

    feedback.catch(() => undefined);
  } catch {
    // Older test builds may not include the native haptics module yet.
  }
}
