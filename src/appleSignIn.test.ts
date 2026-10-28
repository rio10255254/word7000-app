import { describe, expect, it } from 'vitest';
import {
  APPLE_CLIENT_ID, appleClientSecret, appleKeyFrom, exchangeAppleCode, revokeAppleToken,
} from '../supabase/functions/_shared/appleSignIn';

const algorithm = { name: 'ECDSA', namedCurve: 'P-256' } as const;

async function makeKey() {
  const pair = await crypto.subtle.generateKey(algorithm, true, ['sign', 'verify']);
  const pkcs8 = Buffer.from(await crypto.subtle.exportKey('pkcs8', pair.privateKey)).toString('base64');
  const pem = `-----BEGIN PRIVATE KEY-----\n${pkcs8.match(/.{1,64}/g)!.join('\n')}\n-----END PRIVATE KEY-----`;
  return { pair, key: { teamId: 'TEAM123456', keyId: 'KEY1234567', privateKey: pem, clientId: APPLE_CLIENT_ID } };
}

const decode = (part: string) => JSON.parse(Buffer.from(part, 'base64url').toString('utf8'));

describe('Sign in with Apple tokens', () => {
  it('needs a team, key id and private key, and reads escaped newlines', () => {
    expect(appleKeyFrom(() => undefined)).toBeNull();
    const env: Record<string, string> = { APNS_TEAM_ID: 'T', APPLE_SIWA_KEY_ID: 'K', APPLE_SIWA_PRIVATE_KEY: 'a\\nb' };
    expect(appleKeyFrom((name) => env[name])).toEqual({ teamId: 'T', keyId: 'K', privateKey: 'a\nb', clientId: 'com.rio.word7000' });
    expect(appleKeyFrom((name) => ({ ...env, APPLE_SIWA_KEY_ID: '' })[name])).toBeNull();
  });

  it('signs a five-minute client secret for appleid.apple.com', async () => {
    const { pair, key } = await makeKey();
    const now = Date.UTC(2026, 9, 28);
    const secret = await appleClientSecret(key, now);
    const [head, body, signature] = secret.split('.');
    expect(decode(head)).toEqual({ alg: 'ES256', kid: 'KEY1234567' });
    expect(decode(body)).toEqual({ iss: 'TEAM123456', iat: now / 1000, exp: now / 1000 + 300, aud: 'https://appleid.apple.com', sub: 'com.rio.word7000' });
    const valid = await crypto.subtle.verify({ name: 'ECDSA', hash: 'SHA-256' }, pair.publicKey,
      Buffer.from(signature, 'base64url'), new TextEncoder().encode(`${head}.${body}`));
    expect(valid).toBe(true);
  });

  it('exchanges a code for a refresh token and revokes it', async () => {
    const { key } = await makeKey();
    const calls: { url: string; body: URLSearchParams }[] = [];
    const fetcher = async (url: string, init: RequestInit) => {
      calls.push({ url, body: new URLSearchParams(String(init.body)) });
      return url.endsWith('/auth/token') ? Response.json({ refresh_token: 'r-token' }) : new Response('', { status: 200 });
    };
    await expect(exchangeAppleCode('c1.0.code', key, fetcher)).resolves.toBe('r-token');
    await expect(revokeAppleToken('r-token', key, fetcher)).resolves.toBe(true);
    expect(calls[0].url).toBe('https://appleid.apple.com/auth/token');
    expect(Object.fromEntries(calls[0].body)).toMatchObject({ client_id: 'com.rio.word7000', code: 'c1.0.code', grant_type: 'authorization_code' });
    expect(calls[1].url).toBe('https://appleid.apple.com/auth/revoke');
    expect(Object.fromEntries(calls[1].body)).toMatchObject({ token: 'r-token', token_type_hint: 'refresh_token' });
    expect(calls[1].body.get('client_secret')?.split('.')).toHaveLength(3);
  });

  it('treats a refused code as nothing to store', async () => {
    const { key } = await makeKey();
    const refused = async () => Response.json({ error: 'invalid_grant' }, { status: 400 });
    await expect(exchangeAppleCode('c1.0.code', key, refused)).resolves.toBeNull();
    await expect(revokeAppleToken('r', key, refused)).resolves.toBe(false);
  });
});
