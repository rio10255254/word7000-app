// Turns usage_report() JSON (stdin) into the Chinese tables on the
// "📈 使用數據" run page. node scripts/usage-report.mjs < report.json
import { appendFileSync, readFileSync } from 'node:fs';

const report = JSON.parse(readFileSync(0, 'utf8'));
const out = [];
const say = (line = '') => out.push(line);
const pct = (back, cohort) => (cohort ? `${Math.round((back / cohort) * 100)}%（${back}/${cohort}）` : '還沒有資料');
const mode = { english: '學英文', chinese: '學中文' };
const labels = {
  app_open: '打開 App', study_session: '開始一輪學習', study_card: '學習卡片', quiz_answer: '測驗作答',
  spelling_answer: '拼字作答', speaking: '口說練習', coach_check: '口說批改', scan_saved: '掃描存入字庫',
  scan_words: '掃描加入的單字', ai: 'AI 使用成功', ai_failed: 'AI 失敗', paywall_view: '看到付費頁',
  purchase: '購買', restore: '恢復購買', sign_in: 'Apple 登入', account_deleted: '刪除帳號',
  placement: '完成程度測驗', mode_switch: '切換學習模式',
};
const aiKinds = {
  coach: '口說批改', scan: '掃描辨識', explain: '單字解說', quizWhy: '測驗為什麼錯', fillWord: '填空',
  insights: '學習分析', ask: '問小笨貓', chat: '小笨貓聊天', lines: '每日台詞', verdict: '結算評語',
};
const sources = {
  general: '一般入口', 'speaking-coach': '口說批改', scans: '掃描次數用完', ending: '試用快結束',
  'locked-smartAI': '鎖住的 AI 功能', 'locked-scan': '鎖住的掃描',
};
const detailText = (event, detail) => {
  if (!detail) return '';
  if (event === 'ai' || event === 'ai_failed') {
    const [kind, extra] = detail.split(':');
    const tier = { plus: 'Premium', trial: '試用', free: '免費', quota: '額度用完', busy: 'AI 忙碌',
      unavailable: '連不上', invalidInput: '輸入不合規', signInRequired: '沒登入', unknown: '' }[extra] ?? extra;
    return `${aiKinds[kind] ?? kind}${tier ? `（${event === 'ai' ? tier : `原因 ${tier}`}）` : ''}`;
  }
  if (event === 'paywall_view') return sources[detail] ?? detail;
  if (event === 'study_session') {
    const [scope, levels] = detail.split(':');
    const [m, bank] = scope.split('.');
    return `${mode[m] ?? m}・${bank === 'core' ? `內建字庫 ${levels === 'all' ? '全部級數' : levels}` : '自己的字庫'}`;
  }
  return detail.split(/[.:]/).map((part) => mode[part] ?? {
    completed: '完成', skipped: '略過', online: '線上 AI', device: '手機內建 AI', started: '按下購買',
    purchased: '成功', cancelled: '取消', failed: '失敗', pending: '等待中', yearly: '年訂', monthly: '月訂',
    trial: '含免費試用', restored: '恢復成功', noneFound: '沒有可恢復的', apple: 'Apple', guest: '訪客',
    apple_revoked: 'Apple 已撤銷', apple_listed: 'Apple 未撤銷',
  }[part] ?? part).join('・');
};

const u = report.users;
const a = report.active;
say(`# 📈 使用數據（最近 ${report.days} 天，從 ${report.since} 起，UTC）`);
say('');
say('## 👥 使用者');
say('');
say('| 全部帳號 | Apple 登入 | 訪客 | 期間新增 | 期間新增的 Apple 登入 | Premium 訂閱中 |');
say('|---|---|---|---|---|---|');
say(`| ${u.total} | ${u.apple} | ${u.guests} | ${u.new} | ${u.new_apple} | ${u.subscribers} |`);
say('');
say('## 🔥 活躍');
say('');
say('| 今天 | 昨天 | 7 天內 | 30 天內 |');
say('|---|---|---|---|');
say(`| ${a.today} | ${a.yesterday} | ${a.last_7_days} | ${a.last_30_days} |`);
say('');
say('| 日期 | 活躍人數 | 新帳號 |');
say('|---|---|---|');
for (const d of report.daily) say(`| ${d.day} | ${d.active} | ${d.new} |`);
say('');
const r = report.retention;
say('## 🔁 留存（最近 90 天加入的人）');
say('');
say('| 隔天回來 | 第 7 天那週回來 | 第 30 天那週回來 |');
say('|---|---|---|');
say(`| ${pct(r.d1.back, r.d1.cohort)} | ${pct(r.d7.back, r.d7.cohort)} | ${pct(r.d30.back, r.d30.cohort)} |`);
say('');

const events = report.events;
const section = (title, names, note) => {
  const rows = events.filter((e) => names.includes(e.event));
  say(`## ${title}`);
  say('');
  if (note) { say(note); say(''); }
  if (!rows.length) { say('- 還沒有資料'); say(''); return; }
  say('| 項目 | 細分 | 人數 | 次數 |');
  say('|---|---|---|---|');
  for (const e of rows) say(`| ${labels[e.event] ?? e.event} | ${detailText(e.event, e.detail) || '-'} | ${e.users} | ${e.total} |`);
  say('');
};
section('📚 功能使用', ['app_open', 'study_session', 'study_card', 'quiz_answer', 'spelling_answer', 'speaking', 'coach_check', 'scan_saved', 'scan_words', 'placement', 'mode_switch']);
section('🤖 AI', ['ai', 'ai_failed'], '「額度用完」的人數，就是當天把 AI 額度用光的人。');
const buckets = report.ai_per_day;
if (Object.keys(buckets).length) {
  say('每人每天用 AI 幾次（一人一天算一筆，伺服器只保留 7 天）：');
  say('');
  say('| 1-3 次 | 4-10 次 | 11-20 次 | 21-50 次 | 51 次以上 |');
  say('|---|---|---|---|---|');
  say(`| ${['1-3', '4-10', '11-20', '21-50', '51+'].map((k) => buckets[k] ?? 0).join(' | ')} |`);
  say('');
}
section('💰 付費', ['paywall_view', 'purchase', 'restore']);
const eu = report.event_users;
say(`付費漏斗（人數）：看到付費頁 ${eu.paywall_view ?? 0} → 按下購買 ${events.filter((e) => e.event === 'purchase' && e.detail.endsWith(':started')).reduce((n, e) => n + e.users, 0)} → 購買成功 ${events.filter((e) => e.event === 'purchase' && e.detail.endsWith(':purchased')).reduce((n, e) => n + e.users, 0)}`);
say('');
section('🙋 帳號', ['sign_in', 'account_deleted']);
say('> 只統計 2.0.2 (6) 以後的 App。訂閱收入、試用轉換、下載量請看 App Store Connect 的「分析」與「銷售和趨勢」。');

const text = out.join('\n') + '\n';
process.stdout.write(text);
if (process.env.GITHUB_STEP_SUMMARY) appendFileSync(process.env.GITHUB_STEP_SUMMARY, text);
