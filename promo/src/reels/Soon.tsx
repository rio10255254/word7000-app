import { ThreeCanvas } from '@remotion/three';
import { useThree } from '@react-three/fiber';
import { AbsoluteFill, Html5Audio, staticFile, useCurrentFrame } from 'remotion';
import * as THREE from 'three';
import { FONT, HAND, HAND_TC, SERIF, SERIF_TC } from '../fonts';
import script from './episodes.json';
import timings from './timing.json';
import { REEL_FPS } from './Reel';
import { Caption } from './Intro';
import { ABOVE_CAPTIONS, CAPTION_TOP } from './Teaser';
import { CountdownEnd, SoonStamp, StampCard } from './Countdown';
import { Burst, DeskLamp, Grade, InkFilters, Motes, NightBackdrop } from './finish';
import { Mascot, type Mood } from '../Mascot';
import { PHONE, Phone3D, StudioLight, imageTexture, inOut, loadPhone, loadStudio, onScreen, out, ramp, usePrepared } from './three/kit';

/**
 * The launch is late: the one reel that is not a countdown, and looks it.
 *
 * Night. A desk lamp comes on over the card every countdown opened with:
 * the date, stamped. A sticky note is slapped over the date. Then the
 * phone comes up into the lamplight beside a checklist; the pen ticks off
 * what is done, one line a beat, and circles the last one, still going.
 * The list slides off, the phone comes to the middle and turns slowly
 * under the lamp, and the end card is stamped: stay tuned.
 *
 * It says what is true and no more: later than promised, still being
 * checked, and you will be told the day it is out.
 */

const BEAT = 0.5;
const PI = Math.PI;
const CAM_Z = 9;
const FOV = 30;
const FOCAL = 960 / Math.tan(((FOV / 2) * PI) / 180);
const MID = ((960 - 825) / FOCAL) * CAM_Z;

type Slot = { start: number; length: number };
type Scene = { screen: string; was: [string, string]; sticky: string; list: { title: string; done: string[]; doing: string } };
type Episode = { id: string; soon: string; app: string; label: string; note: string; outro: string; lines: { text: string }[]; scene: Scene };
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
const cjk = (text: string) => /[㐀-鿿]/.test(text);

const LIST = { left: 46, top: 330, width: 500, height: 800, tilt: -4, firstRow: 210, rowGap: 112 };

