export type IosUpdatePolicy = {
  latestBuild: number;
  minimumBuild: number;
  testFlightUrl: string;
};

export type IosUpdateDecision = {
  available: boolean;
  required: boolean;
  testFlightUrl: string;
};

export function parseIosUpdatePolicy(value: unknown): IosUpdatePolicy | null {
  if (!value || typeof value !== 'object') {
    return null;
  }

  const candidate = value as Record<string, unknown>;
  const latestBuild = integerBuild(candidate.latestBuild);
  const minimumBuild = integerBuild(candidate.minimumBuild);
  const testFlightUrl = typeof candidate.testFlightUrl === 'string' ? candidate.testFlightUrl.trim() : '';

  if (
    latestBuild === null ||
    minimumBuild === null ||
    minimumBuild > latestBuild ||
    !isSafeUpdateUrl(testFlightUrl)
  ) {
    return null;
  }

  return { latestBuild, minimumBuild, testFlightUrl };
}

export function iosUpdateDecision(currentBuild: string | number | null | undefined, policy: IosUpdatePolicy): IosUpdateDecision {
  const parsedCurrentBuild = integerBuild(currentBuild);
  if (parsedCurrentBuild === null) {
    return { available: false, required: false, testFlightUrl: policy.testFlightUrl };
  }

  return {
    available: parsedCurrentBuild < policy.latestBuild,
    required: parsedCurrentBuild < policy.minimumBuild,
    testFlightUrl: policy.testFlightUrl,
  };
}

function integerBuild(value: unknown): number | null {
  const parsed = typeof value === 'number'
    ? value
    : typeof value === 'string' && /^\d+$/.test(value.trim())
      ? Number(value.trim())
      : Number.NaN;

  return Number.isSafeInteger(parsed) && parsed > 0 ? parsed : null;
}

function isSafeUpdateUrl(value: string): boolean {
  try {
    const url = new URL(value);
    return url.protocol === 'https:' && (
      url.hostname === 'apps.apple.com' ||
      url.hostname === 'testflight.apple.com'
    );
  } catch {
    return false;
  }
}
