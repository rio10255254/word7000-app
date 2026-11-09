import type { ReactNode } from 'react';
import { AbsoluteFill, Easing, Html5Audio, Img, interpolate, spring, staticFile, useCurrentFrame } from 'remotion';
import { FONT, SERIF } from '../fonts';
import { Mascot, type Mood } from '../Mascot';
import { Paper, Tape } from '../collage';
import { clamp } from '../kit';
import script from './episodes.json';
import timings from './timing.json';
import { REEL_FPS } from './Reel';
import { type Cam, Caption, STAGE, camAt, inOut, out, toStage } from './Intro';
import { Backdrop, Burst, Device, Grade, InkFilters, Sheen } from './finish';

/**
 * The launch teaser for WordCat Next (2.0.2), before it goes on sale on
 * 11/16. Olive, like the new icon. 傻貓 peeks in from the edge of the
 * frame the way it does in the app, jumps out, and moves into the phone;
 * then one day's path in quick cuts on the beat (cards, writing, an exam
 * question it catches you on), a speaking stage in the app's own recorded
 * voices, the stamp at the end of the day, a cheeky peek, and the date.
 *
 * Screens are the App Store screenshots of WordCat Next (1206 × 2622 px);
 * the camera works as in episode 1.
 */
const W = 1206;
const H = 2622;
const CLAY = '#C96442';

/** Where 傻貓 sits on Today's word card, as the app draws it. */
const CAT_BOX = { left: 905, top: 476, size: 228 };
const FULL: Cam = { x: 603, y: 1250, z: 0.42 };
const PATH: Cam = { x: 603, y: 1420, z: 0.62 };
const CARD: Cam = { x: 603, y: 1150, z: 0.56 };
const EXAM: Cam = { x: 603, y: 1150, z: 0.62 };
const SHADOW: Cam = { x: 603, y: 1700, z: 0.86 };
const STAMP: Cam = { x: 603, y: 1050, z: 0.6 };

/**
 * The captions get a band of their own at the bottom of the frame: the
 * phone fades out just above it, so a line never sits on top of the app's
 * own text.
 */
const CAPTION_TOP = 1452;
const ABOVE_CAPTIONS = {
  WebkitMaskImage: 'linear-gradient(to bottom, #000 0, #000 1330px, transparent 1420px)',
  maskImage: 'linear-gradient(to bottom, #000 0, #000 1330px, transparent 1420px)',
};

/** The screens each beat cuts to, and where the speaking and stamp screens keep their parts. */
const SCREENS = {
  today: 'n1-today',
  card: 'n2-card',
  write: 'n3-write-solved',
  exam: 'n4-exam-answered',
  shadow: 'n8-shadow',
  stamp: 'n11-stamp',
  mock: 'n4-exam',
};

type Slot = { start: number; length: number; voiceStart: number; voiceLength: number };

/** A phone at camera `cam`, showing `children` (screens) inside its glass. */
const Phone = ({ cam, children, lift = 0, t }: { cam: Cam; children: ReactNode; lift?: number; t: number }) => {
  const left = STAGE.x - cam.x * cam.z;
  const top = STAGE.y - cam.y * cam.z + lift;
  return (
    <div style={{ position: 'absolute', left, top, width: W * cam.z, height: H * cam.z }}>
      <Device z={cam.z} glare={(cam.x - 603) / 40 + Math.sin(t * 0.6) * 5}>
        {children}
      </Device>
    </div>
  );
};

/** One screen in the phone, pushed in from the right at `at` like a navigation push. */
const Screen = ({ shot, t, at, until, cam, children }: { shot: string; t: number; at: number; until?: number; cam: Cam; children?: ReactNode }) => {
  if (t < at) return null;
  const inP = interpolate(t, [at, at + 0.42], [0, 1], { ...clamp, easing: inOut });
  const outP = until === undefined ? 0 : interpolate(t, [until, until + 0.42], [0, 1], { ...clamp, easing: inOut });
  if (outP >= 1) return null;
  const x = (1 - inP) * W - outP * 0.3 * W;
  // Motion blur while it moves, strongest at full speed.
  const blur = 5 * Math.sin(Math.PI * inP) + 3 * Math.sin(Math.PI * outP);
  const filters = [outP ? `brightness(${1 - 0.25 * outP})` : '', blur > 0.3 ? `blur(${blur}px)` : ''].join(' ').trim();
  return (
    <div style={{ position: 'absolute', inset: 0, transform: `translateX(${x * cam.z}px)`, filter: filters || undefined }}>
      <Img src={staticFile(`next/${shot}.jpg`)} style={{ position: 'absolute', width: '100%', height: '100%' }} />
      {children}
    </div>
  );
};

