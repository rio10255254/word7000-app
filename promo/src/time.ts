import { useCurrentFrame } from 'remotion';

/** Every scene is written in frames at this rate. */
export const AUTHORED_FPS = 30;
/** The rate the videos are rendered at. */
export const OUTPUT_FPS = 60;
/** How much slower than written the videos play, so viewers can read everything. */
export const SPEED = 1.2;

/**
 * Real output frames per authored frame: 1.2 for the slowdown × 2 for 60 fps.
 * Cuts, typing, springs and the cat's breathing all run on the authored
 * timeline, so they slow down together and simply gain in-between frames.
 */
const FRAME_SCALE = SPEED * (OUTPUT_FPS / AUTHORED_FPS);

/** The current frame on the authored 30 fps timeline. Fractional between authored frames. */
export const useFrame = () => useCurrentFrame() / FRAME_SCALE;

/** Scene list → output frames: each scene's start and end are scaled, so cuts stay contiguous. */
export const scaleScenes = <T extends { from: number; duration: number }>(scenes: readonly T[]) =>
  scenes.map((scene) => {
    const from = Math.round(scene.from * FRAME_SCALE);
    const to = Math.round((scene.from + scene.duration) * FRAME_SCALE);
    return { ...scene, from, duration: to - from };
  });

export const scaledLength = (frames: number) => Math.round(frames * FRAME_SCALE);
