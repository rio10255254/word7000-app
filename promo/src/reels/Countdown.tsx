import type { ReactNode } from 'react';
import { AbsoluteFill, Easing, Html5Audio, Img, interpolate, spring, staticFile, useCurrentFrame } from 'remotion';
import { FONT, SERIF, SERIF_TC } from '../fonts';
import { Paper, Tape } from '../collage';
import { clamp } from '../kit';
import script from './episodes.json';
import timings from './timing.json';
import { REEL_FPS } from './Reel';
import { type Cam, Caption, Ripple, camAt, inOut, out, toStage } from './Intro';
import { Calendar, Counter, Route, Track } from './props';
import { ABOVE_CAPTIONS, CAPTION_TOP, Peek, Phone } from './Teaser';
import { Backdrop, Grade, InkFilters, Motes, Sheen } from './finish';

/**
 * The daily countdown to launch, one feature a day, in the teaser's look.
 * Cover: the number of days left, stamped on a taped card, and 傻貓
 * peeking in. Then the phone rises on one screen of the app and the
 * camera moves over it while the cat talks, marking what it talks about
 * (a pen ring round a choice, a highlighter under a line); a cheeky peek;
 * and the end card with the days-left stamp.
 *
 * Everything that changes from day to day is in the episode's entry in
 * episodes.json: the screen, the camera's stops, the marks, the taps.
 */
const CLAY = '#C96442';
const BEAT = 0.5;

type Slot = { start: number; length: number };
type Episode = {
  id: string;
  days: number;
  app: string;
  launch: string;
  label: string;
  screen: string;
  dayWords: [string, string];
  note: string;
  outro: string;
  cams: [number, number, Cam][];
  marks: [number, number, 'ring' | 'marker', number, number, number, number][];
  taps: [number, number, number, number][];
  lines: { text: string }[];
  /** Things that fly out of the phone: see props.tsx. Times are [slot, beat]; `from` is a point on the screen. */
  props?: (
    | { kind: 'calendar'; slot: number; beat: number; until?: [number, number]; from: [number, number]; pages: [string, string, string, string][]; final: [string, string, string, string]; tag: string }
    | { kind: 'counter'; slot: number; beat: number; until?: [number, number]; from: [number, number]; at: [number, number]; tilt: number; label: string; unit: string; to: number }
    | { kind: 'track'; slot: number; beat: number; until?: [number, number]; from: [number, number]; at: [number, number]; tilt: number; title: string; steps: string[]; stepWord: string; flag: string }
    | { kind: 'route'; slot: number; beat: number; until?: [number, number]; from: [number, number]; at: [number, number]; tilt: number; stops: string[]; stopBeats: number[]; doneBeat: number; doneText: string }
  )[];
};

/** The days left, as a rubber stamp on cream paper: "還有 6 天" / "6 days to go", and the date under a rule. */
const DaysStamp = ({ days, words, note, scale = 1 }: { days: number; words: [string, string]; note: string; scale?: number }) => (
  <div
    style={{
      filter: 'url(#ink)',
      border: `${9 * scale}px solid ${CLAY}`,
      borderRadius: 30 * scale,
      padding: `${10 * scale}px ${46 * scale}px ${16 * scale}px`,
      color: CLAY,
      display: 'flex',
      flexDirection: 'column',
      alignItems: 'center',
    }}
  >
    <div style={{ display: 'flex', alignItems: 'baseline', gap: 16 * scale, lineHeight: 1 }}>
      {words[0] ? <span style={{ fontFamily: SERIF_TC, fontWeight: 900, fontSize: 64 * scale }}>{words[0]}</span> : null}
      <span style={{ fontFamily: SERIF, fontWeight: 800, fontSize: 190 * scale }}>{days}</span>
      <span style={{ fontFamily: words[0] ? SERIF_TC : SERIF, fontWeight: 900, fontSize: (words[0] ? 64 : 58) * scale }}>{words[1]}</span>
    </div>
    <div style={{ alignSelf: 'stretch', height: 4 * scale, background: CLAY, margin: `${10 * scale}px ${4 * scale}px ${12 * scale}px`, borderRadius: 2 }} />
    <div style={{ fontWeight: 900, fontSize: 32 * scale, letterSpacing: '0.2em', lineHeight: 1, paddingLeft: '0.2em' }}>{note}</div>
  </div>
);