/**
 * A strip of the speaking screen's own blank paper (from `from`) laid over
 * the strip at `to`, so a line can be hidden until it is spoken without a
 * visible patch.
 */
const Patch = ({ shot, from, to, height, z, opacity }: { shot: string; from: number; to: number; height: number; z: number; opacity: number }) =>
  opacity <= 0 ? null : (
    <div style={{ position: 'absolute', left: 0, right: 0, top: to * z, height: height * z, overflow: 'hidden', opacity }}>
      <Img src={staticFile(`next/${shot}.jpg`)} style={{ position: 'absolute', left: 0, top: -from * z, width: W * z, height: H * z }} />
    </div>
  );

/** 傻貓 poking its head in from one side of the frame, as CatPeek does in the app. */
const Peek = ({ t, at, until, side, mood, y }: { t: number; at: number; until: number; side: 1 | -1; mood: Mood; y: number }) => {
  if (t < at - 0.05 || t > until) return null;
  const inP = at <= 0 ? interpolate(t, [0, 0.5], [0.88, 1], { ...clamp, easing: out }) : interpolate(t, [at, at + 0.35], [0, 1], { ...clamp, easing: Easing.out(Easing.back(1.6)) });
  const size = 620;
  const hidden = size * 0.3; // how much stays past the edge
  const x = side > 0 ? 1080 - (size - hidden) * inP : -hidden - (size - hidden) * (1 - inP);
  return (
    <div
      style={{
        position: 'absolute',
        left: x,
        top: y,
        transform: `rotate(${side * -16}deg)`,
        transformOrigin: side > 0 ? '100% 60%' : '0% 60%',
        filter: 'drop-shadow(0 22px 26px rgba(30,34,14,0.32))',
      }}
    >
      <Mascot mood={mood} size={size} next />
    </div>
  );
};

/** The date, inked on like the app's daily stamp. */
const DateStamp = ({ t, at, text }: { t: number; at: number; text: string }) => {
  const press = interpolate(t, [at, at + 0.13], [0, 1], { ...clamp, easing: Easing.in(Easing.cubic) });
  const settle = interpolate(t, [at + 0.13, at + 0.3], [0.94, 1], clamp);
  if (t < at) return null;
  return (
    <div
      style={{
        position: 'absolute',
        left: 0,
        right: 0,
        top: 1010,
        display: 'flex',
        justifyContent: 'center',
        opacity: press,
        transform: `rotate(-6deg) scale(${t < at + 0.13 ? 1.9 - 0.96 * press : settle})`,
      }}
    >
      <div
        style={{
          filter: 'url(#ink)',
          border: `10px solid ${CLAY}`,
          borderRadius: 34,
          padding: '6px 46px 14px',
          color: CLAY,
          fontFamily: SERIF,
          fontWeight: 800,
          fontSize: 170,
          letterSpacing: '0.02em',
          lineHeight: 1,
          background: 'rgba(255,248,238,0.12)',
        }}
      >
        {text}
      </div>
    </div>
  );
};

