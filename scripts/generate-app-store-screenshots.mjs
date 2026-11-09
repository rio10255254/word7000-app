// Draws the App Store screenshots (6.9" iPhone, 1320 × 2868) in the style of
// the launch stories (scripts/generate-ig-story.mjs on the IG branch): a flat
// cream page, one bold headline, a short line under it and a large, real
// screen from the app; the last page is terracotta with no phone.
//
// The screens come from AppStoreScreenshotTests (ios-native.yml, checks
// `store`), published to the native-store-screenshots branch:
//   git fetch origin native-store-screenshots
//   node scripts/generate-app-store-screenshots.mjs        # zh-Hant and en-US
// Writes exports/app-store/<locale>/NN-name.jpg (high-quality JPEG: the paper grain
// makes PNGs about five times bigger for no visible gain). The copy is in COPY below.
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

/**
 * Every word on the pages, per App Store locale. `screen` names a file from the
 * tests; `pair` puts two screens side by side; `sticker` is a taped label over
 * the phone (x and y as fractions of the page); `chips` are small tags under
 * the line; `theme` is the page's colour (words on cream, speaking on sage,
 * the stamp on espresso, the cat on clay); `cat` puts Silly Cat himself on the
 * page (a mood cut out from the tests' store-cat-* pairs, where it goes, and
 * what he says). The story: what it is and who it is for, a plan for your
 * exam, real voices, checks right after the cards, 20 stages, the day's
 * stamp, the cat, and a last word from him.
 */
