import type { CSSProperties, ReactNode } from 'react';
import { AbsoluteFill, interpolate, staticFile } from 'remotion';
import { clamp } from '../kit';

/**
 * The finish on the teaser: a backdrop with depth (moving light, faint paper
 * collage drifting at its own pace, live grain, a vignette), a real phone
 * (titanium band, side keys, Dynamic Island, glass glare, layered shadow),
 * and the small touches: ink-textured stamps, a sheen across the icon, a
 * burst of sparks.
 */

const OLIVE_LIGHT = '#AEBA88';
const OLIVE = '#879763';
const OLIVE_DARK = '#58643B';

/** Deterministic noise, so every render of a frame is the same. */
const hash = (n: number) => {
  const v = Math.sin(n * 127.1 + 311.7) * 43758.5453;
  return v - Math.floor(v);
};

/** Film grain that lives: the paper grain, re-laid every frame. */
export const Grain = ({ frame, opacity = 0.16 }: { frame: number; opacity?: number }) => (
  <AbsoluteFill
    style={{
      backgroundImage: `url(${staticFile('paper-grain.png')})`,
      backgroundSize: '320px 320px',
      backgroundPosition: `${Math.floor(hash(frame) * 320)}px ${Math.floor(hash(frame + 7.3) * 320)}px`,
      mixBlendMode: 'overlay',
      opacity,
      pointerEvents: 'none',
    }}
  />
);

/** A sheet of paper in the backdrop: tinted to the olive, softly out of focus. */
const Sheet = ({ style, kind }: { style: CSSProperties; kind: 'graph' | 'ruled' }) => (
  <div
    style={{
      position: 'absolute',
      borderRadius: 6,
      background:
        kind === 'graph'
          ? 'linear-gradient(to right, rgba(255,255,240,0.22) 1.5px, transparent 1.5px) 0 0 / 38px 38px, linear-gradient(to bottom, rgba(255,255,240,0.22) 1.5px, transparent 1.5px) 0 0 / 38px 38px, rgba(240,244,222,0.16)'
          : 'repeating-linear-gradient(to bottom, transparent 0, transparent 68px, rgba(255,255,240,0.24) 68px, rgba(255,255,240,0.24) 70px), rgba(250,246,230,0.14)',
      boxShadow: '0 30px 60px rgba(40,46,20,0.18)',
      filter: 'blur(2.5px)',
      ...style,
    }}
  />
);

/** The olive desk, with depth. `drift` is how far the camera has travelled, for parallax. */
export const Backdrop = ({ t, frame, drift = 0 }: { t: number; frame: number; drift?: number }) => {
  const lightX = 46 + Math.sin(t * 0.35) * 10;
  const lightY = 30 + Math.cos(t * 0.27) * 6;
  const p = drift * 0.06;
  return (
    <AbsoluteFill style={{ overflow: 'hidden' }}>
      <AbsoluteFill style={{ background: `radial-gradient(130% 85% at 50% 36%, ${OLIVE_LIGHT} 0%, ${OLIVE} 52%, ${OLIVE_DARK} 100%)` }} />
      <Sheet kind="graph" style={{ left: -160 - p, top: 120 + Math.sin(t * 0.4) * 8, width: 560, height: 720, transform: `rotate(${-14 + Math.sin(t * 0.3)}deg)` }} />
      <Sheet kind="ruled" style={{ right: -200 + p * 0.6, top: 1080 + Math.cos(t * 0.33) * 10, width: 620, height: 560, transform: `rotate(${11 + Math.cos(t * 0.25)}deg)` }} />
      {/* A slow, warm light moving across the desk. */}
      <AbsoluteFill style={{ background: `radial-gradient(55% 38% at ${lightX}% ${lightY}%, rgba(255,246,214,0.38), rgba(255,246,214,0) 70%)`, mixBlendMode: 'soft-light' }} />
      <Grain frame={frame} opacity={0.14} />
      <AbsoluteFill style={{ background: 'radial-gradient(120% 95% at 50% 45%, rgba(0,0,0,0) 55%, rgba(30,34,14,0.38) 100%)' }} />
    </AbsoluteFill>
  );
};

/** The lens and the vignette over everything, for one look across the whole piece. */
export const Grade = ({ frame }: { frame: number }) => (
  <>
    <Grain frame={frame + 31} opacity={0.06} />
    <AbsoluteFill style={{ background: 'radial-gradient(140% 100% at 50% 42%, rgba(0,0,0,0) 62%, rgba(24,26,12,0.22) 100%)', pointerEvents: 'none' }} />
  </>
);

/**
 * An iPhone around a 1206 × 2622 screen at scale `z`: titanium band, black
 * bezel, side keys, the Dynamic Island, a glare across the glass that moves
 * as the phone does, and a shadow in two layers (contact and ambient).
 */
