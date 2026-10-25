import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.108.2';
import { verifyEntitlement } from './entitlement.ts';
import { complete, GroqFailure } from './groq.ts';
import { dailyLimit, InputError, isTaskName, planTask, tierFor } from './tasks.ts';

// The Groq key lives only here, as the GROQ_API_KEY function secret. The app
// signs in (a guest account is enough) and sends task data with that session.

const corsHeaders = {
  'Access-Control-Allow-Headers': 'authorization, apikey, content-type, x-client-info',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Origin': '*',
};

// Room for a StoreKit transaction (a few kilobytes) alongside the task data.
const MAX_BODY_BYTES = 32_768;
const BUNDLE_ID = 'com.rio.word7000';
const PLUS_PRODUCTS = ['com.rio.word7000.plus.monthly', 'com.rio.word7000.plus.yearly'];

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (request.method !== 'POST') return reply({ error: 'method_not_allowed' }, 405);

  const apiKey = Deno.env.get('GROQ_API_KEY');
  if (!apiKey || Deno.env.get('AI_DISABLED') === 'true') return reply({ error: 'unavailable' }, 503);

  const authorization = request.headers.get('Authorization');
  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const publishableKey = Deno.env.get('SUPABASE_ANON_KEY');
  if (!authorization?.startsWith('Bearer ') || !supabaseUrl || !publishableKey) {
    return reply({ error: 'unauthorized' }, 401);
  }
  const userClient = createClient(supabaseUrl, publishableKey, {
    auth: { persistSession: false },
    global: { headers: { Authorization: authorization } },
  });
  const { data: userData, error: userError } = await userClient.auth.getUser();
  if (userError || !userData.user) return reply({ error: 'unauthorized' }, 401);

  const raw = await request.text();
  if (new TextEncoder().encode(raw).length > MAX_BODY_BYTES) return reply({ error: 'invalid_input' }, 400);
  let body: { task?: unknown; input?: unknown; entitlement?: unknown };
  try { body = JSON.parse(raw); } catch { return reply({ error: 'invalid_input' }, 400); }
  if (!isTaskName(body.task)) return reply({ error: 'invalid_input' }, 400);

  const task = body.task;
  try { planTask(task, body.input); }
  catch (error) {
    if (error instanceof InputError) return reply({ error: 'invalid_input', detail: error.message }, 400);
    throw error;
  }

  // Plus only from a transaction Apple signed; the trial from the server's own
  // record of the learner's first AI request.
  const entitlement = await verifyEntitlement(body.entitlement, { bundleId: BUNDLE_ID, productIds: PLUS_PRODUCTS });
  // Counted before the call so a burst cannot outrun the limit.
  const { data: quota, error: quotaError } = await userClient.rpc('consume_ai_quota');
  if (quotaError || !quota) return reply({ error: 'unavailable' }, 503);
  const tier = tierFor(entitlement !== null, quota.first_seen);
  const limit = dailyLimit(tier, {
    free: Number(Deno.env.get('AI_FREE_LIMIT') ?? '20'),
    plus: Number(Deno.env.get('AI_PLUS_LIMIT') ?? '100'),
  });
  const used = Number(quota.requests);
  if (used > limit) return reply({ error: 'quota', tier, limit, remaining: 0 }, 429);
  const plan = planTask(task, body.input, tier);

  try {
    const result = await complete(plan, { apiKey });
    return reply({ result: result.content, model: result.model, tier, limit, remaining: Math.max(0, limit - used) });
  } catch (error) {
    if (error instanceof GroqFailure) {
      if (error.kind === 'misconfigured') console.error(error.message);
      return reply({ error: error.kind === 'busy' ? 'busy' : 'unavailable', retryAfter: error.retryAfter ?? null },
        error.kind === 'busy' ? 429 : 503);
    }
    console.error(error);
    return reply({ error: 'unavailable' }, 503);
  }
});

function reply(body: Record<string, unknown>, status = 200): Response {
  return Response.json(body, { headers: corsHeaders, status });
}