const COPY = {
  'zh-Hant': {
    name: 'WordCat 單字貓',
    pages: [
      { file: '01-7000', theme: 'clay', screen: 'store-zh-n1-today', brand: true, phoneTop: 1130,
        title: '7000 單字<br>傻貓<mark>陪你背完</mark>', text: '打開就知道今天背什麼、考什麼、練什麼。',
        chips: ['學測', '統測', '會考', '英檢'],
        cat: { mood: 'smug', x: 0.74, y: 0.395, w: 0.40, bubble: { text: '今天背了沒？', x: 0.33, y: 0.355 } } },
      { file: '02-plan', theme: 'cream', screen: 'store-zh-n6-plan', kicker: '個人計畫', title: '考前讀得完？<br>傻貓<mark>算給你看</mark>',
        text: '先測兩分鐘程度，<br>再照你的考試和日期排好每天的量。',
        sticker: { text: '照考試日期排', x: 0.71, y: 0.64 } },
      { file: '03-listen', theme: 'sage', screen: 'store-zh-n7-listen', kicker: '口說練習', title: '先聽<mark>真人</mark><br>怎麼說',
        text: '點餐、問路、看醫生……<br>每個角色都有自己的聲音，先聽完整段對話。',
        sticker: { text: '真人錄音', x: 0.72, y: 0.47 } },
      { file: '04-shadowing', theme: 'sage', screen: 'store-zh-n8-shadow', zoom: 'said', kicker: '口說練習', title: '念到哪<br><mark>亮到哪</mark>',
        text: '跟著示範念，念對的字變綠，<br>念錯的標出來，念對才往下。' },
      { file: '05-feedback', theme: 'sage', screen: 'store-zh-5-coach', kicker: '口說練習', title: '講錯沒差<br>傻貓幫你<mark>改順</mark>',
        text: '用說的或打的回答，看看怎麼講比較自然。', note: 'AI 批改為 Premium 功能' },
      { file: '06-checks', theme: 'cream', pair: ['store-zh-n3-write-solved', 'store-zh-n4-exam-answered'], kicker: '每天一條路', title: '背完<br>馬上<mark>考一下</mark>',
        text: '翻完卡接著拼字、做題，題型照你的考試出。<br>錯的會再回來，背到記住為止。',
        sticker: { text: '學測題型', x: 0.78, y: 0.47 } },
      { file: '07-map', theme: 'sage', screen: 'store-zh-n10-map', kicker: '口說練習', title: '20 關<br>生活<mark>情境</mark>',
        text: '餐廳、便利商店、飯店、看醫生……<br>一關一關闖，把星星拿滿。' },
      { file: '08-stamp', theme: 'dark', screen: 'store-zh-n11-stamp', title: '走完一天<br><mark>蓋個章</mark>',
        text: '連續天數一天天累積，日曆越塗越滿。' },
      { file: '09-cat', theme: 'honey', character: true, title: '這隻貓<br>嘴<mark>有點賤</mark>',
        text: '記得你哪天考試，偷懶會被念，<br>答錯還會對你吐舌頭。',
        cat: { mood: 'cheeky', x: 0.5, y: 0.75, w: 0.86 },
        bubbles: [{ text: '又來滑手機？', x: 0.28, y: 0.42, tail: 'r' }, { text: '錯得很有自信喔。', x: 0.64, y: 0.50, tail: 'l' },
                  { text: '我假裝沒看到。', x: 0.30, y: 0.585, tail: 'r' }] },
      { file: '10-start', finale: true, kicker: '傻貓在等你', title: '還在滑？<br>來背單字',
        collage: ['store-zh-n1-today', 'store-zh-n7-listen', 'store-zh-n11-stamp'],
        chips: ['翻卡', '拼字', '考題', '口說'],
        text: '每天一條路，走完蓋個章。',
        cat: { mood: 'cheer', x: 0.76, y: 0.29, w: 0.42 } },
    ],
  },
  'en-US': {
    name: 'WordCat',
    pages: [
      { file: '01-chinese', theme: 'clay', screen: 'store-en-n1-today', brand: true, phoneTop: 1130,
        title: 'Chinese,<br><mark>a few words</mark> a day', text: 'Taiwan Mandarin with pinyin and real voices. Today’s path is ready.',
        chips: ['Traditional characters', 'Pinyin', 'Audio'],
        cat: { mood: 'smug', x: 0.74, y: 0.395, w: 0.40, bubble: { text: 'Studied yet?', x: 0.34, y: 0.355 } } },
      { file: '02-plan', theme: 'cream', screen: 'store-en-n6-plan', kicker: 'Your plan', title: 'A plan that<br><mark>fits you</mark>',
        text: 'A two-minute check finds your level. Set a goal, and the cat works out each day for you.',
        sticker: { text: 'Made for you', x: 0.71, y: 0.64 } },
      { file: '03-listen', theme: 'sage', screen: 'store-en-n7-listen', kicker: 'Speaking', title: 'Hear it from<br><mark>real voices</mark>',
        text: 'Every role in every scene has its own Taiwanese Mandarin voice. Listen first, then join in.',
        sticker: { text: 'Real voices', x: 0.72, y: 0.47 } },
      { file: '04-tones', theme: 'sage', screen: 'store-en-n8-shadow', zoom: 'said', kicker: 'Speaking', title: 'See your<br><mark>tones</mark>',
        text: 'Say it along. Each character lights up as you say it, and a slipped tone is marked to say again.' },
      { file: '05-feedback', theme: 'sage', screen: 'store-en-5-coach', kicker: 'Speaking', title: 'Say it<br><mark>out loud</mark>',
        text: 'Mess it up, that’s fine. The cat shows you a smoother way to say it.',
        note: 'AI feedback is a Premium feature' },
      { file: '06-checks', theme: 'cream', pair: ['store-en-n2-card', 'store-en-n3-write-solved'], kicker: 'Every day', title: 'Flip it,<br>then <mark>write it</mark>',
        text: 'Flip the cards, then write each word in Chinese. The ones you miss come back until they stick.' },
      { file: '07-map', theme: 'sage', screen: 'store-en-n10-map', kicker: 'Speaking', title: '20 stages of<br><mark>everyday Taiwan</mark>',
        text: 'Restaurant, convenience store, hotel, the doctor… one stage at a time, for three stars.' },
      { file: '08-stamp', theme: 'dark', screen: 'store-en-n11-stamp', title: 'Finish the day,<br><mark>stamp it</mark>',
        text: 'Your streak grows, and the calendar fills up.' },
      { file: '09-cat', theme: 'honey', character: true, title: 'The cat<br>has <mark>opinions</mark>',
        text: 'It knows your goal, nags when you slack off, and sticks its tongue out at your mistakes.',
        cat: { mood: 'cheeky', x: 0.5, y: 0.75, w: 0.86 },
        bubbles: [{ text: 'Scrolling again?', x: 0.29, y: 0.42, tail: 'r' }, { text: 'Wrong, but with confidence.', x: 0.58, y: 0.50, tail: 'l' },
                  { text: 'I’ll pretend I didn’t see that.', x: 0.40, y: 0.585, tail: 'r' }] },
      { file: '10-start', finale: true, kicker: 'Silly Cat is waiting', title: 'Still<br>scrolling?',
        collage: ['store-en-n1-today', 'store-en-n7-listen', 'store-en-n11-stamp'],
        chips: ['Cards', 'Writing', 'Speaking'],
        text: 'One short path a day. Finish it, stamp it.',
        cat: { mood: 'cheer', x: 0.76, y: 0.29, w: 0.42 } },
    ],
  },
};

