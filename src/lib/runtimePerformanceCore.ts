export type RuntimePerformanceProfile = {
  conserveResources: boolean;
  iosMajorVersion: number | null;
  isLegacyIos: boolean;
  lowPowerMode: boolean;
  reduceMotion: boolean;
  reduceTransparency: boolean;
  supportsLiquidGlass: boolean;
};

export function parseIosMajorVersion(version: string | number): number | null {
  const match = String(version).match(/^\d+/);
  if (!match) {
    return null;
  }
  const major = Number(match[0]);
  return Number.isSafeInteger(major) && major > 0 ? major : null;
}

export function buildRuntimePerformanceProfile({
  iosMajorVersion,
  lowPowerMode,
  reduceMotion,
  reduceTransparency,
}: {
  iosMajorVersion: number | null;
  lowPowerMode: boolean;
  reduceMotion: boolean;
  reduceTransparency: boolean;
}): RuntimePerformanceProfile {
  const isIos = iosMajorVersion !== null;
  return {
    conserveResources: lowPowerMode || reduceMotion,
    iosMajorVersion,
    isLegacyIos: isIos && iosMajorVersion < 19,
    lowPowerMode,
    reduceMotion,
    reduceTransparency,
    supportsLiquidGlass: isIos && iosMajorVersion >= 26 && !lowPowerMode && !reduceTransparency,
  };
}
