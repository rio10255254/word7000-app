// Publishes word list content the app picks up without an update (see
// RemoteContent in the app): ✏️ word fixes and 📚 official banks.
// ACTION: fix | bank-publish | bank-remove. Needs SERVICE_KEY and REST
// (passed by scripts/remote-control.sh). DRY_RUN=true only previews.
import { appendFileSync, existsSync, readFileSync } from 'node:fs';

const env = process.env;
const dry = env.DRY_RUN === 'true';
const summary = env.GITHUB_STEP_SUMMARY;
const say = (line = '') => { console.log(line); if (summary) appendFileSync(summary, line + '\n'); };
const fail = (message) => { say(`❌ ${message}`); console.log(`::error::${message.replace(/\n/g, ' ')}`); process.exit(1); };
const headers = { apikey: env.SERVICE_KEY, 'Content-Type': 'application/json', Prefer: 'return=representation' };
if (env.SERVICE_KEY?.startsWith('eyJ')) headers.Authorization = `Bearer ${env.SERVICE_KEY}`;
async function rest(method, path, body, extra = {}) {
  const response = await fetch(`${env.REST}/${path}`, { method, headers: { ...headers, ...extra }, body: body ? JSON.stringify(body) : undefined });
  const text = await response.text();
  if (!response.ok) fail(`伺服器回應 ${response.status}：${text.slice(0, 300)}`);
  return text ? JSON.parse(text) : null;
}
const modeOf = (label = '') => (label.includes('中文') || label === 'chinese' ? 'chinese' : 'english');
const modeName = { english: '學英文', chinese: '學中文' };
const fieldNames = {
  meaningZh: '中文意思', supplementalMeaningZh: '補充意思', partOfSpeech: '詞性', pronunciation: '音標／拼音',
  example: '例句', exampleZh: '例句翻譯', word: '單字拼法', group: '級數',
};
const fieldOf = {
  '中文意思／中文詞': 'meaningZh', '英文單字／英文解釋': 'word', 中文意思: 'meaningZh', 補充意思: 'supplementalMeaningZh', 詞性: 'partOfSpeech', '音標／拼音': 'pronunciation',
  例句: 'example', 例句翻譯: 'exampleZh', 單字拼法: 'word', 級數: 'group',
};
const show = (value) => (value === undefined || value === null || value === '' ? '（空白）' : value);

