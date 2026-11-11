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
import { Lift, PHONE, colorAt, Phone3D, ScreenLayer, StudioLight, Tap3D, imageTexture, inOut, loadPhone, loadStudio, onScreen, out, ramp, usePrepared } from './three/kit';

/**
 * 11/14, two days to go: 傻貓 the AI teacher (Premium).
 *
 * Cover, then a paper speech bubble slaps down: what you said, mistake
 * and all. The phone comes up beside it; a red squiggle goes under the
 * mistake, and the bubble is drawn into the phone. In on the coach's
 * card: the line with that very mistake lifts off the glass and is
 * ringed in red, then the better sentence and the reason why lift too.
 * Down to the follow-up question, and a tap to answer it. Round once,
 * onto the chat: your message arrives, the cat types, its answer lands,
 * and what it has remembered is pinned under it.
 *
 * The bubble is a prop; its words are the phrase the coach's own card
 * strikes out. Everything on the phone is the app's screenshots.
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
  coach: string;
  chat: string;
  said: [string, string];
  fix: Crop;
  ring: Crop; // centre x, centre y, half-width, half-height, on the screenshot
  sentence: Crop;
  tip: Crop;
  follow: Crop;
  answer: [number, number];
  user: Crop;
  reply: Crop;
  note: Crop;
  premium: string;
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
const frame = (y: number, row: number, z: number) => ((960 - row) / FOCAL) * (CAM_Z - z) - (0.5 - y / 2622) * PHONE.h;

/** The speech bubble on the desk. */
const SAID = { left: 40, top: 400, width: 560, height: 470, tilt: -5 };

