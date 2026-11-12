import type { ReactNode } from 'react';
import { ThreeCanvas } from '@remotion/three';
import { useThree } from '@react-three/fiber';
import { AbsoluteFill, Html5Audio, staticFile, useCurrentFrame } from 'remotion';
import * as THREE from 'three';
import { FONT, HAND, HAND_TC, SERIF } from '../fonts';
import script from './episodes.json';
import timings from './timing.json';
import { REEL_FPS } from './Reel';
import { Caption } from './Intro';
import { ABOVE_CAPTIONS, CAPTION_TOP, Peek } from './Teaser';
import { CountdownEnd, DaysStamp, StampCard } from './Countdown';
import { Burst, DeepBackdrop, Foreground, Grade, InkFilters, Motes } from './finish';
import { Mascot, type Mood } from '../Mascot';
import { Lift, PHONE, colorAt, Phone3D, ScreenLayer, StudioLight, imageTexture, inOut, loadPhone, loadStudio, onScreen, out, ramp, usePrepared } from './three/kit';
import { CAN, CatCan, RubberStamp } from './three/objects';

/**
 * 11/15, one day to go: finishing the day, the stamp, the streak, and
 * the Cat Can that saves it once.
 *
 * Cover, then a paper habit tracker slaps down: three days ticked, the
 * fourth put off. The phone comes up beside it; the tracker slides away
 * and the camera goes in on the day's summary: its three numbers lift
 * off the glass one by one, then the cat's "fine, you may rest". The
 * phone lies back like something on a desk, and a wood-handled rubber
 * stamp comes down on it: the blow prints the "today's done" page, the
 * phone dips under it, and the gold seal lifts off with a +1. Closer on
 * the week: a red cross on a missed day, and the Cat Can jumps out of its
 * place on the row, tumbles through the air and lands on the cross. Last,
 * the tracker comes back and the stamp lands on the day that was put off.
 *
 * The tracker, the stamp and the can are props; the can is named as the
 * app names it. Everything on the phone is the app's screenshots.
 */

const BEAT = 0.5;
const PI = Math.PI;
const CAM_Z = 9;
const FOV = 30;
const FOCAL = 960 / Math.tan(((FOV / 2) * PI) / 180);
const MID = ((960 - 825) / FOCAL) * CAM_Z;

type Slot = { start: number; length: number };
type Crop = [number, number, number, number];
type Scene = {
  summary: string;
  stamp: string;
  tiles: Crop[];
  bubble: Crop;
  seal: Crop;
  week: Crop;
  day: [number, number];
  can: [number, number];
  line: Crop;
  beats: { bubble: number; hit: number; seal: number; plus: number; x: number; canOut: number; canLand: number; line: number; one: number; stamp2: number };
  tracker: { title: string; day: string; excuse: string; plus: string; one: string; label: string };
  desk: [string, number, number, number, number][];
};
type Episode = { id: string; days: number; app: string; label: string; dayWords: [string, string]; note: string; outro: string; lines: { text: string }[]; scene: Scene };
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
const rotationOf = (q: Pose) => new THREE.Matrix4().makeRotationFromEuler(new THREE.Euler(q.rx, q.ry, q.rz, 'YXZ'));
const matrixOf = (q: Pose) => new THREE.Matrix4().makeTranslation(q.x, q.y, q.z).multiply(rotationOf(q));
const projectWith = (q: Pose, x: number, y: number, lift = 0.004) => {
  const v = new THREE.Vector3(...onScreen(x, y, lift)).applyMatrix4(matrixOf(q));
  const k = FOCAL / (CAM_Z - v.z);
  return { x: 540 + v.x * k, y: 960 - v.y * k, k };
};
/** The pose, at this depth and turned this way, that puts the screenshot's (sx, sy) at the frame's (col, row). */
const aim = (z: number, rx: number, ry: number, rz: number, sx: number, sy: number, col: number, row: number): Pose => {
  const turned = new THREE.Vector3(...onScreen(sx, sy)).applyMatrix4(rotationOf({ x: 0, y: 0, z: 0, rx, ry, rz }));
  const k = FOCAL / (CAM_Z - (z + turned.z));
  return { x: (col - 540) / k - turned.x, y: (960 - row) / k - turned.y, z, rx, ry, rz };
};

