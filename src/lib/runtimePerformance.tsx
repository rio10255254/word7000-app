import * as Battery from 'expo-battery';
import { createContext, useContext, useEffect, useMemo, useState, type ReactNode } from 'react';
import { AccessibilityInfo, Platform } from 'react-native';
import {
  buildRuntimePerformanceProfile,
  parseIosMajorVersion,
  type RuntimePerformanceProfile,
} from './runtimePerformanceCore';

export type { RuntimePerformanceProfile } from './runtimePerformanceCore';

const platformIosMajorVersion = Platform.OS === 'ios' ? parseIosMajorVersion(Platform.Version) : null;
const defaultProfile = buildRuntimePerformanceProfile({
  iosMajorVersion: platformIosMajorVersion,
  lowPowerMode: false,
  reduceMotion: false,
  reduceTransparency: false,
});
const RuntimePerformanceContext = createContext<RuntimePerformanceProfile>(defaultProfile);

export function RuntimePerformanceProvider({ children }: { children: ReactNode }) {
  const [lowPowerMode, setLowPowerMode] = useState(false);
  const [reduceMotion, setReduceMotion] = useState(false);
  const [reduceTransparency, setReduceTransparency] = useState(false);

  useEffect(() => {
    let mounted = true;
    void AccessibilityInfo.isReduceMotionEnabled()
      .then((enabled) => mounted && setReduceMotion(enabled))
      .catch(() => undefined);
    void AccessibilityInfo.isReduceTransparencyEnabled()
      .then((enabled) => mounted && setReduceTransparency(enabled))
      .catch(() => undefined);
    void Battery.isLowPowerModeEnabledAsync()
      .then((enabled) => mounted && setLowPowerMode(enabled))
      .catch(() => undefined);

    const motionSubscription = AccessibilityInfo.addEventListener('reduceMotionChanged', setReduceMotion);
    const transparencySubscription = AccessibilityInfo.addEventListener(
      'reduceTransparencyChanged',
      setReduceTransparency,
    );
    const powerSubscription = Battery.addLowPowerModeListener(({ lowPowerMode: enabled }) => {
      setLowPowerMode(enabled);
    });

    return () => {
      mounted = false;
      motionSubscription.remove();
      transparencySubscription.remove();
      powerSubscription.remove();
    };
  }, []);

  const profile = useMemo(
    () => buildRuntimePerformanceProfile({
      iosMajorVersion: platformIosMajorVersion,
      lowPowerMode,
      reduceMotion,
      reduceTransparency,
    }),
    [lowPowerMode, reduceMotion, reduceTransparency],
  );

  return <RuntimePerformanceContext.Provider value={profile}>{children}</RuntimePerformanceContext.Provider>;
}

export function useRuntimePerformance(): RuntimePerformanceProfile {
  return useContext(RuntimePerformanceContext);
}
