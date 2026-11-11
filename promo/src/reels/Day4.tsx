import { ThreeCanvas } from '@remotion/three';
import { useThree } from '@react-three/fiber';
import { AbsoluteFill, Html5Audio, staticFile, useCurrentFrame } from 'remotion';
import * as THREE from 'three';
import { FONT } from '../fonts';
import script from './episodes.json';
import timings from './timing.json';
import { REEL_FPS } from './Reel';
import { Caption } from './Intro';
import { ABOVE_CAPTIONS, CAPTION_TOP, Peek } from './Teaser';
import { CountdownEnd, DaysStamp, StampCard } from './Countdown';
import { Burst, DeepBackdrop, Foreground, Grade, InkFilters, Motes } from './finish';
import { Mascot, type Mood } from '../Mascot';
import waves from './waves.json';
import { Lift, PAL, PHONE, SCREEN_H, SCREEN_W, canvasTexture, colorAt, Phone3D, ScreenLayer, StudioLight, Tap3D, imageTexture, inOut, loadPhone, loadStudio, onScreen, out, ramp, usePrepared } from './three/kit';

/**
 * 11/12, four days to go: speaking, with real voices.
 *
 * Cover, then the phone rises back-first and turns to face you on the
 * map of everyday scenes; the stages lift off the glass one after
 * another. It spins once and comes back on a conversation. The server's
 * line lifts, and the app's own recording plays: the wave over the
 * bubble is that recording's loudness, moment by moment. Then the reply
 * lifts and is said, the screen changes to the result, and the score
 * comes up off the glass.
 *
 * Screenshots, crops and recordings are the episode's `scene` and `clips`.
 */

const BEAT = 0.5;
const PI = Math.PI;
const CAM_Z = 9;
const FOV = 30;
const FOCAL = 960 / Math.tan(((FOV / 2) * PI) / 180);
const MID = ((960 - 825) / FOCAL) * CAM_Z;

