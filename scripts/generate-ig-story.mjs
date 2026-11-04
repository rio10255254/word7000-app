// Draws the Instagram story pages (1080 × 1920) for WordCat's launch:
//   1. an overview of what the app does,
//   2–4. one page per ability, each with a large, real screen from the app,
//   5. when and how to download it, and the @wordcat.app account.
// Plain on purpose: a flat background, one typeface, the app icon and the
// real interface. The screens come from the UI tests' promotional walk
// (ScreenshotTests.testPromo*, run with ios-native.yml's `promo` checks),
// English interface learning Chinese. Top ~250 px and bottom ~250 px are
// left for Instagram's own bars. The copy lives in COPY below so it can be
// edited by a native speaker without touching the layout.
//
//   git fetch origin native-promo-screenshots
//   node scripts/generate-ig-story.mjs            # pages with sticker outlines
//   node scripts/generate-ig-story.mjs --clean    # pages to post
import fs from 'node:fs';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { chromium } from 'playwright';

const W = 1080;
const H = 1920;
const OUT = 'exports/ig-story';
// The run's folder on the screenshots branch, e.g. native-screenshots-335-ios-27.
const SHOTS = process.env.SHOTS ?? (() => {
  const files = execFileSync('git', ['ls-tree', '-r', '--name-only', 'origin/native-promo-screenshots']).toString().split('\n');
  const today = files.find((f) => f.endsWith('/promo-1-today.png'));
  if (!today) throw new Error('No promo screenshots: git fetch origin native-promo-screenshots');
  return `origin/native-promo-screenshots:${path.dirname(today)}`;
})();
const ICON = 'ios/Word7000/Assets.xcassets/AppIcon.appiconset/icon-1024.png';
const FS = 'https://cdn.jsdelivr.net/npm/@fontsource/inter@5.0.0/files';
const clean = process.argv.includes('--clean');

/** Every line of text on the pages. */
const COPY = {
  overview: {
    title: 'Learn Chinese<br>with WordCat',
    text: 'A daily vocabulary app for Traditional Chinese, coming to iPhone.',
    labels: ['Flashcards', 'Quizzes', 'Speaking'],
  },
  study: {
    title: 'New words<br>every day',
    text: 'Each card has pinyin, audio and an example sentence. Words you miss come back until they stick.',
  },
  quiz: {
    title: 'Check what<br>you remember',
    text: 'Quick quizzes and writing drills. Get one wrong and the cat shows you what mixed you up.',
  },
  speaking: {
    title: 'Practice<br>speaking',
    text: 'Answer out loud or type it. The AI tutor shows a more natural way to say it, then asks a follow-up.',
    note: 'AI feedback is included with WordCat Premium.',
  },
  launch: {
    kicker: 'Coming to the App Store',
    date: 'Nov 16',
    text: 'Search “WordCat” on your iPhone.',
    follow: 'Follow @wordcat.app for updates',
  },
};

/** Which screen each page shows (file names in SHOTS). */
const SCREENS = JSON.parse(process.env.SCREENS ?? 'null') ?? {
  overview: ['promo-3-study-answer', 'promo-8-quiz-answered', 'promo-13-coach-a'],
  study: 'promo-3-study-answer',
  quiz: 'promo-8-quiz-answered',
  speaking: 'promo-13-coach-a',
};

const C = { bg: '#F5EFE6', ink: '#24170F', soft: '#6E5444', accent: '#C9623F', cream: '#FFF4E4' };

const png = (buffer) => `data:image/png;base64,${buffer.toString('base64')}`;
const shot = (name) => png(execFileSync('git', ['show', `${SHOTS}/${name}.png`], { maxBuffer: 64 << 20 }));
const icon = png(fs.readFileSync(ICON));

const css = `
  @font-face { font-family: Inter; font-weight: 500; src: url(${FS}/inter-latin-500-normal.woff2) format('woff2'); }
  @font-face { font-family: Inter; font-weight: 600; src: url(${FS}/inter-latin-600-normal.woff2) format('woff2'); }
  @font-face { font-family: Inter; font-weight: 700; src: url(${FS}/inter-latin-700-normal.woff2) format('woff2'); }
  @font-face { font-family: Inter; font-weight: 800; src: url(${FS}/inter-latin-800-normal.woff2) format('woff2'); }
  * { box-sizing: border-box; margin: 0; }
  html, body { width: ${W}px; height: ${H}px; overflow: hidden; }
  body { position: relative; font-family: Inter, sans-serif; color: ${C.ink}; -webkit-font-smoothing: antialiased; }
  .abs { position: absolute; }
  .brand { position: absolute; left: 72px; top: 250px; display: flex; align-items: center; gap: 20px; font: 700 36px Inter; letter-spacing: -0.5px; }
  .brand img { width: 76px; height: 76px; border-radius: 18px; box-shadow: 0 2px 8px rgba(36,23,15,.15); }
  .copy { position: absolute; left: 72px; right: 72px; top: 380px; }
  h1 { font: 800 92px/1.02 Inter; letter-spacing: -3px; }
  .text { margin-top: 30px; font: 500 36px/1.38 Inter; color: ${C.soft}; max-width: 900px; }
  .phone { position: absolute; background: #121212; border-radius: 86px; padding: 16px;
    box-shadow: 0 30px 70px rgba(36,23,15,.22), 0 4px 12px rgba(36,23,15,.12); }
  .phone img { display: block; width: 100%; border-radius: 72px; }
  .slot { position: absolute; border-radius: 28px; }
`;

