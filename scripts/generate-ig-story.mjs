// Draws three Instagram story frames (1080 × 1920) for a partner shout-out:
//   1. what WordCat does, with real screens from the native UI tests,
//   2. a shout-out to the partner's account,
//   3. the App Store release date.
// Same paper desk, cat and terracotta card as the Premium promo art. The
// screens come from the `native-screenshots` branch (pushed by ios-native.yml),
// English interface learning Taiwan Mandarin. Top and bottom ~260 px are left
// for Instagram's own bars; dashed boxes mark where the stickers go (the
// mention and countdown stickers have to be added in Instagram to be tappable).
//
//   git fetch origin native-screenshots
//   node scripts/generate-ig-story.mjs --handle=@name --month=NOV --day=20 --weekday=THURSDAY
//   node scripts/generate-ig-story.mjs ... --clean   # without the sticker guides
import fs from 'node:fs';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { chromium } from 'playwright';
import { kitten } from './lib/mascot-svg.mjs';

const W = 1080;
const H = 1920;
const OUT = 'exports/ig-story';
const SHOTS = 'origin/native-screenshots:native-screenshots-334-ios-26';
const FRAUNCES = 'https://cdn.jsdelivr.net/npm/@fontsource/fraunces@5.0.0/files';
const INTER = 'https://cdn.jsdelivr.net/npm/@fontsource/inter@5.0.0/files';

const arg = (name, fallback) => {
  const hit = process.argv.find((a) => a.startsWith(`--${name}=`));
  return hit ? hit.slice(name.length + 3) : fallback;
};
const opts = {
  handle: arg('handle', '@your.handle'),
  month: arg('month', 'NOV'),
  day: arg('day', '??'),
  weekday: arg('weekday', 'RELEASE DAY'),
  clean: process.argv.includes('--clean'),
};

const palette = {
  furTop: '#FAC48F', furBottom: '#E38A57', shade: '#944929', stripe: '#C26638',
  cream: '#FFF2DB', innerEar: '#FAB3A8', nose: '#ED8585', ink: '#2B1A12', blush: '#F28073',
};

const shot = (name) =>
  `data:image/png;base64,${execFileSync('git', ['show', `${SHOTS}/${name}.png`], { maxBuffer: 64 << 20 }).toString('base64')}`;

const esc = (s) => s.replace(/&/g, '&amp;').replace(/</g, '&lt;');

function catSvg(size, { paws = true } = {}) {
  return `<svg width="${size}" height="${size}" viewBox="0 0 ${size} ${size}" style="overflow:visible">
    <defs><linearGradient id="fur" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="${palette.furTop}"/><stop offset="1" stop-color="${palette.furBottom}"/></linearGradient></defs>
    ${kitten(size, 0, 0, palette, { paws })}</svg>`;
}

