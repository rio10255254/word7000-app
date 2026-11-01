import { useCurrentFrame } from 'remotion';
import timeline from './timeline.json';

/** Every scene is written in frames at this rate. */
export const AUTHORED_FPS = 30;
/** The rate the videos are rendered at. */
export const OUTPUT_FPS = 60;
/** How much slower than written the videos play, so viewers can read everything. */
export const SPEED = 1.2;

/**
 * Output frames per authored frame: 1.2 for the slowdown × 2 for 60 fps.
 * Cuts, typing, springs and the cat's breathing all run on the authored
 * timeline, so they slow down together and simply gain in-between frames.
 */
export const FRAME_SCALE = SPEED * (OUTPUT_FPS / AUTHORED_FPS);

/** One beat of the soundtrack in output frames (100 bpm at 60 fps = 36). */
export const BEAT_FRAMES = Math.round((OUTPUT_FPS * 60) / timeline.bpm);

/** The current frame on the authored 30 fps timeline. Fractional between authored frames. */
export const useFrame = () => useCurrentFrame() / FRAME_SCALE;

export const scaledLength = (frames: number) => Math.round(frames * FRAME_SCALE);