type Slot = { start: number; length: number };
type Crop = [number, number, number, number];
type Scene = { map: string; mapLook: number; mapLifts: [number, number, number, number, number, number][]; talk: [string, string]; talkLook: number; doneLook: number; server: Crop; reply: Crop; replyDone: Crop; score: Crop; desk: [string, number, number, number, number][]; voiceTag: string };
type Episode = { id: string; days: number; app: string; label: string; dayWords: [string, string]; note: string; outro: string; lines: { text: string; clips?: [number, string, number][] }[]; scene: Scene };
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
  const [, scenes, listen, speak] = starts;
  const end = timing.end;
  const at = (slot: number, beat: number) => starts[slot] + beat * BEAT;

  const rise = 2 * BEAT;
  // The app's recordings: when each starts, how long it is, and its loudness over time.
  const clip = (slot: number) => {
    const [beat, file] = episode.lines[slot].clips![0];
    const env = (waves as Record<string, number[]>)[file];
    return { start: at(slot, beat), length: env.length / 60, env };
  };
  const heard = clip(2);
  const said = clip(3);
  const scored = said.start + said.length + 0.15;
  const spin = listen - 0.3;
  const onTalk = t >= spin + 0.3;

  const whole = (z: number, row = 825) => frame(1311, row, z);
  const yMap = (z: number, row = 900) => frame(s.mapLook, row, z);
  const yTalk = (z: number, row = 800) => frame(s.talkLook, row, z);
  const yDone = (z: number, row = 780) => frame(s.doneLook, row, z);
  const keys: Key[] = [
    { at: rise, pose: { x: 0.25, y: -5.4, z: 0, rx: 0.55, ry: PI + 0.9, rz: 0.28 } },
    { at: rise + 0.8, pose: { x: 0.08, y: whole(2.2) + 0.05, z: 2.2, rx: 0.12, ry: PI + 0.42, rz: 0.07 }, ease: out },
    { at: rise + 1.25, pose: { x: 0.04, y: whole(2.1), z: 2.1, rx: 0.08, ry: PI + 0.2, rz: 0.04 }, ease: (n) => n },
    { at: rise + 2.0, pose: { x: 0, y: whole(1.5), z: 1.5, rx: -0.04, ry: PI * 2 - 0.2, rz: 0.012 }, ease: inOut },
    { at: scenes - 0.05, pose: { x: 0, y: whole(1.6), z: 1.6, rx: -0.03, ry: PI * 2 - 0.1, rz: 0.008 }, ease: (n) => n },
    // Three-quarters on the map, so its stages show their depth as they lift.
    { at: scenes + 1.2 * BEAT, pose: { x: 0.28, y: yMap(2.0), z: 2.0, rx: 0.14, ry: PI * 2 - 0.6, rz: 0.03 }, ease: out },
    { at: spin, pose: { x: 0.2, y: yMap(2.15), z: 2.15, rx: 0.1, ry: PI * 2 - 0.4, rz: 0.02 }, ease: (n) => n },
    // Once round, and in on the conversation.
    { at: spin + 0.6, pose: { x: 0, y: whole(1.5), z: 1.5, rx: -0.02, ry: PI * 4 - 0.1, rz: 0 }, ease: inOut },
    { at: listen + 2.6 * BEAT, pose: { x: 0, y: yTalk(2.7), z: 2.7, rx: 0.02, ry: PI * 4, rz: 0 }, ease: inOut },
    { at: heard.start - 0.15, pose: { x: 0, y: yTalk(2.75), z: 2.75, rx: 0.02, ry: PI * 4, rz: 0 }, ease: (n) => n },
    // It turns its ear to you while the server speaks.
    { at: heard.start + 0.5, pose: { x: 0.14, y: yTalk(2.5), z: 2.5, rx: 0.1, ry: PI * 4 - 0.42, rz: 0.02 }, ease: out },
    { at: heard.start + heard.length + 0.3, pose: { x: 0.1, y: yTalk(2.55), z: 2.55, rx: 0.08, ry: PI * 4 - 0.3, rz: 0.015 }, ease: (n) => n },
    { at: speak + 2 * BEAT, pose: { x: 0, y: yTalk(2.6, 760), z: 2.6, rx: 0.03, ry: PI * 4, rz: 0 } },
    { at: said.start - 0.15, pose: { x: 0, y: yTalk(2.65, 760), z: 2.65, rx: 0.03, ry: PI * 4, rz: 0 }, ease: (n) => n },
    // And the other way while you answer.
    { at: said.start + 0.5, pose: { x: -0.14, y: yTalk(2.45, 760), z: 2.45, rx: 0.1, ry: PI * 4 + 0.42, rz: -0.02 }, ease: out },
    { at: scored, pose: { x: -0.12, y: yTalk(2.5, 760), z: 2.5, rx: 0.09, ry: PI * 4 + 0.34, rz: -0.015 }, ease: (n) => n },
    // Round once more: it comes back with the verdict.
    { at: scored + 0.55, pose: { x: 0.1, y: yDone(2.6), z: 2.6, rx: 0.1, ry: PI * 6 - 0.34, rz: 0.015 }, ease: inOut },
    { at: end - 0.2, pose: { x: 0.06, y: yDone(2.7), z: 2.7, rx: 0.08, ry: PI * 6 - 0.2, rz: 0.01 }, ease: (n) => n },
    { at: end + 0.4, pose: { x: 0.5, y: MID - 0.4, z: -7, rx: 0.3, ry: PI * 6 + 1.2, rz: 0.2 }, ease: (n) => n * n },
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
  const mapLifts = s.mapLifts.map(([x0, y0, x1, y1, depth, beat]) => ({ crop: [x0, y0, x1, y1] as Crop, lift: onTalk ? 0 : depth * 1.4 * ramp(t, at(1, beat), at(1, beat) + 0.45, out) * (1 - ramp(t, spin - 0.3, spin, inOut)) }));
  // A bubble stands off the glass while its recording plays.
  const up = (c: { start: number; length: number }, hold = 0.25) => ramp(t, c.start - 0.25, c.start + 0.2, out) * (1 - ramp(t, c.start + c.length + hold, c.start + c.length + hold + 0.35, inOut));
  const talk = {
    server: 0.42 * up(heard),
    reply: 0.42 * up(said, -0.1),
    done: 0.34 * ramp(t, scored + 0.5, scored + 0.9, out) * (1 - ramp(t, end - 0.25, end + 0.05, inOut)),
    score: 0.52 * ramp(t, scored + 0.65, scored + 1.05, out) * (1 - ramp(t, end - 0.25, end + 0.05, inOut)),
    result: t >= scored + 0.28 ? 1 : 0,
  };
  const dim = onTalk ? Math.min(1, Math.max(talk.server, talk.reply, talk.score, talk.done) * 2.4) : Math.min(1, Math.max(0, ...mapLifts.map((x) => x.lift * 2)));
  const centre = project(603, 1311);
  const size = (FOCAL / (CAM_Z - pose.z)) * 0.8;
  const shadow = { x: centre.x, y: centre.y, w: Math.max(60, PHONE.w * size * Math.abs(Math.cos(pose.ry))), h: PHONE.h * size };
  const glare = [rise + 1.75, spin + 0.5, scored + 0.5].reduce((g, start) => (t >= start && t < start + 0.9 ? (t - start) / 0.9 : g), -1);
  // The room goes quiet for the recordings.
  const hush = Math.max(up(heard), up(said, -0.1));
  const landed = scored + 0.95;
  const knock = t >= landed && t < landed + 0.35 ? Math.exp(-(t - landed) * 14) * Math.cos((t - landed) * 60) * 9 : 0;
  return { t, episode, s, timing, at, end, rise, pose, turning, project, glare, shadow, onTalk, mapLifts, talk, dim, heard, said, scored, hush, landed, knock, spin };
};

