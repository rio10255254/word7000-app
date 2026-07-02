type Word7000RuntimeConfig = {
  supabaseAnonKey?: string;
  supabaseUrl?: string;
};

declare global {
  var __WORD7000_CONFIG__: Word7000RuntimeConfig | undefined;
}

export function getSupabaseSettings() {
  const runtimeConfig = getWord7000RuntimeConfig();

  return {
    url: normalizeSupabaseUrl(runtimeConfig?.supabaseUrl ?? process.env.EXPO_PUBLIC_SUPABASE_URL ?? ''),
    anonKey:
      runtimeConfig?.supabaseAnonKey ??
      process.env.EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY ??
      process.env.EXPO_PUBLIC_SUPABASE_ANON_KEY ??
      '',
  };
}

export function normalizeSupabaseUrl(url: string): string {
  return url.trim().replace(/\/+$/, '').replace(/\/rest\/v1$/i, '');
}

function getWord7000RuntimeConfig(): Word7000RuntimeConfig | undefined {
  return globalThis.__WORD7000_CONFIG__;
}
