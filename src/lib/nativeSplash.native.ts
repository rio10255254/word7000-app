import * as SplashScreen from 'expo-splash-screen';

let prepared = false;

export function prepareNativeSplash(): void {
  if (prepared) {
    return;
  }
  prepared = true;
  SplashScreen.setOptions({ duration: 360, fade: true });
  void SplashScreen.preventAutoHideAsync().catch(() => undefined);
}

export function hideNativeSplash(): void {
  void SplashScreen.hideAsync().catch(() => undefined);
}