/**
 * Close-ups drawn over the phone, per interface language: a region of the screen
 * (x, y, w, h in screenshot pixels), enlarged on a taped card. The card sits over
 * the region itself, or with `below`, its top edge goes at that screen y, so what
 * is above stays whole (here: the whole conversation card, then the close-up over
 * the record button).
 */
const ZOOMS = JSON.parse(process.env.ZOOMS ?? 'null') ?? {
  // The line just said back, lit up character by character (for Chinese, with
  // its tones), and how much of it was right.
  said: {
    zh: { x: 400, y: 1570, w: 770, h: 280 },
    en: { x: 280, y: 1400, w: 890, h: 450 },
  },
};

const C = { bg: '#F5EFE6', ink: '#24170F', soft: '#6E5444', accent: '#C9623F', cream: '#FFF4E4' };
const png = (buffer) => `data:image/png;base64,${buffer.toString('base64')}`;
// SHOTS is a git tree (branch:folder) or, for drafts, a folder on disk.
const shot = (name) => png(fs.existsSync(SHOTS) ? fs.readFileSync(path.join(SHOTS, `${name}.png`))
  : execFileSync('git', ['show', `${SHOTS}/${name}.png`], { maxBuffer: 64 << 20 }));
const icon = png(fs.readFileSync(ICON));

// Paper grain over the flat colour, as in the app's own paper surfaces.
const grain = (opacity) => `url("data:image/svg+xml;utf8,${encodeURIComponent(
  `<svg xmlns='http://www.w3.org/2000/svg' width='360' height='360'><filter id='n'><feTurbulence type='fractalNoise' baseFrequency='.85' numOctaves='3' stitchTiles='stitch'/>`
  + `<feColorMatrix values='0 0 0 0 .32  0 0 0 0 .22  0 0 0 0 .14  0 0 0 ${opacity} 0'/></filter><rect width='100%' height='100%' filter='url(#n)'/></svg>`)}")`;

const mic = `<svg viewBox="0 0 24 24" width="30" height="30" aria-hidden="true"><path fill="currentColor" d="M12 14.5a3.5 3.5 0 0 0 3.5-3.5V5.5a3.5 3.5 0 1 0-7 0V11a3.5 3.5 0 0 0 3.5 3.5Zm6-3.5a1 1 0 1 0-2 0 4 4 0 0 1-8 0 1 1 0 1 0-2 0 6 6 0 0 0 5 5.91V19H8.5a1 1 0 1 0 0 2h7a1 1 0 1 0 0-2H13v-2.09A6 6 0 0 0 18 11Z"/></svg>`;

