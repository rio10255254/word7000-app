import { describe, expect, test } from 'vitest';
import { normalizeSupabaseUrl } from './supabaseClient';

describe('Supabase client settings', () => {
  test('keeps the project URL as the Supabase root', () => {
    expect(normalizeSupabaseUrl('https://project.supabase.co')).toBe('https://project.supabase.co');
    expect(normalizeSupabaseUrl('https://project.supabase.co/')).toBe('https://project.supabase.co');
  });

  test('accepts a copied Data API URL by removing the REST path', () => {
    expect(normalizeSupabaseUrl('https://project.supabase.co/rest/v1')).toBe('https://project.supabase.co');
    expect(normalizeSupabaseUrl(' https://project.supabase.co/rest/v1/ ')).toBe('https://project.supabase.co');
  });
});
