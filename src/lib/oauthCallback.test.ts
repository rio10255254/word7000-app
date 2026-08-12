import { describe, expect, test } from 'vitest';
import { parseOAuthCallbackUrl } from './oauthCallback';

describe('OAuth callback parsing', () => {
  test('extracts Supabase implicit-flow tokens from a native callback hash', () => {
    expect(
      parseOAuthCallbackUrl('word7000://auth/callback#access_token=access123&refresh_token=refresh456&expires_in=3600'),
    ).toEqual({
      accessToken: 'access123',
      code: null,
      error: null,
      errorCode: null,
      identityId: null,
      refreshToken: 'refresh456',
    });
  });

  test('extracts a PKCE code from a native callback query string', () => {
    expect(parseOAuthCallbackUrl('word7000://auth/callback?code=pkce-code-123')).toEqual({
      accessToken: null,
      code: 'pkce-code-123',
      error: null,
      errorCode: null,
      identityId: null,
      refreshToken: null,
    });
  });

  test('returns empty values when the callback has no session information', () => {
    expect(parseOAuthCallbackUrl('word7000://auth/callback?error=access_denied&error_code=identity_already_exists')).toEqual({
      accessToken: null,
      code: null,
      error: 'access_denied',
      errorCode: 'identity_already_exists',
      identityId: null,
      refreshToken: null,
    });
  });

  test('extracts the linked identity returned by a native account upgrade', () => {
    expect(parseOAuthCallbackUrl('word7000://auth/callback?identity_id=identity-123')).toEqual({
      accessToken: null,
      code: null,
      error: null,
      errorCode: null,
      identityId: 'identity-123',
      refreshToken: null,
    });
  });
});
