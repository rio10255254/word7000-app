import { ThreeCanvas } from '@remotion/three';
import { useThree } from '@react-three/fiber';
import type { CSSProperties, ReactNode } from 'react';
import { AbsoluteFill, Html5Audio, Img, staticFile, useCurrentFrame } from 'remotion';
import * as THREE from 'three';
import { FONT, HAND, HAND_TC, SERIF, SERIF_TC } from '../fonts';
import script from './episodes.json';
import timings from './timing.json';
import { REEL_FPS } from './Reel';
import { Grain, Sheen } from './finish';
import { Mascot, type Mood } from '../Mascot';
import { Lift, PHONE, Phone3D, ScreenLayer, StudioLight, colorAt, imageTexture, inOut, loadPhone, loadStudio, out, ramp, usePrepared } from './three/kit';

/**
 * It is out. The announcement, and it looks like nothing before it:
 * daylight after the night reel. A poster that moves: flat colour, thick
 * ink outlines, hard shadows, type as big as the frame.
 *
 * The dark of the last reel parts like a curtain on the words. Then each
 * feature gets its own colour, its name, and is shown being used, with
 * pieces of the real screens pulled out of the phone beside it: cards
 * swiped right and left; a recorded line, then yours, scored; a page of
 * notes snapped into rows; a sentence put right; a practice picked, and a
 * day planned for you. All six land together, and then where to find it.
 * Each scene wipes in as a circle of the next colour; 傻貓 crosses with
 * the phone and never leaves.
 */

const BEAT = 0.5;
const PI = Math.PI;
const CAM_Z = 9;
const FOV = 30;
const FOCAL = 960 / Math.tan(((FOV / 2) * PI) / 180);
/** Where the phone rests in the feature scenes: its centre's row, how far back it sits, and how far to the side. */
const ROW = 1010;
const PZ = -1.6;
const K = FOCAL / (CAM_Z - PZ);
const SIDE_X = 262 / K;

const INK = '#2B2620';
const CREAM = '#FBF6EA';
const CLAY = '#C96442';
const SAGE = '#6E8F5E';
const MUSTARD = '#E9BE55';
const NAVY = '#2B3A55';
const NIGHT = '#141A10';
const RED = '#C4452C';
const TINTS = [
  { bg: CLAY, fg: CREAM, dot: '#A94E30', edge: INK },
  { bg: SAGE, fg: CREAM, dot: '#587649', edge: INK },
  { bg: MUSTARD, fg: INK, dot: '#CFA238', edge: CREAM },
  { bg: NAVY, fg: '#F8D9BC', dot: '#1F2B42', edge: INK },
  { bg: '#F0BE98', fg: INK, dot: '#DDA47B', edge: CREAM },
  { bg: '#3F5A3A', fg: '#F6EBC8', dot: '#324A2E', edge: INK },
];
const hard = (n: number, color = INK) => `${n}px ${n}px 0 ${color}`;

type Crop = [number, number, number, number];
type Slot = { start: number; length: number };
type Word = { text: string; beat: number };
type Base = { word: string; slot: number; beat?: number; screen: string; lift: Crop; tile?: Crop; premium?: boolean };
type Swipe = Base & { kind: 'swipe'; cards: [string, number][]; right: Word; left: Word; back: Word };
type Speak = Base & { kind: 'speak'; server: { src: string; crop: Crop }; tag: string; say: Word; reply: Crop; score: Crop };
type Scan = Base & { kind: 'scan'; sheet: { title: string; note: string; rows: [string, string][] }; snap: number; land: number[]; rows: Crop[] };
type Tutor = Base & { kind: 'tutor'; said: [string, string]; odd: number; fix: { beat: number; crop: Crop }; better: { beat: number; crop: Crop } };
type Classic = Base & { kind: 'classic'; tap: { beat: number; x: number; y: number }; tag: Word };
type Easy = Base & { kind: 'easy'; piece: Crop; icons: [number, number][]; steps: number[]; tag: Word };
type Feature = Swipe | Speak | Scan | Tutor | Classic | Easy;
type Scene = {
  wait: string;
  open: number;
  w1: Word;
  w2: Word;
  fresh: string;
  features: Feature[];
  all: { text: string; beat: number; from: number; step: number };
  search: { store: string; query: string; chars: number[]; now: Word; get: Word };
  badge: string;
  premium: string;
};
type Episode = { id: string; app: string; label: string; outro: string; lines: { text: string }[]; scene: Scene };
type Pose = { x: number; y: number; z: number; rx: number; ry: number; rz: number };
type Key = { at: number; pose: Pose; ease?: (n: number) => number };

const cjk = (text: string) => /[㐀-鿿]/.test(text);
const face = (text: string) => (cjk(text) ? { fontFamily: FONT, fontWeight: 900 } : { fontFamily: SERIF, fontWeight: 800 });
const hash = (n: number) => {
  const v = Math.sin(n * 127.1 + 311.7) * 43758.5453;
  return v - Math.floor(v);
};
const poseAt = (keys: Key[], t: number): Pose => {
  let i = 0;
  while (i < keys.length - 1 && t >= keys[i + 1].at) i++;
  const a = keys[i];
  const b = keys[Math.min(i + 1, keys.length - 1)];
  const p = a === b ? 0 : (b.ease ?? inOut)(Math.min(1, Math.max(0, (t - a.at) / (b.at - a.at))));
  const m = (k: keyof Pose) => a.pose[k] + (b.pose[k] - a.pose[k]) * p;
  return { x: m('x'), y: m('y'), z: m('z'), rx: m('rx'), ry: m('ry'), rz: m('rz') };
};
/** Something landing hard: in from too big, then a short ring. */
const slam = (t: number, at: number, from = 2.4) => {
  const age = t - at;
  if (age < 0) return { scale: from, opacity: 0, age };
  const p = Math.min(1, age / 0.13);
  const ring = age > 0.13 ? Math.exp(-(age - 0.13) * 13) * Math.sin((age - 0.13) * 30) * 0.07 : 0;
  return { scale: from - (from - 1) * p * p + ring, opacity: Math.min(1, age / 0.05), age };
};
/** A pop: up from nothing, past its size, and back. */
const pop = (t: number, at: number) => {
  const age = t - at;
  if (age < 0) return 0;
  return 1 - Math.exp(-age * 16) * Math.cos(age * 20);
};
/** The size a crop takes at a given width. */
const sized = (crop: Crop, w: number) => ({ w, h: (w * (crop[3] - crop[1])) / (crop[2] - crop[0]) });

const useFilm = (id: string) => {
  const t = useCurrentFrame() / REEL_FPS;
  const episode = script.episodes.find((e) => e.id === id)! as unknown as Episode;
  const s = episode.scene;
  const timing = (timings as Record<string, { total: number; end: number; slots: Slot[] }>)[id];
  const starts = timing.slots.map((slot) => slot.start);
  const at = (slot: number, beat: number) => starts[slot] + beat * BEAT;
  const end = timing.end;
  const allSlot = s.features[s.features.length - 1].slot + 1;

  const open = at(0, s.open);
  const w1 = at(0, s.w1.beat);
  const w2 = at(0, s.w2.beat);
  /** When each feature's scene starts, and when it gives way to the next. */
  const fb = s.features.map((f) => at(f.slot, f.beat ?? 0));
  const allOn = starts[allSlot];
  const until = fb.map((_, i) => (i + 1 < fb.length ? fb[i + 1] : allOn));
  const all = at(allSlot, s.all.beat);
  const search = starts[allSlot + 1];
  const typed = s.search.chars.map((b) => at(allSlot + 1, b));
  const result = typed[typed.length - 1] + 0.3;
  const now = at(allSlot + 1, s.search.now.beat);
  const get = at(allSlot + 1, s.search.get.beat);

  // The phone: up into the first colour, then across with a full turn to each next screen, and out when all land.
  const y0 = ((960 - ROW) / FOCAL) * (CAM_Z - PZ);
  const sideOf = (i: number) => (i % 2 ? -1 : 1);
  const rest: Pose[] = s.features.map((_, i) => ({ x: sideOf(i) * SIDE_X, y: y0, z: PZ, rx: 0.05, ry: -sideOf(i) * 0.4 + PI * 2 * i, rz: sideOf(i) * 0.03 }));
  const keys: Key[] = [{ at: fb[0] - 0.2, pose: { ...rest[0], y: -5.4, ry: rest[0].ry - 1.3, rz: 0.3, rx: 0.4 } }, { at: fb[0] + 0.4, pose: rest[0], ease: out }];
  for (let i = 1; i < rest.length; i++) {
    const before = rest[i - 1];
    keys.push({ at: fb[i] - 0.3, pose: { ...before, ry: before.ry - sideOf(i - 1) * 0.08, z: before.z + 0.1 }, ease: (n) => n });
    keys.push({ at: fb[i] + 0.3, pose: rest[i], ease: inOut });
  }
  const last = rest[rest.length - 1];
  keys.push({ at: allOn - 0.14, pose: { ...last, ry: last.ry + 0.08, z: last.z + 0.1 }, ease: (n) => n });
  keys.push({ at: allOn + 0.3, pose: { ...last, y: -5.6, rz: -0.35, rx: 0.5 }, ease: (n) => n * n });
  const pose = poseAt(keys, t);
  const turning = Math.abs(pose.ry - poseAt(keys, t - 1 / REEL_FPS).ry) * REEL_FPS;
  const shown = fb.reduce((n, when, i) => (i > 0 && t >= when ? i : n), 0);
  const lifts = s.features.map((_, i) => 0.16 * ramp(t, fb[i] + 0.55, fb[i] + 0.85, out) * (1 - ramp(t, until[i] - 0.5, until[i] - 0.32, inOut)));

  // What each feature gives the cat to be pleased about, and what lands hard enough to shake the frame.
  const cheers: number[] = [];
  const knocks: [number, number][] = [[w1, 16], [w2, 24], [all, 20], [now, 16], [end + 0.75, 14]];
  s.features.forEach((f) => {
    const on = (beat: number) => at(f.slot, beat);
    if (f.kind === 'swipe') { cheers.push(on(f.right.beat) + 0.3, on(f.left.beat) + 0.3); knocks.push([on(f.right.beat), 8], [on(f.left.beat), 8]); }
    if (f.kind === 'speak') { cheers.push(on(f.say.beat) + 0.8); knocks.push([on(f.say.beat) + 0.8, 10]); }
    if (f.kind === 'scan') { cheers.push(on(f.land[f.land.length - 1])); knocks.push([on(f.snap), 10], ...f.land.map((b): [number, number] => [on(b), 5])); }
    if (f.kind === 'tutor') { cheers.push(on(f.fix.beat)); knocks.push([on(f.fix.beat), 12]); }
    if (f.kind === 'classic' || f.kind === 'easy') { cheers.push(on(f.tag.beat)); knocks.push([on(f.tag.beat), 12]); }
  });
  const knock = knocks.reduce((k, [when, size]) => { const age = t - when; return age >= 0 && age < 0.3 ? k + Math.exp(-age * 15) * Math.cos(age * 62) * size : k; }, 0);
  return { t, episode, s, timing, starts, at, end, open, w1, w2, fb, until, allOn, all, search, typed, result, now, get, pose, turning, shown, lifts, knock, cheers, sideOf };
};
type Film = ReturnType<typeof useFilm>;

