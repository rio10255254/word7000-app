import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.108.2';

type LiveActivityDevice = {
  activity_started_for_expires_at: string | null;
  app_locale: 'en' | 'zh-TW';
  daily_target: number;
  device_id: string;
  noon_activity_expires_at: string | null;
  noon_activity_started_for_local_date: string | null;
  progress_date: string | null;
  push_to_start_token: string;
  streak: number;
  streak_expires_at: string | null;
  studied_today: number;
  user_id: string;
};

type ReminderKind = 'noon' | 'streak';

// APNs takes many requests on one connection, but a run with thousands of
// reminders should not open thousands of requests at once.
const APNS_CONCURRENCY = 20;
const APNS_TOKEN = /^[0-9a-fA-F]{32,512}$/;

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
  const [streakClaim, noonClaim] = await Promise.all([
    supabase.rpc('claim_due_streak_live_activities'),
    supabase.rpc('claim_due_noon_live_activities'),
  ]);
  if (streakClaim.error || noonClaim.error) {
    console.error(streakClaim.error ?? noonClaim.error);
    return Response.json({ error: 'Unable to claim reminders' }, { status: 500 });
  }

  const reminders = [
    ...((streakClaim.data ?? []) as LiveActivityDevice[]).map((device) => ({ device, kind: 'streak' as const })),
    ...((noonClaim.data ?? []) as LiveActivityDevice[]).map((device) => ({ device, kind: 'noon' as const })),
  ];
  if (reminders.length === 0) {
    return Response.json({ claimed: 0, failed: 0, sent: 0, noon: 0, streak: 0 });
  }

  const authorization = `bearer ${await createApnsJwt()}`;
  const results = await inBatches(reminders, APNS_CONCURRENCY, async ({ device, kind }) => {
    const response = await sendStartRequest(device, authorization, kind);
    if (response.ok) {
      return { kind, sent: true };
    }

    const errorText = (await response.text()).slice(0, 500);
    // APNs says the token will never work again: stop sending to it rather
    // than retrying every run.
    const dead = response.status === 410 || (response.status === 400 && /BadDeviceToken|DeviceTokenNotForTopic/.test(errorText));
    const reset = kind === 'streak'
      ? {
          activity_started_for_expires_at: null,
          last_push_error: `${response.status} ${errorText}`.trim(),
          updated_at: new Date().toISOString(),
          ...(dead ? { enabled: false } : {}),
        }
      : {
          last_push_error: `${response.status} ${errorText}`.trim(),
          noon_activity_expires_at: null,
          noon_activity_started_for_local_date: null,
          updated_at: new Date().toISOString(),
          ...(dead ? { enabled: false } : {}),
        };
    let resetQuery = supabase
      .from('live_activity_devices')
      .update(reset)
      .eq('user_id', device.user_id)
      .eq('device_id', device.device_id);
    resetQuery = kind === 'streak'
      ? resetQuery.eq('activity_started_for_expires_at', device.streak_expires_at!)
      : resetQuery.eq('noon_activity_started_for_local_date', device.noon_activity_started_for_local_date!);
    await resetQuery;
    return { kind, sent: false };
  });
  const sent = results.filter((result) => result.sent).length;
  return Response.json({
    claimed: reminders.length,
    failed: reminders.length - sent,
    noon: results.filter((result) => result.kind === 'noon' && result.sent).length,
    sent,
    streak: results.filter((result) => result.kind === 'streak' && result.sent).length,
  });
});

async function sendStartRequest(
  device: LiveActivityDevice,
  authorization: string,
  kind: ReminderKind,
): Promise<Response> {
  const expiration = kind === 'streak' ? device.streak_expires_at : device.noon_activity_expires_at;
  if (!expiration) {
    return new Response(`Missing ${kind} reminder expiration`, { status: 500 });
  }

  const expiresAt = new Date(expiration).getTime();
  const startedAt = kind === 'streak' ? expiresAt - 60 * 60 * 1000 : Date.now();
  const chinese = device.app_locale === 'zh-TW';
  const studiedToday = device.progress_date === device.noon_activity_started_for_local_date
    ? Math.max(0, device.studied_today)
    : 0;
  const remaining = Math.max(0, Math.max(1, device.daily_target) - studiedToday);
  const props = kind === 'streak'
    ? {
        activityKind: 'streak',
        countdownLabel: chinese ? '剩餘時間' : 'Time left',
        expiresAt,
        keepStreakLabel: chinese ? '完成 1 個單字即可保住連勝' : 'Study 1 word to keep it',
        progressCurrent: 0,
        progressTarget: 1,
        startedAt,
        streak: device.streak,
        streakLabel: chinese ? `連勝 ${device.streak} 天` : `${device.streak}-day streak`,
        title: chinese ? '你的連勝快中斷了' : 'Your streak needs you',
      }
    : {
        activityKind: 'noon',
        countdownLabel: chinese ? '今日進度' : 'Today',
        expiresAt,
        keepStreakLabel: remaining > 0
          ? chinese
            ? `再學 ${remaining} 個單字，完成今天目標`
            : `Study ${remaining} more words to reach today's goal`
          : chinese
            ? '今日目標已完成，複習 1 個單字保持手感'
            : 'Goal complete. Review 1 word to stay sharp',
        progressCurrent: studiedToday,
        progressTarget: Math.max(1, device.daily_target),
        startedAt,
        streak: device.streak,
        streakLabel: device.streak > 0
          ? chinese
            ? `連勝 ${device.streak} 天`
            : `${device.streak}-day streak`
          : chinese
            ? '今天開始連勝'
            : 'Start your streak today',
        title: chinese ? '今天的學習時間' : "Time for today's practice",
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
  // The token goes into the URL path, so only an APNs-shaped one is used.
  if (!APNS_TOKEN.test(device.push_to_start_token)) {
    return new Response('BadDeviceToken', { status: 400 });
  }

  return fetch(`${host}/3/device/${device.push_to_start_token}`, {
    body: JSON.stringify(payload),
    headers: {
      authorization,
      'apns-priority': '10',
      'apns-push-type': 'liveactivity',
      'apns-topic': `${bundleId}.push-type.liveactivity`,
      'apns-expiration': String(Math.floor(expiresAt / 1000)),
      'content-type': 'application/json',
    },
    method: 'POST',
  });
}

async function inBatches<T, R>(items: T[], size: number, work: (item: T) => Promise<R>): Promise<R[]> {
  const results: R[] = [];
  for (let start = 0; start < items.length; start += size) {
    results.push(...await Promise.all(items.slice(start, start + size).map(work)));
  }
  return results;
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
