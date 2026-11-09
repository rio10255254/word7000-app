import { AbsoluteFill, Easing, Html5Audio, Img, interpolate, staticFile, useCurrentFrame } from 'remotion';
import { FONT, SERIF, SERIF_TC } from '../fonts';
import { Mascot, type Mood } from '../Mascot';
import { Paper, Tape } from '../collage';
import { clamp } from '../kit';
import script from './episodes.json';
import timings from './timing.json';
import { REEL_FPS } from './Reel';
import { Caption, inOut, out } from './Intro';
import { CAPTION_TOP, Peek } from './Teaser';
import { CountdownEnd, DaysStamp, StampCard } from './Countdown';
import { Backdrop, Grade, InkFilters, Motes } from './finish';

/**
 * "One path a day", filmed from above: a dotted path draws itself across
 * the desk, 傻貓 hops along it, and at each stop that step of the day is
 * slapped down like a polaroid (cards, writing, a quiz, speaking), each
 * as the cat names it. At the end of the path the day is stamped done.
 */
const CLAY = '#C96442';
const INK = '#2B2620';
const BEAT = 0.5;

type Slot = { start: number; length: number };
type Episode = {
  id: string;
  days: number;
  app: string;
  label: string;
  dayWords: [string, string];
  note: string;
  outro: string;
  done: string;
  stops: [string, string, number][];
  draw: [number, number, number];
  hops: [number, number][];
  finish: [number, number];
  stampAt: [number, number];
  cheekyAt: [number, number];
  lines: { text: string }[];
};

/** The four polaroids, alternating sides down the desk, and where the cat sits on each. */
const CARDS = [
  { left: 90, top: 300, tilt: -4 },
  { left: 650, top: 440, tilt: 3 },
  { left: 90, top: 800, tilt: 2.5 },
  { left: 650, top: 950, tilt: -3 },
];
const CARD_W = 340;
const CARD_H = 420;
const START = { x: 930, y: 320 };
const SITS = [
  { x: 350, y: 306 },
  { x: 730, y: 446 },
  { x: 350, y: 806 },
  { x: 730, y: 954 },
];
const FINISH_CARD = { left: 150, top: 1080, width: 780, height: 280 };
const FIN = { x: 820, y: 1088 };
const CAT = 190;

/** A smooth path through the points (Catmull-Rom as cubic Béziers). */
const smooth = (pts: { x: number; y: number }[]) => {
  let d = `M ${pts[0].x} ${pts[0].y}`;
  for (let i = 0; i < pts.length - 1; i++) {
    const p0 = pts[Math.max(0, i - 1)];
    const p1 = pts[i];
    const p2 = pts[i + 1];
    const p3 = pts[Math.min(pts.length - 1, i + 2)];
    d += ` C ${p1.x + (p2.x - p0.x) / 6} ${p1.y + (p2.y - p0.y) / 6}, ${p2.x - (p3.x - p1.x) / 6} ${p2.y - (p3.y - p1.y) / 6}, ${p2.x} ${p2.y}`;
  }
  return d;
};

/** A polaroid of one step, slapped down at `at`. */
const Polaroid = ({ t, at, index, shot, label, cropTop, dim }: { t: number; at: number; index: number; shot: string; label: string; cropTop: number; dim: number }) => {
  if (t < at) return null;
  const c = CARDS[index];
  const p = interpolate(t, [at, at + 0.18], [0, 1], { ...clamp, easing: Easing.in(Easing.quad) });
  // Big for a moment, so it can be read, then it settles into its place on the path.
  const settle = interpolate(t, [at + 0.5, at + 1.0], [0, 1], { ...clamp, easing: inOut });
  const big = 1.32 - 0.32 * settle;
  const towardCentre = (1 - settle) * 0.35;
  const imgW = CARD_W - 36;
  const imgH = CARD_H - 36 - 64;
  const scale = imgW / 1126;
  return (
    <div
      style={{
        position: 'absolute',
        left: c.left,
        top: c.top,
        width: CARD_W,
        height: CARD_H,
        opacity: Math.min(1, p * 3),
        transform: `translate(${(540 - (c.left + CARD_W / 2)) * towardCentre}px, ${(760 - (c.top + CARD_H / 2)) * towardCentre}px) rotate(${c.tilt * settle - (1 - p) * 5}deg) scale(${big * (1.12 - 0.12 * p)})`,
        zIndex: settle < 1 ? 5 : 1,
        filter: `drop-shadow(0 22px 26px rgba(30,34,14,0.3)) drop-shadow(0 3px 6px rgba(30,34,14,0.2)) brightness(${1 - 0.2 * dim})`,
      }}
    >
      <Paper kind="ivory" grain={0.5} style={{ inset: 0, background: '#FDFBF6' }} />
      <div style={{ position: 'absolute', left: 18, top: 18, width: imgW, height: imgH, overflow: 'hidden', background: '#F3EEE4' }}>
        <Img src={staticFile(`next/${shot}.jpg`)} style={{ position: 'absolute', left: -40 * scale, top: -cropTop * scale, width: 1206 * scale, height: 2622 * scale }} />
      </div>
      <div style={{ position: 'absolute', left: 0, right: 0, bottom: 14, height: 54, display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 14 }}>
        <div style={{ width: 42, height: 42, borderRadius: 21, background: CLAY, color: '#FFF6EA', display: 'flex', alignItems: 'center', justifyContent: 'center', fontFamily: SERIF, fontWeight: 800, fontSize: 26 }}>
          {index + 1}
        </div>
        <div style={{ fontFamily: FONT, fontWeight: 900, fontSize: 38, color: INK }}>{label}</div>
      </div>
      <Tape width={50} angle={index % 2 ? 12 : -12} style={{ left: index % 2 ? 'auto' : -30, right: index % 2 ? -30 : 'auto', top: -10 }} />
    </div>
  );
};