export const Device = ({ z, glare = 0, children }: { z: number; glare?: number; children: ReactNode }) => {
  const W = 1206;
  const H = 2622;
  const key = (side: 'left' | 'right', top: number, height: number) => (
    <div
      style={{
        position: 'absolute',
        [side]: -66 * z,
        top: top * z,
        width: 16 * z,
        height: height * z,
        borderRadius: 8 * z,
        background: side === 'left' ? 'linear-gradient(to right, #2a2724, #6b665e 60%, #3a3632)' : 'linear-gradient(to left, #2a2724, #6b665e 60%, #3a3632)',
      }}
    />
  );
  return (
    <div style={{ position: 'absolute', left: 0, top: 0, width: W * z, height: H * z }}>
      {/* Shadows: a wide soft one, and a close one where it meets the desk. */}
      <div style={{ position: 'absolute', inset: -56 * z, borderRadius: 220 * z, boxShadow: `0 ${70 * z}px ${160 * z}px rgba(28,32,12,0.42), 0 ${18 * z}px ${36 * z}px rgba(28,32,12,0.3)` }} />
      {key('left', 560, 140)}
      {key('left', 820, 220)}
      {key('left', 1100, 220)}
      {key('right', 860, 330)}
      {/* Titanium band, catching the light on one edge. */}
      <div
        style={{
          position: 'absolute',
          inset: -56 * z,
          borderRadius: 220 * z,
          background: 'linear-gradient(135deg, #8a857b 0%, #3b3833 18%, #2a2825 45%, #55514a 62%, #23211e 85%, #6d685f 100%)',
          boxShadow: `inset 0 0 0 ${2 * z}px rgba(255,255,255,0.14)`,
        }}
      />
      {/* Bezel */}
      <div style={{ position: 'absolute', inset: -42 * z, borderRadius: 206 * z, background: '#0b0a09' }} />
      {/* Screen */}
      <div style={{ position: 'absolute', inset: 0, borderRadius: 165 * z, overflow: 'hidden', background: '#F3EEE4' }}>
        {children}
        {/* Dynamic Island */}
        <div style={{ position: 'absolute', left: 415 * z, top: 34 * z, width: 376 * z, height: 110 * z, borderRadius: 55 * z, background: '#050505' }}>
          <div style={{ position: 'absolute', right: 40 * z, top: 37 * z, width: 36 * z, height: 36 * z, borderRadius: '50%', background: 'radial-gradient(circle at 35% 35%, #2b3442, #07090c 70%)' }} />
        </div>
        {/* Glare across the glass */}
        <div
          style={{
            position: 'absolute',
            inset: 0,
            background: `linear-gradient(118deg, rgba(255,255,255,0) ${28 + glare}%, rgba(255,255,255,0.11) ${38 + glare}%, rgba(255,255,255,0) ${50 + glare}%)`,
            pointerEvents: 'none',
          }}
        />
        <div style={{ position: 'absolute', inset: 0, borderRadius: 165 * z, boxShadow: `inset 0 0 ${10 * z}px rgba(0,0,0,0.25)`, pointerEvents: 'none' }} />
      </div>
    </div>
  );
};

/** SVG filters: inked rubber-stamp edges and speckle. Mount once per frame. */
export const InkFilters = () => (
  <svg width={0} height={0} style={{ position: 'absolute' }}>
    <defs>
      <filter id="ink" x="-10%" y="-10%" width="120%" height="120%">
        <feTurbulence type="fractalNoise" baseFrequency="0.035" numOctaves={2} seed={4} result="warp" />
        <feDisplacementMap in="SourceGraphic" in2="warp" scale={5} xChannelSelector="R" yChannelSelector="G" result="rough" />
        <feTurbulence type="fractalNoise" baseFrequency="1.4" numOctaves={1} seed={9} result="speckle" />
        <feColorMatrix in="speckle" type="matrix" values="0 0 0 0 0  0 0 0 0 0  0 0 0 0 0  0 0 0 -2.2 1.75" result="holes" />
        <feComposite in="rough" in2="holes" operator="in" />
      </filter>
    </defs>
  </svg>
);

/** A band of light sweeping across whatever it covers, at `at` seconds. */
export const Sheen = ({ t, at, radius }: { t: number; at: number; radius: number }) => {
  const p = interpolate(t, [at, at + 0.7], [-60, 160], clamp);
  if (p <= -60 || p >= 160) return null;
  return (
    <div
      style={{
        position: 'absolute',
        inset: 0,
        borderRadius: radius,
        overflow: 'hidden',
        background: `linear-gradient(105deg, rgba(255,255,255,0) ${p - 18}%, rgba(255,255,255,0.55) ${p}%, rgba(255,255,255,0) ${p + 18}%)`,
        mixBlendMode: 'screen',
        pointerEvents: 'none',
      }}
    />
  );
};

/** Gold sparks flying out of a point at `at` seconds (positions in the parent's px). */
export const Burst = ({ t, at, x, y, scale = 1, count = 16 }: { t: number; at: number; x: number; y: number; scale?: number; count?: number }) => {
  const age = t - at;
  if (age < 0 || age > 0.9) return null;
  const ring = interpolate(age, [0, 0.5], [0.2, 1.6], clamp);
  return (
    <>
      <div
        style={{
          position: 'absolute',
          left: x - 260 * scale,
          top: y - 260 * scale,
          width: 520 * scale,
          height: 520 * scale,
          borderRadius: '50%',
          border: `${10 * scale}px solid rgba(255,214,120,0.85)`,
          transform: `scale(${ring})`,
          opacity: interpolate(age, [0, 0.5], [0.9, 0], clamp),
        }}
      />
      {Array.from({ length: count }, (_, i) => {
        const angle = (i / count) * Math.PI * 2 + hash(i) * 0.4;
        const dist = (300 + hash(i + 3) * 260) * scale * Math.sqrt(interpolate(age, [0, 0.9], [0, 1], clamp));
        const size = (16 + hash(i + 5) * 18) * scale;
        return (
          <div
            key={i}
            style={{
              position: 'absolute',
              left: x + Math.cos(angle) * dist - size / 2,
              top: y + Math.sin(angle) * dist - size / 2 + age * age * 300 * scale,
              width: size,
              height: size,
              borderRadius: '50%',
              background: i % 3 === 0 ? '#FFF2C4' : '#FFC861',
              boxShadow: `0 0 ${size}px rgba(255,200,97,0.8)`,
              opacity: interpolate(age, [0, 0.15, 0.9], [0, 1, 0], clamp),
            }}
          />
        );
      })}
    </>
  );
};
