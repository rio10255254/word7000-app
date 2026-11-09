import { X509Certificate } from '@peculiar/x509';

// Proof that a learner subscribes to Plus: the StoreKit 2 transaction the app
// already holds, signed by Apple. It is checked here, offline, the way Apple's
// own server library does it, so a modified app cannot claim Plus.

/** Apple Root CA - G3, from https://www.apple.com/certificateauthority/ (SHA-256 63:34:3A:BF:...:91:79). */
export const APPLE_ROOT_CA_G3 = 'MIICQzCCAcmgAwIBAgIILcX8iNLFS5UwCgYIKoZIzj0EAwMwZzEbMBkGA1UEAwwSQXBwbGUgUm9vdCBDQSAtIEczMSYwJAYDVQQLDB1BcHBsZSBDZXJ0aWZpY2F0aW9uIEF1dGhvcml0eTETMBEGA1UECgwKQXBwbGUgSW5jLjELMAkGA1UEBhMCVVMwHhcNMTQwNDMwMTgxOTA2WhcNMzkwNDMwMTgxOTA2WjBnMRswGQYDVQQDDBJBcHBsZSBSb290IENBIC0gRzMxJjAkBgNVBAsMHUFwcGxlIENlcnRpZmljYXRpb24gQXV0aG9yaXR5MRMwEQYDVQQKDApBcHBsZSBJbmMuMQswCQYDVQQGEwJVUzB2MBAGByqGSM49AgEGBSuBBAAiA2IABJjpLz1AcqTtkyJygRMc3RCV8cWjTnHcFBbZDuWmBSp3ZHtfTjjTuxxEtX/1H7YyYl3J6YRbTzBPEVoA/VhYDKX1DyxNB0cTddqXl5dvMVztK517IDvYuVTZXpmkOlEKMaNCMEAwHQYDVR0OBBYEFLuw3qFYM4iapIqZ3r6966/ayySrMA8GA1UdEwEB/wQFMAMBAf8wDgYDVR0PAQH/BAQDAgEGMAoGCCqGSM49BAMDA2gAMGUCMQCD6cHEFl4aXTQY2e3v9GwOAEZLuN+yRhHFD/3meoyhpmvOwgPUnPWTxnS4at+qIxUCMG1mihDK1A3UT82NQz60imOlM27jbdoXt2QfyFMm+YhidDkLF1vLUagM6BgD56KyKA==';

const LEAF_MARKER_OID = '1.2.840.113635.100.6.11.1';
const INTERMEDIATE_MARKER_OID = '1.2.840.113635.100.6.2.1';

export interface Entitlement {
  productId: string;
  expiresAt: number;
  environment: string;
  /** The same for every renewal of one subscription; claims are bound to it. */
  originalTransactionId: string;
  /** This renewal (or purchase); a refund names it. */
  transactionId: string;
  /** When this renewal was bought, or null when Apple did not say. */
  purchasedAt: number | null;
}

export interface EntitlementRules {
  bundleId: string;
  productIds: string[];
  now?: number;
  /** Base64 DER roots; Apple's root unless a test supplies its own. */
  roots?: string[];
}

function base64ToBytes(text: string): Uint8Array<ArrayBuffer> {
  const normal = text.replace(/-/g, '+').replace(/_/g, '/');
  const padded = normal + '='.repeat((4 - (normal.length % 4)) % 4);
  const binary = atob(padded);
  return Uint8Array.from(binary, (char) => char.charCodeAt(0));
}

function sameBytes(a: Uint8Array, b: Uint8Array): boolean {
  return a.length === b.length && a.every((value, index) => value === b[index]);
}

function validAt(cert: X509Certificate, time: number): boolean {
  return cert.notBefore.getTime() <= time && time <= cert.notAfter.getTime();
}

/**
 * The payload of a JWS that Apple signed (a StoreKit transaction or an App
 * Store server notification), or null when the chain, the signature or the
 * signing date does not hold up.
 */
export async function verifyAppleSigned(
  jws: unknown, options: { roots?: string[]; now?: number; maxLength?: number } = {},
): Promise<Record<string, unknown> | null> {
  try {
    if (typeof jws !== 'string' || jws.length > (options.maxLength ?? 20_000)) return null;
    const parts = jws.split('.');
    if (parts.length !== 3) return null;
    const header = JSON.parse(new TextDecoder().decode(base64ToBytes(parts[0])));
    if (header.alg !== 'ES256' || !Array.isArray(header.x5c) || header.x5c.length !== 3) return null;
    const ders = header.x5c.map((value: string) => base64ToBytes(value));
    const roots = (options.roots ?? [APPLE_ROOT_CA_G3]).map(base64ToBytes);
    if (!roots.some((root) => sameBytes(root, ders[2]))) return null;
    const [leaf, intermediate, root] = ders.map((der: Uint8Array<ArrayBuffer>) => new X509Certificate(der));
    const now = options.now ?? Date.now();

    if (!leaf.getExtension(LEAF_MARKER_OID) || !intermediate.getExtension(INTERMEDIATE_MARKER_OID)) return null;
    if (!validAt(intermediate, now) || !validAt(root, now)) return null;
    if (!(await intermediate.verify({ publicKey: root.publicKey, signatureOnly: true }))) return null;
    if (!(await leaf.verify({ publicKey: intermediate.publicKey, signatureOnly: true }))) return null;

    const key = await leaf.publicKey.export({ name: 'ECDSA', namedCurve: 'P-256' }, ['verify']);
    const signed = new TextEncoder().encode(`${parts[0]}.${parts[1]}`);
    const signatureOK = await crypto.subtle.verify({ name: 'ECDSA', hash: 'SHA-256' }, key, base64ToBytes(parts[2]), signed);
    if (!signatureOK) return null;

    const payload = JSON.parse(new TextDecoder().decode(base64ToBytes(parts[1])));
    // Apple's certificates rotate; a payload is judged by the leaf that was valid when it was signed.
    if (typeof payload.signedDate !== 'number' || !validAt(leaf, payload.signedDate)) return null;
    return payload;
  } catch {
    return null;
  }
}

