import { describe, expect, test } from 'vitest';
import { iosUpdateDecision, parseIosUpdatePolicy } from './nativeUpdatePolicy';

const policy = {
  latestBuild: 21,
  minimumBuild: 21,
  testFlightUrl: 'https://apps.apple.com/app/testflight/id899247664',
};

describe('native iOS update policy', () => {
  test('requires an older TestFlight build to update', () => {
    expect(iosUpdateDecision('20', policy)).toEqual({
      available: true,
      required: true,
      testFlightUrl: policy.testFlightUrl,
    });
  });

  test('keeps the latest build available', () => {
    expect(iosUpdateDecision('21', policy)).toEqual({
      available: false,
      required: false,
      testFlightUrl: policy.testFlightUrl,
    });
  });

  test('supports a visible but optional newer build', () => {
    expect(iosUpdateDecision(21, { ...policy, latestBuild: 22 })).toMatchObject({
      available: true,
      required: false,
    });
  });

  test('rejects malformed or unsafe policies', () => {
    expect(parseIosUpdatePolicy({ ...policy, minimumBuild: 22 })).toBeNull();
    expect(parseIosUpdatePolicy({ ...policy, testFlightUrl: 'http://example.com/update' })).toBeNull();
    expect(parseIosUpdatePolicy(policy)).toEqual(policy);
  });
});