/** The card the stamp sits on, slapped down at `at`, stamped at `stampAt`. */
const StampCard = ({ t, at, stampAt, top, children }: { t: number; at: number; stampAt: number; top: number; children: ReactNode }) => {
  const p = at <= 0 ? 1 : interpolate(t, [at, at + 0.16], [0, 1], { ...clamp, easing: Easing.in(Easing.quad) });
  const press = stampAt <= 0 ? 1 : interpolate(t, [stampAt - 0.13, stampAt], [0, 1], { ...clamp, easing: Easing.in(Easing.cubic) });
  const settle = interpolate(t, [stampAt, stampAt + 0.2], [0.95, 1], { ...clamp, easing: out });
  if (t < at) return null;
  return (
    <div
      style={{
        position: 'absolute',
        left: (1080 - 740) / 2,
        top,
        width: 740,
        height: 380,
        opacity: Math.min(1, p * 3),
        transform: `rotate(${-2 - (1 - p) * 4}deg) scale(${1.1 - 0.1 * p})`,
      }}
    >
      <Paper kind="ivory" grain={0.7} style={{ inset: 0, background: '#FBF6EA', boxShadow: '0 22px 44px rgba(30,34,14,0.28), 0 4px 10px rgba(30,34,14,0.18)' }} />
      <Tape width={60} angle={-8} style={{ left: 40, top: -18 }} />
      <Tape width={60} angle={10} style={{ right: 40, top: -16 }} />
      <div
        style={{
          position: 'absolute',
          inset: 0,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          opacity: press,
          transform: `rotate(-4deg) scale(${t < stampAt ? 1.8 - 0.85 * press : settle})`,
        }}
      >
        {children}
      </div>
    </div>
  );
};

/** A pen ring drawn round a choice, in screen pixels × z. */
const Ring = ({ t, at, x0, y0, x1, y1, z }: { t: number; at: number; x0: number; y0: number; x1: number; y1: number; z: number }) => {
  if (t < at) return null;
  const p = interpolate(t, [at, at + 0.45], [0, 1], { ...clamp, easing: out });
  const pad = 26;
  const cx = ((x0 + x1) / 2) * z;
  const cy = ((y0 + y1) / 2) * z;
  const rx = ((x1 - x0) / 2 + pad) * z;
  const ry = ((y1 - y0) / 2 + pad) * z;
  // A slightly open, slightly tilted loop, like a quick circle in pen.
  const d = `M ${cx + rx * 0.9} ${cy - ry * 0.55} C ${cx + rx * 1.15} ${cy + ry * 0.9}, ${cx - rx * 0.6} ${cy + ry * 1.2}, ${cx - rx * 1.02} ${cy + ry * 0.1} C ${cx - rx * 1.25} ${cy - ry * 0.9}, ${cx + rx * 0.5} ${cy - ry * 1.25}, ${cx + rx * 1.05} ${cy - ry * 0.25}`;
  const length = 4 * (rx + ry) * 1.3;
  return (
    <svg style={{ position: 'absolute', left: 0, top: 0, width: '100%', height: '100%', overflow: 'visible' }}>
      <path d={d} fill="none" stroke={CLAY} strokeWidth={9 * z} strokeLinecap="round" strokeDasharray={length} strokeDashoffset={length * (1 - p)} opacity={0.9} />
    </svg>
  );
};

/** A highlighter stroke under a line, swept left to right. */
const Marker = ({ t, at, x0, y0, x1, y1, z }: { t: number; at: number; x0: number; y0: number; x1: number; y1: number; z: number }) => {
  if (t < at) return null;
  const p = interpolate(t, [at, at + 0.4], [0, 1], { ...clamp, easing: inOut });
  return (
    <div
      style={{
        position: 'absolute',
        left: (x0 - 10) * z,
        top: (y0 + (y1 - y0) * 0.35) * z,
        width: (x1 - x0 + 20) * z * p,
        height: (y1 - y0) * 0.7 * z,
        background: 'rgba(240,170,110,0.5)',
        mixBlendMode: 'multiply',
        borderRadius: 6 * z,
        transform: 'rotate(-0.6deg)',
      }}
    />
  );
};

