import { ThreeCanvas } from '@remotion/three';
import { useThree } from '@react-three/fiber';
import { useMemo } from 'react';
import { AbsoluteFill, Html5Audio, staticFile, useCurrentFrame } from 'remotion';
import * as THREE from 'three';
import { FONT, SERIF, SERIF_TC } from '../fonts';
import script from './episodes.json';
import timings from './timing.json';
import { REEL_FPS } from './Reel';
import { Caption } from './Intro';
import { ABOVE_CAPTIONS, CAPTION_TOP, Peek } from './Teaser';
import { CountdownEnd, DaysStamp, StampCard } from './Countdown';
import { Counter } from './props';
import { DeepBackdrop, Foreground, Grade, InkFilters, Motes } from './finish';
import { Mascot, type Mood } from '../Mascot';
import { Lift, PAL, PHONE, SCREEN_H, SCREEN_W, canvasTexture, colorAt, Phone3D, ScreenLayer, StudioLight, Tap3D, imageTexture, inOut, loadPhone, loadStudio, onScreen, out, ramp, roundedRect, usePrepared } from './three/kit';

/**
 * 11/11, five days to go: flashcards you swipe.
 *
 * Cover, then the phone rises back-first and turns to face you on a deck
 * of word cards. A fingertip takes the top card and drags it right: it
 * tilts on its foot, washes green, the app's own verdict ("認識") shows
 * on it, and it is flung away; the next card is already underneath. That
 * one goes left: red, "不熟", and it turns over in the air to a paper back
 * that says it will be back. Then the phone swings to three-quarters and
 * the cards go quickly, one after another, while a counter runs up.
 *
 * Every card is a real screenshot's card, cut out; the episode's `scene`
 * lists them, the swipes, and the labels.
 */

const BEAT = 0.5;
/** How long a flung card is in the air. */
const FLIGHT = 0.62;
const PI = Math.PI;
const CAM_Z = 9;
const FOV = 30;
const FOCAL = 960 / Math.tan(((FOV / 2) * PI) / 180);
const MID = ((960 - 825) / FOCAL) * CAM_Z;

type Slot = { start: number; length: number };
type Prop = { kind: 'counter'; slot: number; beat: number; from: [number, number]; at: [number, number]; tilt: number; label: string; unit: string; to: number };
/** `cards`: screenshot and the row its card starts on. `rect`: the card's left, right and bottom, the same in every screenshot. `swipes`: slot, beat, direction, beats held before it is flung. */
type Scene = { base: string; cards: [string, number][]; rect: [number, number, number]; look: number; swipes: [number, number, number, number][]; badges: [string, string]; back: string; desk: [string, number][]; tally: [string, string]; returns: string; props: Prop[] };
type Episode = { id: string; days: number; app: string; label: string; dayWords: [string, string]; note: string; outro: string; lines: { text: string }[]; scene: Scene };
type Pose = { x: number; y: number; z: number; rx: number; ry: number; rz: number };
type Key = { at: number; pose: Pose; ease?: (n: number) => number };
type CardState = { drag: number; lift: number; flip: number; rise: number; fade: number; touching: boolean; under: number; small: number };

const poseAt = (keys: Key[], t: number): Pose => {
  let i = 0;
  while (i < keys.length - 1 && t >= keys[i + 1].at) i++;
  const a = keys[i];
  const b = keys[Math.min(i + 1, keys.length - 1)];
  const p = a === b ? 0 : (b.ease ?? inOut)(Math.min(1, Math.max(0, (t - a.at) / (b.at - a.at))));
  const m = (k: keyof Pose) => a.pose[k] + (b.pose[k] - a.pose[k]) * p;
  return { x: m('x'), y: m('y'), z: m('z'), rx: m('rx'), ry: m('ry'), rz: m('rz') };
};
const frame = (y: number, row: number, z: number) => ((960 - row) / FOCAL) * (CAM_Z - z) - (0.5 - y / 2622) * PHONE.h;

