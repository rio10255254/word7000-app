import AsyncStorage from '@react-native-async-storage/async-storage';
import type { SupabaseClient } from '@supabase/supabase-js';
import { AppState } from 'react-native';
import 'react-native-url-polyfill/auto';

export const nativeAuthStorage = AsyncStorage;

let nativeAuthRefreshRegistered = false;

export function registerNativeAuthRefresh(client: SupabaseClient): void {
  if (nativeAuthRefreshRegistered) {
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