const BARS = 40;
const capsule = canvasTexture(32, 160, (ctx, w, h) => {
  ctx.fillStyle = '#fff';
  ctx.beginPath();
  ctx.roundRect(4, 2, w - 8, h - 4, (w - 8) / 2);
  ctx.fill();
});
/**
 * A recording as a wave over its bubble. Each bar is how loud it was a
 * moment ago, above and below a centre line, so the sound travels along
 * the row; the newest bars are the brightest.
 */
const Wave = ({ crop, lift, clip, t, color, below = false }: { crop: Crop; lift: number; clip: { start: number; length: number; env: number[] }; t: number; color: string; below?: boolean }) => {
  const age = t - clip.start;
  if (age < -0.25 || age > clip.length + 0.8 || lift <= 0.001) return null;
  const [x0, y0, x1, y1] = crop;
  const w = ((x1 - x0) / SCREEN_W) * PHONE.w;
  // Over the bubble, or under it when something is already written above.
  const [cx, edge, z] = onScreen((x0 + x1) / 2, below ? y1 : y0, 0.003);
  const top = below ? edge - 0.21 : edge;
  const span = w * 0.94;
  const step = span / BARS;
  const show = ramp(t, clip.start - 0.25, clip.start, out) * (1 - ramp(t, clip.start + clip.length + 0.4, clip.start + clip.length + 0.8, inOut));
  return (
    <group position={[cx - span / 2, top + 0.105, z + lift]}>
      {Array.from({ length: BARS }, (_, i) => {
        const at = age - i * 0.014;
        const amp = at < 0 ? 0 : (clip.env[Math.floor(at * 60)] ?? 0);
        const h = 0.014 + amp * 0.17;
        const fresh = Math.max(0, 1 - i / 14);
        return (
          <mesh key={i} position={[(i + 0.5) * step, 0, 0]} scale={[step * 0.6, h, 1]} renderOrder={6}>
            <planeGeometry args={[1, 1]} />
            <meshBasicMaterial map={capsule} color={color} transparent opacity={show * (0.3 + 0.45 * Math.min(1, amp * 2.4) + 0.25 * fresh * Math.min(1, amp * 3))} depthWrite={false} toneMapped={false} />
          </mesh>
        );
      })}
    </group>
  );
};

