import type { CSSProperties, ReactNode } from 'react';
import { AbsoluteFill, Easing, Html5Audio, Img, interpolate, spring, staticFile, useCurrentFrame } from 'remotion';
import { FONT } from '../fonts';
import { Mascot, type Mood } from '../Mascot';
import { COLLAGE, Desk, K, Paper, Tape, torn } from '../collage';
import { C, clamp } from '../kit';
import script from './episodes.json';
import timings from './timing.json';

/**
 * One IG reel: 小笨貓 talks, a real screen from the app is slapped onto
 * the desk for each line, and every episode ends on the same card with
 * the same three-note sound logo. Timing comes from scripts/make-reels.py,
 * which laid the slots out from the spoken lines.
 *
 * Instagram covers the top ~220 px (header) and the bottom ~380 px (caption,
 * buttons), plus the right-hand column of buttons; everything that matters
 * stays clear of them.
 */
export const REEL_FPS = 60;

type Line = {
  text: string;
  shot?: string;
  crop?: number[];
  tap?: number[];
  sfx?: string;
  mood?: string;
};
type Episode = { id: string; series: string; hook: string[]; lines: Line[] };
type Slot = { start: number; length: number; voiceStart: number; voiceLength: number };
type Timing = { total: number; end: number; slots: Slot[] };

export const EPISODES = script.episodes as Episode[];
const timingOf = (id: string) => (timings as Record<string, Timing>)[id];
export const reelFrames = (id: string) => Math.round(timingOf(id).total * REEL_FPS);

const useSeconds = () => useCurrentFrame() / REEL_FPS;
const ease = Easing.bezier(0.16, 1, 0.3, 1);

/** Where the screens sit: centred, under the hook, above the cat. */
const CARD = { top: 575, maxWidth: 960, maxHeight: 690 };
/** The cat and its line, above Instagram's caption. */
const TALK_TOP = 1300;

/** A piece of paper slapped onto the desk at `at` seconds. */
const slap = (t: number, at: number) => {
  const p = interpolate(t, [at, at + 0.2], [0, 1], { ...clamp, easing: Easing.in(Easing.quad) });
  return { opacity: Math.min(1, p * 3), scale: 1.12 - 0.12 * p, tilt: (1 - p) * 4 };
};

const Hook = ({ lines, t, end }: { lines: string[]; t: number; end: number }) => {
  // Already on the first frame (it is the reel's cover), with a small settle.
  const settle = interpolate(t, [0, 0.35], [1.06, 1], { ...clamp, easing: ease });
  const out = interpolate(t, [end - 0.3, end], [1, 0], clamp);
  const width = 960;
  const height = 300;
  return (
    <div style={{ position: 'absolute', left: (1080 - width) / 2, top: 236, width, height, opacity: out, transform: `rotate(-1.5deg) scale(${settle})` }}>
      <Paper kind="peach" style={{ inset: 0, clipPath: torn(width, height, ['top', 'bottom'], 3, 5) }} />
      <Tape width={70} angle={-8} style={{ left: 20, top: -18 }} />
      <Tape width={70} angle={6} style={{ right: 24, top: -14 }} />
      <div
        style={{
          position: 'absolute',
          inset: 0,
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
          justifyContent: 'center',
          color: C.ink,
          fontWeight: 900,
          fontSize: 92,
          lineHeight: 1.18,
          letterSpacing: '0.02em',
        }}
      >
        {lines.map((line, i) => (
          <div key={i} style={i === 1 ? { color: COLLAGE.clay } : undefined}>
            {line}
          </div>
        ))}
      </div>
    </div>
  );
};

