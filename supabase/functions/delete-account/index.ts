import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.108.2';
import { appleKeyFrom, revokeAppleToken } from '../_shared/appleSignIn.ts';

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
  // Sign in with Apple: revoke the app's access to the Apple ID too. A failure
  // is logged but never keeps the account from being deleted.
  const appleKey = appleKeyFrom((name) => Deno.env.get(name));
  if (appleKey) {
    const { data: token } = await adminClient.rpc('apple_token_for', { p_user: data.user.id });
    if (typeof token === 'string' && token) {
      const revoked = await revokeAppleToken(token, appleKey).catch(() => false);
      if (!revoked) console.error(JSON.stringify({ apple: 'revoke_failed', user: data.user.id }));
    }
  }
  const { error: deleteError } = await adminClient.auth.admin.deleteUser(data.user.id);
  if (deleteError) {
    // The details stay in the function logs, not in the app.
    console.error(deleteError);
    return response({ error: 'Unable to delete the account' }, 500);
  }

  return response({ deleted: true });
});

function response(body: Record<string, unknown>, status = 200): Response {
  return Response.json(body, { headers: corsHeaders, status });
}
