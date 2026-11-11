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
 * 11/13, three days to go: scanning a word list (Premium).
 *
 * Cover, then a handwritten sheet slaps down on the desk. The phone comes
 * up beside it, turned towards it, on the scan's review page with
 * nothing found yet. A flash; a band of light runs down the sheet and
 * marks each line it reads. Then the lines leave the paper one at a
 * time, cross to the phone, and land as rows of the real review page,
 * each lifting off the glass as it arrives. The sheet slides away, the
 * phone comes to the middle; a tap on Save, the saved page, and (in
 * Chinese) round once more to the first of the new cards.
 *
 * The sheet is a prop written for this, with the screenshot's own words;
 * everything on the phone is the app's screenshots.
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
  review: string;
  header: Crop;
  rows: Crop[];
  land: number[];
  save: Crop;
  look: number;
  saved?: string;
  savedLift?: Crop;
  card?: string;
  cardCrop?: Crop;
  sheet: { title: string; note: string; rows: [string, string][] };
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

/** The sheet on the desk: where it lies, and where each written line is on it. */
const SHEET = { left: 44, top: 318, width: 520, height: 900, tilt: -4, firstRow: 250, rowGap: 150 };
const FLIGHT = 0.6;

const useFilm = (id: string) => {
  const t = useCurrentFrame() / REEL_FPS;
  const episode = script.episodes.find((e) => e.id === id)! as unknown as Episode;
  const s = episode.scene;
  const timing = (timings as Record<string, { total: number; end: number; slots: Slot[] }>)[id];
  const starts = timing.slots.map((slot) => slot.start);
  const [, snap, lines, keep] = starts;
  const end = timing.end;
  const at = (slot: number, beat: number) => starts[slot] + beat * BEAT;

  const rise = snap - 0.9; // the cover and then the sheet have the first line to themselves
  const sheetIn = 2.2 * BEAT;
  const flash = at(1, 2);
  const sweep = [at(1, 2.6), at(1, 6.6)] as const;
  const lands = s.land.map((beat) => at(2, beat));
  const tap = at(3, 1);
  const savedAt = tap + 0.3;
  const spin = s.card ? at(3, 4.6) : Infinity;
  const onCard = t >= spin + 0.3;
  const sheetOut = ramp(t, keep - 0.2, keep + 0.5, inOut);

  const beside = (z: number, row = 800) => frame(1311, row, z);
  const yList = (z: number, row = 830) => frame(s.look, row, z);
  const keys: Key[] = [
    // Up beside the sheet, turned towards it.
    { at: rise, pose: { x: 1.1, y: -5.2, z: 0, rx: 0.5, ry: PI + 0.9, rz: 0.25 } },
    { at: rise + 0.8, pose: { x: 0.6, y: beside(1.4) + 0.05, z: 1.4, rx: 0.12, ry: PI + 0.5, rz: 0.06 }, ease: out },
    { at: rise + 1.7, pose: { x: 0.5, y: beside(1.3), z: 1.3, rx: 0.04, ry: PI * 2 - 0.4, rz: 0.012 }, ease: inOut },
    { at: flash, pose: { x: 0.5, y: beside(1.3), z: 1.3, rx: 0.04, ry: PI * 2 - 0.42, rz: 0.012 }, ease: (n) => n },
    // It leans in over the sheet for the shot, and back.
    { at: flash + 0.15, pose: { x: 0.44, y: beside(1.4), z: 1.4, rx: 0.06, ry: PI * 2 - 0.5, rz: 0.02 }, ease: out },
    { at: flash + 0.7, pose: { x: 0.5, y: beside(1.3), z: 1.3, rx: 0.04, ry: PI * 2 - 0.4, rz: 0.012 } },
    { at: lines, pose: { x: 0.5, y: beside(1.35), z: 1.35, rx: 0.04, ry: PI * 2 - 0.38, rz: 0.012 }, ease: (n) => n },
    { at: keep - 0.2, pose: { x: 0.49, y: beside(1.4), z: 1.4, rx: 0.05, ry: PI * 2 - 0.34, rz: 0.01 }, ease: (n) => n },
    // To the middle, on the list and its Save button.
    { at: keep + 0.6, pose: { x: 0, y: yList(2.1), z: 2.1, rx: 0.06, ry: PI * 2, rz: 0 }, ease: inOut },
    { at: tap + 0.25, pose: { x: 0, y: yList(2.15), z: 2.15, rx: 0.06, ry: PI * 2 + 0.04, rz: 0 }, ease: (n) => n },
    ...(s.card
      ? ([
          { at: tap + 1.0, pose: { x: 0.06, y: frame(760, 800, 2.5), z: 2.5, rx: 0.08, ry: PI * 2 - 0.3, rz: 0.01 }, ease: out },
          { at: spin, pose: { x: 0.06, y: frame(760, 800, 2.45), z: 2.45, rx: 0.07, ry: PI * 2 - 0.22, rz: 0.01 }, ease: (n: number) => n },
          // Once round, onto the first of the new cards.
          { at: spin + 0.6, pose: { x: 0, y: frame(1400, 900, 2.2), z: 2.2, rx: 0.05, ry: PI * 4 + 0.2, rz: 0 }, ease: inOut },
          { at: end - 0.2, pose: { x: 0, y: frame(1400, 900, 2.3), z: 2.3, rx: 0.04, ry: PI * 4 + 0.08, rz: 0 }, ease: (n: number) => n },
          { at: end + 0.4, pose: { x: 0.5, y: MID - 0.4, z: -7, rx: 0.3, ry: PI * 4 + 1.2, rz: 0.2 }, ease: (n: number) => n * n },
        ] as Key[])
      : ([
          { at: tap + 1.1, pose: { x: 0.2, y: yList(2.0, 880), z: 2.0, rx: 0.13, ry: PI * 2 - 0.56, rz: 0.03 }, ease: out },
          { at: end - 0.2, pose: { x: 0.14, y: yList(2.1, 880), z: 2.1, rx: 0.1, ry: PI * 2 - 0.36, rz: 0.02 }, ease: (n: number) => n },
          { at: end + 0.4, pose: { x: 0.5, y: MID - 0.4, z: -7, rx: 0.3, ry: PI * 2 + 1.2, rz: 0.2 }, ease: (n: number) => n * n },
        ] as Key[])),
  ];
  const pose = poseAt(keys, t);
  const before = poseAt(keys, t - 1 / REEL_FPS);
  const turning = Math.abs(pose.ry - before.ry) * REEL_FPS;
  const matrixOf = (q: Pose) => new THREE.Matrix4().makeTranslation(q.x, q.y, q.z).multiply(new THREE.Matrix4().makeRotationFromEuler(new THREE.Euler(q.rx, q.ry, q.rz, 'YXZ')));
  const projectWith = (q: Pose, x: number, y: number) => {
    const v = new THREE.Vector3(...onScreen(x, y)).applyMatrix4(matrixOf(q));
    const k = FOCAL / (CAM_Z - v.z);
    return { x: 540 + v.x * k, y: 960 - v.y * k, k };
  };
  const project = (x: number, y: number) => projectWith(pose, x, y);
  // Each written line: read by the light, then across to its row.
  const rows = s.rows.map((crop, i) => {
    const land = lands[i];
    const y = SHEET.firstRow + i * (s.rows.length > 3 ? 132 : SHEET.rowGap);
    const read = sweep[0] + ((y + 30) / SHEET.height) * (sweep[1] - sweep[0]);
    // Where the row will be when the line gets there.
    const target = projectWith(poseAt(keys, land), crop[0] + 330, (crop[1] + crop[3]) / 2 - 20);
    const arrived = t >= land;
    const age = t - land;
    // The row jumps off the glass as the line lands in it, and settles a little proud of it.
    const pop = arrived ? 0.07 + 0.3 * Math.exp(-age * 7) * Math.abs(Math.cos(age * 9)) : 0;
    return { crop, land, read, y, target, arrived, lift: onCard ? 0 : pop * (1 - ramp(t, tap, tap + 0.3, inOut)), fly: Math.min(1, Math.max(0, (t - (land - FLIGHT)) / FLIGHT)) };
  });
  const found = rows.filter((r) => r.arrived).length;
  const saved = ramp(t, savedAt, savedAt + 0.25, (n) => n);
  const lifts = {
    save: 0.3 * ramp(t, tap - 0.6, tap - 0.2, out) * (1 - ramp(t, tap, tap + 0.12, (n) => n)) + (s.saved ? 0 : 0.34 * ramp(t, tap + 0.3, tap + 0.7, out) * (1 - ramp(t, end - 0.25, end, inOut))),
    saved: s.saved ? 0.34 * ramp(t, savedAt + 0.2, savedAt + 0.6, out) * (1 - ramp(t, spin - 0.35, spin - 0.05, inOut)) : 0,
    card: s.card ? 0.22 * ramp(t, spin + 0.7, spin + 1.1, out) * (1 - ramp(t, end - 0.25, end, inOut)) : 0,
    all: s.saved ? 0 : 0.26 * ramp(t, tap + 0.5, tap + 0.9, out) * (1 - ramp(t, end - 0.25, end, inOut)),
  };
  const done = savedAt + 0.35;
  const knock = [...lands, done].reduce((k, when) => { const age = t - when; return age >= 0 && age < 0.3 ? k + Math.exp(-age * 15) * Math.cos(age * 62) * (when === done ? 10 : 5) : k; }, 0);
  const centre = project(603, 1311);
  const size = (FOCAL / (CAM_Z - pose.z)) * 0.8;
  const shadow = { x: centre.x, y: centre.y, w: Math.max(60, PHONE.w * size * Math.abs(Math.cos(pose.ry))), h: PHONE.h * size };
  const glare = [rise + 1.5, keep + 0.6, spin + 0.5].reduce((g, start) => (t >= start && t < start + 0.9 ? (t - start) / 0.9 : g), -1);
  return { t, episode, s, timing, at, end, rise, sheetIn, flash, sweep, lands, tap, savedAt, done, spin, onCard, sheetOut, pose, turning, project, rows, found, saved, lifts, knock, shadow, glare };
};