/** The habit tracker on the desk, and its fourth box. */
const TRACK = { left: 40, top: 400, width: 560, height: 480, tilt: -4 };
const BOX = { size: 112, gap: 16, left: 40, top: 158, row: 150 };
const boxAt = (n: number) => ({ x: BOX.left + (n % 4) * (BOX.size + BOX.gap) + BOX.size / 2, y: BOX.top + Math.floor(n / 4) * BOX.row + BOX.size / 2 });
/** Where a point of the tracker is in the frame, with the tracker's tilt. */
const trackPoint = (x: number, y: number) => {
  const a = (TRACK.tilt * PI) / 180;
  const dx = x - TRACK.width / 2;
  const dy = y - TRACK.height / 2;
  return { x: TRACK.left + TRACK.width / 2 + dx * Math.cos(a) - dy * Math.sin(a), y: TRACK.top + TRACK.height / 2 + dx * Math.sin(a) + dy * Math.cos(a) };
};

/** A stamp's height above what it prints, around the moment `hit` it lands; -1 while it is away. */
const stampHeight = (t: number, hit: number) => {
  const a = t - hit;
  if (a < -0.8 || a > 1.05) return -1;
  if (a < -0.3) return 3.2 - 2.45 * ramp(a, -0.8, -0.3, out);
  if (a < -0.11) return 0.75 + 0.12 * ramp(a, -0.3, -0.11, inOut);
  if (a < 0) return 0.87 * (1 - ramp(a, -0.11, 0, (n) => n * n));
  if (a < 0.16) return 0;
  if (a < 0.5) return 0.6 * ramp(a, 0.16, 0.5, out);
  return 0.6 + 3 * ramp(a, 0.5, 1.05, (n) => n * n);
};
const pressOf = (t: number, hit: number) => (t >= hit && t < hit + 0.16 ? 1 - ((t - hit) / 0.16) * 0.4 : 0);