/**
 * A Plus subscription transaction Apple signed and has not revoked, whether or
 * not its period has ended: in Apple's billing grace period the app still
 * holds the last one, past its expiry. The server decides on grace itself.
 */
export async function verifySubscriptionTransaction(jws: unknown, rules: EntitlementRules): Promise<Entitlement | null> {
  const payload = await verifyAppleSigned(jws, { roots: rules.roots, now: rules.now });
  if (!payload) return null;
  if (payload.bundleId !== rules.bundleId || !rules.productIds.includes(String(payload.productId))) return null;
  if (payload.revocationDate || typeof payload.expiresDate !== 'number') return null;
  const original = String(payload.originalTransactionId ?? payload.transactionId ?? '');
  const transaction = String(payload.transactionId ?? original);
  if (!/^[0-9]{1,32}$/.test(original) || !/^[0-9]{1,32}$/.test(transaction)) return null;
  return {
    productId: String(payload.productId),
    expiresAt: payload.expiresDate,
    environment: String(payload.environment ?? ''),
    originalTransactionId: original,
    transactionId: transaction,
    purchasedAt: typeof payload.purchaseDate === 'number' ? payload.purchaseDate : null,
  };
}

/** The active Plus subscription in a signed transaction, or null for anything else (an ended period included). */
export async function verifyEntitlement(jws: unknown, rules: EntitlementRules): Promise<Entitlement | null> {
  const entitlement = await verifySubscriptionTransaction(jws, rules);
  if (!entitlement || entitlement.expiresAt <= (rules.now ?? Date.now())) return null;
  return entitlement;
}

/** What an App Store server notification says about a Plus subscription. */
export interface SubscriptionNotice {
  type: string;
  /** Null for notices about no transaction, such as Apple's TEST notice. */
  originalTransactionId: string | null;
  /** True once Apple refunded or revoked it; false when a refund was reversed. */
  revoked: boolean | null;
  /** The transaction the notice is about: for a refund, the refunded one. */
  transactionId: string | null;
  /** When that transaction's period ends (or ended), or null. */
  expiresAt: number | null;
  /**
   * The subscription's renewal info, when the notice carries it: the end of
   * its billing grace period (null: not in one) and when Apple signed it.
   */
  renewal: { graceUntil: number | null; signedAt: number } | null;
}

/**
 * Reads an App Store Server Notification (version 2). Refunds, revocations
 * and reversed refunds set `revoked`; other notices verify with
 * `revoked: null`. Any notice may carry the renewal info (grace period).
 */
export async function verifyNotification(signedPayload: unknown, rules: EntitlementRules): Promise<SubscriptionNotice | null> {
  // A notice carries the transaction and the renewal info, each a signed
  // token with its own certificate chain, encoded once more: about 19 KB.
  const notice = await verifyAppleSigned(signedPayload, { roots: rules.roots, now: rules.now, maxLength: 60_000 });
  if (!notice || typeof notice.notificationType !== 'string') return null;
  const data = (notice.data ?? {}) as Record<string, unknown>;
  if (data.bundleId !== rules.bundleId) return null;
  if (data.signedTransactionInfo === undefined) {
    return { type: notice.notificationType, originalTransactionId: null, revoked: null, transactionId: null, expiresAt: null, renewal: null };
  }
  const transaction = await verifyAppleSigned(data.signedTransactionInfo, { roots: rules.roots, now: rules.now });
  if (!transaction || transaction.bundleId !== rules.bundleId || !rules.productIds.includes(String(transaction.productId))) return null;
  const original = String(transaction.originalTransactionId ?? '');
  if (!/^[0-9]{1,32}$/.test(original)) return null;
  const transactionId = /^[0-9]{1,32}$/.test(String(transaction.transactionId ?? '')) ? String(transaction.transactionId) : null;
  const type = notice.notificationType;
  const revoked = type === 'REFUND' || type === 'REVOKE' ? true : type === 'REFUND_REVERSED' ? false : null;
  // The renewal info is signed on its own; one about another subscription,
  // or one that does not verify, is ignored rather than failing the notice.
  let renewal: SubscriptionNotice['renewal'] = null;
  if (data.signedRenewalInfo !== undefined) {
    const info = await verifyAppleSigned(data.signedRenewalInfo, { roots: rules.roots, now: rules.now });
    if (info && String(info.originalTransactionId ?? '') === original && typeof info.signedDate === 'number') {
      renewal = { graceUntil: typeof info.gracePeriodExpiresDate === 'number' ? info.gracePeriodExpiresDate : null, signedAt: info.signedDate };
    }
  }
  return {
    type, originalTransactionId: original, revoked, transactionId,
    expiresAt: typeof transaction.expiresDate === 'number' ? transaction.expiresDate : null, renewal,
  };
}
