// Draws the App Store screenshots (6.9" iPhone, 1320 × 2868) in the style of
// the launch stories (scripts/generate-ig-story.mjs on the IG branch): a flat
// cream page, one bold headline, a short line under it and a large, real
// screen from the app; the last page is terracotta with no phone.
//
// The screens come from AppStoreScreenshotTests (ios-native.yml, checks
// `store`), published to the native-store-screenshots branch:
//   git fetch origin native-store-screenshots
//   node scripts/generate-app-store-screenshots.mjs        # zh-Hant and en-US
// Writes exports/app-store/<locale>/NN-name.png. The copy is in COPY below.
import fs from 'node:fs';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { chromium } from 'playwright';

const W = 1320;
const H = 2868;
const OUT = 'exports/app-store';
const SHOTS = process.env.SHOTS ?? (() => {
  const files = execFileSync('git', ['ls-tree', '-r', '--name-only', 'origin/native-store-screenshots']).toString().split('\n');
  const first = files.find((f) => f.endsWith('/store-zh-1-today.png') || f.endsWith('/store-en-1-today.png'));
  if (!first) throw new Error('No App Store screens: git fetch origin native-store-screenshots');
  return `origin/native-store-screenshots:${path.dirname(first)}`;
})();
const ICON = 'ios/Word7000/Assets.xcassets/AppIcon.appiconset/icon-1024.png';

/** Every word on the pages, per App Store locale. `screen` names a file from the tests. */
const COPY = {
  'zh-Hant': {
    name: 'WordCat',
    pages: [
      { file: '01-7000', screen: 'store-zh-1-today', title: '7000 單字<br>一天一點點',
        text: '打開就背，今天的進度傻貓排好了。' },
      { file: '02-cards', screen: 'store-zh-2-card', title: '背了又忘？<br>正常啦',
        text: '不熟的字過幾天會再跑出來，背到記住為止。' },
      { file: '03-speaking', screen: 'store-zh-5-coach', title: '英文要講出來<br>才是你的',
        text: '講錯沒差，傻貓會跟你說怎麼講比較順。', note: '線上 AI 批改要 Premium' },
      { file: '04-quiz', screen: 'store-zh-3-quiz', title: '又選錯？<br>看哪裡搞混',
        text: '小測驗、拼字、模擬考都有，錯了馬上知道差在哪。' },
      { file: '05-cat', screen: 'store-zh-7-cat', title: '這隻貓<br>嘴有點賤',
        text: '它記得你哪天考試，偷懶就會被念。' },
      { file: '06-scan', screen: 'store-zh-6-scan', title: '講義拍一下<br>就是單字卡',
        text: '印的、手寫的都行，不用自己打。', note: '掃描要 Premium' },
      { file: '07-free', finale: true, kicker: '背單字不用錢', title: '先背<br>再說',
        text: '單字卡、測驗、口說練習都免費。<br>想要 AI 批改和掃描，再升級 Premium。' },
    ],
  },
  'en-US': {
    name: 'WordCat',
    pages: [
      { file: '01-chinese', screen: 'store-en-1-today', title: 'Chinese,<br>a few words a day',
        text: 'Taiwan Mandarin with pinyin and audio. Today’s words are already picked.' },
      { file: '02-cards', screen: 'store-en-2-card', title: 'Forgot it?<br>Happens.',
        text: 'Words you miss come back in a few days, until they stick.' },
      { file: '03-speaking', screen: 'store-en-5-coach', title: 'Say it<br>out loud',
        text: 'Mess it up, that’s fine. The cat shows you a smoother way to say it.',
        note: 'Online feedback comes with Premium.' },
      { file: '04-quiz', screen: 'store-en-3-quiz', title: 'Wrong again?<br>Here’s why',
        text: 'Quick quizzes and writing drills. Miss one and you’ll see what you mixed up.' },
      { file: '05-cat', screen: 'store-en-7-cat', title: 'The cat<br>has opinions',
        text: 'It knows when your test is, and it’ll let you know when you slack off.' },
      { file: '06-scan', screen: 'store-en-6-scan', title: 'Snap a list,<br>get flashcards',
        text: 'Printed or handwritten. No typing.', note: 'Scanning comes with Premium.' },
      { file: '07-free', finale: true, kicker: 'Studying words is free', title: 'Just<br>start',
        text: 'Flashcards, quizzes and speaking practice cost nothing.<br>Upgrade when you want AI feedback and scanning.' },
    ],
  },
};