/** A real screen from the app, cropped to what the line is about, taped to the desk. */
const Shot = ({ line, slot, t, seed }: { line: Line; slot: Slot; t: number; seed: number }) => {
  const [x0, y0, x1, y1] = line.crop ?? [0, 0, 1206, 2622];
  const scale = Math.min(CARD.maxWidth / (x1 - x0), CARD.maxHeight / (y1 - y0));
  const w = (x1 - x0) * scale;
  const h = (y1 - y0) * scale;
  const s = slap(t, slot.start);
  const angle = ((seed * 7) % 5) - 2;
  const push = interpolate(t, [slot.start, slot.start + slot.length], [1, 1.035], clamp);
  const shake = line.sfx === 'wrong' ? Math.sin((t - slot.start) * 70) * 14 * interpolate(t, [slot.start + 0.1, slot.start + 0.5], [1, 0], clamp) : 0;
  const tapAge = t - slot.start - 0.05;
  return (
    <div
      style={{
        position: 'absolute',
        left: (1080 - w) / 2 + shake,
        top: CARD.top + (CARD.maxHeight - h) / 2,
        width: w,
        height: h,
        opacity: s.opacity,
        transform: `rotate(${angle - s.tilt}deg) scale(${s.scale * push})`,
      }}
    >
      <div style={{ position: 'absolute', inset: -14, background: '#FFFDF8', boxShadow: '0 18px 40px rgba(43,38,32,0.16)' }} />
      <div style={{ position: 'absolute', inset: 0, overflow: 'hidden' }}>
        <Img
          src={staticFile(`shots/${line.shot}.jpg`)}
          style={{ position: 'absolute', left: -x0 * scale, top: -y0 * scale, width: 1206 * scale, height: 2622 * scale }}
        />
        {line.tap && tapAge > 0 && tapAge < 0.7 ? (
          <div
            style={{
              position: 'absolute',
              left: (line.tap[0] - x0) * scale,
              top: (line.tap[1] - y0) * scale,
              width: 0,
              height: 0,
            }}
          >
            <div
              style={{
                position: 'absolute',
                width: 150,
                height: 150,
                left: -75,
                top: -75,
                borderRadius: '50%',
                border: `8px solid ${COLLAGE.clay}`,
                transform: `scale(${0.3 + tapAge * 1.6})`,
                opacity: interpolate(tapAge, [0, 0.7], [0.9, 0], clamp),
              }}
            />
            <div
              style={{
                position: 'absolute',
                width: 70,
                height: 70,
                left: -35,
                top: -35,
                borderRadius: '50%',
                background: 'rgba(201,100,66,0.45)',
                opacity: interpolate(tapAge, [0, 0.15, 0.5], [0, 1, 0], clamp),
              }}
            />
          </div>
        ) : null}
      </div>
      <Tape width={60} angle={-34} style={{ left: -44, top: 4 }} />
      <Tape width={60} angle={30} style={{ right: -44, top: 6 }} />
    </div>
  );
};

/** A line without a screen: the cat itself, big, in the middle of the desk. */
const BigCat = ({ line, slot, t }: { line: Line; slot: Slot; t: number }) => {
  const pop = slot.start === 0 ? 1 : spring({ frame: (t - slot.start) * REEL_FPS, fps: REEL_FPS, config: { damping: 11, stiffness: 140, mass: 0.8 } });
  const talking = t > slot.voiceStart && t < slot.voiceStart + slot.voiceLength;
  const bob = talking ? Math.abs(Math.sin((t - slot.voiceStart) * 9)) * 14 : 0;
  return (
    <div style={{ position: 'absolute', left: 0, right: 0, top: CARD.top - 20, display: 'flex', justifyContent: 'center' }}>
      <div style={{ transform: `translateY(${-bob}px) scale(${pop})`, transformOrigin: '50% 90%' }}>
        <Mascot mood={(line.mood as Mood) ?? 'happy'} size={600} sparkles={line.mood === 'happy'} />
      </div>
    </div>
  );
};

/** The line being said, typed out as fast as the cat says it. */
const Said = ({ text, slot, t }: { text: string; slot: Slot; t: number }) => {
  const chars = Array.from(text);
  const shown = Math.ceil(interpolate(t, [slot.voiceStart, slot.voiceStart + slot.voiceLength * 0.92], [0, chars.length], clamp));
  return (
    <>
      {chars.map((c, i) => (
        <span key={i} style={{ opacity: i < shown ? 1 : 0 }}>
          {c}
        </span>
      ))}
    </>
  );
};

