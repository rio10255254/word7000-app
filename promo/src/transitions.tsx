import type { ReactElement } from 'react';
import { AbsoluteFill, Easing } from 'remotion';
import { TransitionSeries, linearTiming } from '@remotion/transitions';
import type { TransitionPresentation, TransitionPresentationComponentProps } from '@remotion/transitions';
import { scaledLength } from './time';

/**
 * Between scenes the next page is laid over the last one, like turning to
 * a fresh sheet in the collage notebook: it slides in from one side with a
 * slight tilt and a soft shadow while the page underneath sinks back and
 * dims. Nothing cuts hard, and each scene holds a beat before it goes.
 */

/** Extra authored frames each scene stays on screen after its own animation. */
export const HOLD = 24;
/** Authored frames the page turn takes; the two scenes overlap for this long. */
export const TURN = 16;

type From = 'bottom' | 'right' | 'left';
type PaperProps = { from: From };

const PaperTurn = ({ presentationProgress: p, presentationDirection, children, passedProps }: TransitionPresentationComponentProps<PaperProps>) => {
  if (presentationDirection === 'exiting') {
    // The page underneath sinks back a little and dims as it is covered.
    return (
      <AbsoluteFill style={{ transform: `scale(${1 - 0.06 * p})`, filter: `brightness(${1 - 0.18 * p})` }}>
        {children}
      </AbsoluteFill>
    );
  }
  const rest = 1 - p;
  const { from } = passedProps;
  const x = from === 'right' ? 105 * rest : from === 'left' ? -105 * rest : 0;
  const y = from === 'bottom' ? 105 * rest : 6 * rest;
  const tilt = (from === 'left' ? -1 : 1) * 5 * rest;
  return (
    <AbsoluteFill
      style={{
        transform: `translate(${x}%, ${y}%) rotate(${tilt}deg)`,
        transformOrigin: from === 'bottom' ? '50% 100%' : from === 'right' ? '100% 50%' : '0% 50%',
        boxShadow: `0 0 ${60 + 40 * rest}px rgba(43,38,32,${0.35 * Math.min(1, rest * 3)})`,
      }}
    >
      {children}
    </AbsoluteFill>
  );
};

const paperTurn = (from: From): TransitionPresentation<PaperProps> => ({ component: PaperTurn, props: { from } });

const ORDER: From[] = ['bottom', 'right', 'left'];
const turnTiming = () => linearTiming({ durationInFrames: scaledLength(TURN), easing: Easing.bezier(0.65, 0, 0.35, 1) });

type SceneDef = { id: string; duration: number };

/** Total output frames for a scene list played with holds and page turns. */
export const trackLength = (scenes: readonly SceneDef[]) =>
  scenes.reduce((sum, s) => sum + scaledLength(s.duration + HOLD), 0) - (scenes.length - 1) * scaledLength(TURN);

/** Plays the scenes in order, each held a beat longer and joined by page turns. */
export const SceneTrack = ({ scenes, components }: { scenes: readonly SceneDef[]; components: Record<string, () => ReactElement> }) => (
  <TransitionSeries>
    {scenes.flatMap((scene, i) => {
      const Component = components[scene.id];
      const items = [
        <TransitionSeries.Sequence key={scene.id} durationInFrames={scaledLength(scene.duration + HOLD)} name={scene.id}>
          <Component />
        </TransitionSeries.Sequence>,
      ];
      if (i > 0) {
        items.unshift(<TransitionSeries.Transition key={`turn-${scene.id}`} presentation={paperTurn(ORDER[(i - 1) % ORDER.length])} timing={turnTiming()} />);
      }
      return items;
    })}
  </TransitionSeries>
);