const useFilm = (id: string) => {
  const t = useCurrentFrame() / REEL_FPS;
  const episode = script.episodes.find((e) => e.id === id)! as unknown as Episode;
  const s = episode.scene;
  const timing = (timings as Record<string, { total: number; end: number; slots: Slot[] }>)[id];
  const starts = timing.slots.map((slot) => slot.start);
  const [, right, left, fast] = starts;
  const end = timing.end;
  const at = (slot: number, beat: number) => starts[slot] + beat * BEAT;

  const rise = 2 * BEAT;
  const swipes = s.swipes.map(([slot, beat, dir, hold]) => ({ grab: at(slot, beat), fling: at(slot, beat + hold), dir }));
  // Each card: where the fingertip has it, or how far it has flown.
  const cards: CardState[] = s.cards.map((_, i) => {
    const sw = swipes[i];
    const before = swipes[i - 1];
    // Waiting under the card above: it comes up to full size as that one leaves.
    const under = before ? ramp(t, before.fling, before.fling + 0.35, out) : 1;
    if (!sw) return { drag: 0, lift: 0, flip: 0, rise: 0, fade: 1, touching: false, under, small: 0 };
    const pull = ramp(t, sw.grab, sw.grab + 0.42, out);
    // In the hand it is never quite still; once flung it belongs to the room (see `flights`).
    const held = pull > 0.9 ? Math.sin(t * 5) * 0.012 : 0;
    return { drag: sw.dir * 0.4 * pull + held, lift: 0.05 * pull, flip: 0, rise: 0, fade: t < sw.fling ? 1 : 0, touching: t > sw.grab && t < sw.fling, under, small: 0 };
  });
  const top = swipes.filter((sw) => t >= sw.fling).length; // the card now on top of the deck

  const whole = (z: number, row = 825) => frame(1311, row, z);
  const yCard = (z: number, row = 830) => frame(s.look, row, z);
  const first = swipes[0];
  const second = swipes.find((sw) => sw.dir < 0)!;
  const keys: Key[] = [
    { at: rise, pose: { x: 0.25, y: -5.4, z: 0, rx: 0.55, ry: PI + 0.9, rz: 0.28 } },
    { at: rise + 0.8, pose: { x: 0.08, y: whole(2.2) + 0.05, z: 2.2, rx: 0.12, ry: PI + 0.42, rz: 0.07 }, ease: out },
    { at: rise + 1.25, pose: { x: 0.04, y: whole(2.1), z: 2.1, rx: 0.08, ry: PI + 0.2, rz: 0.04 }, ease: (n) => n },
    { at: rise + 2.0, pose: { x: 0, y: whole(1.5), z: 1.5, rx: -0.04, ry: PI * 2 - 0.2, rz: 0.012 }, ease: inOut },
    { at: right - 0.05, pose: { x: 0, y: whole(1.6), z: 1.6, rx: -0.03, ry: PI * 2 - 0.1, rz: 0.008 }, ease: (n) => n },
    // In on the deck.
    { at: right + 1.4 * BEAT, pose: { x: 0, y: yCard(2.40, 940), z: 2.40, rx: 0.02, ry: PI * 2, rz: 0 }, ease: out },
    { at: first.grab, pose: { x: 0, y: yCard(2.45, 940), z: 2.45, rx: 0.02, ry: PI * 2, rz: 0 }, ease: (n) => n },
    // The phone leans the way the card goes, so the card stands off the glass.
    { at: first.grab + 0.6, pose: { x: -0.04, y: yCard(2.30, 940), z: 2.30, rx: 0.1, ry: PI * 2 + 0.3, rz: -0.02 }, ease: out },
    { at: first.fling, pose: { x: -0.04, y: yCard(2.35, 940), z: 2.35, rx: 0.1, ry: PI * 2 + 0.36, rz: -0.02 }, ease: (n) => n },
    { at: first.fling + 0.5, pose: { x: -0.06, y: yCard(2.15, 940), z: 2.15, rx: 0.08, ry: PI * 2 + 0.46, rz: -0.03 }, ease: out },
    { at: second.grab, pose: { x: 0, y: yCard(2.40, 940), z: 2.40, rx: 0.03, ry: PI * 2, rz: 0 } },
    { at: second.grab + 0.6, pose: { x: 0.04, y: yCard(2.30, 940), z: 2.30, rx: 0.1, ry: PI * 2 - 0.3, rz: 0.02 }, ease: out },
    { at: second.fling, pose: { x: 0.04, y: yCard(2.35, 940), z: 2.35, rx: 0.1, ry: PI * 2 - 0.36, rz: 0.02 }, ease: (n) => n },
    { at: second.fling + 0.5, pose: { x: 0.06, y: yCard(2.1, 940), z: 2.1, rx: 0.08, ry: PI * 2 - 0.5, rz: 0.03 }, ease: out },
    { at: fast - 0.1, pose: { x: 0.06, y: yCard(2.15, 940), z: 2.15, rx: 0.08, ry: PI * 2 - 0.44, rz: 0.03 }, ease: (n) => n },
    // Back a little and to three-quarters: the cards go quickly now.
    { at: fast + 0.5, pose: { x: 0.12, y: yCard(1.9, 960), z: 1.9, rx: 0.13, ry: PI * 2 - 0.34, rz: 0.02 }, ease: inOut },
    { at: end - 0.2, pose: { x: 0.06, y: yCard(2.0, 960), z: 2.0, rx: 0.1, ry: PI * 2 - 0.16, rz: 0.012 }, ease: (n) => n },
    { at: end + 0.4, pose: { x: 0.5, y: MID - 0.4, z: -7, rx: 0.3, ry: PI * 2 + 1.2, rz: 0.2 }, ease: (n) => n * n },
  ];
  /** The phone's transform at any moment, with its idle drift: the scene and the flights both use it. */
  const phoneAt = (tt: number) => {
    const q = poseAt(keys, tt);
    return { position: [q.x, q.y + Math.sin(tt * 1.3) * 0.012, q.z] as [number, number, number], rotation: [q.rx + Math.sin(tt * 0.9) * 0.008, q.ry, q.rz] as [number, number, number] };
  };
  const pose = poseAt(keys, t);
  const before = poseAt(keys, t - 1 / REEL_FPS);
  const turning = Math.abs(pose.ry - before.ry) * REEL_FPS;
  const matrix = new THREE.Matrix4().makeTranslation(pose.x, pose.y, pose.z).multiply(new THREE.Matrix4().makeRotationFromEuler(new THREE.Euler(pose.rx, pose.ry, pose.rz, 'YXZ')));
  const project = (x: number, y: number) => {
    const v = new THREE.Vector3(...onScreen(x, y)).applyMatrix4(matrix);
    const k = FOCAL / (CAM_Z - v.z);
    return { x: 540 + v.x * k, y: 960 - v.y * k };
  };
  const centre = project(603, 1311);
  const size = (FOCAL / (CAM_Z - pose.z)) * 0.8;
  const shadow = { x: centre.x, y: centre.y, w: Math.max(60, PHONE.w * size * Math.abs(Math.cos(pose.ry))), h: PHONE.h * size };
  const glare = [rise + 1.75, fast + 0.5].reduce((g, start) => (t >= start && t < start + 0.9 ? (t - start) / 0.9 : g), -1);
  const back = swipes[swipes.length - 1].fling + 0.35; // the card sent left is on top again
  const stampAt = back + 0.45;
  const landed = (dir: number) => swipes.filter((sw) => sw.dir === dir && t >= sw.fling + FLIGHT);
  // Every landing gives the frame a small knock.
  const knock = swipes.reduce((k, sw) => { const age = t - sw.fling - FLIGHT; return age >= 0 && age < 0.3 ? k + Math.exp(-age * 16) * Math.sin(age * 70) * 5 : k; }, 0) + (t >= stampAt && t < stampAt + 0.35 ? Math.exp(-(t - stampAt) * 14) * Math.cos((t - stampAt) * 60) * 12 : 0);
  return { t, episode, s, timing, at, end, rise, pose, turning, project, glare, shadow, cards, top, swipes, landed, back, stampAt, phoneAt, knock };
};