const css = `
  @import url('https://fonts.googleapis.com/css2?family=Inter:wght@500;600;700;800;900&family=Noto+Sans+TC:wght@500;700;900&display=block');
  * { box-sizing: border-box; margin: 0; }
  html, body { width: ${W}px; height: ${H}px; overflow: hidden; }
  body { position: relative; font-family: Inter, 'Noto Sans TC', sans-serif; color: ${C.ink}; -webkit-font-smoothing: antialiased;
    background-color: ${C.bg};
    background-image: ${grain(0.07)},
      radial-gradient(120% 70% at 18% 8%, rgba(255,255,255,.55), rgba(255,255,255,0) 60%),
      radial-gradient(90% 55% at 50% 100%, rgba(170,110,60,.10), rgba(170,110,60,0) 70%); }
  body.finale { background-color: ${C.accent};
    background-image: ${grain(0.10)}, radial-gradient(110% 70% at 20% 10%, rgba(255,214,170,.28), rgba(255,214,170,0) 60%),
      radial-gradient(90% 60% at 80% 100%, rgba(90,30,10,.22), rgba(90,30,10,0) 70%); }

  /* The words: kicker, headline (one phrase marked as with a highlighter), a line, a note. */
  .copy { position: absolute; left: 100px; right: 100px; top: 150px; height: 790px;
    display: flex; flex-direction: column; justify-content: center; }
  .brand { display: flex; align-items: center; gap: 22px; margin-bottom: 64px; font-weight: 800; font-size: 44px; letter-spacing: -0.5px; }
  .brand img { width: 92px; height: 92px; border-radius: 22px; box-shadow: 0 6px 18px rgba(80,45,20,.20), 0 1px 3px rgba(80,45,20,.18); }
  .kicker { align-self: flex-start; display: inline-flex; align-items: center; gap: 12px; margin-bottom: 34px; padding: 12px 30px 12px 22px;
    border-radius: 999px; background: ${C.accent}; color: ${C.cream}; font-weight: 800; font-size: 34px; letter-spacing: 2px;
    box-shadow: 0 6px 16px rgba(201,98,63,.28); transform: rotate(-1.5deg); }
  :lang(en) .kicker { letter-spacing: 1px; text-transform: uppercase; font-size: 30px; }
  h1 { font-weight: 900; font-size: 124px; line-height: 1.08; letter-spacing: -3.5px; text-wrap: balance; }
  :lang(zh) h1 { letter-spacing: 1px; font-size: 128px; line-height: 1.16; }
  h1 mark { color: inherit; background: none; position: relative; z-index: 0; white-space: nowrap; }
  h1 mark::before { content: ''; position: absolute; z-index: -1; left: -0.08em; right: -0.1em; bottom: 0.06em; height: 0.36em;
    background: rgba(229,172,76,.62); border-radius: 0.12em 0.2em 0.16em 0.1em; transform: rotate(-1.2deg) skewX(-8deg); }
  .text { margin-top: 42px; font-weight: 500; font-size: 46px; line-height: 1.45; color: ${C.soft}; max-width: 1100px; text-wrap: pretty; }
  .note { margin-top: 26px; display: flex; align-items: center; gap: 14px; font-weight: 700; font-size: 34px; color: ${C.accent}; }
  .note::before { content: ''; width: 16px; height: 16px; border-radius: 4px; background: ${C.accent}; transform: rotate(45deg); }

  /* An iPhone: titanium edge, black bezel, the Dynamic Island and the side keys. */
  .phone { position: absolute; border-radius: var(--r);
    background: linear-gradient(145deg, #57514c 0%, #26221f 18%, #141210 50%, #2a2623 82%, #5c5650 100%);
    box-shadow: 0 60px 120px rgba(80,45,20,.26), 0 18px 40px rgba(80,45,20,.20), 0 2px 4px rgba(0,0,0,.25),
      inset 0 0 0 2px rgba(255,255,255,.10); }
  .phone .bezel { position: absolute; inset: var(--edge); border-radius: calc(var(--r) - var(--edge)); background: #060606; }
  .phone img { position: absolute; display: block; inset: var(--bezel); width: calc(100% - 2 * var(--bezel));
    border-radius: calc(var(--r) - var(--edge) - var(--bezel)); }
  .phone .island { position: absolute; left: 50%; transform: translateX(-50%); background: #000; border-radius: 999px; }
  .phone .key { position: absolute; width: 7px; border-radius: 4px; background: linear-gradient(90deg, #2b2724, #5d5752); }

  /* Small tags under the line. */
  .chips { margin-top: 40px; display: flex; gap: 18px; flex-wrap: wrap; }
  .chips span { padding: 12px 28px; border-radius: 999px; background: rgba(201,98,63,.12); border: 2px solid rgba(201,98,63,.45);
    color: ${C.accent}; font-weight: 800; font-size: 36px; }
  .chips span::before { content: '✓ '; }

  /* A taped paper label over the phone, pointing something out. */
  .sticker { position: absolute; transform: translate(-50%, -50%) rotate(-4deg); padding: 22px 40px; border-radius: 14px;
    background: ${C.accent}; color: ${C.cream}; font-weight: 900; font-size: 52px; letter-spacing: 1px; white-space: nowrap;
    background-image: ${grain(0.10)}; box-shadow: 0 24px 50px rgba(80,45,20,.32), 0 6px 14px rgba(80,45,20,.2); }
  .sticker::after { content: ''; position: absolute; top: -26px; left: 50%; width: 140px; height: 46px; margin-left: -70px;
    transform: rotate(5deg); background: rgba(236,214,162,.85); box-shadow: 0 3px 8px rgba(80,45,20,.14); }

  /* Page colours: words on cream, speaking on sage, the stamp on espresso, the cat on honey and clay. */
  body.t-sage { background-color: #3E6A5D; }
  body.t-dark { background-color: #2B2019; }
  body.t-clay { background-color: ${C.accent}; }
  body.t-honey { background-color: #E7B04A; }
  body.t-sage, body.t-dark, body.t-clay { color: ${C.cream};
    background-image: ${grain(0.10)}, radial-gradient(110% 70% at 20% 8%, rgba(255,240,215,.16), rgba(255,240,215,0) 60%),
      radial-gradient(90% 60% at 80% 100%, rgba(0,0,0,.20), rgba(0,0,0,0) 70%); }
  body.t-honey { background-image: ${grain(0.08)}, radial-gradient(110% 70% at 20% 8%, rgba(255,250,235,.35), rgba(255,250,235,0) 60%),
      radial-gradient(90% 60% at 80% 100%, rgba(150,80,10,.18), rgba(150,80,10,0) 70%); }
  body.t-sage .text, body.t-dark .text, body.t-clay .text { color: rgba(255,244,228,.84); }
  body.t-sage .note, body.t-dark .note, body.t-clay .note { color: #F6D27A; }
  body.t-sage .note::before, body.t-dark .note::before, body.t-clay .note::before { background: #F6D27A; }
  body.t-sage h1 mark, body.t-dark h1 mark, body.t-clay h1 mark { color: #F8D27C; }
  body.t-sage h1 mark::before, body.t-dark h1 mark::before, body.t-clay h1 mark::before { background: rgba(0,0,0,.18); }
  body.t-sage .kicker { background: ${C.cream}; color: #3E6A5D; box-shadow: 0 6px 16px rgba(0,0,0,.18); }
  body.t-dark .kicker, body.t-clay .kicker { background: ${C.cream}; color: ${C.accent}; box-shadow: 0 6px 16px rgba(0,0,0,.18); }
  body.t-sage .chips span, body.t-dark .chips span, body.t-clay .chips span { background: rgba(255,244,228,.14);
    border-color: rgba(255,244,228,.55); color: ${C.cream}; }
  body.t-clay .brand img { box-shadow: 0 10px 26px rgba(60,20,5,.35); }
  body.t-honey .text { color: #5B3A12; }
  body.t-honey h1 mark::before { background: rgba(255,250,235,.7); }
  body.t-sage .sticker { background-color: #F6D27A; color: #2E4F45; }

  /* Silly Cat himself, cut out of the tests' pictures, and what he says. */
  .cat { position: absolute; z-index: 5; transform: translate(-50%, -50%);
    filter: drop-shadow(0 30px 34px rgba(50,25,8,.30)) drop-shadow(0 6px 10px rgba(50,25,8,.18)); }
  .bubble { position: absolute; z-index: 6; transform: translate(-50%, -50%) rotate(-1.5deg); background: #FFFDF8; color: ${C.ink};
    font-weight: 900; font-size: 56px; letter-spacing: 1px; padding: 28px 44px; border-radius: 48px; white-space: nowrap;
    box-shadow: 0 24px 50px rgba(50,25,8,.25), 0 4px 10px rgba(50,25,8,.15); }
  :lang(en) .bubble { letter-spacing: 0; font-size: 52px; }
  .bubble::after { content: ''; position: absolute; bottom: -16px; width: 40px; height: 40px; background: #FFFDF8; transform: rotate(45deg);
    border-radius: 6px; }
  .bubble.r::after { right: 64px; }
  .bubble.l::after { left: 64px; }

  /* A close-up on a taped scrap of paper over the phone. */
  .zoom { position: absolute; border-radius: 26px; transform: rotate(-1.6deg); padding: 14px; background: ${C.cream};
    background-image: ${grain(0.05)};
    box-shadow: 0 40px 80px rgba(80,45,20,.30), 0 8px 20px rgba(80,45,20,.18); }
  .zoom .shot { width: 100%; height: 100%; border-radius: 16px; background-repeat: no-repeat; }
  .zoom .tape { position: absolute; top: -30px; width: 200px; height: 58px; background: rgba(236,214,162,.80);
    box-shadow: 0 3px 8px rgba(80,45,20,.14); }
  .zoom .tape.a { left: 70px; transform: rotate(-7deg); }
  .zoom .tape.b { right: 80px; transform: rotate(6deg); }
`;

