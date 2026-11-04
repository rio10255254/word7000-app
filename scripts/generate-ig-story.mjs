// Draws four Instagram story frames (1080 × 1920) for WordCat's launch:
//   1. what WordCat does, with real screens from the native UI tests,
//   2. the AI tutor: a speaking question from the app and the coach's three-part reply,
//   3. a shout-out to WordCat's own Instagram account,
//   4. the App Store release date.
// Same paper desk, cat and terracotta card as the Premium promo art. The
// screens come from the `native-screenshots` branch (pushed by ios-native.yml),
// English interface learning Taiwan Mandarin. Top ~250 px and bottom ~270 px
// are left for Instagram's own bars; dashed boxes mark where the stickers go
// (mention and countdown stickers must be added in Instagram to be tappable).
//
//   git fetch origin native-screenshots
//   node scripts/generate-ig-story.mjs --month=NOV --day=16 --weekday=MONDAY [--handle=@wordcat.app]
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
const FS = 'https://cdn.jsdelivr.net/npm/@fontsource';

const arg = (name, fallback) => {
  const hit = process.argv.find((a) => a.startsWith(`--${name}=`));
  return hit ? hit.slice(name.length + 3) : fallback;
};
const opts = {
  handle: arg('handle', '@wordcat.app'),
  month: arg('month', 'NOV'),
  day: arg('day', '??'),
  weekday: arg('weekday', 'RELEASE DAY'),
  clean: process.argv.includes('--clean'),
};

const palette = {
  furTop: '#FAC48F', furBottom: '#E38A57', shade: '#944929', stripe: '#C26638',
  cream: '#FFF2DB', innerEar: '#FAB3A8', nose: '#ED8585', ink: '#2B1A12', blush: '#F28073',
};
const C = { ink: '#2B1A12', brown: '#6B4A36', terra: '#C9623F', deep: '#A4442A', paper: '#FBF8F2', cream: '#FFF1DA' };

const esc = (s) => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;');
const shot = (name) =>
  `data:image/png;base64,${execFileSync('git', ['show', `${SHOTS}/${name}.png`], { maxBuffer: 64 << 20 }).toString('base64')}`;

// A seeded wobble, so torn edges look the same on every run.
let seed = 7;
const rand = () => ((seed = (seed * 16807) % 2147483647) / 2147483647);

// ---------------------------------------------------------------- pieces

