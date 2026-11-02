import type { ReactElement } from 'react';
import { AbsoluteFill, Easing } from 'remotion';
import { TransitionSeries, linearTiming } from '@remotion/transitions';
import type { TransitionPresentation, TransitionPresentationComponentProps } from '@remotion/transitions';
import { BEAT_FRAMES, scaledLength } from './time';
import timeline from './timeline.json';

/**
 * Transitions in the manner of app ads: no hard cuts, and the move fits
 * the moment — a circle growing out of the cat, a whip push with motion
 * blur, a zoom through the frame, a lock screen pulled down from the top,
 * a soft blur dissolve to the end card. Each scene also holds a beat
 * after its own animation before the next one comes in.
 */

/** Extra authored frames each scene stays on screen after its own animation. */
export const HOLD = timeline.hold;

type P<T extends Record<string, unknown>> = TransitionPresentationComponentProps<T>;
const W = 1080;
const H = 1920;
/** A presentation with its props bound; the track takes any of them. */
export type Move = TransitionPresentation<Record<string, unknown>>;
const move = <T extends Record<string, unknown>>(component: (props: P<T>) => ReactElement, props: T) =>
  ({ component, props }) as unknown as Move;

/** 0 at both ends of a move, 1 at its fastest: for motion blur. */
const speed = (p: number) => Math.sin(Math.PI * p);

/* ── Circle: the next scene grows out of a point, like the reference's orange disc. ── */
type CircleProps = { x: number; y: number };
const Circle = ({ presentationProgress: p, presentationDirection, children, passedProps: { x, y } }: P<CircleProps>) => {
  if (presentationDirection === 'exiting') {
    return <AbsoluteFill style={{ transform: `scale(${1 + 0.04 * p})` }}>{children}</AbsoluteFill>;
  }
  const reach = Math.hypot(Math.max(x, W - x), Math.max(y, H - y));
  return <AbsoluteFill style={{ clipPath: `circle(${reach * p}px at ${x}px ${y}px)` }}>{children}</AbsoluteFill>;
};
export const circle = (x: number, y: number) => move(Circle, { x, y });

/* ── Push: both scenes move together, blurred along the move at full speed. ── */
type PushProps = { to: 'left' | 'up' };
const Push = ({ presentationProgress: p, presentationDirection, children, passedProps: { to } }: P<PushProps>) => {
  const offset = presentationDirection === 'exiting' ? -100 * p : 100 * (1 - p);
  const blur = 14 * speed(p);
  const transform = to === 'left' ? `translateX(${offset}%)` : `translateY(${offset}%)`;
  return (
    <AbsoluteFill style={{ transform, filter: blur > 0.3 ? `blur(${blur}px)` : undefined }}>{children}</AbsoluteFill>
  );
};
export const push = (to: 'left' | 'up' = 'left') => move(Push, { to });

/* ── Zoom through: the old scene rushes past the camera, the new one settles in. ── */
type NoProps = Record<string, never>;
const ZoomThrough = ({ presentationProgress: p, presentationDirection, children }: P<NoProps>) => {
  if (presentationDirection === 'exiting') {
    return (
      <AbsoluteFill style={{ transform: `scale(${1 + 0.5 * p})`, opacity: 1 - p, filter: `blur(${16 * p}px)` }}>{children}</AbsoluteFill>
    );
  }
  return (
    <AbsoluteFill style={{ transform: `scale(${0.88 + 0.12 * p})`, opacity: Math.min(1, p * 1.6), filter: `blur(${12 * (1 - p)}px)` }}>
      {children}
    </AbsoluteFill>
  );
};
export const zoomThrough = () => move(ZoomThrough, {});

/* ── Pull down: the next scene drops from the top, like pulling down the lock screen. ── */
const PullDown = ({ presentationProgress: p, presentationDirection, children }: P<NoProps>) => {
  if (presentationDirection === 'exiting') {
    return <AbsoluteFill style={{ transform: `scale(${1 - 0.05 * p})`, filter: `brightness(${1 - 0.35 * p})` }}>{children}</AbsoluteFill>;
  }
  return (
    <AbsoluteFill style={{ transform: `translateY(${-100 * (1 - p)}%)`, boxShadow: `0 30px 80px rgba(0,0,0,${0.45 * (1 - p)})` }}>
      {children}
    </AbsoluteFill>
  );
};
export const pullDown = () => move(PullDown, {});