const page = (body, { lang, finale = false, theme = 'cream' }) =>
  `<!doctype html><html lang="${lang}"><head><meta charset="utf-8"><style>${css}</style></head><body class="${finale ? 'finale' : `t-${theme}`}">${body}</body></html>`;

/** Silly Cat cut out (see `cutout`), where `c` says, and his line in a bubble. */
const cats = {};
function catArt(c) {
  if (!c || !cats[c.mood]) return '';
  const bubble = c.bubble ? `<div class="bubble ${c.bubble.tail ?? 'r'}" style="left:${Math.round(c.bubble.x * W)}px;top:${Math.round(c.bubble.y * H)}px">${c.bubble.text}</div>` : '';
  return `<img class="cat" src="${cats[c.mood]}" style="left:${Math.round(c.x * W)}px;top:${Math.round(c.y * H)}px;width:${Math.round(c.w * W)}px">${bubble}`;
}
const bubbles = (list = []) => list.map((b) =>
  `<div class="bubble ${b.tail ?? 'r'}" style="left:${Math.round(b.x * W)}px;top:${Math.round(b.y * H)}px">${b.text}</div>`).join('');

// The phone's outline, in page pixels, for a given width.
const device = (w) => {
  const edge = Math.round(w * 0.012);       // the metal band
  const bezel = Math.round(w * 0.015);      // black glass around the screen
  const screen = w - 2 * (edge + bezel);
  const pt = screen / 402;                  // one iOS point (iPhone 18 Pro is 402 pt wide)
  return { w, edge, bezel, screen, pt, r: Math.round(w * 0.135) };
};