// ───────────────────────── pieces of the poster ─────────────────────────

/** Printed dots over a flat colour, drifting: what keeps a block of colour from being dead. */
const Dots = ({ color, t, size = 34 }: { color: string; t: number; size?: number }) => (
  <AbsoluteFill style={{ backgroundImage: `radial-gradient(${color} 22%, transparent 24%)`, backgroundSize: `${size}px ${size}px`, backgroundPosition: `${t * 14}px ${t * 9}px`, opacity: 0.55 }} />
);

/** Rays turning slowly behind the headline. */
const Sunburst = ({ t, a, b, x = 540, y = 800 }: { t: number; a: string; b: string; x?: number; y?: number }) => (
  <div style={{ position: 'absolute', left: x - 1500, top: y - 1500, width: 3000, height: 3000, borderRadius: '50%', background: `repeating-conic-gradient(${a} 0deg 9deg, ${b} 9deg 18deg)`, transform: `rotate(${t * 5}deg)` }} />
);

/** A scene that arrives as a growing circle of its own colour, ringed in ink. */
const Wipe = ({ t, at, x, y, color, children, until }: { t: number; at: number; x: number; y: number; color: string; children?: ReactNode; until?: number }) => {
  if (t < at - 0.12 || (until !== undefined && t > until)) return null;
  const r = ramp(t, at - 0.12, at + 0.38, inOut) * 2500;
  return (
    <>
      {r < 2480 ? <AbsoluteFill style={{ background: INK, clipPath: `circle(${r + 16}px at ${x}px ${y}px)` }} /> : null}
      <AbsoluteFill style={{ background: color, clipPath: r < 2480 ? `circle(${r}px at ${x}px ${y}px)` : undefined, overflow: 'hidden' }}>{children}</AbsoluteFill>
    </>
  );
};

/** Paper confetti thrown from a point: each piece flies, tumbles and falls. */
const Confetti = ({ t, at, x, y, count = 46, spread = PI * 0.9, aim = -PI / 2, power = 1, seed = 0 }: { t: number; at: number; x: number; y: number; count?: number; spread?: number; aim?: number; power?: number; seed?: number }) => {
  const age = t - at;
  if (age < 0 || age > 2.6) return null;
  const colors = [CLAY, SAGE, MUSTARD, NAVY, '#F3C9A8', CREAM];
  return (
    <>
      {Array.from({ length: count }, (_, i) => {
        const k = i + seed * 97;
        const angle = aim + (hash(k) - 0.5) * spread;
        const speed = (900 + hash(k + 1) * 1500) * power;
        const drag = 1 - Math.exp(-age * 2.2);
        const px = x + (Math.cos(angle) * speed * drag) / 2.2 + Math.sin(age * 3 + k) * 26;
        const py = y + (Math.sin(angle) * speed * drag) / 2.2 + 620 * age * age;
        const w = 16 + hash(k + 2) * 22;
        const kind = i % 4;
        return (
          <div
            key={i}
            style={{
              position: 'absolute',
              left: px,
              top: py,
              width: w,
              height: kind === 0 ? w : w * 0.5,
              borderRadius: kind === 0 ? '50%' : 3,
              background: colors[i % colors.length],
              border: `3px solid ${INK}`,
              transform: `rotate(${hash(k + 3) * 360 + age * (300 + hash(k + 4) * 500)}deg) scaleY(${Math.cos(age * (6 + hash(k + 5) * 8))})`,
              opacity: 1 - ramp(age, 1.9, 2.6, (n) => n),
            }}
          />
        );
      })}
    </>
  );
};

/** A word set a character at a time, each landing just after the last. */
const Chars = ({ text, t, at, gap = 0.045, style, from = 2.2 }: { text: string; t: number; at: number; gap?: number; style?: CSSProperties; from?: number }) => (
  <span style={{ display: 'inline-block', whiteSpace: 'pre', ...style }}>
    {[...text].map((ch, i) => {
      const hit = slam(t, at + i * gap, from);
      return (
        <span key={i} style={{ display: 'inline-block', whiteSpace: 'pre', transform: `scale(${hit.scale}) rotate(${(1 - Math.min(1, Math.max(0, hit.age) / 0.13)) * (i % 2 ? 8 : -8)}deg)`, opacity: hit.opacity }}>
          {ch}
        </span>
      );
    })}
  </span>
);

/** A piece of a real screenshot, at a width (or fitted in a box), outlined like everything else here. */
const Piece = ({ src, crop, w, h, radius = 24, shadow = 0, border = 5 }: { src: string; crop: Crop; w: number; h?: number; radius?: number; shadow?: number; border?: number }) => {
  const [x0, y0, x1, y1] = crop;
  const k = Math.min(w / (x1 - x0), h === undefined ? Infinity : h / (y1 - y0));
  return (
    <div style={{ position: 'relative', width: (x1 - x0) * k, height: (y1 - y0) * k, overflow: 'hidden', borderRadius: radius, border: `${border}px solid ${INK}`, boxSizing: 'content-box', background: CREAM, boxShadow: shadow ? hard(shadow) : undefined }}>
      <Img src={staticFile(`${src}.jpg`)} style={{ position: 'absolute', left: -x0 * k, top: -y0 * k, width: 1206 * k, height: 2622 * k, maxWidth: 'none' }} />
    </div>
  );
};

const Sticker = ({ children, bg, fg = INK, size, rotate = 0, pad = '0.16em 0.5em', shadow = 10, font }: { children: ReactNode; bg: string; fg?: string; size: number; rotate?: number; pad?: string; shadow?: number; font?: string }) => (
  <div style={{ display: 'inline-block', background: bg, color: fg, border: `6px solid ${INK}`, borderRadius: size * 0.34, padding: pad, fontFamily: font ?? FONT, fontWeight: 900, fontSize: size, lineHeight: 1.15, whiteSpace: 'nowrap', boxShadow: hard(shadow), transform: `rotate(${rotate}deg)` }}>{children}</div>
);

/** A fingertip: where a touch is, and when it presses. */
const Finger = ({ x, y, show, press = 0 }: { x: number; y: number; show: number; press?: number }) =>
  show <= 0 ? null : (
    <div style={{ position: 'absolute', left: x - 44, top: y - 44, width: 88, height: 88, borderRadius: '50%', background: 'rgba(251,246,234,0.92)', border: `6px solid ${INK}`, boxShadow: hard(6 * (1 - press)), transform: `scale(${show * (1 - press * 0.18)})` }}>
      <div style={{ position: 'absolute', inset: 14, borderRadius: '50%', border: `5px solid ${CLAY}`, opacity: 0.9 }} />
    </div>
  );

/** A ring thrown off a point when something happens there. */
const Ring = ({ t, at, x, y, color = MUSTARD, size = 300 }: { t: number; at: number; x: number; y: number; color?: string; size?: number }) => {
  const age = t - at;
  if (age < 0 || age > 0.6) return null;
  return <div style={{ position: 'absolute', left: x - size / 2, top: y - size / 2, width: size, height: size, borderRadius: '50%', border: `10px solid ${color}`, transform: `scale(${ramp(age, 0, 0.5, out) * 1.2})`, opacity: 1 - ramp(age, 0.1, 0.6, (n) => n) }} />;
};

