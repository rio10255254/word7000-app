// Read-only health check for Sign in with Apple account deletion.
// 1. Signs a client secret with the Sign in with Apple key from the secrets and
//    asks Apple to trade a made-up code: "invalid_grant" means Apple accepted
//    the key (only the code was wrong); "invalid_client" means the key, key id,
//    team id or bundle id is wrong, so no sign-in can ever be revoked.
// 2. With SUPABASE_ACCESS_TOKEN, lists the last days of apple-token and
//    delete-account calls and their logs.
import { createPrivateKey, sign } from 'node:crypto';
import { appendFileSync } from 'node:fs';

const { APPLE_TEAM_ID, APPLE_SIWA_KEY_ID, APPLE_SIWA_PRIVATE_KEY, SUPABASE_ACCESS_TOKEN, PROJECT_REF, GITHUB_STEP_SUMMARY } = process.env;
const CLIENT_ID = 'com.rio.word7000';
const say = (line = '') => { console.log(line); if (GITHUB_STEP_SUMMARY) appendFileSync(GITHUB_STEP_SUMMARY, line + '\n'); };
const b64 = (value) => Buffer.from(typeof value === 'string' ? value : value).toString('base64url');

say('## 🍎 Apple 登入金鑰');
if (!APPLE_TEAM_ID || !APPLE_SIWA_KEY_ID || !APPLE_SIWA_PRIVATE_KEY) {
  say('- ❌ GitHub Secrets 少了 APPLE_TEAM_ID、APPLE_SIWA_KEY_ID 或 APPLE_SIWA_PRIVATE_KEY');
} else {
  say(`- Team ID 長度 ${APPLE_TEAM_ID.trim().length}（應為 10）；Key ID 長度 ${APPLE_SIWA_KEY_ID.trim().length}（應為 10）`);
  try {
    const iat = Math.floor(Date.now() / 1000);
    const head = b64(JSON.stringify({ alg: 'ES256', kid: APPLE_SIWA_KEY_ID }));
    const claims = b64(JSON.stringify({ iss: APPLE_TEAM_ID, iat, exp: iat + 300, aud: 'https://appleid.apple.com', sub: CLIENT_ID }));
    const key = createPrivateKey(APPLE_SIWA_PRIVATE_KEY.replace(/\\n/g, '\n'));
    const signature = sign('sha256', Buffer.from(`${head}.${claims}`), { key, dsaEncoding: 'ieee-p1363' });
    const secret = `${head}.${claims}.${b64(signature)}`;
    const response = await fetch('https://appleid.apple.com/auth/token', {
      method: 'POST',
      headers: { 'content-type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({ client_id: CLIENT_ID, client_secret: secret, code: 'c0ffee.0.check.health', grant_type: 'authorization_code' }),
    });
    const text = await response.text();
    const error = (() => { try { return JSON.parse(text).error; } catch { return text.slice(0, 120); } })();
    if (error === 'invalid_grant') say('- ✅ Apple 接受這把金鑰（測試用的假代碼被拒是正常的）');
    else if (error === 'invalid_client') say('- ❌ Apple 不接受這把金鑰：Key ID／Team ID 不對，或這把 Key 沒勾 Sign in with Apple、主要 App ID 不是 com.rio.word7000');
    else say(`- ⚠️ Apple 回應 ${response.status}：${error}`);
  } catch (e) {
    say(`- ❌ 金鑰讀不出來（.p8 內容格式不對）：${e.message}`);
  }
}

if (SUPABASE_ACCESS_TOKEN && PROJECT_REF) {
  const end = new Date();
  const start = new Date(end.getTime() - 24 * 3600 * 1000);
  const query = async (sql) => {
    const url = new URL(`https://api.supabase.com/v1/projects/${PROJECT_REF}/analytics/endpoints/logs`);
    url.searchParams.set('sql', sql);
    url.searchParams.set('iso_timestamp_start', start.toISOString());
    url.searchParams.set('iso_timestamp_end', end.toISOString());
    const response = await fetch(url, { headers: { Authorization: `Bearer ${SUPABASE_ACCESS_TOKEN}` } });
    const body = await response.json().catch(() => ({}));
    if (!response.ok || body.error) return { error: JSON.stringify(body.error ?? body).slice(0, 200) };
    return { rows: body.result ?? [] };
  };
  say('');
  say('## 📜 最近 24 小時的 Apple 登入／刪除帳號呼叫');
  const calls = await query(`select timestamp, request.pathname as path, response.status_code as status
    from edge_logs cross join unnest(metadata) as m cross join unnest(m.request) as request cross join unnest(m.response) as response
    where request.pathname like '%apple-token%' or request.pathname like '%delete-account%'
    order by timestamp desc limit 20`);
  if (calls.error) say(`- 讀不到：${calls.error}`);
  else if (!calls.rows.length) say('- 沒有');
  else for (const row of calls.rows) say(`- ${new Date(Number(row.timestamp) / 1000).toISOString().slice(0, 19)} ${row.path} → ${row.status}`);
  const logs = await query(`select timestamp, event_message from function_logs
    where event_message like '%apple%' or event_message like '%revoke%'
    order by timestamp desc limit 20`);
  if (!logs.error && logs.rows.length) {
    say('');
    say('**函式紀錄**');
    for (const row of logs.rows) say(`- ${new Date(Number(row.timestamp) / 1000).toISOString().slice(0, 19)} ${String(row.event_message).slice(0, 200)}`);
  }
}
