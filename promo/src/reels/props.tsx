import type { CSSProperties, ReactNode } from 'react';
import { Easing, interpolate } from 'remotion';
import { FONT, SERIF, SERIF_TC } from '../fonts';
import { Paper, Tape } from '../collage';
import { clamp } from '../kit';

/**
 * Things that come out of the phone in the countdown reels: the exam date
 * as a tear-off desk calendar flipping to the day, a counter tag, a
 * chapter track, a route. Each one flies out from the spot on the screen
 * it stands for (`from`, already in frame pixels) to its place above the
 * phone, and leaves at `until`.
 */
const CLAY = '#C96442';
const INK = '#2B2620';
const SAGE = '#6E8F5E';

type Flight = { t: number; at: number; until?: number; from: { x: number; y: number }; left: number; top: number; width: number; height: number; tilt: number };

/** Out of the phone with a little overshoot, and away again (up and off) at `until`. */
const Fly = ({ t, at, until, from, left, top, width, height, tilt, children }: Flight & { children: ReactNode }) => {
  if (t < at || (until !== undefined && t > until + 0.4)) return null;
  const p = interpolate(t, [at, at + 0.42], [0, 1], { ...clamp, easing: Easing.out(Easing.back(1.4)) });
  const q = until === undefined ? 0 : interpolate(t, [until, until + 0.35], [0, 1], { ...clamp, easing: Easing.in(Easing.cubic) });
  const cx = left + width / 2;
  const cy = top + height / 2;
  const dx = (from.x - cx) * (1 - p);
  const dy = (from.y - cy) * (1 - p) - q * 1100;
  return (
    <div
      style={{
        position: 'absolute',
        left,
        top,
        width,
        height,
        transform: `translate(${dx}px, ${dy}px) rotate(${tilt * p + q * 14}deg) scale(${0.12 + 0.88 * Math.min(p, 1.2)})`,
        opacity: Math.min(1, p * 4) * (1 - q * 0.6),
        filter: 'drop-shadow(0 24px 30px rgba(30,34,14,0.3)) drop-shadow(0 4px 8px rgba(30,34,14,0.2))',
      }}
    >
      {children}
    </div>
  );
};

