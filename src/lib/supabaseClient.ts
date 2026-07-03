import { createClient, processLock, type SupabaseClient } from '@supabase/supabase-js';
import { Platform } from 'react-native';
import { nativeAuthStorage, registerNativeAuthRefresh } from './nativeSupabaseRuntime';
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
      ...(nativeAuthStorage ? { storage: nativeAuthStorage } : {}),
      autoRefreshToken: true,
      detectSessionInUrl: Platform.OS === 'web',
      lock: processLock,
      persistSession: true,
    },
  });

  registerNativeAuthRefresh(client);
  return client;
}