/** A pill like the app's own verdict on a dragged card. */
const badgeTexture = (text: string, mark: string, color: string) =>
  canvasTexture(640, 200, (ctx, w, h) => {
    ctx.fillStyle = color;
    ctx.beginPath();
    ctx.roundRect(8, 8, w - 16, h - 16, 92);
    ctx.fill();
    ctx.fillStyle = '#FFFDF6';
    ctx.font = `900 92px ${FONT}`;
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillText(`${mark} ${text}`, w / 2, h / 2 + 6);
  });

/** The back of a card that has been sent away: lined paper, and a promise. */
const backTexture = (text: string) =>
  canvasTexture(1108, 1760, (ctx, w, h) => {
    ctx.fillStyle = '#F6EFDD';
    ctx.fillRect(0, 0, w, h);
    ctx.strokeStyle = 'rgba(120,110,90,0.22)';
    ctx.lineWidth = 3;
    for (let y = 150; y < h; y += 92) {
      ctx.beginPath();
      ctx.moveTo(0, y);
      ctx.lineTo(w, y);
      ctx.stroke();
    }
    ctx.strokeStyle = 'rgba(201,100,66,0.5)';
    ctx.beginPath();
    ctx.moveTo(110, 0);
    ctx.lineTo(110, h);
    ctx.stroke();
    ctx.translate(w / 2, h / 2);
    ctx.rotate(-0.08);
    ctx.strokeStyle = PAL.clay;
    ctx.lineWidth = 12;
    ctx.beginPath();
    ctx.roundRect(-400, -130, 800, 260, 30);
    ctx.stroke();
    ctx.fillStyle = PAL.clay;
    ctx.font = `900 130px ${SERIF_TC}`;
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillText(text, 0, 8, 720);
  });

const cardShadow = canvasTexture(256, 256, (ctx, w, h) => {
  ctx.filter = 'blur(22px)';
  ctx.fillStyle = 'rgba(40,32,20,0.8)';
  ctx.fillRect(50, 50, w - 100, h - 100);
});

/**
 * A rubber stamp's impression: clay ink in a double frame, worn where the
 * rubber did not meet the paper. It goes on the card itself.
 */
