import { describe, expect, test } from 'vitest';
import { authRedirectTo } from './authRedirect';

describe('auth redirect URL', () => {
  test('returns the current web origin root for OAuth redirects', () => {
    expect(authRedirectTo({ origin: 'https://word7000.pages.dev', pathname: '/' })).toBe('https://word7000.pages.dev/');
  });

  test('keeps a non-root app path when the app is hosted under one', () => {
    expect(authRedirectTo({ origin: 'http://localhost:8083', pathname: '/preview' })).toBe(
      'http://localhost:8083/preview',
    );
  });

  test('returns undefined outside a browser location', () => {
    expect(authRedirectTo(null)).toBeUndefined();
  });
});