const css = `
  @font-face { font-family: Fraunces; font-weight: 700; src: url(${FRAUNCES}/fraunces-latin-700-normal.woff2) format('woff2'); }
  @font-face { font-family: Fraunces; font-weight: 600; font-style: italic; src: url(${FRAUNCES}/fraunces-latin-600-italic.woff2) format('woff2'); }
  @font-face { font-family: Fraunces; font-weight: 500; src: url(${FRAUNCES}/fraunces-latin-500-normal.woff2) format('woff2'); }
  @font-face { font-family: Inter; font-weight: 500; src: url(${INTER}/inter-latin-500-normal.woff2) format('woff2'); }
  @font-face { font-family: Inter; font-weight: 700; src: url(${INTER}/inter-latin-700-normal.woff2) format('woff2'); }
  * { box-sizing: border-box; }
  html, body { margin: 0; width: ${W}px; height: ${H}px; overflow: hidden; }
  body { position: relative; font-family: Inter, sans-serif; color: #2B1A12;
    background:
      radial-gradient(ellipse at 50% 42%, #FCF8F1 0%, #F1E8D9 62%, #DCCBB0 100%); }
  body::before { content: ''; position: absolute; inset: 0;
    background-image: linear-gradient(#D6D9CC 2px, transparent 2px), linear-gradient(90deg, #D6D9CC 2px, transparent 2px);
    background-size: 54px 54px; opacity: 0.5; }
  .abs { position: absolute; }
  .kicker { font-family: Fraunces; font-weight: 500; font-size: 30px; letter-spacing: 10px; color: #A4442A; }
  .h1 { font-family: Fraunces; font-weight: 700; font-size: 96px; line-height: 1.02; letter-spacing: -1px; color: #2B1A12; }
  .h1 em { font-weight: 600; font-style: italic; color: #C9623F; }
  .phone { position: absolute; border-radius: 64px; padding: 12px; background: #1E1410;
    box-shadow: 0 30px 60px rgba(58,26,8,.30), 0 4px 8px rgba(58,26,8,.25); }
  .phone img { display: block; width: 100%; border-radius: 52px; }
  .tape { position: absolute; width: 150px; height: 44px; background: rgba(239,227,198,.92);
    box-shadow: 0 2px 4px rgba(58,36,16,.18); }
  .bubble { position: absolute; background: #FFFBF4; border-radius: 34px; padding: 22px 30px;
    font-family: Fraunces; font-weight: 600; font-style: italic; font-size: 40px; color: #2B1A12;
    box-shadow: 0 10px 24px rgba(58,36,16,.18); }
  .note { position: absolute; background: #FBF8F2; padding: 26px 26px 24px; width: 300px;
    box-shadow: 0 10px 22px rgba(58,36,16,.16); }
  .note b { display: block; font-family: Fraunces; font-weight: 700; font-size: 38px; line-height: 1.05; margin-bottom: 8px; }
  .note span { font-size: 25px; line-height: 1.3; color: #6B4A36; font-weight: 500; }
  .note .num { position: absolute; top: -22px; left: 22px; width: 46px; height: 46px; border-radius: 23px;
    background: #C9623F; color: #FFF2DB; font: 700 26px/46px Inter; text-align: center; }
  .card { position: absolute; border-radius: 48px; background: linear-gradient(135deg, #E2875D 0%, #C9623F 55%, #A4442A 100%);
    box-shadow: 0 18px 44px rgba(58,26,8,.34), 0 3px 6px rgba(58,26,8,.25); color: #FFF1DA; }
  .card::after { content: ''; position: absolute; inset: 16px; border-radius: 34px; border: 2px solid rgba(255,233,204,.38); }
  .foot { font-family: Inter; font-weight: 700; font-size: 32px; letter-spacing: 1px; color: #6B4A36; text-align: center; }
  .guide { position: absolute; border: 4px dashed rgba(164,68,42,.55); border-radius: 30px;
    display: flex; align-items: center; justify-content: center; text-align: center;
    font: 700 28px Inter; color: rgba(164,68,42,.7); letter-spacing: 1px; }
`;

const page = (body) => `<!doctype html><html><head><meta charset="utf-8"><style>${css}</style></head><body>${body}</body></html>`;
const guide = (x, y, w, h, label) => (opts.clean ? '' : `<div class="guide" style="left:${x}px;top:${y}px;width:${w}px;height:${h}px">${label}</div>`);

// 1. What WordCat does.
function frameApp() {
  const pw = 320;
  return page(`
    <div class="abs kicker" style="left:90px;top:270px">WORDCAT · TAIWAN MANDARIN</div>
    <div class="abs h1" style="left:86px;top:320px;width:920px">Learn Mandarin<br><em>with a judgy cat.</em></div>

    <div class="phone" style="width:${pw}px;left:70px;top:650px;transform:rotate(-7deg)"><img src="${shot('zh-2-study')}"></div>
    <div class="phone" style="width:${pw}px;right:70px;top:650px;transform:rotate(7deg)"><img src="${shot('zh-4-speaking')}"></div>
    <div class="phone" style="width:${pw + 40}px;left:${(W - pw - 40) / 2}px;top:610px;z-index:2"><img src="${shot('zh-1-today')}"></div>
    <div class="abs" style="left:610px;top:500px;z-index:3">${catSvg(150)}</div>
    <div class="bubble" style="left:740px;top:560px;z-index:3;transform:rotate(4deg)">“Only 7? LOL.”</div>

    <div class="note" style="left:60px;top:1420px;transform:rotate(-2deg)"><div class="num">1</div><b>Flashcards</b><span>pinyin + Taiwan readings</span></div>
    <div class="note" style="left:390px;top:1412px;transform:rotate(1.5deg)"><div class="num">2</div><b>Speaking</b><span>answer out loud, in Chinese</span></div>
    <div class="note" style="left:720px;top:1424px;transform:rotate(-1deg)"><div class="num">3</div><b>Quizzes</b><span>+ a cat that never forgets</span></div>
    <div class="abs foot" style="left:0;width:${W}px;top:1620px">FREE TO STUDY · NO ADS · iPHONE</div>
  `);
}

