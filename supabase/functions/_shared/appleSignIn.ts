// Sign in with Apple tokens, so deleting an account also revokes the app's
// access to the learner's Apple ID, as App Store Review asks (5.1.1(v)).
// Needs a Sign in with Apple key: APPLE_TEAM_ID, APPLE_SIWA_KEY_ID and
// APPLE_SIWA_PRIVATE_KEY (the .p8 file). Without them nothing is stored or
// revoked and sign-in works as before.

const APPLE = 'https://appleid.apple.com';
export const APPLE_CLIENT_ID = 'com.rio.word7000';

export interface AppleKey {
  teamId: string;
  keyId: string;
  privateKey: string;
  clientId: string;
}

type Fetch = (input: string, init: RequestInit) => Promise<Response>;

export function appleKeyFrom(get: (name: string) => string | undefined): AppleKey | null {
  const teamId = get('APPLE_TEAM_ID') || get('APNS_TEAM_ID');
  const keyId = get('APPLE_SIWA_KEY_ID');
  const privateKey = get('APPLE_SIWA_PRIVATE_KEY');
  if (!teamId || !keyId || !privateKey) return null;
  return { teamId, keyId, privateKey: privateKey.replace(/\\n/g, '\n'), clientId: APPLE_CLIENT_ID };
}

/** The short-lived ES256 client secret Apple's token endpoints expect. */
export async function appleClientSecret(key: AppleKey, now = Date.now()): Promise<string> {
  const iat = Math.floor(now / 1000);
  const header = base64Url(JSON.stringify({ alg: 'ES256', kid: key.keyId }));
  const claims = base64Url(JSON.stringify({ iss: key.teamId, iat, exp: iat + 300, aud: APPLE, sub: key.clientId }));
  const signing = await crypto.subtle.importKey('pkcs8', pemToBytes(key.privateKey), { name: 'ECDSA', namedCurve: 'P-256' }, false, ['sign']);
  const signature = await crypto.subtle.sign({ name: 'ECDSA', hash: 'SHA-256' }, signing, new TextEncoder().encode(`${header}.${claims}`));
  return `${header}.${claims}.${base64Url(new Uint8Array(signature))}`;
}

/** Trades the authorization code from a sign-in for a refresh token, or null. */
export async function exchangeAppleCode(code: string, key: AppleKey, fetcher: Fetch = fetch): Promise<string | null> {
  const response = await fetcher(`${APPLE}/auth/token`, {
    method: 'POST',
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      client_id: key.clientId, client_secret: await appleClientSecret(key), code, grant_type: 'authorization_code',
    }).toString(),
  });
  if (!response.ok) return null;
  const body = await response.json().catch(() => ({})) as { refresh_token?: unknown };
  return typeof body.refresh_token === 'string' && body.refresh_token.length > 0 ? body.refresh_token : null;
}

export async function revokeAppleToken(refreshToken: string, key: AppleKey, fetcher: Fetch = fetch): Promise<boolean> {
  const response = await fetcher(`${APPLE}/auth/revoke`, {
    method: 'POST',
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      client_id: key.clientId, client_secret: await appleClientSecret(key), token: refreshToken, token_type_hint: 'refresh_token',
    }).toString(),
  });
  return response.ok;
}

function pemToBytes(pem: string): Uint8Array<ArrayBuffer> {
  const base64 = pem.replace(/-----BEGIN PRIVATE KEY-----|-----END PRIVATE KEY-----|\s/g, '');
  return Uint8Array.from(atob(base64), (character) => character.charCodeAt(0));
}

function base64Url(value: string | Uint8Array): string {
  const bytes = typeof value === 'string' ? new TextEncoder().encode(value) : value;
  let binary = '';
  bytes.forEach((byte) => { binary += String.fromCharCode(byte); });
  return btoa(binary).replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_');
}
