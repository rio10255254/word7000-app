import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.108.2';

type LiveActivityDevice = {
  activity_started_for_expires_at: string | null;
  app_locale: 'en' | 'zh-TW';
  device_id: string;
  push_to_start_token: string;
  streak: number;
  streak_expires_at: string;
  user_id: string;
};

const requiredEnvironment = [
  'SUPABASE_URL',
  'SUPABASE_SERVICE_ROLE_KEY',
  'APNS_TEAM_ID',
  'APNS_KEY_ID',
  'APNS_PRIVATE_KEY',
  'CRON_SECRET',
] as const;

Deno.serve(async (request) => {
  const cronSecret = Deno.env.get('CRON_SECRET');
  if (!cronSecret || request.headers.get('x-cron-secret') !== cronSecret) {
    return Response.json({ error: 'Unauthorized' }, { status: 401 });
  }

  const missing = requiredEnvironment.filter((name) => !Deno.env.get(name));
  if (missing.length > 0) {
    return Response.json({ error: `Missing secrets: ${missing.join(', ')}` }, { status: 500 });
  }

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    { auth: { persistSession: false } },
  );
  const { data, error } = await supabase.rpc('claim_due_streak_live_activities');
  if (error) {
    return Response.json({ error: error.message }, { status: 500 });
  }

  const devices = (data ?? []) as LiveActivityDevice[];
  if (devices.length === 0) {
    return Response.json({ claimed: 0, failed: 0, sent: 0 });
  }

  const authorization = `bearer ${await createApnsJwt()}`;
  const results = await Promise.all(
    devices.map(async (device) => {
      const response = await sendStartRequest(device, authorization);
      if (response.ok) {
        return true;
      }

      const errorText = (await response.text()).slice(0, 500);
      await supabase
        .from('live_activity_devices')
        .update({
          activity_started_for_expires_at: null,
          last_push_error: `${response.status} ${errorText}`.trim(),
          updated_at: new Date().toISOString(),
        })
        .eq('user_id', device.user_id)
        .eq('device_id', device.device_id)
        .eq('activity_started_for_expires_at', device.streak_expires_at);
      return false;
    }),
  );
  const sent = results.filter(Boolean).length;
  return Response.json({ claimed: devices.length, failed: devices.length - sent, sent });
});

async function sendStartRequest(device: LiveActivityDevice, authorization: string): Promise<Response> {
  const expiresAt = new Date(device.streak_expires_at).getTime();
  const startedAt = expiresAt - 60 * 60 * 1000;
  const chinese = device.app_locale === 'zh-TW';
  const props = {
    countdownLabel: chinese ? '剩餘時間' : 'Time left',
    expiresAt,
    keepStreakLabel: chinese ? '完成 1 個單字即可保住連勝' : 'Study 1 word to keep it',
    startedAt,
    streak: device.streak,
    streakLabel: chinese ? `連勝 ${device.streak} 天` : `${device.streak}-day streak`,
    title: chinese ? '你的連勝快中斷了' : 'Your streak needs you',
  };
  const payload = {
    aps: {
      alert: {
        body: props.keepStreakLabel,
        title: props.title,
      },
      attributes: {},
      'attributes-type': 'LiveActivityAttributes',
      'content-state': {
        name: 'StreakLiveActivity',
        props: JSON.stringify(props),
      },
      event: 'start',
      'input-push-token': 1,
      'stale-date': Math.floor(expiresAt / 1000),
      timestamp: Math.floor(Date.now() / 1000),
    },
  };
  const production = Deno.env.get('APNS_ENVIRONMENT') !== 'sandbox';
  const host = production ? 'https://api.push.apple.com' : 'https://api.sandbox.push.apple.com';
  const bundleId = Deno.env.get('APNS_BUNDLE_ID') || 'com.rio.word7000';

  return fetch(`${host}/3/device/${device.push_to_start_token}`, {
    body: JSON.stringify(payload),
    headers: {
      authorization,
      'apns-priority': '10',
      'apns-push-type': 'liveactivity',
      'apns-topic': `${bundleId}.push-type.liveactivity`,
      'content-type': 'application/json',
    },
    method: 'POST',
  });
}

async function createApnsJwt(): Promise<string> {
  const teamId = Deno.env.get('APNS_TEAM_ID')!;
  const keyId = Deno.env.get('APNS_KEY_ID')!;
  const privateKey = Deno.env.get('APNS_PRIVATE_KEY')!.replace(/\\n/g, '\n');
  const header = base64Url(JSON.stringify({ alg: 'ES256', kid: keyId }));
  const claims = base64Url(JSON.stringify({ iss: teamId, iat: Math.floor(Date.now() / 1000) }));
  const signingInput = `${header}.${claims}`;
  const key = await crypto.subtle.importKey(
    'pkcs8',
    pemToBytes(privateKey),
    { name: 'ECDSA', namedCurve: 'P-256' },
    false,
    ['sign'],
  );
  const signature = await crypto.subtle.sign(
    { name: 'ECDSA', hash: 'SHA-256' },
    key,
    new TextEncoder().encode(signingInput),
  );
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
