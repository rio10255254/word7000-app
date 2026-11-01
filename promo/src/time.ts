import { useCurrentFrame } from 'remotion';

/**
 * How much slower than written the videos play. Every scene is authored in
 * frames at 30 fps; at SPEED 1.2 each of those frames lasts 1.2 real frames,
 * so the whole piece — cuts, typing, springs, the cat's breathing — runs
 * 1.2× slower while the file stays a smooth 30 fps.
 */
export const SPEED = 1.2;

/** The current frame on the authored (unslowed) timeline. May be fractional. */
export const useFrame = () => useCurrentFrame() / SPEED;

/** Scene list → real frames: each scene's start and end are scaled, so cuts stay contiguous. */
export const scaleScenes = <T extends { from: number; duration: number }>(scenes: readonly T[]) =>
  scenes.map((scene) => {
    const from = Math.round(scene.from * SPEED);
    const to = Math.round((scene.from + scene.duration) * SPEED);
    return { ...scene, from, duration: to - from };
  });

export const scaledLength = (frames: number) => Math.round(frames * SPEED);