const useFilm = (id: string) => {
  const t = useCurrentFrame() / REEL_FPS;
  const episode = script.episodes.find((e) => e.id === id)! as unknown as Episode;
  const s = episode.scene;
  const timing = (timings as Record<string, { total: number; end: number; slots: Slot[] }>)[id];
  const starts = timing.slots.map((slot) => slot.start);
  const [, fixing, asking, remembering] = starts;
  const end = timing.end;
  const at = (slot: number, beat: number) => starts[slot] + beat * BEAT;

  const saidIn = 2.2 * BEAT;
  const rise = fixing - 1.0;
  const squiggle = fixing - 0.35;
  const drawnIn = at(1, 1.6); // the bubble goes into the phone
  const ringAt = at(1, 3.6);
  const sentenceAt = at(1, 5);
  const tipAt = at(1, 6.5);
  const followAt = at(2, 1);
  const answerAt = at(2, 4);
  const spin = remembering - 0.3;
  const onChat = t >= spin + 0.3;
  const userAt = at(3, 1.5);
  const typing = [at(3, 2.2), at(3, 3.6)] as const;
  const replyAt = at(3, 3.6);
  const noteAt = at(3, 6);

  const beside = (z: number, row = 800) => frame(1311, row, z);
  const look = (y: number, z: number, row = 800) => frame(y, row, z);
  const fixY = (s.fix[1] + s.fix[3]) / 2;
  const cardY = (s.sentence[1] + s.tip[3]) / 2;
  const followY = (s.follow[1] + s.follow[3]) / 2;
  const chatY = (s.user[1] + s.note[3]) / 2;
  const keys: Key[] = [
    { at: rise, pose: { x: 1.1, y: -5.2, z: 0, rx: 0.5, ry: PI + 0.9, rz: 0.25 } },
    { at: rise + 0.8, pose: { x: 0.6, y: beside(1.4) + 0.05, z: 1.4, rx: 0.12, ry: PI + 0.5, rz: 0.06 }, ease: out },
    { at: rise + 1.6, pose: { x: 0.5, y: beside(1.3), z: 1.3, rx: 0.04, ry: PI * 2 - 0.4, rz: 0.012 }, ease: inOut },
    { at: drawnIn - 0.1, pose: { x: 0.5, y: beside(1.3), z: 1.3, rx: 0.04, ry: PI * 2 - 0.42, rz: 0.012 }, ease: (n) => n },
    // To the middle and in on the line with the mistake.
    { at: drawnIn + 0.7, pose: { x: 0, y: look(fixY, 4.2, 760), z: 4.2, rx: 0.03, ry: PI * 2, rz: 0 }, ease: inOut },
    { at: sentenceAt - 0.2, pose: { x: 0, y: look(fixY, 4.3, 760), z: 4.3, rx: 0.03, ry: PI * 2 + 0.05, rz: 0 }, ease: (n) => n },
    // Back to three-quarters: the whole card, in layers.
    { at: sentenceAt + 0.5, pose: { x: 0.22, y: look(cardY, 3.3, 800), z: 3.3, rx: 0.13, ry: PI * 2 - 0.58, rz: 0.03 }, ease: out },
    { at: asking - 0.1, pose: { x: 0.16, y: look(cardY, 3.4, 800), z: 3.4, rx: 0.1, ry: PI * 2 - 0.4, rz: 0.02 }, ease: (n) => n },
    // Down to the follow-up.
    { at: asking + 0.6, pose: { x: 0, y: look(followY, 3.9, 780), z: 3.9, rx: 0.08, ry: PI * 2 + 0.16, rz: 0 }, ease: inOut },
    { at: spin, pose: { x: 0, y: look(followY, 4.0, 780), z: 4.0, rx: 0.08, ry: PI * 2 + 0.24, rz: 0 }, ease: (n) => n },
    // Once round, onto the chat.
    { at: spin + 0.6, pose: { x: 0, y: look(chatY, 3.8, 800), z: 3.8, rx: 0.05, ry: PI * 4 - 0.12, rz: 0 }, ease: inOut },
    { at: replyAt, pose: { x: 0, y: look(chatY, 3.85, 800), z: 3.85, rx: 0.05, ry: PI * 4 - 0.02, rz: 0 }, ease: (n) => n },
    { at: replyAt + 0.6, pose: { x: 0.14, y: look(chatY, 3.5, 820), z: 3.5, rx: 0.11, ry: PI * 4 - 0.4, rz: 0.02 }, ease: out },
    { at: end - 0.2, pose: { x: 0.1, y: look(chatY, 3.6, 820), z: 3.6, rx: 0.09, ry: PI * 4 - 0.26, rz: 0.015 }, ease: (n) => n },
    { at: end + 0.4, pose: { x: 0.5, y: MID - 0.4, z: -7, rx: 0.3, ry: PI * 4 + 1.2, rz: 0.2 }, ease: (n) => n * n },
  ];
  const pose = poseAt(keys, t);
  const before = poseAt(keys, t - 1 / REEL_FPS);
  const turning = Math.abs(pose.ry - before.ry) * REEL_FPS;
  const matrixOf = (q: Pose) => new THREE.Matrix4().makeTranslation(q.x, q.y, q.z).multiply(new THREE.Matrix4().makeRotationFromEuler(new THREE.Euler(q.rx, q.ry, q.rz, 'YXZ')));
  const projectWith = (q: Pose, x: number, y: number) => {
    const v = new THREE.Vector3(...onScreen(x, y)).applyMatrix4(matrixOf(q));
    const k = FOCAL / (CAM_Z - v.z);
    return { x: 540 + v.x * k, y: 960 - v.y * k };
  };
  const project = (x: number, y: number) => projectWith(pose, x, y);
  // Something comes up off the glass at `when` and stays up until `until`.
  const up = (when: number, until: number, depth: number, hop = 0.3) => (t < when ? 0 : (depth + hop * Math.exp(-(t - when) * 7) * Math.abs(Math.cos((t - when) * 9))) * ramp(t, when, when + 0.12, out) * (1 - ramp(t, until - 0.3, until, inOut)));
  const leaveCard = asking - 0.15;
  const lifts = {
    fix: up(drawnIn + 0.75, leaveCard, 0.2, 0.2),
    sentence: up(sentenceAt, leaveCard, 0.42),
    tip: up(tipAt, leaveCard, 0.3),
    follow: up(followAt, spin - 0.1, 0.3),
    user: up(userAt, end - 0.05, 0.16),
    reply: up(replyAt, end - 0.05, 0.3),
    note: up(noteAt, end - 0.05, 0.44),
  };
  const dim = Math.min(1, Math.max(lifts.sentence, lifts.tip, lifts.follow, lifts.reply, lifts.note) * 2.2);
  // The bubble's journey into the phone: where it is going, and how far along.
  const goal = projectWith(poseAt(keys, drawnIn + 0.45), (s.fix[0] + s.fix[2]) / 2 - 150, fixY);
  const into = ramp(t, drawnIn, drawnIn + 0.5, inOut);
  const knocks = [ringAt + 0.3, answerAt + 0.1, noteAt];
  const knock = knocks.reduce((k, when) => { const age = t - when; return age >= 0 && age < 0.3 ? k + Math.exp(-age * 15) * Math.cos(age * 62) * (when === noteAt ? 10 : 5) : k; }, 0);
  const centre = project(603, 1311);
  const size = (FOCAL / (CAM_Z - pose.z)) * 0.8;
  const shadow = { x: centre.x, y: centre.y, w: Math.max(60, PHONE.w * size * Math.abs(Math.cos(pose.ry))), h: PHONE.h * size };
  const glare = [rise + 1.5, drawnIn + 0.7, spin + 0.5].reduce((g, start) => (t >= start && t < start + 0.9 ? (t - start) / 0.9 : g), -1);
  return { t, episode, s, timing, at, end, rise, saidIn, squiggle, drawnIn, ringAt, sentenceAt, tipAt, followAt, answerAt, spin, onChat, userAt, typing, replyAt, noteAt, pose, turning, project, lifts, dim, goal, into, knock, shadow, glare };
};