/** A many-pointed seal, for one loud word. */
const Seal = ({ children, size, bg = MUSTARD, turn = 0 }: { children: ReactNode; size: number; bg?: string; turn?: number }) => {
  const star = (r0: number, r1: number) => `polygon(${Array.from({ length: 32 }, (_, i) => { const r = i % 2 ? r1 : r0; const a = (i / 32) * PI * 2; return `${50 + Math.cos(a) * r}% ${50 + Math.sin(a) * r}%`; }).join(',')})`;
  return (
    <div style={{ position: 'relative', width: size, height: size }}>
      <div style={{ position: 'absolute', inset: 0, background: INK, clipPath: star(50, 41), transform: `translate(9px, 9px) rotate(${turn}deg)` }} />
      <div style={{ position: 'absolute', inset: 0, background: INK, clipPath: star(50, 41), transform: `rotate(${turn}deg)` }} />
      <div style={{ position: 'absolute', inset: 0, background: bg, clipPath: star(46, 37), transform: `rotate(${turn}deg)` }} />
      <div style={{ position: 'absolute', inset: 0, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>{children}</div>
    </div>
  );
};

// ───────────────────────── the phone ─────────────────────────

const Stage = ({ id }: { id: string }) => {
  const gl = useThree((state) => state.gl);
  const film = useFilm(id);
  const { t, s, pose } = film;
  const maps = usePrepared(async () => {
    const [env, phone, ...screens] = await Promise.all([loadStudio(gl), loadPhone(), ...s.features.map((f) => imageTexture(`${f.screen}.jpg`))]);
    return { env, phone, screens, ground: s.features.map((f, i) => colorAt(screens[i], Math.max(4, f.lift[0] - 16), f.lift[1] + 30)) };
  });
  if (!maps) return null;
  const f = s.features[film.shown];
  return (
    <>
      <StudioLight env={maps.env} turn={t * 0.1 + pose.ry * 0.25 + 1.4} />
      <group position={[pose.x, pose.y + Math.sin(t * 1.7) * 0.016, pose.z]} rotation={[pose.rx + Math.sin(t * 1.1) * 0.01, pose.ry + Math.sin(t * 0.8) * 0.02, pose.rz, 'YXZ']}>
        <Phone3D model={maps.phone} screen={maps.screens[film.shown]}>
          <ScreenLayer color="#2a2418" opacity={Math.min(1, film.lifts[film.shown] * 9) * 0.16} over />
          <Lift map={maps.screens[film.shown]} crop={f.lift} lift={film.lifts[film.shown]} ground={maps.ground[film.shown]} radius={40} />
        </Phone3D>
      </group>
    </>
  );
};

// ───────────────────────── the opening ─────────────────────────

/** The dark of the night reel, parting on the daylight. */
const Curtain = ({ film }: { film: Film }) => {
  const { t, s, open } = film;
  const p = ramp(t, open, open + 0.5, out);
  if (p >= 1) return null;
  const gap = 5 + t * t * 30 + p * 640;
  const words = (
    <div style={{ position: 'absolute', left: 0, width: 1080, top: 760, textAlign: 'center', fontFamily: cjk(s.wait) ? SERIF_TC : SERIF, fontWeight: cjk(s.wait) ? 900 : 800, fontSize: cjk(s.wait) ? 150 : 98, letterSpacing: cjk(s.wait) ? '0.08em' : '0', color: '#FFC861', textShadow: '0 0 40px rgba(255,190,90,0.45)', whiteSpace: 'nowrap' }}>
      {s.wait}
    </div>
  );
  return (
    <>
      {/* The light coming through the gap. */}
      <div style={{ position: 'absolute', left: 540 - gap - 60, width: gap * 2 + 120, top: 0, bottom: 0, background: 'linear-gradient(to right, rgba(255,236,170,0), rgba(255,244,206,0.9) 45%, rgba(255,244,206,0.9) 55%, rgba(255,236,170,0))', opacity: (1 - p) * 0.9 }} />
      {[-1, 1].map((side) => (
        <div key={side} style={{ position: 'absolute', left: side < 0 ? 0 : 540, top: 0, width: 540, height: 1920, overflow: 'hidden', transform: `translateX(${side * gap}px) skewY(${side * p * 3}deg)`, background: NIGHT, boxShadow: `${-side * 10}px 0 0 ${INK}, ${-side * 30}px 0 60px rgba(0,0,0,0.5)` }}>
          <div style={{ position: 'absolute', left: side < 0 ? 0 : -540, top: 0, width: 1080, height: 1920 }}>
            <div style={{ position: 'absolute', inset: 0, background: `radial-gradient(900px 700px at 540px 830px, rgba(255,200,97,${0.16 + t * 0.12}), rgba(0,0,0,0) 70%)` }} />
            {words}
          </div>
        </div>
      ))}
    </>
  );
};

/** The headline: the name, and the two words the whole reel is for. */
const Headline = ({ film }: { film: Film }) => {
  const { t, s, episode, open, w1, w2 } = film;
  const wide = cjk(s.w1.text);
  const icon = pop(t, open + 0.12);
  const seal = slam(t, w2 + 0.45, 3);
  return (
    <>
      <Sunburst t={t} a="#FBF6EA" b="#F6E9C6" y={860} />
      <Dots color="rgba(201,100,66,0.14)" t={t} size={40} />
      <div style={{ position: 'absolute', left: 0, right: 0, top: 262, display: 'flex', justifyContent: 'center', alignItems: 'center', gap: 26, transform: `scale(${icon})`, opacity: Math.min(1, icon * 2) }}>
        <Img src={staticFile('icon-next.png')} style={{ width: 132, height: 132, borderRadius: 30, border: `5px solid ${INK}`, boxShadow: hard(8) }} />
        <Sticker bg={CREAM} size={50} shadow={8} font={cjk(episode.app) ? FONT : SERIF}>{episode.app}</Sticker>
      </div>
      <div style={{ position: 'absolute', left: 0, right: 0, top: wide ? 420 : 520, textAlign: 'center', lineHeight: 1 }}>
        <Chars text={s.w1.text} t={t} at={w1} style={{ ...face(s.w1.text), fontSize: wide ? 340 : 210, color: INK, letterSpacing: wide ? '0.04em' : '-0.01em' }} />
      </div>
      <div style={{ position: 'absolute', left: 0, right: 0, top: wide ? 770 : 790, textAlign: 'center', lineHeight: 1 }}>
        <Chars text={s.w2.text} t={t} at={w2} from={3} style={{ ...face(s.w2.text), fontSize: wide ? 340 : 270, color: CLAY, letterSpacing: wide ? '0.04em' : '-0.01em', textShadow: `${hard(12)}`, WebkitTextStroke: `5px ${INK}`, paintOrder: 'stroke fill' }} />
      </div>
      {/* A seal slapped on the corner of the headline. */}
      <div style={{ position: 'absolute', left: 806, top: 386, transform: `scale(${seal.scale}) rotate(${12 + Math.sin(t * 2.2) * 3}deg)`, opacity: seal.opacity }}>
        <Seal size={230} turn={t * 14}>
          <span style={{ fontFamily: SERIF, fontWeight: 800, fontSize: 66, color: INK, letterSpacing: '0.02em' }}>{s.fresh}</span>
        </Seal>
      </div>
      <Confetti t={t} at={w2 + 0.02} x={60} y={1500} aim={-PI / 3} seed={1} />
      <Confetti t={t} at={w2 + 0.02} x={1020} y={1500} aim={(-PI * 2) / 3} seed={2} />
    </>
  );
};

// ───────────────────────── a feature: its wall, and it being used ─────────────────────────

/** One feature's colour, its number, and its name as big as it will go. */
const FeatureWall = ({ film, i }: { film: Film; i: number }) => {
  const { t, s, fb } = film;
  const f = s.features[i];
  const tint = TINTS[i % TINTS.length];
  const at = fb[i];
  const wide = cjk(f.word);
  const size = Math.min(wide ? 236 : 214, 920 / ([...f.word].length * (wide ? 1.03 : 0.6)));
  const slide = 1 - ramp(t, at - 0.05, at + 0.3, out);
  const side = film.sideOf(i);
  return (
    <>
      <Dots color={tint.dot} t={t} />
      {/* A band of the darker tone behind where the feature is shown, so the pieces have a floor. */}
      <div style={{ position: 'absolute', left: -80, right: -80, top: 1120, height: 420, background: tint.dot, opacity: 0.55, transform: `rotate(${side * -3}deg)` }} />
      <div style={{ position: 'absolute', left: 60, right: 60, top: 236, display: 'flex', alignItems: 'center', justifyContent: 'space-between', opacity: 1 - slide }}>
        <span style={{ fontFamily: SERIF, fontWeight: 800, fontSize: 44, color: tint.fg, letterSpacing: '0.08em' }}>
          0{i + 1}
          <span style={{ opacity: 0.55 }}> / 0{s.features.length}</span>
        </span>
        {f.premium ? (
          <div style={{ transform: `scale(${pop(t, at + 0.3)})` }}>
            <Sticker bg={INK} fg="#FFC861" size={36} shadow={6} rotate={3} font={SERIF}>{s.premium}</Sticker>
          </div>
        ) : null}
      </div>
      <div style={{ position: 'absolute', left: 0, right: 0, top: 292, textAlign: 'center', lineHeight: 1.12, transform: `translateX(${slide * -side * 700}px) skewX(${slide * side * 14}deg)` }}>
        <span style={{ ...face(f.word), fontSize: size, color: tint.fg, whiteSpace: 'nowrap', textShadow: hard(10, tint.edge), letterSpacing: wide ? '0.03em' : '-0.01em' }}>{f.word}</span>
      </div>
    </>
  );
};

type Demo<F> = { film: Film; f: F; on: (beat: number) => number; start: number };

/** Cards, swiped: one right for known, one left for not yet, and what happens to the second. */
const SwipeDemo = ({ film, f, on, start }: Demo<Swipe>) => {
  const { t } = film;
  const right = on(f.right.beat);
  const left = on(f.left.beat);
  const moves = [{ at: right, dir: 1, word: f.right.text, color: SAGE }, { at: left, dir: -1, word: f.left.text, color: CLAY }];
  const gone = (n: number) => (n < moves.length ? ramp(t, moves[n].at - 0.08, moves[n].at + 0.42, (v) => v * v) : 0);
  const size = sized([52, 478, 1154, 1450], 500);
  const counts = [t >= left + 0.4 ? 1 : 0, t >= right + 0.4 ? 1 : 0];
  const back = pop(t, on(f.back.beat));
  return (
    <>
      {[2, 1, 0].map((n) => {
        const [src, top] = f.cards[n];
        const p = gone(n);
        if (p >= 1) return null;
        const move = moves[n];
        // How far down the deck this card is now: the ones above it have gone.
        const depth = n - (n > 0 ? ramp(t, moves[0].at + 0.2, moves[0].at + 0.5, out) : 0) - (n > 1 ? ramp(t, moves[1].at + 0.2, moves[1].at + 0.5, out) : 0);
        const press = move ? ramp(t, move.at - 0.5, move.at - 0.3, out) : 0;
        const enter = pop(t, start + 0.28 + (2 - n) * 0.09);
        const stamp = move ? slam(t, move.at - 0.12, 2.6) : null;
        const dir = move?.dir ?? 0;
        return (
          <div key={n} style={{ position: 'absolute', left: 50 + depth * 14 * (n % 2 ? 1 : -1), top: 96 + depth * 22, width: size.w + 10, height: size.h + 10, transform: `translate(${p * dir * 880}px, ${-p * 70}px) rotate(${[0, 3.5, -4][n] * Math.min(1, depth) + p * dir * 24}deg) scale(${enter * (1 + press * 0.04 - depth * 0.03)})`, transformOrigin: '50% 80%' }}>
            <div style={{ boxShadow: hard(12 + press * 8), borderRadius: 30 }}>
              <Piece src={src} crop={[52, top, 1154, top + 972]} w={size.w} radius={26} />
            </div>
            {move ? <div style={{ position: 'absolute', inset: 0, borderRadius: 30, background: move.color, opacity: Math.min(0.42, Math.max(0, (t - move.at + 0.25) * 1.8)) * (t >= move.at - 0.25 ? 1 : 0) }} /> : null}
            {stamp && stamp.opacity > 0 ? (
              <div style={{ position: 'absolute', left: dir > 0 ? 26 : undefined, right: dir > 0 ? undefined : 26, top: 30, transform: `scale(${stamp.scale}) rotate(${dir * -13}deg)`, opacity: stamp.opacity }}>
                <Sticker bg={move.color} fg={CREAM} size={cjk(move.word) ? 76 : 62} shadow={8} font={cjk(move.word) ? FONT : SERIF}>{`${dir > 0 ? '✓' : '✕'} ${move.word}`}</Sticker>
              </div>
            ) : null}
          </div>
        );
      })}
      {moves.map((move, n) => {
        const show = pop(t, move.at - 0.55) * (1 - ramp(t, move.at + 0.2, move.at + 0.35, (v) => v));
        const p = gone(n);
        return <Finger key={n} x={300 + p * move.dir * 880} y={470 - p * 70} show={show} press={ramp(t, move.at - 0.5, move.at - 0.3, out)} />;
      })}
      {/* The tally, where each card went. */}
      {[{ word: f.left.text, color: CLAY, x: 20, n: counts[0], at: left + 0.4 }, { word: f.right.text, color: SAGE, x: 318, n: counts[1], at: right + 0.4 }].map((tally, n) => (
        <div key={n} style={{ position: 'absolute', left: tally.x, top: 630, transform: `scale(${pop(t, start + 0.6 + n * 0.1) * (1 + Math.exp(-Math.max(0, t - tally.at) * 12) * (t >= tally.at ? 0.28 : 0))}) rotate(${n ? 2 : -2}deg)`, transformOrigin: '50% 50%' }}>
          <Sticker bg={CREAM} size={cjk(tally.word) ? 50 : 40} shadow={8}>
            <span style={{ color: tally.color }}>{tally.word}</span>
            <span style={{ display: 'inline-block', marginLeft: 16, minWidth: 44, textAlign: 'center', background: tally.color, color: CREAM, borderRadius: 14, padding: '0 10px', fontFamily: SERIF }}>{tally.n}</span>
          </Sticker>
        </div>
      ))}
      <div style={{ position: 'absolute', left: 20, top: 742, transform: `scale(${back}) rotate(-1.5deg)`, transformOrigin: '20% 50%' }}>
        <Sticker bg={INK} fg="#FFE7B0" size={cjk(f.back.text) ? 40 : 34} shadow={0} pad="0.34em 0.8em">{`↻ ${f.back.text}`}</Sticker>
      </div>
      <Ring t={t} at={right + 0.38} x={520} y={380} color={SAGE} />
      <Ring t={t} at={left + 0.38} x={80} y={380} color={CREAM} />
    </>
  );
};

/** A recorded line to listen to, then your turn: the mic, what you said, and the score. */
const SpeakDemo = ({ film, f, on, start }: Demo<Speak>) => {
  const { t } = film;
  const say = on(f.say.beat);
  const replyAt = say + 0.38;
  const scoreAt = say + 0.82;
  const server = sized(f.server.crop, 548);
  const reply = sized(f.reply, f.reply[2] - f.reply[0] > 700 ? 500 : 370);
  const score = sized(f.score, f.score[2] - f.score[0] > 700 ? 520 : 380);
  const playing = ramp(t, start + 0.7, start + 0.9) * (1 - ramp(t, say - 0.25, say - 0.05));
  const mic = pop(t, say - 0.1);
  const listening = t >= say && t < replyAt + 0.2;
  const hit = slam(t, scoreAt, 2.6);
  const micY = 96 + server.h + 150;
  return (
    <>
      <div style={{ position: 'absolute', left: 20, top: 70, transform: `scale(${pop(t, start + 0.32)}) rotate(-1.5deg)`, transformOrigin: '20% 50%' }}>
        <div style={{ boxShadow: hard(10), borderRadius: 28 }}>
          <Piece src={f.server.src} crop={f.server.crop} w={server.w} radius={24} />
        </div>
      </div>
      <div style={{ position: 'absolute', left: 300, top: 22, transform: `scale(${pop(t, start + 0.6)}) rotate(4deg)` }}>
        <Sticker bg={MUSTARD} size={cjk(f.tag) ? 44 : 38} shadow={7}>{f.tag}</Sticker>
      </div>
      {/* The recording playing: a strip of level bars. */}
      <div style={{ position: 'absolute', left: 60, top: 96 + server.h + 20, width: 430, height: 96, borderRadius: 30, background: CREAM, border: `5px solid ${INK}`, boxShadow: hard(8), transform: `scale(${pop(t, start + 0.7)})`, display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 9 }}>
        <svg width={44} height={44} viewBox="0 0 44 44" style={{ marginRight: 8 }}>
          <path d="M6 16 h9 l11 -9 v30 l-11 -9 h-9 z" fill={CLAY} stroke={INK} strokeWidth={3} strokeLinejoin="round" />
          <path d="M32 14 q7 8 0 16" fill="none" stroke={INK} strokeWidth={4} strokeLinecap="round" opacity={0.4 + 0.6 * playing} />
        </svg>
        {Array.from({ length: 16 }, (_, i) => {
          const level = 0.16 + playing * (0.3 + 0.7 * Math.abs(Math.sin(t * (7 + (i % 5)) + i * 1.7)) * Math.abs(Math.sin(t * 2.3 + i * 0.5)));
          return <div key={i} style={{ width: 11, height: 66 * level, borderRadius: 6, background: i / 16 < ((t - start - 0.8) / Math.max(0.1, say - start - 1)) ? CLAY : '#D9CFB8' }} />;
        })}
      </div>
      {/* Your turn. */}
      <Ring t={t} at={say} x={130} y={micY + 68} color={CREAM} size={260} />
      {listening ? <Ring t={t} at={say + 0.22} x={130} y={micY + 68} color={CREAM} size={260} /> : null}
      <div style={{ position: 'absolute', left: 62, top: micY, width: 136, height: 136, borderRadius: '50%', background: CLAY, border: `6px solid ${INK}`, boxShadow: hard(listening ? 4 : 10), transform: `scale(${mic * (1 + (listening ? Math.sin((t - say) * 26) * 0.04 : 0))})`, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
        <svg width={70} height={70} viewBox="0 0 70 70">
          <rect x={25} y={8} width={20} height={34} rx={10} fill={CREAM} stroke={INK} strokeWidth={4} />
          <path d="M16 34 a19 19 0 0 0 38 0 M35 53 v10 M24 63 h22" fill="none" stroke={CREAM} strokeWidth={5} strokeLinecap="round" />
        </svg>
      </div>
      <div style={{ position: 'absolute', left: 222, top: micY + 34, transform: `scale(${pop(t, say + 0.05)}) rotate(-3deg)`, transformOrigin: '0% 50%' }}>
        <Sticker bg={INK} fg="#FFE7B0" size={cjk(f.say.text) ? 48 : 42} shadow={0} pad="0.26em 0.7em">{f.say.text}</Sticker>
      </div>
      <div style={{ position: 'absolute', right: 10, top: micY + 150, transform: `translateX(${(1 - ramp(t, replyAt, replyAt + 0.3, out)) * 700}px) rotate(1.5deg)` }}>
        <div style={{ boxShadow: hard(10), borderRadius: 28 }}>
          <Piece src={f.screen} crop={f.reply} w={reply.w} radius={24} />
        </div>
      </div>
      <div style={{ position: 'absolute', right: 30, top: micY + 150 + reply.h + 22, transform: `scale(${hit.scale}) rotate(-3deg)`, opacity: hit.opacity, transformOrigin: '70% 50%' }}>
        <div style={{ boxShadow: hard(10, MUSTARD), borderRadius: 26 }}>
          <Piece src={f.screen} crop={f.score} w={score.w} radius={22} />
        </div>
      </div>
      <Confetti t={t} at={scoreAt + 0.03} x={380} y={micY + 170 + reply.h} spread={PI * 1.6} power={0.55} count={26} seed={11} />
    </>
  );
};

/** A page of handwritten notes, snapped: the flash, the pass of light, and each line coming off as a row of the real list. */
const ScanDemo = ({ film, f, on, start }: Demo<Scan>) => {
  const { t } = film;
  const snap = on(f.snap);
  const lands = f.land.map(on);
  const paper = pop(t, start + 0.3);
  const frame = pop(t, start + 0.55);
  const flash = t >= snap ? Math.exp(-(t - snap) * 9) : 0;
  const beam = ramp(t, snap + 0.12, snap + 0.75, inOut);
  const rowW = f.rows.length > 3 ? 440 : 520;
  const rowTop = f.rows.length > 3 ? 478 : 500;
  const rowH = sized(f.rows[0], rowW).h;
  const gap = Math.min(rowH + 12, (806 - rowTop - rowH) / (f.rows.length - 1));
  const lineY = (i: number) => 150 + i * (270 / f.rows.length);
  return (
    <>
      <div style={{ position: 'absolute', left: 60, top: 14, width: 400, height: 452, transform: `scale(${paper * (1 - flash * 0.03)}) rotate(-4deg)`, transformOrigin: '50% 50%' }}>
        <div style={{ position: 'absolute', inset: 0, background: '#FFFDF4', border: `5px solid ${INK}`, borderRadius: 10, boxShadow: hard(12), overflow: 'hidden', backgroundImage: 'repeating-linear-gradient(to bottom, transparent 0, transparent 62px, rgba(60,90,150,0.22) 62px, rgba(60,90,150,0.22) 65px)', backgroundPosition: '0 62px' }}>
          <div style={{ position: 'absolute', left: 44, top: 0, bottom: 0, width: 3, background: 'rgba(196,69,44,0.4)' }} />
          <div style={{ position: 'absolute', left: 64, top: 30, fontFamily: HAND_TC, fontSize: 46, color: '#2B3A55', whiteSpace: 'nowrap' }}>{f.sheet.title}</div>
          <div style={{ position: 'absolute', right: 18, bottom: 16, fontFamily: cjk(f.sheet.note) ? HAND_TC : HAND, fontWeight: 600, fontSize: cjk(f.sheet.note) ? 30 : 38, color: RED, transform: 'rotate(-6deg)', border: `3px solid ${RED}`, borderRadius: '50%', padding: '2px 12px', whiteSpace: 'nowrap' }}>{f.sheet.note}</div>
          {f.sheet.rows.map(([a, b], i) => {
            const taken = t >= lands[i] - 0.3;
            return (
              <div key={i} style={{ position: 'absolute', left: 64, top: lineY(i) - 26, display: 'flex', alignItems: 'baseline', gap: 22, whiteSpace: 'nowrap', opacity: taken ? 0.35 : 1 }}>
                <span style={{ fontFamily: cjk(a) ? HAND_TC : HAND, fontWeight: 600, fontSize: cjk(a) ? 44 : 54, color: '#2B2620' }}>{a}</span>
                <span style={{ fontFamily: cjk(b) ? HAND_TC : HAND, fontWeight: 600, fontSize: cjk(b) ? 36 : 44, color: '#4A5A7A' }}>{b}</span>
              </div>
            );
          })}
          {/* The pass of light that reads it. */}
          {beam > 0 && beam < 1 ? <div style={{ position: 'absolute', left: 0, right: 0, top: beam * 452 - 70, height: 80, background: 'linear-gradient(to bottom, rgba(201,100,66,0), rgba(201,100,66,0.35) 80%, #C96442 96%, rgba(201,100,66,0))' }} /> : null}
          <div style={{ position: 'absolute', inset: 0, background: '#FFFFFF', opacity: flash }} />
        </div>
        {/* The viewfinder's corners. */}
        {[[0, 0], [1, 0], [0, 1], [1, 1]].map(([cx, cy], n) => (
          <div key={n} style={{ position: 'absolute', left: cx ? undefined : -26, right: cx ? -26 : undefined, top: cy ? undefined : -26, bottom: cy ? -26 : undefined, width: 62, height: 62, borderLeft: cx ? undefined : `9px solid ${INK}`, borderRight: cx ? `9px solid ${INK}` : undefined, borderTop: cy ? undefined : `9px solid ${INK}`, borderBottom: cy ? `9px solid ${INK}` : undefined, borderRadius: 8, transform: `scale(${frame}) translate(${(cx ? -1 : 1) * flash * 14}px, ${(cy ? -1 : 1) * flash * 14}px)` }} />
        ))}
      </div>
      {/* Each line, as the row it becomes. */}
      {f.rows.map((crop, i) => {
        const fly = ramp(t, lands[i] - 0.3, lands[i], inOut);
        if (fly <= 0) return null;
        const hit = t >= lands[i] ? Math.exp(-(t - lands[i]) * 12) * Math.sin((t - lands[i]) * 28) * 0.05 : 0;
        const x = 90 + (40 - 90) * fly;
        const y = lineY(i) - 20 + (rowTop + i * gap - (lineY(i) - 20)) * fly - Math.sin(PI * fly) * 60;
        return (
          <div key={i} style={{ position: 'absolute', left: x, top: y, transform: `scale(${0.5 + 0.5 * fly + hit}) rotate(${(1 - fly) * -4 + (i % 2 ? 1.2 : -1.2) * fly}deg)`, transformOrigin: '10% 50%', opacity: Math.min(1, fly * 4) }}>
            <div style={{ boxShadow: hard(9), borderRadius: 22 }}>
              <Piece src={f.screen} crop={crop} w={rowW} radius={18} />
            </div>
          </div>
        );
      })}
      {lands.map((when, i) => (
        <Ring key={i} t={t} at={when} x={80} y={rowTop + i * gap + rowH / 2} color={CREAM} size={150} />
      ))}
      <Confetti t={t} at={lands[lands.length - 1] + 0.05} x={300} y={640} spread={PI * 1.6} power={0.5} count={24} seed={12} />
    </>
  );
};

/** What you said, what was odd about it, and the real correction. */
const TutorDemo = ({ film, f, on, start }: Demo<Tutor>) => {
  const { t } = film;
  const odd = on(f.odd);
  const fixAt = on(f.fix.beat);
  const betterAt = on(f.better.beat);
  const fix = sized(f.fix.crop, 560);
  const hit = slam(t, fixAt, 2.4);
  const mark = pop(t, odd + 0.3);
  const wide = cjk(f.said[1]);
  return (
    <>
      <div style={{ position: 'absolute', left: 14, top: 40, transform: `scale(${pop(t, start + 0.3)}) rotate(-2deg)`, transformOrigin: '20% 60%' }}>
        <div style={{ position: 'relative', background: CREAM, border: `6px solid ${INK}`, borderRadius: 34, boxShadow: hard(10), padding: '34px 40px 30px' }}>
          <div style={{ position: 'absolute', left: 30, top: -30, background: CLAY, color: CREAM, border: `5px solid ${INK}`, borderRadius: 16, padding: '2px 18px', fontWeight: 900, fontSize: 30, whiteSpace: 'nowrap' }}>{f.said[0]}</div>
          <div style={{ fontFamily: wide ? FONT : SERIF, fontWeight: wide ? 700 : 700, fontSize: wide ? 50 : 48, color: INK, whiteSpace: 'nowrap', lineHeight: 1.2 }}>{f.said[1]}</div>
          <svg width="100%" height={26} viewBox="0 0 400 26" preserveAspectRatio="none" style={{ display: 'block', marginTop: 2, overflow: 'visible' }}>
            <path d="M2 14 q 25 -16 50 0 t 50 0 t 50 0 t 50 0 t 50 0 t 50 0 t 50 0 t 46 0" fill="none" stroke={RED} strokeWidth={7} strokeLinecap="round" pathLength={100} strokeDasharray={100} strokeDashoffset={100 * (1 - ramp(t, odd, odd + 0.4, inOut))} vectorEffect="non-scaling-stroke" />
          </svg>
          {/* The tail of the bubble. */}
          <div style={{ position: 'absolute', left: 70, bottom: -27, width: 44, height: 44, background: CREAM, borderRight: `6px solid ${INK}`, borderBottom: `6px solid ${INK}`, transform: 'rotate(45deg) skew(12deg, 12deg)' }} />
        </div>
      </div>
      <div style={{ position: 'absolute', left: 500, top: -26, width: 96, height: 96, borderRadius: '50%', background: MUSTARD, border: `6px solid ${INK}`, boxShadow: hard(8), transform: `scale(${mark}) rotate(${12 + Math.sin(t * 9) * 4 * Math.exp(-Math.max(0, t - odd - 0.3) * 2)}deg)`, display: 'flex', alignItems: 'center', justifyContent: 'center', fontFamily: SERIF, fontWeight: 800, fontSize: 68, color: INK }}>?</div>
      {/* The tutor reading it: three dots, until the correction lands. */}
      {t >= odd + 0.55 && t < fixAt + 0.05 ? (
        <div style={{ position: 'absolute', left: 40, top: 300, transform: `scale(${pop(t, odd + 0.55) * (1 - ramp(t, fixAt - 0.1, fixAt + 0.05, (n) => n))}) rotate(2deg)`, transformOrigin: '20% 50%' }}>
          <Sticker bg={INK} fg="#FFE7B0" size={cjk(f.word) ? 46 : 42} shadow={0} pad="0.3em 0.8em">
            <span>{f.word}</span>
            {[0, 1, 2].map((n) => (
              <span key={n} style={{ display: 'inline-block', width: 16, height: 16, borderRadius: '50%', background: '#FFC861', marginLeft: n ? 10 : 22, transform: `translateY(${-Math.max(0, Math.sin((t - odd) * 9 - n * 0.9)) * 16}px)` }} />
            ))}
          </Sticker>
        </div>
      ) : null}
      {/* The correction, from the real screen. */}
      <div style={{ position: 'absolute', left: 20, top: 290, transform: `scale(${hit.scale}) rotate(1.5deg)`, opacity: hit.opacity, transformOrigin: '50% 50%' }}>
        <div style={{ boxShadow: hard(12, MUSTARD), borderRadius: 28 }}>
          <Piece src={f.screen} crop={f.fix.crop} w={fix.w} radius={24} />
        </div>
      </div>
      <div style={{ position: 'absolute', left: 20, top: 290 + fix.h + 44, transform: `scale(${pop(t, betterAt)}) rotate(-1.5deg)`, transformOrigin: '50% 30%' }}>
        <div style={{ boxShadow: hard(10), borderRadius: 28 }}>
          <Piece src={f.screen} crop={f.better.crop} w={560} radius={24} />
        </div>
      </div>
      <Ring t={t} at={fixAt + 0.02} x={300} y={290 + fix.h / 2} color={MUSTARD} size={460} />
      <Confetti t={t} at={fixAt + 0.04} x={300} y={300 + fix.h / 2} spread={PI * 2} power={0.55} count={28} seed={13} />
    </>
  );
};

/** Classic: the practices laid out, and a finger picking one. */
const ClassicDemo = ({ film, f, on, start }: Demo<Classic>) => {
  const { t } = film;
  const tap = on(f.tap.beat);
  const size = sized(f.lift, 580);
  const tx = 10 + f.tap.x * size.w;
  const ty = 60 + f.tap.y * size.h;
  const travel = ramp(t, tap - 0.5, tap, out);
  const press = ramp(t, tap - 0.02, tap + 0.06, out) * (1 - ramp(t, tap + 0.12, tap + 0.3, out));
  const tag = slam(t, on(f.tag.beat), 2.6);
  return (
    <>
      <div style={{ position: 'absolute', left: 6, top: 56, transform: `scale(${pop(t, start + 0.3) * (1 - press * 0.02)}) rotate(-1.5deg)`, transformOrigin: '50% 50%' }}>
        <div style={{ boxShadow: hard(12), borderRadius: 30 }}>
          <Piece src={f.screen} crop={f.lift} w={size.w} radius={26} />
        </div>
        {/* The one that was picked. */}
        {t >= tap ? <div style={{ position: 'absolute', left: (f.tap.x > 0.5 ? 0.5 : 0) * size.w + 12, top: (f.tap.y > 0.5 ? 0.5 : 0) * size.h + 12, width: size.w / 2 - 14, height: size.h / 2 - 14, borderRadius: 22, border: `8px solid ${CLAY}`, boxShadow: `0 0 0 5px ${CREAM}`, opacity: Math.min(1, (t - tap) * 8), transform: `scale(${1 + Math.exp(-(t - tap) * 10) * 0.12})` }} /> : null}
      </div>
      <Ring t={t} at={tap} x={tx} y={ty} color={CLAY} size={280} />
      <Finger x={tx + (1 - travel) * 160} y={ty + (1 - travel) * 420} show={pop(t, tap - 0.55) * (1 - ramp(t, tap + 0.5, tap + 0.7, (v) => v))} press={press} />
      <div style={{ position: 'absolute', left: 40, top: 80 + size.h + 60, transform: `scale(${tag.scale}) rotate(-4deg)`, opacity: tag.opacity, transformOrigin: '40% 50%' }}>
        <Sticker bg={CREAM} size={cjk(f.tag.text) ? 92 : 58} shadow={12} font={cjk(f.tag.text) ? FONT : SERIF}>{f.tag.text}</Sticker>
      </div>
      <Confetti t={t} at={on(f.tag.beat) + 0.03} x={300} y={120 + size.h + 110} spread={PI * 1.6} power={0.5} count={24} seed={14} />
    </>
  );
};

/** Easy mode: the day already laid out, its steps ticked off one after another. */
const EasyDemo = ({ film, f, on, start }: Demo<Easy>) => {
  const { t } = film;
  const k = Math.min(520 / (f.piece[2] - f.piece[0]), 610 / (f.piece[3] - f.piece[1]));
  const w = (f.piece[2] - f.piece[0]) * k;
  const h = (f.piece[3] - f.piece[1]) * k;
  const left = (600 - w) / 2;
  const tag = slam(t, on(f.tag.beat), 2.6);
  return (
    <>
      <div style={{ position: 'absolute', left, top: 0, transform: `scale(${pop(t, start + 0.42)}) rotate(1.5deg)`, transformOrigin: '50% 50%' }}>
        <div style={{ boxShadow: hard(12), borderRadius: 30 }}>
          <Piece src={f.screen} crop={f.piece} w={520} h={610} radius={26} />
        </div>
        {f.icons.map(([x, y], i) => {
          const when = on(f.steps[i]);
          const hit = slam(t, when, 2.8);
          return (
            <div key={i} style={{ position: 'absolute', left: x * w - 34 + 5, top: y * h - 62 + 5, width: 68, height: 68, borderRadius: '50%', background: SAGE, border: `5px solid ${INK}`, boxShadow: hard(5), transform: `scale(${hit.scale}) rotate(-8deg)`, opacity: hit.opacity, display: 'flex', alignItems: 'center', justifyContent: 'center', color: CREAM, fontWeight: 900, fontSize: 44, lineHeight: 1 }}>✓</div>
          );
        })}
        {f.steps.map((b, i) => (
          <Ring key={i} t={t} at={on(b)} x={f.icons[i][0] * w + 5} y={f.icons[i][1] * h - 22} color={CREAM} size={150} />
        ))}
      </div>
      <div style={{ position: 'absolute', left: 30, top: 640, transform: `scale(${tag.scale}) rotate(-4deg)`, opacity: tag.opacity, transformOrigin: '40% 50%' }}>
        <Sticker bg={MUSTARD} size={cjk(f.tag.text) ? 70 : 56} shadow={12} font={cjk(f.tag.text) ? FONT : SERIF}>{f.tag.text}</Sticker>
      </div>
      <Confetti t={t} at={on(f.tag.beat) + 0.03} x={300} y={700} spread={PI * 1.6} power={0.5} count={24} seed={15} />
    </>
  );
};

/** The feature being used, beside the phone: a 600 × 820 space on the side the phone is not. */
const FeatureDemo = ({ film, i }: { film: Film; i: number }) => {
  const { t, s, fb, until, at } = film;
  const f = s.features[i];
  if (t < fb[i] + 0.1 || t > until[i] + 0.05) return null;
  const side = film.sideOf(i);
  const leave = ramp(t, until[i] - 0.22, until[i] + 0.02, (n) => n * n);
  const on = (beat: number) => at(f.slot, beat);
  const props = { film, on, start: fb[i] };
  return (
    <div style={{ position: 'absolute', left: (side > 0 ? 24 : 456) - leave * side * 500, top: 588, width: 600, height: 820, opacity: 1 - leave, transform: `rotate(${-leave * side * 8}deg)` }}>
      {f.kind === 'swipe' ? <SwipeDemo {...props} f={f} /> : null}
      {f.kind === 'speak' ? <SpeakDemo {...props} f={f} /> : null}
      {f.kind === 'scan' ? <ScanDemo {...props} f={f} /> : null}
      {f.kind === 'tutor' ? <TutorDemo {...props} f={f} /> : null}
      {f.kind === 'classic' ? <ClassicDemo {...props} f={f} /> : null}
      {f.kind === 'easy' ? <EasyDemo {...props} f={f} /> : null}
    </div>
  );
};

// ───────────────────────── the rest ─────────────────────────

/** All of them at once: a wall of real pieces dealt out on the beat, and the words that close the list. */
const AllHere = ({ film }: { film: Film }) => {
  const { t, s, all, allOn } = film;
  const badge = slam(t, all, 3);
  return (
    <>
      <Sunburst t={t} a="#FBF6EA" b="#F3E6C2" y={820} />
      {s.features.map((f, i) => {
        const hit = slam(t, allOn + (s.all.from + i * s.all.step) * BEAT, 1.8);
        const tint = TINTS[i % TINTS.length];
        const col = i % 2;
        const row = Math.floor(i / 2);
        return (
          <div key={i} style={{ position: 'absolute', left: 70 + col * 484, top: 246 + row * 322, width: 456, height: 300, borderRadius: 34, background: tint.bg, border: `6px solid ${INK}`, boxShadow: hard(10), transform: `scale(${hit.scale}) rotate(${[-2, 1.6, 1.4, -1.8, -1.2, 2][i % 6]}deg)`, opacity: hit.opacity, overflow: 'hidden' }}>
            <Dots color={tint.dot} t={t} size={28} />
            <div style={{ position: 'absolute', left: 0, right: 0, top: 16, height: 196, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
              <Piece src={f.screen} crop={f.tile ?? f.lift} w={404} h={186} radius={18} border={4} />
            </div>
            <div style={{ position: 'absolute', left: 0, right: 0, bottom: 10, textAlign: 'center', ...face(f.word), fontSize: cjk(f.word) ? 58 : 54, lineHeight: 1.1, color: tint.fg, whiteSpace: 'nowrap', textShadow: hard(4, tint.edge) }}>{f.word}</div>
          </div>
        );
      })}
      <div style={{ position: 'absolute', left: 240, right: 0, top: 1226, display: 'flex', justifyContent: 'center', transform: `scale(${badge.scale})`, opacity: badge.opacity }}>
        <Sticker bg={CLAY} fg={CREAM} size={cjk(s.all.text) ? 136 : 116} rotate={-4} shadow={14} font={cjk(s.all.text) ? FONT : SERIF}>{s.all.text}</Sticker>
      </div>
      <Confetti t={t} at={all + 0.03} x={660} y={1300} spread={PI * 1.2} power={1} count={50} seed={3} />
    </>
  );
};

/** Where it is: a search, typed with the voice, and the thing itself. */
const Search = ({ film }: { film: Film }) => {
  const { t, s, search, typed, result, now, get } = film;
  const count = typed.filter((when) => t >= when).length;
  const bar = pop(t, search + 0.2);
  const card = slam(t, result, 1.7);
  const press = t >= get ? Math.exp(-(t - get) * 9) * Math.sin((t - get) * 22) * 0.12 - Math.exp(-(t - get) * 30) * 0.14 : 0;
  const cta = slam(t, now, 2.6);
  const ray = ramp(t, result, result + 0.6, out);
  const wide = cjk(s.search.now.text);
  return (
    <>
      <Dots color="#1D2317" t={t} />
      {/* What is being looked for, hollow and huge, drifting past until it is found. */}
      {[0, 1].map((row) => (
        <div key={row} style={{ position: 'absolute', left: -700, top: 600 + row * 330, width: 2480, textAlign: 'center', ...face(s.search.query), fontSize: 300, lineHeight: 1, whiteSpace: 'nowrap', color: 'transparent', WebkitTextStroke: '5px #3D4732', transform: `translateX(${(t - search) * (row ? 90 : -90)}px)`, opacity: ramp(t, search + 0.15, search + 0.5) * (1 - ramp(t, result - 0.1, result + 0.25)) }}>{`${s.search.query}　${s.search.query}　${s.search.query}`}</div>
      ))}
      {/* Light behind the result. */}
      <div style={{ position: 'absolute', left: 540 - 1300, top: 880 - 1300, width: 2600, height: 2600, borderRadius: '50%', background: 'repeating-conic-gradient(rgba(233,190,85,0.2) 0deg 7deg, rgba(233,190,85,0) 7deg 14deg)', maskImage: 'radial-gradient(closest-side, #000 20%, transparent 62%)', WebkitMaskImage: 'radial-gradient(closest-side, #000 20%, transparent 62%)', transform: `rotate(${t * 8}deg) scale(${ray})`, opacity: ray }} />
      <div style={{ position: 'absolute', left: 0, right: 0, top: 250, textAlign: 'center', fontFamily: SERIF, fontWeight: 800, fontSize: 60, color: '#FFE7B0', letterSpacing: '0.04em', opacity: ramp(t, search + 0.1, search + 0.4) }}>{s.search.store}</div>
      <div style={{ position: 'absolute', left: 70, top: 356, width: 940, height: 150, borderRadius: 75, background: CREAM, border: `6px solid ${INK}`, boxShadow: hard(12, MUSTARD), transform: `scale(${bar})`, display: 'flex', alignItems: 'center', padding: '0 46px', gap: 30, boxSizing: 'border-box' }}>
        <svg width={64} height={64} viewBox="0 0 64 64">
          <circle cx={27} cy={27} r={19} fill="none" stroke={INK} strokeWidth={8} />
          <path d="M42 42 L58 58" stroke={INK} strokeWidth={9} strokeLinecap="round" />
        </svg>
        <span style={{ ...face(s.search.query), fontSize: 80, color: INK, whiteSpace: 'pre', lineHeight: 1 }}>
          {[...s.search.query].slice(0, count).map((ch, i) => (
            <span key={i} style={{ display: 'inline-block', transform: `scale(${1 + Math.exp(-(t - typed[i]) * 16) * 0.5})` }}>{ch}</span>
          ))}
        </span>
        <div style={{ width: 7, height: 86, background: CLAY, borderRadius: 4, marginLeft: -18, opacity: Math.floor(t * 3) % 2 || t - typed[Math.max(0, count - 1)] < 0.3 ? 1 : 0 }} />
      </div>
      {/* What the search finds. */}
      <div style={{ position: 'absolute', left: 90, top: 566, width: 900, height: 420, borderRadius: 60, background: CREAM, border: `6px solid ${INK}`, boxShadow: hard(16, MUSTARD), transform: `scale(${card.scale}) rotate(-2deg)`, opacity: card.opacity }}>
        <div style={{ position: 'absolute', left: 54, top: 70 }}>
          <Img src={staticFile('icon-next.png')} style={{ width: 280, height: 280, borderRadius: 64, border: `5px solid ${INK}`, display: 'block' }} />
          <Sheen t={t} at={result + 0.35} radius={64} />
        </div>
        <div style={{ position: 'absolute', left: 376, top: 84, right: 30 }}>
          {film.episode.app.split(' ').map((part, i) => (
            <div key={i} style={{ ...face(part), fontSize: cjk(part) ? 72 : 80, lineHeight: 1.18, color: INK, whiteSpace: 'nowrap' }}>{part}</div>
          ))}
        </div>
        <div style={{ position: 'absolute', right: 50, bottom: 50, transform: `scale(${1 + press})` }}>
          <Sticker bg={CLAY} fg={CREAM} size={58} shadow={t >= get && t - get < 0.1 ? 2 : 8} pad="0.2em 0.9em" font={cjk(s.search.get.text) ? FONT : SERIF}>{s.search.get.text}</Sticker>
        </div>
      </div>
      <div style={{ position: 'absolute', left: 0, right: 0, top: 1048, textAlign: 'center', lineHeight: 1, transform: `scale(${cta.scale}) rotate(-3deg)`, opacity: cta.opacity }}>
        <span style={{ ...face(s.search.now.text), fontWeight: 900, fontSize: wide ? 176 : 164, color: MUSTARD, whiteSpace: 'nowrap', WebkitTextStroke: `5px ${INK}`, paintOrder: 'stroke fill', textShadow: hard(12, CLAY), letterSpacing: wide ? '0.02em' : '-0.01em' }}>{s.search.now.text}</span>
      </div>
      <Ring t={t} at={get} x={840} y={896} size={400} />
      <Confetti t={t} at={get + 0.05} x={840} y={896} spread={PI * 1.4} power={0.9} count={50} seed={5} />
    </>
  );
};

/** The end card: the icon, the name, and that it is out. */
const EndCard = ({ film }: { film: Film }) => {
  const { t, s, episode, end } = film;
  const icon = pop(t, end + 0.12);
  const badge = slam(t, end + 0.75, 3);
  const follow = pop(t, end + 1.5);
  const parts = episode.app.split(' ');
  return (
    <>
      <Sunburst t={t} a="#FBF6EA" b="#F6E9C6" y={520} />
      <Dots color="rgba(201,100,66,0.14)" t={t} size={40} />
      <div style={{ position: 'absolute', left: 540 - 150, top: 268, width: 300, height: 300, transform: `scale(${icon}) rotate(-3deg)` }}>
        <Img src={staticFile('icon-next.png')} style={{ width: 300, height: 300, borderRadius: 68, border: `6px solid ${INK}`, boxShadow: hard(14), display: 'block' }} />
        <Sheen t={t} at={end + 1.0} radius={68} />
      </div>
      <div style={{ position: 'absolute', left: 0, right: 0, top: 622, display: 'flex', justifyContent: 'center', alignItems: 'baseline', gap: 20, color: INK, opacity: ramp(t, end + 0.25, end + 0.5), transform: `translateY(${(1 - ramp(t, end + 0.25, end + 0.6, out)) * 30}px)` }}>
        <span style={{ fontFamily: SERIF, fontWeight: 800, fontSize: 104 }}>{parts[0]}</span>
        {parts.length > 1 ? <span style={{ fontFamily: FONT, fontWeight: 900, fontSize: 88, letterSpacing: '0.04em' }}>{parts.slice(1).join(' ')}</span> : null}
      </div>
      <div style={{ position: 'absolute', left: 0, right: 0, top: 810, display: 'flex', justifyContent: 'center', transform: `scale(${badge.scale})`, opacity: badge.opacity }}>
        <Sticker bg={CLAY} fg={CREAM} size={cjk(s.badge) ? 74 : 60} rotate={-4} shadow={14} pad="0.3em 0.7em" font={cjk(s.badge) ? FONT : SERIF}>{s.badge}</Sticker>
      </div>
      <div style={{ position: 'absolute', left: 0, right: 0, top: 1010, display: 'flex', justifyContent: 'center', transform: `scale(${follow})` }}>
        <Sticker bg={INK} fg={CREAM} size={cjk(episode.outro) ? 46 : 44} shadow={0} pad="0.42em 1em">{episode.outro}</Sticker>
      </div>
      <Confetti t={t} at={end + 0.78} x={540} y={900} spread={PI * 2} power={1.1} count={60} seed={6} />
      <Confetti t={t} at={end + 2.2} x={100} y={1500} aim={-PI / 3} power={0.9} count={30} seed={7} />
      <Confetti t={t} at={end + 2.2} x={980} y={1500} aim={(-PI * 2) / 3} power={0.9} count={30} seed={8} />
    </>
  );
};

/** The line being said, as a sticker: a white card in ink, what matters marked in yellow. */
const StickerCaption = ({ text, start, length, t, first, label }: { text: string; start: number; length: number; t: number; first: boolean; label: string }) => {
  if (t < start || t > start + length) return null;
  const age = first ? t + 1 : t - start;
  const scale = pop(age, 0) * (1 - ramp(t, start + length - 0.12, start + length, (n) => n));
  const lines = text.split('\n').map((line) => line.split('**').map((part, i) => ({ part, strong: i % 2 === 1 })));
  const size = cjk(text) ? 52 : 46;
  return (
    <div style={{ position: 'absolute', left: 0, right: 0, top: 1446, display: 'flex', justifyContent: 'center' }}>
      <div style={{ position: 'relative', transform: `scale(${scale}) rotate(-1deg)`, transformOrigin: '50% 60%' }}>
        <div style={{ position: 'absolute', left: 26, top: -36, background: CLAY, color: CREAM, border: `5px solid ${INK}`, borderRadius: '14px 14px 0 0', borderBottom: 'none', padding: '2px 18px 4px', fontWeight: 900, fontSize: 24, letterSpacing: '0.12em', whiteSpace: 'nowrap' }}>{label}</div>
        <div style={{ background: '#FFFFFF', border: `5px solid ${INK}`, borderRadius: 22, boxShadow: hard(9), padding: '14px 34px 16px', textAlign: 'center' }}>
          {lines.map((parts, li) => (
            <div key={li} style={{ fontWeight: 900, fontSize: size, lineHeight: 1.32, color: INK, whiteSpace: 'nowrap' }}>
              {parts.map(({ part, strong }, pi) => (strong ? <span key={pi} style={{ background: `linear-gradient(to bottom, transparent 46%, #FFD766 46%, #FFD766 92%, transparent 92%)`, padding: '0 4px' }}>{part}</span> : <span key={pi}>{part}</span>))}
            </div>
          ))}
        </div>
      </div>
    </div>
  );
};

/** 傻貓, on screen from the moment the curtain parts to the last frame: beside the phone in each feature, crossing over with it. */
const Buddy = ({ film }: { film: Film }) => {
  const { t, s, open, w2, fb, all, allOn, search, result, now, get, end } = film;
  if (t < open + 0.1) return null;
  const spots: { at: number; left: number; top: number; turn: number; size: number }[] = [
    { at: open + 0.1, left: 350, top: 1150, turn: 0, size: 1 },
    ...s.features.map((_, i) => ({ at: fb[i] - 0.1, left: film.sideOf(i) > 0 ? 712 : -12, top: 1074, turn: film.sideOf(i) * -6, size: 0.66 })),
    { at: allOn - 0.05, left: -70, top: 1196, turn: 10, size: 0.86 },
    { at: search - 0.1, left: 748, top: 1216, turn: -10, size: 1 },
    { at: end - 0.1, left: 350, top: 1140, turn: 0, size: 1 },
  ];
  let i = 0;
  while (i < spots.length - 1 && t >= spots[i + 1].at) i++;
  const a = spots[Math.max(0, i - 1)];
  const b = spots[i];
  const p = i === 0 ? 1 : ramp(t, b.at, b.at + 0.5, inOut);
  const mix = (k: 'left' | 'top' | 'turn' | 'size') => a[k] + (b[k] - a[k]) * p;
  const rise = ramp(t, open + 0.1, open + 0.5, out);
  const events: { at: number; mood: Mood; stay?: boolean }[] = [
    { at: open, mood: 'happy' as Mood },
    { at: w2, mood: 'happy' as Mood, stay: true },
    ...fb.map((at) => ({ at, mood: 'idle' as Mood })),
    ...film.cheers.map((at) => ({ at, mood: 'happy' as Mood })),
    { at: all, mood: 'smug' as Mood, stay: true },
    { at: search, mood: 'idle' as Mood },
    { at: result, mood: 'cheeky' as Mood, stay: true },
    { at: now, mood: 'happy' as Mood },
    { at: get, mood: 'happy' as Mood, stay: true },
    { at: end + 0.75, mood: 'happy' as Mood, stay: true },
  ].sort((x, y) => x.at - y.at);
  const nowEvent = [...events].reverse().find((e) => t >= e.at);
  const age = nowEvent ? t - nowEvent.at : 9;
  const mood: Mood = nowEvent && (nowEvent.stay || age < 1.0) ? nowEvent.mood : 'idle';
  const hop = nowEvent && nowEvent.mood !== 'idle' && age < 0.6 ? Math.exp(-age * 7) * Math.sin(age * 17) : 0;
  const arc = Math.sin(PI * p) * (Math.abs(b.left - a.left) > 300 ? 150 : 60);
  return (
    <div style={{ position: 'absolute', left: mix('left'), top: mix('top') + (1 - rise) * 700 - hop * 30 - arc, transform: `rotate(${mix('turn') + hop * 3 + Math.sin(PI * p) * (b.left > a.left ? 14 : -14)}deg) scale(${mix('size')})`, transformOrigin: '50% 100%', filter: `drop-shadow(9px 9px 0 ${INK})` }}>
      <Mascot mood={mood} size={380} next />
    </div>
  );
};

export const Debut = ({ id }: { id: string }) => {
  const frameNo = useCurrentFrame();
  const film = useFilm(id);
  const { t, episode, s, timing, fb, until, allOn, search, end } = film;
  const smear = Math.min(22, Math.max(0, film.turning - 3) * 2);
  const phoneOn = t >= fb[0] - 0.25 && t < allOn + 0.36;
  const px = 540 + film.pose.x * K;
  const py = ROW - (film.pose.y - ((960 - ROW) / FOCAL) * (CAM_Z - PZ)) * K;

  return (
    <AbsoluteFill style={{ fontFamily: FONT, overflow: 'hidden', background: CREAM }}>
      <Html5Audio src={staticFile(`reels/${id}.mp3`)} />
      <svg width={0} height={0} style={{ position: 'absolute' }}>
        <defs>
          <filter id="spin" x="-30%" y="0" width="160%" height="100%">
            <feGaussianBlur stdDeviation={`${smear} 0`} />
          </filter>
        </defs>
      </svg>
      <AbsoluteFill style={{ transform: `translate(${film.knock * 0.5}px, ${film.knock}px)` }}>
        {t < fb[0] + 0.5 ? (
          <AbsoluteFill>
            <Headline film={film} />
          </AbsoluteFill>
        ) : null}
        {s.features.map((_, i) => (
          <Wipe key={i} t={t} at={fb[i]} x={i % 2 ? 120 : 960} y={i % 2 ? 1500 : 420} color={TINTS[i % TINTS.length].bg} until={until[i] + 0.5}>
            <FeatureWall film={film} i={i} />
          </Wipe>
        ))}
        {phoneOn ? (
          <>
            <div style={{ position: 'absolute', left: px - 150 + 22, top: py - 350 + 26, width: 300, height: 700, borderRadius: 60, background: 'rgba(20,16,10,0.36)', filter: 'blur(22px)', opacity: ramp(t, fb[0] + 0.1, fb[0] + 0.4) * (1 - ramp(t, allOn - 0.1, allOn + 0.1)) * (1 - Math.min(1, smear / 8)) }} />
            <AbsoluteFill style={{ filter: smear > 0.5 ? 'url(#spin)' : undefined }}>
              <ThreeCanvas width={1080} height={1920} dpr={1} gl={{ antialias: true, alpha: true, toneMapping: THREE.ACESFilmicToneMapping, toneMappingExposure: 0.95 }} camera={{ fov: FOV, near: 0.5, far: 60, position: [0, 0, CAM_Z] }}>
                <Stage id={id} />
              </ThreeCanvas>
            </AbsoluteFill>
            {s.features.map((_, i) => (
              <FeatureDemo key={i} film={film} i={i} />
            ))}
          </>
        ) : null}
        <Wipe t={t} at={allOn} x={540} y={900} color={CREAM} until={search + 0.5}>
          <AllHere film={film} />
        </Wipe>
        <Wipe t={t} at={search} x={120} y={420} color="#232A1C" until={end + 0.5}>
          <Search film={film} />
        </Wipe>
        <Wipe t={t} at={end} x={540} y={420} color={CREAM}>
          <EndCard film={film} />
        </Wipe>
        <Curtain film={film} />
        <Buddy film={film} />
      </AbsoluteFill>
      {episode.lines.map((line, i) => (
        <StickerCaption key={i} text={line.text} start={timing.slots[i].start} length={timing.slots[i].length} t={t} first={i === 0} label={episode.label} />
      ))}
      <Grain frame={frameNo} opacity={0.1} />
    </AbsoluteFill>
  );
};