async function fix() {
  const mode = modeOf(env.MODE);
  const query = (env.WORD ?? '').trim();
  const choice = (env.FIELD ?? '').trim();
  const value = (env.VALUE ?? '').trim();
  if (!query) fail('請填要校正的單字');
  const bundled = JSON.parse(readFileSync(mode === 'chinese' ? 'ios/Word7000/Resources/words-zh.json' : 'ios/Word7000/Resources/words.json', 'utf8'));
  const banks = await rest('GET', `official_banks?select=id,name_zh,words&mode=eq.${mode}`);
  const pool = [...bundled.map((w) => ({ ...w, where: '內建字庫' })),
    ...banks.flatMap((b) => b.words.map((w) => ({ ...w, where: `官方字庫「${b.name_zh}」` })))];
  const lower = query.toLowerCase();
  let matches = pool.filter((w) => w.id === query);
  if (!matches.length) matches = pool.filter((w) => w.word.toLowerCase() === lower || w.meaningZh === query);
  if (!matches.length) matches = pool.filter((w) => w.meaningZh.split(/[；;、,，]/).map((s) => s.trim()).includes(query));
  if (!matches.length) {
    const stem = lower.slice(0, Math.max(3, lower.length - 2));
    const near = pool.filter((w) => w.word.toLowerCase().startsWith(stem) || w.meaningZh.includes(query)).slice(0, 8);
    fail(`在${modeName[mode]}找不到「${query}」。${near.length ? `相近的有：${near.map((w) => `${w.word}（${w.meaningZh}，代號 ${w.id}）`).join('、')}` : ''}`);
  }
  if (matches.length > 1) {
    say(`## 🔎 「${query}」有 ${matches.length} 個，請在「單字」欄改填代號再按一次`);
    say('');
    say('| 代號 | 單字 | 詞性 | 中文意思 | 在哪裡 |');
    say('|---|---|---|---|---|');
    for (const w of matches) say(`| ${w.id} | ${w.word} | ${w.partOfSpeech} | ${w.meaningZh} | ${w.where} |`);
    process.exit(1);
  }
  const word = matches[0];
  if (mode === 'chinese') Object.assign(fieldNames, { meaningZh: '中文詞', word: '英文解釋', pronunciation: '拼音' });
  const existing = (await rest('GET', `content_corrections?select=fields,hidden,active&mode=eq.${mode}&word_id=eq.${encodeURIComponent(word.id)}`))[0];
  const fields = existing?.active ? { ...existing.fields } : {};
  let hidden = existing?.active ? existing.hidden : false;
  let active = true;
  let change;
  if (choice.startsWith('取消')) {
    if (!existing?.active) fail(`「${word.word}」目前沒有校正，不用取消`);
    active = false;
    change = '取消這個字的所有校正，恢復原本內容';
  } else if (choice.startsWith('隱藏')) {
    hidden = true;
    change = '隱藏這個字（大家的 App 不再出現，學習紀錄保留）';
  } else if (choice.startsWith('恢復顯示')) {
    hidden = false;
    change = '恢復顯示這個字';
  } else {
    const field = fieldOf[choice];
    if (!field) fail(`不認得要改的欄位「${choice}」`);
    if (!value && ['word', 'meaningZh', 'group'].includes(field)) fail(`「${fieldNames[field]}」不能是空白`);
    if (value.length > 600) fail('內容太長（最多 600 字）');
    fields[field] = value;
    change = `${fieldNames[field]}：${show(word[field])} → ${show(value)}`;
  }
  say(`## ${dry ? '👀 預覽（還沒送出）' : '✏️ 已校正'}：${word.word}（${word.meaningZh}）`);
  say('');
  say(`- 模式：${modeName[mode]}；位置：${word.where}；代號 ${word.id}`);
  say(`- 這次的修改：**${change}**`);
  const after = Object.entries(fields);
  if (active && after.length) say(`- 這個字目前所有的校正：${after.map(([k, v]) => `${fieldNames[k] ?? k}「${show(v)}」`).join('、')}${hidden ? '（已隱藏）' : ''}`);
  say('');
  if (dry) { say('確認沒問題後，取消勾選「只預覽」再按一次。'); return; }
  await rest('POST', 'content_corrections?on_conflict=mode,word_id',
    { mode, word_id: word.id, fields, hidden, active, note: (env.NOTE ?? '').slice(0, 300) || null, updated_at: new Date().toISOString() },
    { Prefer: 'resolution=merge-duplicates,return=representation' });
  say('✅ 大家下次打開或回到 App 時就會套用，不用更新 App。');
}

const slug = (text) => text.toLowerCase().normalize('NFKD').replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '').slice(0, 40);

function loadBank(id) {
  if (!/^[a-z0-9][a-z0-9-]{1,39}$/.test(id)) fail(`字庫代號「${id}」只能用小寫英文、數字和 -`);
  const path = `content/banks/${id}.json`;
  if (!existsSync(path)) fail(`找不到 ${path}。新字庫的內容檔要先放進 content/banks/（可以請 Claude 做）`);
  const bank = JSON.parse(readFileSync(path, 'utf8'));
  const mode = modeOf(bank.mode);
  if (!bank.name_zh) fail('字庫內容檔缺少 name_zh（中文名稱）');
  const seen = new Set();
  const problems = [];
  const words = (bank.words ?? []).map((w, index) => {
    const word = String(w.word ?? '').trim();
    const meaning = String(w.meaningZh ?? '').trim();
    if (!word || !meaning) { problems.push(`第 ${index + 1} 個缺少 word 或 meaningZh`); return null; }
    let wordId = w.id ? String(w.id) : `pack-${id}-${slug(mode === 'chinese' ? `${word} ${w.partOfSpeech ?? ''}` : word) || index + 1}`;
    if (!wordId.startsWith('pack-')) wordId = `pack-${id}-${wordId}`;
    if (seen.has(wordId)) wordId = `${wordId}-${slug(w.partOfSpeech ?? '') || index + 1}`;
    if (seen.has(wordId)) { problems.push(`「${word}」重複了`); return null; }
    seen.add(wordId);
    return {
      id: wordId, word, partOfSpeech: String(w.partOfSpeech ?? ''), pronunciation: String(w.pronunciation ?? ''),
      meaningZh: meaning, ...(w.supplementalMeaningZh ? { supplementalMeaningZh: String(w.supplementalMeaningZh) } : {}),
      example: String(w.example ?? ''), exampleZh: String(w.exampleZh ?? ''), group: String(w.group ?? 'Level 1'),
    };
  }).filter(Boolean);
  if (problems.length) fail(`字庫內容有問題：${problems.slice(0, 10).join('；')}`);
  if (!words.length) fail('字庫裡沒有單字');
  return {
    id, mode, name_zh: bank.name_zh, name_en: bank.name_en ?? '', description_zh: bank.description_zh ?? '',
    description_en: bank.description_en ?? '', icon: bank.icon ?? 'books.vertical.fill', color: bank.color ?? '#5856D6',
    premium: Boolean(bank.premium), sort: Number(bank.sort ?? 0), words,
  };
}