const useFilm = (id: string) => {
  const t = useCurrentFrame() / REEL_FPS;
  const episode = script.episodes.find((e) => e.id === id)! as unknown as Episode;
  const s = episode.scene;
  const b = s.beats;
  const timing = (timings as Record<string, { total: number; end: number; slots: Slot[] }>)[id];
  const starts = timing.slots.map((slot) => slot.start);
  const [, resting, stamping, saving, tomorrow] = starts;
  const end = timing.end;
  const at = (slot: number, beat: number) => starts[slot] + beat * BEAT;

  const trackIn = 2.2 * BEAT;
  const rise = resting - 1.0;
  const toCentre = at(1, 0.4);
  const tileAt = [at(1, 1), at(1, 1.5), at(1, 2)];
  const quarter = at(1, 2.7);
  const bubbleAt = at(1, b.bubble);
  const lay = stamping - 0.35;
  const hit = at(2, b.hit);
  const sealAt = at(2, b.seal);
  const plusAt = at(2, b.plus);
  const closer = saving - 0.2;
  const xAt = at(3, b.x);
  const canOut = at(3, b.canOut);
  const canLand = at(3, b.canLand);
  const lineAt = at(3, b.line);
  const oneAt = at(3, b.one);
  const back = tomorrow - 0.25;
  const trackBack = at(4, 0.2);
  const hit2 = at(4, b.stamp2);

  const upright = (y: number, row: number, z: number) => ((960 - row) / FOCAL) * (CAM_Z - z) - (0.5 - y / 2622) * PHONE.h;
  const tilesY = (s.tiles[0][1] + s.bubble[3]) / 2;
  const sealX = (s.seal[0] + s.seal[2]) / 2;
  const sealY = (s.seal[1] + s.seal[3]) / 2;
  const onDesk = aim(3.1, -0.74, PI * 2 + 0.1, -0.03, sealX, sealY, 540, 900);
  const onDeskAfter = aim(3.3, -0.66, PI * 2 - 0.16, 0.02, sealX, sealY, 540, 880);
  const onWeek = aim(4.7, -0.6, PI * 2 - 0.24, 0.02, 603, s.week[1] + 30, 540, 850);
  const onWeekLate = aim(4.85, -0.56, PI * 2 - 0.1, 0.01, 603, s.week[1] + 60, 540, 850);
  const keys: Key[] = [
    { at: rise, pose: { x: 1.1, y: -5.2, z: 0, rx: 0.5, ry: PI + 0.9, rz: 0.25 } },
    { at: rise + 0.8, pose: { x: 0.6, y: upright(1311, 800, 1.4) + 0.05, z: 1.4, rx: 0.12, ry: PI + 0.5, rz: 0.06 }, ease: out },
    { at: rise + 1.5, pose: { x: 0.5, y: upright(1311, 800, 1.3), z: 1.3, rx: 0.04, ry: PI * 2 - 0.4, rz: 0.012 }, ease: inOut },
    { at: toCentre, pose: { x: 0.5, y: upright(1311, 800, 1.3), z: 1.3, rx: 0.04, ry: PI * 2 - 0.42, rz: 0.012 }, ease: (n) => n },
    // To the middle and in on the three numbers.
    { at: toCentre + 0.7, pose: { x: 0, y: upright(tilesY, 800, 3.7), z: 3.7, rx: 0.03, ry: PI * 2 + 0.06, rz: 0 }, ease: inOut },
    { at: quarter, pose: { x: 0, y: upright(tilesY, 800, 3.8), z: 3.8, rx: 0.03, ry: PI * 2 + 0.1, rz: 0 }, ease: (n) => n },
    { at: quarter + 0.6, pose: { x: 0.2, y: upright(tilesY + 60, 810, 3.5), z: 3.5, rx: 0.12, ry: PI * 2 - 0.52, rz: 0.03 }, ease: out },
    { at: lay, pose: { x: 0.16, y: upright(tilesY + 60, 810, 3.55), z: 3.55, rx: 0.1, ry: PI * 2 - 0.4, rz: 0.02 }, ease: (n) => n },
    // It lies back on the desk for the stamp.
    { at: lay + 0.55, pose: onDesk, ease: inOut },
    { at: sealAt, pose: onDesk, ease: (n) => n },
    { at: sealAt + 0.6, pose: onDeskAfter, ease: out },
    { at: closer, pose: { ...onDeskAfter, ry: onDeskAfter.ry + 0.06 }, ease: (n) => n },
    // Closer, on the week.
    { at: closer + 0.6, pose: onWeek, ease: inOut },
    { at: back, pose: onWeekLate, ease: (n) => n },
    // Up again and over to the right, once round on the way: the tracker is coming back.
    { at: back + 0.75, pose: { x: 0.7, y: upright(1311, 800, 0.9), z: 0.9, rx: 0.05, ry: PI * 4 - 0.46, rz: 0.015 }, ease: inOut },
    { at: end - 0.2, pose: { x: 0.68, y: upright(1311, 800, 0.95), z: 0.95, rx: 0.05, ry: PI * 4 - 0.36, rz: 0.012 }, ease: (n) => n },
    { at: end + 0.4, pose: { x: 0.5, y: MID - 0.4, z: -7, rx: 0.3, ry: PI * 4 + 1.2, rz: 0.2 }, ease: (n) => n * n },
  ];
  const still = poseAt(keys, t);
  // The phone gives under the stamp and springs back.
  const since = t - hit;
  const give = since >= 0 && since < 0.9 ? Math.exp(-since * 7) * Math.cos(since * 19) : 0;
  const pose = { ...still, z: still.z - 0.28 * give, rx: still.rx - 0.03 * give };
  const before = poseAt(keys, t - 1 / REEL_FPS);
  const turning = Math.abs(still.ry - before.ry) * REEL_FPS;
  const project = (x: number, y: number, lift = 0.004) => projectWith(pose, x, y, lift);
  const up = (when: number, until: number, depth: number, hop = 0.3) => (t < when ? 0 : (depth + hop * Math.exp(-(t - when) * 7) * Math.abs(Math.cos((t - when) * 9))) * ramp(t, when, when + 0.12, out) * (1 - ramp(t, until - 0.3, until, inOut)));
  const leaveSummary = lay + 0.1;
  const leaveStamp = back + 0.1;
  const lifts = {
    tiles: tileAt.map((when, i) => up(when, leaveSummary, 0.2 + i * 0.05, 0.22)),
    bubble: up(bubbleAt, leaveSummary, 0.4),
    seal: up(sealAt, closer + 0.2, 0.32, 0.25) + (t >= plusAt && t < plusAt + 0.5 ? 0.1 * Math.exp(-(t - plusAt) * 8) * Math.abs(Math.cos((t - plusAt) * 12)) : 0),
    week: up(xAt - 0.25, leaveStamp, 0.1, 0.12),
    line: up(lineAt, leaveStamp, 0.2, 0.2),
  };
  const dim = Math.min(1, Math.max(lifts.bubble, lifts.seal * 0.6, lifts.line) * 2.2);
  const onStampPage = t >= hit;
  const knocks: [number, number][] = [
    [trackIn + 0.22, 7],
    [hit, 16],
    [canLand, 8],
    [oneAt, 5],
    [hit2, 12],
  ];
  const knock = knocks.reduce((k, [when, size]) => { const age = t - when; return age >= 0 && age < 0.32 ? k + Math.exp(-age * 14) * Math.cos(age * 60) * size : k; }, 0);
  const centre = project(603, 1311);
  const size = (FOCAL / (CAM_Z - pose.z)) * 0.8;
  const shadow = { x: centre.x, y: centre.y, w: Math.max(60, PHONE.w * size * Math.abs(Math.cos(pose.ry))), h: PHONE.h * size * Math.max(0.35, Math.cos(pose.rx)) };
  const glare = [rise + 1.4, toCentre + 0.7, sealAt + 0.55, back + 0.7].reduce((g, start) => (t >= start && t < start + 0.9 ? (t - start) / 0.9 : g), -1);
  // The tracker: here, away while the phone has the stage, and back for the end.
  const away = ramp(t, toCentre, toCentre + 0.5, inOut) * (1 - ramp(t, trackBack, trackBack + 0.55, out));
  return { t, episode, s, timing, at, end, rise, trackIn, toCentre, tileAt, bubbleAt, lay, hit, sealAt, plusAt, closer, xAt, canOut, canLand, lineAt, oneAt, back, trackBack, hit2, pose, turning, project, lifts, dim, onStampPage, knock, shadow, glare, away, sealX, sealY };
};
type Film = ReturnType<typeof useFilm>;