const Stage = ({ id }: { id: string }) => {
  const gl = useThree((state) => state.gl);
  const film = useFilm(id);
  const { t, s, pose } = film;
  const maps = usePrepared(async () => {
    const [map, shadowing, result, env, phone] = await Promise.all([imageTexture(`${s.map}.jpg`), imageTexture(`${s.talk[0]}.jpg`), imageTexture(`${s.talk[1]}.jpg`), loadStudio(gl), loadPhone()]);
    const ground = (tex: THREE.Texture, crops: number[][]) => crops.map(([x0, y0]) => colorAt(tex, Math.max(4, x0 - 20), y0 + 40));
    return { map, shadowing, result, env, phone, mapGround: ground(map, s.mapLifts), talkGround: ground(shadowing, [s.server, s.reply]), doneGround: ground(result, [s.replyDone, s.score]) };
  });
  if (!maps || t < film.rise - 0.05) return null;
  const done = film.talk.result > 0.5;
  return (
    <>
      <StudioLight env={maps.env} turn={t * 0.12 + pose.ry * 0.25} />
      <group position={[pose.x, pose.y + Math.sin(t * 1.3) * 0.012, pose.z]} rotation={[pose.rx + Math.sin(t * 0.9) * 0.008, pose.ry, pose.rz, 'YXZ']}>
        <Phone3D model={maps.phone} screen={!film.onTalk ? maps.map : done ? maps.result : maps.shadowing} glare={film.glare}>
          <ScreenLayer color="#2a2418" opacity={film.dim * (film.onTalk ? 0.3 : 0.16)} over />
          {film.onTalk && !done ? (
            <>
              <Lift map={maps.shadowing} crop={s.server} lift={film.talk.server} ground={maps.talkGround[0]} />
              <Lift map={maps.shadowing} crop={s.reply} lift={film.talk.reply} ground={maps.talkGround[1]} />
              <Wave crop={s.server} lift={film.talk.server * 1.06} clip={film.heard} t={t} color={PAL.clay} />
              <Wave crop={s.reply} lift={film.talk.reply * 1.06} clip={film.said} t={t} color={PAL.sage} below />
              <Tap3D t={t} at={film.heard.start - 0.2} x={s.server[2] - 50} y={(s.server[1] + s.server[3]) / 2 - 20} />
              <Tap3D t={t} at={film.said.start - 0.3} x={603} y={2290} />
            </>
          ) : film.onTalk ? (
            <>
              <Lift map={maps.result} crop={s.replyDone} lift={film.talk.done} ground={maps.doneGround[0]} />
              <Lift map={maps.result} crop={s.score} lift={film.talk.score} ground={maps.doneGround[1]} radius={30} />
            </>
          ) : (
            film.mapLifts.map((x, i) => <Lift key={i} map={maps.map} crop={x.crop} lift={x.lift} ground={maps.mapGround[i]} radius={20} />)
          )}
        </Phone3D>
      </group>
    </>
  );
};

/**
 * 傻貓 in the corner for the whole of it: one cat who stays. He nods to
 * the recordings as they play, and is pleased with the score.
 */
