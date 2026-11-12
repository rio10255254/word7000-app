import { ThreeCanvas } from '@remotion/three';
import { useThree } from '@react-three/fiber';
import { AbsoluteFill, Easing, Html5Audio, interpolate, staticFile, useCurrentFrame } from 'remotion';
import * as THREE from 'three';
import { FONT, SERIF, SERIF_TC } from '../fonts';
import script from './episodes.json';
import timings from './timing.json';
import { REEL_FPS } from './Reel';
import { Caption } from './Intro';
import { ABOVE_CAPTIONS, CAPTION_TOP } from './Teaser';
import { StampCard } from './Countdown';
import { Burst, DeepBackdrop, Foreground, Grade, InkFilters, Motes } from './finish';
import { Mascot, type Mood } from '../Mascot';
import { Lift, PHONE, colorAt, Phone3D, ScreenLayer, StudioLight, imageTexture, inOut, loadPhone, loadStudio, onScreen, out, ramp, usePrepared } from './three/kit';
import { IconTile } from './three/objects';
import { Slip } from './Day1';

/**
 * 11/16, launch day.
 *
 * Cover: "out now" stamped on the card, the whole cat in front of it for
 * once. The phone comes up and goes round once for each thing the week
 * showed, landing on its screen as the cat names it, a piece of that
 * screen jumping off the glass and its name slapped down beside it:
 * plans, swiping, speaking, scanning, the tutor, the stamp. "All in
 * here": the phone steps back and the six names land round it. Then the
 * two ways to use it: the phone turns to the classic Today, and a second
 * phone slides out from behind it with easy mode; they stand side by side
 * like an open book, each under its name. They part, and the app's icon
 * comes tumbling in as a thick glossy tile: free to study, on the App
 * Store now. The end card builds under the icon: "out now" stamped on the
 * sound logo's chord, and where to get it.
 *
 * Every screen is the app's own; the icon tile and the paper are props.
 */

const BEAT = 0.5;
const PI = Math.PI;
const CAM_Z = 9;
const FOV = 30;
const FOCAL = 960 / Math.tan(((FOV / 2) * PI) / 180);
const MID = ((960 - 825) / FOCAL) * CAM_Z;
const CLAY = '#C96442';

type Slot = { start: number; length: number };
type Crop = [number, number, number, number];
type Stop = { screen: string; lift: Crop; beat: number; label: string; premium?: boolean; round?: boolean };
type Mode = { screen: string; lift: Crop; tag: string; sub: string; beat: number; outBeat?: number };
type Scene = {
  stampWord: string;
  stampNote: string;
  recap: Stop[];
  allBeat: number;
  classic: Mode;
  easy: Mode;
  free: [string, string];
  freeBeat: number;
  storeBeat: number;
  nowBeat: number;
  nowText: string;
  premium: string;
  desk: [string, number, number, number, number][];
};
type Episode = { id: string; app: string; label: string; outro: string; captionSize?: number; lines: { text: string; parts?: [string, number][] }[]; scene: Scene };
type Pose = { x: number; y: number; z: number; rx: number; ry: number; rz: number };
type Key = { at: number; pose: Pose; ease?: (n: number) => number };

const poseAt = (keys: Key[], t: number): Pose => {
  let i = 0;
  while (i < keys.length - 1 && t >= keys[i + 1].at) i++;
  const a = keys[i];
  const b = keys[Math.min(i + 1, keys.length - 1)];
  const p = a === b ? 0 : (b.ease ?? inOut)(Math.min(1, Math.max(0, (t - a.at) / (b.at - a.at))));
  const m = (k: keyof Pose) => a.pose[k] + (b.pose[k] - a.pose[k]) * p;
  return { x: m('x'), y: m('y'), z: m('z'), rx: m('rx'), ry: m('ry'), rz: m('rz') };
};
const matrixOf = (q: Pose) => new THREE.Matrix4().makeTranslation(q.x, q.y, q.z).multiply(new THREE.Matrix4().makeRotationFromEuler(new THREE.Euler(q.rx, q.ry, q.rz, 'YXZ')));
const projectWith = (q: Pose, x: number, y: number, lift = 0.004) => {
  const v = new THREE.Vector3(...onScreen(x, y, lift)).applyMatrix4(matrixOf(q));
  const k = FOCAL / (CAM_Z - v.z);
  return { x: 540 + v.x * k, y: 960 - v.y * k };
};
const upright = (y: number, row: number, z: number) => ((960 - row) / FOCAL) * (CAM_Z - z) - (0.5 - y / 2622) * PHONE.h;