const Stage = ({ id }: { id: string }) => {
  const gl = useThree((state) => state.gl);
  const film = useFilm(id);
  const { t, s, pose } = film;
  const maps = usePrepared(async () => {
    await Promise.all([document.fonts.load('900 92px "Noto Sans TC"', s.tracker.label), document.fonts.load('800 80px "Noto Serif"', s.tracker.label)]);
    const [summary, stamp, env, phone] = await Promise.all([imageTexture(`${s.summary}.jpg`), imageTexture(`${s.stamp}.jpg`), loadStudio(gl), loadPhone()]);
    return {
      summary,
      stamp,
      env,
      phone,
      ground: { page: colorAt(summary, 20, s.tiles[0][1] - 20), dark: colorAt(stamp, s.seal[0] + 14, s.seal[1] + 14), row: colorAt(stamp, 60, s.day[1]) },
    };
  });
  if (!maps || t < film.rise - 0.05) return null;

  // The stamp over the phone: along the glass's own normal, so it is seen from the side as the phone lies back.
  const h = stampHeight(t, film.hit);
  const sealPos = onScreen(film.sealX, film.sealY, 0.008);
  const flash = t >= film.hit ? Math.exp(-(t - film.hit) * 9) : 0;

  // The cross on the day that was missed, in the teacher's red.
  const stroke = (from: number) => ramp(t, film.xAt + from, film.xAt + from + 0.14, inOut);
  const dayPos = onScreen(s.day[0], s.day[1], 0.006 + film.lifts.week);
  const crossed = t >= film.xAt && t < film.canLand + 0.04;

  // The can: out of its place on the row, up through the air, down on the cross.
  const flight = ramp(t, film.canOut, film.canLand, (n) => n);
  const from = new THREE.Vector3(...onScreen(s.can[0], s.can[1], 0.01));
  const to = new THREE.Vector3(...onScreen(s.day[0], s.day[1], 0.012 + film.lifts.week));
  const canPos = from.clone().lerp(to, inOut(flight));
  canPos.z += Math.sin(PI * flight) * 0.62;
  const landed = t - film.canLand;
  const squash = landed >= 0 && landed < 0.5 ? 1 - 0.28 * Math.exp(-landed * 13) * Math.cos(landed * 30) : 1;
  const canScale = ramp(t, film.canOut, film.canOut + 0.16, out) * (1 + 0.75 * Math.sin(PI * flight)) * (1 - ramp(t, film.back - 0.05, film.back + 0.2, inOut));
  const canOn = t >= film.canOut && canScale > 0.01;

  // The second stamp, on the tracker: in the room, not on the phone.
  const h2 = stampHeight(t, film.hit2);
  const target = trackPoint(boxAt(3).x, boxAt(3).y);
  const lean = 1.02;
  const axis = new THREE.Vector3(0, Math.cos(lean), Math.sin(lean));
  const foot = new THREE.Vector3(((target.x - 540) / FOCAL) * CAM_Z, ((960 - target.y) / FOCAL) * CAM_Z, 0).addScaledVector(axis, Math.max(0, h2) * 0.8);

  return (
    <>
      <StudioLight env={maps.env} turn={t * 0.12 + pose.ry * 0.25} />
      <group position={[pose.x, pose.y + Math.sin(t * 1.3) * 0.012, pose.z]} rotation={[pose.rx + Math.sin(t * 0.9) * 0.008, pose.ry, pose.rz, 'YXZ']}>
        <Phone3D model={maps.phone} screen={film.onStampPage ? maps.stamp : maps.summary} glare={film.glare}>
          <ScreenLayer color="#2a2418" opacity={film.dim * 0.18} over />
          {/* The blow prints the page: for an instant the glass is all gold. */}
          <ScreenLayer color="#FFE7A8" opacity={flash * 0.85} over />
          {film.onStampPage ? (
            <>
              <Lift map={maps.stamp} crop={s.seal} lift={film.lifts.seal} ground={maps.ground.dark} radius={(s.seal[2] - s.seal[0]) / 2} />
              <Lift map={maps.stamp} crop={s.week} lift={film.lifts.week} ground={maps.ground.row} radius={50} />
              <Lift map={maps.stamp} crop={s.line} lift={film.lifts.line} ground={maps.ground.row} radius={20} />
              {crossed
                ? [0, 1].map((i) => (
                    <mesh key={i} position={[dayPos[0], dayPos[1], dayPos[2] + 0.002 * (i + 1)]} rotation={[0, 0, i ? -PI / 4 : PI / 4]} scale={[Math.max(0.001, stroke(i * 0.14)), 1, 1]} renderOrder={6}>
                      <planeGeometry args={[0.105, 0.016]} />
                      <meshBasicMaterial color="#C4452C" transparent opacity={0.94} depthWrite={false} toneMapped={false} />
                    </mesh>
                  ))
                : null}
              {canOn ? (
                <group position={[canPos.x, canPos.y, canPos.z]} rotation={[(PI / 2) * (1 - Math.sin(PI * flight) * 0.92), 0, Math.sin(PI * flight * 2) * 0.22]} scale={canScale}>
                  <group rotation={[0, 0.5 + flight * PI * 3 + Math.max(0, landed) * 0.2, 0]} scale={[1 + (1 - squash) * 0.5, squash, 1 + (1 - squash) * 0.5]}>
                    <CatCan word={s.tracker.label} />
                  </group>
                  {/* Its shadow on the row, once it is down. */}
                  {landed >= 0 ? (
                    <mesh position={[CAN.r * 0.25, -0.004, CAN.r * 0.3]} rotation={[-PI / 2, 0, 0]} renderOrder={5}>
                      <circleGeometry args={[CAN.r * 1.35, 40]} />
                      <meshBasicMaterial color="#120c06" transparent opacity={0.34 * ramp(landed, 0, 0.15)} depthWrite={false} toneMapped={false} />
                    </mesh>
                  ) : null}
                </group>
              ) : null}
            </>
          ) : (
            <>
              {s.tiles.map((crop, i) => (
                <Lift key={i} map={maps.summary} crop={crop} lift={film.lifts.tiles[i]} ground={maps.ground.page} radius={44} />
              ))}
              <Lift map={maps.summary} crop={s.bubble} lift={film.lifts.bubble} ground={maps.ground.page} radius={40} />
            </>
          )}
          {h >= 0 ? (
            <group position={[sealPos[0], sealPos[1], sealPos[2] + h]} rotation={[PI / 2 - 0.1 * Math.min(1, h), 0, 0.14 * Math.min(1, h)]}>
              <group rotation={[0, 0.7, 0]}>
                <RubberStamp press={pressOf(t, film.hit)} />
              </group>
            </group>
          ) : null}
        </Phone3D>
      </group>
      {h2 >= 0 ? (
        <group position={[foot.x, foot.y, foot.z]} rotation={[lean, 0, -0.08]} scale={0.8}>
          <group rotation={[0, 2.4, 0]}>
            <RubberStamp press={pressOf(t, film.hit2)} />
          </group>
        </group>
      ) : null}
    </>
  );
};