function cat(size, { x, y, z = 3, paws = true }) {
  return `<svg class="abs" style="left:${x}px;top:${y}px;z-index:${z};overflow:visible;filter:drop-shadow(0 10px 14px rgba(42,20,8,.28))"
    width="${size}" height="${size}" viewBox="0 0 ${size} ${size}">
    <defs><linearGradient id="fur${size}" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="${palette.furTop}"/><stop offset="1" stop-color="${palette.furBottom}"/></linearGradient></defs>
    ${kitten(size, 0, 0, palette, { paws }).replaceAll('url(#fur)', `url(#fur${size})`)}</svg>`;
}

function sparkle(x, y, r, fill = C.terra, z = 4) {
  const k = r * 0.16;
  return `<svg class="abs" style="left:${x - r}px;top:${y - r}px;z-index:${z}" width="${2 * r}" height="${2 * r}" viewBox="${-r} ${-r} ${2 * r} ${2 * r}">
    <path d="M0,${-r} Q${k},${-k} ${r},0 Q${k},${k} 0,${r} Q${-k},${k} ${-r},0 Q${-k},${-k} 0,${-r}Z" fill="${fill}"/></svg>`;
}

/** Masking tape with torn ends. */
function tape(x, y, w, rot, { h = 46, color = 'rgba(239,227,198,.9)', z = 5 } = {}) {
  const teeth = (right) => Array.from({ length: 7 }, (_, i) => `${right ? 100 - (i % 2 ? 4 : 0) : i % 2 ? 4 : 0}% ${(i / 6) * 100}%`);
  return `<div class="abs" style="left:${x}px;top:${y}px;width:${w}px;height:${h}px;z-index:${z};transform:rotate(${rot}deg);
    background:linear-gradient(180deg,rgba(255,255,255,.35),rgba(255,255,255,0) 60%),${color};
    clip-path:polygon(${[...teeth(false), ...teeth(true).reverse()].join(',')});filter:drop-shadow(0 2px 2px rgba(58,36,16,.18))"></div>`;
}

/** A clip-path for paper with a torn bottom edge. */
function tornBottom(steps = 18) {
  const pts = ['0 0', '100% 0'];
  for (let i = steps; i >= 0; i -= 1) pts.push(`${(i / steps) * 100}% calc(100% - ${Math.round(rand() * 10)}px)`);
  return `polygon(${pts.join(',')})`;
}

function note({ x, y, w, rot, num, title, text, z = 4 }) {
  return `<div class="abs" style="left:${x}px;top:${y}px;width:${w}px;z-index:${z};transform:rotate(${rot}deg);filter:drop-shadow(0 10px 14px rgba(58,36,16,.18))">
    <div style="background:${C.paper};padding:30px 28px 34px;clip-path:${tornBottom()};position:relative">
      <div class="lines"></div>
      <div style="position:relative">
        <div style="display:flex;align-items:center;gap:12px;margin-bottom:8px">
          ${num ? `<span class="num">${num}</span>` : ''}<b class="ntitle">${title}</b>
        </div>
        <span class="ntext">${text}</span>
      </div>
    </div>
  </div>`;
}

/** A rubber stamp: two rings and text, inked unevenly. */
function stamp({ x, y, r, rot, top, big, bottom = '', color = C.deep, z = 6 }) {
  const id = `ink${Math.round(rand() * 1e6)}`;
  return `<svg class="abs" style="left:${x - r}px;top:${y - r}px;z-index:${z};transform:rotate(${rot}deg)" width="${2 * r}" height="${2 * r}" viewBox="0 0 ${2 * r} ${2 * r}">
    <defs>
      <filter id="${id}" x="-10%" y="-10%" width="120%" height="120%">
        <feTurbulence type="fractalNoise" baseFrequency="1.4" numOctaves="1" seed="${Math.round(rand() * 50)}" result="n"/>
        <feColorMatrix in="n" type="matrix" values="0 0 0 0 0  0 0 0 0 0  0 0 0 0 0  0 0 0 -1 1.25" result="speckle"/>
        <feComposite in="SourceGraphic" in2="speckle" operator="in"/>
      </filter>
      <path id="${id}t" d="M ${r * 0.3},${r} A ${r * 0.7},${r * 0.7} 0 0 1 ${r * 1.7},${r}"/>
      <path id="${id}b" d="M ${r * 0.2},${r} A ${r * 0.8},${r * 0.8} 0 0 0 ${r * 1.8},${r}"/>
    </defs>
    <circle cx="${r}" cy="${r}" r="${r - 4}" fill="rgba(251,246,236,.8)"/>
    <g filter="url(#${id})" fill="${color}" stroke="${color}">
      <circle cx="${r}" cy="${r}" r="${r - 10}" fill="none" stroke-width="6"/>
      <circle cx="${r}" cy="${r}" r="${r * 0.6}" fill="none" stroke-width="2.5"/>
      <text font-family="Inter" font-weight="700" font-size="${r * 0.16}" letter-spacing="${r * 0.03}" stroke="none"><textPath href="#${id}t" startOffset="50%" text-anchor="middle">${top}</textPath></text>
      <text font-family="Inter" font-weight="700" font-size="${r * 0.16}" letter-spacing="${r * 0.03}" stroke="none"><textPath href="#${id}b" startOffset="50%" text-anchor="middle">${bottom}</textPath></text>
      <text x="${r}" y="${r + r * 0.17}" text-anchor="middle" font-family="Fraunces" font-weight="900" font-size="${r * 0.48}" stroke="none">${big}</text>
    </g>
  </svg>`;
}

/** An iPhone: titanium edge, side buttons, a faint glare across the glass. */
function phone(img, { x, y, w, rot = 0, z = 2 }) {
  const r = w * 0.155;
  const b = w * 0.028;
  return `<div class="abs" style="left:${x}px;top:${y}px;width:${w}px;z-index:${z};transform:rotate(${rot}deg)">
    <div class="btn" style="left:-5px;top:${w * 0.42}px;height:${w * 0.12}px"></div>
    <div class="btn" style="left:-5px;top:${w * 0.58}px;height:${w * 0.12}px"></div>
    <div class="btn" style="right:-5px;top:${w * 0.5}px;height:${w * 0.2}px"></div>
    <div style="position:relative;border-radius:${r}px;padding:${b}px;
      background:linear-gradient(140deg,#6d5a50 0%,#2a1f1a 18%,#17100c 50%,#3b2d26 82%,#7a675c 100%);
      box-shadow:0 34px 60px rgba(58,26,8,.32),0 6px 10px rgba(58,26,8,.25),inset 0 0 0 1.5px rgba(255,255,255,.12)">
      <img src="${img}" style="display:block;width:100%;border-radius:${r - b}px">
      <div style="position:absolute;inset:${b}px;border-radius:${r - b}px;
        background:linear-gradient(115deg,rgba(255,255,255,.16) 0%,rgba(255,255,255,0) 32%)"></div>
    </div>
  </div>`;
}

/** A hand-drawn arrow from (x1,y1) to (x2,y2), bowed sideways by `bend`. */
function arrow(x1, y1, x2, y2, bend = 40, color = C.deep, z = 7) {
  const minX = Math.min(x1, x2) - 60;
  const minY = Math.min(y1, y2) - 60;
  const [ax, ay, bx, by] = [x1 - minX, y1 - minY, x2 - minX, y2 - minY];
  const len = Math.hypot(bx - ax, by - ay);
  const mx = (ax + bx) / 2 - ((by - ay) / len) * bend;
  const my = (ay + by) / 2 + ((bx - ax) / len) * bend;
  const ang = Math.atan2(by - my, bx - mx);
  const head = (d) => `${bx - 22 * Math.cos(ang + d)},${by - 22 * Math.sin(ang + d)}`;
  return `<svg class="abs" style="left:${minX}px;top:${minY}px;z-index:${z};overflow:visible" width="${Math.abs(x2 - x1) + 120}" height="${Math.abs(y2 - y1) + 120}">
    <path d="M${ax},${ay} Q${mx},${my} ${bx},${by}" fill="none" stroke="${color}" stroke-width="4.5" stroke-linecap="round"/>
    <path d="M${head(0.5)} L${bx},${by} L${head(-0.5)}" fill="none" stroke="${color}" stroke-width="4.5" stroke-linecap="round" stroke-linejoin="round"/>
  </svg>`;
}

const hand = (y, text, { size = 46, rot = -2, color = C.brown } = {}) =>
  `<div class="abs hand" style="left:0;width:${W}px;text-align:center;top:${y}px;font-size:${size}px;color:${color};z-index:7;transform:rotate(${rot}deg)">${text}</div>`;

const bubble = (x, y, text, rot = 3, z = 6) =>
  `<div class="abs bubble" style="left:${x}px;top:${y}px;z-index:${z};transform:rotate(${rot}deg)">${text}</div>`;

const guide = (x, y, w, h, label) =>
  opts.clean ? '' : `<div class="guide" style="left:${x}px;top:${y}px;width:${w}px;height:${h}px">${label}</div>`;

const kicker = (text, center) =>
  `<div class="abs kicker" style="${center ? `left:0;width:${W}px;text-align:center` : 'left:90px'};top:262px">${text}</div>`;

// ---------------------------------------------------------------- page

const grain = `url("data:image/svg+xml,${encodeURIComponent(
  `<svg xmlns='http://www.w3.org/2000/svg' width='360' height='360'><filter id='g'><feTurbulence type='fractalNoise' baseFrequency='.85' numOctaves='2' stitchTiles='stitch'/><feColorMatrix type='saturate' values='0'/></filter><rect width='100%' height='100%' filter='url(#g)' opacity='.55'/></svg>`,
)}")`;

const css = `
  @font-face { font-family: Fraunces; font-weight: 900; src: url(${FS}/fraunces@5.0.0/files/fraunces-latin-900-normal.woff2) format('woff2'); }
  @font-face { font-family: Fraunces; font-weight: 700; src: url(${FS}/fraunces@5.0.0/files/fraunces-latin-700-normal.woff2) format('woff2'); }
  @font-face { font-family: Fraunces; font-weight: 600; font-style: italic; src: url(${FS}/fraunces@5.0.0/files/fraunces-latin-600-italic.woff2) format('woff2'); }
  @font-face { font-family: Inter; font-weight: 500; src: url(${FS}/inter@5.0.0/files/inter-latin-500-normal.woff2) format('woff2'); }
  @font-face { font-family: Inter; font-weight: 500; src: url(${FS}/inter@5.0.0/files/inter-latin-ext-500-normal.woff2) format('woff2'); unicode-range: U+0100-024F, U+1E00-1EFF; }
  @font-face { font-family: Inter; font-weight: 600; src: url(${FS}/inter@5.0.0/files/inter-latin-600-normal.woff2) format('woff2'); }
  @font-face { font-family: Inter; font-weight: 700; src: url(${FS}/inter@5.0.0/files/inter-latin-700-normal.woff2) format('woff2'); }
  @font-face { font-family: Caveat; font-weight: 700; src: url(${FS}/caveat@5.0.0/files/caveat-latin-700-normal.woff2) format('woff2'); }
  * { box-sizing: border-box; }
  html, body { margin: 0; width: ${W}px; height: ${H}px; overflow: hidden; }
  body { position: relative; font-family: Inter, sans-serif; color: ${C.ink};
    background: radial-gradient(ellipse 85% 60% at 50% 45%, #FDF9F2 0%, #F3EADB 60%, #DCCAAE 100%); }
  body::before { content: ''; position: absolute; inset: 0; z-index: 0;
    background-image: linear-gradient(rgba(170,180,160,.28) 2px, transparent 2px), linear-gradient(90deg, rgba(170,180,160,.28) 2px, transparent 2px);
    background-size: 54px 54px; background-position: -2px 10px; }
  body::after { content: ''; position: absolute; inset: 0; z-index: 50; pointer-events: none;
    background: ${grain}; mix-blend-mode: multiply; opacity: .16; }
  .abs { position: absolute; }
  .kicker { font-family: Inter; font-weight: 700; font-size: 26px; letter-spacing: 9px; color: ${C.deep}; z-index: 5; }
  .h1 { font-family: Fraunces; font-weight: 900; font-size: 104px; line-height: .98; letter-spacing: -2px; color: ${C.ink}; z-index: 5; }
  .h1 em { font-weight: 600; font-style: italic; letter-spacing: -1px; color: ${C.terra}; }
  .hand { font-family: Caveat; font-weight: 700; line-height: 1; white-space: nowrap; }
  .btn { position: absolute; width: 8px; border-radius: 4px; background: linear-gradient(90deg,#2a1f1a,#6d5a50); }
  .bubble { background: #FFFBF4; border-radius: 30px; padding: 18px 28px 20px;
    font-family: Fraunces; font-weight: 600; font-style: italic; font-size: 38px; white-space: nowrap; color: ${C.ink};
    box-shadow: 0 12px 26px rgba(58,36,16,.2), 0 2px 4px rgba(58,36,16,.12); }
  .bubble::after { content: ''; position: absolute; left: 34px; bottom: -12px; width: 26px; height: 26px; background: #FFFBF4; transform: rotate(45deg); border-radius: 4px; }
  .lines { position: absolute; inset: 0; background: repeating-linear-gradient(transparent 0 43px, rgba(150,180,205,.35) 43px 45px); background-position: 0 22px; }
  .num { display: inline-block; flex: none; width: 44px; height: 44px; border-radius: 22px; background: ${C.terra}; color: ${C.cream}; font: 700 24px/44px Inter; text-align: center; }
  .ntitle { font-family: Fraunces; font-weight: 700; font-size: 38px; line-height: 1.05; }
  .ntext { display: block; font-size: 25px; line-height: 1.35; color: ${C.brown}; font-weight: 500; }
  .card { position: absolute; border-radius: 48px; overflow: hidden; color: ${C.cream};
    background: linear-gradient(135deg, #E2875D 0%, #C9623F 55%, #A4442A 100%);
    box-shadow: 0 22px 48px rgba(58,26,8,.34), 0 3px 6px rgba(58,26,8,.25); }
  .card::before { content: ''; position: absolute; inset: 0; background: linear-gradient(135deg, rgba(255,255,255,.28) 0%, rgba(255,255,255,.04) 38%, transparent 39%); }
  .card::after { content: ''; position: absolute; inset: 16px; border-radius: 34px; border: 2px solid rgba(255,233,204,.4); }
  .dots { position: absolute; right: 0; top: 0; width: 320px; height: 220px;
    background: radial-gradient(circle, rgba(255,242,219,.35) 2.4px, transparent 3px) 0 0/20px 20px;
    -webkit-mask: radial-gradient(circle at 100% 0, #000 0, transparent 75%); }
  .chip { display: inline-flex; align-items: center; padding: 14px 22px; border-radius: 40px; background: rgba(251,248,242,.95);
    font: 600 26px Inter; color: ${C.ink}; box-shadow: 0 6px 14px rgba(58,36,16,.12); }
  .chip b { color: ${C.terra}; margin-right: 10px; }
  .zh { font-family: 'Noto Sans TC', sans-serif; }
  .qcard { z-index: 4; background: #FBF8F2; border-radius: 28px; padding: 30px 36px 32px; box-shadow: 0 14px 30px rgba(58,36,16,.16); }
  .said { z-index: 4; background: #FFFDF8; border-radius: 34px 34px 8px 34px; padding: 24px 32px 28px; box-shadow: 0 12px 26px rgba(58,36,16,.16); transform: rotate(1deg); }
  .reply { position: relative; border-radius: 26px; padding: 22px 30px 26px 30px; box-shadow: 0 10px 22px rgba(58,36,16,.14); }
  .rnum { position: absolute; left: -20px; top: 20px; width: 40px; height: 40px; border-radius: 20px; background: #C9623F; color: #FFF1DA; font: 700 22px/40px Inter; text-align: center; box-shadow: 0 3px 6px rgba(58,36,16,.2); }
  .clabel { font: 700 21px Inter; letter-spacing: 3px; margin-bottom: 10px; }
  .cpy { font: 500 24px Inter; color: #7A5A46; margin-top: 8px; }
  .cen { font: 500 24px Inter; color: #9A8070; margin-top: 4px; }
  .oops { text-decoration: underline wavy #D0452B; text-decoration-thickness: 3px; text-underline-offset: 8px; }
  .good { background: linear-gradient(transparent 58%, rgba(120,160,95,.45) 58%); }
  .guide { position: absolute; z-index: 8; border: 4px dashed rgba(164,68,42,.55); border-radius: 30px;
    display: flex; align-items: center; justify-content: center; text-align: center;
    font: 700 26px Inter; color: rgba(164,68,42,.75); letter-spacing: 2px; background: rgba(255,250,240,.35); }
`;

// Only the Chinese characters a frame uses are fetched from Noto Sans TC.
const page = (body) => {
  const han = [...new Set(body.replace(/<[^>]*>/g, '').match(/[\u3000-\u303f\u4e00-\u9fff\uff00-\uffef]/g) ?? [])].join('');
  const cjk = han ? `<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Noto+Sans+TC:wght@500;700&text=${encodeURIComponent(han)}">` : '';
  return `<!doctype html><html><head><meta charset="utf-8">${cjk}<style>${css}</style></head><body>${body}</body></html>`;
};

// ---------------------------------------------------------------- frames

// 1. What WordCat does.
function frameApp() {
  return page(`
    ${kicker('WORDCAT · TAIWAN MANDARIN')}
    <div class="abs h1" style="left:84px;top:306px">Learn Mandarin<br><em>with a judgy cat.</em></div>

    ${phone(shot('zh-2-study'), { x: 50, y: 720, w: 320, rot: -8, z: 2 })}
    ${phone(shot('zh-4-speaking'), { x: 710, y: 720, w: 320, rot: 8, z: 2 })}
    ${phone(shot('zh-1-today'), { x: 350, y: 650, w: 380, z: 3 })}
    ${cat(150, { x: 600, y: 540, z: 4 })}
    ${bubble(735, 566, '“Only 7? LOL.”', 4)}
    ${stamp({ x: 150, y: 640, r: 92, rot: -14, top: 'STUDY FOR', big: 'FREE', bottom: 'NO ADS' })}

    ${note({ x: 48, y: 1510, w: 320, rot: -2, num: 1, title: 'Flashcards', text: 'traditional characters + pinyin' })}
    ${note({ x: 382, y: 1500, w: 320, rot: 1.5, num: 2, title: 'Speaking', text: 'answer out loud, in Chinese' })}
    ${note({ x: 716, y: 1512, w: 320, rot: -1.2, num: 3, title: 'AI tutor ✦', text: 'fixes what you say (next →)' })}
    ${tape(150, 1490, 120, -6, { h: 36 })}
    ${tape(490, 1482, 120, 4, { h: 36 })}
    ${tape(820, 1494, 120, -3, { h: 36 })}
  `);
}

// 2. The AI tutor. The question is the app's own speaking question for 貼上;
// the answer and the coach's reply are a sample written to the coach's rules
// (supabase/functions/ai/tasks.ts): a natural rewrite and a follow-up in
// Taiwan Mandarin, one actionable tip in English.
function frameAI() {
  const label = (text, color) => `<div class="clabel" style="color:${color}">${text}</div>`;
  const py = (text) => `<div class="cpy">${text}</div>`;
  const en = (text) => `<div class="cen">${text}</div>`;
  return page(`
    ${kicker('WORDCAT · AI TUTOR')}
    <div class="abs h1" style="left:84px;top:306px">Say it wrong.<br><em>The cat fixes it.</em></div>

    <div class="abs qcard" style="left:60px;top:556px;width:960px;transform:rotate(-1deg)">
      ${label('THE QUESTION · use <span class="zh" style="color:#C9623F">貼上</span> (to paste)', C.deep)}
      <div class="zh" style="font-size:44px;font-weight:700;line-height:1.3">你寫報告的時候，會從網路上找資料嗎？</div>
      ${py('nǐ xiě bào gào de shí hòu, huì cóng wǎng lù shàng zhǎo zī liào ma?')}
      ${en('When you write a report, do you look for information online?')}
    </div>
    ${tape(470, 540, 140, 3, { h: 38 })}

    <div class="abs said" style="right:60px;top:842px;width:760px">
      ${label('YOU SAID', '#8A6A56')}
      <div class="zh" style="font-size:38px;font-weight:500;line-height:1.35">會，我常常從網路上找資料，然後<span class="oops">貼上到</span>我的報告。</div>
    </div>

    ${cat(128, { x: 34, y: 1066, z: 6 })}
    <div class="abs" style="left:196px;top:1056px;width:824px;z-index:5;display:flex;flex-direction:column;gap:16px">
      <div class="reply" style="background:#E4EBD6;transform:rotate(.6deg)">
        <span class="rnum">1</span>${label('MORE NATURAL', '#4F6B45')}
        <div class="zh" style="font-size:38px;font-weight:700;line-height:1.35">會啊，我常常上網找資料，再<span class="good">貼到報告裡</span>。</div>
      </div>
      <div class="reply" style="background:#F2E2AE;transform:rotate(-.5deg)">
        <span class="rnum">2</span>${label('WHAT TO FIX', '#8A6414')}
        <div style="font-size:28px;font-weight:600;line-height:1.38">Almost. <span class="zh">貼上</span> already means “paste,” so <span class="zh">貼上到</span> says it twice. Try <span class="zh">貼到報告裡</span>: paste it into the report.</div>
      </div>
      <div class="reply" style="background:#F5D6C2;transform:rotate(.4deg)">
        <span class="rnum">3</span>${label('FOLLOW-UP', C.deep)}
        <div class="zh" style="font-size:36px;font-weight:700;line-height:1.35">你怎麼確定網路上的資料是對的？</div>
        ${py('nǐ zěn me què dìng wǎng lù shàng de zī liào shì duì de?')}
        ${en('How do you make sure what you find online is right?')}
      </div>
    </div>
    ${sparkle(1006, 1046, 22)}

    ${hand(1612, 'the full AI tutor comes with Premium', { size: 42, rot: -1 })}
  `);
}

// 3. Shout-out.
function frameShout() {
  const handle = esc(opts.handle);
  const size = handle.length > 14 ? Math.max(64, Math.round(1450 / handle.length)) : 104;
  const card = { x: 100, y: 830, w: 880, h: 420 };
  return page(`
    ${kicker('THE CAT HAS AN INSTAGRAM', true)}
    <div class="abs h1" style="left:0;width:${W}px;text-align:center;top:306px">Come <em>hang out.</em></div>
    ${sparkle(150, 350, 22)}${sparkle(950, 330, 14, C.deep)}

    <div class="abs" style="left:0;top:0;width:${W}px;height:${H}px;transform:rotate(-2.5deg);transform-origin:${W / 2}px ${card.y + card.h / 2}px;z-index:3">
      ${cat(440, { x: W / 2 - 220, y: card.y - 300, z: 1, paws: false })}
      <div class="card" style="left:${card.x}px;top:${card.y}px;width:${card.w}px;height:${card.h}px;z-index:2">
        <div class="dots"></div>
        <div class="abs" style="left:66px;top:78px;font:700 26px Inter;letter-spacing:9px;opacity:.85">FOLLOW US</div>
        <div class="abs" style="left:60px;top:150px;width:760px;font-family:Fraunces;font-weight:600;font-style:italic;font-size:${size}px;line-height:1.1;color:#FFE6BD;word-break:break-all">${handle}</div>
        <div class="abs" style="left:66px;bottom:62px;font:600 24px Inter;letter-spacing:3px;opacity:.8">WORDCAT · OFFICIAL</div>
      </div>
      ${[-1, 1].map((s) => `<div class="abs" style="left:${W / 2 + s * 66 - 33}px;top:${card.y - 18}px;width:66px;height:40px;border-radius:50%;background:${palette.cream};z-index:3;box-shadow:0 3px 4px rgba(90,52,24,.25)"></div>`).join('')}
      ${tape(card.x - 40, card.y + 26, 160, -38)}
      ${tape(card.x + card.w - 110, card.y - 14, 150, 32)}
      ${sparkle(card.x + card.w - 150, card.y + 110, 46, '#FFE6BD', 3)}
      ${sparkle(card.x + card.w - 80, card.y + 60, 18, '#FFE6BD', 3)}
    </div>
    ${bubble(640, 540, '“Fine. Follow me.”', 5)}
    ${stamp({ x: 905, y: 1265, r: 92, rot: -12, top: 'WORDCAT', big: '✓', bottom: 'THE REAL ONE', z: 6 })}

    ${guide(240, 1360, 600, 150, 'MENTION STICKER')}
    ${hand(1550, 'new words, cat sass &amp; launch news', { size: 50 })}
  `);
}

// 4. Release date.
function frameDate() {
  const cal = { x: 230, y: 660, w: 620, h: 640 };
  const ring = (dx) => `<div class="abs" style="left:${cal.x + dx}px;top:${cal.y - 26}px;width:26px;height:60px;border-radius:13px;z-index:5;
    background:linear-gradient(90deg,#3b2d26,#8a776b 45%,#2a1f1a);box-shadow:0 3px 4px rgba(0,0,0,.3)"></div>`;
  return page(`
    ${kicker('MARK YOUR CALENDAR', true)}
    <div class="abs h1" style="left:0;width:${W}px;text-align:center;top:306px;font-size:96px">WordCat lands on<br><em>the App Store</em></div>

    <div class="abs" style="left:${cal.x + 18}px;top:${cal.y + 26}px;width:${cal.w}px;height:${cal.h}px;background:#EFE7DA;border-radius:40px;transform:rotate(4deg);z-index:2;box-shadow:0 14px 30px rgba(58,26,8,.18)"></div>
    <div class="abs" style="left:${cal.x}px;top:${cal.y}px;width:${cal.w}px;height:${cal.h}px;z-index:3;transform:rotate(1.5deg);
      background:${C.paper};border-radius:40px;box-shadow:0 26px 52px rgba(58,26,8,.26);overflow:hidden">
      <div style="height:180px;background:linear-gradient(135deg,#E2875D,#A4442A);color:${C.cream};
        font:900 104px/190px Fraunces;letter-spacing:16px;text-align:center;position:relative">${esc(opts.month)}
        <div class="dots" style="width:260px;height:180px"></div></div>
      <div style="font:900 330px/1 Fraunces;text-align:center;margin-top:26px;color:${C.ink};letter-spacing:-8px">${esc(opts.day)}</div>
      <div style="font:700 30px Inter;letter-spacing:8px;text-align:center;margin-top:18px;color:${C.deep}">${esc(opts.weekday)}</div>
    </div>
    ${ring(150)}${ring(cal.w - 176)}
    ${cat(220, { x: 700, y: 520, z: 6 })}
    ${bubble(90, 560, '“Don’t be late.”', -4)}
    ${stamp({ x: 250, y: 1270, r: 96, rot: -16, top: 'FREE ON IPHONE', big: 'NEW', bottom: 'WORDCAT', z: 6 })}

    ${guide(240, 1380, 600, 170, 'COUNTDOWN STICKER')}
    ${hand(1572, 'search “WordCat” on the App Store', { size: 46, rot: -1.5 })}
    ${hand(1622, 'tap the countdown so the cat can remind you', { size: 38, rot: -1.5, color: C.deep })}
  `);
}

fs.mkdirSync(OUT, { recursive: true });
const browser = await chromium.launch(process.env.CHROMIUM_PATH ? { executablePath: process.env.CHROMIUM_PATH } : {});
try {
  const tab = await browser.newPage({ viewport: { width: W, height: H }, deviceScaleFactor: 1 });
  const frames = [['1-what-it-does', frameApp], ['2-ai-tutor', frameAI], ['3-shout-out', frameShout], ['4-release-date', frameDate]];
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
