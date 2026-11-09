import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.108.2';
import { verifySubscriptionTransaction } from './entitlement.ts';
import { AIFailure, complete } from './claude.ts';
import { COACH_MODEL, COACH_MODEL_DAILY, coachUsesStrongModel, dailyLimit, InputError, isTaskName, planTask, tierFor } from './tasks.ts';

// The Anthropic key lives only here, as the ANTHROPIC_API_KEY function secret.
// The app sends task data with the learner's session. Guest sessions are
// refused: anyone can make guests by the thousand, so online AI needs an
// account signed in with Apple, Google or email.

const corsHeaders = {
  'Access-Control-Allow-Headers': 'authorization, apikey, content-type, x-client-info',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Origin': '*',
};

// Room for a StoreKit transaction (a few kilobytes) alongside the task data.
const MAX_BODY_BYTES = 32_768;
const BUNDLE_ID = 'com.rio.word7000';
const PLUS_PRODUCTS = ['com.rio.word7000.plus.monthly', 'com.rio.word7000.plus.yearly'];
// Learners agreed to send text to a named provider. Builds that asked about an
// earlier provider do not send this, so their text is never sent to Anthropic;
// they get `unavailable` and use the on-device model until they update.
const PROVIDER = 'anthropic';

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (request.method !== 'POST') return reply({ error: 'method_not_allowed' }, 405);

  const apiKey = Deno.env.get('ANTHROPIC_API_KEY');
  if (!apiKey || Deno.env.get('AI_DISABLED') === 'true') return reply({ error: 'unavailable' }, 503);

  const authorization = request.headers.get('Authorization');
  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const publishableKey = Deno.env.get('SUPABASE_ANON_KEY');
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!authorization?.startsWith('Bearer ') || !supabaseUrl || !publishableKey || !serviceKey) {
    return reply({ error: 'unauthorized' }, 401);
  }
  // Refuse an oversized body before reading it.
  const declared = Number(request.headers.get('content-length') ?? '0');
  if (Number.isFinite(declared) && declared > MAX_BODY_BYTES) return reply({ error: 'invalid_input' }, 400);
  const userClient = createClient(supabaseUrl, publishableKey, {
    auth: { persistSession: false },
    global: { headers: { Authorization: authorization } },
  });
  const { data: userData, error: userError } = await userClient.auth.getUser();
  if (userError || !userData.user) return reply({ error: 'unauthorized' }, 401);
  if (userData.user.is_anonymous) return reply({ error: 'sign_in_required' }, 403);
  const user = userData.user.id;
  // Quota and Plus claims are written only with the service role; the app
  // itself cannot call those functions.
  const service = createClient(supabaseUrl, serviceKey, { auth: { persistSession: false } });

  const raw = await request.text();
  if (new TextEncoder().encode(raw).length > MAX_BODY_BYTES) return reply({ error: 'invalid_input' }, 400);
  let body: { task?: unknown; input?: unknown; entitlement?: unknown; consent?: unknown };
  try { body = JSON.parse(raw); } catch { return reply({ error: 'invalid_input' }, 400); }
  if (body.consent !== PROVIDER) return reply({ error: 'unavailable' }, 503);
  if (!isTaskName(body.task)) return reply({ error: 'invalid_input' }, 400);

  const task = body.task;
  try { planTask(task, body.input); }
  catch (error) {
    if (error instanceof InputError) return reply({ error: 'invalid_input', detail: error.message }, 400);
    throw error;
  }

  // Plus only from a transaction Apple signed, not refunded, current (or in
  // Apple's billing grace period), and used by at most three accounts a month.
  // The expiry and grace period are decided by the database.
  const entitlement = await verifySubscriptionTransaction(body.entitlement, { bundleId: BUNDLE_ID, productIds: PLUS_PRODUCTS });
  let subscribed = false;
  if (entitlement) {
    const { data: claimed, error: claimError } = await service.rpc('claim_plus_subscription', {
      p_user: user, p_original_transaction_id: entitlement.originalTransactionId,
      p_transaction_id: entitlement.transactionId, p_expires_at: new Date(entitlement.expiresAt).toISOString(),
      p_purchased_at: entitlement.purchasedAt == null ? null : new Date(entitlement.purchasedAt).toISOString(),
    });
    if (claimError) return reply({ error: 'unavailable' }, 503);
    subscribed = claimed === true;
    if (!subscribed) console.log(JSON.stringify({ plus: 'refused', transaction: entitlement.originalTransactionId }));
  }
  // The online AI is a Plus feature: without a subscription Apple signed
  // (its free trial included), nothing is counted and nothing is asked.
  if (!subscribed) return reply({ error: 'plus_required' }, 403);
  // Counted before the call so a burst cannot outrun the limit, and given
  // back when no answer comes (a bounded number a day; see refund_ai_quota_for).
  const usageDate = new Date().toISOString().slice(0, 10);
  const { data: quota, error: quotaError } = await service.rpc('consume_ai_quota_for', { p_user: user });
  if (quotaError || !quota) return reply({ error: 'unavailable' }, 503);
  const giveBack = async () => {
    const { error } = await service.rpc('refund_ai_quota_for', { p_user: user, p_usage_date: usageDate });
    if (error) console.error(error);
  };
  const tier = tierFor(subscribed, quota.first_seen);
  const limit = dailyLimit(tier, {
    free: envLimit('AI_FREE_LIMIT', 5),
    plus: envLimit('AI_PLUS_LIMIT', 60),
  });
  const used = Number(quota.requests);
  if (!(used <= limit)) return reply({ error: 'quota', tier, limit, remaining: 0 }, 429);
  // A ceiling on the whole service's day, whatever happens to the per-learner
  // limits; only requests within a learner's allowance count towards it.
  // A failed request still counts here: it may have cost tokens.
  const { data: total, error: totalError } = await service.rpc('count_ai_request_today');
  if (totalError || total == null) {
    await giveBack();
    return reply({ error: 'unavailable' }, 503);
  }
  if (Number(total) > envLimit('AI_GLOBAL_DAILY_LIMIT', 20_000)) {
    console.error(JSON.stringify({ budget: 'exhausted', total }));
    await giveBack();
    return reply({ error: 'unavailable' }, 503);
  }
  const plan = planTask(task, body.input, tier);

  // The speaking coach for learners of Chinese gets the stronger model for the
  // day's first answers: the quick one misses Chinese word-order mistakes.
  // Learners of English stay on the quick model, which catches theirs.
  let model: string | undefined;
  if (task === 'coach' && coachUsesStrongModel(body.input)) {
    const { data: coachUsed, error: coachError } = await service.rpc('consume_coach_answer_for', { p_user: user });
    if (!coachError && Number(coachUsed) <= envLimit('AI_COACH_MODEL_DAILY', COACH_MODEL_DAILY)) model = COACH_MODEL;
  }

  try {
    // If the stronger model is busy, the quick one answers instead.
    // Both together stay under the app's 30-second wait.
    const result = await complete(plan, { apiKey, model, totalTimeoutMs: model ? 16_000 : undefined }).catch((error) => {
      if (model && error instanceof AIFailure && error.kind !== 'misconfigured') return complete(plan, { apiKey, totalTimeoutMs: 12_000 });
      throw error;
    });
    // One line per answer, so the function logs show what each task really costs.
    console.log(JSON.stringify({ task, tier, model: result.model, effort: result.effort, ...result.usage }));
    return reply({ result: result.content, model: result.model, effort: result.effort, tier, limit, remaining: Math.max(0, limit - used) });
  } catch (error) {
    // No answer: the learner gets the request back.
    await giveBack();
    if (error instanceof AIFailure) {
      if (error.kind === 'misconfigured') console.error(error.message);
      return reply({ error: error.kind === 'busy' ? 'busy' : 'unavailable', retryAfter: error.retryAfter ?? null },
        error.kind === 'busy' ? 429 : 503);
    }
    console.error(error);
    return reply({ error: 'unavailable' }, 503);
  }
});

/** A whole-number limit from a function secret; a missing or malformed one falls back rather than lifting the limit. */
function envLimit(name: string, fallback: number): number {
  const text = Deno.env.get(name)?.trim();
  const value = text ? Number(text) : NaN;
  return Number.isInteger(value) && value >= 0 ? value : fallback;
}

function reply(body: Record<string, unknown>, status = 200): Response {
  return Response.json(body, { headers: corsHeaders, status });
}