const Stage = ({ id }: { id: string }) => {
  const gl = useThree((state) => state.gl);
  const film = useFilm(id);
  const { t, s, pose } = film;
  const maps = usePrepared(async () => {
    const [coach, chat, env, phone] = await Promise.all([imageTexture(`${s.coach}.jpg`), imageTexture(`${s.chat}.jpg`), loadStudio(gl), loadPhone()]);
    const beside2 = (tex: THREE.Texture, c: Crop) => colorAt(tex, Math.max(4, c[0] - 16), c[1] + 30);
    return { coach, chat, env, phone, ground: { fix: colorAt(coach, s.fix[0] + 4, s.fix[1] + 4), sentence: beside2(coach, s.sentence), tip: colorAt(coach, s.tip[0] - 30, s.tip[1] + 40), follow: beside2(coach, s.follow), sheet: colorAt(chat, 30, s.user[1] + 40) } };
  });
  if (!maps || t < film.rise - 0.05) return null;
  const patch = (crop: Crop, key: string) => (
    <mesh key={key} position={[...onScreen((crop[0] + crop[2]) / 2, (crop[1] + crop[3]) / 2, 0.0019)] as [number, number, number]} renderOrder={2}>
      <planeGeometry args={[((crop[2] - crop[0] + 6) / 1206) * PHONE.w, ((crop[3] - crop[1] + 6) / 2622) * PHONE.h]} />
      <meshBasicMaterial color={maps.ground.sheet} toneMapped={false} depthWrite={false} transparent />
    </mesh>
  );
  // The red ring round the mistake: drawn, not placed.
  const ringed = ramp(t, film.ringAt, film.ringAt + 0.42, inOut);
  const [rx, ry, rw, rh] = s.ring;
  const ringPos = onScreen(rx, ry, 0.004);
  const dots = t >= film.typing[0] && t < film.typing[1];
  return (
    <>
      <StudioLight env={maps.env} turn={t * 0.12 + pose.ry * 0.25} />
      <group position={[pose.x, pose.y + Math.sin(t * 1.3) * 0.012, pose.z]} rotation={[pose.rx + Math.sin(t * 0.9) * 0.008, pose.ry, pose.rz, 'YXZ']}>
        <Phone3D model={maps.phone} screen={film.onChat ? maps.chat : maps.coach} glare={film.glare}>
          <ScreenLayer color="#2a2418" opacity={film.dim * 0.18} over />
          {film.onChat ? (
            <>
              {/* The chat as it happens: nothing is there until it is said. */}
              {t < film.userAt ? patch(s.user, 'user') : null}
              {t < film.replyAt ? patch(s.reply, 'reply') : null}
              {t < film.noteAt ? patch(s.note, 'note') : null}
              <Lift map={maps.chat} crop={s.user} lift={film.lifts.user} ground={maps.ground.sheet} radius={40} />
              <Lift map={maps.chat} crop={s.reply} lift={film.lifts.reply} ground={maps.ground.sheet} radius={40} />
              <Lift map={maps.chat} crop={s.note} lift={film.lifts.note} ground={maps.ground.sheet} radius={16} />
              {/* The cat is typing. */}
              {dots
                ? [0, 1, 2].map((i) => (
                    <mesh key={i} position={[...onScreen(s.reply[0] + 80 + i * 44, s.reply[1] + 60 - Math.max(0, Math.sin((t - film.typing[0]) * 9 - i * 0.9)) * 22, 0.004)] as [number, number, number]} renderOrder={5}>
                      <circleGeometry args={[0.014, 20]} />
                      <meshBasicMaterial color="#9A8F80" transparent opacity={0.9} depthWrite={false} toneMapped={false} />
                    </mesh>
                  ))
                : null}
            </>
          ) : (
            <>
              <Lift map={maps.coach} crop={s.sentence} lift={film.lifts.sentence} ground={maps.ground.sentence} radius={10} />
              <Lift map={maps.coach} crop={s.fix} lift={film.lifts.fix} ground={maps.ground.fix} radius={14} />
              <Lift map={maps.coach} crop={s.tip} lift={film.lifts.tip} ground={maps.ground.tip} radius={6} />
              <Lift map={maps.coach} crop={s.follow} lift={film.lifts.follow} ground={maps.ground.follow} radius={8} />
              {ringed > 0 && t < film.followAt ? (
                <group position={[ringPos[0], ringPos[1], ringPos[2] + film.lifts.fix * 1.02]} rotation={[0, 0, -0.05]} scale={[(rw / 1206) * PHONE.w, (rh / 2622) * PHONE.h, 1]}>
                  <mesh rotation={[0, 0, 2.4]} renderOrder={7}>
                    <ringGeometry args={[0.93, 1, 72, 1, 0, -PI * 2.12 * ringed]} />
                    <meshBasicMaterial color="#C4452C" transparent opacity={0.92} depthWrite={false} toneMapped={false} side={THREE.DoubleSide} />
                  </mesh>
                </group>
              ) : null}
              <Tap3D t={t} at={film.answerAt} x={s.answer[0]} y={s.answer[1]} />
            </>
          )}
        </Phone3D>
      </group>
    </>
  );
};

