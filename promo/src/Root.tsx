import { Composition } from 'remotion';
import { FULL_DURATION, Full } from './Full';
import { Intro } from './reels/Intro';
import { EPISODES, REEL_FPS, Reel, reelFrames } from './reels/Reel';
import { OUTPUT_FPS } from './time';

export const Root = () => (
  <>
    <Composition id="Full" component={Full} durationInFrames={FULL_DURATION} fps={OUTPUT_FPS} width={1080} height={1920} />
    {EPISODES.map((e) => (
      <Composition
        key={e.id}
        id={`Reel-${e.id}`}
        component={e.id === 'ep01' ? Intro : Reel}
        defaultProps={{ id: e.id }}
        durationInFrames={reelFrames(e.id)}
        fps={REEL_FPS}
        width={1080}
        height={1920}
      />
    ))}
  </>
);