/** A phone whose top edge is at y; it runs off the bottom of the page. */
const phone = (screen, y, w = 920) => {
  const d = device(w);
  const h = Math.round(2 * (d.edge + d.bezel) + d.screen * 2622 / 1206);
  const key = (side, top, height) =>
    `<span class="key" style="${side}:-6px;top:${Math.round(top * d.pt)}px;height:${Math.round(height * d.pt)}px"></span>`;
  return `<div class="phone" style="left:${(W - w) / 2}px;top:${y}px;width:${w}px;height:${h}px;--r:${d.r}px;--edge:${d.edge}px;--bezel:${d.bezel}px">
    ${key('left', 118, 30)}${key('left', 176, 62)}${key('left', 252, 62)}${key('right', 196, 98)}
    <div class="bezel"><img src="${screen}">
      <span class="island" style="top:${Math.round(d.bezel + 11 * d.pt)}px;width:${Math.round(126 * d.pt)}px;height:${Math.round(37 * d.pt)}px"></span>
    </div></div>`;
};

const PHONE_TOP = 1000;

function feature(p, lang) {
  const screen = p.screen ? shot(p.screen) : null;
  const top = p.phoneTop ?? PHONE_TOP;
  return page(`
    <div class="copy">
      ${p.brand ? `<div class="brand"><img src="${icon}">${p.brandName ?? 'WordCat'}</div>` : ''}
      ${p.kicker ? `<p class="kicker">${mic}${p.kicker}</p>` : ''}
      <h1>${p.title}</h1><p class="text">${p.text}</p>${p.note ? `<p class="note">${p.note}</p>` : ''}
      ${p.chips ? `<div class="chips">${p.chips.map((c) => `<span>${c}</span>`).join('')}</div>` : ''}
    </div>
    ${p.character ? '' : p.pair ? pairOf(p.pair) : phone(screen, top)}
    ${p.zoom ? zoom(screen, ZOOMS[p.zoom][lang], top) : ''}
    ${p.sticker ? `<div class="sticker" style="left:${Math.round(p.sticker.x * W)}px;top:${Math.round(p.sticker.y * H)}px">${p.sticker.text}</div>` : ''}
    ${catArt(p.cat)}${bubbles(p.bubbles)}
  `, { lang, theme: p.theme });
}