/** Where the icon rests, and how big: the same place the end card keeps it. */
const ICON = { row: 440, size: 0.82 };
/** Where the six names land round the phone. */
const ROUND: [number, number, number][] = [
  [150, 452, -5],
  [138, 716, 4],
  [156, 980, -3],
  [930, 436, 5],
  [942, 700, -4],
  [926, 964, 3],
];

const useFilm = (id: string) => {
  const t = useCurrentFrame() / REEL_FPS;
  const episode = script.episodes.find((e) => e.id === id)! as unknown as Episode;
  const s = episode.scene;
  const timing = (timings as Record<string, { total: number; end: number; slots: Slot[] }>)[id];
  const starts = timing.slots.map((slot) => slot.start);
  const [, recap, modes, store] = starts;
  const end = timing.end;
  const at = (slot: number, beat: number) => starts[slot] + beat * BEAT;

  const coverOut = recap - 1.0;
  const rise = recap - 0.9;
  const stops = s.recap.map((stop) => at(1, stop.beat));
  const spin = (i: number) => Math.min(0.5, stops[i] - stops[i - 1] - 0.16);
  const all = at(1, s.allBeat);
  const classicTag = at(2, s.classic.beat);
  const easyOut = at(2, s.easy.outBeat ?? 5);
  const easyTag = at(2, s.easy.beat);
  const part = store - 0.15;
  const iconIn = store - 0.05;
  const freeAt = at(3, s.freeBeat);
  const storeAt = at(3, s.storeBeat);
  const nowAt = at(3, s.nowBeat);

  // The phone that shows the week: round once to each stop.
  const side = (i: number) => (i % 2 ? -1 : 1);
  const stopPose = (i: number): Pose => {
    const z = 3.2 + (i % 3) * 0.12;
    const [, y0, , y1] = s.recap[i].lift;
    return { x: -side(i) * 0.1, y: upright(Math.min(1500, Math.max(900, (y0 + y1) / 2)), 800, z), z, rx: 0.07, ry: PI * 2 * (i + 1) + side(i) * 0.36, rz: side(i) * 0.012 };
  };
  const last = s.recap.length - 1;
  const turned = PI * 2 * (last + 1);
  const alone: Pose = { x: 0.0, y: upright(1700, 830, 2.3), z: 2.3, rx: 0.08, ry: turned + 0.44, rz: -0.015 };
  const pairA: Pose = { x: -0.57, y: upright(1311, 810, 0.9), z: 0.9, rx: 0.04, ry: turned + 0.3, rz: 0.008 };
  const pairB: Pose = { x: 0.57, y: upright(1311, 810, 0.9), z: 0.9, rx: 0.04, ry: -0.3, rz: -0.008 };
  const keysA: Key[] = [
    { at: rise, pose: { x: 0.9, y: -5.4, z: 0, rx: 0.5, ry: PI + 0.9, rz: 0.25 } },
    { at: stops[0], pose: stopPose(0), ease: out },
    ...s.recap.slice(1).flatMap((_, n) => {
      const i = n + 1;
      const from = stopPose(i - 1);
      return [
        { at: stops[i] - spin(i), pose: { ...from, ry: from.ry - side(i - 1) * 0.08 }, ease: (v: number) => v },
        { at: stops[i], pose: stopPose(i), ease: inOut },
      ];
    }),
    { at: all - 0.05, pose: { ...stopPose(last), ry: stopPose(last).ry - side(last) * 0.06 }, ease: (v) => v },
    // "All in here": it steps back to make room for the six names.
    { at: all + 0.55, pose: { x: 0, y: upright(1311, 800, 1.3), z: 1.3, rx: 0.04, ry: turned, rz: 0 }, ease: inOut },
    { at: modes - 0.1, pose: { x: 0, y: upright(1311, 800, 1.35), z: 1.35, rx: 0.04, ry: turned + 0.08, rz: 0 }, ease: (v) => v },
    // The classic Today, close.
    { at: modes + 0.6, pose: alone, ease: inOut },
    { at: easyOut, pose: { ...alone, ry: alone.ry - 0.1 }, ease: (v) => v },
    // …and aside, as the other phone comes out from behind it.
    { at: easyOut + 0.65, pose: pairA, ease: inOut },
    { at: part, pose: { ...pairA, ry: pairA.ry - 0.05 }, ease: (v) => v },
    { at: part + 0.6, pose: { x: -3.4, y: MID - 0.6, z: -6, rx: 0.25, ry: turned - 2.0, rz: -0.25 }, ease: (v) => v * v },
  ];
  const keysB: Key[] = [
    { at: easyOut, pose: { ...alone, z: alone.z - 0.4, ry: 0.34, y: alone.y } },
    { at: easyOut + 0.65, pose: pairB, ease: inOut },
    { at: part, pose: { ...pairB, ry: pairB.ry + 0.05 }, ease: (v) => v },
    { at: part + 0.6, pose: { x: 3.4, y: MID - 0.6, z: -6, rx: 0.25, ry: 2.0, rz: 0.25 }, ease: (v) => v * v },
  ];
  // Phone A's turns are counted from zero for the other phone to match: its screen faces us at any multiple of 2π.
  const a = poseAt(keysA, t);
  const b = poseAt(keysB, t);
  const before = poseAt(keysA, t - 1 / REEL_FPS);
  const turning = Math.abs(a.ry - before.ry) * REEL_FPS;
  // Which stop's screen is on: it changes while the back is to us.
  let shown = 0;
  for (let i = 1; i <= last; i++) if (t >= stops[i] - spin(i) / 2) shown = i;
  const onModes = t >= modes + 0.3;
  const up = (when: number, until: number, depth: number, hop = 0.3) => (t < when ? 0 : (depth + hop * Math.exp(-(t - when) * 7) * Math.abs(Math.cos((t - when) * 9))) * ramp(t, when, when + 0.12, out) * (1 - ramp(t, until - 0.22, until, inOut)));
  const lifts = {
    stop: s.recap.map((_, i) => up(stops[i] + 0.04, i < last ? stops[i + 1] - spin(i + 1) + 0.05 : all + 0.1, 0.3, 0.3)),
    classic: up(classicTag - 0.25, part + 0.1, 0.22, 0.25),
    easy: up(easyTag - 0.25, part + 0.1, 0.22, 0.25),
  };
  const knocks: [number, number][] = [...stops.map((when) => [when, 4] as [number, number]), [all + 0.2, 8], [classicTag, 6], [easyTag, 6], [iconIn + 0.6, 9], [freeAt, 6], [nowAt, 5], [end + 0.75, 6]];
  const knock = knocks.reduce((k, [when, size]) => { const age = t - when; return age >= 0 && age < 0.32 ? k + Math.exp(-age * 14) * Math.cos(age * 60) * size : k; }, 0);
  const shadowOf = (q: Pose) => {
    const c = projectWith(q, 603, 1311);
    const size = (FOCAL / (CAM_Z - q.z)) * 0.8;
    return { x: c.x, y: c.y, w: Math.max(60, PHONE.w * size * Math.abs(Math.cos(q.ry))), h: PHONE.h * size };
  };
  const glare = [stops[0] - 0.1, all + 0.5, modes + 0.6, easyOut + 0.65].reduce((g, start) => (t >= start && t < start + 0.9 ? (t - start) / 0.9 : g), -1);
  return { t, episode, s, timing, at, end, coverOut, rise, stops, all, modes, classicTag, easyOut, easyTag, part, iconIn, freeAt, storeAt, nowAt, a, b, turning, shown, onModes, lifts, knock, shadowOf, glare, last, side };
};
type Film = ReturnType<typeof useFilm>;