const Tick = ({ drawn }: { drawn: number }) => (
  <svg width={84} height={78} viewBox="0 0 84 78" style={{ position: 'absolute', left: 14, top: 26, overflow: 'visible' }}>
    <path d="M8 44 L30 66 L76 10" fill="none" stroke="#5E8A52" strokeWidth={10} strokeLinecap="round" strokeLinejoin="round" strokeDasharray={110} strokeDashoffset={110 * (1 - drawn)} />
  </svg>
);

/**
 * The habit tracker: seven days on a card, three ticked in pencil, the
 * fourth put off. It slaps down, slides away while the phone has the
 * stage, and comes back to be stamped.
 */
const Tracker = ({ film }: { film: Film }) => {
  const { t, s, trackIn, away, hit2, end } = film;
  if (t < trackIn) return null;
  const drop = ramp(t, trackIn, trackIn + 0.22, (n) => n * n);
  const settle = t > trackIn + 0.22 ? Math.exp(-(t - trackIn - 0.22) * 9) * Math.sin((t - trackIn - 0.22) * 22) * 0.012 : 0;
  const leave = ramp(t, end - 0.2, end + 0.25, inOut);
  if (away >= 1 || leave >= 1) return null;
  const cjk = /[㐀-鿿]/.test(s.tracker.title);
  const hand = cjk ? { fontFamily: HAND_TC } : { fontFamily: HAND, fontWeight: 600 };
  const stamped = t - hit2;
  const jolt = stamped >= 0 && stamped < 0.4 ? Math.exp(-stamped * 12) * Math.sin(stamped * 50) * 1.2 : 0;
  return (
    <div
      style={{
        position: 'absolute',
        left: TRACK.left - away * 760,
        top: TRACK.top + (1 - drop) * -1400,
        width: TRACK.width,
        height: TRACK.height,
        transform: `rotate(${TRACK.tilt - (1 - drop) * 12 - away * 10 + jolt}deg) scale(${1 + (1 - drop) * 0.5 + settle})`,
        opacity: 1 - leave,
        filter: `drop-shadow(0 ${22 + (1 - drop) * 50}px ${26 + (1 - drop) * 40}px rgba(26,30,10,0.4))`,
      }}
    >
      <div style={{ position: 'absolute', inset: 0, borderRadius: 8, backgroundColor: '#FBF7EC', backgroundImage: `url(${staticFile('paper-grain.png')})`, backgroundBlendMode: 'multiply', backgroundSize: '320px', border: '2px solid rgba(90,80,50,0.14)' }} />
      <div style={{ position: 'absolute', left: 210, top: -20, width: 140, height: 40, background: 'rgba(238,226,190,0.8)', transform: 'rotate(-3deg)', boxShadow: '0 1px 2px rgba(0,0,0,0.12)' }} />
      <div style={{ position: 'absolute', left: 40, top: 40, color: '#2B3A55', lineHeight: 1, ...hand, fontSize: cjk ? 64 : 78 }}>
        {s.tracker.title}
        <svg width={cjk ? 380 : 440} height={16} viewBox="0 0 440 16" preserveAspectRatio="none" style={{ display: 'block', marginTop: 6 }}>
          <path d="M2 9 C 90 2, 180 14, 270 7 S 400 4, 438 9" fill="none" stroke="#2B3A55" strokeWidth={4} strokeLinecap="round" opacity={0.7} />
        </svg>
      </div>
      {Array.from({ length: 7 }, (_, n) => {
        const c = boxAt(n);
        return (
          <div key={n} style={{ position: 'absolute', left: c.x - BOX.size / 2, top: c.y - BOX.size / 2, width: BOX.size, height: BOX.size, borderRadius: 12, border: '3px solid rgba(110,100,82,0.55)', background: 'rgba(255,255,255,0.35)' }}>
            <div style={{ position: 'absolute', left: 0, right: 0, top: 6, textAlign: 'center', fontFamily: FONT, fontWeight: 700, fontSize: 20, color: '#8A7F70', letterSpacing: '0.04em' }}>{s.tracker.day.replace('{n}', String(n + 1))}</div>
            {n < 3 ? <Tick drawn={1} /> : null}
            {n === 3 ? (
              <div style={{ position: 'absolute', left: -6, right: -6, top: 44, textAlign: 'center', color: '#8D8577', transform: 'rotate(-9deg)', ...hand, fontSize: cjk ? 25 : 32, whiteSpace: 'nowrap', lineHeight: 1, opacity: stamped >= 0 ? 0.25 : 1 }}>{s.tracker.excuse}</div>
            ) : null}
            {/* What the stamp leaves. */}
            {n === 3 && stamped >= 0 ? (
              <div style={{ position: 'absolute', left: 4, top: 14, width: 98, height: 98, borderRadius: 49, border: '8px solid #C96442', color: '#C96442', display: 'flex', alignItems: 'center', justifyContent: 'center', fontFamily: SERIF, fontWeight: 800, fontSize: 60, transform: 'rotate(-10deg)', filter: 'url(#ink)' }}>✓</div>
            ) : null}
          </div>
        );
      })}
    </div>
  );
};