export const Countdown = ({ id }: { id: string }) => {
  const t = useCurrentFrame() / REEL_FPS;
  const frame = useCurrentFrame();
  const episode = script.episodes.find((e) => e.id === id)! as unknown as Episode;
  const timing = (timings as Record<string, { total: number; end: number; slots: Slot[] }>)[id];
  const starts = timing.slots.map((s) => s.start);
  const at = (slot: number, beat: number) => starts[slot] + beat * BEAT;
  const [, show, , mock] = starts;
  const end = timing.end;

  // The camera: rising onto the first stop, then the episode's own stops.
  const keys: [number, Cam][] = [];
  const first = episode.cams[0][2];
  keys.push([show, { ...first, z: first.z * 0.92 }]);
  episode.cams.forEach(([slot, beat, c], i) => {
    const time = at(slot, beat);
    keys.push([i === 0 ? show + 0.8 : time + 0.6, c]);
    const next = episode.cams[i + 1];
    if (next) keys.push([at(next[0], next[1]) - 0.05, { ...c, z: c.z * 1.02 }]);
  });
  const cam = camAt(keys, t);
  const phoneIn = interpolate(t, [show, show + 0.8], [0, 1], { ...clamp, easing: inOut });
  const back = interpolate(t, [mock, mock + 0.4], [0, 1], clamp);
  const exit = interpolate(t, [end - 0.15, end + 0.35], [0, 1], { ...clamp, easing: inOut });

  const fx = Math.sin(t * 0.83) * 4 + Math.sin(t * 1.7) * 1.5;
  const fy = Math.cos(t * 0.61) * 5;
  const rx = 2 + Math.sin(t * 0.4) * 2.2;
  const ry = -3 + Math.sin(t * 0.3 + 0.5) * 4;
  const hold = `perspective(2600px) rotateX(${rx}deg) rotateY(${ry}deg) translate(${fx}px, ${fy}px) rotate(${Math.sin(t * 0.47) * 0.35}deg)`;

  const iconPop = spring({ frame: (t - end - 0.05) * REEL_FPS, fps: REEL_FPS, config: { damping: 14, stiffness: 150, mass: 0.9 } });
  const knock = end + 0.75;
  const endShake = t > knock && t < knock + 0.25 ? Math.sin((t - knock) * 80) * 5 * (1 - (t - knock) / 0.25) : 0;
  const coverOut = interpolate(t, [show - 0.1, show + 0.25], [0, 1], { ...clamp, easing: inOut });
  // While the calendar is out, the phone sinks back a little.
  const calendar = (episode.props ?? []).find((pr) => pr.kind === 'calendar');
  const sink = calendar
    ? interpolate(t, [at(calendar.slot, calendar.beat), at(calendar.slot, calendar.beat) + 0.4], [0, 1], clamp) *
      (calendar.until ? interpolate(t, [at(...calendar.until), at(...calendar.until) + 0.35], [1, 0], clamp) : 1)
    : 0;
  const stamp = <DaysStamp days={episode.days} words={episode.dayWords} note={episode.note} />;

  return (
    <AbsoluteFill style={{ fontFamily: FONT, overflow: 'hidden' }}>
      <Html5Audio src={staticFile(`reels/${id}.mp3`)} />
      <InkFilters />
      <Backdrop t={t} frame={frame} drift={t >= show ? (cam.y - 1250) * cam.z : 0} />
      <Motes t={t} />

      {/* The cover: the days left, stamped on a card; it lifts away as the phone comes up. */}
      {coverOut < 1 ? (
        <div style={{ position: 'absolute', inset: 0, opacity: 1 - coverOut, transform: `translateY(${-coverOut * 120}px)` }}>
          <StampCard t={t} at={0} stampAt={0} top={300}>
            {stamp}
          </StampCard>
        </div>
      ) : null}

      {t >= show && t < end + 0.4 ? (
        <div style={{ position: 'absolute', inset: 0, filter: back || sink ? `blur(${back * 7 + exit * 8 + sink * 3}px) brightness(${1 - 0.18 * sink})` : undefined, opacity: 1 - 0.25 * back, ...ABOVE_CAPTIONS }}>
          <div style={{ position: 'absolute', inset: 0, transform: `${hold} scale(${1 - 0.08 * exit})`, transformOrigin: '50% 43%', opacity: 1 - exit }}>
            <Phone cam={cam} lift={(1 - phoneIn) * 1500} t={t}>
              <Img src={staticFile(`next/${episode.screen}.jpg`)} style={{ position: 'absolute', width: '100%', height: '100%' }} />
              {episode.marks.map(([slot, beat, kind, x0, y0, x1, y1], i) =>
                kind === 'ring' ? (
                  <Ring key={i} t={t} at={at(slot, beat)} x0={x0} y0={y0} x1={x1} y1={y1} z={cam.z} />
                ) : (
                  <Marker key={i} t={t} at={at(slot, beat)} x0={x0} y0={y0} x1={x1} y1={y1} z={cam.z} />
                ),
              )}
            </Phone>
            {episode.taps.map(([slot, beat, x, y], i) => (
              <Ripple key={i} at={at(slot, beat)} t={t} x={x} y={y} cam={cam} />
            ))}
          </div>
        </div>
      ) : null}

      {(episode.props ?? []).map((pr, i) => {
        const when = at(pr.slot, pr.beat);
        const until = pr.until ? at(...pr.until) : end - 0.2;
        const from = toStage(cam, pr.from[0], pr.from[1]);
        if (pr.kind === 'calendar') return <Calendar key={i} t={t} at={when} until={until} from={from} pages={pr.pages} final={pr.final} tag={pr.tag} />;
        if (pr.kind === 'counter')
          return <Counter key={i} t={t} at={when} until={until} from={from} left={pr.at[0]} top={pr.at[1]} tilt={pr.tilt} label={pr.label} unit={pr.unit} to={pr.to} />;
        if (pr.kind === 'track')
          return <Track key={i} t={t} at={when} until={until} from={from} left={pr.at[0]} top={pr.at[1]} tilt={pr.tilt} title={pr.title} steps={pr.steps} stepWord={pr.stepWord} flag={pr.flag} />;
        return (
          <Route
            key={i}
            t={t}
            at={when}
            until={until}
            from={from}
            left={pr.at[0]}
            top={pr.at[1]}
            tilt={pr.tilt}
            stops={pr.stops}
            stopTimes={pr.stopBeats.map((b) => at(pr.slot, b))}
            doneAt={at(pr.slot, pr.doneBeat)}
            doneText={pr.doneText}
          />
        );
      })}

      <Peek t={t} at={0} until={show + 0.05} side={1} mood="smug" y={760} />
      <Peek t={t} at={mock + 0.05} until={end + 0.4} side={-1} mood="cheeky" y={520} outAt={end - 0.15} />

      <Motes t={t} front />
      {episode.lines.map((line, i) => (
        <Caption key={i} text={line.text} start={timing.slots[i].start} length={timing.slots[i].length} t={t} first={i === 0} label={episode.label} top={CAPTION_TOP} size={62} glass />
      ))}

      {/* The end card: the icon and the name, the days-left stamp landing on the sound logo's chord, the ask. */}
      {t >= end - 0.05 ? (
        <AbsoluteFill style={{ transform: `translate(${endShake}px, ${endShake * 0.4}px)` }}>
          <div
            style={{
              position: 'absolute',
              left: 0,
              right: 0,
              top: 330,
              display: 'flex',
              justifyContent: 'center',
              alignItems: 'center',
              gap: 30,
              opacity: Math.min(1, iconPop * 1.5),
              transform: `translateY(${(1 - iconPop) * 50}px)`,
            }}
          >
            <div style={{ position: 'relative', transform: 'rotate(-3deg)' }}>
              <Img src={staticFile('icon-next.png')} style={{ width: 170, height: 170, borderRadius: 38, display: 'block', boxShadow: '0 22px 44px rgba(30,34,18,0.36)' }} />
              <Sheen t={t} at={end + 1.0} radius={38} />
            </div>
            <div style={{ display: 'flex', alignItems: 'baseline', gap: 16, color: '#FFF8EC', textShadow: '0 4px 20px rgba(30,34,18,0.3)' }}>
              <span style={{ fontFamily: SERIF, fontWeight: 800, fontSize: 78 }}>{episode.app.split(' ')[0]}</span>
              {episode.app.includes(' ') ? <span style={{ fontFamily: SERIF_TC, fontWeight: 900, fontSize: 68, letterSpacing: '0.06em' }}>{episode.app.split(' ').slice(1).join(' ')}</span> : null}
            </div>
          </div>
          <StampCard t={t} at={end + 0.35} stampAt={knock} top={660}>
            {stamp}
          </StampCard>
          <div
            style={{
              position: 'absolute',
              left: 110,
              right: 110,
              top: 1150,
              display: 'flex',
              justifyContent: 'center',
              opacity: interpolate(t, [end + 1.3, end + 1.6], [0, 1], clamp),
              transform: `translateY(${interpolate(t, [end + 1.3, end + 1.6], [16, 0], { ...clamp, easing: out })}px)`,
            }}
          >
            <div
              style={{
                background: 'linear-gradient(180deg, rgba(46,42,34,0.88), rgba(30,28,22,0.92))',
                border: '1.5px solid rgba(255,250,235,0.14)',
                color: '#FFF8EE',
                fontWeight: 900,
                fontSize: 46,
                padding: '18px 38px',
                borderRadius: 26,
                textAlign: 'center',
                textWrap: 'balance',
                boxShadow: 'inset 0 1.5px 0 rgba(255,250,235,0.12), 0 20px 46px rgba(20,24,10,0.3)',
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

