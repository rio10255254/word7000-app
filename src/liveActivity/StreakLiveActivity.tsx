import { HStack, Image, Spacer, Text, VStack } from '@expo/ui/swift-ui';
import {
  activityBackgroundTint,
  font,
  foregroundStyle,
  frame,
  monospacedDigit,
  padding,
} from '@expo/ui/swift-ui/modifiers';
import { createLiveActivity, type LiveActivityEnvironment } from 'expo-widgets';
import type { StreakLiveActivityProps } from '../lib/streakReminder';

const StreakLiveActivityLayout = (
  props: StreakLiveActivityProps,
  environment: LiveActivityEnvironment,
) => {
  'widget';
  const primaryColor = environment.isLuminanceReduced ? '#FFFFFF' : '#F2F2F7';
  const secondaryColor = environment.isLuminanceReduced ? '#D1D1D6' : '#C7C7CC';
  const accentColor = environment.isLuminanceReduced ? '#FFD60A' : '#FF9F0A';
  const countdownInterval = {
    lower: new Date(props.startedAt),
    upper: new Date(props.expiresAt),
  };

  return {
    banner: (
      <HStack
        alignment="center"
        spacing={12}
        modifiers={[
          padding({ all: 16 }),
          activityBackgroundTint(environment.isLuminanceReduced ? '#111111' : '#101827'),
        ]}
      >
        <VStack alignment="center" spacing={3} modifiers={[frame({ width: 44 })]}>
          <Image systemName="flame.fill" color={accentColor} size={27} />
          <Text modifiers={[font({ size: 11, weight: 'semibold' }), foregroundStyle(accentColor)]}>
            {props.streak}
          </Text>
        </VStack>
        <VStack alignment="leading" spacing={3}>
          <Text modifiers={[font({ size: 16, weight: 'bold' }), foregroundStyle(primaryColor)]}>
            {props.title}
          </Text>
          <Text modifiers={[font({ size: 13, weight: 'semibold' }), foregroundStyle(accentColor)]}>
            {props.streakLabel}
          </Text>
          <Text modifiers={[font({ size: 12 }), foregroundStyle(secondaryColor)]}>
            {props.keepStreakLabel}
          </Text>
        </VStack>
        <Spacer />
        <VStack alignment="trailing" spacing={3}>
          <Text
            countsDown
            timerInterval={countdownInterval}
            modifiers={[
              font({ design: 'rounded', size: 23, weight: 'bold' }),
              foregroundStyle(primaryColor),
              monospacedDigit(),
            ]}
          />
          <Text modifiers={[font({ size: 10, weight: 'medium' }), foregroundStyle(secondaryColor)]}>
            {props.countdownLabel}
          </Text>
        </VStack>
      </HStack>
    ),
    compactLeading: <Image systemName="flame.fill" color={accentColor} size={16} />,
    compactTrailing: (
      <Text
        countsDown
        timerInterval={countdownInterval}
        modifiers={[font({ size: 13, weight: 'semibold' }), foregroundStyle(accentColor), monospacedDigit()]}
      />
    ),
    minimal: <Image systemName="flame.fill" color={accentColor} size={16} />,
    expandedLeading: (
      <VStack alignment="center" spacing={3} modifiers={[padding({ all: 8 })]}>
        <Image systemName="flame.fill" color={accentColor} size={25} />
        <Text modifiers={[font({ size: 11, weight: 'bold' }), foregroundStyle(accentColor)]}>
          {props.streak}
        </Text>
      </VStack>
    ),
    expandedTrailing: (
      <VStack alignment="trailing" spacing={2} modifiers={[padding({ all: 8 })]}>
        <Text
          countsDown
          timerInterval={countdownInterval}
          modifiers={[font({ design: 'rounded', size: 20, weight: 'bold' }), monospacedDigit()]}
        />
        <Text modifiers={[font({ size: 10 })]}>{props.countdownLabel}</Text>
      </VStack>
    ),
    expandedBottom: (
      <VStack alignment="leading" spacing={4} modifiers={[padding({ horizontal: 12, vertical: 8 })]}>
        <Text modifiers={[font({ size: 15, weight: 'bold' })]}>{props.title}</Text>
        <Text modifiers={[font({ size: 12 }), foregroundStyle(secondaryColor)]}>
          {props.keepStreakLabel}
        </Text>
      </VStack>
    ),
  };
};

export default createLiveActivity<StreakLiveActivityProps>('StreakLiveActivity', StreakLiveActivityLayout);