const Stage = ({ id }: { id: string }) => {
  const gl = useThree((state) => state.gl);
  const film = useFilm(id);
  const { t, s, a, b } = film;
  const maps = usePrepared(async () => {
    const [recap, classic, easy, icon, env, phoneA, phoneB] = await Promise.all([Promise.all(s.recap.map((stop) => imageTexture(`${stop.screen}.jpg`))), imageTexture(`${s.classic.screen}.jpg`), imageTexture(`${s.easy.screen}.jpg`), imageTexture('icon-next.png'), loadStudio(gl), loadPhone(), loadPhone()]);
    const beside = (tex: THREE.Texture, c: Crop, round?: boolean) => (round ? colorAt(tex, c[0] + 14, c[1] + 14) : colorAt(tex, Math.max(4, c[0] - 16), c[1] + 30));
    return { recap, classic, easy, icon, env, phoneA, phoneB, ground: { recap: s.recap.map((stop, i) => beside(recap[i], stop.lift, stop.round)), classic: beside(classic, s.classic.lift), easy: colorAt(easy, s.easy.lift[0] + 6, s.easy.lift[1] + 6) } };
  });
  if (!maps) return null;
  const phones = t >= film.rise - 0.05 && t < film.part + 0.65;
  const stop = s.recap[film.shown];

  // The icon: in from far off, turning over, to rest where the end card keeps it.
  const arrive = ramp(t, film.iconIn, film.iconIn + 0.7, out);
  const landed = t - (film.iconIn + 0.6);
  const bounce = landed >= 0 && landed < 0.6 ? Math.exp(-landed * 8) * Math.cos(landed * 20) * 0.07 : 0;
  const flourish = ramp(t, film.nowAt - 0.05, film.nowAt + 0.6, inOut);
  const stamped = t - (film.end + 0.75);
  const jolt = stamped >= 0 && stamped < 0.4 ? Math.exp(-stamped * 10) * Math.cos(stamped * 40) * 0.05 : 0;
  const iconY = ((960 - ICON.row) / FOCAL) * CAM_Z;

  return (
    <>
      <StudioLight env={maps.env} turn={t * 0.12 + a.ry * 0.25} />
      {phones ? (
        <>
          {t >= film.easyOut - 0.02 ? (
            <group position={[b.x, b.y + Math.sin(t * 1.2 + 1) * 0.012, b.z]} rotation={[b.rx, b.ry, b.rz, 'YXZ']}>
              <Phone3D model={maps.phoneB} screen={maps.easy} glare={film.glare}>
                <Lift map={maps.easy} crop={s.easy.lift} lift={film.lifts.easy} ground={maps.ground.easy} radius={60} />
              </Phone3D>
            </group>
          ) : null}
          <group position={[a.x, a.y + Math.sin(t * 1.3) * 0.012, a.z]} rotation={[a.rx + Math.sin(t * 0.9) * 0.008, a.ry, a.rz, 'YXZ']}>
            <Phone3D model={maps.phoneA} screen={film.onModes ? maps.classic : maps.recap[film.shown]} glare={film.glare}>
              {film.onModes ? (
                <Lift map={maps.classic} crop={s.classic.lift} lift={film.lifts.classic} ground={maps.ground.classic} radius={30} />
              ) : (
                <>
                  <ScreenLayer color="#2a2418" opacity={Math.min(1, film.lifts.stop[film.shown] * 2.2) * 0.16} over />
                  <Lift map={maps.recap[film.shown]} crop={stop.lift} lift={film.lifts.stop[film.shown]} ground={maps.ground.recap[film.shown]} radius={stop.round ? (stop.lift[2] - stop.lift[0]) / 2 : 40} />
                </>
              )}
            </Phone3D>
          </group>
        </>
      ) : null}
      {arrive > 0 ? (
        <group position={[0, iconY - (1 - arrive) * 2.6 + jolt, -(1 - arrive) * 16]} rotation={[(1 - arrive) * PI * 2 + Math.sin(t * 0.7 + 1) * 0.09, (1 - arrive) * PI * 3 + flourish * PI * 2 + Math.sin(t * 0.9) * 0.26, Math.sin(t * 0.5) * 0.03]} scale={ICON.size * (1 + bounce)}>
          <IconTile map={maps.icon} />
        </group>
      ) : null}
    </>
  );
};

