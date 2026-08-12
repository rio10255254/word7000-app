import type { StreakLiveActivityProps } from './streakReminder';

export type StreakLiveActivitySyncResult = {
  active: boolean;
  activityPushToken: string | null;
  startedForExpiresAt: string | null;
};

export type StreakPushTokenSubscription = {
  remove: () => void;
};

export async function syncStreakLiveActivity(
  _props: StreakLiveActivityProps | null,
  _activeNow: boolean,
): Promise<StreakLiveActivitySyncResult> {
  return {
    active: false,
    activityPushToken: null,
    startedForExpiresAt: null,
  };
}

export function subscribeToStreakPushToStartToken(
  _listener: (token: string) => void,
): StreakPushTokenSubscription | null {
  return null;
}
