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

/** Every word on the pages, per App Store locale. `screen` names a file from the tests. */
const COPY = {
  'zh-Hant': {
    name: 'WordCat',
    pages: [
      { file: '01-7000', screen: 'store-zh-1-today', brand: true, title: '7000 單字<br>一天<mark>一點點</mark>',
        text: '打開就背，今天的進度傻貓排好了。' },
      { file: '02-scenes', screen: 'store-zh-4-speaking-shadow', kicker: '口說練習', title: '點餐、問路<br>先在這<mark>練一遍</mark>',
        text: '餐廳、問路、看醫生……10 個生活情境，<br>輪到你就開口說。' },
      { file: '03-shadowing', screen: 'store-zh-4-speaking-shadow-result', kicker: '口說練習', title: '念到哪<br><mark>亮到哪</mark>',
        text: '跟著示範念一遍，念對的字會變綠，<br>念完自動跳下一步。', zoom: 'sentence' },
      { file: '04-feedback', screen: 'store-zh-5-coach', kicker: '口說練習', title: '講錯沒差<br>傻貓幫你<mark>改順</mark>',
        text: '用說的或打的回答，看看怎麼講比較自然。', note: '線上 AI 批改要 Premium' },
      { file: '05-map', screen: 'store-zh-4-speaking-map', kicker: '口說練習', title: '十個場景<br><mark>挑一個</mark>開始',
        text: '餐廳、便利商店、飯店、看醫生……<br>每個場景兩關，想練哪個點哪個。' },
      { file: '06-cards', screen: 'store-zh-2-card', title: '背了又忘？<br><mark>正常啦</mark>',
        text: '不熟的字過幾天會再跑出來，背到記住為止。' },
      { file: '07-quiz', screen: 'store-zh-3-quiz', title: '又選錯？<br>看哪裡<mark>搞混</mark>',
        text: '小測驗、拼字、模擬考都有，錯了馬上知道差在哪。' },
      { file: '08-cat', screen: 'store-zh-7-cat', title: '這隻貓<br>嘴<mark>有點賤</mark>',
        text: '它記得你哪天考試，偷懶就會被念。' },
      { file: '09-scan', screen: 'store-zh-6-scan', title: '講義拍一下<br>就是<mark>單字卡</mark>',
        text: '印的、手寫的都行，不用自己打。', note: '掃描要 Premium' },
      { file: '10-free', finale: true, kicker: '背單字不用錢', title: '先背<br>再說',
        collage: ['store-zh-1-today', 'store-zh-4-speaking-shadow', 'store-zh-5-coach'],
        text: '這些都免費。想要 AI 批改和掃描，再升級 Premium。' },
    ],
  },
  'en-US': {
    name: 'WordCat',
    pages: [
      { file: '01-chinese', screen: 'store-en-1-today', brand: true, title: 'Chinese,<br><mark>a few words</mark> a day',
        text: 'Taiwan Mandarin with pinyin and audio. Today’s words are already picked.' },
      { file: '02-scenes', screen: 'store-en-4-speaking-shadow', kicker: 'Speaking', title: 'Order, ask the way,<br><mark>see a doctor</mark>',
        text: 'Ten everyday scenes in Taiwan Mandarin. When it’s your turn, say your line.' },
      { file: '03-tones', screen: 'store-en-4-speaking-shadow-result', kicker: 'Speaking', title: 'See your<br><mark>tones</mark>',
        text: 'Say it along. Each character lights up when it’s heard, with your pitch drawn underneath.', zoom: 'sentence' },
      { file: '04-feedback', screen: 'store-en-5-coach', kicker: 'Speaking', title: 'Say it<br><mark>out loud</mark>',
        text: 'Mess it up, that’s fine. The cat shows you a smoother way to say it.',
        note: 'Online feedback comes with Premium.' },
      { file: '05-map', screen: 'store-en-4-speaking-map', kicker: 'Speaking', title: 'Ten scenes,<br><mark>pick one</mark>',
        text: 'Restaurant, convenience store, hotel, the doctor… two stages each. Start anywhere.' },
      { file: '06-cards', screen: 'store-en-2-card', title: 'Forgot it?<br><mark>Happens.</mark>',
        text: 'Words you miss come back in a few days, until they stick.' },
      { file: '07-quiz', screen: 'store-en-3-quiz', title: 'Wrong again?<br><mark>Here’s why</mark>',
        text: 'Quick quizzes and writing drills. Miss one and you’ll see what you mixed up.' },
      { file: '08-cat', screen: 'store-en-7-cat', title: 'The cat<br>has <mark>opinions</mark>',
        text: 'It knows when your test is, and it’ll let you know when you slack off.' },
      { file: '09-scan', screen: 'store-en-6-scan', title: 'Snap a list,<br>get <mark>flashcards</mark>',
        text: 'Printed or handwritten. No typing.', note: 'Scanning comes with Premium.' },
      { file: '10-free', finale: true, kicker: 'Studying words is free', title: 'Just<br>start',
        collage: ['store-en-1-today', 'store-en-4-speaking-shadow', 'store-en-5-coach'],
        text: 'All free. Upgrade when you want AI feedback and scanning.' },
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
  // The line just said, lit up word by word (for Chinese, with its tones), and the score under it.
  sentence: {
    zh: { x: 70, y: 950, w: 1066, h: 355, below: 1340 },
    en: { x: 70, y: 1004, w: 1066, h: 466, below: 1548 },
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

const page = (body, { lang, finale = false }) =>
  `<!doctype html><html lang="${lang}"><head><meta charset="utf-8"><style>${css}</style></head><body${finale ? ' class="finale"' : ''}>${body}</body></html>`;

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
  const screen = shot(p.screen);
  return page(`
    <div class="copy">
      ${p.brand ? `<div class="brand"><img src="${icon}">WordCat</div>` : ''}
      ${p.kicker ? `<p class="kicker">${mic}${p.kicker}</p>` : ''}
      <h1>${p.title}</h1><p class="text">${p.text}</p>${p.note ? `<p class="note">${p.note}</p>` : ''}
    </div>
    ${phone(screen, PHONE_TOP)}
    ${p.zoom ? zoom(screen, ZOOMS[p.zoom][lang], PHONE_TOP) : ''}
  `, { lang });
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
  const chips = lang === 'zh' ? ['單字卡', '測驗', '口說練習'] : ['Flashcards', 'Quizzes', 'Speaking'];
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
    <div style="position:absolute;left:100px;right:100px;top:300px;color:${C.cream}">
      <div class="brand" style="margin:0"><img src="${icon}" style="width:150px;height:150px;border-radius:36px;box-shadow:0 18px 40px rgba(60,20,5,.35)">
        <span style="font-size:64px">${name}</span></div>
      <p style="margin-top:100px;font-weight:700;font-size:62px;letter-spacing:${lang === 'zh' ? 2 : -1}px;opacity:.95">${p.kicker}</p>
      <p style="margin-top:24px;font-weight:900;font-size:${lang === 'zh' ? 300 : 290}px;line-height:1.0;letter-spacing:${lang === 'zh' ? 4 : -11}px;
        text-shadow:0 10px 30px rgba(80,25,8,.25)">${p.title}</p>
      <div style="margin-top:80px;display:flex;gap:20px;flex-wrap:wrap">
        ${chips.map((c) => `<span style="padding:16px 34px;border-radius:999px;border:3px solid rgba(255,244,228,.85);font-weight:700;font-size:40px">✓ ${c}</span>`).join('')}
      </div>
      <p style="margin-top:56px;font-weight:500;font-size:46px;line-height:1.5;opacity:.9;text-wrap:pretty">${p.text}</p>
    </div>
  `, { lang, finale: true });
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
    for (const p of pages) {
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