/** A tag of cream paper, taped at the top. */
const Tag = ({ children, style }: { children: ReactNode; style?: CSSProperties }) => (
  <div style={{ position: 'absolute', inset: 0, ...style }}>
    <Paper kind="ivory" grain={0.7} style={{ inset: 0, background: '#FBF6EA', borderRadius: 6 }} />
    <Tape width={54} angle={-6} style={{ left: '50%', marginLeft: -27 * 2.69, top: -16 }} />
    <div style={{ position: 'absolute', inset: 0, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', color: INK, fontFamily: FONT }}>{children}</div>
  </div>
);

type Page = [string, string, string, string];

/** One page of a desk calendar: year and month on the clay band, the day big, the weekday. */
const CalendarPage = ({ page, tag }: { page: Page; tag?: string }) => (
  <div style={{ position: 'absolute', inset: 0, borderRadius: 18, overflow: 'hidden', background: '#FBF6EA' }}>
    <Paper kind="ivory" grain={0.7} style={{ inset: 0, background: '#FBF6EA' }} />
    <div style={{ position: 'absolute', left: 0, right: 0, top: 0, height: 120, background: CLAY, color: '#FFF6EA', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 18 }}>
      <span style={{ fontFamily: SERIF, fontWeight: 800, fontSize: 52 }}>{page[0]}</span>
      <span style={{ fontFamily: SERIF_TC, fontWeight: 900, fontSize: 48 }}>{page[1]} 月</span>
    </div>
    <div style={{ position: 'absolute', left: 0, right: 0, top: 128, bottom: 70, display: 'flex', alignItems: 'center', justifyContent: 'center', fontFamily: SERIF, fontWeight: 800, fontSize: 250, color: INK, lineHeight: 1 }}>
      {page[2]}
    </div>
    <div style={{ position: 'absolute', left: 0, right: 0, bottom: 34, textAlign: 'center', fontFamily: SERIF_TC, fontWeight: 900, fontSize: 40, color: '#7A6F62', letterSpacing: '0.2em' }}>{page[3]}</div>
    {tag ? (
      <div
        style={{
          position: 'absolute',
          right: 26,
          top: 146,
          filter: 'url(#ink)',
          border: `5px solid ${CLAY}`,
          borderRadius: 12,
          padding: '2px 14px 6px',
          color: CLAY,
          fontWeight: 900,
          fontSize: 40,
          transform: 'rotate(8deg)',
        }}
      >
        {tag}
      </div>
    ) : null}
  </div>
);

/**
 * The exam date: a tear-off desk calendar out of the phone, its pages
 * flipping up and over until it reaches the day, which gets a pen ring.
 */
export const Calendar = ({ t, at, until, from, pages, final, tag }: { t: number; at: number; until?: number; from: { x: number; y: number }; pages: Page[]; final: Page; tag: string }) => {
  const width = 500;
  const height = 560;
  const flipStart = at + 0.42;
  const each = 0.15;
  const landed = flipStart + pages.length * each;
  const ring = interpolate(t, [landed + 0.15, landed + 0.6], [0, 1], { ...clamp, easing: Easing.out(Easing.cubic) });
  return (
    <Fly t={t} at={at} until={until} from={from} left={(1080 - width) / 2} top={250} width={width} height={height} tilt={-3}>
      <div style={{ position: 'absolute', inset: 0, perspective: 1600 }}>
        <CalendarPage page={final} tag={t > landed ? tag : undefined} />
        {pages
          .map((page, i) => {
            const start = flipStart + i * each;
            const p = interpolate(t, [start, start + each * 1.4], [0, 1], { ...clamp, easing: Easing.in(Easing.quad) });
            if (p >= 1) return null;
            return (
              <div key={i} style={{ position: 'absolute', inset: 0, transformOrigin: '50% 0%', transform: `rotateX(${p * 120}deg)`, backfaceVisibility: 'hidden', zIndex: pages.length - i }}>
                <CalendarPage page={page} />
              </div>
            );
          })
          .reverse()}
        {/* Binding rings */}
        {[0.3, 0.7].map((x) => (
          <div key={x} style={{ position: 'absolute', left: `${x * 100}%`, top: -22, width: 26, height: 52, marginLeft: -13, borderRadius: 13, background: 'linear-gradient(90deg, #6d685f, #d9d3c6 50%, #5a554d)', zIndex: 20 }} />
        ))}
        {ring > 0 ? (
          <svg style={{ position: 'absolute', inset: 0, overflow: 'visible', zIndex: 21 }} width={width} height={height}>
            <path
              d="M 380 250 C 420 420, 140 470, 110 330 C 85 210, 260 150, 395 215"
              fill="none"
              stroke={CLAY}
              strokeWidth={11}
              strokeLinecap="round"
              strokeDasharray={1100}
              strokeDashoffset={1100 * (1 - ring)}
              opacity={0.9}
            />
          </svg>
        ) : null}
      </div>
    </Fly>
  );
};

/** A number counting up on a tag: "每天 20 個字" / "Daily goal 20 words a day". */
export const Counter = ({ t, at, until, from, left, top, tilt, label, unit, to }: { t: number; at: number; until?: number; from: { x: number; y: number }; left: number; top: number; tilt: number; label: string; unit: string; to: number }) => {
  const n = Math.round(interpolate(t, [at + 0.35, at + 1.0], [0, to], { ...clamp, easing: Easing.out(Easing.cubic) }));
  return (
    <Fly t={t} at={at} until={until} from={from} left={left} top={top} width={440} height={330} tilt={tilt}>
      <Tag>
        <div style={{ fontWeight: 900, fontSize: 38, color: '#7A6F62', letterSpacing: '0.1em' }}>{label}</div>
        <div style={{ fontFamily: SERIF, fontWeight: 800, fontSize: 180, lineHeight: 1, color: CLAY, margin: '4px 0 6px' }}>{n}</div>
        <div style={{ fontWeight: 900, fontSize: 44 }}>{unit}</div>
      </Tag>
    </Fly>
  );
};

/** Chapters lighting up one by one to the one you will reach, with a flag on it. */
export const Track = ({ t, at, until, from, left, top, tilt, title, steps, stepWord, flag }: { t: number; at: number; until?: number; from: { x: number; y: number }; left: number; top: number; tilt: number; title: string; steps: string[]; stepWord: string; flag: string }) => (
  <Fly t={t} at={at} until={until} from={from} left={left} top={top} width={470} height={330} tilt={tilt}>
    <Tag>
      <div style={{ fontWeight: 900, fontSize: 38, color: '#7A6F62', letterSpacing: '0.1em', marginBottom: 26 }}>{title}</div>
      <div style={{ position: 'relative', display: 'flex', gap: 28 }}>
        <div style={{ position: 'absolute', left: 32, right: 32, top: 31, borderTop: `4px dashed rgba(201,100,66,0.45)` }} />
        {steps.map((s, i) => {
          const on = interpolate(t, [at + 0.5 + i * 0.22, at + 0.62 + i * 0.22], [0, 1], clamp);
          return (
            <div key={s} style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 10, position: 'relative' }}>
              <div
                style={{
                  width: 66,
                  height: 66,
                  borderRadius: 33,
                  background: on > 0.5 ? CLAY : '#FBF6EA',
                  border: `4px solid ${CLAY}`,
                  color: on > 0.5 ? '#FFF6EA' : CLAY,
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  fontFamily: SERIF,
                  fontWeight: 800,
                  fontSize: 34,
                  transform: `scale(${1 + 0.18 * Math.sin(Math.PI * on)})`,
                }}
              >
                {s}
              </div>
              <div style={{ fontWeight: 800, fontSize: 24, color: '#7A6F62', whiteSpace: 'nowrap' }}>{stepWord.replace('{n}', s)}</div>
              {i === steps.length - 1 ? (
                <div
                  style={{
                    position: 'absolute',
                    left: 46,
                    top: -50,
                    transformOrigin: '0% 100%',
                    transform: `scale(${interpolate(t, [at + 0.62 + i * 0.22, at + 0.9 + i * 0.22], [0, 1], { ...clamp, easing: Easing.out(Easing.back(2)) })})`,
                  }}
                >
                  <div style={{ width: 4, height: 64, background: INK, borderRadius: 2 }} />
                  <div style={{ position: 'absolute', left: 4, top: 0, background: SAGE, color: '#fff', fontWeight: 900, fontSize: 26, padding: '4px 12px 6px', borderRadius: '0 8px 8px 0', whiteSpace: 'nowrap' }}>
                    {flag}
                  </div>
                </div>
              ) : null}
            </div>
          );
        })}
      </div>
    </Tag>
  </Fly>
);

