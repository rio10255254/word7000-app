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
  purchase: '購買', restore: '恢復購買', sign_in: 'Apple 登入', sign_in_failed: 'Apple 登入失敗', account_deleted: '刪除帳號',
  placement: '完成程度測驗', mode_switch: '切換學習模式',
};
const aiKinds = {
  coach: '口說批改', scan: '掃描辨識', explain: '單字解說', quizWhy: '測驗為什麼錯', fillWord: '填空',
  insights: '學習分析', ask: '問傻貓', chat: '傻貓聊天', lines: '每日台詞', verdict: '結算評語',
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
    const where = bank === 'core' ? `內建字庫 ${levels === 'all' ? '全部級數' : levels}` : bank === 'official' ? `官方字庫 ${levels}` : '自己的字庫';
    return `${mode[m] ?? m}・${where}`;
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
const both = (all, apple) => `${all}（Apple ${apple}）`;
say(`# 📈 使用數據（最近 ${report.days} 天，${report.since} 到 ${report.today}，台灣時間）`);
say('');
say('## 👥 使用者');
say('');
say('| 全部 | Apple 登入 | 訪客 | 期間新增（Apple／訪客） | Premium 訂閱中 |');
say('|---|---|---|---|---|');
say(`| ${u.total} | ${u.apple} | ${u.guests} | ${u.new}（${u.new_apple}／${u.new_guests}） | ${u.subscribers} |`);
say('');
const leftOut = (u.left_out_merged ?? 0) + (u.left_out_empty ?? 0);
if (leftOut) {
  say(`> 沒算進來的訪客 ${leftOut} 個：${u.left_out_merged ?? 0} 個已經併進原本的 Apple 帳號、${u.left_out_empty ?? 0} 個是加入超過 7 天、只打開過一天的空帳號。資料沒有刪除。`);
  say('');
}
say('## 🔥 活躍');
say('');
say('| 今天 | 昨天 | 7 天內 | 30 天內 |');
say('|---|---|---|---|');
say(`| ${both(a.today, a.today_apple)} | ${both(a.yesterday, a.yesterday_apple)} | ${both(a.last_7_days, a.last_7_days_apple)} | ${both(a.last_30_days, a.last_30_days_apple)} |`);
say('');
say('| 日期 | 活躍（Apple） | 新帳號（Apple） |');
say('|---|---|---|');
for (const d of report.daily) say(`| ${d.day} | ${both(d.active, d.active_apple)} | ${both(d.new, d.new_apple)} |`);
say('');
say('「Apple」是用 Apple 登入的帳號，最接近真人數；訪客可能是同一個人換手機或重新安裝。');
say('');
say('## 🔁 留存（最近 90 天加入的人）');
say('');
say('| | 隔天回來 | 第 7 天那週回來 | 第 30 天那週回來 |');
say('|---|---|---|---|');
for (const [kind, label] of [['apple', 'Apple 登入'], ['guests', '訪客']]) {
  const r = report.retention?.[kind];
  if (r) say(`| ${label} | ${pct(r.d1.back, r.d1.cohort)} | ${pct(r.d7.back, r.d7.cohort)} | ${pct(r.d30.back, r.d30.cohort)} |`);
}
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
section('🙋 帳號', ['sign_in', 'sign_in_failed', 'account_deleted']);
// Per build: each account counted under the build it runs now.
const byBuild = report.by_build;
if (byBuild?.builds?.length) {
  const key = ['app_open', 'study_card', 'quiz_answer', 'spelling_answer', 'speaking', 'coach_check', 'placement', 'scan_saved', 'paywall_view'];
  const name = (b) => b.app_version === '?' ? '沒回報版本' : `${b.app_version}${b.app_build ? ` (${b.app_build})` : ''}`;
  const same = (b, e) => e.app_version === b.app_version && (e.app_build ?? null) === (b.app_build ?? null);
  say('## 🧩 各版本的使用（依每個帳號現在裝的版本）');
  say('');
  say('一個帳號整段期間的使用都算在它「現在」的版本底下；格子是「人數／次數」。');
  say('');
  say(`| 版本 | 活躍帳號 | ${key.map((k) => labels[k] ?? k).join(' | ')} |`);
  say(`|---|---|${key.map(() => '---').join('|')}|`);
  for (const b of byBuild.builds) {
    const cells = key.map((k) => {
      const rows = byBuild.events.filter((e) => same(b, e) && e.event === k);
      if (!rows.length) return '-';
      const people = Math.max(...rows.map((e) => e.people));
      const times = rows.reduce((n, e) => n + e.times, 0);
      return `${people}／${times}`;
    });
    say(`| ${name(b)} | ${b.accounts} | ${cells.join(' | ')} |`);
  }
  say('');
}
say('> 只統計 2.0.2 (6) 以後的 App。訂閱收入、試用轉換、下載量請看 App Store Connect 的「分析」與「銷售和趨勢」。');

const text = out.join('\n') + '\n';
process.stdout.write(text);
if (process.env.GITHUB_STEP_SUMMARY) appendFileSync(process.env.GITHUB_STEP_SUMMARY, text);
