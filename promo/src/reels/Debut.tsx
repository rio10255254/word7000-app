import { ThreeCanvas } from '@remotion/three';
import { useThree } from '@react-three/fiber';
import type { CSSProperties, ReactNode } from 'react';
import { AbsoluteFill, Html5Audio, Img, staticFile, useCurrentFrame } from 'remotion';
import * as THREE from 'three';
import { FONT, SERIF, SERIF_TC } from '../fonts';
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
 * The dark of the last reel parts like a curtain on the words. Then one
 * colour and one giant word per feature, the phone spinning to the next
 * real screen on every beat; all four land together; free, forever; and
 * where to find it. Each scene wipes in as a circle of the next colour.
 */

const BEAT = 0.5;
const PI = Math.PI;
const CAM_Z = 9;
const FOV = 30;
const FOCAL = 960 / Math.tan(((FOV / 2) * PI) / 180);
/** Where the phone rests in the feature scenes: its centre's row on screen, and how far back it sits. */
const ROW = 1050;
const PZ = -0.5;

const INK = '#2B2620';
const CREAM = '#FBF6EA';
const CLAY = '#C96442';
const SAGE = '#6E8F5E';
const MUSTARD = '#E9BE55';
const NAVY = '#2B3A55';
const NIGHT = '#141A10';
const TINTS = [
  { bg: CLAY, fg: CREAM, dot: '#A94E30' },
  { bg: SAGE, fg: CREAM, dot: '#587649' },
  { bg: MUSTARD, fg: INK, dot: '#CFA238' },
  { bg: NAVY, fg: '#F8D9BC', dot: '#1F2B42' },
];
const hard = (n: number, color = INK) => `${n}px ${n}px 0 ${color}`;

type Crop = [number, number, number, number];
type Slot = { start: number; length: number };
type Word = { text: string; beat: number };
type Feature = { word: string; sub: string; screen: string; lift: Crop; beat: number; premium?: boolean };
type Scene = {
  wait: string;
  open: number;
  w1: Word;
  w2: Word;
  features: Feature[];
  all: Word;
  free: { head: string; sticker: Word; giant: Word; foot: string };
  search: { store: string; query: string; chars: number[]; now: Word; get: Word };
  badge: string;
  premium: string;
};
type Episode = { id: string; app: string; label: string; outro: string; lines: { text: string }[]; scene: Scene };
type Pose = { x: number; y: number; z: number; rx: number; ry: number; rz: number };
type Key = { at: number; pose: Pose; ease?: (n: number) => number };

const cjk = (text: string) => /[㐀-鿿]/.test(text);
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

