import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.108.2';
import { verifyNotification } from '../ai/entitlement.ts';

// App Store Server Notifications (version 2). Set this function's URL as the
// Production and Sandbox server URL in App Store Connect. Apple signs every
// notice, so no session is needed: anything that does not verify through
// Apple's root is refused. A refund or revocation ends Plus on the AI server
// for that subscription; a reversed refund restores it.

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
  console.log(JSON.stringify({ notice: notice.type, transaction: notice.originalTransactionId, revoked: notice.revoked }));
  if (notice.revoked === null || !notice.originalTransactionId) return Response.json({ received: true });

  const service = createClient(supabaseUrl, serviceKey, { auth: { persistSession: false } });
  const { error } = await service.rpc('record_plus_notice', {
    p_original_transaction_id: notice.originalTransactionId, p_type: notice.type, p_revoked: notice.revoked,
  });
  // Apple retries a notice that was not acknowledged, so a failed write is
  // reported rather than swallowed.
  if (error) {
    console.error(error);
    return Response.json({ error: 'unavailable' }, { status: 503 });
  }
  return Response.json({ received: true });
});
