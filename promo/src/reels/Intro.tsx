import { AbsoluteFill, Easing, Html5Audio, Img, interpolate, staticFile, useCurrentFrame } from 'remotion';
import { FONT } from '../fonts';
import { Mascot, type Mood } from '../Mascot';
import { COLLAGE, Desk, Paper, Tape, torn } from '../collage';
import { C, clamp } from '../kit';
import script from './episodes.json';
import timings from './timing.json';
import { EndCard, REEL_FPS } from './Reel';

/**
 * Episode 1, the first time anyone meets the app: one phone and one cat,
 * filmed like a camera move. The camera starts on the cat in the corner of
 * the Today screen, pulls back to show where it lives, pushes into what it
 * says to you, follows a tap into a study card, and the cat jumps out of
 * the phone to say goodbye. One thing on screen at a time, every cut on
 * the beat.
 *
 * The world is the screenshot itself (1206 × 2622 px, an iPhone at 3×);
 * the camera says which point of it sits in the middle of the frame, and
 * how many frame pixels one screenshot pixel takes.
 */
export type Cam = { x: number; y: number; z: number };
export const STAGE = { x: 540, y: 820 };
const W = 1206;
const H = 2622;

const FULL: Cam = { x: 603, y: 1311, z: 0.41 };
/** The whole phone, a little lower, so the app's name fits above it. */
const MEET: Cam = { x: 603, y: 1033, z: 0.39 };
/** The study card and its buttons. */
const STUDY: Cam = { x: 603, y: 1420, z: 0.5 };
/** The cat in the corner of Today's word card, as the app draws it. */
const CAT_BOX = { left: 914, top: 375, size: 218 };
const CAT: Cam = { x: 1023, y: 482, z: 2.7 };
const BUBBLE: Cam = { x: 820, y: 470, z: 1.28 };
const BUTTON: Cam = { x: 603, y: 1032, z: 0.72 };
/** Taps, in screenshot pixels. */
const TAP_CONTINUE = { x: 603, y: 1032 };
const TAP_SHOW = { x: 603, y: 2416 };
const TAP_KNOW = { x: 884, y: 2416 };
/** The little cat at the top of a study card, where it jumps out from. */
const STUDY_CAT = { x: 94, y: 400, size: 104 };

export const inOut = Easing.bezier(0.65, 0, 0.35, 1);
export const out = Easing.bezier(0.16, 1, 0.3, 1);

export const lerpCam = (a: Cam, b: Cam, p: number): Cam => ({
  x: a.x + (b.x - a.x) * p,
  y: a.y + (b.y - a.y) * p,
  // Zoom moves in ratios, so a push-in feels even all the way.
  z: Math.exp(Math.log(a.z) + (Math.log(b.z) - Math.log(a.z)) * p),
});

/** Keyframes: [seconds, camera]. Between two, the camera eases. */
export const camAt = (keys: [number, Cam][], t: number): Cam => {
  if (t <= keys[0][0]) return keys[0][1];
  for (let i = 1; i < keys.length; i++) {
    const [t0, c0] = keys[i - 1];
    const [t1, c1] = keys[i];
    if (t <= t1) return lerpCam(c0, c1, inOut((t - t0) / (t1 - t0)));
  }
  return keys[keys.length - 1][1];
};

export const toStage = (cam: Cam, x: number, y: number) => ({ x: STAGE.x + (x - cam.x) * cam.z, y: STAGE.y + (y - cam.y) * cam.z });

export const Ripple = ({ at, t, x, y, cam }: { at: number; t: number; x: number; y: number; cam: Cam }) => {
  const age = t - at;
  if (age < 0 || age > 0.6) return null;
  const p = toStage(cam, x, y);
  return (
    <>
      <div
        style={{
          position: 'absolute',
          left: p.x - 70,
          top: p.y - 70,
          width: 140,
          height: 140,
          borderRadius: '50%',
          border: `7px solid ${COLLAGE.clay}`,
          transform: `scale(${0.35 + age * 1.8})`,
          opacity: interpolate(age, [0, 0.6], [0.95, 0], clamp),
        }}
      />
      <div
        style={{
          position: 'absolute',
          left: p.x - 34,
          top: p.y - 34,
          width: 68,
          height: 68,
          borderRadius: '50%',
          background: 'rgba(43,38,32,0.28)',
          opacity: interpolate(age, [0, 0.08, 0.35], [0, 1, 0], clamp),
        }}
      />
    </>
  );
};

