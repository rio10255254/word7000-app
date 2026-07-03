import { describe, expect, test } from 'vitest';
import { appleCredentialMetadata, createAppleNoncePair, sha256Hex } from './appleAuth';

describe('Apple native sign-in helpers', () => {
  test('creates a raw nonce and a sha256 nonce for native Apple sign-in', async () => {
    const nonce = await createAppleNoncePair(32);

    expect(nonce.raw).toHaveLength(32);
    expect(nonce.sha256).toHaveLength(64);
    expect(nonce.sha256).toBe(await sha256Hex(nonce.raw));
    expect(nonce.sha256).not.toBe(nonce.raw);
  });

  test('hashes nonce text using SHA-256 hex', async () => {
    await expect(sha256Hex('abc')).resolves.toBe('ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad');
  });

  test('keeps Apple first-sign-in profile metadata compact', () => {
    expect(
      appleCredentialMetadata(
        {
          familyName: 'Chiang',
          givenName: 'Rio',
        },
        'rio@example.com',
        'apple-user-id',
      ),
    ).toEqual({
      apple_user: 'apple-user-id',
      email: 'rio@example.com',
      family_name: 'Chiang',
      full_name: 'Rio Chiang',
      given_name: 'Rio',
    });
  });
});