const inkTexture = (text: string) =>
  canvasTexture(1024, 420, (ctx, w, h) => {
    let seed = 7;
    const rnd = () => (seed = (seed * 16807) % 2147483647) / 2147483647;
    ctx.strokeStyle = PAL.clay;
    ctx.fillStyle = PAL.clay;
    ctx.lineWidth = 16;
    ctx.beginPath();
    ctx.roundRect(16, 16, w - 32, h - 32, 44);
    ctx.stroke();
    ctx.lineWidth = 5;
    ctx.beginPath();
    ctx.roundRect(42, 42, w - 84, h - 84, 26);
    ctx.stroke();
    ctx.font = `900 ${/[a-z]/i.test(text) ? 150 : 210}px ${SERIF_TC}`;
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillText(text, w / 2, h / 2 + 10, w - 150);
    // Where the ink is thin: soft patches, then pinholes, then a few dry streaks.
    ctx.globalCompositeOperation = 'destination-out';
    for (let i = 0; i < 9; i++) {
      const x = rnd() * w;
      const y = rnd() * h;
      const r = 70 + rnd() * 150;
      const g = ctx.createRadialGradient(x, y, 0, x, y, r);
      g.addColorStop(0, `rgba(0,0,0,${0.16 + rnd() * 0.22})`);
      g.addColorStop(1, 'rgba(0,0,0,0)');
      ctx.fillStyle = g;
      ctx.fillRect(x - r, y - r, r * 2, r * 2);
    }
    ctx.fillStyle = 'rgba(0,0,0,0.85)';
    for (let i = 0; i < 3200; i++) {
      ctx.beginPath();
      ctx.arc(rnd() * w, rnd() * h, 0.5 + rnd() * rnd() * 3.2, 0, PI * 2);
      ctx.fill();
    }
    ctx.strokeStyle = 'rgba(0,0,0,0.5)';
    for (let i = 0; i < 16; i++) {
      ctx.lineWidth = 1 + rnd() * 2.5;
      const x = rnd() * w;
      const y = rnd() * h;
      ctx.beginPath();
      ctx.moveTo(x, y);
      ctx.lineTo(x + 40 + rnd() * 160, y - 6 + rnd() * 12);
      ctx.stroke();
    }
  });

const touchDot = canvasTexture(128, 128, (ctx, w) => {
  const g = ctx.createRadialGradient(w / 2, w / 2, 0, w / 2, w / 2, w / 2);
  g.addColorStop(0, 'rgba(255,255,255,0.75)');
  g.addColorStop(0.45, 'rgba(255,255,255,0.4)');
  g.addColorStop(0.8, 'rgba(255,255,255,0.12)');
  g.addColorStop(1, 'rgba(255,255,255,0)');
  ctx.fillStyle = g;
  ctx.fillRect(0, 0, w, w);
  ctx.strokeStyle = 'rgba(255,255,255,0.55)';
  ctx.lineWidth = 3;
  ctx.beginPath();
  ctx.arc(w / 2, w / 2, w * 0.36, 0, PI * 2);
  ctx.stroke();
});
/** The light that slides over paper as it tilts. */
const sheen = canvasTexture(256, 256, (ctx, w, h) => {
  const g = ctx.createLinearGradient(0, 0, w, h);
  g.addColorStop(0.2, 'rgba(255,255,255,0)');
  g.addColorStop(0.5, 'rgba(255,252,240,0.5)');
  g.addColorStop(0.8, 'rgba(255,255,255,0)');
  ctx.fillStyle = g;
  ctx.fillRect(0, 0, w, h);
});

const cardSize = (rect: [number, number, number], top: number) => ({ w: ((rect[1] - rect[0]) / SCREEN_W) * PHONE.w, h: ((rect[2] - top) / SCREEN_H) * PHONE.h });
const useCardGeometry = (rect: [number, number, number], top: number) => {
  const [x0, x1, y1] = rect;
  const { w, h } = cardSize(rect, top);
  return useMemo(() => {
    const front = new THREE.ShapeGeometry(roundedRect(w, h, 0.012), 6);
    const pos = front.attributes.position;
    const uv = front.attributes.uv;
    for (let i = 0; i < pos.count; i++) uv.setXY(i, (x0 + (pos.getX(i) / w + 0.5) * (x1 - x0)) / SCREEN_W, 1 - (top + (0.5 - pos.getY(i) / h) * (y1 - top)) / SCREEN_H);
    return { front, plain: new THREE.PlaneGeometry(w, h) };
  }, [w, h, x0, top, x1, y1]);
};

