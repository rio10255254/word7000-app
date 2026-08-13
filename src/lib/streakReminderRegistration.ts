import type { AppSupabaseClient } from './supabaseClient';
import type { StorageLike } from './progressStorage';

const STREAK_DEVICE_ID_STORAGE_KEY = 'word7000-streak-device-id-v1';

export type StreakReminderRegistration = {
  activityPushToken: string | null;
  dailyTarget: number;
  deviceId: string;
  enabled: boolean;
  expiresAt: string | null;
  locale: 'en' | 'zh-TW';
  progressDate: string;
  pushToStartToken: string;
  startedForExpiresAt: string | null;
  streak: number;
  studiedToday: number;
  timeZone: string;
};

export function getOrCreateStreakDeviceId(storage: StorageLike | undefined): string {
  const existing = storage?.getItem(STREAK_DEVICE_ID_STORAGE_KEY)?.trim();
  if (existing) {
    return existing;
  }

  const deviceId = `ios-${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 12)}`;
  storage?.setItem(STREAK_DEVICE_ID_STORAGE_KEY, deviceId);
  return deviceId;
}

export async function saveStreakReminderRegistration(
  client: AppSupabaseClient,
  userId: string,
  registration: StreakReminderRegistration,
): Promise<boolean> {
  const { error } = await client.from('live_activity_devices').upsert(
    {
      activity_push_token: registration.activityPushToken,
      activity_started_for_expires_at: registration.startedForExpiresAt,
      app_locale: registration.locale,
      daily_target: Math.max(1, Math.round(registration.dailyTarget)),
      device_id: registration.deviceId,
      enabled: registration.enabled,
      progress_date: registration.progressDate,
      push_to_start_token: registration.pushToStartToken,
      streak: registration.streak,
      streak_expires_at: registration.expiresAt,
      studied_today: Math.max(0, Math.round(registration.studiedToday)),
      time_zone: registration.timeZone,
      updated_at: new Date().toISOString(),
      user_id: userId,
    },
    { onConflict: 'user_id,device_id' },
  );

  return !error;
}

export async function disableStreakReminderRegistration(
  client: AppSupabaseClient,
  userId: string,
  deviceId: string,
): Promise<void> {
  await client
    .from('live_activity_devices')
    .update({ enabled: false, updated_at: new Date().toISOString() })
    .eq('user_id', userId)
    .eq('device_id', deviceId);
}

export async function deleteStreakReminderRegistrations(
  client: AppSupabaseClient,
  userId: string,
): Promise<void> {
  await client.from('live_activity_devices').delete().eq('user_id', userId);
}