const page = (body, bg = C.bg) =>
  `<!doctype html><html><head><meta charset="utf-8"><style>${css}</style></head><body style="background:${bg}">${body}</body></html>`;

const brand = (color = C.ink) => `<div class="brand" style="color:${color}"><img src="${icon}">WordCat</div>`;

/** A phone, its top edge at y; a tall one runs off the bottom of the page. */
const phone = (screen, { y = 900, w = 680, x = (W - w) / 2 } = {}) => {
  const r = Math.round(w * 0.127);
  const pad = Math.round(w * 0.024);
  return `<div class="phone" style="left:${x}px;top:${y}px;width:${w}px;padding:${pad}px;border-radius:${r}px">
    <img src="${screen}" style="border-radius:${r - pad}px"></div>`;
};

/** Where an Instagram sticker goes; outlined in the drafts only. */
const slot = (x, y, w, h, label, color) => clean ? '' :
  `<div class="slot" style="left:${x}px;top:${y}px;width:${w}px;height:${h}px;border:3px dashed ${color};
    display:flex;align-items:center;justify-content:center;font:600 24px Inter;letter-spacing:2px;color:${color}">${label}</div>`;

function overview() {
  const c = COPY.overview;
  const w = 300;
  const gap = 30;
  const x0 = (W - 3 * w - 2 * gap) / 2;
  const top = 860;
  return page(`
    ${brand()}
    <div class="copy"><h1>${c.title}</h1><p class="text">${c.text}</p></div>
    ${SCREENS.overview.map((name, i) => `
      ${phone(shot(name), { x: x0 + i * (w + gap), y: top, w })}
      <div class="abs" style="left:${x0 + i * (w + gap)}px;top:${top + Math.round(w * 2.2) + 36}px;width:${w}px;text-align:center;font:700 34px Inter">
        <span style="color:${C.accent}">${i + 1}</span>&nbsp; ${c.labels[i]}</div>`).join('')}
  `, C.bg);
}

function feature(key) {
  const c = COPY[key];
  return page(`
    ${brand()}
    <div class="copy"><h1>${c.title}</h1><p class="text">${c.text}</p>
      ${c.note ? `<p style="margin-top:18px;font:600 28px Inter;color:${C.accent}">${c.note}</p>` : ''}</div>
    ${phone(shot(SCREENS[key]), { y: c.note ? 960 : 910 })}
  `, C.bg);
}

function launch() {
  const c = COPY.launch;
  const line = 'rgba(255,244,228,.75)';
  return page(`
    ${brand(C.cream)}
    <div class="abs" style="left:72px;right:72px;top:420px;color:${C.cream}">
      <p style="font:700 52px Inter;letter-spacing:-1px">${c.kicker}</p>
      <p style="font:800 260px/1 Inter;letter-spacing:-10px;margin-top:20px">${c.date}</p>
      <p style="font:500 40px/1.35 Inter;margin-top:36px;opacity:.9">${c.text}</p>
    </div>
    ${slot(72, 1060, 936, 190, 'COUNTDOWN STICKER', line)}
    <p class="abs" style="left:72px;top:1330px;font:700 44px Inter;color:${C.cream}">${c.follow}</p>
    ${slot(72, 1410, 520, 120, 'MENTION STICKER', line)}
  `, C.accent);
}

fs.mkdirSync(OUT, { recursive: true });
const browser = await chromium.launch(process.env.CHROMIUM_PATH ? { executablePath: process.env.CHROMIUM_PATH } : {});
try {
  const tab = await browser.newPage({ viewport: { width: W, height: H }, deviceScaleFactor: 1 });
  const pages = [['1-overview', overview], ['2-flashcards', () => feature('study')], ['3-quizzes', () => feature('quiz')],
    ['4-speaking', () => feature('speaking')], ['5-launch', launch]];
  for (const [name, draw] of pages) {
    await tab.setContent(draw(), { waitUntil: 'networkidle' });
    await tab.evaluate(() => document.fonts.ready);
    const target = path.join(OUT, `${name}${clean ? '' : '-draft'}.png`);
    await tab.screenshot({ path: target, type: 'png' });
    console.log(`Wrote ${target}`);
  }
} finally {
  await browser.close();
}
