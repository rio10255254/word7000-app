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
const OLIVE_LIGHT = '#A9B583';
const OLIVE = '#869661';
const OLIVE_DARK = '#5F6B40';
const CLAY = '#C96442';
const INK = '#2B2620';

/** Where 傻貓 sits on Today's word card, as the app draws it. */
const CAT_BOX = { left: 905, top: 476, size: 228 };
const FULL: Cam = { x: 603, y: 1250, z: 0.42 };
const PATH: Cam = { x: 603, y: 1420, z: 0.62 };
const CARD: Cam = { x: 603, y: 1150, z: 0.56 };
const EXAM: Cam = { x: 603, y: 1150, z: 0.62 };
const SHADOW: Cam = { x: 603, y: 1700, z: 0.86 };
const STAMP: Cam = { x: 603, y: 1050, z: 0.6 };

type Slot = { start: number; length: number; voiceStart: number; voiceLength: number };

/** The olive desk the whole teaser sits on. */
const Olive = () => (
  <AbsoluteFill style={{ background: `radial-gradient(120% 80% at 50% 38%, ${OLIVE_LIGHT} 0%, ${OLIVE} 55%, ${OLIVE_DARK} 100%)` }}>
    <Paper kind="ivory" grain={0.35} style={{ inset: 0, background: 'transparent', mixBlendMode: 'multiply' }} />
  </AbsoluteFill>
);

