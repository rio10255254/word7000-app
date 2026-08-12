import StreakLiveActivity from '../liveActivity/StreakLiveActivity';
import { addPushToStartTokenListener } from 'expo-widgets';
import type { StreakLiveActivityProps } from './streakReminder';
import type {
  StreakLiveActivitySyncResult,
  StreakPushTokenSubscription,
} from './streakLiveActivityController';

export async function syncStreakLiveActivity(
  props: StreakLiveActivityProps | null,
  activeNow: boolean,
): Promise<StreakLiveActivitySyncResult> {
  try {
    const instances = StreakLiveActivity.getInstances();
    if (!props || !activeNow || Date.now() >= props.expiresAt) {
      await Promise.all(instances.map((instance) => instance.end('immediate')));
      return {
        active: false,
        activityPushToken: null,
        startedForExpiresAt: null,
      };
    }

    const instance = instances[0] ?? StreakLiveActivity.start(props, 'word7000://study');
    if (instances[0]) {
      await instances[0].update(props);
    }
    if (instances.length > 1) {
      await Promise.all(instances.slice(1).map((duplicate) => duplicate.end('immediate')));
    }

    return {
      active: true,
      activityPushToken: await instance.getPushToken(),
      startedForExpiresAt: new Date(props.expiresAt).toISOString(),
    };
  } catch {
    return {
      active: false,
      activityPushToken: null,
      startedForExpiresAt: null,
    };
  }
}

export function subscribeToStreakPushToStartToken(
  listener: (token: string) => void,
): StreakPushTokenSubscription {
  return addPushToStartTokenListener(({ activityPushToStartToken }) => {
    if (activityPushToStartToken) {
      listener(activityPushToStartToken);
    }
  });
}