const useFilm = (id: string) => {
  const t = useCurrentFrame() / REEL_FPS;
  const episode = script.episodes.find((e) => e.id === id)! as unknown as Episode;
  const s = episode.scene;
  const timing = (timings as Record<string, { total: number; end: number; slots: Slot[] }>)[id];
  const starts = timing.slots.map((slot) => slot.start);
  const [, care, soon] = starts;
  const end = timing.end;
  const at = (slot: number, beat: number) => starts[slot] + beat * BEAT;

  // The lamp flickers on in the first half-second.
  const lamp = t < 0.12 ? 0 : t < 0.2 ? 0.7 : t < 0.28 ? 0.15 : t < 0.4 ? 0.9 : t < 0.46 ? 0.5 : 1;
  const stickyAt = at(0, 5);
  const rise = care - 0.25;
  const listIn = at(1, 1.6);
  const ticks = s.list.done.map((_, i) => at(1, 3 + i));
  const doing = at(1, 7.6);
  const listOut = ramp(t, soon - 0.2, soon + 0.5, inOut);

  const beside = (z: number, row = 800) => frame(1311, row, z);
  const keys: Key[] = [
    { at: rise, pose: { x: 1.1, y: -5.2, z: 0, rx: 0.5, ry: PI + 0.9, rz: 0.25 } },
    { at: rise + 0.8, pose: { x: 0.6, y: beside(1.4) + 0.05, z: 1.4, rx: 0.12, ry: PI + 0.5, rz: 0.06 }, ease: out },
    { at: rise + 1.6, pose: { x: 0.5, y: beside(1.3), z: 1.3, rx: 0.04, ry: PI * 2 - 0.38, rz: 0.012 }, ease: inOut },
    { at: soon - 0.2, pose: { x: 0.49, y: beside(1.4), z: 1.4, rx: 0.05, ry: PI * 2 - 0.3, rz: 0.01 }, ease: (n) => n },
    // To the middle, and a slow turn under the lamp.
    { at: soon + 0.7, pose: { x: 0, y: beside(2.2, 820), z: 2.2, rx: 0.05, ry: PI * 2 - 0.26, rz: 0 }, ease: inOut },
    { at: end - 0.2, pose: { x: 0, y: beside(2.5, 820), z: 2.5, rx: 0.03, ry: PI * 2 + 0.24, rz: 0 }, ease: (n) => n },
    { at: end + 0.4, pose: { x: 0.5, y: MID - 0.4, z: -7, rx: 0.3, ry: PI * 2 + 1.2, rz: 0.2 }, ease: (n) => n * n },
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
  const knocks = [stickyAt + 0.16, ...ticks, doing];
  const knock = knocks.reduce((k, when) => { const age = t - when; return age >= 0 && age < 0.3 ? k + Math.exp(-age * 15) * Math.cos(age * 62) * (when === stickyAt + 0.16 ? 11 : 4) : k; }, 0);
  const centre = project(603, 1311);
  const size = (FOCAL / (CAM_Z - pose.z)) * 0.8;
  const shadow = { x: centre.x, y: centre.y, w: Math.max(60, PHONE.w * size * Math.abs(Math.cos(pose.ry))), h: PHONE.h * size };
  const glare = [rise + 1.5, soon + 0.9, soon + 2.6].reduce((g, start) => (t >= start && t < start + 1.0 ? (t - start) / 1.0 : g), -1);
  return { t, episode, s, timing, at, end, lamp, stickyAt, rise, listIn, ticks, doing, listOut, pose, turning, project, knock, shadow, glare, soon };
};

const Stage = ({ id }: { id: string }) => {
  const gl = useThree((state) => state.gl);
  const film = useFilm(id);
  const { t, s, pose } = film;
  const maps = usePrepared(async () => {
    const [screen, env, phone] = await Promise.all([imageTexture(`${s.screen}.jpg`), loadStudio(gl), loadPhone()]);
    return { screen, env, phone };
  });
  if (!maps || t < film.rise - 0.05) return null;
  return (
    <>
      <StudioLight env={maps.env} turn={t * 0.1 + pose.ry * 0.25 + 1.4} />
      <group position={[pose.x, pose.y + Math.sin(t * 1.3) * 0.012, pose.z]} rotation={[pose.rx + Math.sin(t * 0.9) * 0.008, pose.ry, pose.rz, 'YXZ']}>
        <Phone3D model={maps.phone} screen={maps.screen} glare={film.glare} />
      </group>
    </>
  );
};

const paper = (color: string) => ({ backgroundColor: color, backgroundImage: `url(${staticFile('paper-grain.png')})`, backgroundBlendMode: 'multiply' as const, backgroundSize: '320px' });

/** The note over the date: yellow, taped, written in a hurry. */
const Sticky = ({ film }: { film: ReturnType<typeof useFilm> }) => {
  const { t, s, stickyAt } = film;
  if (t < stickyAt) return null;
  const age = t - stickyAt;
  const fall = ramp(t, stickyAt, stickyAt + 0.16, (n) => n * n);
  const settle = age > 0.16 ? Math.exp(-(age - 0.16) * 10) * Math.sin((age - 0.16) * 26) * 0.05 : 0;
  const hand = cjk(s.sticky) ? { fontFamily: HAND_TC, fontSize: 70, letterSpacing: '0.02em', whiteSpace: 'nowrap' as const } : { fontFamily: HAND, fontWeight: 600, fontSize: 84, whiteSpace: 'nowrap' as const };
  return (
    <div style={{ position: 'absolute', left: 300, top: 300, width: 440, height: 330, transform: `rotate(${7 + (1 - fall) * 16}deg) scale(${1 + (1 - fall) * 1.1 + settle})`, transformOrigin: '50% 30%', opacity: ramp(t, stickyAt, stickyAt + 0.05, (n) => n), filter: `drop-shadow(0 ${14 + (1 - fall) * 50}px ${16 + (1 - fall) * 40}px rgba(0,0,0,${0.5 - (1 - fall) * 0.2}))` }}>
      <div style={{ position: 'absolute', inset: 0, borderRadius: '4px 4px 30px 4px', ...paper('#F6D873'), boxShadow: 'inset 0 -30px 40px rgba(180,130,30,0.18)' }} />
      {/* The corner that has started to curl. */}
      <div style={{ position: 'absolute', right: 0, bottom: 0, width: 62, height: 62, borderRadius: '30px 0 30px 0', background: 'linear-gradient(135deg, #E4BF52 0%, #FBE9A6 55%, #D9B347 100%)', boxShadow: '-5px -5px 10px rgba(120,84,10,0.25)' }} />
      <div style={{ position: 'absolute', left: 150, top: -24, width: 140, height: 46, background: 'rgba(238,226,190,0.7)', transform: 'rotate(-4deg)', boxShadow: '0 1px 3px rgba(0,0,0,0.2)' }} />
      <div style={{ position: 'absolute', left: 10, right: 10, top: 96, textAlign: 'center', color: '#3A2E12', lineHeight: 1.1, ...hand }}>{s.sticky}</div>
      <svg width={300} height={30} viewBox="0 0 300 30" style={{ position: 'absolute', left: 70, top: 226, overflow: 'visible', opacity: t > stickyAt + 0.35 ? 1 : 0 }}>
        <path d="M4 16 q 40 -18 80 -2 t 80 2 t 80 -4 t 50 2" fill="none" stroke="#C4452C" strokeWidth={7} strokeLinecap="round" strokeDasharray={320} strokeDashoffset={320 * (1 - ramp(t, stickyAt + 0.35, stickyAt + 0.8, inOut))} />
      </svg>
    </div>
  );
};

/**
 * The checklist in the lamplight: what is done, ticked a line a beat in
 * red pen, and the last line ringed, with the ring still being gone over.
 */
const Checklist = ({ film }: { film: ReturnType<typeof useFilm> }) => {
  const { t, s, listIn, ticks, doing, listOut } = film;
  if (t < listIn || listOut >= 1) return null;
  const drop = ramp(t, listIn, listIn + 0.22, (n) => n * n);
  const settle = t > listIn + 0.22 ? Math.exp(-(t - listIn - 0.22) * 9) * Math.sin((t - listIn - 0.22) * 22) * 0.012 : 0;
  const rows = [...s.list.done, s.list.doing];
  const hand = (text: string) => (cjk(text) ? { fontFamily: HAND_TC, fontSize: 52, letterSpacing: '0.03em' } : { fontFamily: HAND, fontWeight: 600, fontSize: 64 });
  const ring = ramp(t, doing, doing + 0.5, inOut);
  // The pen keeps going round it: still working.
  const again = t > doing + 0.6 ? ((t - doing - 0.6) % 1.4) / 1.4 : 0;
  return (
    <div style={{ position: 'absolute', left: LIST.left - listOut * 760, top: LIST.top + (1 - drop) * -1500, width: LIST.width, height: LIST.height, transform: `rotate(${LIST.tilt - (1 - drop) * 14 - listOut * 10}deg) scale(${1 + (1 - drop) * 0.5 + settle})`, transformOrigin: '50% 40%', filter: listOut > 0 ? `blur(${listOut * 9}px)` : undefined, ...ABOVE_CAPTIONS }}>
      <div style={{ position: 'absolute', inset: 0, borderRadius: 6, boxShadow: `0 ${26 + (1 - drop) * 60}px ${44 + (1 - drop) * 60}px rgba(0,0,0,0.6), 0 2px 3px rgba(0,0,0,0.4)`, ...paper('#F7F1E0'), overflow: 'hidden' }}>
        {/* A clipboard's clip. */}
        <div style={{ position: 'absolute', left: 170, top: -8, width: 160, height: 58, borderRadius: '0 0 16px 16px', background: 'linear-gradient(to bottom, #8E8A80, #5B574E)', boxShadow: '0 4px 8px rgba(0,0,0,0.35)' }} />
        <div style={{ position: 'absolute', left: 54, top: 92, fontFamily: cjk(s.list.title) ? SERIF_TC : SERIF, fontWeight: cjk(s.list.title) ? 900 : 800, fontSize: 48, color: '#2B2620', letterSpacing: '0.04em' }}>{s.list.title}</div>
        <div style={{ position: 'absolute', left: 54, top: 162, width: 240, height: 5, background: '#2B2620', opacity: 0.75 }} />
        {rows.map((text, i) => {
          const last = i === rows.length - 1;
          const when = last ? doing : ticks[i];
          const done = !last && t >= when;
          const y = LIST.firstRow + i * LIST.rowGap;
          return (
            <div key={i} style={{ position: 'absolute', left: 54, top: y, display: 'flex', alignItems: 'center', gap: 24, transform: `rotate(${[-1.2, 0.8, -0.5, 1.1, -0.8][i % 5]}deg)`, transformOrigin: '0% 50%' }}>
              <div style={{ position: 'relative', width: 50, height: 50, border: '4px solid #4A4338', borderRadius: 8, flex: 'none' }}>
                {done ? <div style={{ position: 'absolute', left: -6, top: -40, fontFamily: HAND, fontWeight: 600, fontSize: 100, lineHeight: 1, color: '#C4452C', transform: `rotate(-6deg) scale(${1 + Math.exp(-(t - when) * 12) * 0.9})`, opacity: ramp(t, when, when + 0.06, (n) => n) }}>✓</div> : null}
              </div>
              <div style={{ position: 'relative', color: '#2B3A55', whiteSpace: 'nowrap', lineHeight: 1, opacity: done ? 0.62 : 1, ...hand(text) }}>
                {text}
                {last ? <span style={{ opacity: 0.8 }}>{'.'.repeat(1 + (Math.floor(Math.max(0, t - doing) * 2.4) % 3))}</span> : null}
                {last && ring > 0 ? (
                  <svg viewBox="0 0 300 100" preserveAspectRatio="none" style={{ position: 'absolute', left: -22, top: -18, width: 'calc(100% + 44px)', height: 'calc(100% + 36px)', overflow: 'visible' }}>
                    <ellipse cx={150} cy={50} rx={146} ry={44} fill="none" stroke="#C4452C" strokeWidth={5} strokeLinecap="round" pathLength={100} strokeDasharray={100} strokeDashoffset={100 * (1 - ring)} transform="rotate(-3 150 50)" vectorEffect="non-scaling-stroke" />
                    {again > 0 ? <ellipse cx={150} cy={50} rx={150} ry={47} fill="none" stroke="#C4452C" strokeWidth={4} strokeLinecap="round" pathLength={100} strokeDasharray="14 86" strokeDashoffset={-again * 100} opacity={0.7} transform="rotate(2 150 50)" vectorEffect="non-scaling-stroke" /> : null}
                  </svg>
                ) : null}
              </div>
            </div>
          );
        })}
        {/* The lamp only reaches so far across the page. */}
        <div style={{ position: 'absolute', inset: 0, background: 'linear-gradient(125deg, rgba(255,214,140,0.22) 0%, rgba(0,0,0,0) 45%, rgba(10,12,6,0.34) 100%)', mixBlendMode: 'multiply' }} />
      </div>
    </div>
  );
};

/** 傻貓 at the corner of the desk, up late: pleased with each tick, and not letting go of the last line. */
const Buddy = ({ film }: { film: ReturnType<typeof useFilm> }) => {
  const { t, end } = film;
  const arrive = film.rise + 0.4;
  if (t < arrive) return null;
  const inP = ramp(t, arrive, arrive + 0.5, out) * (1 - ramp(t, end - 0.25, end + 0.1, inOut));
  const events: { at: number; mood: Mood; stay: boolean }[] = [...film.ticks.map((at) => ({ at, mood: 'happy' as Mood, stay: false })), { at: film.doing, mood: 'smug', stay: false }, { at: film.soon + 1.0, mood: 'happy', stay: true }];
  const now = [...events].reverse().find((e) => t >= e.at);
  const age = now ? t - now.at : 9;
  const mood: Mood = now && (now.stay || age < 0.7) ? now.mood : 'idle';
  const hop = age < 0.6 ? Math.exp(-age * 7) * Math.sin(age * 17) : 0;
  return (
    <div style={{ position: 'absolute', left: -96 - (1 - inP) * 360, top: 1068 - hop * 26, transform: `rotate(${13 + hop * 3}deg)`, transformOrigin: '30% 100%', filter: 'drop-shadow(0 18px 22px rgba(0,0,0,0.55)) brightness(0.94)' }}>
      <Mascot mood={mood} size={400} next />
    </div>
  );
};

export const Soon = ({ id }: { id: string }) => {
  const frameNo = useCurrentFrame();
  const film = useFilm(id);
  const { t, episode, s, timing, end, rise } = film;
  const stamp = <SoonStamp words={episode.soon} note={episode.note} />;
  const tip = ramp(t, rise - 0.12, rise + 0.4, inOut);
  const leave = ramp(t, end - 0.15, end + 0.35, inOut);
  const smear = Math.min(26, Math.max(0, film.turning - 2.5) * 2.4);
  const lit = ramp(t, rise, rise + 0.8, (n) => n) * (1 - leave);
  const drift = (film.pose.y - MID) * 260 + film.pose.x * 500;

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
      <NightBackdrop t={t} frame={frameNo} lamp={film.lamp} drift={drift} />
      <Motes t={t} />

      {/* What every countdown opened with: the date, stamped. Then the note over it. */}
      {tip < 1 ? (
        <div style={{ position: 'absolute', inset: 0, opacity: (1 - tip * tip) * (0.25 + 0.75 * film.lamp), transform: `translateY(${film.knock}px) perspective(1400px) translateY(${-tip * 420}px) translateZ(${-tip * 500}px) rotateX(${tip * 70}deg)`, transformOrigin: '50% 22%' }}>
          <StampCard t={t} at={0} stampAt={0} top={300}>
            <SoonStamp words={s.was[0]} note={s.was[1]} />
          </StampCard>
          <Sticky film={film} />
        </div>
      ) : null}

      <Checklist film={film} />

      {/* The light the screen throws, and the phone's shadow. */}
      {lit > 0 && leave < 1 ? (
        <>
          <div style={{ position: 'absolute', left: film.shadow.x - film.shadow.w, top: film.shadow.y - film.shadow.h * 0.62, width: film.shadow.w * 2, height: film.shadow.h * 1.24, borderRadius: '50%', background: 'radial-gradient(closest-side, rgba(255,226,170,0.26), rgba(255,226,170,0) 100%)', opacity: lit, ...ABOVE_CAPTIONS }} />
          <div style={{ position: 'absolute', left: film.shadow.x - film.shadow.w / 2, top: film.shadow.y - film.shadow.h / 2 + 40, width: film.shadow.w, height: film.shadow.h, borderRadius: film.shadow.w * 0.3, background: 'rgba(0,0,0,0.42)', boxShadow: '0 34px 80px 40px rgba(0,0,0,0.42)', opacity: lit, ...ABOVE_CAPTIONS }} />
        </>
      ) : null}

      {t >= rise - 0.2 && leave < 1 ? (
        <AbsoluteFill style={{ opacity: 1 - leave, transform: `translateY(${film.knock}px)`, ...ABOVE_CAPTIONS }}>
          <AbsoluteFill style={{ filter: smear > 0.5 ? 'url(#smear)' : leave > 0 ? `blur(${leave * 12}px)` : undefined }}>
            <ThreeCanvas width={1080} height={1920} dpr={1} gl={{ antialias: true, alpha: true, toneMapping: THREE.ACESFilmicToneMapping, toneMappingExposure: 0.92 }} camera={{ fov: FOV, near: 0.5, far: 60, position: [0, 0, CAM_Z] }}>
              <Stage id={id} />
            </ThreeCanvas>
          </AbsoluteFill>
        </AbsoluteFill>
      ) : null}

      <DeskLamp t={t} lamp={film.lamp * (1 - leave)} />
      {/* A spark when the last line is ringed, and when the phone comes round into the light. */}
      <Burst t={t} at={film.doing + 0.45} x={LIST.left + 300} y={LIST.top + LIST.firstRow + s.list.done.length * LIST.rowGap + 30} scale={0.9} count={12} />
      <Burst t={t} at={film.soon + 1.0} x={540} y={760} scale={1.5} count={22} />
      <Buddy film={film} />
      <Motes t={t} front />
      {episode.lines.map((line, i) => (
        <Caption key={i} text={line.text} start={timing.slots[i].start} length={timing.slots[i].length} t={t} first={i === 0} label={episode.label} top={CAPTION_TOP} size={62} glass />
      ))}
      <CountdownEnd t={t} end={end} episode={episode} stamp={stamp} />
      <Grade frame={frameNo} />
    </AbsoluteFill>
  );
};
