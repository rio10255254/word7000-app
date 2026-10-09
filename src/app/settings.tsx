import { Redirect, useRouter } from 'expo-router';
import { useEffect, useRef, useState } from 'react';
import { Animated, Appearance, Easing, Platform, ScrollView, StyleSheet, View } from 'react-native';
import { ProfileSettingsView, Word7000RouteScreen } from '../../App';
import { useAppRouteBridge } from '../lib/appRouteBridge';
import { useRuntimePerformance } from '../lib/runtimePerformance';

export default function SettingsRoute() {
  const router = useRouter();
  const bridge = useAppRouteBridge();
  const runtimePerformance = useRuntimePerformance();
  const themeTransitionOpacity = useRef(new Animated.Value(0)).current;
  const themeTransitionRunning = useRef(false);
  const themeTransitionAnimation = useRef<Animated.CompositeAnimation | null>(null);
  const [themeTransitionColor, setThemeTransitionColor] = useState('#F2F2F7');
  const [showThemeTransition, setShowThemeTransition] = useState(false);

  useEffect(
    () => () => {
      themeTransitionAnimation.current?.stop();
    },
    [],
  );

  if (!bridge) {
    return <Redirect href="/" />;
  }

  const closeRoute = () => {
    if (router.canGoBack()) {
      router.back();
    } else {
      router.replace('/');
    }
  };

  const changeThemePreference = (preference: 'system' | 'light' | 'dark') => {
    if (preference === bridge.themePreference || themeTransitionRunning.current) {
      return;
    }
    const nextMode = preference === 'system'
      ? Appearance.getColorScheme() === 'dark' ? 'dark' : 'light'
      : preference;
    // Only an actual change of colours deserves the crossfade; switching to
    // "system" while the system already matches just updates the choice.
    if (nextMode === bridge.themeMode || runtimePerformance.conserveResources) {
      bridge.actions.setThemePreference(preference);
      return;
    }

    themeTransitionRunning.current = true;
    setThemeTransitionColor(nextMode === 'dark' ? '#000000' : '#F2F2F7');
    setShowThemeTransition(true);
    themeTransitionOpacity.setValue(0);
    bridge.actions.setThemePreference(preference);

    const animation = Animated.sequence([
      Animated.timing(themeTransitionOpacity, {
        duration: 190,
        easing: Easing.out(Easing.cubic),
        toValue: 1,
        useNativeDriver: Platform.OS !== 'web',
      }),
      Animated.delay(24),
      Animated.timing(themeTransitionOpacity, {
        duration: 280,
        easing: Easing.inOut(Easing.cubic),
        toValue: 0,
        useNativeDriver: Platform.OS !== 'web',
      }),
    ]);
    themeTransitionAnimation.current = animation;
    animation.start(() => {
      themeTransitionRunning.current = false;
      setShowThemeTransition(false);
      themeTransitionAnimation.current = null;
    });
  };

  return (
    <Word7000RouteScreen
      studyMode={bridge.studyMode}
      themeMode={bridge.themeMode}
      vocabularyWords={bridge.vocabularyWords}
    >
      <View style={routeStyles.screen}>
        <ScrollView
          alwaysBounceVertical={false}
          automaticallyAdjustContentInsets={false}
          automaticallyAdjustKeyboardInsets={Platform.OS === 'ios'}
          bounces={false}
          contentContainerStyle={routeStyles.content}
          contentInsetAdjustmentBehavior="never"
          keyboardDismissMode="on-drag"
          keyboardShouldPersistTaps="handled"
          overScrollMode="never"
          showsVerticalScrollIndicator={false}
          style={routeStyles.scroll}
        >
          <ProfileSettingsView
            accountBusy={bridge.accountBusy}
            accountReady={bridge.accountReady}
            dailyTarget={bridge.progress.dailyTarget}
            developerMessage={bridge.developerMessage}
            developerVocabulary={bridge.developerVocabulary}
            streakReminderEnabled={bridge.streakReminderEnabled}
            studyMode={bridge.studyMode}
            themeMode={bridge.themeMode}
            themePreference={bridge.themePreference}
            vocabularyCount={bridge.vocabularyWords.length}
            onBack={closeRoute}
            onClearDeveloperVocabulary={bridge.actions.clearDeveloperVocabulary}
            onConfirmDeleteAccountData={bridge.actions.confirmDeleteAccountData}
            onExportVocabulary={bridge.actions.exportVocabulary}
            onImportVocabulary={bridge.actions.importVocabulary}
            onOpenAppInfoLink={bridge.actions.openAppInfoLink}
            onDailyTargetChange={bridge.actions.setDailyTarget}
            onStreakReminderEnabledChange={bridge.actions.setStreakReminderEnabled}
            onThemePreferenceChange={changeThemePreference}
          />
        </ScrollView>
        {showThemeTransition && (
          <Animated.View
            pointerEvents="auto"
            style={[
              routeStyles.themeTransition,
              { backgroundColor: themeTransitionColor, opacity: themeTransitionOpacity },
            ]}
            testID="settings-theme-transition-overlay"
          />
        )}
      </View>
    </Word7000RouteScreen>
  );
}

const routeStyles = StyleSheet.create({
  content: {
    padding: 18,
    paddingBottom: 30,
  },
  screen: {
    flex: 1,
    overflow: 'hidden',
  },
  scroll: {
    flex: 1,
  },
  themeTransition: {
    bottom: 0,
    left: 0,
    position: 'absolute',
    right: 0,
    top: 0,
    zIndex: 20,
  },
});