/**
 * A line as words of characters; `**word**` is the word to lean on. Each
 * Latin word stays whole on one line; Chinese may break between any two
 * characters, as it does in print.
 */
const parse = (text: string) => {
  const words: { c: string; strong: boolean }[][] = [];
  text.split(/(\*\*[^*]+\*\*)/).forEach((part) => {
    const strong = part.startsWith('**');
    const body = strong ? part.slice(2, -2) : part;
    for (const piece of body.match(/[A-Za-z0-9'’.,!?:;-]+|\s+|./gu) ?? []) {
      words.push(Array.from(piece).map((c) => ({ c, strong })));
    }
  });
  return words;
};

/**
 * What the cat says: always in the same place, low in the frame, one line
 * at a time, dark so it stands apart from the light app screens behind it.
 * A small "SillyCat" tab says who is talking; the characters come in one
 * after another, and the word to lean on is in peach.
 */
export const Caption = ({
  text,
  start,
  length,
  t,
  first,
  label = 'SillyCat',
  top = 1478,
  size = 56,
}: {
  text: string;
  start: number;
  length: number;
  t: number;
  first: boolean;
  label?: string;
  /** Where the caption's box starts, and its type size. */
  top?: number;
  size?: number;
}) => {
  if (t < start || t > start + length) return null;
  const age = first ? 10 : t - start;
  const enter = interpolate(age, [0, 0.24], [0, 1], { ...clamp, easing: out });
  const leave = interpolate(t, [start + length - 0.16, start + length], [1, 0], clamp);
  const words = parse(text);
  const starts = words.map((_, w) => words.slice(0, w).reduce((n, word) => n + word.length, 0));
  const count = words.reduce((n, word) => n + word.length, 0);
  const stagger = Math.min(0.03, 0.34 / count);
  return (
    <div style={{ position: 'absolute', left: 70, right: 70, top, display: 'flex', justifyContent: 'center' }}>
      <div
        style={{
          position: 'relative',
          background: 'rgba(43,38,32,0.94)',
          color: '#FFF8EE',
          fontWeight: 900,
          fontSize: size,
          lineHeight: 1.32,
          letterSpacing: '0.02em',
          padding: '22px 36px 20px',
          borderRadius: 24,
          boxShadow: '0 14px 34px rgba(43,38,32,0.28)',
          textAlign: 'center',
          textWrap: 'balance',
          opacity: enter * leave,
          transform: `translateY(${(1 - enter) * 18}px) scale(${0.97 + 0.03 * enter})`,
        }}
      >
        <div
          style={{
            position: 'absolute',
            left: 26,
            top: -24,
            display: 'flex',
            alignItems: 'center',
            gap: 6,
            padding: '4px 16px 4px 6px',
            borderRadius: 999,
            background: COLLAGE.clay,
            color: '#FFF8EE',
            fontSize: 24,
            fontWeight: 800,
            letterSpacing: '0.04em',
            lineHeight: 1,
          }}
        >
          <Mascot mood="smug" size={38} />
          {label}
        </div>
        {words.map((word, w) => (
          <span key={w} style={{ display: 'inline-block', whiteSpace: 'pre' }}>
            {word.map(({ c, strong }, k) => {
              const i = starts[w] + k;
              const p = interpolate(age, [i * stagger, i * stagger + 0.14], [0, 1], { ...clamp, easing: out });
              return (
                <span
                  key={k}
                  style={{
                    display: 'inline-block',
                    opacity: p,
                    transform: `translateY(${(1 - p) * 10}px)`,
                    color: strong ? '#F7B98F' : undefined,
                    whiteSpace: 'pre',
                  }}
                >
                  {c}
                </span>
              );
            })}
          </span>
        ))}
      </div>
    </div>
  );
};

/** The app's name, stamped on once the camera has shown where the cat lives. */
const NameTag = ({ at, until, t, name, tagline }: { at: number; until: number; t: number; name: string; tagline: string }) => {
  const press = interpolate(t, [at, at + 0.12], [0, 1], { ...clamp, easing: Easing.in(Easing.cubic) });
  const leave = interpolate(t, [until - 0.25, until], [1, 0], clamp);
  if (t < at || t > until) return null;
  const width = 900;
  const height = 150;
  return (
    <div
      style={{
        position: 'absolute',
        left: (1080 - width) / 2,
        top: 238,
        width,
        height,
        opacity: press * leave,
        transform: `rotate(-2deg) scale(${1.5 - 0.5 * press})`,
      }}
    >
      <Paper kind="peach" style={{ inset: 0, clipPath: torn(width, height, ['top', 'bottom'], 5, 4) }} />
      <Tape width={56} angle={-10} style={{ left: 18, top: -16 }} />
      <div style={{ position: 'absolute', inset: 0, display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 26, color: C.ink }}>
        <span style={{ fontWeight: 900, fontSize: 76, letterSpacing: '0.04em' }}>{name}</span>
        <span style={{ fontWeight: 700, fontSize: 38, color: COLLAGE.clay, whiteSpace: 'nowrap' }}>{tagline}</span>
      </div>
    </div>
  );
};

export const Intro = ({ id }: { id: string }) => {
  const t = useCurrentFrame() / REEL_FPS;
  const episode = script.episodes.find((e) => e.id === id)! as (typeof script.episodes)[number] & {
    app?: string;
    tagline?: string;
    outro?: string;
    outroNote?: string;
    catTop?: number;
    shots?: { today: string; study: string; answer: string };
  };
  const shots = episode.shots ?? { today: 'today', study: 'study', answer: 'study-answer' };
  const timing = (timings as Record<string, { total: number; end: number; slots: { start: number; length: number }[] }>)[id];
  const [hook, meet, roast, study, bye] = timing.slots.map((s) => s.start);
  const BEAT = 0.5;
  const tapContinue = study + 0.8 * BEAT;
  const push = study + 1 * BEAT;
  const tapShow = study + 3 * BEAT;
  const tapKnow = study + 4.4 * BEAT;
  const jump = bye + 1 * BEAT;

  const cam = camAt(
    [
      [0, CAT],
      [meet - 0.05, { ...CAT, z: 2.95 }],
      [meet + 1.1, MEET],
      [roast, { ...MEET, y: 1000, z: 0.4 }],
      [roast + 0.75, BUBBLE],
      [study - 0.05, { ...BUBBLE, z: 1.36 }],
      [tapContinue - 0.05, BUTTON],
      [push + 0.75, STUDY],
      [bye, { ...STUDY, z: 0.52 }],
      [bye + 0.9, { ...FULL, y: 1180, z: 0.33 }],
    ],
    t,
  );

  // The screen pushes to the study card like a navigation push: in from
  // the right, the old screen drifting left and dimming underneath.
  const nav = interpolate(t, [push, push + 0.55], [0, 1], { ...clamp, easing: inOut });
  const answer = interpolate(t, [tapShow + 0.08, tapShow + 0.3], [0, 1], clamp);
  const knowFlash = interpolate(t, [tapKnow + 0.05, tapKnow + 0.2, tapKnow + 0.7], [0, 1, 0], clamp);
  // Depth of field: close on the cat, the screen behind it goes soft.
  const blur = interpolate(cam.z, [0.8, 2.7], [0, 9], clamp);
  const dim = interpolate(t, [bye + 0.3, bye + 1.0], [0, 0.35], clamp);

  const left = STAGE.x - cam.x * cam.z;
  const top = STAGE.y - cam.y * cam.z;
  const bezel = 46;

  // The cat in the app's corner: drawn crisp over the screenshot so it can
  // move, and carried along when the screen pushes away.
  const todayShift = -0.3 * W * nav;
  const catStage = toStage(cam, CAT_BOX.left + todayShift, episode.catTop ?? CAT_BOX.top);
  const catSize = CAT_BOX.size * cam.z;
  const greet = interpolate(t, [0.05, 0.3], [0, 1], { ...clamp, easing: Easing.out(Easing.back(2.2)) });
  const catMood: Mood = t < 0.25 ? 'idle' : t < meet ? 'smug' : t < roast + 0.6 ? 'happy' : 'smug';

  // The goodbye jump: out of the little cat on the study card, up and
  // towards the camera, landing big in front of the phone.
  const jp = interpolate(t, [jump, jump + 0.6], [0, 1], { ...clamp, easing: out });
  const from = toStage(cam, STUDY_CAT.x - STUDY_CAT.size / 2, STUDY_CAT.y - STUDY_CAT.size / 2);
  const landSize = 560;
  const jumpSize = STUDY_CAT.size * cam.z + (landSize - STUDY_CAT.size * cam.z) * jp;
  const jumpX = from.x + (540 - landSize / 2 - from.x) * jp;
  const jumpY = from.y + (930 - landSize / 2 - from.y) * jp - Math.sin(Math.PI * jp) * 260;

  // The end card opens as a circle out of the cat.
  const reveal = interpolate(t, [timing.end - 0.05, timing.end + 0.5], [0, 1], { ...clamp, easing: inOut });

  const lines = episode.lines;
  return (
    <AbsoluteFill style={{ fontFamily: FONT, overflow: 'hidden' }}>
      <Html5Audio src={staticFile(`reels/${id}.mp3`)} />
      <Desk kind="desk" />

      {/* The phone */}
      <div style={{ position: 'absolute', left, top, width: W * cam.z, height: H * cam.z, filter: dim ? `brightness(${1 - dim})` : undefined }}>
        <div
          style={{
            position: 'absolute',
            inset: -bezel * cam.z,
            borderRadius: 210 * cam.z,
            background: '#1E1A17',
            boxShadow: `0 ${40 * cam.z}px ${110 * cam.z}px rgba(43,38,32,0.32)`,
          }}
        />
        <div style={{ position: 'absolute', inset: 0, borderRadius: 165 * cam.z, overflow: 'hidden', filter: blur > 0.2 ? `blur(${blur}px)` : undefined, background: COLLAGE.desk }}>
          <div style={{ position: 'absolute', inset: 0, transform: `translateX(${todayShift * cam.z}px)`, filter: `brightness(${1 - 0.25 * nav})` }}>
            <Img src={staticFile(`shots/${shots.today}.jpg`)} style={{ width: '100%', height: '100%' }} />
          </div>
          {nav > 0 ? (
            <div style={{ position: 'absolute', inset: 0, transform: `translateX(${(1 - nav) * W * cam.z}px)`, boxShadow: '-20px 0 40px rgba(0,0,0,0.12)' }}>
              <Img src={staticFile(`shots/${shots.study}.jpg`)} style={{ position: 'absolute', width: '100%', height: '100%' }} />
              <Img src={staticFile(`shots/${shots.answer}.jpg`)} style={{ position: 'absolute', width: '100%', height: '100%', opacity: answer }} />
              <div style={{ position: 'absolute', inset: 0, background: '#6E8F5E', opacity: knowFlash * 0.22 }} />
              {/* Where the little cat was, once it has jumped out. */}
              {jp > 0 ? (
                <div
                  style={{
                    position: 'absolute',
                    left: (STUDY_CAT.x - STUDY_CAT.size / 2) * cam.z,
                    top: (STUDY_CAT.y - STUDY_CAT.size / 2) * cam.z,
                    width: STUDY_CAT.size * cam.z,
                    height: STUDY_CAT.size * cam.z,
                    background: COLLAGE.desk,
                    borderRadius: '50%',
                    filter: `blur(${4 * cam.z}px)`,
                  }}
                />
              ) : null}
            </div>
          ) : null}
        </div>
      </div>

      {/* The cat in the app */}
      {nav < 1 ? (
        <div
          style={{
            position: 'absolute',
            left: catStage.x,
            top: catStage.y,
            transform: `rotate(${(1 - greet) * -8}deg) scale(${0.94 + 0.06 * greet})`,
            transformOrigin: '50% 90%',
            filter: `brightness(${1 - 0.25 * nav})`,
          }}
        >
          <Mascot mood={catMood} size={catSize} />
        </div>
      ) : null}

      <Ripple at={tapContinue} t={t} x={TAP_CONTINUE.x} y={TAP_CONTINUE.y} cam={cam} />
      <Ripple at={tapShow} t={t} x={TAP_SHOW.x} y={TAP_SHOW.y} cam={cam} />
      <Ripple at={tapKnow} t={t} x={TAP_KNOW.x} y={TAP_KNOW.y} cam={cam} />

      {/* The goodbye */}
      {jp > 0 && t < timing.end + 0.5 ? (
        <div style={{ position: 'absolute', left: jumpX, top: jumpY }}>
          <Mascot mood="smug" size={jumpSize} />
        </div>
      ) : null}

      <NameTag at={meet + 2 * BEAT} until={roast} t={t} name={episode.app ?? '單字貓'} tagline={episode.tagline ?? ''} />
      {lines.map((line, i) => (
        <Caption key={i} text={line.text} start={timing.slots[i].start} length={timing.slots[i].length} t={t} first={i === 0} />
      ))}

      {reveal > 0 ? (
        <AbsoluteFill style={{ clipPath: `circle(${reveal * 1250}px at 540px 930px)` }}>
          <EndCard start={timing.end - 0.2} t={t} series={episode.series} name={episode.app} outro={episode.outro} note={episode.outroNote} />
        </AbsoluteFill>
      ) : null}
    </AbsoluteFill>
  );
};