const Talk = ({ line, slot, t, big }: { line: Line; slot: Slot; t: number; big: boolean }) => {
  const appear = interpolate(t, [slot.start, slot.start + 0.15], [0, 1], { ...clamp, easing: ease });
  const talking = t > slot.voiceStart && t < slot.voiceStart + slot.voiceLength;
  const bob = talking ? Math.abs(Math.sin((t - slot.voiceStart) * 9)) * 8 : 0;
  const bubble: CSSProperties = {
    background: '#FFFAF0',
    color: '#3B2619',
    fontWeight: 900,
    fontSize: 58,
    lineHeight: 1.32,
    padding: '26px 38px',
    borderRadius: 40,
    boxShadow: '0 14px 36px rgba(59,38,25,0.18)',
    opacity: appear,
    transform: `scale(${0.96 + 0.04 * appear})`,
  };
  if (big) {
    return (
      <div style={{ position: 'absolute', left: 70, right: 70, top: TALK_TOP + 40, display: 'flex', justifyContent: 'center' }}>
        <div style={{ ...bubble, textAlign: 'center', maxWidth: 900 }}>
          <Said text={line.text} slot={slot} t={t} />
        </div>
      </div>
    );
  }
  return (
    <div style={{ position: 'absolute', left: 40, top: TALK_TOP, width: 920, display: 'flex', alignItems: 'center', gap: 10 }}>
      <div style={{ flex: 'none', transform: `translateY(${-bob}px)` }}>
        <Mascot mood={(line.mood as Mood) ?? 'idle'} size={230} />
      </div>
      <div style={{ position: 'relative', ...bubble, flex: 1 }}>
        <div
          style={{
            position: 'absolute',
            left: -26,
            top: '50%',
            marginTop: -20,
            width: 0,
            height: 0,
            borderStyle: 'solid',
            borderWidth: '20px 28px 20px 0',
            borderColor: 'transparent #FFFAF0 transparent transparent',
          }}
        />
        <Said text={line.text} slot={slot} t={t} />
      </div>
    </div>
  );
};

/** Every episode ends here, on the same three notes. */
const EndCard = ({ start, t, series }: { start: number; t: number; series: string }) => {
  const s = slap(t, start);
  const line = interpolate(t, [start + 0.5, start + 0.8], [0, 1], { ...clamp, easing: ease });
  if (t < start) return null;
  return (
    <AbsoluteFill style={{ opacity: s.opacity }}>
      <Desk kind="peach" />
      <AbsoluteFill style={{ alignItems: 'center', paddingTop: 380, color: C.ink, transform: `scale(${s.scale})` }}>
        <div style={{ position: 'relative', transform: `rotate(${-3 - s.tilt}deg)` }}>
          <Img src={staticFile('icon-collage.png')} style={{ width: 400, height: 400, display: 'block', borderRadius: 88, boxShadow: '0 22px 50px rgba(43,38,32,0.25)' }} />
          <Tape width={56} angle={-38} style={{ left: -46, top: 14 }} />
        </div>
        <div style={{ fontWeight: 900, fontSize: 150, letterSpacing: '0.05em', marginTop: 50 }}>單字貓</div>
        <div style={{ fontWeight: 900, fontSize: 56, marginTop: 24, color: COLLAGE.clay, opacity: line, transform: `translateY(${(1 - line) * 16}px)` }}>
          {script.outro}
        </div>
        <div style={{ fontWeight: 700, fontSize: 40, marginTop: 22, color: C.inkSoft, opacity: line }}>{script.outroNote}</div>
      </AbsoluteFill>
      <div style={{ position: 'absolute', left: 0, right: 0, top: 250, textAlign: 'center', fontWeight: 700, fontSize: 30, letterSpacing: '0.12em', color: C.inkSoft }}>
        {series}
      </div>
    </AbsoluteFill>
  );
};

export const Reel = ({ id }: { id: string }) => {
  const t = useSeconds();
  const episode = EPISODES.find((e) => e.id === id)!;
  const timing = timingOf(id);
  let current = 0;
  timing.slots.forEach((slot, i) => {
    if (t >= slot.start) current = i;
  });
  const children: ReactNode[] = [];
  // Each screen stays under the next one until that one has landed.
  timing.slots.forEach((slot, i) => {
    const line = episode.lines[i];
    if (i < current - 1 || i > current || t >= timing.end + 0.25 || !line.shot) return;
    // A big cat clears the desk.
    if (i === current - 1 && !episode.lines[current].shot && t > timing.slots[current].start + 0.2) return;
    children.push(<Shot key={i} line={line} slot={slot} t={t} seed={i + 1} />);
  });
  const line = episode.lines[current];
  const slot = timing.slots[current];
  const big = !line.shot;
  return (
    <AbsoluteFill style={{ fontFamily: FONT, overflow: 'hidden' }}>
      <Html5Audio src={staticFile(`reels/${id}.mp3`)} />
      <Desk kind="desk" />
      {t < timing.end ? (
        <>
          <Hook lines={episode.hook} t={t} end={timing.end} />
          {children}
          {big ? <BigCat line={line} slot={slot} t={t} /> : null}
          <Talk line={line} slot={slot} t={t} big={big} />
        </>
      ) : null}
      <EndCard start={timing.end} t={t} series={episode.series} />
    </AbsoluteFill>
  );
};
