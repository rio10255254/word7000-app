import { describe, expect, test } from 'vitest';
import { parseOAuthCallbackUrl } from './oauthCallback';

describe('OAuth callback parsing', () => {
  test('extracts Supabase implicit-flow tokens from a native callback hash', () => {
    expect(
      parseOAuthCallbackUrl('word7000://auth/callback#access_token=access123&refresh_token=refresh456&expires_in=3600'),
    ).toEqual({
      accessToken: 'access123',
      code: null,
      refreshToken: 'refresh456',
    });
  });

  test('extracts a PKCE code from a native callback query string', () => {
    expect(parseOAuthCallbackUrl('word7000://auth/callback?code=pkce-code-123')).toEqual({
      accessToken: null,
      code: 'pkce-code-123',
      refreshToken: null,
    });
  });

  test('returns empty values when the callback has no session information', () => {
    expect(parseOAuthCallbackUrl('word7000://auth/callback?error=access_denied')).toEqual({
      accessToken: null,
      code: null,
      refreshToken: null,
    });
  });
});