/** "Out now", as the countdown's stamp was the days left. */
const LaunchStamp = ({ word, note }: { word: string; note: string }) => {
  const cjk = /[㐀-鿿]/.test(word);
  return (
    <div style={{ filter: 'url(#ink)', border: `9px solid ${CLAY}`, borderRadius: 30, padding: '14px 50px 18px', color: CLAY, display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
      <div style={{ fontFamily: cjk ? SERIF_TC : SERIF, fontWeight: cjk ? 900 : 800, fontSize: cjk ? 150 : 124, lineHeight: 1.05, letterSpacing: cjk ? '0.06em' : '0.02em', whiteSpace: 'nowrap' }}>{word}</div>
      <div style={{ alignSelf: 'stretch', height: 4, background: CLAY, margin: '12px 4px 12px', borderRadius: 2 }} />
      <div style={{ fontWeight: 900, fontSize: 30, letterSpacing: '0.2em', lineHeight: 1, paddingLeft: '0.2em', whiteSpace: 'nowrap' }}>{note}</div>
    </div>
  );
};

/** A feature's name on a slip, with a star if it is part of Premium. */
const Name = ({ stop, premium, small = false }: { stop: Stop; premium: string; small?: boolean }) => (
  <span style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', lineHeight: 1.1 }}>
    <span style={{ fontFamily: FONT, fontWeight: 900, fontSize: small ? 58 : 72, color: '#2B2620' }}>{stop.label}</span>
    {stop.premium ? (
      <span style={{ fontFamily: SERIF, fontWeight: 800, fontSize: small ? 24 : 30, color: '#B8860B', marginTop: 2 }}>★ {premium}</span>
    ) : null}
  </span>
);

/** 傻貓 in the corner while the phones have the stage. */
const Buddy = ({ film }: { film: Film }) => {
  const { t } = film;
  const arrive = film.at(1, 0.6);
  if (t < arrive) return null;
  const inP = ramp(t, arrive, arrive + 0.5, out) * (1 - ramp(t, film.part - 0.1, film.part + 0.3, inOut));
  if (inP <= 0) return null;
  const events: { at: number; mood: Mood }[] = [...film.stops.map((when, i) => ({ at: when, mood: (i % 2 ? 'cheeky' : 'happy') as Mood })), { at: film.all + 0.2, mood: 'happy' }, { at: film.classicTag, mood: 'cheeky' }, { at: film.easyTag, mood: 'happy' }];
  const now = [...events].reverse().find((e) => t >= e.at);
  const age = now ? t - now.at : 9;
  const mood: Mood = now && age < 0.7 ? now.mood : 'smug';
  const hop = age < 0.6 ? Math.exp(-age * 7) * Math.sin(age * 17) : 0;
  return (
    <div style={{ position: 'absolute', left: -96 - (1 - inP) * 360, top: 1068 - hop * 30, transform: `rotate(${13 + hop * 3}deg)`, transformOrigin: '30% 100%', filter: 'drop-shadow(0 18px 20px rgba(30,34,14,0.34))' }}>
      <Mascot mood={mood} size={400} next />
    </div>
  );
};

const Shadow = ({ at, opacity }: { at: { x: number; y: number; w: number; h: number }; opacity: number }) => (
  <div style={{ position: 'absolute', left: at.x - at.w / 2, top: at.y - at.h / 2 + 34, width: at.w, height: at.h, borderRadius: at.w * 0.3, background: 'rgba(28,32,12,0.3)', boxShadow: '0 30px 70px 34px rgba(28,32,12,0.3)', opacity, ...ABOVE_CAPTIONS }} />
);

export const Launch = ({ id }: { id: string }) => {
  const frameNo = useCurrentFrame();
  const film = useFilm(id);
  const { t, episode, s, timing, end } = film;

  const stamp = <LaunchStamp word={s.stampWord} note={s.stampNote} />;
  const tip = ramp(t, film.coverOut - 0.12, film.coverOut + 0.38, inOut);
  const smear = Math.min(26, Math.max(0, film.turning - 2.5) * 2.4);
  const phonesOut = ramp(t, film.part, film.part + 0.5, inOut);
  const lit = ramp(t, film.coverOut, film.coverOut + 0.8, (n) => n);
  const drift = (film.a.y - MID) * 200 * (1 - phonesOut) + film.a.x * 300 * (1 - phonesOut);
  // The cat in front of its card, for once all of it.
  const hello = t - 0.6;
  const jump = hello >= 0 && hello < 0.7 ? Math.sin((hello / 0.7) * PI) * 90 : 0;
  // The end card under the icon.
  const nameIn = ramp(t, film.storeAt, film.storeAt + 0.45, inOut);
  const tidy = ramp(t, end - 0.1, end + 0.25, inOut);
  const cta = interpolate(t, [end + 1.45, end + 1.75], [0, 1], { extrapolateLeft: 'clamp', extrapolateRight: 'clamp', easing: Easing.bezier(0.16, 1, 0.3, 1) });
  const over = ramp(t, end + 1.05, end + 1.45, Easing.out(Easing.back(1.8)));
  const iconPx = { x: 540, y: 440 };
  const classicAt = { x: 300 - 20 * ramp(t, film.easyOut, film.easyOut + 0.65, inOut), y: 292 };

  return (
    <AbsoluteFill style={{ fontFamily: FONT, overflow: 'hidden' }}>
      <Html5Audio src={staticFile(`reels/${id}.mp3`)} />
      <InkFilters />
      <svg width={0} height={0} style={{ position: 'absolute' }}>
        <defs>
          <filter id="smear" x="-20%" y="0" width="140%" height="100%">
            <feGaussianBlur stdDeviation={`${smear} 0`} />
          </filter>
        </defs>
      </svg>
      <DeepBackdrop t={t} frame={frameNo} drift={drift} focus={lit} cards={s.desk.map(([src, x, y, w, h]) => (src ? { src: `${src}.jpg`, crop: [x, y, w, h] as [number, number, number, number] } : {}))} />
      <AbsoluteFill style={{ background: `radial-gradient(70% 46% at 50% 42%, rgba(255,244,214,${0.2 * lit}) 0%, rgba(255,244,214,0) 70%), radial-gradient(120% 90% at 50% 42%, rgba(0,0,0,0) 45%, rgba(26,30,12,${0.42 * lit * (1 - 0.5 * phonesOut)}) 100%)` }} />
      <Motes t={t} />

      {/* The cover: out now, and the cat itself. */}
      {tip < 1 ? (
        <>
          <div style={{ position: 'absolute', inset: 0, opacity: 1 - tip * tip, transform: `perspective(1400px) translateY(${-tip * 420}px) translateZ(${-tip * 500}px) rotateX(${tip * 70}deg)`, transformOrigin: '50% 22%' }}>
            <StampCard t={t} at={0} stampAt={0} top={300}>
              {stamp}
            </StampCard>
          </div>
          <div style={{ position: 'absolute', left: 540 - 270, top: 740 - jump + tip * 1300, transform: `rotate(${Math.sin(hello * 9) * (jump > 0 ? 3 : 0)}deg)`, filter: 'drop-shadow(0 26px 30px rgba(30,34,14,0.34))' }}>
            <Mascot mood={hello >= 0 && hello < 1.2 ? 'happy' : 'cheeky'} size={540} next sparkles={hello >= 0.2} />
          </div>
        </>
      ) : null}

      {/* The phones' shadows on the backdrop. */}
      {lit > 0 && phonesOut < 1 && t >= film.rise + 0.4 ? (
        <>
          <Shadow at={film.shadowOf(film.a)} opacity={lit * (1 - phonesOut)} />
          {t >= film.easyOut + 0.3 ? <Shadow at={film.shadowOf(film.b)} opacity={ramp(t, film.easyOut + 0.3, film.easyOut + 0.65) * (1 - phonesOut)} /> : null}
        </>
      ) : null}

      {/* The phones, and the icon. */}
      {t >= film.rise - 0.2 ? (
        <AbsoluteFill style={{ transform: `translateY(${film.knock}px)`, ...(t < film.iconIn ? ABOVE_CAPTIONS : {}) }}>
          <AbsoluteFill style={{ filter: smear > 0.5 ? 'url(#smear)' : undefined }}>
            <ThreeCanvas width={1080} height={1920} dpr={1} gl={{ antialias: true, alpha: true, toneMapping: THREE.ACESFilmicToneMapping, toneMappingExposure: 1.0 }} camera={{ fov: FOV, near: 0.5, far: 60, position: [0, 0, CAM_Z] }}>
              <Stage id={id} />
            </ThreeCanvas>
          </AbsoluteFill>
        </AbsoluteFill>
      ) : null}

      {/* Each thing's name as the phone lands on it… */}
      {s.recap.map((stop, i) => (
        <Slip key={`now${i}`} t={t} at={film.stops[i]} until={(i < film.last ? film.stops[i + 1] : film.all) - 0.22} x={film.side(i) > 0 ? 808 : 272} y={338} tilt={film.side(i) * 5}>
          <Name stop={stop} premium={s.premium} />
        </Slip>
      ))}
      {/* …and all six round it. */}
      {s.recap.map((stop, i) => (
        <Slip key={`all${i}`} t={t} at={film.all + 0.12 + i * 0.07} until={film.modes - 0.25 + i * 0.02} x={ROUND[i][0]} y={ROUND[i][1]} tilt={ROUND[i][2]}>
          <Name stop={stop} premium={s.premium} small />
        </Slip>
      ))}

      {/* The two ways to use it, each under its name. */}
      {[
        { mode: s.classic, at: film.classicTag, x: classicAt.x, y: classicAt.y, tilt: -4 },
        { mode: s.easy, at: film.easyTag, x: 792, y: 292, tilt: 4 },
      ].map(({ mode, at, x, y, tilt }) => (
        <Slip key={mode.tag} t={t} at={at} until={film.part - 0.05} x={x} y={y} tilt={tilt}>
          <span style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', lineHeight: 1.12 }}>
            <span style={{ fontFamily: /[㐀-鿿]/.test(mode.tag) ? SERIF_TC : SERIF, fontWeight: 900, fontSize: 62, color: CLAY }}>{mode.tag}</span>
            <span style={{ fontFamily: FONT, fontWeight: 700, fontSize: 32, color: '#6F6557', marginTop: 4 }}>{mode.sub}</span>
          </span>
        </Slip>
      ))}

      <Buddy film={film} />

      {/* Under the icon: the name, what it costs to study, where to get it. */}
      {nameIn > 0 ? (
        <div style={{ position: 'absolute', left: 0, right: 0, top: 642, display: 'flex', justifyContent: 'center', alignItems: 'baseline', gap: 24, color: '#FFF8EC', textShadow: '0 4px 20px rgba(30,34,18,0.3)', clipPath: `inset(-20% ${(1 - nameIn) * 100}% -20% 0)`, transform: `translateY(${(1 - nameIn) * 14}px)` }}>
          <span style={{ fontFamily: SERIF, fontWeight: 800, fontSize: 96, letterSpacing: '0.01em' }}>{episode.app.split(' ')[0]}</span>
          {episode.app.includes(' ') ? <span style={{ fontFamily: SERIF_TC, fontWeight: 900, fontSize: 84, letterSpacing: '0.08em' }}>{episode.app.split(' ').slice(1).join(' ')}</span> : null}
        </div>
      ) : null}
      <AbsoluteFill style={{ opacity: 1 - tidy, transform: `translateY(${tidy * 40}px)` }}>
        <Slip t={t} at={film.freeAt} until={end + 1} x={540} y={930} tilt={-3}>
          <span style={{ display: 'flex', alignItems: 'baseline', gap: 18 }}>
            <span style={{ fontFamily: FONT, fontWeight: 900, fontSize: 54, color: '#2B2620' }}>{s.free[0]}</span>
            <span style={{ fontFamily: /[㐀-鿿]/.test(s.free[1]) ? SERIF_TC : SERIF, fontWeight: 900, fontSize: 92, color: CLAY }}>{s.free[1]}</span>
          </span>
        </Slip>
        {t >= film.nowAt ? (
          <div style={{ position: 'absolute', left: 0, right: 0, top: 1090, display: 'flex', justifyContent: 'center', opacity: ramp(t, film.nowAt, film.nowAt + 0.2), transform: `scale(${1.25 - 0.25 * ramp(t, film.nowAt, film.nowAt + 0.22, Easing.out(Easing.back(2)))})` }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 18, background: 'linear-gradient(180deg, rgba(46,42,34,0.9), rgba(30,28,22,0.94))', border: '1.5px solid rgba(255,250,235,0.14)', color: '#FFF8EE', fontWeight: 900, fontSize: 56, letterSpacing: '0.03em', padding: '22px 46px', borderRadius: 30, boxShadow: 'inset 0 1.5px 0 rgba(255,250,235,0.12), 0 20px 46px rgba(20,24,10,0.34)' }}>
              <svg width={44} height={44} viewBox="0 0 44 44">
                <path d="M22 6 V28 M12 19 L22 29 L32 19 M8 36 H36" fill="none" stroke="#F7B98F" strokeWidth={5} strokeLinecap="round" strokeLinejoin="round" />
              </svg>
              {s.nowText}
            </div>
          </div>
        ) : null}
      </AbsoluteFill>

      {/* The end: out now, stamped on the chord, and where to get it. */}
      {t >= end ? (
        <>
          {/* The cat looks over the card it is about to be stamped on. */}
          <div style={{ position: 'absolute', left: 792, top: 838 - 104 * over, transform: 'rotate(9deg)', opacity: over > 0 ? 1 : 0 }}>
            <Mascot mood="cheeky" size={180} next />
          </div>
          <StampCard t={t} at={end + 0.35} stampAt={end + 0.75} top={832}>
            {stamp}
          </StampCard>
          <div style={{ position: 'absolute', left: 110, right: 110, top: 1262, display: 'flex', justifyContent: 'center', opacity: cta, transform: `translateY(${(1 - cta) * 16}px)` }}>
            <div style={{ background: 'linear-gradient(180deg, rgba(46,42,34,0.88), rgba(30,28,22,0.92))', border: '1.5px solid rgba(255,250,235,0.14)', color: '#FFF8EE', fontWeight: 900, fontSize: 50, letterSpacing: '0.03em', padding: '18px 40px', borderRadius: 26, textAlign: 'center', boxShadow: 'inset 0 1.5px 0 rgba(255,250,235,0.12), 0 20px 46px rgba(20,24,10,0.3)' }}>{episode.outro}</div>
          </div>
        </>
      ) : null}

      <Burst t={t} at={film.all + 0.2} x={540} y={800} scale={1.6} count={20} />
      <Burst t={t} at={film.iconIn + 0.6} x={iconPx.x} y={iconPx.y} scale={1.2} count={18} />
      <Burst t={t} at={film.nowAt} x={540} y={1130} scale={1.1} count={14} />
      <Burst t={t} at={end + 0.75} x={540} y={1020} scale={1.2} count={16} />
      <Foreground t={t} drift={drift} show={lit * (1 - phonesOut)} />
      <Motes t={t} front />
      {/* A long line is captioned a phrase at a time, as it is said. */}
      {episode.lines.flatMap((line, i) => {
        const slot = timing.slots[i];
        const parts: [string, number][] = line.parts ?? [[line.text, 0]];
        return parts.map(([text, beat], k) => {
          const start = slot.start + beat * BEAT;
          const stop = k + 1 < parts.length ? slot.start + parts[k + 1][1] * BEAT : slot.start + slot.length;
          return <Caption key={`${i}-${k}`} text={text} start={start} length={stop - start} t={t} first={i === 0 && k === 0} label={episode.label} top={CAPTION_TOP} size={episode.captionSize ?? 62} glass />;
        });
      })}
      <Grade frame={frameNo} />
    </AbsoluteFill>
  );
};