/** A phone at camera `cam`, showing `children` (screens) inside its glass. */
const Phone = ({ cam, children, dim = 0, lift = 0 }: { cam: Cam; children: ReactNode; dim?: number; lift?: number }) => {
  const left = STAGE.x - cam.x * cam.z;
  const top = STAGE.y - cam.y * cam.z + lift;
  const bezel = 46;
  return (
    <div style={{ position: 'absolute', left, top, width: W * cam.z, height: H * cam.z, filter: dim ? `brightness(${1 - dim})` : undefined }}>
      <div
        style={{
          position: 'absolute',
          inset: -bezel * cam.z,
          borderRadius: 210 * cam.z,
          background: '#1E1A17',
          boxShadow: `0 ${50 * cam.z}px ${120 * cam.z}px rgba(30,34,18,0.45)`,
        }}
      />
      <div style={{ position: 'absolute', inset: 0, borderRadius: 165 * cam.z, overflow: 'hidden', background: '#F3EEE4' }}>{children}</div>
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
  return (
    <div style={{ position: 'absolute', inset: 0, transform: `translateX(${x * cam.z}px)`, filter: outP ? `brightness(${1 - 0.25 * outP})` : undefined }}>
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
const Patch = ({ from, to, height, z, opacity }: { from: number; to: number; height: number; z: number; opacity: number }) =>
  opacity <= 0 ? null : (
    <div style={{ position: 'absolute', left: 0, right: 0, top: to * z, height: height * z, overflow: 'hidden', opacity }}>
      <Img src={staticFile('next/n8-shadow.jpg')} style={{ position: 'absolute', left: 0, top: -from * z, width: W * z, height: H * z }} />
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
    <div style={{ position: 'absolute', left: x, top: y, transform: `rotate(${side * -16}deg)`, transformOrigin: side > 0 ? '100% 60%' : '0% 60%' }}>
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
          border: `10px solid ${CLAY}`,
          borderRadius: 34,
          padding: '6px 46px 14px',
          color: CLAY,
          fontFamily: SERIF,
          fontWeight: 800,
          fontSize: 170,
          letterSpacing: '0.02em',
          lineHeight: 1,
          background: 'rgba(255,248,238,0.18)',
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
    app?: string;
    outroNote?: string;
    outro?: string;
  };
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
      [speak + 0.5, SHADOW],
      [stamp - 0.1, { ...SHADOW, z: 0.9 }],
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

  return (
    <AbsoluteFill style={{ fontFamily: FONT, overflow: 'hidden', transform: `translateX(${shake}px)` }}>
      <Html5Audio src={staticFile(`reels/${id}.mp3`)} />
      <Olive />

      {phoneShown ? (
        <div style={{ position: 'absolute', inset: 0, filter: back ? `blur(${back * 7}px)` : undefined, opacity: 1 - 0.25 * back }}>
          <Phone cam={cam} lift={(1 - phoneIn) * 1500}>
            <Screen shot="n1-today" t={t} at={0} until={toCard} cam={cam} />
            <Screen shot="n2-card" t={t} at={toCard} until={toWrite} cam={cam} />
            <Screen shot="n3-write-solved" t={t} at={toWrite} until={toExam} cam={cam} />
            <Screen shot="n4-exam-answered" t={t} at={toExam} until={speak} cam={cam} />
            <Screen shot="n8-shadow" t={t} at={speak} until={stamp} cam={cam}>
              {/* The server's line, then the learner's reply, as they are spoken. */}
              <Patch from={700} to={1240} height={300} z={cam.z} opacity={1 - partnerShown} />
              <Patch from={620} to={1545} height={330} z={cam.z} opacity={1 - replyShown} />
            </Screen>
            <Screen shot="n11-stamp" t={t} at={stamp} until={mock} cam={cam}>
              <div style={{ position: 'absolute', inset: 0, background: '#FFE7A6', opacity: stampFlash, mixBlendMode: 'screen' }} />
            </Screen>
            {t >= stamp && t < mock + 0.5 ? (
              // The stamp itself, pressed down on the beat.
              <div
                style={{
                  position: 'absolute',
                  left: (603 - 300) * cam.z,
                  top: (1120 - 300) * cam.z,
                  width: 600 * cam.z,
                  height: 600 * cam.z,
                  overflow: 'hidden',
                  borderRadius: '50%',
                  transform: `scale(${stampScale})`,
                  opacity: t < stampHit ? 0 : 1,
                }}
              >
                <Img
                  src={staticFile('next/n11-stamp.jpg')}
                  style={{ position: 'absolute', left: -(603 - 300) * cam.z, top: -(1120 - 300) * cam.z, width: W * cam.z, height: H * cam.z }}
                />
              </div>
            ) : null}
            {t >= mock ? <Screen shot="n4-exam" t={t} at={mock} cam={cam} /> : null}
          </Phone>
        </div>
      ) : null}

      {/* 傻貓 peeking in: the cold open */}
      <Peek t={t} at={0} until={meet + 0.05} side={1} mood="smug" y={560} />
      {/* …jumping out, then moving into the phone */}
      {catOnScreen ? (
        <div style={{ position: 'absolute', left: catX - todayShift * 0.3 * W * cam.z, top: catY, opacity: 1 - todayShift }}>
          <Mascot mood={moveIn < 1 ? 'cheeky' : 'idle'} size={catSize} sparkles={moveIn === 0 && jump > 0.6} next />
        </div>
      ) : null}
      {/* …and the cheeky peek from the other side */}
      <Peek t={t} at={mock + 0.05} until={end + 0.1} side={-1} mood="cheeky" y={520} />

      {/* The date, stamped in the corner of the cold open so the cover says it */}
      {t < meet + 0.3 ? (
        <div style={{ position: 'absolute', left: 70, top: 250, transform: 'rotate(-7deg)', opacity: interpolate(t, [meet, meet + 0.3], [1, 0], clamp) }}>
          <div style={{ border: `7px solid ${CLAY}`, borderRadius: 22, padding: '2px 26px 8px', color: CLAY, fontFamily: SERIF, fontWeight: 800, fontSize: 96, lineHeight: 1, background: 'rgba(255,248,238,0.85)' }}>
            {episode.launch}
          </div>
          <Tape width={50} angle={-20} style={{ left: -20, top: -22 }} />
        </div>
      ) : null}

      {lines.map((line, i) => (
        <Caption key={i} text={line.text} start={timing.slots[i].start} length={timing.slots[i].length} t={t} first={i === 0} label="傻貓 SillyCat" />
      ))}

      {/* The end card: the new icon, the name, the date */}
      {endIn > 0 ? (
        <AbsoluteFill style={{ clipPath: `circle(${endIn * 1300}px at 140px 800px)` }}>
          <Olive />
          <AbsoluteFill style={{ alignItems: 'center', paddingTop: 300 }}>
            <div style={{ transform: `rotate(-3deg) scale(${iconPop})`, position: 'relative' }}>
              <Img src={staticFile('icon-next.png')} style={{ width: 360, height: 360, borderRadius: 80, display: 'block', boxShadow: '0 26px 60px rgba(30,34,18,0.4)' }} />
              <Tape width={56} angle={-36} style={{ left: -40, top: 12 }} />
            </div>
            <div style={{ marginTop: 44, color: '#FFF8EC', fontWeight: 900, fontSize: 104, letterSpacing: '0.03em', textShadow: '0 4px 18px rgba(30,34,18,0.35)' }}>
              {episode.app}
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
              color: '#FFF8EC',
              fontWeight: 800,
              fontSize: 44,
              letterSpacing: '0.08em',
              opacity: interpolate(t, [end + 0.5, end + 0.8], [0, 1], clamp),
            }}
          >
            {episode.outroNote}
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
            <div style={{ background: INK, color: '#FFF8EE', fontWeight: 900, fontSize: 52, padding: '20px 40px', borderRadius: 24, boxShadow: '0 14px 34px rgba(30,34,18,0.35)' }}>
              {episode.outro}
            </div>
          </div>
        </AbsoluteFill>
      ) : null}
    </AbsoluteFill>
  );
};