export const Teaser = ({ id }: { id: string }) => {
  const t = useCurrentFrame() / REEL_FPS;
  const episode = script.episodes.find((e) => e.id === id)! as (typeof script.episodes)[number] & {
    launch?: string;
    label?: string;
    screens?: Partial<typeof SCREENS>;
    shadowCam?: Cam;
    patches?: number[][];
    ringY?: number;
    app?: string;
    outroNote?: string;
    outro?: string;
  };
  const sc = { ...SCREENS, ...episode.screens };
  const shadowCam = episode.shadowCam ?? SHADOW;
  const patches = episode.patches ?? [
    [700, 1240, 300],
    [620, 1545, 330],
  ];
  const ringY = episode.ringY ?? 1120;
  const timing = (timings as Record<string, { total: number; end: number; slots: Slot[] }>)[id];
  const [, meet, path, speak, stamp, mock] = timing.slots.map((s) => s.start);
  const end = timing.end;
  const BEAT = 0.5;

  // ── Cut times inside the day's path ──
  const toCard = path + 3 * BEAT;
  const toWrite = path + 5 * BEAT;
  const toExam = path + 7.6 * BEAT;
  const stampHit = stamp + 0.9 * BEAT;

  // ── The camera on the phone ──
  const cam = camAt(
    [
      [meet + 1.0, { ...FULL, y: FULL.y + 900 }],
      [meet + 2.0, FULL],
      [path - 0.05, { ...FULL, z: 0.44 }],
      [path + 0.6, PATH],
      [toCard - 0.1, { ...PATH, z: 0.64 }],
      [toCard + 0.4, CARD],
      [toExam - 0.1, CARD],
      [toExam + 0.4, EXAM],
      [speak - 0.1, { ...EXAM, z: 0.64 }],
      [speak + 0.5, shadowCam],
      [stamp - 0.1, { ...shadowCam, z: shadowCam.z + 0.04 }],
      [stamp + 0.5, STAMP],
      [mock - 0.1, { ...STAMP, z: 0.62 }],
      [mock + 0.4, { ...EXAM, z: 0.5 }],
    ],
    t,
  );
  // The phone rises into the frame once 傻貓 has said where it is moving to.
  const phoneIn = interpolate(t, [meet + 1.0, meet + 2.0], [0, 1], { ...clamp, easing: inOut });
  const phoneShown = t >= meet + 1.0 && t < end + 0.3;
  // In the last peek the phone steps back and goes soft behind the cat.
  const back = interpolate(t, [mock, mock + 0.4], [0, 1], clamp);
  const stampFlash = interpolate(t, [stampHit, stampHit + 0.06, stampHit + 0.5], [0, 0.55, 0], clamp);
  const shake = t > stampHit && t < stampHit + 0.35 ? Math.sin((t - stampHit) * 90) * 16 * (1 - (t - stampHit) / 0.35) : 0;
  const stampScale = interpolate(t, [stamp, stampHit, stampHit + 0.12], [1.35, 1.35, 1], { ...clamp, easing: Easing.in(Easing.cubic) });

  // ── 傻貓: peeks in, jumps out, moves into the phone ──
  const jump = interpolate(t, [meet, meet + 0.55], [0, 1], { ...clamp, easing: out });
  const moveIn = interpolate(t, [meet + 1.5, meet + 2.15], [0, 1], { ...clamp, easing: inOut });
  const home = toStage(cam, CAT_BOX.left, CAT_BOX.top);
  const homeSize = CAT_BOX.size * cam.z;
  const bigSize = 640;
  const bigX = 540 - bigSize / 2;
  const bigY = 360 + Math.sin(Math.PI * jump) * -120;
  const catX = bigX + (home.x - bigX) * moveIn;
  const catY = bigY + (home.y - bigY) * moveIn - Math.sin(Math.PI * moveIn) * 160;
  const catSize = bigSize + (homeSize - bigSize) * moveIn;
  const catOnScreen = t >= meet && t < toCard; // it rides the Today screen until the first push
  const todayShift = interpolate(t, [toCard, toCard + 0.42], [0, 1], { ...clamp, easing: inOut });

  // ── The speaking stage: the reply appears as the learner says it ──
  const replyAt = speak + 6.2 * BEAT;
  const replyShown = interpolate(t, [replyAt, replyAt + 0.25], [0, 1], clamp);
  const partnerShown = interpolate(t, [speak + 0.2, speak + 0.5], [0, 1], clamp);

  // ── The end card ──
  const endIn = interpolate(t, [end - 0.05, end + 0.45], [0, 1], { ...clamp, easing: inOut });
  const iconPop = spring({ frame: (t - end - 0.1) * REEL_FPS, fps: REEL_FPS, config: { damping: 12, stiffness: 170, mass: 0.8 } });
  const lines = episode.lines;
  const frame = useCurrentFrame();
  // A hand holding the camera: a slow, small float that keeps the frame alive.
  const fx = Math.sin(t * 0.83) * 4 + Math.sin(t * 1.7) * 1.5;
  const fy = Math.cos(t * 0.61) * 5;
  const tilt = Math.sin(t * 0.47) * 0.35;
  // 傻貓 lands in its corner with a squash and a bounce.
  const land = meet + 2.15;
  const sy = interpolate(t, [land, land + 0.07, land + 0.2, land + 0.32], [1, 0.84, 1.06, 1], clamp);

  return (
    <AbsoluteFill style={{ fontFamily: FONT, overflow: 'hidden', transform: `translateX(${shake}px)` }}>
      <Html5Audio src={staticFile(`reels/${id}.mp3`)} />
      <InkFilters />
      <Backdrop t={t} frame={frame} drift={phoneShown ? (cam.y - 1250) * cam.z : 0} />

      {phoneShown ? (
        <div style={{ position: 'absolute', inset: 0, filter: back ? `blur(${back * 7}px)` : undefined, opacity: 1 - 0.25 * back, ...ABOVE_CAPTIONS }}>
          <div style={{ position: 'absolute', inset: 0, transform: `translate(${fx}px, ${fy}px) rotate(${tilt}deg)`, transformOrigin: '50% 43%' }}>
          <Phone cam={cam} lift={(1 - phoneIn) * 1500} t={t}>
            <Screen shot={sc.today} t={t} at={0} until={toCard} cam={cam} />
            <Screen shot={sc.card} t={t} at={toCard} until={toWrite} cam={cam} />
            <Screen shot={sc.write} t={t} at={toWrite} until={toExam} cam={cam} />
            <Screen shot={sc.exam} t={t} at={toExam} until={speak} cam={cam} />
            <Screen shot={sc.shadow} t={t} at={speak} until={stamp} cam={cam}>
              {/* The server's line, then the learner's reply, as they are spoken. */}
              <Patch shot={sc.shadow} from={patches[0][0]} to={patches[0][1]} height={patches[0][2]} z={cam.z} opacity={1 - partnerShown} />
              <Patch shot={sc.shadow} from={patches[1][0]} to={patches[1][1]} height={patches[1][2]} z={cam.z} opacity={1 - replyShown} />
            </Screen>
            <Screen shot={sc.stamp} t={t} at={stamp} until={mock} cam={cam}>
              <div style={{ position: 'absolute', inset: 0, background: '#FFE7A6', opacity: stampFlash, mixBlendMode: 'screen' }} />
            </Screen>
            {t >= stamp && t < mock + 0.5 ? (
              // The stamp itself, pressed down on the beat.
              <div
                style={{
                  position: 'absolute',
                  left: (603 - 300) * cam.z,
                  top: (ringY - 300) * cam.z,
                  width: 600 * cam.z,
                  height: 600 * cam.z,
                  overflow: 'hidden',
                  borderRadius: '50%',
                  transform: `scale(${stampScale})`,
                  opacity: t < stampHit ? 0 : 1,
                }}
              >
                <Img
                  src={staticFile(`next/${sc.stamp}.jpg`)}
                  style={{ position: 'absolute', left: -(603 - 300) * cam.z, top: -(ringY - 300) * cam.z, width: W * cam.z, height: H * cam.z }}
                />
              </div>
            ) : null}
            <Burst t={t} at={stampHit} x={603 * cam.z} y={ringY * cam.z} scale={cam.z} />
            {t >= mock ? <Screen shot={sc.mock} t={t} at={mock} cam={cam} /> : null}
          </Phone>
          </div>
        </div>
      ) : null}

      {/* 傻貓 peeking in: the cold open */}
      <Peek t={t} at={0} until={meet + 0.05} side={1} mood="smug" y={560} />
      {/* …jumping out, then moving into the phone */}
      {catOnScreen ? (
        <div
          style={{
            ...(moveIn > 0.5 ? ABOVE_CAPTIONS : {}),
            position: 'absolute',
            left: catX - todayShift * 0.3 * W * cam.z + fx * moveIn,
            top: catY + fy * moveIn,
            opacity: 1 - todayShift,
            transform: `scale(${2 - sy}, ${sy})`,
            transformOrigin: '50% 95%',
            filter: moveIn < 1 ? 'drop-shadow(0 26px 30px rgba(30,34,14,0.3))' : undefined,
          }}
        >
          <Mascot mood={moveIn < 1 ? 'cheeky' : 'idle'} size={catSize} sparkles={moveIn === 0 && jump > 0.6} next />
        </div>
      ) : null}
      {/* …and the cheeky peek from the other side */}
      <Peek t={t} at={mock + 0.05} until={end + 0.1} side={-1} mood="cheeky" y={520} />

      {/* The date, stamped in the corner of the cold open so the cover says it */}
      {t < meet + 0.3 ? (
        <div style={{ position: 'absolute', left: 70, top: 250, transform: 'rotate(-7deg)', opacity: interpolate(t, [meet, meet + 0.3], [1, 0], clamp) }}>
          <div style={{ background: '#FBF6EA', padding: '14px 18px', borderRadius: 6, boxShadow: '0 12px 26px rgba(30,34,14,0.28)' }}>
            <div style={{ filter: 'url(#ink)', border: `7px solid ${CLAY}`, borderRadius: 20, padding: '2px 26px 8px', color: CLAY, fontFamily: SERIF, fontWeight: 800, fontSize: 92, lineHeight: 1 }}>
              {episode.launch}
            </div>
          </div>
          <Tape width={50} angle={-20} style={{ left: -20, top: -22 }} />
        </div>
      ) : null}

      {lines.map((line, i) => (
        <Caption key={i} text={line.text} start={timing.slots[i].start} length={timing.slots[i].length} t={t} first={i === 0} label={episode.label ?? '傻貓 SillyCat'} top={CAPTION_TOP} size={62} glass />
      ))}

      {/* The end card: the new icon, the name, the date */}
      {endIn > 0 ? (
        <AbsoluteFill style={{ clipPath: `circle(${endIn * 1300}px at 140px 800px)` }}>
          <Backdrop t={t} frame={frame} />
          <AbsoluteFill style={{ alignItems: 'center', paddingTop: 300 }}>
            <div style={{ transform: `rotate(-3deg) scale(${iconPop})`, position: 'relative' }}>
              <Img
                src={staticFile('icon-next.png')}
                style={{ width: 360, height: 360, borderRadius: 80, display: 'block', boxShadow: '0 34px 70px rgba(30,34,18,0.42), 0 8px 18px rgba(30,34,18,0.28)' }}
              />
              <Sheen t={t} at={end + 0.75} radius={80} />
              <Tape width={56} angle={-36} style={{ left: -40, top: 12 }} />
            </div>
            <div
              style={{
                marginTop: 46,
                display: 'flex',
                alignItems: 'baseline',
                gap: 22,
                color: '#FFF8EC',
                textShadow: '0 4px 18px rgba(30,34,18,0.35)',
                opacity: interpolate(t, [end + 0.25, end + 0.55], [0, 1], clamp),
                transform: `translateY(${interpolate(t, [end + 0.25, end + 0.55], [18, 0], { ...clamp, easing: out })}px)`,
              }}
            >
              <span style={{ fontFamily: SERIF, fontWeight: 800, fontSize: 104, letterSpacing: '0.01em' }}>{(episode.app ?? '').split(' ')[0]}</span>
              {(episode.app ?? '').includes(' ') ? (
                <span style={{ fontWeight: 900, fontSize: 92, letterSpacing: '0.06em' }}>{(episode.app ?? '').split(' ').slice(1).join(' ')}</span>
              ) : null}
            </div>
          </AbsoluteFill>
          <DateStamp t={t} at={end + 0.05} text={episode.launch ?? ''} />
          <div
            style={{
              position: 'absolute',
              left: 0,
              right: 0,
              top: 1250,
              textAlign: 'center',
              display: 'flex',
              justifyContent: 'center',
              opacity: interpolate(t, [end + 0.5, end + 0.8], [0, 1], clamp),
            }}
          >
            <div style={{ color: '#FFF8EC', fontWeight: 800, fontSize: 40, letterSpacing: '0.12em', padding: '8px 30px', borderRadius: 999, border: '2px solid rgba(255,248,236,0.55)' }}>
              {episode.outroNote}
            </div>
          </div>
          <div
            style={{
              position: 'absolute',
              left: 90,
              right: 90,
              top: 1340,
              display: 'flex',
              justifyContent: 'center',
              opacity: interpolate(t, [end + 1.5, end + 1.8], [0, 1], clamp),
              transform: `translateY(${interpolate(t, [end + 1.5, end + 1.8], [16, 0], { ...clamp, easing: out })}px)`,
            }}
          >
            <div
              style={{
                background: 'linear-gradient(180deg, rgba(46,42,34,0.9), rgba(30,28,22,0.94))',
                border: '1.5px solid rgba(255,250,235,0.14)',
                color: '#FFF8EE',
                fontWeight: 900,
                fontSize: 52,
                padding: '20px 40px',
                borderRadius: 28,
                textAlign: 'center',
                textWrap: 'balance',
                boxShadow: 'inset 0 1.5px 0 rgba(255,250,235,0.12), 0 20px 46px rgba(20,24,10,0.34)',
              }}
            >
              {episode.outro}
            </div>
          </div>
        </AbsoluteFill>
      ) : null}
      <Grade frame={frame} />
    </AbsoluteFill>
  );
};