/** A slip of paper with tape on it, slapped down beside what it is about. */
export const Slip = ({ t, at, until, x, y, tilt, children }: { t: number; at: number; until: number; x: number; y: number; tilt: number; children: ReactNode }) => {
  if (t < at || t > until + 0.3) return null;
  const drop = ramp(t, at, at + 0.14, (n) => n * n);
  const leave = ramp(t, until, until + 0.3, inOut);
  return (
    <div style={{ position: 'absolute', left: x, top: y, transform: `translate(-50%, -50%) rotate(${tilt - (1 - drop) * 8}deg) scale(${1.7 - 0.7 * drop})`, opacity: Math.min(1, drop * 3) * (1 - leave) }}>
      <div style={{ position: 'absolute', left: '50%', marginLeft: -40, top: -15, width: 80, height: 28, background: 'rgba(238,226,190,0.8)', transform: 'rotate(-3deg)', boxShadow: '0 1px 2px rgba(0,0,0,0.12)' }} />
      <div style={{ padding: '10px 26px 12px', borderRadius: 6, backgroundColor: '#FBF6EA', backgroundImage: `url(${staticFile('paper-grain.png')})`, backgroundBlendMode: 'multiply', backgroundSize: '300px', boxShadow: '0 12px 24px rgba(30,30,10,0.34)', border: '1px solid rgba(90,80,50,0.16)', whiteSpace: 'nowrap' }}>{children}</div>
    </div>
  );
};

