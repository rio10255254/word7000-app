import { describe, expect, test } from 'vitest';
import { getSupabaseSettings, normalizeSupabaseUrl } from './supabaseClient';

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

  test('accepts a copied Data API URL by removing the REST path', () => {
    expect(normalizeSupabaseUrl('https://project.supabase.co/rest/v1')).toBe('https://project.supabase.co');
    expect(normalizeSupabaseUrl(' https://project.supabase.co/rest/v1/ ')).toBe('https://project.supabase.co');
  });
});
