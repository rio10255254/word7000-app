import { DarkTheme, DefaultTheme, Stack, ThemeProvider } from 'expo-router';
import { Platform } from 'react-native';
import { GestureHandlerRootView } from 'react-native-gesture-handler';
import { SafeAreaProvider } from 'react-native-safe-area-context';
import { useAppRouteThemeMode } from '../lib/appRouteBridge';
import { prepareNativeSplash } from '../lib/nativeSplash';
import { iosVisual } from '../design/iosVisualSystem';
import { AppErrorBoundary } from '../components/AppErrorBoundary';
import { RuntimePerformanceProvider, useRuntimePerformance } from '../lib/runtimePerformance';

prepareNativeSplash();

const lightNavigationTheme = {
  ...DefaultTheme,
  colors: {
    ...DefaultTheme.colors,
    primary: iosVisual.light.accent,
    background: iosVisual.light.background,
    card: iosVisual.light.background,
    text: iosVisual.light.label,
    border: iosVisual.light.separator,
    notification: iosVisual.light.red,
  },
};

const darkNavigationTheme = {
  ...DarkTheme,
  colors: {
    ...DarkTheme.colors,
    primary: iosVisual.dark.accent,
    background: iosVisual.dark.background,
    card: iosVisual.dark.background,
    text: iosVisual.dark.label,
    border: iosVisual.dark.separator,
    notification: iosVisual.dark.red,
  },
};

function RootNavigator() {
  const themeMode = useAppRouteThemeMode();
  const performance = useRuntimePerformance();
  const modernIosNavigation = Platform.OS === 'ios' && !performance.isLegacyIos;
  const pushAnimation = Platform.OS === 'ios'
    ? modernIosNavigation ? 'simple_push' : 'default'
    : 'slide_from_right';

  return (
    <ThemeProvider value={themeMode === 'dark' ? darkNavigationTheme : lightNavigationTheme}>
      <Stack
        screenOptions={{
          animation: performance.reduceMotion ? 'fade' : pushAnimation,
          animationDuration: performance.reduceMotion ? 120 : modernIosNavigation ? 350 : undefined,
          animationMatchesGesture: modernIosNavigation && !performance.reduceMotion,
          fullScreenGestureEnabled: modernIosNavigation && !performance.reduceMotion,
          gestureEnabled: true,
          headerShown: false,
        }}
      >
        <Stack.Screen name="(tabs)" options={{ animation: 'none' }} />
        <Stack.Screen name="library/[wordId]" />
        <Stack.Screen name="sets" />
        <Stack.Screen name="scan" />
        <Stack.Screen name="settings" />
        <Stack.Screen name="stats" />
        <Stack.Screen name="auth/callback" options={{ animation: 'none' }} />
      </Stack>
    </ThemeProvider>
  );
}

export default function RootLayout() {
  return (
    <AppErrorBoundary>
      <GestureHandlerRootView style={{ flex: 1 }}>
        <SafeAreaProvider>
          <RuntimePerformanceProvider>
            <RootNavigator />
          </RuntimePerformanceProvider>
        </SafeAreaProvider>
      </GestureHandlerRootView>
    </AppErrorBoundary>
  );
}