// 2. Shout-out.
function frameShout() {
  const handle = esc(opts.handle);
  const fs = handle.length > 16 ? 76 : 96;
  return page(`
    <div class="abs kicker" style="left:0;width:${W}px;text-align:center;top:290px">A LITTLE COLLAB</div>
    <div class="abs h1" style="left:0;width:${W}px;text-align:center;top:350px">WordCat <em>×</em></div>

    <div class="abs" style="left:${W / 2 - 210}px;top:500px">${catSvg(420, { paws: false })}</div>
    <div class="card" style="left:110px;top:800px;width:860px;height:400px;transform:rotate(-2.5deg)">
      <div class="abs" style="left:64px;top:70px;font:500 28px Fraunces;letter-spacing:9px;opacity:.85">SAY HI TO</div>
      <div class="abs" style="left:60px;top:150px;width:740px;font-family:Fraunces;font-weight:600;font-style:italic;font-size:${fs}px;line-height:1.1;color:#FFE9C4;word-break:break-all">${handle}</div>
    </div>
    <div class="tape" style="left:70px;top:800px;transform:rotate(-38deg)"></div>
    <div class="tape" style="left:870px;top:770px;transform:rotate(32deg)"></div>
    <div class="abs" style="left:${W / 2 - 112}px;top:788px;display:flex;gap:90px;transform:rotate(-2.5deg)">
      <div style="width:66px;height:40px;border-radius:50%;background:#FFF2DB"></div>
      <div style="width:66px;height:40px;border-radius:50%;background:#FFF2DB"></div>
    </div>
    <div class="bubble" style="left:640px;top:520px;transform:rotate(4deg)">“Fine. They’re cool.”</div>

    ${guide(240, 1300, 600, 150, 'MENTION STICKER')}
    <div class="abs foot" style="left:0;width:${W}px;top:1520px">Go follow them. The cat insists.</div>
  `);
}

// 3. Release date.
function frameDate() {
  return page(`
    <div class="abs kicker" style="left:0;width:${W}px;text-align:center;top:290px">MARK YOUR CALENDAR</div>
    <div class="abs h1" style="left:0;width:${W}px;text-align:center;top:350px;font-size:88px">WordCat lands on<br><em>the App Store</em></div>

    <div class="abs" style="left:240px;top:640px;width:600px;height:620px;transform:rotate(2deg);
      background:#FBF8F2;border-radius:40px;box-shadow:0 24px 50px rgba(58,26,8,.25);overflow:hidden">
      <div style="height:170px;background:linear-gradient(135deg,#E2875D,#A4442A);color:#FFF1DA;
        font:700 96px/170px Fraunces;letter-spacing:14px;text-align:center">${esc(opts.month)}</div>
      <div style="font:700 300px/1 Fraunces;text-align:center;margin-top:40px;color:#2B1A12">${esc(opts.day)}</div>
      <div style="font:700 32px Inter;letter-spacing:6px;text-align:center;margin-top:24px;color:#A4442A">${esc(opts.weekday)}</div>
    </div>
    <div class="tape" style="left:230px;top:620px;transform:rotate(-30deg)"></div>
    <div class="abs" style="left:700px;top:500px">${catSvg(230)}</div>
    <div class="bubble" style="left:80px;top:560px;transform:rotate(-4deg)">“Don’t be late.”</div>

    ${guide(240, 1320, 600, 190, 'COUNTDOWN STICKER')}
    <div class="abs foot" style="left:0;width:${W}px;top:1560px">Search “WordCat” · Free on iPhone</div>
  `);
}

fs.mkdirSync(OUT, { recursive: true });
const browser = await chromium.launch(process.env.CHROMIUM_PATH ? { executablePath: process.env.CHROMIUM_PATH } : {});
try {
  const tab = await browser.newPage({ viewport: { width: W, height: H }, deviceScaleFactor: 1 });
  const frames = [['1-what-it-does', frameApp], ['2-shout-out', frameShout], ['3-release-date', frameDate]];
  for (const [name, draw] of frames) {
    await tab.setContent(draw(), { waitUntil: 'networkidle' });
    await tab.evaluate(() => document.fonts.ready);
    const target = path.join(OUT, `${name}${opts.clean ? '' : '-draft'}.png`);
    await tab.screenshot({ path: target, type: 'png' });
    console.log(`Wrote ${target}`);
  }
} finally {
  await browser.close();
}