const Stage = ({ id }: { id: string }) => {
  const gl = useThree((state) => state.gl);
  const film = useFilm(id);
  const { t, s, pose } = film;
  const maps = usePrepared(async () => {
    const [review, env, phone, saved, card] = await Promise.all([imageTexture(`${s.review}.jpg`), loadStudio(gl), loadPhone(), s.saved ? imageTexture(`${s.saved}.jpg`) : null, s.card ? imageTexture(`${s.card}.jpg`) : null]);
    return {
      review,
      env,
      phone,
      saved,
      card,
      // The colour of a row with nothing in it yet, and of the page around the list.
      blank: colorAt(review, s.rows[0][0] + 24, s.rows[0][1] + 12),
      page: colorAt(review, 16, s.header[1] + 20),
      around: s.rows.map(([x0, y0]) => colorAt(review, x0 + 24, y0 + 12)),
      saveGround: colorAt(review, 16, s.save[1] + 40),
      savedGround: saved ? colorAt(saved, 16, 300) : '#000',
      cardGround: card ? colorAt(card, 16, 1400) : '#000',
    };
  });
  const patch = (crop: Crop, color: string, key: string, pad = 0) => (
    <mesh key={key} position={[...onScreen((crop[0] + crop[2]) / 2, (crop[1] + crop[3]) / 2, 0.0019)] as [number, number, number]} renderOrder={2}>
      <planeGeometry args={[((crop[2] - crop[0] + pad) / 1206) * PHONE.w, ((crop[3] - crop[1] + pad) / 2622) * PHONE.h]} />
      <meshBasicMaterial color={color} toneMapped={false} depthWrite={false} transparent />
    </mesh>
  );
  if (!maps || t < film.rise - 0.05) return null;
  const screen = film.onCard && maps.card ? maps.card : maps.review;
  return (
    <>
      <StudioLight env={maps.env} turn={t * 0.12 + pose.ry * 0.25} />
      <group position={[pose.x, pose.y + Math.sin(t * 1.3) * 0.012, pose.z]} rotation={[pose.rx + Math.sin(t * 0.9) * 0.008, pose.ry, pose.rz, 'YXZ']}>
        <Phone3D model={maps.phone} screen={screen} glare={film.glare}>
          {film.onCard && maps.card && s.cardCrop ? (
            <Lift map={maps.card} crop={s.cardCrop} lift={film.lifts.card} ground={maps.cardGround} radius={12} />
          ) : (
            <>
              {maps.saved ? <ScreenLayer map={maps.saved} opacity={film.saved} /> : null}
              {film.saved < 0.5 ? (
                <>
                  {/* Nothing found yet: the rows are bare until a line lands in them. */}
                  {film.found < s.rows.length ? patch(s.header, maps.page, 'header') : null}
                  {film.rows.map((r, i) => (r.arrived ? null : patch(r.crop, maps.blank, `row${i}`, 4)))}
                  {film.rows.map((r, i) => (
                    <Lift key={i} map={maps.review} crop={r.crop} lift={Math.max(r.lift, r.arrived ? film.lifts.all * (1 + i * 0.12) : 0)} ground={maps.around[i]} radius={20} />
                  ))}
                  <Lift map={maps.review} crop={s.save} lift={film.lifts.save} ground={maps.saveGround} radius={60} />
                  <Tap3D t={t} at={film.tap} x={(s.save[0] + s.save[2]) / 2} y={(s.save[1] + s.save[3]) / 2} />
                  {film.rows.map((r, i) => (
                    <Tap3D key={`land${i}`} t={t} at={r.land - 0.02} x={r.crop[0] + 100} y={(r.crop[1] + r.crop[3]) / 2 - 20} />
                  ))}
                </>
              ) : maps.saved && s.savedLift ? (
                <Lift map={maps.saved} crop={s.savedLift} lift={film.lifts.saved} ground={maps.savedGround} radius={24} />
              ) : null}
            </>
          )}
          <ScreenLayer color="#2a2418" opacity={Math.min(0.2, Math.max(film.lifts.saved, film.lifts.card, film.lifts.all) * 0.5)} over />
        </Phone3D>
      </group>
    </>
  );
};

