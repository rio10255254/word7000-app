import {
  Capsule,
  Circle,
  HStack,
  Image,
  ProgressView,
  Spacer,
  Text,
  VStack,
  ZStack,
} from '@expo/ui/swift-ui';
import {
  activityBackgroundTint,
  contentTransition,
  font,
  foregroundStyle,
  frame,
  lineLimit,
  minimumScaleFactor,
  monospacedDigit,
  padding,
  progressViewStyle,
  tint,
} from '@expo/ui/swift-ui/modifiers';
import { createLiveActivity, type LiveActivityEnvironment } from 'expo-widgets';
import type { StreakLiveActivityProps } from '../lib/streakReminder';

const StreakLiveActivityLayout = (
  props: StreakLiveActivityProps,
  environment: LiveActivityEnvironment,
) => {
  'widget';
  const isNoon = props.activityKind === 'noon';
  const progressTarget = Math.max(1, props.progressTarget ?? 1);
  const progressCurrent = Math.max(0, Math.min(progressTarget, props.progressCurrent ?? 0));
  const progressValue = progressCurrent / progressTarget;
  const remainingWords = Math.max(0, progressTarget - progressCurrent);
  const reduced = Boolean(environment.isLuminanceReduced);
  const completed = isNoon && remainingWords === 0;
  const accentColor = completed
    ? reduced ? '#63E6A1' : '#30D158'
    : isNoon
      ? reduced ? '#8BD7FF' : '#40A9FF'
      : reduced ? '#FFD76A' : '#FF9F0A';
  const accentSoft = completed
    ? '#163D2B'
    : isNoon
      ? '#102C42'
      : '#3D2A0C';
  const primaryColor = '#F5F7FA';
  const secondaryColor = reduced ? '#C7C7CC' : '#AEB5C0';
  const tertiaryColor = reduced ? '#A1A1A6' : '#7E8795';
  const activityBackground = reduced ? '#0C0D0F' : '#101217';
  const symbolName = completed
    ? 'checkmark.circle.fill'
    : isNoon
      ? 'book.closed.fill'
      : 'flame.fill';
  const compactProgress = `${progressCurrent}/${progressTarget}`;
  const minimalProgress = completed ? '✓' : `${remainingWords}`;
  const countdownInterval = {
    lower: new Date(props.startedAt),
    upper: new Date(props.expiresAt),
  };
  const progressModifiers = [
    progressViewStyle('linear'),
    tint(accentColor),
    frame({ maxWidth: Infinity }),
  ];

  const statusIcon = (
    <ZStack modifiers={[frame({ width: 42, height: 42 })]}>
      <Circle modifiers={[foregroundStyle(accentSoft), frame({ width: 42, height: 42 })]} />
      <Image systemName={symbolName} color={accentColor} size={21} />
    </ZStack>
  );

  const bannerMetric = isNoon ? (
    <VStack alignment="trailing" spacing={1} modifiers={[frame({ minWidth: 54 })]}>
      <Text
        modifiers={[
          font({ design: 'rounded', size: 21, weight: 'bold' }),
          foregroundStyle(primaryColor),
          monospacedDigit(),
          contentTransition('numericText'),
        ]}
      >
        {compactProgress}
      </Text>
      <Text modifiers={[font({ size: 10, weight: 'semibold' }), foregroundStyle(tertiaryColor)]}>
        {props.countdownLabel}
      </Text>
    </VStack>
  ) : (
    <VStack alignment="trailing" spacing={1} modifiers={[frame({ minWidth: 70 })]}>
      <Text
        countsDown
        timerInterval={countdownInterval}
        modifiers={[
          font({ design: 'rounded', size: 21, weight: 'bold' }),
          foregroundStyle(primaryColor),
          monospacedDigit(),
          minimumScaleFactor(0.72),
        ]}
      />
      <Text modifiers={[font({ size: 10, weight: 'semibold' }), foregroundStyle(accentColor)]}>
        {props.countdownLabel}
      </Text>
    </VStack>
  );

  const progressBar = isNoon ? (
    <ProgressView value={progressValue} modifiers={progressModifiers} />
  ) : (
    <ProgressView countsDown timerInterval={countdownInterval} modifiers={progressModifiers} />
  );

  const compactTrailing = isNoon ? (
    <Text
      modifiers={[
        font({ design: 'rounded', size: 13, weight: 'bold' }),
        foregroundStyle(accentColor),
        monospacedDigit(),
        minimumScaleFactor(0.72),
        contentTransition('numericText'),
      ]}
    >
      {compactProgress}
    </Text>
  ) : (
    <Text
      countsDown
      timerInterval={countdownInterval}
      modifiers={[
        font({ design: 'rounded', size: 13, weight: 'bold' }),
        foregroundStyle(accentColor),
        monospacedDigit(),
        minimumScaleFactor(0.68),
      ]}
    />
  );

  const expandedMetric = isNoon ? (
    <VStack alignment="trailing" spacing={1} modifiers={[padding({ top: 9, trailing: 12 })]}>
      <Text
        modifiers={[
          font({ design: 'rounded', size: 19, weight: 'bold' }),
          foregroundStyle(primaryColor),
          monospacedDigit(),
          contentTransition('numericText'),
        ]}
      >
        {compactProgress}
      </Text>
      <Text modifiers={[font({ size: 10, weight: 'semibold' }), foregroundStyle(accentColor)]}>
        {props.countdownLabel}
      </Text>
    </VStack>
  ) : (
    <VStack alignment="trailing" spacing={1} modifiers={[padding({ top: 9, trailing: 12 })]}>
      <Text
        countsDown
        timerInterval={countdownInterval}
        modifiers={[
          font({ design: 'rounded', size: 19, weight: 'bold' }),
          foregroundStyle(primaryColor),
          monospacedDigit(),
          minimumScaleFactor(0.72),
        ]}
      />
      <Text modifiers={[font({ size: 10, weight: 'semibold' }), foregroundStyle(accentColor)]}>
        {props.countdownLabel}
      </Text>
    </VStack>
  );

  return {
    banner: (
      <HStack
        alignment="center"
        spacing={12}
        modifiers={[
          padding({ horizontal: 16, vertical: 14 }),
          activityBackgroundTint(activityBackground),
        ]}
      >
        {statusIcon}
        <VStack alignment="leading" spacing={5} modifiers={[frame({ maxWidth: Infinity })]}>
          <Text
            modifiers={[
              font({ size: 16, weight: 'bold' }),
              foregroundStyle(primaryColor),
              lineLimit(1),
              minimumScaleFactor(0.82),
            ]}
          >
            {props.title}
          </Text>
          <Text
            modifiers={[
              font({ size: 12, weight: 'medium' }),
              foregroundStyle(secondaryColor),
              lineLimit(2),
              minimumScaleFactor(0.86),
            ]}
          >
            {props.keepStreakLabel}
          </Text>
          {progressBar}
          <HStack spacing={6}>
            <Text modifiers={[font({ size: 10, weight: 'semibold' }), foregroundStyle(accentColor)]}>
              {props.streakLabel}
            </Text>
            <Spacer />
            <Text modifiers={[font({ size: 10, weight: 'medium' }), foregroundStyle(tertiaryColor)]}>
              Word7000
            </Text>
          </HStack>
        </VStack>
        {bannerMetric}
      </HStack>
    ),
    bannerSmall: (
      <HStack spacing={8} modifiers={[padding({ horizontal: 12, vertical: 10 })]}>
        <Image systemName={symbolName} color={accentColor} size={16} />
        <VStack alignment="leading" spacing={1}>
          <Text modifiers={[font({ size: 12, weight: 'bold' }), lineLimit(1)]}>{props.title}</Text>
          <Text modifiers={[font({ size: 10, weight: 'medium' }), foregroundStyle(secondaryColor), lineLimit(1)]}>
            {props.streakLabel}
          </Text>
        </VStack>
        <Spacer />
        {compactTrailing}
      </HStack>
    ),
    compactLeading: (
      <HStack spacing={4}>
        <Image systemName={symbolName} color={accentColor} size={15} />
        <Text
          modifiers={[
            font({ design: 'rounded', size: 12, weight: 'bold' }),
            foregroundStyle(primaryColor),
            monospacedDigit(),
          ]}
        >
          {isNoon ? 'W7' : props.streak}
        </Text>
      </HStack>
    ),
    compactTrailing,
    minimal: isNoon ? (
      <ZStack modifiers={[frame({ width: 32, height: 32 })]}>
        <Circle modifiers={[foregroundStyle(accentSoft), frame({ width: 30, height: 30 })]} />
        <Text
          modifiers={[
            font({ design: 'rounded', size: 12, weight: 'bold' }),
            foregroundStyle(accentColor),
            monospacedDigit(),
            minimumScaleFactor(0.7),
            contentTransition('numericText'),
          ]}
        >
          {minimalProgress}
        </Text>
      </ZStack>
    ) : (
      <Text
        countsDown
        timerInterval={countdownInterval}
        modifiers={[
          font({ design: 'rounded', size: 11, weight: 'bold' }),
          foregroundStyle(accentColor),
          monospacedDigit(),
          minimumScaleFactor(0.62),
        ]}
      />
    ),
    expandedLeading: (
      <HStack spacing={5} modifiers={[padding({ top: 9, leading: 12 })]}>
        <Image systemName={symbolName} color={accentColor} size={19} />
        <Text
          modifiers={[
            font({ design: 'rounded', size: 15, weight: 'bold' }),
            foregroundStyle(primaryColor),
            monospacedDigit(),
          ]}
        >
          {isNoon ? 'W7' : props.streak}
        </Text>
      </HStack>
    ),
    expandedTrailing: expandedMetric,
    expandedCenter: (
      <Text
        modifiers={[
          font({ size: 15, weight: 'bold' }),
          foregroundStyle(primaryColor),
          lineLimit(1),
          minimumScaleFactor(0.82),
          padding({ horizontal: 14 }),
        ]}
      >
        {props.title}
      </Text>
    ),
    expandedBottom: (
      <VStack alignment="leading" spacing={7} modifiers={[padding({ horizontal: 14, vertical: 9 })]}>
        <Text
          modifiers={[
            font({ size: 12, weight: 'medium' }),
            foregroundStyle(secondaryColor),
            lineLimit(2),
            minimumScaleFactor(0.82),
          ]}
        >
          {props.keepStreakLabel}
        </Text>
        {progressBar}
        <HStack spacing={8}>
          <Text modifiers={[font({ size: 10, weight: 'semibold' }), foregroundStyle(accentColor)]}>
            {props.streakLabel}
          </Text>
          <Spacer />
          <HStack spacing={4}>
            <Capsule modifiers={[foregroundStyle(accentColor), frame({ width: 16, height: 4 })]} />
            <Text modifiers={[font({ size: 10, weight: 'medium' }), foregroundStyle(tertiaryColor)]}>
              Word7000
            </Text>
          </HStack>
        </HStack>
      </VStack>
    ),
  };
};

export default createLiveActivity<StreakLiveActivityProps>('StreakLiveActivity', StreakLiveActivityLayout);