const useFilm = (id: string) => {
  const t = useCurrentFrame() / REEL_FPS;
  const episode = script.episodes.find((e) => e.id === id)! as unknown as Episode;
  const s = episode.scene;
  const timing = (timings as Record<string, { total: number; end: number; slots: Slot[] }>)[id];
  const starts = timing.slots.map((slot) => slot.start);
  const at = (slot: number, beat: number) => starts[slot] + beat * BEAT;
  const end = timing.end;

  const open = at(0, s.open);
  const w1 = at(0, s.w1.beat);
  const w2 = at(0, s.w2.beat);
  const fb = s.features.map((f) => at(1, f.beat));
  const all = at(1, s.all.beat);
  const free = starts[2];
  const sticker = at(2, s.free.sticker.beat);
  const giant = at(2, s.free.giant.beat);
  const search = starts[3];
  const typed = s.search.chars.map((b) => at(3, b));
  const result = typed[typed.length - 1] + 0.3;
  const now = at(3, s.search.now.beat);
  const get = at(3, s.search.get.beat);

  // The phone: up into the first colour, a full turn to each next screen, and out when all four land.
  const y0 = ((960 - ROW) / FOCAL) * (CAM_Z - PZ);
  const rest: Pose[] = [
    { x: 0.2, y: y0, z: PZ, rx: 0.06, ry: -0.36, rz: 0.035 },
    { x: 0.13, y: y0, z: PZ, rx: 0.05, ry: 0.3, rz: -0.03 },
    { x: 0.2, y: y0, z: PZ, rx: 0.06, ry: -0.3, rz: 0.03 },
    { x: 0.13, y: y0, z: PZ, rx: 0.05, ry: 0.34, rz: -0.035 },
  ].map((p, i) => ({ ...p, ry: p.ry + PI * 2 * i }));
  const keys: Key[] = [{ at: starts[1] - 0.2, pose: { ...rest[0], y: -5, ry: rest[0].ry - 1.3, rz: 0.3, rx: 0.4 } }, { at: starts[1] + 0.35, pose: rest[0], ease: out }];
  for (let i = 1; i < rest.length; i++) {
    const before = rest[i - 1];
    keys.push({ at: fb[i] - 0.26, pose: { ...before, ry: before.ry + (i % 2 ? 0.07 : -0.07), z: before.z + 0.12 }, ease: (n) => n });
    keys.push({ at: fb[i] + 0.26, pose: rest[i], ease: inOut });
  }
  const last = rest[rest.length - 1];
  keys.push({ at: all - 0.12, pose: { ...last, ry: last.ry - 0.07, z: last.z + 0.12 }, ease: (n) => n });
  keys.push({ at: all + 0.3, pose: { ...last, y: -5.4, rz: -0.35, rx: 0.5 }, ease: (n) => n * n });
  const pose = poseAt(keys, t);
  const turning = Math.abs(pose.ry - poseAt(keys, t - 1 / REEL_FPS).ry) * REEL_FPS;
  const shown = fb.reduce((n, when, i) => (i > 0 && t >= when ? i : n), 0);
  const lifts = s.features.map((_, i) => {
    const from = i === 0 ? starts[1] + 0.5 : fb[i] + 0.34;
    const until = i + 1 < fb.length ? fb[i + 1] - 0.3 : all - 0.14;
    return 0.2 * ramp(t, from, from + 0.3, out) * (1 - ramp(t, until - 0.16, until, inOut));
  });

  const knocks: [number, number][] = [[w1, 16], [w2, 24], [all, 18], [sticker, 12], [giant, s.free.giant.beat > s.free.sticker.beat ? 24 : 18], [now, 16], [end + 0.75, 14]];
  const knock = knocks.reduce((k, [when, size]) => { const age = t - when; return age >= 0 && age < 0.3 ? k + Math.exp(-age * 15) * Math.cos(age * 62) * size : k; }, 0);
  return { t, episode, s, timing, starts, end, open, w1, w2, fb, all, free, sticker, giant, search, typed, result, now, get, pose, turning, shown, lifts, knock };
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

/** A piece of a real screenshot, fitted in a box. */
const Piece = ({ src, crop, w, h, radius = 26 }: { src: string; crop: Crop; w: number; h: number; radius?: number }) => {
  const [x0, y0, x1, y1] = crop;
  const k = Math.min(w / (x1 - x0), h / (y1 - y0));
  return (
    <div style={{ position: 'relative', width: (x1 - x0) * k, height: (y1 - y0) * k, overflow: 'hidden', borderRadius: radius, border: `5px solid ${INK}`, boxSizing: 'content-box', background: CREAM }}>
      <Img src={staticFile(`${src}.jpg`)} style={{ position: 'absolute', left: -x0 * k, top: -y0 * k, width: 1206 * k, height: 2622 * k, maxWidth: 'none' }} />
    </div>
  );
};

const Sticker = ({ children, bg, fg = INK, size, rotate = 0, pad = '0.16em 0.5em', shadow = 10, font }: { children: ReactNode; bg: string; fg?: string; size: number; rotate?: number; pad?: string; shadow?: number; font?: string }) => (
  <div style={{ display: 'inline-block', background: bg, color: fg, border: `6px solid ${INK}`, borderRadius: size * 0.34, padding: pad, fontFamily: font ?? FONT, fontWeight: 900, fontSize: size, lineHeight: 1.15, whiteSpace: 'nowrap', boxShadow: hard(shadow), transform: `rotate(${rotate}deg)` }}>{children}</div>
);

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
      <group position={[pose.x, pose.y + Math.sin(t * 1.7) * 0.014, pose.z]} rotation={[pose.rx + Math.sin(t * 1.1) * 0.01, pose.ry, pose.rz, 'YXZ']}>
        <Phone3D model={maps.phone} screen={maps.screens[film.shown]}>
          <ScreenLayer color="#2a2418" opacity={Math.min(1, film.lifts[film.shown] * 9) * 0.16} over />
          <Lift map={maps.screens[film.shown]} crop={f.lift} lift={film.lifts[film.shown]} ground={maps.ground[film.shown]} radius={40} />
        </Phone3D>
      </group>
    </>
  );
};