/** A card's two sides, centred on its middle: the screenshot's card, the verdict's wash and badge, a paper edge, and the back. */
const CardFaces = ({ geo, h, map, back, badges, right, wash, badge, glint, dim = 1, opacity = 1 }: { geo: { front: THREE.BufferGeometry; plain: THREE.BufferGeometry }; h: number; map: THREE.Texture; back: THREE.Texture; badges: [THREE.Texture, THREE.Texture]; right: boolean; wash: number; badge: number; glint: number; dim?: number; opacity?: number }) => (
  <>
    {/* The thickness of the paper: a darker sheet just behind and below. */}
    {opacity >= 1 ? (
      <mesh geometry={geo.plain} position={[0.004, -0.006, -0.0012]} renderOrder={4}>
        <meshBasicMaterial color="#B9AE95" transparent opacity={0.9} toneMapped={false} />
      </mesh>
    ) : null}
    <mesh geometry={geo.front} renderOrder={5}>
      <meshBasicMaterial map={map} toneMapped={false} transparent opacity={opacity} depthWrite={opacity >= 1} color={new THREE.Color().setScalar(dim)} />
    </mesh>
    {wash > 0.003 ? (
      <mesh geometry={geo.plain} position={[0, 0, 0.0006]} renderOrder={6}>
        <meshBasicMaterial color={right ? PAL.sage : PAL.clay} transparent opacity={wash * opacity} depthWrite={false} toneMapped={false} />
      </mesh>
    ) : null}
    {glint > 0.01 ? (
      <mesh geometry={geo.plain} position={[0, 0, 0.0009]} renderOrder={6}>
        <meshBasicMaterial map={sheen} transparent opacity={glint * 0.2 * opacity} depthWrite={false} toneMapped={false} blending={THREE.AdditiveBlending} />
      </mesh>
    ) : null}
    {badge > 0.01 ? (
      <mesh position={[0, h * 0.495, 0.0014]} scale={[0.46 * badge, 0.144 * badge, 1]} rotation={[0, 0, right ? 0.1 : -0.1]} renderOrder={7}>
        <planeGeometry args={[1, 1]} />
        <meshBasicMaterial map={badges[right ? 0 : 1]} transparent opacity={Math.min(1, badge) * opacity} depthWrite={false} toneMapped={false} />
      </mesh>
    ) : null}
    <mesh geometry={geo.plain} rotation={[0, PI, 0]} position={[0, 0, -0.0016]} renderOrder={5}>
      <meshBasicMaterial map={back} toneMapped={false} transparent opacity={opacity} depthWrite={opacity >= 1} />
    </mesh>
  </>
);

type Shared = { map: THREE.Texture; back: THREE.Texture; badges: [THREE.Texture, THREE.Texture]; top: number; rect: [number, number, number] };

/** A card on the phone: waiting in the deck, or in the fingertip's hand. */
const SwipeCard = ({ map, back, badges, top, rect, state, t }: Shared & { state: CardState; t: number }) => {
  const [x0, x1, y1] = rect;
  const { w, h } = cardSize(rect, top);
  const geo = useCardGeometry(rect, top);
  if (state.fade <= 0) return null;
  const [cx, cy, z] = onScreen((x0 + x1) / 2, (top + y1) / 2, 0.003);
  const right = state.drag > 0;
  // The card turns on its foot, as it does in the app.
  const tilt = -state.drag * 0.42;
  return (
    <>
      {state.lift > 0.002 ? (
        <mesh position={[cx + state.drag * w * 0.9 + state.lift * 0.5, cy - state.lift * 0.7, z + 0.0002]} scale={[w * 1.22, h * 1.16, 1]} rotation={[0, 0, tilt]} renderOrder={4}>
          <planeGeometry args={[1, 1]} />
          <meshBasicMaterial map={cardShadow} transparent opacity={Math.min(0.55, 0.25 + state.lift * 5)} depthWrite={false} toneMapped={false} />
        </mesh>
      ) : null}
      <group position={[cx + state.drag * w, cy - h / 2, z + 0.0004 + state.lift]} rotation={[0, 0, tilt]} scale={0.955 + 0.045 * state.under}>
        <group position={[0, h / 2, 0]}>
          <CardFaces geo={geo} h={h} map={map} back={back} badges={badges} right={right} wash={Math.min(0.24, Math.abs(state.drag) * 0.6)} badge={Math.min(1, Math.max(0, (Math.abs(state.drag) - 0.06) / 0.14))} glint={Math.min(1, Math.abs(state.drag) * 2.5)} dim={0.9 + 0.1 * state.under} />
        </group>
        {state.touching ? (
          <mesh position={[0, h * 0.3, 0.003]} scale={0.15 + Math.sin(t * 6) * 0.006} renderOrder={8}>
            <planeGeometry args={[1, 1]} />
            <meshBasicMaterial map={touchDot} transparent depthWrite={false} toneMapped={false} />
          </mesh>
        ) : null}
      </group>
    </>
  );
};

type Flight = { fling: number; dir: number; nth: number; from: { position: [number, number, number]; rotation: [number, number, number] } };
/**
 * Where each pile sits: beside the phone and behind it. Everything a card does happens nearer the
 * lens than its pile (in the hand, in the air), so a pile can never show through a card.
 */
const PILE_Z = 1.1;
const PILE_X = { 1: 944, [-1]: 136 } as Record<number, number>;
const pileAt = (dir: number) => new THREE.Vector3(((PILE_X[dir] - 540) / FOCAL) * (CAM_Z - PILE_Z), ((960 - 474) / FOCAL) * (CAM_Z - PILE_Z), PILE_Z);
const PILE_SCALE = 0.4;
const LEAN = [-0.1, 0.07, -0.03, 0.12, -0.07];

/**
 * A card that has been flung: it leaves the phone where the fingertip let
 * go, arcs towards the lens and over to its pile, and stays there. One
 * sent left turns over on the way, so that pile is all backs.
 */