const C = { bg: '#F5EFE6', ink: '#24170F', soft: '#6E5444', accent: '#C9623F', cream: '#FFF4E4' };
const png = (buffer) => `data:image/png;base64,${buffer.toString('base64')}`;
// SHOTS is a git tree (branch:folder) or, for drafts, a folder on disk.
const shot = (name) => png(fs.existsSync(SHOTS) ? fs.readFileSync(path.join(SHOTS, `${name}.png`))
  : execFileSync('git', ['show', `${SHOTS}/${name}.png`], { maxBuffer: 64 << 20 }));
const icon = png(fs.readFileSync(ICON));

const css = `
  @import url('https://fonts.googleapis.com/css2?family=Inter:wght@500;600;700;800&family=Noto+Sans+TC:wght@500;700;900&display=block');
  * { box-sizing: border-box; margin: 0; }
  html, body { width: ${W}px; height: ${H}px; overflow: hidden; }
  body { position: relative; font-family: Inter, 'Noto Sans TC', sans-serif; color: ${C.ink}; -webkit-font-smoothing: antialiased; }
  .copy { position: absolute; left: 96px; right: 96px; top: 200px; }
  h1 { font-weight: 900; font-size: 124px; line-height: 1.08; letter-spacing: -3px; }
  :lang(zh) h1 { letter-spacing: 0; font-size: 128px; line-height: 1.14; }
  .text { margin-top: 40px; font-weight: 500; font-size: 46px; line-height: 1.42; color: ${C.soft}; max-width: 1110px; }
  .note { margin-top: 24px; font-weight: 700; font-size: 36px; color: ${C.accent}; }
  .phone { position: absolute; background: #121212; box-shadow: 0 40px 90px rgba(36,23,15,.24), 0 6px 16px rgba(36,23,15,.12); }
  .phone img { display: block; width: 100%; }
  .brand { display: flex; align-items: center; gap: 24px; font-weight: 800; font-size: 46px; }
  .brand img { width: 96px; height: 96px; border-radius: 22px; box-shadow: 0 2px 8px rgba(36,23,15,.18); }
`;

const page = (body, { bg = C.bg, lang }) =>
  `<!doctype html><html lang="${lang}"><head><meta charset="utf-8"><style>${css}</style></head><body style="background:${bg}">${body}</body></html>`;

/** A phone whose top edge is at y; it runs off the bottom of the page. */
const phone = (screen, y, w = 920) => {
  const r = Math.round(w * 0.127);
  const pad = Math.round(w * 0.024);
  return `<div class="phone" style="left:${(W - w) / 2}px;top:${y}px;width:${w}px;padding:${pad}px;border-radius:${r}px">
    <img src="${screen}" style="border-radius:${r - pad}px"></div>`;
};

function feature(p, lang) {
  // Leave the headline room; lines under it push the phone down a little.
  const lines = (p.text.length > (lang === 'zh' ? 26 : 60) ? 2 : 1) + (p.note ? 0.7 : 0);
  return page(`
    <div class="copy"><h1>${p.title}</h1><p class="text">${p.text}</p>${p.note ? `<p class="note">${p.note}</p>` : ''}</div>
    ${phone(shot(p.screen), 860 + lines * 70)}
  `, { lang });
}

function finale(p, lang, name) {
  return page(`
    <div style="position:absolute;left:96px;right:96px;top:520px;color:${C.cream}">
      <div class="brand"><img src="${icon}">${name}</div>
      <p style="margin-top:110px;font-weight:700;font-size:64px;letter-spacing:${lang === 'zh' ? 0 : -1}px">${p.kicker}</p>
      <p style="margin-top:30px;font-weight:900;font-size:${lang === 'zh' ? 300 : 280}px;line-height:1.02;letter-spacing:${lang === 'zh' ? 0 : -10}px">${p.title}</p>
      <p style="margin-top:70px;font-weight:500;font-size:50px;line-height:1.45;opacity:.92">${p.text}</p>
    </div>
  `, { bg: C.accent, lang });
}

const browser = await chromium.launch(process.env.CHROMIUM_PATH ? { executablePath: process.env.CHROMIUM_PATH } : {});
try {
  const tab = await browser.newPage({ viewport: { width: W, height: H }, deviceScaleFactor: 1 });
  for (const [locale, { name, pages }] of Object.entries(COPY)) {
    const lang = locale.startsWith('zh') ? 'zh' : 'en';
    const dir = path.join(OUT, locale);
    fs.mkdirSync(dir, { recursive: true });
    for (const p of pages) {
      await tab.setContent(p.finale ? finale(p, lang, name) : feature(p, lang), { waitUntil: 'networkidle' });
      await tab.evaluate(() => document.fonts.ready);
      const target = path.join(dir, `${p.file}.png`);
      await tab.screenshot({ path: target, type: 'png' });
      console.log(`Wrote ${target}`);
    }
  }
} finally {
  await browser.close();
}