/** One written line: the word in pen, its meaning beside it. */
const Written = ({ a, b, size = 1, ink = '#2B3A55' }: { a: string; b: string; size?: number; ink?: string }) => {
  const hand = (text: string) => (/[㐀-鿿]/.test(text) ? { fontFamily: HAND_TC, fontSize: 52 * size, letterSpacing: '0.04em' } : { fontFamily: HAND, fontWeight: 600, fontSize: 66 * size });
  return (
    <div style={{ display: 'flex', alignItems: 'baseline', gap: 26 * size, color: ink, whiteSpace: 'nowrap', lineHeight: 1 }}>
      <span style={hand(a)}>{a}</span>
      <span style={{ ...hand(b), opacity: 0.82 }}>{b}</span>
    </div>
  );
};

/**
 * The sheet: ruled paper with punched holes, a title in the teacher's
 * print, the words in a student's hand. The light that reads it runs
 * down it, and each line is marked as it is read; a line that has gone
 * to the phone leaves only its pencil ghost.
 */
const Sheet = ({ film }: { film: ReturnType<typeof useFilm> }) => {
  const { t, s, sheetIn, sweep, sheetOut } = film;
  if (t < sheetIn || sheetOut >= 1) return null;
  const drop = ramp(t, sheetIn, sheetIn + 0.22, (n) => n * n);
  const settle = t > sheetIn + 0.22 ? Math.exp(-(t - sheetIn - 0.22) * 9) * Math.sin((t - sheetIn - 0.22) * 22) * 0.012 : 0;
  const light = Math.min(1, Math.max(0, (t - sweep[0]) / (sweep[1] - sweep[0])));
  const lit = t > sweep[0] && t < sweep[1] + 0.15;
  return (
    <div
      style={{
        position: 'absolute',
        left: SHEET.left - sheetOut * 760,
        top: SHEET.top + (1 - drop) * -1500,
        width: SHEET.width,
        height: SHEET.height,
        transform: `rotate(${SHEET.tilt - (1 - drop) * 14 - sheetOut * 10}deg) scale(${1 + (1 - drop) * 0.5 + settle})`,
        transformOrigin: '50% 40%',
        filter: sheetOut > 0 ? `blur(${sheetOut * 9}px)` : undefined,
        ...ABOVE_CAPTIONS,
      }}
    >
      <div style={{ position: 'absolute', inset: 0, borderRadius: 6, boxShadow: `0 ${26 + (1 - drop) * 60}px ${40 + (1 - drop) * 60}px rgba(26,30,10,${0.42 - (1 - drop) * 0.2}), 0 2px 3px rgba(26,30,10,0.3)`, backgroundColor: '#FBF7EC', backgroundImage: `url(${staticFile('paper-grain.png')}), repeating-linear-gradient(to bottom, rgba(0,0,0,0) 0px, rgba(0,0,0,0) 73px, rgba(96,128,170,0.34) 74px, rgba(96,128,170,0.34) 76px)`, backgroundBlendMode: 'multiply, normal', backgroundSize: '320px, auto', backgroundPosition: '0 0, 0 100px', overflow: 'hidden' }}>
        <div style={{ position: 'absolute', left: 76, top: 0, bottom: 0, width: 2, background: 'rgba(201,100,66,0.5)' }} />
        {[150, 450, 750].map((y) => (
          <div key={y} style={{ position: 'absolute', left: 22, top: y, width: 30, height: 30, borderRadius: 15, background: 'radial-gradient(circle at 40% 35%, #6F7C50, #8D9A68)', boxShadow: 'inset 0 3px 5px rgba(0,0,0,0.35)' }} />
        ))}
        <div style={{ position: 'absolute', left: 100, top: 52, fontFamily: SERIF, fontWeight: 800, fontSize: 46, color: '#3A342C', letterSpacing: '0.02em' }}>{s.sheet.title}</div>
        <div style={{ position: 'absolute', left: 100, top: 116, width: 250, height: 5, background: '#3A342C', opacity: 0.7 }} />
        <div style={{ position: 'absolute', right: 40, bottom: 60, transform: 'rotate(-7deg)', color: '#C4452C', ...(/[㐀-鿿]/.test(s.sheet.note) ? { fontFamily: HAND_TC, fontSize: 38 } : { fontFamily: HAND, fontWeight: 600, fontSize: 48 }), border: '3px solid #C4452C', borderRadius: '50% 46% 52% 48%', padding: '4px 14px' }}>{s.sheet.note}</div>
        {film.rows.map((r, i) => {
          const marked = ramp(t, r.read, r.read + 0.28, out);
          const gone = r.fly > 0 ? 1 : 0;
          return (
            <div key={i} style={{ position: 'absolute', left: 100 + [0, 8, -4, 6][i % 4], top: r.y - 40, transform: `rotate(${[-1.6, 1.1, -0.7, 1.4][i % 4]}deg)`, transformOrigin: '0% 50%' }}>
              {/* The marker's stroke as the line is read. */}
              <div style={{ position: 'absolute', left: -10, top: 18, height: 46, width: 400 * marked, background: 'rgba(255,200,97,0.5)', borderRadius: '8px 22px 12px 18px', mixBlendMode: 'multiply' }} />
              <div style={{ position: 'relative', opacity: gone ? 0.2 : 1 }}>
                <Written a={s.sheet.rows[i][0]} b={s.sheet.rows[i][1]} />
              </div>
              {r.arrived ? <div style={{ position: 'absolute', left: -62, top: -6, fontFamily: HAND, fontWeight: 600, fontSize: 84, lineHeight: 1, color: '#C4452C', transform: `rotate(-8deg) scale(${1 + Math.exp(-(t - r.land) * 12) * 0.8})`, opacity: ramp(t, r.land, r.land + 0.08, (n) => n) }}>✓</div> : null}
            </div>
          );
        })}
        <div style={{ position: 'absolute', left: 104, bottom: 70, fontFamily: HAND, fontWeight: 600, fontSize: 60, color: 'rgba(60,70,90,0.55)', transform: 'rotate(-4deg)' }}>★ ✓ ✓</div>
        {/* The light that reads the page. */}
        {lit ? (
          <div style={{ position: 'absolute', left: 0, right: 0, top: light * SHEET.height - 130, height: 150, background: 'linear-gradient(to bottom, rgba(255,214,120,0) 0%, rgba(255,214,120,0.34) 70%, rgba(255,246,214,0.95) 96%, rgba(255,214,120,0) 100%)', opacity: 1 - ramp(t, sweep[1], sweep[1] + 0.15, (n) => n) }} />
        ) : null}
      </div>
      {/* The camera's frame around what it is reading. */}
      {t > film.flash - 0.25 && t < sweep[1] + 0.35
        ? [
            [0, 0],
            [1, 0],
            [0, 1],
            [1, 1],
          ].map(([cx, cy]) => {
            const on = ramp(t, film.flash - 0.25, film.flash, out) * (1 - ramp(t, sweep[1] + 0.1, sweep[1] + 0.35, (n) => n));
            // Inside the sheet's edge: the sheet's own box is all that is drawn of it.
            const gap = -(16 + (1 - on) * 36 + Math.sin(t * 6) * 2);
            return (
              <div
                key={`${cx}${cy}`}
                style={{ position: 'absolute', [cx ? 'right' : 'left']: -gap, [cy ? 'bottom' : 'top']: -gap, width: 74, height: 74, opacity: on, [cx ? 'borderRight' : 'borderLeft']: '7px solid #E39B2B', [cy ? 'borderBottom' : 'borderTop']: '7px solid #E39B2B', borderRadius: 6, filter: 'drop-shadow(0 0 8px rgba(255,200,97,0.95))' }}
              />
            );
          })
        : null}
      {/* Tape at the top. */}
      <div style={{ position: 'absolute', left: 190, top: -22, width: 150, height: 44, background: 'rgba(238,226,190,0.8)', transform: 'rotate(-3deg)', boxShadow: '0 1px 3px rgba(0,0,0,0.14)' }} />
    </div>
  );
};

