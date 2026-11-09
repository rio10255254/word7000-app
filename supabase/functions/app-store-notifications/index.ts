import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.108.2';
import { verifyNotification } from '../ai/entitlement.ts';

// App Store Server Notifications (version 2). Set this function's URL as the
// Production and Sandbox server URL in App Store Connect. Apple signs every
// notice, so no session is needed: anything that does not verify through
// Apple's root is refused. A refund or revocation ends Plus on the AI server
// for the refunded transaction (and earlier periods of that subscription, not
// later renewals); a reversed refund restores it. The renewal info that most
// notices carry says whether the subscription is in its billing grace period,
// during which Plus stays on.

const BUNDLE_ID = 'com.rio.word7000';
const PLUS_PRODUCTS = ['com.rio.word7000.plus.monthly', 'com.rio.word7000.plus.yearly'];
// A notice is two signed tokens with their certificate chains: a few kilobytes.
const MAX_BODY_BYTES = 65_536;

Deno.serve(async (request) => {
  if (request.method !== 'POST') return Response.json({ error: 'method_not_allowed' }, { status: 405 });
  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!supabaseUrl || !serviceKey) return Response.json({ error: 'unavailable' }, { status: 503 });

  const declared = Number(request.headers.get('content-length') ?? '0');
  if (Number.isFinite(declared) && declared > MAX_BODY_BYTES) return Response.json({ error: 'invalid' }, { status: 400 });
  const raw = await request.text();
  if (new TextEncoder().encode(raw).length > MAX_BODY_BYTES) return Response.json({ error: 'invalid' }, { status: 400 });
  let body: { signedPayload?: unknown };
  try { body = JSON.parse(raw); } catch { return Response.json({ error: 'invalid' }, { status: 400 }); }

  const notice = await verifyNotification(body.signedPayload, { bundleId: BUNDLE_ID, productIds: PLUS_PRODUCTS });
  if (!notice) return Response.json({ error: 'invalid' }, { status: 400 });
  console.log(JSON.stringify({
    notice: notice.type, transaction: notice.originalTransactionId, revoked: notice.revoked,
    grace: notice.renewal?.graceUntil ? new Date(notice.renewal.graceUntil).toISOString() : null,
  }));
  const original = notice.originalTransactionId;
  if (!original || (notice.revoked === null && !notice.renewal)) return Response.json({ received: true });

  const service = createClient(supabaseUrl, serviceKey, { auth: { persistSession: false } });
  const iso = (time: number | null) => time == null ? null : new Date(time).toISOString();
  const writes: PromiseLike<{ error: unknown }>[] = [];
  if (notice.renewal) {
    writes.push(service.rpc('record_plus_renewal', {
      p_original_transaction_id: original, p_grace_until: iso(notice.renewal.graceUntil), p_signed_at: iso(notice.renewal.signedAt),
    }));
  }
  if (notice.revoked !== null) {
    writes.push(notice.transactionId
      ? service.rpc('record_plus_refund', {
          p_original_transaction_id: original, p_transaction_id: notice.transactionId,
          p_expires_at: iso(notice.expiresAt), p_type: notice.type, p_revoked: notice.revoked,
        })
      // A notice without its transaction id: the whole subscription, as before.
      : service.rpc('record_plus_notice', { p_original_transaction_id: original, p_type: notice.type, p_revoked: notice.revoked }));
  }
  // Apple retries a notice that was not acknowledged, so a failed write is
  // reported rather than swallowed. Each write is safe to repeat.
  const failed = (await Promise.all(writes)).find((result) => result.error);
  if (failed) {
    console.error(failed.error);
    return Response.json({ error: 'unavailable' }, { status: 503 });
  }
  return Response.json({ received: true });
});
