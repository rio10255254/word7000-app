import type { SupabaseClient } from '@supabase/supabase-js';

export const nativeAuthStorage = undefined;

export function registerNativeAuthRefresh(_client: SupabaseClient): void {
  // Web auth refresh is handled by Supabase's browser session flow.
}
