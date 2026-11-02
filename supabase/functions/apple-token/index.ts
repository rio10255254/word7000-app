import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.108.2';
import { appleKeyFrom, exchangeAppleCode } from '../_shared/appleSignIn.ts';

// Called by the app right after Sign in with Apple with the one-time
// authorization code. The refresh token Apple returns is kept, unreadable by
// the app, so account deletion can revoke it (see delete-account).

const corsHeaders = {
  'Access-Control-Allow-Headers': 'authorization, apikey, content-type, x-client-info',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Origin': '*',
};

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (request.method !== 'POST') return reply({ error: 'method_not_allowed' }, 405);

  const authorization = request.headers.get('Authorization');
  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const publishableKey = Deno.env.get('SUPABASE_ANON_KEY');
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!authorization?.startsWith('Bearer ') || !supabaseUrl || !publishableKey || !serviceKey) {
    return reply({ error: 'unauthorized' }, 401);
  }
  const key = appleKeyFrom((name) => Deno.env.get(name));
  if (!key) return reply({ stored: false });

  const raw = await request.text();
  if (raw.length > 4096) return reply({ error: 'invalid_input' }, 400);
  let code: unknown;
  try { code = JSON.parse(raw).code; } catch { return reply({ error: 'invalid_input' }, 400); }
  if (typeof code !== 'string' || !/^[A-Za-z0-9._-]{10,512}$/.test(code)) return reply({ error: 'invalid_input' }, 400);

  const userClient = createClient(supabaseUrl, publishableKey, {
    auth: { persistSession: false },
    global: { headers: { Authorization: authorization } },
  });
  const { data, error } = await userClient.auth.getUser();
  if (error || !data.user) return reply({ error: 'unauthorized' }, 401);
  if (!data.user.identities?.some((identity) => identity.provider === 'apple')) return reply({ stored: false });

  const refreshToken = await exchangeAppleCode(code, key);
  if (!refreshToken) return reply({ stored: false });
  const service = createClient(supabaseUrl, serviceKey, { auth: { persistSession: false } });
  const { error: saveError } = await service.rpc('save_apple_token_for', { p_user: data.user.id, p_refresh_token: refreshToken });
  if (saveError) {
    console.error(saveError);
    return reply({ error: 'unavailable' }, 503);
  }
  return reply({ stored: true });
});

function reply(body: Record<string, unknown>, status = 200): Response {
  return Response.json(body, { headers: corsHeaders, status });
}