/** Two screens side by side, the second a little lower, each a phone leaning in. */
function pairOf([first, second]) {
  const w = 640;
  const one = phone(shot(first), PHONE_TOP + 20, w).replace('class="phone" style="left:' + (W - w) / 2 + 'px;',
    'class="phone" style="transform:rotate(-3deg);left:' + 70 + 'px;');
  const two = phone(shot(second), PHONE_TOP + 180, w).replace('class="phone" style="left:' + (W - w) / 2 + 'px;',
    'class="phone" style="transform:rotate(3deg);left:' + (W - w - 70) + 'px;');
  return one + two;
}

/** A region of the screen, enlarged on a taped paper card over the phone. */
function zoom(screen, r, phoneTop, phoneWidth = 920) {
  const d = device(phoneWidth);
  const scale = d.screen / 1206;                        // screen pixels → page pixels inside the phone
  const width = W - 2 * 64;                             // the card spans the page, gutter to gutter
  const inner = width - 28;
  const factor = inner / (r.w * scale);                 // how much bigger than on the phone
  const height = Math.round(r.h * scale * factor) + 28;
  const screenTop = phoneTop + d.edge + d.bezel;
  const y = Math.round(r.below != null ? screenTop + r.below * scale : screenTop + (r.y + r.h / 2) * scale - height / 2);
  return `<div class="zoom" style="left:64px;top:${y}px;width:${width}px;height:${height}px">
      <div class="shot" style="background-image:url(${screen});background-size:${Math.round(1206 * scale * factor)}px auto;
        background-position:-${Math.round(r.x * scale * factor)}px -${Math.round(r.y * scale * factor)}px"></div>
      <span class="tape a"></span><span class="tape b"></span>
    </div>`;
}

function finale(p, lang, name) {
  const chips = p.chips ?? (lang === 'zh' ? ['單字卡', '測驗', '口說練習'] : ['Flashcards', 'Quizzes', 'Speaking']);
  // Three screens of the app, fanned out like taped scraps under the words.
  const fan = (p.collage ?? []).map((name, i) => {
    const w = 400, x = [70, 460, 850][i], y = [1790, 1700, 1810][i], turn = [-7, 1.5, 8][i];
    return `<div style="position:absolute;left:${x}px;top:${y}px;width:${w}px;transform:rotate(${turn}deg);padding:12px;border-radius:30px;
        background:${C.cream};box-shadow:0 40px 80px rgba(70,20,5,.38), 0 8px 20px rgba(70,20,5,.22)">
        <img src="${shot(name)}" style="display:block;width:100%;border-radius:20px">
        <span style="position:absolute;top:-24px;left:50%;width:150px;height:46px;margin-left:-75px;transform:rotate(${-turn * 0.8 + 3}deg);
          background:rgba(236,214,162,.85);box-shadow:0 3px 8px rgba(70,20,5,.18)"></span>
      </div>`;
  }).join('');
  return page(`
    ${fan}
    ${catArt(p.cat)}
    <div style="position:absolute;left:100px;right:100px;top:300px;color:${C.cream}">
      <div class="brand" style="margin:0"><img src="${icon}" style="width:150px;height:150px;border-radius:36px;box-shadow:0 18px 40px rgba(60,20,5,.35)">
        <span style="font-size:64px">${name}</span></div>
      <p style="margin-top:100px;font-weight:700;font-size:62px;letter-spacing:${lang === 'zh' ? 2 : -1}px;opacity:.95">${p.kicker}</p>
      <p style="margin-top:24px;font-weight:900;font-size:${lang === 'zh' ? 230 : 250}px;line-height:1.02;letter-spacing:${lang === 'zh' ? 4 : -9}px;
        text-shadow:0 10px 30px rgba(80,25,8,.25)">${p.title}</p>
      <div style="margin-top:80px;display:flex;gap:20px;flex-wrap:wrap">
        ${chips.map((c) => `<span style="padding:16px 34px;border-radius:999px;border:3px solid rgba(255,244,228,.85);font-weight:700;font-size:40px">${c}</span>`).join('')}
      </div>
      <p style="margin-top:56px;font-weight:500;font-size:46px;line-height:1.5;opacity:.9;text-wrap:pretty">${p.text}</p>
    </div>
  `, { lang, finale: true });
}

/** A shot, or null when the tests did not make it. */
const maybeShot = (name) => { try { return shot(name); } catch { return null; } };

