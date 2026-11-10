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
import { Calendar, Counter, Route, Track } from './props';
import { Backdrop, Grade, InkFilters, Motes } from './finish';
import { Lift, PHONE, colorAt, Phone3D, ScreenLayer, StudioLight, Tap3D, imageTexture, inOut, loadStudio, onScreen, out, ramp, usePrepared } from './three/kit';

/**
 * 11/10, six days to go: the study plan, on a real phone in 3D.
 *
 * The look is the teaser's (the olive backdrop, the paper props, the
 * caption band); what is new is that the phone is a modelled object in a
 * photo studio's light, and the cuts are moves of that phone.
 *
 * Cover (the days-left card and 傻貓 peeking, as every day opens). The
 * card tips away and the phone rises back-first, lenses catching the
 * light, and turns to face you on a quiz. A tap, the wrong answer, and
 * the screen comes apart in depth: the cat's verdict and the two choices
 * lift off the glass as the phone swings to three-quarters. They drop
 * back; the phone spins once and comes round on the plan. It tilts down
 * to the exam and the date, a tap, and the calendar flies out and flips
 * to the day. One more spin, and the plan's lines lift off one at a
 * time while the counter and the chapter track come out beside them.
 *
 * What changes with the language is the episode's `scene` in
 * episodes.json: the screenshots, the taps, the pieces that lift, the
 * props.
 */

const BEAT = 0.5;
const PI = Math.PI;
// The camera never moves: the phone does.
const CAM_Z = 9;
const FOV = 30;
const FOCAL = 960 / Math.tan(((FOV / 2) * PI) / 180);
/** World height that puts something on the middle of the safe area (y = 825 px) at depth 0. */
const MID = ((960 - 825) / FOCAL) * CAM_Z;

type Slot = { start: number; length: number };
type Crop = [number, number, number, number, number, number]; // x0, y0, x1, y1, lift, beat
type Prop =
  | { kind: 'calendar'; slot: number; beat: number; until?: [number, number]; from: [number, number]; pages: [string, string, string, string][]; final: [string, string, string, string]; tag: string }
  | { kind: 'counter'; slot: number; beat: number; until?: [number, number]; from: [number, number]; at: [number, number]; tilt: number; label: string; unit: string; to: number }
  | { kind: 'track'; slot: number; beat: number; until?: [number, number]; from: [number, number]; at: [number, number]; tilt: number; title: string; steps: string[]; stepWord: string; flag: string }
  | { kind: 'route'; slot: number; beat: number; until?: [number, number]; from: [number, number]; at: [number, number]; tilt: number; stops: string[]; stopBeats: number[]; doneBeat: number; doneText: string };
type Scene = {
  quiz: [string, string];
  quizTap: [number, number];
  quizLook: number;
  quizLifts: Crop[];
  plan: string;
  planTaps: [number, number, number][];
  planLook: number;
  planLifts: Crop[];
  props: Prop[];
};
type Episode = { id: string; days: number; app: string; label: string; dayWords: [string, string]; note: string; outro: string; lines: { text: string }[]; scene: Scene };

type Pose = { x: number; y: number; z: number; rx: number; ry: number; rz: number };
type Key = { at: number; pose: Pose; ease?: (n: number) => number };

/** The phone's place and attitude at `t`, eased from one written pose to the next. */
const poseAt = (keys: Key[], t: number): Pose => {
  let i = 0;
  while (i < keys.length - 1 && t >= keys[i + 1].at) i++;
  const a = keys[i];
  const b = keys[Math.min(i + 1, keys.length - 1)];
  const p = a === b ? 0 : (b.ease ?? inOut)(Math.min(1, Math.max(0, (t - a.at) / (b.at - a.at))));
  const m = (k: keyof Pose) => a.pose[k] + (b.pose[k] - a.pose[k]) * p;
  return { x: m('x'), y: m('y'), z: m('z'), rx: m('rx'), ry: m('ry'), rz: m('rz') };
};