const FlyingCard = ({ map, back, badges, top, rect, flight, t, ghost = 0 }: Shared & { flight: Flight; t: number; ghost?: number }) => {
  const [x0, x1, y1] = rect;
  const { w, h } = cardSize(rect, top);
  const geo = useCardGeometry(rect, top);
  const u = Math.min(1, Math.max(0, (t - ghost - flight.fling) / FLIGHT));
  if (t < flight.fling || (ghost > 0 && (u <= 0 || u >= 1))) return null;
  const e = inOut(u);
  // Where it was let go, in the room.
  const phone = new THREE.Matrix4().makeTranslation(...flight.from.position).multiply(new THREE.Matrix4().makeRotationFromEuler(new THREE.Euler(...flight.from.rotation, 'YXZ')));
  const [cx, cy, z] = onScreen((x0 + x1) / 2, (top + y1) / 2, 0.003);
  const drag = flight.dir * 0.4;
  const local = new THREE.Matrix4()
    .makeTranslation(cx + drag * w, cy - h / 2, z + 0.05)
    .multiply(new THREE.Matrix4().makeRotationZ(-drag * 0.42))
    .multiply(new THREE.Matrix4().makeTranslation(0, h / 2, 0));
  const p0 = new THREE.Vector3();
  const q0 = new THREE.Quaternion();
  const s0 = new THREE.Vector3();
  phone.multiply(local).decompose(p0, q0, s0);
  // Where it comes to rest.
  const p1 = pileAt(flight.dir).add(new THREE.Vector3(LEAN[flight.nth % 5] * 0.3, -flight.nth * 0.016, flight.nth * 0.01));
  const q1 = new THREE.Quaternion().setFromEuler(new THREE.Euler(0, flight.dir < 0 ? PI : 0, LEAN[flight.nth % 5] * (flight.dir < 0 ? -1 : 1)));
  const pos = p0.clone().lerp(p1, e);
  // It lifts towards the lens as it leaves, then falls away to the pile behind the phone.
  pos.z += Math.sin(PI * Math.min(1, u * 1.4)) * 0.4;
  pos.y += Math.sin(PI * u) * 0.12;
  const quat = q0.clone().slerp(q1, e);
  const size = 1 + (PILE_SCALE - 1) * e;
  const opacity = ghost > 0 ? 0.13 * Math.sin(PI * u) : 1;
  return (
    <group position={pos} quaternion={quat} scale={size}>
      {ghost === 0 ? (
        <mesh position={[0.03, -0.045, -0.01]} scale={[w * 1.2, h * 1.14, 1]} renderOrder={4}>
          <planeGeometry args={[1, 1]} />
          <meshBasicMaterial map={cardShadow} transparent opacity={0.5 * e} depthWrite={false} toneMapped={false} side={THREE.DoubleSide} />
        </mesh>
      ) : null}
      <CardFaces geo={geo} h={h} map={map} back={back} badges={badges} right={flight.dir > 0} wash={0.24 * (1 - e)} badge={1 - Math.min(1, u * 3)} glint={Math.sin(PI * u)} opacity={opacity} />
    </group>
  );
};

