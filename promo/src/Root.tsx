import { Composition } from 'remotion';
import { FULL_DURATION, Full } from './Full';
import { OUTPUT_FPS } from './time';

export const Root = () => (
  <Composition id="Full" component={Full} durationInFrames={FULL_DURATION} fps={OUTPUT_FPS} width={1080} height={1920} />
);