/** How far up the phone has to sit for the screenshot row `y` to land on frame row `row` when it is `z` towards the lens. */
const frame = (y: number, row: number, z: number) => ((960 - row) / FOCAL) * (CAM_Z - z) - (0.5 - y / 2622) * PHONE.h;

/** Everything that happens, on the beat grid; the scene and the overlays both read it. */
const useFilm = (id: string) => {
  const t = useCurrentFrame() / REEL_FPS;
  const episode = script.episodes.find((e) => e.id === id)! as unknown as Episode;
  const s = episode.scene;
  const timing = (timings as Record<string, { total: number; end: number; slots: Slot[] }>)[id];
  const starts = timing.slots.map((slot) => slot.start);
  const [, check, plan, route] = starts;
  const end = timing.end;
  const at = (slot: number, beat: number) => starts[slot] + beat * BEAT;

  const rise = 2 * BEAT; // the cover gives way on the second beat
  const tapAt = check + 2 * BEAT;
  const answered = ramp(t, tapAt + 0.2, tapAt + 0.45, (n) => n);
  const apart = check + 3 * BEAT;
  const together = check + 5.5 * BEAT;
  const spin1 = check + 6 * BEAT;
  const spin2 = route;
  const calendar = s.props.find((pr) => pr.kind === 'calendar' || (pr.slot === 2 && pr.until));
  const propOut = calendar ? ramp(t, at(calendar.slot, calendar.beat), at(calendar.slot, calendar.beat) + 0.4, (n) => n) * (calendar.until ? 1 - ramp(t, at(...calendar.until), at(...calendar.until) + 0.3, (n) => n) : 1) : 0;

  const whole = (z: number, row = 825) => frame(1311, row, z);
  const yQuiz = frame(s.quizLook, 840, 3.4);
  const yPlan = frame(s.planLook, 1110, 3.0);
  const keys: Key[] = [
    // Up from under the frame, back to the lens, and round to face it.
    { at: rise, pose: { x: 0.25, y: -5.4, z: 0, rx: 0.55, ry: PI + 0.9, rz: 0.28 } },
    { at: rise + 0.8, pose: { x: 0.08, y: whole(2.2) + 0.05, z: 2.2, rx: 0.12, ry: PI + 0.42, rz: 0.07 }, ease: out },
    { at: rise + 1.25, pose: { x: 0.04, y: whole(2.1), z: 2.1, rx: 0.08, ry: PI + 0.2, rz: 0.04 }, ease: (n) => n },
    { at: rise + 2.0, pose: { x: 0, y: whole(1.5), z: 1.5, rx: -0.04, ry: PI * 2 - 0.2, rz: 0.012 }, ease: inOut },
    { at: check - 0.05, pose: { x: 0, y: whole(1.6), z: 1.6, rx: -0.03, ry: PI * 2 - 0.1, rz: 0.008 }, ease: (n) => n },
    // In on the question.
    { at: check + 1.2 * BEAT, pose: { x: 0, y: yQuiz, z: 3.4, rx: 0, ry: PI * 2, rz: 0 }, ease: out },
    { at: apart - 0.05, pose: { x: 0, y: frame(s.quizLook, 840, 3.5), z: 3.5, rx: 0, ry: PI * 2, rz: 0 }, ease: (n) => n },
    // Three-quarters, so the lifted pieces show their depth.
    { at: apart + 0.55, pose: { x: 0.34, y: frame(s.quizLook, 880, 2.3), z: 2.3, rx: 0.16, ry: PI * 2 - 0.72, rz: 0.035 }, ease: out },
    { at: together, pose: { x: 0.24, y: frame(s.quizLook, 880, 2.45), z: 2.45, rx: 0.12, ry: PI * 2 - 0.52, rz: 0.025 }, ease: (n) => n },
    { at: spin1, pose: { x: 0, y: whole(1.4), z: 1.4, rx: 0, ry: PI * 2 - 0.1, rz: 0 } },
    // Once round; it comes back on the plan.
    { at: spin1 + 0.55, pose: { x: 0, y: whole(1.5), z: 1.5, rx: -0.03, ry: PI * 4 - 0.2, rz: 0.01 }, ease: inOut },
    { at: plan - 0.05, pose: { x: 0, y: whole(1.6), z: 1.6, rx: -0.03, ry: PI * 4 - 0.12, rz: 0.008 }, ease: (n) => n },
    // Down to the exam and the date.
    { at: plan + 1.0 * BEAT, pose: { x: 0, y: yPlan, z: 3.0, rx: 0.1, ry: PI * 4 + 0.1, rz: 0 }, ease: out },
    { at: route - 0.05, pose: { x: 0, y: yPlan + 0.03, z: 3.05, rx: 0.1, ry: PI * 4 + 0.16, rz: 0 }, ease: (n) => n },
    // Round again, and to three-quarters on the plan's lines.
    { at: route + 0.6, pose: { x: 0.3, y: frame(1000, 960, 1.9), z: 1.9, rx: 0.14, ry: PI * 6 - 0.62, rz: 0.03 }, ease: inOut },
    { at: end - 0.2, pose: { x: 0.22, y: frame(1000, 960, 2.0), z: 2.0, rx: 0.11, ry: PI * 6 - 0.42, rz: 0.02 }, ease: (n) => n },
    // Away, into the end card.
    { at: end + 0.4, pose: { x: 0.5, y: MID - 0.4, z: -7, rx: 0.3, ry: PI * 6 + 1.2, rz: 0.2 }, ease: (n) => n * n },
  ];
  const pose = poseAt(keys, t);
  // It shakes its head at the wrong answer.
  const no = t > tapAt + 0.22 ? Math.sin((t - tapAt - 0.22) * 34) * 0.07 * Math.max(0, 1 - (t - tapAt - 0.22) / 0.45) : 0;
  pose.ry += no;
  // While something is out of the phone, the phone sinks back a little.
  pose.z -= propOut * 1.2;
  const before = poseAt(keys, t - 1 / REEL_FPS);
  const turning = Math.abs(pose.ry - before.ry) * REEL_FPS; // rad/s, for the motion blur
  const matrix = new THREE.Matrix4().makeTranslation(pose.x, pose.y, pose.z).multiply(new THREE.Matrix4().makeRotationFromEuler(new THREE.Euler(pose.rx, pose.ry, pose.rz, 'YXZ')));
  /** A point on the screenshot, in frame pixels: where a prop flies out from. */
  const project = (x: number, y: number) => {
    const v = new THREE.Vector3(...onScreen(x, y)).applyMatrix4(matrix);
    const k = FOCAL / (CAM_Z - v.z);
    return { x: 540 + v.x * k, y: 960 - v.y * k };
  };
  // The quiz is on the glass until the first spin shows the back; then the plan.
  const onPlan = t >= spin1 + 0.27;
  const lifts = (onPlan ? s.planLifts : s.quizLifts).map(([x0, y0, x1, y1, depth, beat]) => {
    const up = at(onPlan ? 3 : 1, beat);
    const down = onPlan ? end - 0.25 : together;
    return { crop: [x0, y0, x1, y1] as [number, number, number, number], lift: depth * 1.5 * ramp(t, up, up + 0.45, out) * (1 - ramp(t, down, down + 0.3, inOut)) };
  });
  const dim = Math.min(1, Math.max(0, ...lifts.map((l) => l.lift * 2.2)));
  // Where the phone's shadow falls: behind it, a little smaller, narrowing as it turns edge-on.
  const centre = project(603, 1311);
  const size = (FOCAL / (CAM_Z - pose.z)) * 0.8;
  const shadow = { x: centre.x, y: centre.y, w: Math.max(60, PHONE.w * size * Math.abs(Math.cos(pose.ry))), h: PHONE.h * size };
  // A softbox crosses the glass each time the phone comes to rest facing you.
  const glare = [rise + 1.75, spin1 + 0.4, route + 0.45].reduce((g, start) => (t >= start && t < start + 0.9 ? (t - start) / 0.9 : g), -1);
  return { t, episode, s, timing, at, check, plan, route, end, rise, tapAt, answered, pose, turning, project, onPlan, lifts, dim, propOut, glare, shadow };
};