// ───────────────────────── scenes ─────────────────────────

/** The dark of the night reel, parting on the daylight. */
const Curtain = ({ film }: { film: Film }) => {
  const { t, s, open } = film;
  const p = ramp(t, open, open + 0.5, out);
  if (p >= 1) return null;
  const gap = 5 + t * 9 + p * 640;
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
  return (
    <>
      <Sunburst t={t} a="#FBF6EA" b="#F6E9C6" y={860} />
      <Dots color="rgba(201,100,66,0.14)" t={t} size={40} />
      <div style={{ position: 'absolute', left: 0, right: 0, top: 262, display: 'flex', justifyContent: 'center', alignItems: 'center', gap: 26, transform: `scale(${icon})`, opacity: Math.min(1, icon * 2) }}>
        <Img src={staticFile('icon-next.png')} style={{ width: 132, height: 132, borderRadius: 30, border: `5px solid ${INK}`, boxShadow: hard(8) }} />
        <Sticker bg={CREAM} size={50} shadow={8} font={cjk(episode.app) ? FONT : SERIF}>{episode.app}</Sticker>
      </div>
      <div style={{ position: 'absolute', left: 0, right: 0, top: wide ? 420 : 520, textAlign: 'center', lineHeight: 1 }}>
        <Chars text={s.w1.text} t={t} at={w1} style={{ fontFamily: wide ? FONT : SERIF, fontWeight: wide ? 900 : 800, fontSize: wide ? 340 : 210, color: INK, letterSpacing: wide ? '0.04em' : '-0.01em' }} />
      </div>
      <div style={{ position: 'absolute', left: 0, right: 0, top: wide ? 770 : 790, textAlign: 'center', lineHeight: 1 }}>
        <Chars text={s.w2.text} t={t} at={w2} from={3} style={{ fontFamily: wide ? FONT : SERIF, fontWeight: wide ? 900 : 800, fontSize: wide ? 340 : 270, color: CLAY, letterSpacing: wide ? '0.04em' : '-0.01em', textShadow: `${hard(12)}`, WebkitTextStroke: `5px ${INK}`, paintOrder: 'stroke fill' }} />
      </div>
      <Confetti t={t} at={w2 + 0.02} x={60} y={1500} aim={-PI / 3} seed={1} />
      <Confetti t={t} at={w2 + 0.02} x={1020} y={1500} aim={(-PI * 2) / 3} seed={2} />
    </>
  );
};

