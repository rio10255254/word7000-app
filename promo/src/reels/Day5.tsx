import { ThreeCanvas } from '@remotion/three';
import { useThree } from '@react-three/fiber';
import { useMemo } from 'react';
import { AbsoluteFill, Html5Audio, staticFile, useCurrentFrame } from 'remotion';
import * as THREE from 'three';
import { FONT, SERIF_TC } from '../fonts';
import script from './episodes.json';
import timings from './timing.json';
import { REEL_FPS } from './Reel';
import { Caption } from './Intro';
import { ABOVE_CAPTIONS, CAPTION_TOP, Peek } from './Teaser';
import { CountdownEnd, DaysStamp, StampCard } from './Countdown';
import { Counter } from './props';
import { Backdrop, Grade, InkFilters, Motes } from './finish';
import { Lift, PAL, PHONE, SCREEN_H, SCREEN_W, canvasTexture, colorAt, Phone3D, ScreenLayer, StudioLight, Tap3D, imageTexture, inOut, loadPhone, loadStudio, onScreen, out, ramp, roundedRect, usePrepared } from './three/kit';

/**
 * 11/11, five days to go: flashcards you swipe.
 *
 * Cover, then the phone rises back-first and turns to face you on a word
 * card. A fingertip takes the card and drags it right: it tilts on its
 * foot, washes green, and the app's own verdict ("認識") shows on it; let
 * go and it springs back. Then left: red, "不熟", and this time it is
 * flung. It leaves the glass, turns over in the air to a paper back that
 * says it will be back, and is gone. The phone whips round once and
 * comes back on today's page at three-quarters, the day's ring lifting
 * off the glass while a counter runs up beside it.
 *
 * The card is the real screenshot's card, cut out; the rest of the
 * episode's `scene` says which screenshots, where, and what the labels are.
 */

const BEAT = 0.5;
const PI = Math.PI;
const CAM_Z = 9;
const FOV = 30;
const FOCAL = 960 / Math.tan(((FOV / 2) * PI) / 180);
const MID = ((960 - 825) / FOCAL) * CAM_Z;

type Slot = { start: number; length: number };
type Crop = [number, number, number, number, number, number];
type Prop = { kind: 'counter'; slot: number; beat: number; from: [number, number]; at: [number, number]; tilt: number; label: string; unit: string; to: number };
type Scene = { card: string; cardCrop: [number, number, number, number]; look: number; badges: [string, string]; back: string; today: string; todayLook: number; todayLifts: Crop[]; props: Prop[] };
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
const frame = (y: number, row: number, z: number) => ((960 - row) / FOCAL) * (CAM_Z - z) - (0.5 - y / 2622) * PHONE.h;