const Stage = ({ id }: { id: string }) => {
  const gl = useThree((state) => state.gl);
  const film = useFilm(id);
  const { t, s, pose } = film;
  const maps = usePrepared(async () => {
    const [quiz, done, plan, env] = await Promise.all([imageTexture(`${s.quiz[0]}.jpg`), imageTexture(`${s.quiz[1]}.jpg`), imageTexture(`${s.plan}.jpg`), loadStudio(gl)]);
    // What is left where a piece lifts off: the page just outside its top-left corner.
    const ground = (map: THREE.Texture, crops: Crop[]) => crops.map(([x0, y0]) => colorAt(map, x0 + 60, y0 - 14));
    return { quiz, done, plan, env, quizGround: ground(done, s.quizLifts), planGround: ground(plan, s.planLifts) };
  });
  if (!maps || t < film.rise - 0.05) return null;
  const top = film.onPlan ? maps.plan : film.answered > 0.5 ? maps.done : maps.quiz;
  return (
    <>
      <StudioLight env={maps.env} turn={t * 0.12 + pose.ry * 0.25} />
      <group position={[pose.x, pose.y + Math.sin(t * 1.3) * 0.012, pose.z]} rotation={[pose.rx + Math.sin(t * 0.9) * 0.008, pose.ry, pose.rz, 'YXZ']}>
        <Phone3D screen={film.onPlan ? maps.plan : maps.quiz} glare={film.glare}>
          {!film.onPlan ? <ScreenLayer map={maps.done} opacity={film.answered} /> : null}
          <ScreenLayer color="#2a2418" opacity={Math.max(film.dim * 0.16, film.propOut * 0.3)} over />
          {film.lifts.map((l, i) => (
            <Lift key={`${film.onPlan}${i}`} map={top} crop={l.crop} lift={l.lift} ground={(film.onPlan ? maps.planGround : maps.quizGround)[i]} />
          ))}
          {!film.onPlan ? <Tap3D t={t} at={film.tapAt} x={s.quizTap[0]} y={s.quizTap[1]} /> : null}
          {film.onPlan ? s.planTaps.map(([beat, x, y], i) => <Tap3D key={i} t={t} at={film.at(2, beat)} x={x} y={y} />) : null}
        </Phone3D>
      </group>
    </>
  );
};