/**
 * What you said, on a paper speech bubble: a label, the sentence in your
 * own hand, and under the mistake a red squiggle. It is drawn into the
 * phone, shrinking onto the line that corrects it.
 */
const Said = ({ film }: { film: ReturnType<typeof useFilm> }) => {
  const { t, s, saidIn, squiggle, into, goal } = film;
  if (t < saidIn || into >= 1) return null;
  const drop = ramp(t, saidIn, saidIn + 0.22, (n) => n * n);
  const settle = t > saidIn + 0.22 ? Math.exp(-(t - saidIn - 0.22) * 9) * Math.sin((t - saidIn - 0.22) * 22) * 0.012 : 0;
  const drawn = ramp(t, squiggle, squiggle + 0.5, inOut);
  const cjk = /[㐀-鿿]/.test(s.said[1]);
  const cx = SAID.left + SAID.width / 2;
  const cy = SAID.top + SAID.height / 2;
  const x = cx + (goal.x - cx) * into;
  const y = cy + (goal.y - cy) * into - Math.sin(PI * into) * 120;
  return (
    <div
      style={{
        position: 'absolute',
        left: x - SAID.width / 2,
        top: y - SAID.height / 2 + (1 - drop) * -1400,
        width: SAID.width,
        height: SAID.height,
        transform: `rotate(${SAID.tilt * (1 - into) - (1 - drop) * 14}deg) scale(${(1 + (1 - drop) * 0.5 + settle) * (1 - into * 0.72)})`,
        opacity: 1 - ramp(into, 0.75, 1, (n) => n),
        filter: `drop-shadow(0 ${24 + (1 - drop) * 50 + Math.sin(PI * into) * 30}px ${28 + (1 - drop) * 40}px rgba(26,30,10,0.4))`,
      }}
    >
      {/* The bubble's tail. */}
      <div style={{ position: 'absolute', left: 70, bottom: -46, width: 0, height: 0, borderLeft: '10px solid transparent', borderRight: '74px solid transparent', borderTop: '60px solid #FBF7EC' }} />
      <div style={{ position: 'absolute', inset: 0, borderRadius: 54, backgroundColor: '#FBF7EC', backgroundImage: `url(${staticFile('paper-grain.png')})`, backgroundBlendMode: 'multiply', backgroundSize: '320px', border: '2px solid rgba(90,80,50,0.14)' }} />
      <div style={{ position: 'absolute', left: 44, top: 40, display: 'flex', alignItems: 'center', gap: 14 }}>
        <span style={{ width: 54, height: 54, borderRadius: 27, background: '#C96442', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
          <span style={{ width: 18, height: 28, borderRadius: 9, background: '#FBF6EA' }} />
        </span>
        <span style={{ fontWeight: 900, fontSize: 40, color: '#7A6F62', letterSpacing: '0.08em' }}>{s.said[0]}</span>
      </div>
      <div style={{ position: 'absolute', left: 44, right: 30, top: 140, color: '#2B3A55', lineHeight: 1.12, ...(cjk ? { fontFamily: HAND_TC, fontSize: 84, letterSpacing: '0.03em' } : { fontFamily: HAND, fontWeight: 600, fontSize: 112 }) }}>
        {s.said[1]}
        {/* The teacher's red pen under it. */}
        <svg width={420} height={40} viewBox="0 0 420 40" style={{ display: 'block', marginTop: 4, overflow: 'visible' }}>
          <path d="M4 22 q 18 -22 36 0 t 36 0 t 36 0 t 36 0 t 36 0 t 36 0 t 36 0 t 36 0 t 36 0 t 36 0 t 36 0" fill="none" stroke="#C4452C" strokeWidth={7} strokeLinecap="round" strokeDasharray={640} strokeDashoffset={640 * (1 - drawn)} />
        </svg>
      </div>
    </div>
  );
};

/**
 * 傻貓 in the corner for the whole of it: the teacher, pleased with every
 * mark it makes and smug about what it remembers.
 */
const Buddy = ({ film }: { film: ReturnType<typeof useFilm> }) => {
  const { t, end } = film;
  const arrive = film.at(1, 0.6);
  if (t < arrive) return null;
  const inP = ramp(t, arrive, arrive + 0.5, out) * (1 - ramp(t, end - 0.25, end + 0.1, inOut));
  const events: { at: number; mood: Mood; stay: boolean }[] = [
    { at: film.ringAt + 0.3, mood: 'cheeky', stay: false },
    { at: film.sentenceAt, mood: 'happy', stay: false },
    { at: film.answerAt + 0.1, mood: 'happy', stay: false },
    { at: film.replyAt, mood: 'cheeky', stay: false },
    { at: film.noteAt, mood: 'cheeky', stay: true },
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

export const Day2 = ({ id }: { id: string }) => {
  const frameNo = useCurrentFrame();
  const film = useFilm(id);
  const { t, episode, s, timing, at, end, rise } = film;

  const stamp = <DaysStamp days={episode.days} words={episode.dayWords} note={episode.note} />;
  // The cover tips back and away as the phone comes up through where it was.
  const tip = ramp(t, film.saidIn - 0.12, film.saidIn + 0.38, inOut);
  const leave = ramp(t, end - 0.15, end + 0.35, inOut);
  const smear = Math.min(26, Math.max(0, film.turning - 2.5) * 2.4);
  const lit = ramp(t, film.saidIn, film.saidIn + 0.8, (n) => n) * (1 - leave);

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
      <Motes t={t} />

      {/* The cover. */}
      {tip < 1 ? (
        <div style={{ position: 'absolute', inset: 0, opacity: 1 - tip * tip, transform: `perspective(1400px) translateY(${-tip * 420}px) translateZ(${-tip * 500}px) rotateX(${tip * 70}deg)`, transformOrigin: '50% 22%' }}>
          <StampCard t={t} at={0} stampAt={0} top={300}>
            {stamp}
          </StampCard>
        </div>
      ) : null}
      <Peek t={t} at={0} until={film.saidIn + 0.3} side={1} mood="smug" y={760} outAt={film.saidIn - 0.14} />

      <Said film={film} />

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
      {/* This one is a Premium feature, and says so the whole time it is on. */}
      {(() => {
        const on = ramp(t, film.rise + 0.9, film.rise + 1.3, out) * (1 - ramp(t, end - 0.3, end, inOut));
        if (on <= 0) return null;
        return (
          <div style={{ position: 'absolute', left: 760, top: 240, opacity: on, transform: `translateY(${(1 - on) * -90}px) rotate(3deg)` }}>
            <div style={{ position: 'absolute', left: 88, top: -16, width: 84, height: 30, background: 'rgba(238,226,190,0.78)', transform: 'rotate(-3deg)', boxShadow: '0 1px 2px rgba(0,0,0,0.12)' }} />
            <div style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '10px 24px 10px 18px', borderRadius: 6, backgroundColor: '#FBF6EA', backgroundImage: `url(${staticFile('paper-grain.png')})`, backgroundBlendMode: 'multiply', backgroundSize: '300px', boxShadow: '0 10px 22px rgba(30,30,10,0.32)', border: '1px solid rgba(90,80,50,0.16)' }}>
              <span style={{ color: '#D9A21E', fontSize: 36, lineHeight: 1 }}>★</span>
              <span style={{ fontFamily: SERIF, fontWeight: 800, fontSize: 40, color: '#2B2620', letterSpacing: '0.02em' }}>{s.premium}</span>
            </div>
          </div>
        );
      })()}
      {/* Gold on what it has remembered. */}
      {(() => {
        const p = film.project((s.note[0] + s.note[2]) / 2 - 150, (s.note[1] + s.note[3]) / 2);
        return <Burst t={t} at={film.noteAt} x={p.x} y={p.y} scale={1.1} count={18} />;
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