const Buddy = ({ film }: { film: ReturnType<typeof useFilm> }) => {
  const { t, end, heard, said, landed } = film;
  const arrive = film.at(1, 0.6);
  if (t < arrive) return null;
  const inP = ramp(t, arrive, arrive + 0.5, out) * (1 - ramp(t, end - 0.25, end + 0.1, inOut));
  const loud = (c: { start: number; length: number; env: number[] }) => (t >= c.start && t < c.start + c.length ? (c.env[Math.floor((t - c.start) * 60)] ?? 0) : 0);
  const listening = loud(heard) + loud(said);
  const age = t - landed;
  const mood: Mood = age >= 0 ? 'happy' : t >= heard.start - 0.3 ? 'idle' : 'smug';
  const hop = age >= 0 && age < 0.7 ? Math.exp(-age * 6) * Math.sin(age * 16) : 0;
  return (
    <div style={{ position: 'absolute', left: -96 - (1 - inP) * 360, top: 1068 - hop * 34 + listening * 12, transform: `rotate(${13 + hop * 3 - listening * 4}deg)`, transformOrigin: '30% 100%', filter: 'drop-shadow(0 18px 20px rgba(30,34,14,0.34))' }}>
      <Mascot mood={mood} size={400} next />
    </div>
  );
};

export const Day4 = ({ id }: { id: string }) => {
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
      <DeepBackdrop t={t} frame={frameNo} drift={(film.pose.y - MID) * 260 + film.pose.x * 500} focus={lit} cards={s.desk.map(([src, x, y, w, h]) => (src ? { src: `${src}.jpg`, crop: [x, y, w, h] as [number, number, number, number] } : {}))} />
      <AbsoluteFill style={{ background: `radial-gradient(70% 46% at 50% 42%, rgba(255,244,214,${0.2 * lit}) 0%, rgba(255,244,214,0) 70%), radial-gradient(120% 90% at 50% 42%, rgba(0,0,0,0) 45%, rgba(26,30,12,${0.42 * lit}) 100%)` }} />
      <AbsoluteFill style={{ background: `radial-gradient(60% 40% at 50% 42%, rgba(20,24,10,0) 30%, rgba(20,24,10,${0.5 * film.hush}) 100%)` }} />
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
      {/* What you are hearing: a paper label, lit while the recording plays. */}
      {(() => {
        const on = ramp(t, film.heard.start - 0.35, film.heard.start - 0.05, out) * (1 - ramp(t, film.heard.start + film.heard.length + 0.35, film.heard.start + film.heard.length + 0.7, inOut));
        if (on <= 0) return null;
        const live = t > film.heard.start && t < film.heard.start + film.heard.length;
        return (
          <div style={{ position: 'absolute', left: 60, top: 252, opacity: on, transform: `translateY(${(1 - on) * -90}px) rotate(-3deg)` }}>
            <div style={{ position: 'absolute', left: 96, top: -16, width: 84, height: 30, background: 'rgba(238,226,190,0.78)', transform: 'rotate(-3deg)', boxShadow: '0 1px 2px rgba(0,0,0,0.12)' }} />
            <div style={{ display: 'flex', alignItems: 'center', gap: 16, padding: '12px 26px 12px 20px', borderRadius: 6, backgroundColor: '#FBF6EA', backgroundImage: `url(${staticFile('paper-grain.png')})`, backgroundBlendMode: 'multiply', backgroundSize: '300px', boxShadow: '0 10px 22px rgba(30,30,10,0.32)', border: '1px solid rgba(90,80,50,0.16)' }}>
              <span style={{ width: 22, height: 22, borderRadius: 11, background: '#C96442', opacity: live ? 0.55 + 0.45 * Math.sin(t * 9) ** 2 : 0.4, boxShadow: live ? '0 0 14px rgba(201,100,66,0.7)' : 'none' }} />
              <span style={{ fontWeight: 900, fontSize: 44, color: '#2B2620', letterSpacing: '0.06em', whiteSpace: 'nowrap' }}>{s.voiceTag}</span>
            </div>
          </div>
        );
      })()}
      {/* Gold off the score as it lands. */}
      {(() => {
        const at2 = film.project((s.score[0] + s.score[2]) / 2, (s.score[1] + s.score[3]) / 2);
        return <Burst t={t} at={film.landed} x={at2.x} y={at2.y - 20} scale={1.1} count={18} />;
      })()}
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