export const PathDay = ({ id }: { id: string }) => {
  const t = useCurrentFrame() / REEL_FPS;
  const frame = useCurrentFrame();
  const episode = script.episodes.find((e) => e.id === id)! as unknown as Episode;
  const timing = (timings as Record<string, { total: number; end: number; slots: Slot[] }>)[id];
  const starts = timing.slots.map((s) => s.start);
  const at = (slot: number, beat: number) => starts[slot] + beat * BEAT;
  const show = starts[1];
  const end = timing.end;

  // Where the cat hops: from the start, onto each card as it is named, then onto the finished day.
  const points = [START, ...SITS, FIN];
  const lands = [...episode.hops.map(([s, b]) => at(s, b)), at(...episode.finish)];
  const hop = 0.38;
  let cat = points[0];
  let squash = 1;
  let rising = 0;
  for (let i = 0; i < lands.length; i++) {
    const from = points[i];
    const to = points[i + 1];
    const land = lands[i];
    if (t >= land - hop && t < land) {
      const p = inOut((t - (land - hop)) / hop);
      cat = { x: from.x + (to.x - from.x) * p, y: from.y + (to.y - from.y) * p - Math.sin(Math.PI * p) * 150 };
      rising = 1;
      break;
    }
    if (t >= land) {
      cat = to;
      const since = t - land;
      squash = interpolate(since, [0, 0.07, 0.2, 0.32], [0.82, 0.84, 1.06, 1], clamp);
    }
  }
  const stampT = at(...episode.stampAt);
  const cheeky = at(...episode.cheekyAt);
  const mood: Mood = t >= cheeky ? 'cheeky' : t >= stampT ? 'happy' : rising ? 'smug' : 'idle';
  const catIn = interpolate(t, [show, show + 0.3], [0, 1], { ...clamp, easing: Easing.out(Easing.back(1.8)) });
  const leave = interpolate(t, [end - 0.2, end + 0.25], [0, 1], { ...clamp, easing: inOut });

  // The path draws itself as the cat says it has laid one out.
  const [ds, db0, db1] = episode.draw;
  const drawn = interpolate(t, [at(ds, db0), at(ds, db1)], [0, 1], { ...clamp, easing: inOut });
  const path = smooth(points);

  const coverOut = interpolate(t, [show - 0.1, show + 0.25], [0, 1], { ...clamp, easing: inOut });
  const finishCard = interpolate(t, [stampT - 0.4, stampT - 0.22], [0, 1], { ...clamp, easing: Easing.in(Easing.quad) });
  const press = interpolate(t, [stampT - 0.13, stampT], [0, 1], { ...clamp, easing: Easing.in(Easing.cubic) });
  const knock = t > stampT && t < stampT + 0.25 ? Math.sin((t - stampT) * 80) * 6 * (1 - (t - stampT) / 0.25) : 0;
  const stamp = <DaysStamp days={episode.days} words={episode.dayWords} note={episode.note} />;
  // A slow drift over the desk, following the cat down.
  const driftY = interpolate(t, [show, end], [0, -40], clamp);

  return (
    <AbsoluteFill style={{ fontFamily: FONT, overflow: 'hidden' }}>
      <Html5Audio src={staticFile(`reels/${id}.mp3`)} />
      <InkFilters />
      <Backdrop t={t} frame={frame} drift={driftY} />
      <Motes t={t} />

      {coverOut < 1 ? (
        <div style={{ position: 'absolute', inset: 0, opacity: 1 - coverOut, transform: `translateY(${-coverOut * 120}px)` }}>
          <StampCard t={t} at={0} stampAt={0} top={300}>
            {stamp}
          </StampCard>
        </div>
      ) : null}
      <Peek t={t} at={0} until={show + 0.05} side={1} mood="smug" y={760} outAt={show - 0.25} />

      {t >= show && t < end + 0.3 ? (
        <AbsoluteFill style={{ opacity: 1 - leave, filter: leave ? `blur(${leave * 8}px)` : undefined, transform: `translate(${knock}px, ${driftY + knock * 0.4}px) scale(${1 - 0.06 * leave})` }}>
          {/* The path, dotted, drawing itself from the start to the finish. */}
          <svg style={{ position: 'absolute', inset: 0, overflow: 'visible' }} width={1080} height={1920}>
            <defs>
              <mask id={`reveal-${id}`}>
                <path d={path} fill="none" stroke="#fff" strokeWidth={40} strokeLinecap="round" pathLength={1000} strokeDasharray={1000} strokeDashoffset={1000 * (1 - drawn)} />
              </mask>
            </defs>
            <path d={path} fill="none" stroke="rgba(40,46,20,0.18)" strokeWidth={14} strokeLinecap="round" strokeDasharray="0.1 30" transform="translate(0 4)" mask={`url(#reveal-${id})`} />
            <path d={path} fill="none" stroke="#FFF6E0" strokeWidth={14} strokeLinecap="round" strokeDasharray="0.1 30" mask={`url(#reveal-${id})`} />
          </svg>

          {episode.stops.map(([shot, label, cropTop], i) => (
            <Polaroid key={i} t={t} at={lands[i] - 0.12} index={i} shot={shot} label={label} cropTop={cropTop} dim={finishCard} />
          ))}

          {/* The day, stamped done at the end of the path. */}
          {finishCard > 0 ? (
            <div
              style={{
                position: 'absolute',
                ...FINISH_CARD,
                zIndex: 6,
                opacity: Math.min(1, finishCard * 3),
                transform: `rotate(${-3 - (1 - finishCard) * 5}deg) scale(${1.15 - 0.15 * finishCard})`,
                filter: 'drop-shadow(0 26px 32px rgba(30,34,14,0.32)) drop-shadow(0 4px 8px rgba(30,34,14,0.2))',
              }}
            >
              <Paper kind="ivory" grain={0.7} style={{ inset: 0, background: '#FBF6EA' }} />
              <Tape width={60} angle={-8} style={{ left: 40, top: -18 }} />
              <div
                style={{
                  position: 'absolute',
                  inset: 0,
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  opacity: press,
                  transform: `rotate(-5deg) scale(${t < stampT ? 1.8 - 0.85 * press : interpolate(t, [stampT, stampT + 0.2], [0.95, 1], { ...clamp, easing: out })})`,
                }}
              >
                <div style={{ filter: 'url(#ink)', border: `9px solid ${CLAY}`, borderRadius: 30, padding: '14px 40px 18px', color: CLAY, display: 'flex', alignItems: 'center', gap: 22 }}>
                  <div style={{ width: 92, height: 92, borderRadius: 46, border: `8px solid ${CLAY}`, display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 60, fontWeight: 900 }}>✓</div>
                  <div style={{ fontFamily: episode.dayWords[0] ? SERIF_TC : SERIF, fontWeight: 900, fontSize: episode.dayWords[0] ? 80 : 72, lineHeight: 1, whiteSpace: 'nowrap' }}>{episode.done}</div>
                </div>
              </div>
            </div>
          ) : null}

          {/* 傻貓 on its way */}
          <div
            style={{
              position: 'absolute',
              left: cat.x - CAT / 2,
              top: cat.y - CAT * 0.94,
              transform: `scale(${catIn * (2 - squash)}, ${catIn * squash})`,
              transformOrigin: '50% 94%',
              zIndex: 7,
              filter: 'drop-shadow(0 16px 18px rgba(30,34,14,0.3))',
            }}
          >
            <Mascot mood={mood} size={CAT} next sparkles={t >= stampT && t < cheeky} />
          </div>
        </AbsoluteFill>
      ) : null}

      <Motes t={t} front />
      {episode.lines.map((line, i) => (
        <Caption key={i} text={line.text} start={timing.slots[i].start} length={timing.slots[i].length} t={t} first={i === 0} label={episode.label} top={CAPTION_TOP} size={62} glass />
      ))}

      <CountdownEnd t={t} end={end} episode={episode} stamp={stamp} />
      <Grade frame={frame} />
    </AbsoluteFill>
  );
};