const useFilm = (id: string) => {
  const t = useCurrentFrame() / REEL_FPS;
  const episode = script.episodes.find((e) => e.id === id)! as unknown as Episode;
  const s = episode.scene;
  const timing = (timings as Record<string, { total: number; end: number; slots: Slot[] }>)[id];
  const starts = timing.slots.map((slot) => slot.start);
  const [, right, left, count] = starts;
  const end = timing.end;
  const at = (slot: number, beat: number) => starts[slot] + beat * BEAT;

  const rise = 2 * BEAT;
  // The drags: right and back, then left and away.
  const grabR = right + 2 * BEAT;
  const letGo = right + 5.5 * BEAT;
  const grabL = left + 1.5 * BEAT;
  const fling = left + 4 * BEAT;
  const spin = left + 6.2 * BEAT;
  const back = t < letGo ? 0 : 1 - Math.exp(-(t - letGo) * 9) * Math.cos((t - letGo) * 15);
  const r = ramp(t, grabR, grabR + 0.5, out) * (1 - back);
  const l = ramp(t, grabL, grabL + 0.5, out);
  const gone = ramp(t, fling, fling + 0.95, (n) => n * (2 - n) * 0.6 + n * n * 0.4);
  // A held card is never quite still.
  const held = (r > 0.9 || (l > 0.9 && gone === 0) ? Math.sin(t * 5) * 0.012 : 0);
  const drag = 0.4 * r - 0.4 * l - 1.45 * gone + held;
  const card = { drag, lift: 0.05 * Math.max(r, l) + 0.85 * gone, flip: -ramp(t, fling + 0.05, fling + 0.55, inOut) * PI, rise: gone * 0.5, fade: 1 - ramp(t, fling + 0.78, fling + 0.98, (n) => n), touching: (t > grabR && t < letGo) || (t > grabL && t < fling), grabs: [grabR, grabL] };

  const whole = (z: number, row = 825) => frame(1311, row, z);
  const yCard = (z: number) => frame(s.look, 830, z);
  const keys: Key[] = [
    { at: rise, pose: { x: 0.25, y: -5.4, z: 0, rx: 0.55, ry: PI + 0.9, rz: 0.28 } },
    { at: rise + 0.8, pose: { x: 0.08, y: whole(2.2) + 0.05, z: 2.2, rx: 0.12, ry: PI + 0.42, rz: 0.07 }, ease: out },
    { at: rise + 1.25, pose: { x: 0.04, y: whole(2.1), z: 2.1, rx: 0.08, ry: PI + 0.2, rz: 0.04 }, ease: (n) => n },
    { at: rise + 2.0, pose: { x: 0, y: whole(1.5), z: 1.5, rx: -0.04, ry: PI * 2 - 0.2, rz: 0.012 }, ease: inOut },
    { at: right - 0.05, pose: { x: 0, y: whole(1.6), z: 1.6, rx: -0.03, ry: PI * 2 - 0.1, rz: 0.008 }, ease: (n) => n },
    // In on the card.
    { at: right + 1.4 * BEAT, pose: { x: 0, y: yCard(2.7), z: 2.7, rx: 0.02, ry: PI * 2, rz: 0 }, ease: out },
    { at: grabR, pose: { x: 0, y: yCard(2.75), z: 2.75, rx: 0.02, ry: PI * 2, rz: 0 }, ease: (n) => n },
    // The phone leans the way the card goes, so the card stands off the glass.
    { at: grabR + 0.6, pose: { x: -0.1, y: yCard(2.6), z: 2.6, rx: 0.1, ry: PI * 2 + 0.3, rz: -0.02 }, ease: out },
    { at: letGo, pose: { x: -0.1, y: yCard(2.65), z: 2.65, rx: 0.1, ry: PI * 2 + 0.36, rz: -0.02 }, ease: (n) => n },
    { at: grabL, pose: { x: 0, y: yCard(2.7), z: 2.7, rx: 0.03, ry: PI * 2, rz: 0 } },
    { at: grabL + 0.6, pose: { x: 0.1, y: yCard(2.6), z: 2.6, rx: 0.1, ry: PI * 2 - 0.3, rz: 0.02 }, ease: out },
    { at: fling, pose: { x: 0.1, y: yCard(2.65), z: 2.65, rx: 0.1, ry: PI * 2 - 0.36, rz: 0.02 }, ease: (n) => n },
    // It follows the card out, a little.
    { at: fling + 0.5, pose: { x: 0.22, y: yCard(2.2), z: 2.2, rx: 0.08, ry: PI * 2 - 0.5, rz: 0.03 }, ease: out },
    { at: spin, pose: { x: 0.1, y: whole(1.5), z: 1.5, rx: 0, ry: PI * 2 - 0.2, rz: 0 } },
    // Once round, onto today's page at three-quarters.
    { at: spin + 0.6, pose: { x: 0.3, y: frame(s.todayLook, 940, 2.0), z: 2.0, rx: 0.14, ry: PI * 4 - 0.62, rz: 0.03 }, ease: inOut },
    { at: end - 0.2, pose: { x: 0.22, y: frame(s.todayLook, 940, 2.1), z: 2.1, rx: 0.11, ry: PI * 4 - 0.42, rz: 0.02 }, ease: (n) => n },
    { at: end + 0.4, pose: { x: 0.5, y: MID - 0.4, z: -7, rx: 0.3, ry: PI * 4 + 1.2, rz: 0.2 }, ease: (n) => n * n },
  ];
  const pose = poseAt(keys, t);
  const before = poseAt(keys, t - 1 / REEL_FPS);
  const turning = Math.abs(pose.ry - before.ry) * REEL_FPS;
  const matrix = new THREE.Matrix4().makeTranslation(pose.x, pose.y, pose.z).multiply(new THREE.Matrix4().makeRotationFromEuler(new THREE.Euler(pose.rx, pose.ry, pose.rz, 'YXZ')));
  const project = (x: number, y: number) => {
    const v = new THREE.Vector3(...onScreen(x, y)).applyMatrix4(matrix);
    const k = FOCAL / (CAM_Z - v.z);
    return { x: 540 + v.x * k, y: 960 - v.y * k };
  };
  const onToday = t >= spin + 0.3;
  const lifts = s.todayLifts.map(([x0, y0, x1, y1, depth, beat]) => {
    const up = at(3, beat);
    return { crop: [x0, y0, x1, y1] as [number, number, number, number], lift: onToday ? depth * 1.5 * ramp(t, up, up + 0.45, out) * (1 - ramp(t, end - 0.25, end + 0.05, inOut)) : 0 };
  });
  const dim = Math.min(1, Math.max(0, ...lifts.map((x) => x.lift * 2.2)));
  const centre = project(603, 1311);
  const size = (FOCAL / (CAM_Z - pose.z)) * 0.8;
  const shadow = { x: centre.x, y: centre.y, w: Math.max(60, PHONE.w * size * Math.abs(Math.cos(pose.ry))), h: PHONE.h * size };
  const glare = [rise + 1.75, spin + 0.45].reduce((g, start) => (t >= start && t < start + 0.9 ? (t - start) / 0.9 : g), -1);
  return { t, episode, s, timing, at, end, rise, pose, turning, project, onToday, lifts, dim, glare, shadow, card };
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

/** The word card itself, cut from the screenshot, in the fingertip's hand. */
const SwipeCard = ({ map, back, badges, crop, ground, card, t }: { map: THREE.Texture; back: THREE.Texture; badges: [THREE.Texture, THREE.Texture]; crop: [number, number, number, number]; ground: string; card: ReturnType<typeof useFilm>['card']; t: number }) => {
  const [x0, y0, x1, y1] = crop;
  const w = ((x1 - x0) / SCREEN_W) * PHONE.w;
  const h = ((y1 - y0) / SCREEN_H) * PHONE.h;
  const geo = useMemo(() => {
    const front = new THREE.ShapeGeometry(roundedRect(w, h, 0.012), 6);
    const pos = front.attributes.position;
    const uv = front.attributes.uv;
    for (let i = 0; i < pos.count; i++) uv.setXY(i, (x0 + (pos.getX(i) / w + 0.5) * (x1 - x0)) / SCREEN_W, 1 - (y0 + (0.5 - pos.getY(i) / h) * (y1 - y0)) / SCREEN_H);
    const plain = new THREE.PlaneGeometry(w, h);
    return { front, plain };
  }, [w, h, x0, y0, x1, y1]);
  const [cx, cy, z] = onScreen((x0 + x1) / 2, (y0 + y1) / 2, 0.003);
  const out3 = Math.abs(card.drag) > 0.002 || card.lift > 0.002;
  if (!out3 || card.fade <= 0) return null;
  const right = card.drag > 0;
  const wash = Math.min(0.24, Math.abs(card.drag) * 0.6) * (Math.abs(card.flip) < PI / 2 ? 1 : 0);
  const badge = Math.min(1, Math.max(0, (Math.abs(card.drag) - 0.06) / 0.14)) * (Math.abs(card.flip) < PI / 2 ? 1 : 0);
  // The card turns on its foot, as it does in the app.
  const tilt = -card.drag * 0.42;
  return (
    <>
      <mesh geometry={geo.plain} position={[cx, cy, PHONE.depth / 2 + 0.0019]} renderOrder={2}>
        <meshBasicMaterial color={ground} toneMapped={false} depthWrite={false} transparent />
      </mesh>
      <mesh position={[cx + card.drag * w * 0.9 + card.lift * 0.08, cy - card.lift * 0.12, z]} scale={[w * 1.25, h * 1.2, 1]} rotation={[0, 0, tilt]} renderOrder={4}>
        <planeGeometry args={[1, 1]} />
        <meshBasicMaterial map={cardShadow} transparent opacity={Math.min(0.5, 0.22 + card.lift * 2) * card.fade * Math.max(0, 1 - card.lift * 0.9)} depthWrite={false} toneMapped={false} />
      </mesh>
      <group position={[cx + card.drag * w, cy - h / 2 + card.rise, z + card.lift]} rotation={[0, 0, tilt]}>
        <group position={[0, h / 2, 0]} rotation={[0, card.flip, 0]}>
          <mesh geometry={geo.front} renderOrder={5}>
            <meshBasicMaterial map={map} toneMapped={false} transparent opacity={card.fade} />
          </mesh>
          <mesh geometry={geo.plain} position={[0, 0, 0.0006]} renderOrder={6}>
            <meshBasicMaterial color={right ? PAL.sage : PAL.clay} transparent opacity={wash} depthWrite={false} toneMapped={false} />
          </mesh>
          <mesh position={[0, h * 0.495, 0.0012]} scale={[0.46 * badge + 0.0001, 0.144 * badge + 0.0001, 1]} rotation={[0, 0, right ? 0.1 : -0.1]} renderOrder={7}>
            <planeGeometry args={[1, 1]} />
            <meshBasicMaterial map={badges[right ? 0 : 1]} transparent opacity={badge} depthWrite={false} toneMapped={false} />
          </mesh>
          <mesh geometry={geo.plain} rotation={[0, PI, 0]} position={[0, 0, -0.0006]} renderOrder={5}>
            <meshBasicMaterial map={back} toneMapped={false} transparent opacity={card.fade} />
          </mesh>
        </group>
        {/* The fingertip. */}
        {card.touching ? (
          <mesh position={[0, h * 0.3, 0.002]} renderOrder={8}>
            <circleGeometry args={[0.05, 32]} />
            <meshBasicMaterial color="#ffffff" transparent opacity={0.42 + Math.sin(t * 6) * 0.04} depthWrite={false} toneMapped={false} />
          </mesh>
        ) : null}
      </group>
    </>
  );
};

const Stage = ({ id }: { id: string }) => {
  const gl = useThree((state) => state.gl);
  const film = useFilm(id);
  const { t, s, pose } = film;
  const maps = usePrepared(async () => {
    await Promise.all([document.fonts.load(`900 92px ${FONT}`, s.badges.join('')), document.fonts.load(`900 130px ${SERIF_TC}`, s.back)]);
    const [card, today, env, phone] = await Promise.all([imageTexture(`${s.card}.jpg`), imageTexture(`${s.today}.jpg`), loadStudio(gl), loadPhone()]);
    return {
      card,
      today,
      env,
      phone,
      back: backTexture(s.back),
      badges: [badgeTexture(s.badges[0], '✓', PAL.sage), badgeTexture(s.badges[1], '✕', PAL.clay)] as [THREE.Texture, THREE.Texture],
      cardGround: colorAt(card, 16, s.cardCrop[1] + 300),
      todayGround: s.todayLifts.map(([x0, y0]) => colorAt(today, x0 + 60, y0 - 14)),
    };
  });
  if (!maps || t < film.rise - 0.05) return null;
  const cx = (s.cardCrop[0] + s.cardCrop[2]) / 2;
  const cy = s.cardCrop[1] + (s.cardCrop[3] - s.cardCrop[1]) * 0.2;
  return (
    <>
      <StudioLight env={maps.env} turn={t * 0.12 + pose.ry * 0.25} />
      <group position={[pose.x, pose.y + Math.sin(t * 1.3) * 0.012, pose.z]} rotation={[pose.rx + Math.sin(t * 0.9) * 0.008, pose.ry, pose.rz, 'YXZ']}>
        <Phone3D model={maps.phone} screen={film.onToday ? maps.today : maps.card} glare={film.glare}>
          <ScreenLayer color="#2a2418" opacity={film.onToday ? film.dim * 0.16 : Math.min(0.14, Math.abs(film.card.drag) * 0.3)} over />
          {film.onToday ? (
            film.lifts.map((x, i) => <Lift key={i} map={maps.today} crop={x.crop} lift={x.lift} ground={maps.todayGround[i]} />)
          ) : (
            <>
              <SwipeCard map={maps.card} back={maps.back} badges={maps.badges} crop={s.cardCrop} ground={maps.cardGround} card={film.card} t={t} />
              {film.card.grabs.map((g, i) => (
                <Tap3D key={i} t={t} at={g - 0.12} x={cx} y={cy} />
              ))}
            </>
          )}
        </Phone3D>
      </group>
    </>
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
      <Backdrop t={t} frame={frameNo} drift={(film.pose.y - MID) * 260} />
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
        <AbsoluteFill style={{ opacity: 1 - leave, ...ABOVE_CAPTIONS }}>
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
      {s.props.map((pr, i) => (
        <Counter key={i} t={t} at={at(pr.slot, pr.beat)} until={end - 0.2} from={film.project(pr.from[0], pr.from[1])} left={pr.at[0]} top={pr.at[1]} tilt={pr.tilt} label={pr.label} unit={pr.unit} to={pr.to} />
      ))}

      <Peek t={t} at={at(3, 6)} until={end + 0.4} side={-1} mood="cheeky" y={1010} outAt={end - 0.15} />
      <Motes t={t} front />
      {episode.lines.map((line, i) => (
        <Caption key={i} text={line.text} start={timing.slots[i].start} length={timing.slots[i].length} t={t} first={i === 0} label={episode.label} top={CAPTION_TOP} size={62} glass />
      ))}
      <CountdownEnd t={t} end={end} episode={episode} stamp={stamp} />
      <Grade frame={frameNo} />
    </AbsoluteFill>
  );
};