/** The written lines on their way from the paper to their rows on the phone. */
const Crossing = ({ film }: { film: ReturnType<typeof useFilm> }) => (
  <>
    {film.rows.map((r, i) => {
      if (r.fly <= 0 || r.fly >= 1) return null;
      const u = inOut(r.fly);
      const from = { x: SHEET.left + 100 + r.y * 0.07, y: SHEET.top + r.y - 22 };
      const x = from.x + (r.target.x - 170 - from.x) * u;
      const y = from.y + (r.target.y - 30 - from.y) * u - Math.sin(PI * r.fly) * 150;
      const lift = Math.sin(PI * r.fly);
      const at2 = (f: number) => {
        const v = inOut(Math.max(0, f));
        return { x: from.x + (r.target.x - 170 - from.x) * v, y: from.y + (r.target.y - 30 - from.y) * v - Math.sin(PI * Math.max(0, f)) * 150 };
      };
      return (
        <div key={i}>
          {[1, 2, 3, 4, 5, 6].map((k) => {
            const p = at2(r.fly - k * 0.045);
            const size = 16 - k * 2;
            return <div key={k} style={{ position: 'absolute', left: p.x + 60 + Math.sin(k * 2.3 + i) * 26, top: p.y + 26 + Math.cos(k * 1.7 + i) * 16, width: size, height: size, borderRadius: size, background: '#FFD678', boxShadow: '0 0 12px 3px rgba(255,214,120,0.75)', opacity: (1 - k / 7) * Math.sin(PI * r.fly) }} />;
          })}
        <div style={{ position: 'absolute', left: x, top: y, transform: `rotate(${SHEET.tilt * (1 - u) - lift * 5}deg) scale(${1 + lift * 0.35 - u * 0.42})`, transformOrigin: '0% 50%', opacity: 1 - ramp(r.fly, 0.82, 1, (n) => n), filter: `drop-shadow(0 ${10 + lift * 26}px ${8 + lift * 16}px rgba(26,30,10,${0.25 + lift * 0.2})) blur(${Math.sin(PI * r.fly) * 1.2}px)` }}>
          <div style={{ padding: '6px 18px 10px', background: 'rgba(255,200,97,0.42)', borderRadius: '10px 24px 14px 20px' }}>
            <Written a={film.s.sheet.rows[i][0]} b={film.s.sheet.rows[i][1]} />
          </div>
        </div>
        </div>
      );
    })}
  </>
);