/** 傻貓 in the corner for the whole of it. */
const Buddy = ({ film }: { film: Film }) => {
  const { t, end } = film;
  const arrive = film.at(1, 0.6);
  if (t < arrive) return null;
  const inP = ramp(t, arrive, arrive + 0.5, out) * (1 - ramp(t, end - 0.25, end + 0.1, inOut));
  const events: { at: number; mood: Mood; stay: boolean }[] = [
    { at: film.tileAt[2], mood: 'happy', stay: false },
    { at: film.bubbleAt, mood: 'annoyed', stay: false },
    { at: film.hit, mood: 'happy', stay: false },
    { at: film.plusAt, mood: 'cheeky', stay: false },
    { at: film.xAt, mood: 'annoyed', stay: false },
    { at: film.canLand, mood: 'happy', stay: false },
    { at: film.oneAt, mood: 'cheeky', stay: false },
    { at: film.hit2, mood: 'cheeky', stay: true },
  ];
  const now = [...events].reverse().find((e) => t >= e.at);
  const age = now ? t - now.at : 9;
  const mood: Mood = now && (now.stay || age < 0.9) ? now.mood : 'smug';
  const hop = age < 0.6 ? Math.exp(-age * 7) * Math.sin(age * 17) : 0;
  return (
    <div style={{ position: 'absolute', left: -96 - (1 - inP) * 360, top: 1068 - hop * 30, transform: `rotate(${13 + hop * 3}deg)`, transformOrigin: '30% 100%', filter: 'drop-shadow(0 18px 20px rgba(30,34,14,0.34))' }}>
      <Mascot mood={mood} size={400} next />
    </div>
  );
};