/** One feature: its colour, and its name as big as it will go. */
const FeatureWall = ({ film, i }: { film: Film; i: number }) => {
  const { t, s, fb, starts } = film;
  const f = s.features[i];
  const tint = TINTS[i];
  const at = i === 0 ? starts[1] : fb[i];
  const wide = cjk(f.word);
  const size = Math.min(wide ? 280 : 250, 940 / ([...f.word].length * (wide ? 1.02 : 0.6)));
  const slide = 1 - ramp(t, at - 0.05, at + 0.3, out);
  const side = i % 2 ? 1 : -1;
  return (
    <>
      <Dots color={tint.dot} t={t} />
      {/* The word again, hollow and huge, sliding past behind. */}
      <div style={{ position: 'absolute', left: -200, top: 980, width: 1480, textAlign: 'center', fontFamily: wide ? FONT : SERIF, fontWeight: wide ? 900 : 800, fontSize: size * 1.9, lineHeight: 1, whiteSpace: 'nowrap', color: 'transparent', WebkitTextStroke: `5px ${tint.dot}`, transform: `translateX(${(t - at) * -side * 46}px)` }}>{f.word}</div>
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
      <div style={{ position: 'absolute', left: 0, right: 0, top: 296, textAlign: 'center', lineHeight: 1.12, transform: `translateX(${slide * side * 700}px) skewX(${slide * side * -14}deg)` }}>
        <span style={{ fontFamily: wide ? FONT : SERIF, fontWeight: wide ? 900 : 800, fontSize: size, color: tint.fg, whiteSpace: 'nowrap', textShadow: hard(10, i === 2 ? CREAM : INK), letterSpacing: wide ? '0.03em' : '-0.01em' }}>{f.word}</span>
      </div>
    </>
  );
};

/** What each feature is, in a line, pinned under the phone's corner. */
const FeatureNote = ({ film }: { film: Film }) => {
  const { t, s, fb, starts, all } = film;
  return (
    <>
      {s.features.map((f, i) => {
        const at = (i === 0 ? starts[1] + 0.2 : fb[i]) + 0.42;
        const until = i + 1 < fb.length ? fb[i + 1] - 0.2 : all - 0.1;
        if (t < at || t > until) return null;
        const size = cjk(f.sub) ? 46 : 40;
        return (
          <div key={i} style={{ position: 'absolute', right: 44, top: 1296, display: 'flex', justifyContent: 'flex-end', transformOrigin: '80% 50%', transform: `scale(${pop(t, at) * (1 - ramp(t, until - 0.12, until, (n) => n))})` }}>
            <Sticker bg={CREAM} size={size} rotate={i % 2 ? 2 : -2} shadow={8}>{f.sub}</Sticker>
          </div>
        );
      })}
    </>
  );
};