/**
 * 傻貓 in the corner for the whole of it: one cat who stays, pleased each
 * time a line lands and smug once they are saved.
 */
const Buddy = ({ film }: { film: ReturnType<typeof useFilm> }) => {
  const { t, end, lands, done } = film;
  const arrive = film.at(1, 0.6);
  if (t < arrive) return null;
  const inP = ramp(t, arrive, arrive + 0.5, out) * (1 - ramp(t, end - 0.25, end + 0.1, inOut));
  const events = [...lands.map((at) => ({ at, mood: 'happy' as Mood, stay: false })), { at: done, mood: 'cheeky' as Mood, stay: true }];
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

export const Day3 = ({ id }: { id: string }) => {
  const frameNo = useCurrentFrame();
  const film = useFilm(id);
  const { t, episode, s, timing, at, end, rise } = film;

  const stamp = <DaysStamp days={episode.days} words={episode.dayWords} note={episode.note} />;
  // The cover tips back and away as the phone comes up through where it was.
  const tip = ramp(t, film.sheetIn - 0.12, film.sheetIn + 0.38, inOut);
  const leave = ramp(t, end - 0.15, end + 0.35, inOut);
  const smear = Math.min(26, Math.max(0, film.turning - 2.5) * 2.4);
  const lit = ramp(t, film.sheetIn, film.sheetIn + 0.8, (n) => n) * (1 - leave);

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
      <Peek t={t} at={0} until={film.sheetIn + 0.3} side={1} mood="smug" y={760} outAt={film.sheetIn - 0.14} />

      {/* The pencil it was written with. */}
      {t >= film.sheetIn + 0.1 && film.sheetOut < 1 ? (
        <div style={{ position: 'absolute', left: 150 - film.sheetOut * 700, top: 252 + (1 - ramp(t, film.sheetIn + 0.1, film.sheetIn + 0.32, (n) => n * n)) * -700, width: 400, height: 26, transform: 'rotate(5deg)', filter: `drop-shadow(0 10px 8px rgba(26,30,10,0.4))${film.sheetOut > 0 ? ` blur(${film.sheetOut * 8}px)` : ''}`, ...ABOVE_CAPTIONS }}>
          <div style={{ position: 'absolute', left: 0, top: 0, width: 34, height: 26, borderRadius: '8px 2px 2px 8px', background: 'linear-gradient(to bottom, #E79A8E, #C96A5E)' }} />
          <div style={{ position: 'absolute', left: 34, top: 0, width: 22, height: 26, background: 'linear-gradient(to bottom, #D9D4C8, #9C968A)' }} />
          <div style={{ position: 'absolute', left: 56, top: 0, width: 290, height: 26, background: 'linear-gradient(to bottom, #F2C24E 0%, #E6AE2E 48%, #C98F1C 100%)' }} />
          <div style={{ position: 'absolute', left: 346, top: 0, width: 0, height: 0, borderTop: '13px solid transparent', borderBottom: '13px solid transparent', borderLeft: '42px solid #E8D2A6' }} />
          <div style={{ position: 'absolute', left: 376, top: 8, width: 0, height: 0, borderTop: '5px solid transparent', borderBottom: '5px solid transparent', borderLeft: '14px solid #3A3A3A' }} />
        </div>
      ) : null}
      <Sheet film={film} />

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
      <Crossing film={film} />
      {/* The shot. */}
      {t >= film.flash && t < film.flash + 0.3 ? <AbsoluteFill style={{ background: '#FFFBEF', opacity: 0.8 * Math.exp(-(t - film.flash) * 14) }} /> : null}
      {/* This one is a Premium feature, and says so the whole time it is on. */}
      {(() => {
        const on = ramp(t, film.flash - 0.9, film.flash - 0.5, out) * (1 - ramp(t, end - 0.3, end, inOut));
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
      {/* Gold when they are saved. */}
      {(() => {
        const c = s.saved && s.savedLift ? [(s.savedLift[0] + s.savedLift[2]) / 2, s.savedLift[1] + 150] : [(s.save[0] + s.save[2]) / 2, (s.save[1] + s.save[3]) / 2];
        const p = film.project(c[0], c[1]);
        return <Burst t={t} at={film.done} x={p.x} y={p.y} scale={1.2} count={20} />;
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