export const Day1 = ({ id }: { id: string }) => {
  const frameNo = useCurrentFrame();
  const film = useFilm(id);
  const { t, episode, s, timing, end, rise } = film;

  const stamp = <DaysStamp days={episode.days} words={episode.dayWords} note={episode.note} />;
  const tip = ramp(t, film.trackIn - 0.12, film.trackIn + 0.38, inOut);
  const leave = ramp(t, end - 0.15, end + 0.35, inOut);
  const smear = Math.min(26, Math.max(0, film.turning - 2.5) * 2.4);
  const lit = ramp(t, film.trackIn, film.trackIn + 0.8, (n) => n) * (1 - leave);
  const drift = (film.pose.y - MID) * 260 + film.pose.x * 500;
  const seal = film.project(film.sealX, film.sealY, film.lifts.seal);
  const day = film.project(s.day[0], s.day[1], film.lifts.week + 0.1);
  const box = trackPoint(boxAt(3).x, boxAt(3).y);
  const serif = { fontFamily: SERIF, fontWeight: 800, color: '#C96442' } as const;
  const word = { fontFamily: FONT, fontWeight: 900, color: '#2B2620' } as const;
  const split = (text: string) => text.split(/(\d+|[+×])/).filter(Boolean);

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
      <AbsoluteFill style={{ background: `radial-gradient(70% 46% at 50% 42%, rgba(255,244,214,${0.2 * lit}) 0%, rgba(255,244,214,0) 70%), radial-gradient(120% 90% at 50% 42%, rgba(0,0,0,0) 45%, rgba(26,30,12,${0.42 * lit}) 100%)` }} />
      <Motes t={t} />

      {/* The cover. */}
      {tip < 1 ? (
        <div style={{ position: 'absolute', inset: 0, opacity: 1 - tip * tip, transform: `perspective(1400px) translateY(${-tip * 420}px) translateZ(${-tip * 500}px) rotateX(${tip * 70}deg)`, transformOrigin: '50% 22%' }}>
          <StampCard t={t} at={0} stampAt={0} top={300}>
            {stamp}
          </StampCard>
        </div>
      ) : null}
      <Peek t={t} at={0} until={film.trackIn + 0.3} side={1} mood="smug" y={760} outAt={film.trackIn - 0.14} />

      <AbsoluteFill style={{ transform: `translateY(${film.knock * 0.6}px)` }}>
        <Tracker film={film} />
      </AbsoluteFill>

      {/* The phone's shadow on the backdrop. */}
      {lit > 0 && leave < 1 ? (
        <div
          style={{
            position: 'absolute',
            left: film.shadow.x - film.shadow.w / 2,
            top: film.shadow.y - film.shadow.h / 2 + 34,
            width: film.shadow.w,
            height: film.shadow.h,
            borderRadius: film.shadow.w * 0.3,
            background: 'rgba(28,32,12,0.3)',
            boxShadow: '0 30px 70px 34px rgba(28,32,12,0.3)',
            opacity: lit * (1 - leave),
            ...ABOVE_CAPTIONS,
          }}
        />
      ) : null}

      {/* The phone, the stamp and the can. */}
      {t >= rise - 0.2 && leave < 1 ? (
        <AbsoluteFill style={{ opacity: 1 - leave, transform: `translateY(${film.knock}px)`, ...ABOVE_CAPTIONS }}>
          <AbsoluteFill style={{ filter: smear > 0.5 ? 'url(#smear)' : leave > 0 ? `blur(${leave * 12}px)` : undefined }}>
            <ThreeCanvas width={1080} height={1920} dpr={1} gl={{ antialias: true, alpha: true, toneMapping: THREE.ACESFilmicToneMapping, toneMappingExposure: 1.0 }} camera={{ fov: FOV, near: 0.5, far: 60, position: [0, 0, CAM_Z] }}>
              <Stage id={id} />
            </ThreeCanvas>
          </AbsoluteFill>
        </AbsoluteFill>
      ) : null}

      {/* The streak goes up by one. */}
      <Slip t={t} at={film.plusAt} until={film.closer} x={Math.min(880, seal.x + 290)} y={seal.y - 190} tilt={7}>
        {split(s.tracker.plus).map((part, i) => (
          <span key={i} style={/[\d+×]/.test(part) ? { ...serif, fontSize: 104 } : { ...word, fontSize: 62, marginLeft: 8 }}>
            {part.trim()}
          </span>
        ))}
      </Slip>
      {/* And there is only the one can. */}
      <Slip t={t} at={film.oneAt} until={film.back - 0.1} x={Math.min(860, day.x + 250)} y={day.y - 190} tilt={6}>
        {split(s.tracker.one).map((part, i) => (
          <span key={i} style={/[\d+×]/.test(part) ? { ...serif, fontSize: 88, margin: '0 10px' } : { ...word, fontSize: 56 }}>
            {part.trim()}
          </span>
        ))}
      </Slip>

      <Burst t={t} at={film.hit} x={seal.x} y={seal.y} scale={1.5} count={22} />
      <Burst t={t} at={film.canLand} x={day.x} y={day.y} scale={0.8} count={12} />
      <Burst t={t} at={film.hit2} x={box.x} y={box.y} scale={0.9} count={14} />
      <Buddy film={film} />
      <Foreground t={t} drift={drift} show={lit} />
      <Motes t={t} front />
      {episode.lines.map((line, i) => (
        <Caption key={i} text={line.text} start={timing.slots[i].start} length={timing.slots[i].length} t={t} first={i === 0} label={episode.label} top={CAPTION_TOP} size={62} glass />
      ))}
      <CountdownEnd t={t} end={end} episode={episode} stamp={stamp} />
      <Grade frame={frameNo} />
    </AbsoluteFill>
  );
};