/** All four at once: a wall of real pieces, and the words that close the list. */
const AllHere = ({ film }: { film: Film }) => {
  const { t, s, all } = film;
  const badge = slam(t, all + 0.4, 3);
  return (
    <>
      <Sunburst t={t} a="#FBF6EA" b="#F3E6C2" y={820} />
      {s.features.map((f, i) => {
        const hit = slam(t, all + i * 0.07, 1.8);
        const tint = TINTS[i];
        const col = i % 2;
        const row = Math.floor(i / 2);
        return (
          <div key={i} style={{ position: 'absolute', left: 44 + col * 506, top: 244 + row * 496, width: 486, height: 472, borderRadius: 40, background: tint.bg, border: `6px solid ${INK}`, boxShadow: hard(12), transform: `scale(${hit.scale}) rotate(${[-2.2, 1.8, 1.6, -1.9][i]}deg)`, opacity: hit.opacity, overflow: 'hidden' }}>
            <Dots color={tint.dot} t={t} size={28} />
            <div style={{ position: 'absolute', left: 0, right: 0, top: 22, height: 320, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
              <Piece src={f.screen} crop={f.lift} w={420} h={310} radius={22} />
            </div>
            <div style={{ position: 'absolute', left: 0, right: 0, bottom: 16, textAlign: 'center', fontFamily: cjk(f.word) ? FONT : SERIF, fontWeight: cjk(f.word) ? 900 : 800, fontSize: cjk(f.word) ? 76 : 70, lineHeight: 1.1, color: tint.fg, whiteSpace: 'nowrap', textShadow: hard(5, i === 2 ? CREAM : INK) }}>{f.word}</div>
          </div>
        );
      })}
      <div style={{ position: 'absolute', left: 250, right: 0, top: 1228, display: 'flex', justifyContent: 'center', transform: `scale(${badge.scale})`, opacity: badge.opacity }}>
        <Sticker bg={CREAM} size={cjk(s.all.text) ? 124 : 112} rotate={-4} shadow={14} font={cjk(s.all.text) ? FONT : SERIF}>{s.all.text}</Sticker>
      </div>
      <Confetti t={t} at={all + 0.42} x={660} y={1300} spread={PI * 1.2} power={1} count={46} seed={3} />
    </>
  );
};

/** Free, forever: the biggest word in the reel. */
const Free = ({ film }: { film: Film }) => {
  const { t, s, free, sticker, giant } = film;
  const g = slam(t, giant, 3.2);
  const st = slam(t, sticker, 2.6);
  const wide = cjk(s.free.giant.text);
  const stickerFirst = s.free.sticker.beat < s.free.giant.beat;
  const foot = pop(t, Math.max(giant, sticker) + 0.45);
  return (
    <>
      <Sunburst t={t} a="#F4D98A" b={MUSTARD} y={860} />
      <Dots color="rgba(43,38,32,0.08)" t={t} size={40} />
      <div style={{ position: 'absolute', left: 0, right: 0, top: 300, textAlign: 'center' }}>
        <Chars text={s.free.head} t={t} at={free + 0.12} from={1.8} style={{ fontFamily: wide ? FONT : SERIF, fontWeight: wide ? 900 : 800, fontSize: wide ? 150 : 124, color: INK, letterSpacing: wide ? '0.06em' : '0' }} />
      </div>
      <div style={{ position: 'absolute', left: 0, right: 0, top: wide ? 610 : 640, textAlign: 'center', lineHeight: 1, transform: `scale(${g.scale}) rotate(-3deg)`, opacity: g.opacity }}>
        <span style={{ fontFamily: wide ? FONT : SERIF, fontWeight: 900, fontSize: wide ? 470 : 360, color: CLAY, whiteSpace: 'nowrap', WebkitTextStroke: `7px ${INK}`, paintOrder: 'stroke fill', textShadow: hard(16), letterSpacing: wide ? '0.02em' : '-0.01em' }}>{s.free.giant.text}</span>
      </div>
      <div style={{ position: 'absolute', left: stickerFirst ? 96 : undefined, right: stickerFirst ? undefined : 70, top: stickerFirst ? 500 : 1010, transform: `scale(${st.scale})`, opacity: st.opacity }}>
        <Sticker bg={SAGE} fg={CREAM} size={wide ? 140 : 132} rotate={stickerFirst ? -9 : -7} shadow={12} font={wide ? FONT : SERIF}>{s.free.sticker.text}</Sticker>
      </div>
      <div style={{ position: 'absolute', left: stickerFirst ? 50 : undefined, right: stickerFirst ? undefined : 50, top: stickerFirst ? 1262 : 1290, transformOrigin: '50% 50%', transform: `scale(${foot})` }}>
        <Sticker bg={INK} fg="#FFE7B0" size={cjk(s.free.foot) ? 33 : 29} shadow={0} pad="0.4em 0.9em">{s.free.foot}</Sticker>
      </div>
      <Confetti t={t} at={Math.max(giant, sticker) + 0.02} x={540} y={900} spread={PI * 2} power={0.9} count={44} seed={4} />
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
      {/* Light behind the result. */}
      <div style={{ position: 'absolute', left: 540 - 1300, top: 880 - 1300, width: 2600, height: 2600, borderRadius: '50%', background: 'repeating-conic-gradient(rgba(233,190,85,0.2) 0deg 7deg, rgba(233,190,85,0) 7deg 14deg)', maskImage: 'radial-gradient(closest-side, #000 20%, transparent 62%)', WebkitMaskImage: 'radial-gradient(closest-side, #000 20%, transparent 62%)', transform: `rotate(${t * 8}deg) scale(${ray})`, opacity: ray }} />
      <div style={{ position: 'absolute', left: 0, right: 0, top: 250, textAlign: 'center', fontFamily: SERIF, fontWeight: 800, fontSize: 60, color: '#FFE7B0', letterSpacing: '0.04em', opacity: ramp(t, search + 0.1, search + 0.4) }}>{s.search.store}</div>
      <div style={{ position: 'absolute', left: 70, top: 356, width: 940, height: 150, borderRadius: 75, background: CREAM, border: `6px solid ${INK}`, boxShadow: hard(12, MUSTARD), transform: `scale(${bar})`, display: 'flex', alignItems: 'center', padding: '0 46px', gap: 30, boxSizing: 'border-box' }}>
        <svg width={64} height={64} viewBox="0 0 64 64">
          <circle cx={27} cy={27} r={19} fill="none" stroke={INK} strokeWidth={8} />
          <path d="M42 42 L58 58" stroke={INK} strokeWidth={9} strokeLinecap="round" />
        </svg>
        <span style={{ fontFamily: cjk(s.search.query) ? FONT : SERIF, fontWeight: cjk(s.search.query) ? 900 : 800, fontSize: 80, color: INK, whiteSpace: 'pre', lineHeight: 1 }}>
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
            <div key={i} style={{ fontFamily: cjk(part) ? FONT : SERIF, fontWeight: cjk(part) ? 900 : 800, fontSize: cjk(part) ? 72 : 80, lineHeight: 1.18, color: INK, whiteSpace: 'nowrap' }}>{part}</div>
          ))}
        </div>
        <div style={{ position: 'absolute', right: 50, bottom: 50, transform: `scale(${1 + press})` }}>
          <Sticker bg={CLAY} fg={CREAM} size={58} shadow={t >= get && t - get < 0.1 ? 2 : 8} pad="0.2em 0.9em" font={cjk(s.search.get.text) ? FONT : SERIF}>{s.search.get.text}</Sticker>
        </div>
      </div>
      <div style={{ position: 'absolute', left: 0, right: 0, top: 1048, textAlign: 'center', lineHeight: 1, transform: `scale(${cta.scale}) rotate(-3deg)`, opacity: cta.opacity }}>
        <span style={{ fontFamily: wide ? FONT : SERIF, fontWeight: 900, fontSize: wide ? 176 : 164, color: MUSTARD, whiteSpace: 'nowrap', WebkitTextStroke: `5px ${INK}`, paintOrder: 'stroke fill', textShadow: hard(12, CLAY), letterSpacing: wide ? '0.02em' : '-0.01em' }}>{s.search.now.text}</span>
      </div>
      {t >= get && t - get < 0.6 ? <div style={{ position: 'absolute', left: 840 - 200, top: 896 - 200, width: 400, height: 400, borderRadius: '50%', border: `10px solid ${MUSTARD}`, transform: `scale(${ramp(t, get, get + 0.5, out) * 1.5})`, opacity: 1 - ramp(t, get, get + 0.6, (n) => n) }} /> : null}
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

/** 傻貓, on screen from the moment the curtain parts to the last frame, moving between scenes rather than cutting. */
const Buddy = ({ film }: { film: Film }) => {
  const { t, s, open, w2, fb, starts, all, free, giant, sticker, search, result, now, get, end } = film;
  if (t < open + 0.1) return null;
  const spots: { at: number; left: number; top: number; turn: number }[] = [
    { at: open + 0.1, left: 350, top: 1150, turn: 0 },
    { at: starts[1] - 0.1, left: -70, top: 1096, turn: 12 },
    { at: all - 0.05, left: -96, top: 1206, turn: 10 },
    { at: free - 0.1, left: s.free.sticker.beat < s.free.giant.beat ? 720 : -80, top: 1120, turn: s.free.sticker.beat < s.free.giant.beat ? -10 : 10 },
    { at: search - 0.1, left: 748, top: 1216, turn: -10 },
    { at: end - 0.1, left: 350, top: 1140, turn: 0 },
  ];
  let i = 0;
  while (i < spots.length - 1 && t >= spots[i + 1].at) i++;
  const a = spots[Math.max(0, i - 1)];
  const b = spots[i];
  const p = i === 0 ? 1 : ramp(t, b.at, b.at + 0.5, inOut);
  const rise = ramp(t, open + 0.1, open + 0.5, out);
  const events: { at: number; mood: Mood; stay?: boolean }[] = [{ at: open, mood: 'happy' }, { at: w2, mood: 'happy', stay: true }, ...fb.map((at) => ({ at: at + 0.1, mood: 'happy' as Mood })), { at: all, mood: 'smug' as Mood, stay: true }, { at: free, mood: 'idle' }, { at: Math.max(giant, sticker), mood: 'smug', stay: true }, { at: search, mood: 'idle' }, { at: result, mood: 'cheeky', stay: true }, { at: now, mood: 'happy' }, { at: get, mood: 'happy', stay: true }, { at: end + 0.75, mood: 'happy', stay: true }];
  const nowEvent = [...events].reverse().find((e) => t >= e.at);
  const age = nowEvent ? t - nowEvent.at : 9;
  const mood: Mood = nowEvent && (nowEvent.stay || age < 0.8) ? nowEvent.mood : 'idle';
  const hop = age < 0.6 ? Math.exp(-age * 7) * Math.sin(age * 17) : 0;
  const arc = Math.sin(PI * p) * 90;
  return (
    <div style={{ position: 'absolute', left: a.left + (b.left - a.left) * p, top: a.top + (b.top - a.top) * p + (1 - rise) * 700 - hop * 30 - arc, transform: `rotate(${a.turn + (b.turn - a.turn) * p + hop * 3}deg)`, transformOrigin: '50% 100%', filter: `drop-shadow(9px 9px 0 ${INK})` }}>
      <Mascot mood={mood} size={380} next />
    </div>
  );
};

export const Debut = ({ id }: { id: string }) => {
  const frameNo = useCurrentFrame();
  const film = useFilm(id);
  const { t, episode, s, timing, starts, fb, all, free, search, end } = film;
  const smear = Math.min(22, Math.max(0, film.turning - 3) * 2);
  const phoneOn = t >= starts[1] - 0.25 && t < all + 0.36;

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
        {t < starts[1] + 0.5 ? (
          <AbsoluteFill>
            <Headline film={film} />
          </AbsoluteFill>
        ) : null}
        {s.features.map((_, i) => (
          <Wipe key={i} t={t} at={i === 0 ? starts[1] : fb[i]} x={i % 2 ? 120 : 960} y={i % 2 ? 1500 : 420} color={TINTS[i].bg} until={(i + 1 < fb.length ? fb[i + 1] : all) + 0.5}>
            <FeatureWall film={film} i={i} />
          </Wipe>
        ))}
        {phoneOn ? (
          <>
            <div style={{ position: 'absolute', left: 540 + film.pose.x * 377 - 180 + 26, top: ROW - (film.pose.y - ((960 - ROW) / FOCAL) * (CAM_Z - PZ)) * 377 - 390 + 30, width: 360, height: 780, borderRadius: 70, background: 'rgba(20,16,10,0.34)', filter: 'blur(26px)', opacity: ramp(t, starts[1] + 0.1, starts[1] + 0.4) * (1 - ramp(t, all - 0.1, all + 0.1)) }} />
            <AbsoluteFill style={{ filter: smear > 0.5 ? 'url(#spin)' : undefined }}>
              <ThreeCanvas width={1080} height={1920} dpr={1} gl={{ antialias: true, alpha: true, toneMapping: THREE.ACESFilmicToneMapping, toneMappingExposure: 0.95 }} camera={{ fov: FOV, near: 0.5, far: 60, position: [0, 0, CAM_Z] }}>
                <Stage id={id} />
              </ThreeCanvas>
            </AbsoluteFill>
            <FeatureNote film={film} />
          </>
        ) : null}
        <Wipe t={t} at={all} x={540} y={900} color={CREAM} until={free + 0.5}>
          <AllHere film={film} />
        </Wipe>
        <Wipe t={t} at={free} x={960} y={1500} color={MUSTARD} until={search + 0.5}>
          <Free film={film} />
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