export const Day6 = ({ id }: { id: string }) => {
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
      {s.props.map((pr, i) => {
        const when = at(pr.slot, pr.beat);
        const until = pr.until ? at(...pr.until) : end - 0.2;
        const from = film.project(pr.from[0], pr.from[1]);
        if (pr.kind === 'calendar') return <Calendar key={i} t={t} at={when} until={until} from={from} pages={pr.pages} final={pr.final} tag={pr.tag} />;
        if (pr.kind === 'counter') return <Counter key={i} t={t} at={when} until={until} from={from} left={pr.at[0]} top={pr.at[1]} tilt={pr.tilt} label={pr.label} unit={pr.unit} to={pr.to} />;
        if (pr.kind === 'track') return <Track key={i} t={t} at={when} until={until} from={from} left={pr.at[0]} top={pr.at[1]} tilt={pr.tilt} title={pr.title} steps={pr.steps} stepWord={pr.stepWord} flag={pr.flag} />;
        return <Route key={i} t={t} at={when} until={until} from={from} left={pr.at[0]} top={pr.at[1]} tilt={pr.tilt} stops={pr.stops} stopTimes={pr.stopBeats.map((b) => at(pr.slot, b))} doneAt={at(pr.slot, pr.doneBeat)} doneText={pr.doneText} />;
      })}

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
