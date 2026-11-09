import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.108.2';
import { readAllPages, sameSecret } from './helpers.ts';

// Sends one announcement (see the announcements table) as a push
// notification to every iPhone that allowed them, or to its audience. The
// announcement must ask for a push and not have been pushed yet; it is
// marked pushed before anything is sent, so a second call sends nothing.
// Called by the "Broadcast a message" workflow (scripts/remote-control.sh),
// which sends the project's service key in the x-broadcast-secret header;
// announcements are public, so without that check anyone could push one that
// asked for a push but had not been pushed yet.

type Device = { token: string; language: 'zh' | 'en'; app_version: string | null; app_build: number | null };

/** Whether a phone's app is older than the message's limit (no limit: all;
 * a phone that never said its version is from before versions were kept). */
export function isBelow(device: Pick<Device, 'app_version' | 'app_build'>, version: string | null, build: number | null) {
  if (!version) return true;
  if (!device.app_version) return true;
  const a = device.app_version.split('.').map(Number), b = version.split('.').map(Number);
  for (let i = 0; i < Math.max(a.length, b.length); i++) {
    const x = a[i] ?? 0, y = b[i] ?? 0;
    if (x !== y) return x < y;
  }
  return build != null && device.app_build != null && device.app_build < build;
}

const APNS_CONCURRENCY = 20;
const APNS_TOKEN = /^[0-9a-f]{32,512}$/;
const requiredEnvironment = ['SUPABASE_URL', 'SUPABASE_SERVICE_ROLE_KEY', 'APNS_TEAM_ID', 'APNS_KEY_ID', 'APNS_PRIVATE_KEY'] as const;

Deno.serve(async (request) => {
  if (request.method !== 'POST') return Response.json({ error: 'method_not_allowed' }, { status: 405 });
  // The caller proves itself with the project's service key (the
  // announcement workflow reads it with its Supabase access token), or with
  // BROADCAST_PUSH_SECRET where one is set: nothing to set up by hand.
  const given = request.headers.get('x-broadcast-secret');
  const accepted = [Deno.env.get('SUPABASE_SERVICE_ROLE_KEY'), Deno.env.get('BROADCAST_PUSH_SECRET')]
    .filter((value): value is string => !!value);
  let allowed = false;
  for (const expected of accepted) allowed = (await sameSecret(given, expected)) || allowed;
  if (!allowed) return Response.json({ error: 'unauthorized' }, { status: 401 });
  const missing = requiredEnvironment.filter((name) => !Deno.env.get(name));
  if (missing.length > 0) return Response.json({ error: `Missing secrets: ${missing.join(', ')}` }, { status: 500 });

  const body = await request.json().catch(() => ({})) as { id?: unknown };
  const id = typeof body.id === 'string' ? body.id : '';
  if (!/^[0-9a-f-]{36}$/i.test(id)) return Response.json({ error: 'invalid_input' }, { status: 400 });

  const supabase = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!, {
    auth: { persistSession: false },
  });
  const { data: message, error } = await supabase.from('announcements')
    .update({ pushed_at: new Date().toISOString() })
    .eq('id', id).eq('push', true).eq('active', true).is('pushed_at', null)
    .select('id, audience, title_zh, body_zh, title_en, body_en, below_version, below_build')
    .maybeSingle();
  if (error) {
    console.error(error);
    return Response.json({ error: 'unavailable' }, { status: 500 });
  }
  if (!message) return Response.json({ error: 'nothing_to_push' }, { status: 409 });

  const { rows: devices, error: devicesError } = await readAllPages<Device>((from, to) => {
    let query = supabase.from('push_devices').select('token, language, app_version, app_build');
    if (message.audience === 'tester') query = query.eq('tester', true);
    else if (message.audience !== 'all') query = query.eq('audience', message.audience);
    return query.order('token').range(from, to);
  }, (device) => device.token);
  if (devicesError) {
    console.error(devicesError);
    // Nothing was sent: leave it to be pushed again.
    await supabase.from('announcements').update({ pushed_at: null }).eq('id', message.id);
    return Response.json({ error: 'unavailable' }, { status: 500 });
  }

  const authorization = `bearer ${await createApnsJwt()}`;
  const gone: string[] = [];
  let sent = 0;
  let failed = 0;
  const list = devices.filter((device) => isBelow(device, message.below_version, message.below_build));
  for (let start = 0; start < list.length; start += APNS_CONCURRENCY) {
    await Promise.all(list.slice(start, start + APNS_CONCURRENCY).map(async (device) => {
      const english = device.language === 'en';
      const title = (english && message.title_en) ? message.title_en : message.title_zh;
      const text = (english && message.body_en) ? message.body_en : message.body_zh;
      const response = await sendAlert(device.token, title, text, message.id, authorization).catch(() => null);
      if (response?.ok) {
        sent += 1;
        return;
      }
      failed += 1;
      const reason = response ? await response.json().then((value) => value?.reason).catch(() => '') : '';
      if (response?.status === 410 || reason === 'BadDeviceToken' || reason === 'Unregistered') gone.push(device.token);
    }));
  }
  if (gone.length > 0) await supabase.from('push_devices').delete().in('token', gone);
  console.log(JSON.stringify({ announcement: message.id, devices: list.length, sent, failed, removed: gone.length }));
  return Response.json({ devices: list.length, sent, failed, removed: gone.length });
});

