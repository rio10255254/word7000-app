import AsyncStorage from '@react-native-async-storage/async-storage';
import { createClient, processLock, type SupabaseClient } from '@supabase/supabase-js';
import { AppState, Platform } from 'react-native';
import 'react-native-url-polyfill/auto';
import { isSupabaseConfigured } from './supabaseProgress';
import { getSupabaseSettings } from './supabaseSettings';

export type AppSupabaseClient = SupabaseClient;
export { getSupabaseSettings, normalizeSupabaseUrl } from './supabaseSettings';

export function createAppSupabaseClient(): AppSupabaseClient | null {
  const settings = getSupabaseSettings();

  if (!isSupabaseConfigured(settings.url, settings.anonKey)) {
    return null;
  }

  const client = createClient(settings.url, settings.anonKey, {
    auth: {
      ...(Platform.OS !== 'web' ? { storage: AsyncStorage } : {}),
      autoRefreshToken: true,
      detectSessionInUrl: Platform.OS === 'web',
      lock: processLock,
      persistSession: true,
    },
  });

  registerNativeAuthRefresh(client);
  return client;
}

let nativeAuthRefreshRegistered = false;

function registerNativeAuthRefresh(client: AppSupabaseClient): void {
  if (Platform.OS === 'web' || nativeAuthRefreshRegistered) {
    return;
  }

  nativeAuthRefreshRegistered = true;
  AppState.addEventListener('change', (state) => {
    if (state === 'active') {
      client.auth.startAutoRefresh();
      return;
    }

    client.auth.stopAutoRefresh();
  });
}