async function publish() {
  const id = (env.BANK ?? '').trim();
  const bank = loadBank(id);
  const existing = (await rest('GET', `official_banks?select=id,active,words&id=eq.${id}`))[0];
  const levels = [...new Set(bank.words.map((w) => w.group))];
  say(`## ${dry ? '👀 預覽（還沒上架）' : '📚 已上架'}：${bank.name_zh}${bank.name_en ? `／${bank.name_en}` : ''}`);
  say('');
  say(`- 模式：${modeName[bank.mode]}；${bank.premium ? '💎 Premium 才能學' : '免費'}；${bank.words.length} 個單字；級數 ${levels.join('、')}`);
  if (bank.description_zh) say(`- 說明：${bank.description_zh}`);
  if (existing) {
    const before = new Set(existing.words.map((w) => w.id));
    const after = new Set(bank.words.map((w) => w.id));
    say(`- 這是更新：新增 ${[...after].filter((x) => !before.has(x)).length} 個、移除 ${[...before].filter((x) => !after.has(x)).length} 個${existing.active ? '' : '（目前是下架狀態，會重新上架）'}`);
  }
  say('');
  say('前 10 個單字：');
  say('');
  say('| 單字 | 詞性 | 中文意思 | 級數 |');
  say('|---|---|---|---|');
  for (const w of bank.words.slice(0, 10)) say(`| ${w.word} | ${w.partOfSpeech} | ${w.meaningZh} | ${w.group} |`);
  say('');
  if (dry) { say('確認沒問題後，取消勾選「只預覽」再按一次。'); return; }
  await rest('POST', 'official_banks?on_conflict=id', { ...bank, active: true, updated_at: new Date().toISOString() },
    { Prefer: 'resolution=merge-duplicates,return=minimal' });
  say('✅ 大家下次打開或回到 App 時，就會在「單字」頁看到這個字庫，不用更新 App。');
}

async function remove() {
  const id = (env.BANK ?? '').trim();
  const existing = (await rest('GET', `official_banks?select=id,name_zh,active&id=eq.${encodeURIComponent(id)}`))[0];
  if (!existing) fail(`沒有代號「${id}」的字庫`);
  if (!existing.active) fail(`「${existing.name_zh}」已經是下架狀態`);
  say(`## ${dry ? '👀 預覽（還沒下架）' : '🧹 已下架'}：${existing.name_zh}`);
  say('');
  say('正在用這個字庫的人會自動切回內建字庫；學習紀錄會保留，重新上架就回來。');
  if (dry) { say(''); say('確認沒問題後，取消勾選「只預覽」再按一次。'); return; }
  await rest('PATCH', `official_banks?id=eq.${encodeURIComponent(id)}`, { active: false, updated_at: new Date().toISOString() }, { Prefer: 'return=minimal' });
}

const actions = { fix, 'bank-publish': publish, 'bank-remove': remove };
if (!actions[env.ACTION]) fail(`unknown ACTION ${env.ACTION}`);
await actions[env.ACTION]();
