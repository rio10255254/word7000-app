import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.108.2';
import { appleKeyFrom, exchangeAppleCode, revokeAppleToken } from '../_shared/appleSignIn.ts';

const corsHeaders = {
  'Access-Control-Allow-Headers': 'authorization, apikey, content-type, x-client-info',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Origin': '*',
};

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }
  if (request.method !== 'POST') {
    return response({ error: 'Method not allowed' }, 405);
  }

  const authorization = request.headers.get('Authorization');
  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const publishableKey = Deno.env.get('SUPABASE_ANON_KEY');
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!authorization?.startsWith('Bearer ') || !supabaseUrl || !publishableKey || !serviceRoleKey) {
    return response({ error: 'Unauthorized' }, 401);
  }

  const userClient = createClient(supabaseUrl, publishableKey, {
    auth: { persistSession: false },
    global: { headers: { Authorization: authorization } },
  });
  const { data, error: userError } = await userClient.auth.getUser();
  if (userError || !data.user) {
    return response({ error: 'A valid account is required' }, 401);
  }

  const adminClient = createClient(supabaseUrl, serviceRoleKey, { auth: { persistSession: false } });
  // Sign in with Apple: revoke the app's access to the Apple ID too, so it
  // leaves Settings > Sign in with Apple. The app sends a fresh authorization
  // code (it asks Apple to confirm before deleting); the token kept at sign-in
  // is the fallback. A failure is logged but never keeps the account from
  // being deleted.
  let appleRevoked = false;
  const appleKey = appleKeyFrom((name) => Deno.env.get(name));
  if (appleKey) {
    const code = await request.json().then((body) => body?.code).catch(() => undefined);
    const tokens: string[] = [];
    if (typeof code === 'string' && /^[A-Za-z0-9._-]{10,512}$/.test(code)) {
      const fresh = await exchangeAppleCode(code, appleKey).catch(() => null);
      if (fresh) tokens.push(fresh);
      else console.error(JSON.stringify({ apple: 'code_exchange_failed', user: data.user.id }));
    }
    const { data: stored } = await adminClient.rpc('apple_token_for', { p_user: data.user.id });
    if (typeof stored === 'string' && stored) tokens.push(stored);
    for (const token of tokens) {
      if (await revokeAppleToken(token, appleKey).catch(() => false)) appleRevoked = true;
    }
    if (!appleRevoked && data.user.identities?.some((identity) => identity.provider === 'apple')) {
      console.error(JSON.stringify({ apple: 'revoke_failed', user: data.user.id, tokens: tokens.length }));
    }
  }
  const { error: deleteError } = await adminClient.auth.admin.deleteUser(data.user.id);
  if (deleteError) {
    // The details stay in the function logs, not in the app.
    console.error(deleteError);
    return response({ error: 'Unable to delete the account' }, 500);
  }

  return response({ deleted: true, apple_revoked: appleRevoked });
});

function response(body: Record<string, unknown>, status = 200): Response {
  return Response.json(body, { headers: corsHeaders, status });
}
