import { DarkTheme, DefaultTheme, Stack, ThemeProvider } from 'expo-router';
import { Platform } from 'react-native';
import { GestureHandlerRootView } from 'react-native-gesture-handler';
import { SafeAreaProvider } from 'react-native-safe-area-context';
import { useAppRouteThemeMode } from '../lib/appRouteBridge';
import { prepareNativeSplash } from '../lib/nativeSplash';

prepareNativeSplash();

export default function RootLayout() {
  const themeMode = useAppRouteThemeMode();
  const pushAnimation = Platform.OS === 'ios' ? 'simple_push' : 'slide_from_right';

  return (
    <GestureHandlerRootView style={{ flex: 1 }}>
      <SafeAreaProvider>
        <ThemeProvider value={themeMode === 'dark' ? DarkTheme : DefaultTheme}>
          <Stack
            screenOptions={{
              animation: pushAnimation,
              animationDuration: 360,
              fullScreenGestureEnabled: true,
              gestureEnabled: true,
              headerShown: false,
            }}
          >
            <Stack.Screen name="index" options={{ animation: 'none' }} />
            <Stack.Screen name="library/[wordId]" />
            <Stack.Screen name="sets" />
            <Stack.Screen name="settings" />
            <Stack.Screen name="auth/callback" options={{ animation: 'none' }} />
          </Stack>
        </ThemeProvider>
      </SafeAreaProvider>
    </GestureHandlerRootView>
  );
}