/**
 * Silly Cat on a clear background: the tests draw him still on black and on
 * white (AppStoreScreenshotTests.testStoreMascots); where the two differ is
 * how see-through he is there, which gives his exact edges and soft shadow.
 * Cropped to him. Null (no cat on the page) when the pair is missing.
 */
async function cutout(tab, mood) {
  const black = maybeShot(`store-cat-${mood}-black`);
  const white = maybeShot(`store-cat-${mood}-white`);
  if (!black || !white) { console.warn(`No store-cat-${mood} pair: pages leave the cat out`); return null; }
  await tab.setContent('<html><body></body></html>');
  return tab.evaluate(async ([b, w]) => {
    const load = (src) => new Promise((done) => { const image = new Image(); image.onload = () => done(image); image.src = src; });
    const [ib, iw] = await Promise.all([load(b), load(w)]);
    const width = ib.width, height = ib.height;
    const pixels = (image) => {
      const canvas = document.createElement('canvas'); canvas.width = width; canvas.height = height;
      const context = canvas.getContext('2d'); context.drawImage(image, 0, 0);
      return context.getImageData(0, 0, width, height).data;
    };
    const pb = pixels(ib), pw = pixels(iw);
    const out = new ImageData(width, height);
    let minX = width, minY = height, maxX = 0, maxY = 0;
    // The top and bottom edges hold the system's own marks (the home indicator).
    const top = Math.round(height * 0.06), bottom = Math.round(height * 0.94);
    for (let y = top; y < bottom; y++) {
      for (let x = 0; x < width; x++) {
        const i = (y * width + x) * 4;
        const spread = ((pw[i] - pb[i]) + (pw[i + 1] - pb[i + 1]) + (pw[i + 2] - pb[i + 2])) / 3;
        let alpha = 1 - spread / 255;
        if (alpha < 0.03) continue;
        alpha = Math.min(1, alpha);
        out.data[i] = Math.min(255, pb[i] / alpha);
        out.data[i + 1] = Math.min(255, pb[i + 1] / alpha);
        out.data[i + 2] = Math.min(255, pb[i + 2] / alpha);
        out.data[i + 3] = Math.round(alpha * 255);
        if (alpha > 0.2) { minX = Math.min(minX, x); maxX = Math.max(maxX, x); minY = Math.min(minY, y); maxY = Math.max(maxY, y); }
      }
    }
    const pad = 40;
    minX = Math.max(0, minX - pad); minY = Math.max(0, minY - pad); maxX = Math.min(width - 1, maxX + pad); maxY = Math.min(height - 1, maxY + pad);
    const full = document.createElement('canvas'); full.width = width; full.height = height;
    full.getContext('2d').putImageData(out, 0, 0);
    const crop = document.createElement('canvas'); crop.width = maxX - minX + 1; crop.height = maxY - minY + 1;
    crop.getContext('2d').drawImage(full, minX, minY, crop.width, crop.height, 0, 0, crop.width, crop.height);
    return crop.toDataURL('image/png');
  }, [black, white]);
}

const browser = await chromium.launch(process.env.CHROMIUM_PATH ? { executablePath: process.env.CHROMIUM_PATH } : {});
try {
  const tab = await browser.newPage({ viewport: { width: W, height: H }, deviceScaleFactor: 1 });
  for (const [locale, { name, pages }] of Object.entries(COPY)) {
    const lang = locale.startsWith('zh') ? 'zh' : 'en';
    const dir = path.join(OUT, locale);
    // A fresh folder, so a page that was dropped or renamed doesn't linger.
    fs.rmSync(dir, { recursive: true, force: true });
    fs.mkdirSync(dir, { recursive: true });
    for (const mood of new Set(pages.map((p) => p.cat?.mood).filter(Boolean))) {
      cats[mood] ??= await cutout(tab, mood);
    }
    for (const p of pages) {
      if (p.brand) p.brandName ??= name;
      await tab.setContent(p.finale ? finale(p, lang, name) : feature(p, lang), { waitUntil: 'networkidle' });
      await tab.evaluate(() => document.fonts.ready);
      const target = path.join(dir, `${p.file}.jpg`);
      await tab.screenshot({ path: target, type: 'jpeg', quality: 95 });
      console.log(`Wrote ${target}`);
    }
  }
} finally {
  await browser.close();
}