const Stage = ({ id }: { id: string }) => {
  const gl = useThree((state) => state.gl);
  const film = useFilm(id);
  const { t, s, pose } = film;
  const maps = usePrepared(async () => {
    await Promise.all([document.fonts.load(`900 92px ${FONT}`, s.badges.join('')), document.fonts.load(`900 130px ${SERIF_TC}`, s.back + s.returns)]);
    const [base, env, phone, ...cards] = await Promise.all([imageTexture(`${s.base}.jpg`), loadStudio(gl), loadPhone(), ...s.cards.map(([shot]) => imageTexture(`${shot}.jpg`))]);
    return {
      base: base as THREE.Texture,
      env: env as THREE.Texture,
      phone: phone as THREE.Object3D,
      cards: cards as THREE.Texture[],
      back: backTexture(s.back),
      ink: inkTexture(s.returns),
      badges: [badgeTexture(s.badges[0], '✓', PAL.sage), badgeTexture(s.badges[1], '✕', PAL.clay)] as [THREE.Texture, THREE.Texture],
      ground: colorAt(base as THREE.Texture, 16, 1400),
    };
  });
  const [x0, x1, y1] = s.rect;
  const deckTop = Math.min(...s.cards.map(([, y]) => y));
  const patch = useMemo(() => new THREE.PlaneGeometry(((x1 - x0 + 16) / SCREEN_W) * PHONE.w, ((y1 - deckTop + 30) / SCREEN_H) * PHONE.h), [x0, x1, y1, deckTop]);
  if (!maps || t < film.rise - 0.05) return null;
  // The deck, bottom up: the card after next is never seen; the next one waits; the top one is in hand; the last one flung may still be in the air.
  const order = [film.top + 1, film.top].filter((i) => i >= 0 && i < s.cards.length);
  const sw = film.swipes;
  const counts: Record<number, number> = { 1: 0, [-1]: 0 };
  const flights: Flight[] = sw.map((x) => ({ fling: x.fling, dir: x.dir, nth: counts[x.dir]++, from: film.phoneAt(x.fling) }));
  return (
    <>
      <StudioLight env={maps.env} turn={t * 0.12 + pose.ry * 0.25} />
      <group position={[pose.x, pose.y + Math.sin(t * 1.3) * 0.012, pose.z]} rotation={[pose.rx + Math.sin(t * 0.9) * 0.008, pose.ry, pose.rz, 'YXZ']}>
        <Phone3D model={maps.phone} screen={maps.base} glare={film.glare}>
          {/* The page under the deck, so the screenshot's own card is not there twice. */}
          <mesh geometry={patch} position={[...onScreen((x0 + x1) / 2, (deckTop - 22 + y1) / 2, 0.0019)] as [number, number, number]} renderOrder={2}>
            <meshBasicMaterial color={maps.ground} toneMapped={false} depthWrite={false} transparent />
          </mesh>
          {order.map((i, k) => (
            <group key={i} position={[0, 0, k * 0.003]}>
              <SwipeCard map={maps.cards[i]} back={maps.back} badges={maps.badges} top={s.cards[i][1]} rect={s.rect} state={film.cards[i]} t={t} />
            </group>
          ))}
          {/* The one sent left is back on top, and gets stamped for it. */}
          {t >= film.stampAt ? (
            <mesh position={[...onScreen((x0 + x1) / 2 - 110, s.cards[s.cards.length - 1][1] + (y1 - s.cards[s.cards.length - 1][1]) * 0.84, 0.012)] as [number, number, number]} rotation={[0, 0, -0.16]} scale={[0.66 * (1 + Math.exp(-(t - film.stampAt) * 16) * 0.9), 0.27 * (1 + Math.exp(-(t - film.stampAt) * 16) * 0.9), 1]} renderOrder={9}>
              <planeGeometry args={[1, 1]} />
              <meshBasicMaterial map={maps.ink} transparent opacity={0.94 * ramp(t, film.stampAt, film.stampAt + 0.06, (n) => n)} depthWrite={false} toneMapped={false} />
            </mesh>
          ) : null}
          {sw.map((x, i) => (
            <Tap3D key={i} t={t} at={x.grab - 0.1} x={(x0 + x1) / 2} y={s.cards[i][1] + (y1 - s.cards[i][1]) * 0.2} />
          ))}
        </Phone3D>
      </group>
      {/* The cards that have left the phone: in the air, with the blur of their movement, or at rest on their pile. */}
      {flights.map((f, i) => {
        const shared = { map: maps.cards[i], back: maps.back, badges: maps.badges, top: s.cards[i][1], rect: s.rect };
        return (
          <group key={i}>
            <FlyingCard {...shared} flight={f} t={t} ghost={0.034} />
            <FlyingCard {...shared} flight={f} t={t} ghost={0.017} />
            <FlyingCard {...shared} flight={f} t={t} />
          </group>
        );
      })}
    </>
  );
};

/**
 * 傻貓, watching from the corner the whole time: one cat that stays, whose
 * face changes with each card and who hops when one lands.
 */
const Buddy = ({ film }: { film: ReturnType<typeof useFilm> }) => {
  const { t, end, swipes, stampAt } = film;
  const arrive = swipes[0].grab - 0.3;
  if (t < arrive) return null;
  const events: { at: number; mood: Mood; stay: boolean }[] = [...swipes.map((sw) => ({ at: sw.fling + FLIGHT, mood: (sw.dir > 0 ? 'happy' : 'annoyed') as Mood, stay: false })), { at: stampAt, mood: 'cheeky' as Mood, stay: true }];
  const now = [...events].reverse().find((e) => t >= e.at);
  const age = now ? t - now.at : 9;
  const mood: Mood = now && (now.stay || age < 1.0) ? now.mood : 'smug';
  const inP = ramp(t, arrive, arrive + 0.5, out) * (1 - ramp(t, end - 0.25, end + 0.1, inOut));
  const hop = age < 0.6 ? Math.exp(-age * 7) * Math.sin(age * 17) : 0;
  const squash = age < 0.3 ? Math.exp(-age * 12) * 0.07 : 0;
  return (
    <div style={{ position: 'absolute', left: -96 - (1 - inP) * 360, top: 1068 - hop * 30, transform: `rotate(${13 + hop * 3}deg) scale(${1 + squash}, ${1 - squash})`, transformOrigin: '30% 100%', filter: 'drop-shadow(0 18px 20px rgba(30,34,14,0.34))' }}>
      <Mascot mood={mood} size={400} next />
    </div>
  );
};

