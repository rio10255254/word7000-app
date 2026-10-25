import { beforeAll, describe, expect, it } from 'vitest';
import * as x509 from '@peculiar/x509';
import { APPLE_ROOT_CA_G3, verifyEntitlement } from '../supabase/functions/ai/entitlement';

// A stand-in for Apple's chain: same shape (root → intermediate → leaf, P-256,
// Apple's marker extensions), signed with keys made here.
const algorithm = { name: 'ECDSA', namedCurve: 'P-256', hash: 'SHA-256' } as const;
const marker = (oid: string) => new x509.Extension(oid, false, new Uint8Array([5, 0]));
const day = 86_400_000;
const now = Date.UTC(2026, 9, 25);

type Chain = { leafKey: CryptoKeyPair; x5c: string[]; root: string };

async function makeChain(options: { leafMarker?: boolean; leafExpired?: boolean } = {}): Promise<Chain> {
  const rootKey = await crypto.subtle.generateKey(algorithm, true, ['sign', 'verify']);
  const intermediateKey = await crypto.subtle.generateKey(algorithm, true, ['sign', 'verify']);
  const leafKey = await crypto.subtle.generateKey(algorithm, true, ['sign', 'verify']);
  const root = await x509.X509CertificateGenerator.createSelfSigned({
    serialNumber: '01', name: 'CN=Test Root', keys: rootKey, signingAlgorithm: algorithm,
    notBefore: new Date(now - 365 * day), notAfter: new Date(now + 3650 * day),
  });
  const intermediate = await x509.X509CertificateGenerator.create({
    serialNumber: '02', subject: 'CN=Test Intermediate', issuer: root.subject,
    publicKey: intermediateKey.publicKey, signingKey: rootKey.privateKey, signingAlgorithm: algorithm,
    notBefore: new Date(now - 365 * day), notAfter: new Date(now + 3650 * day),
    extensions: [marker('1.2.840.113635.100.6.2.1')],
  });
  const leaf = await x509.X509CertificateGenerator.create({
    serialNumber: '03', subject: 'CN=Test Leaf', issuer: intermediate.subject,
    publicKey: leafKey.publicKey, signingKey: intermediateKey.privateKey, signingAlgorithm: algorithm,
    notBefore: new Date(now - 30 * day), notAfter: new Date(now + (options.leafExpired ? -2 * day : 300 * day)),
    extensions: options.leafMarker === false ? [] : [marker('1.2.840.113635.100.6.11.1')],
  });
  const der = (cert: x509.X509Certificate) => Buffer.from(cert.rawData).toString('base64');
  return { leafKey, x5c: [der(leaf), der(intermediate), der(root)], root: der(root) };
}

const b64url = (data: Uint8Array | string) =>
  Buffer.from(typeof data === 'string' ? new TextEncoder().encode(data) : data).toString('base64url');

async function sign(chain: Chain, payload: Record<string, unknown>, signingKey = chain.leafKey.privateKey): Promise<string> {
  const head = b64url(JSON.stringify({ alg: 'ES256', x5c: chain.x5c }));
  const body = b64url(JSON.stringify(payload));
  const signature = await crypto.subtle.sign({ name: 'ECDSA', hash: 'SHA-256' }, signingKey, new TextEncoder().encode(`${head}.${body}`));
  return `${head}.${body}.${b64url(new Uint8Array(signature))}`;
}

const subscription = {
  bundleId: 'com.rio.word7000',
  productId: 'com.rio.word7000.plus.monthly',
  signedDate: now - day,
  expiresDate: now + 20 * day,
  environment: 'Sandbox',
  type: 'Auto-Renewable Subscription',
};
const rules = (chain: Chain) => ({
  bundleId: 'com.rio.word7000',
  productIds: ['com.rio.word7000.plus.monthly', 'com.rio.word7000.plus.yearly'],
  now,
  roots: [chain.root],
});

describe('Plus entitlement', () => {
  let chain: Chain;
  beforeAll(async () => { chain = await makeChain(); });

  it('accepts an active subscription signed through the trusted root', async () => {
    await expect(verifyEntitlement(await sign(chain, subscription), rules(chain))).resolves.toEqual({
      productId: 'com.rio.word7000.plus.monthly', expiresAt: subscription.expiresDate, environment: 'Sandbox',
    });
  });

  it('pins Apple Root CA G3 by default', async () => {
    expect(Buffer.from(APPLE_ROOT_CA_G3, 'base64').length).toBe(583);
    const cert = new x509.X509Certificate(Buffer.from(APPLE_ROOT_CA_G3, 'base64'));
    expect(cert.subject).toContain('Apple Root CA - G3');
    // Our own test chain is not Apple's, so the default roots reject it.
    expect(await verifyEntitlement(await sign(chain, subscription), { ...rules(chain), roots: undefined })).toBeNull();
  });

  it('rejects a chain from another root, a tampered payload or a foreign signature', async () => {
    const other = await makeChain();
    expect(await verifyEntitlement(await sign(other, subscription), rules(chain))).toBeNull();
    const valid = await sign(chain, subscription);
    const [head, , signature] = valid.split('.');
    const forged = `${head}.${b64url(JSON.stringify({ ...subscription, expiresDate: now + 999 * day }))}.${signature}`;
    expect(await verifyEntitlement(forged, rules(chain))).toBeNull();
    expect(await verifyEntitlement(await sign(chain, subscription, other.leafKey.privateKey), rules(chain))).toBeNull();
  });

  it('rejects expired, revoked, other-app and other-product transactions', async () => {
    for (const change of [
      { expiresDate: now - 1 },
      { revocationDate: now - day },
      { bundleId: 'com.example.other' },
      { productId: 'com.rio.word7000.coins' },
      { signedDate: undefined },
    ]) {
      expect(await verifyEntitlement(await sign(chain, { ...subscription, ...change }), rules(chain))).toBeNull();
    }
  });

  it('rejects a leaf without Apple’s marker or one that had expired when it signed', async () => {
    const unmarked = await makeChain({ leafMarker: false });
    expect(await verifyEntitlement(await sign(unmarked, subscription), rules(unmarked))).toBeNull();
    const expired = await makeChain({ leafExpired: true });
    expect(await verifyEntitlement(await sign(expired, subscription), rules(expired))).toBeNull();
  });

  it('ignores anything that is not a three-part ES256 token', async () => {
    for (const value of [undefined, 42, '', 'a.b', 'x'.repeat(30_000), `${b64url('{"alg":"none"}')}.e30.`]) {
      expect(await verifyEntitlement(value, rules(chain))).toBeNull();
    }
  });
});