/** Stops on a path lighting up as they are named, then stamped done. */
export const Route = ({ t, at, until, from, left, top, tilt, stops, stopTimes, doneAt, doneText }: { t: number; at: number; until?: number; from: { x: number; y: number }; left: number; top: number; tilt: number; stops: string[]; stopTimes: number[]; doneAt: number; doneText: string }) => {
  const done = interpolate(t, [doneAt - 0.13, doneAt], [0, 1], { ...clamp, easing: Easing.in(Easing.cubic) });
  return (
    <Fly t={t} at={at} until={until} from={from} left={left} top={top} width={780} height={330} tilt={tilt}>
      <Tag>
        <div style={{ position: 'relative', display: 'flex', gap: 80, marginTop: -20 }}>
          <div style={{ position: 'absolute', left: 50, right: 50, top: 46, borderTop: `5px dashed rgba(201,100,66,0.45)` }} />
          {stops.map((s, i) => {
            const on = interpolate(t, [stopTimes[i], stopTimes[i] + 0.12], [0, 1], clamp);
            return (
              <div key={s} style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 14 }}>
                <div
                  style={{
                    width: 96,
                    height: 96,
                    borderRadius: 48,
                    background: on > 0.5 ? CLAY : '#FBF6EA',
                    border: `5px solid ${CLAY}`,
                    color: on > 0.5 ? '#FFF6EA' : CLAY,
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    fontFamily: SERIF,
                    fontWeight: 800,
                    fontSize: 46,
                    transform: `scale(${1 + 0.2 * Math.sin(Math.PI * on)})`,
                  }}
                >
                  {i + 1}
                </div>
                <div style={{ fontWeight: 900, fontSize: 38 }}>{s}</div>
              </div>
            );
          })}
        </div>
        {done > 0 ? (
          <div
            style={{
              position: 'absolute',
              right: 24,
              bottom: 18,
              filter: 'url(#ink)',
              border: `6px solid ${SAGE}`,
              borderRadius: 14,
              padding: '4px 18px 8px',
              color: SAGE,
              fontWeight: 900,
              fontSize: 36,
              opacity: done,
              transform: `rotate(-7deg) scale(${t < doneAt ? 1.8 - 0.8 * done : 1})`,
              whiteSpace: 'nowrap',
            }}
          >
            ✓ {doneText}
          </div>
        ) : null}
      </Tag>
    </Fly>
  );
};
