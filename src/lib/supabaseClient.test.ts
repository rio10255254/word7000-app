import { describe, expect, test } from 'vitest';
import { getSupabaseSettings, normalizeSupabaseUrl } from './supabaseSettings';

describe('Supabase client settings', () => {
  test('reads public Supabase settings injected into the web runtime', () => {
    const globalConfig = globalThis as typeof globalThis & {
      __WORD7000_CONFIG__?: { supabaseAnonKey?: string; supabaseUrl?: string };
    };
    globalConfig.__WORD7000_CONFIG__ = {
      supabaseAnonKey: 'runtime-publishable-key',
      supabaseUrl: 'https://runtime-project.supabase.co/rest/v1',
    };

    expect(getSupabaseSettings()).toEqual({
      anonKey: 'runtime-publishable-key',
      url: 'https://runtime-project.supabase.co',
    });

    delete globalConfig.__WORD7000_CONFIG__;
  });

  test('keeps the project URL as the Supabase root', () => {
    expect(normalizeSupabaseUrl('https://project.supabase.co')).toBe('https://project.supabase.co');
    expect(normalizeSupabaseUrl('https://project.supabase.co/')).toBe('https://project.supabase.co');
  });

  test('falls back to the legacy anon key when the publishable key env value is blank', () => {
    const previousUrl = process.env.EXPO_PUBLIC_SUPABASE_URL;
    const previousPublishable = process.env.EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY;
    const previousAnon = process.env.EXPO_PUBLIC_SUPABASE_ANON_KEY;

    process.env.EXPO_PUBLIC_SUPABASE_URL = 'https://env-project.supabase.co';
    process.env.EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY = '   ';
    process.env.EXPO_PUBLIC_SUPABASE_ANON_KEY = 'legacy-anon-key';

    try {
      expect(getSupabaseSettings()).toEqual({
        anonKey: 'legacy-anon-key',
        url: 'https://env-project.supabase.co',
      });
    } finally {
      process.env.EXPO_PUBLIC_SUPABASE_URL = previousUrl;
      process.env.EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY = previousPublishable;
      process.env.EXPO_PUBLIC_SUPABASE_ANON_KEY = previousAnon;
    }
  });

  test('accepts a copied Data API URL by removing the REST path', () => {
    expect(normalizeSupabaseUrl('https://project.supabase.co/rest/v1')).toBe('https://project.supabase.co');
    expect(normalizeSupabaseUrl(' https://project.supabase.co/rest/v1/ ')).toBe('https://project.supabase.co');
  });
});