function sendAlert(token: string, title: string, body: string, id: string, authorization: string): Promise<Response> {
  // The token goes into the URL path, so only an APNs-shaped one is used.
  if (!APNS_TOKEN.test(token)) return Promise.resolve(new Response('{"reason":"BadDeviceToken"}', { status: 400 }));
  const production = Deno.env.get('APNS_ENVIRONMENT') !== 'sandbox';
  const host = production ? 'https://api.push.apple.com' : 'https://api.sandbox.push.apple.com';
  const bundleId = Deno.env.get('APNS_BUNDLE_ID') || 'com.rio.word7000';
  return fetch(`${host}/3/device/${token}`, {
    method: 'POST',
    body: JSON.stringify({ aps: { alert: { title, body }, sound: 'default' }, announcement: id }),
    headers: {
      authorization,
      'apns-priority': '10',
      'apns-push-type': 'alert',
      'apns-topic': bundleId,
      'content-type': 'application/json',
    },
  });
}

async function createApnsJwt(): Promise<string> {
  const teamId = Deno.env.get('APNS_TEAM_ID')!;
  const keyId = Deno.env.get('APNS_KEY_ID')!;
  const privateKey = Deno.env.get('APNS_PRIVATE_KEY')!.replace(/\\n/g, '\n');
  const header = base64Url(JSON.stringify({ alg: 'ES256', kid: keyId }));
  const claims = base64Url(JSON.stringify({ iss: teamId, iat: Math.floor(Date.now() / 1000) }));
  const signingInput = `${header}.${claims}`;
  const key = await crypto.subtle.importKey('pkcs8', pemToBytes(privateKey), { name: 'ECDSA', namedCurve: 'P-256' }, false, ['sign']);
  const signature = await crypto.subtle.sign({ name: 'ECDSA', hash: 'SHA-256' }, key, new TextEncoder().encode(signingInput));
  return `${signingInput}.${base64Url(new Uint8Array(signature))}`;
}

function pemToBytes(pem: string): Uint8Array {
  const base64 = pem.replace(/-----BEGIN PRIVATE KEY-----|-----END PRIVATE KEY-----|\s/g, '');
  return Uint8Array.from(atob(base64), (character) => character.charCodeAt(0));
}

function base64Url(value: string | Uint8Array): string {
  const bytes = typeof value === 'string' ? new TextEncoder().encode(value) : value;
  let binary = '';
  bytes.forEach((byte) => {
    binary += String.fromCharCode(byte);
  });
  return btoa(binary).replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_');
}