/* ── Blur dissolve: a soft cross-fade through blur, for a calm landing. ── */
const BlurDissolve = ({ presentationProgress: p, presentationDirection, children }: P<NoProps>) => {
  const t = presentationDirection === 'exiting' ? p : 1 - p;
  return (
    <AbsoluteFill style={{ opacity: presentationDirection === 'exiting' ? 1 : p, filter: `blur(${18 * t}px)` }}>{children}</AbsoluteFill>
  );
};
export const blurDissolve = () => move(BlurDissolve, {});

/* ── The track ── */

/**
 * Everything lands on the soundtrack's strong beats. A transition is a whole
 * number of beats, and each scene is held until the next transition can
 * start on a multiple of `quantizeBeats` (2: beat 1 or 3 of a bar). The
 * music is laid out by the same rule (scripts/make-music.py), so every
 * change of scene starts on a strong beat, where the music hits.
 */
const GRID = (timeline.quantizeBeats ?? 1) * BEAT_FRAMES;
/** A bar of the soundtrack, and where bar lines fall (the song's first downbeat). */
const BAR = 4 * BEAT_FRAMES;
const BAR_PHASE = (timeline.barPhaseBeats ?? 0) * BEAT_FRAMES;
const ceilTo = (frames: number, unit: number) => Math.ceil(frames / unit) * unit;
const turnFrames = (s: Step) => (s.turnBeats ?? 1) * BEAT_FRAMES;
const timing = (s: Step) => linearTiming({ durationInFrames: turnFrames(s), easing: Easing.bezier(0.7, 0, 0.3, 1) });

export type Step = {
  id: string;
  /** Authored length of the scene's own animation (HOLD is added). */
  duration?: number;
  /** Or its exact length in output frames, holds included (a nested section). */
  frames?: number;
  render: () => ReactElement;
  /** How this scene comes in; ignored on the first. */
  enter?: Move;
  /** How many beats that transition takes (1 unless set). */
  turnBeats?: number;
  /** Start on a bar line, where the song begins a new section (the chorus, the dip, the end). */
  onBar?: boolean;
};

const rawFrames = (s: Step) => s.frames ?? scaledLength((s.duration ?? 0) + HOLD);

/**
 * Starts and lengths of each step in output frames. `fill` stretches the
 * last step so the track lasts at least that long (a nested section filling
 * the slot its parent track gave it).
 */
export const trackLayout = (steps: readonly Step[], fill = 0) => {
  const starts: number[] = [];
  const lengths: number[] = [];
  let t = 0;
  steps.forEach((step, i) => {
    starts.push(t);
    const next = steps[i + 1];
    if (next) {
      let advance = ceilTo(rawFrames(step) - turnFrames(next), GRID);
      // A scene that opens a new section of the song waits for the next bar line.
      while (next.onBar && (((t + advance - BAR_PHASE) % BAR) + BAR) % BAR !== 0) advance += GRID;
      lengths.push(advance + turnFrames(next));
      t += advance;
    } else {
      lengths.push(Math.max(ceilTo(rawFrames(step), BEAT_FRAMES), fill - t));
    }
  });
  return { starts, lengths, total: t + lengths[lengths.length - 1] };
};

/** Total output frames for a list of steps played with their transitions. */
export const trackFrames = (steps: readonly Step[]) => trackLayout(steps).total;

/** Where each step starts, in output frames (for things that span steps). */
export const stepStarts = (steps: readonly Step[]) => trackLayout(steps).starts;

type Entry = { id: string; duration?: number; turnBeats?: number; onBar?: boolean };
/** A scene's timing from timeline.json, which the soundtrack is built from too. */
export const timed = (entries: readonly Entry[], id: string) => {
  const entry = entries.find((e) => e.id === id);
  if (!entry) throw new Error(`No timeline entry for ${id}`);
  return { duration: entry.duration, turnBeats: entry.turnBeats, onBar: entry.onBar };
};

export const Track = ({ steps, fill = 0 }: { steps: readonly Step[]; fill?: number }) => {
  const { lengths } = trackLayout(steps, fill);
  return (
    <TransitionSeries>
      {steps.flatMap((step, i) => {
        const Render = step.render;
        const sequence = (
          <TransitionSeries.Sequence key={step.id} durationInFrames={lengths[i]} name={step.id}>
            <Render />
          </TransitionSeries.Sequence>
        );
        if (i === 0) return [sequence];
        return [
          <TransitionSeries.Transition key={`into-${step.id}`} presentation={step.enter ?? blurDissolve()} timing={timing(step)} />,
          sequence,
        ];
      })}
    </TransitionSeries>
  );
};