export const Day5 = ({ id }: { id: string }) => {
  const frameNo = useCurrentFrame();
  const film = useFilm(id);
  const { t, episode, s, timing, at, end, rise } = film;

  const stamp = <DaysStamp days={episode.days} words={episode.dayWords} note={episode.note} />;
  // The cover tips back and away as the phone comes up through where it was.
  const tip = ramp(t, rise - 0.12, rise + 0.38, inOut);
  const leave = ramp(t, end - 0.15, end + 0.35, inOut);
  const smear = Math.min(26, Math.max(0, film.turning - 2.5) * 2.4);
  const lit = ramp(t, rise, rise + 0.8, (n) => n) * (1 - leave);

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
      <DeepBackdrop t={t} frame={frameNo} drift={(film.pose.y - MID) * 260 + film.pose.x * 500} focus={lit} cards={s.desk.map(([src, top]) => (src ? { src: `${src}.jpg`, crop: [s.rect[0], top, s.rect[1] - s.rect[0], s.rect[2] - top] as [number, number, number, number] } : {}))} />
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
      <Peek t={t} at={0} until={rise + 0.3} side={1} mood="smug" y={760} outAt={rise - 0.14} />

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

      {/* The phone. */}
      {t >= rise - 0.2 && leave < 1 ? (
        <AbsoluteFill style={{ opacity: 1 - leave, transform: `translateY(${film.knock}px)`, ...ABOVE_CAPTIONS }}>
          <AbsoluteFill
            style={{
              filter: smear > 0.5 ? 'url(#smear)' : leave > 0 ? `blur(${leave * 12}px)` : undefined,
            }}
          >
            <ThreeCanvas width={1080} height={1920} dpr={1} gl={{ antialias: true, alpha: true, toneMapping: THREE.ACESFilmicToneMapping, toneMappingExposure: 1.0 }} camera={{ fov: FOV, near: 0.5, far: 60, position: [0, 0, CAM_Z] }}>
              <Stage id={id} />
            </ThreeCanvas>
          </AbsoluteFill>
        </AbsoluteFill>
      ) : null}

      {/* What comes out of the phone. */}
      {/* A paper label over each pile, and its count. */}
      {([1, -1] as const).map((dir) => {
        const pile = film.landed(dir);
        const first = film.swipes[0].grab;
        const show = ramp(t, first - 0.5, first - 0.1, out) * (1 - ramp(t, end - 0.3, end, inOut));
        if (show <= 0) return null;
        const last = pile.length ? pile[pile.length - 1].fling + FLIGHT : -9;
        const age = t - last;
        const bump = age >= 0 && age < 0.5 ? Math.exp(-age * 9) * Math.cos(age * 16) : 0;
        const color = dir > 0 ? '#5F8050' : '#C96442';
        // The number rolls: the old one leaves upward as the new one arrives.
        const roll = age >= 0 && age < 0.28 ? 1 - out(age / 0.28) : 0;
        return (
          <div key={dir} style={{ position: 'absolute', left: PILE_X[dir] - 118, top: 244 + film.knock * 0.6, width: 236, opacity: show, transform: `translateY(${(1 - show) * -120}px) rotate(${dir > 0 ? 2.5 : -2.5}deg) scale(${1 + bump * 0.1})`, transformOrigin: '50% 50%' }}>
            <div style={{ position: 'absolute', left: 78, top: -16, width: 80, height: 30, background: 'rgba(238,226,190,0.78)', transform: 'rotate(-3deg)', boxShadow: '0 1px 2px rgba(0,0,0,0.12)' }} />
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '8px 14px 8px 16px', borderRadius: 6, backgroundColor: '#FBF6EA', backgroundImage: `url(${staticFile('paper-grain.png')})`, backgroundBlendMode: 'multiply', backgroundSize: '300px', boxShadow: '0 10px 22px rgba(30,30,10,0.32), 0 1px 0 rgba(255,255,255,0.6) inset', border: '1px solid rgba(90,80,50,0.16)' }}>
              <span style={{ fontWeight: 900, fontSize: s.tally[0].length > 3 ? 25 : 34, color, letterSpacing: s.tally[0].length > 3 ? '0.01em' : '0.04em', whiteSpace: 'nowrap' }}>
                {dir > 0 ? '✓' : '✕'} {s.tally[dir > 0 ? 0 : 1]}
              </span>
              <span style={{ position: 'relative', display: 'block', width: 44, height: 58, overflow: 'hidden' }}>
                <span style={{ position: 'absolute', inset: 0, textAlign: 'right', fontFamily: SERIF, fontWeight: 800, fontSize: 54, lineHeight: '58px', color: '#2B2620', transform: `translateY(${roll * 58}px)` }}>{pile.length}</span>
                {roll > 0 ? <span style={{ position: 'absolute', inset: 0, textAlign: 'right', fontFamily: SERIF, fontWeight: 800, fontSize: 54, lineHeight: '58px', color: '#2B2620', transform: `translateY(${(roll - 1) * 58}px)` }}>{pile.length - 1}</span> : null}
              </span>
            </div>
          </div>
        );
      })}
      <Buddy film={film} />
      <Foreground t={t} drift={(film.pose.y - MID) * 260 + film.pose.x * 500} show={lit} />
      <Motes t={t} front />
      {episode.lines.map((line, i) => (
        <Caption key={i} text={line.text} start={timing.slots[i].start} length={timing.slots[i].length} t={t} first={i === 0} label={episode.label} top={CAPTION_TOP} size={62} glass />
      ))}
      <CountdownEnd t={t} end={end} episode={episode} stamp={stamp} />
      <Grade frame={frameNo} />
    </AbsoluteFill>
  );
};
