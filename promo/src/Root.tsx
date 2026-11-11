import { Composition } from 'remotion';
import { FULL_DURATION, Full } from './Full';
import { Intro } from './reels/Intro';
import { Teaser } from './reels/Teaser';
import { Countdown } from './reels/Countdown';
import { Day4 } from './reels/Day4';
import { Day5 } from './reels/Day5';
import { Day6 } from './reels/Day6';
import { PathDay } from './reels/PathDay';
import { EPISODES, REEL_FPS, Reel, reelFrames } from './reels/Reel';
import { OUTPUT_FPS } from './time';

export const Root = () => (
  <>
    <Composition id="Full" component={Full} durationInFrames={FULL_DURATION} fps={OUTPUT_FPS} width={1080} height={1920} />
    {EPISODES.map((e) => (
      <Composition
        key={e.id}
        id={`Reel-${e.id}`}
        component={e.id.startsWith('d6') ? Day6 : e.id.startsWith('d5') ? Day5 : e.id.startsWith('d4') ? Day4 : e.id.startsWith('cd5') ? PathDay : e.id.startsWith('cd') ? Countdown : e.id.startsWith('teaser') ? Teaser : e.id.startsWith('ep01') ? Intro : Reel}
        defaultProps={{ id: e.id }}
        durationInFrames={reelFrames(e.id)}
        fps={REEL_FPS}
        width={1080}
        height={1920}
      />
    ))}
  </>
);
