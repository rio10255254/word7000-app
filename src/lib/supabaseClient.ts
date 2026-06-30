import { createClient, type SupabaseClient } from '@supabase/supabase-js';
import { isSupabaseConfigured } from './supabaseProgress';

export type AppSupabaseClient = SupabaseClient;

export function getSupabaseSettings() {
  return {
    url: normalizeSupabaseUrl(process.env.EXPO_PUBLIC_SUPABASE_URL ?? ''),
    anonKey: process.env.EXPO_PUBLIC_SUPABASE_ANON_KEY ?? '',
  };
}

export function normalizeSupabaseUrl(url: string): string {
  return url.trim().replace(/\/+$/, '').replace(/\/rest\/v1$/i, '');
}

export function createAppSupabaseClient(): AppSupabaseClient | null {
  const settings = getSupabaseSettings();

  if (!isSupabaseConfigured(settings.url, settings.anonKey)) {
    return null;
  }

  return createClient(settings.url, settings.anonKey);
}
