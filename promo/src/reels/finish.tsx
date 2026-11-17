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
      <AbsoluteFill style={{ background: `radial-gradient(135% 95% at 50% 34%, ${OLIVE_LIGHT} 0%, ${OLIVE} 56%, ${OLIVE_DARK} 115%)` }} />
      <Sheet kind="graph" style={{ left: -160 - p, top: 120 + Math.sin(t * 0.4) * 8, width: 560, height: 720, transform: `rotate(${-14 + Math.sin(t * 0.3)}deg)` }} />
      <Sheet kind="ruled" style={{ right: -200 + p * 0.6, top: 1080 + Math.cos(t * 0.33) * 10, width: 620, height: 560, transform: `rotate(${11 + Math.cos(t * 0.25)}deg)` }} />
      {/* A slow, warm light moving across the desk. */}
      <AbsoluteFill style={{ background: `radial-gradient(55% 38% at ${lightX}% ${lightY}%, rgba(255,246,214,0.38), rgba(255,246,214,0) 70%)`, mixBlendMode: 'soft-light' }} />
      <Grain frame={frame} opacity={0.14} />
      <AbsoluteFill style={{ background: 'radial-gradient(125% 100% at 50% 40%, rgba(0,0,0,0) 58%, rgba(30,34,14,0.24) 100%)' }} />
    </AbsoluteFill>
  );
};

/** A thing lying on the desk behind the subject: `src` cropped to (x, y, w, h) of a 1206-wide screenshot, or a plain ruled sheet. */
export type DeskCard = { src?: string; crop?: [number, number, number, number] };

/**
 * The same desk with depth to it, for a subject held near the lens. Far:
 * the backdrop, thrown out of focus by `focus` (0–1). Middle: cards lying
 * about on the desk, softer the further they are, sliding against the
 * backdrop as the subject moves (`drift`). Then daylight through a
 * window in slow bands, and a darker edge to the frame.
 */
export const DeepBackdrop = ({ t, frame, drift = 0, focus = 1, cards = [] }: { t: number; frame: number; drift?: number; focus?: number; cards?: DeskCard[] }) => {
  const spots: { x: number; y: number; r: number; k: number; depth: number }[] = [
    { x: -150, y: 1010, r: -19, k: 0.33, depth: 0.5 },
    { x: 800, y: 560, r: 15, k: 0.3, depth: 0.8 },
    { x: 700, y: 1360, r: -9, k: 0.34, depth: 0.6 },
    { x: -70, y: 330, r: 9, k: 0.27, depth: 1 },
    { x: 380, y: 30, r: -5, k: 0.26, depth: 1.1 },
  ];
  return (
    <AbsoluteFill style={{ overflow: 'hidden' }}>
      <AbsoluteFill style={{ filter: `blur(${2 + focus * 7}px)`, transform: 'scale(1.06)' }}>
        <Backdrop t={t} frame={frame} drift={drift} />
      </AbsoluteFill>
      {cards.slice(0, spots.length).map((card, i) => {
        const at = spots[i];
        const [cx, cy, cw, ch] = card.crop ?? [0, 0, 1102, 1760];
        const slide = drift * 0.1 * (1.4 - at.depth);
        return (
          <div
            key={i}
            style={{
              position: 'absolute',
              left: at.x - slide + Math.sin(t * 0.3 + i) * 5,
              top: at.y + Math.cos(t * 0.26 + i * 2) * 6,
              width: cw * at.k,
              height: ch * at.k,
              borderRadius: 5,
              backgroundColor: '#F4EEDD',
              backgroundImage: card.src ? `url(${staticFile(card.src)})` : 'repeating-linear-gradient(to bottom, rgba(0,0,0,0) 0px, rgba(0,0,0,0) 27px, rgba(110,100,80,0.2) 28px)',
              backgroundSize: card.src ? `${1206 * at.k}px auto` : undefined,
              backgroundPosition: card.src ? `${-cx * at.k}px ${-cy * at.k}px` : undefined,
              transform: `rotate(${at.r + Math.sin(t * 0.22 + i) * 0.8}deg)`,
              boxShadow: '0 18px 30px rgba(26,30,10,0.34), 0 2px 4px rgba(26,30,10,0.25)',
              filter: `blur(${4 + focus * 5 * (0.6 + at.depth)}px) brightness(${0.8 - at.depth * 0.08}) saturate(0.85)`,
              opacity: 0.86,
            }}
          />
        );
      })}
      {/* Daylight through a window: soft bands that creep across the desk. */}
      <AbsoluteFill
        style={{
          background: 'repeating-linear-gradient(112deg, rgba(255,244,206,0) 0px, rgba(255,244,206,0.5) 150px, rgba(255,244,206,0.5) 230px, rgba(255,244,206,0) 380px, rgba(255,244,206,0) 620px)',
          backgroundPosition: `${t * 16}px 0`,
          mixBlendMode: 'soft-light',
          filter: 'blur(26px)',
          transform: 'scale(1.15)',
          opacity: 0.45,
        }}
      />
      <AbsoluteFill style={{ background: `radial-gradient(90% 70% at 50% 44%, rgba(18,22,8,0) 40%, rgba(18,22,8,${0.2 + focus * 0.22}) 100%)` }} />
    </AbsoluteFill>
  );
};

/** Paper close to the lens, far out of focus, at the edges of the frame: it moves the other way from the desk. */
export const Foreground = ({ t, drift = 0, show = 1 }: { t: number; drift?: number; show?: number }) =>
  show <= 0 ? null : (
    <AbsoluteFill style={{ pointerEvents: 'none', opacity: show }}>
      <div style={{ position: 'absolute', left: -330 + drift * 0.22 + Math.sin(t * 0.37) * 14, top: 560 + Math.cos(t * 0.3) * 18, width: 470, height: 640, borderRadius: 14, background: 'linear-gradient(120deg, #FBF6EA, #E9DFC6)', transform: `rotate(${17 + Math.sin(t * 0.25) * 1.5}deg)`, filter: 'blur(30px)', opacity: 0.34 }} />
      <div style={{ position: 'absolute', right: -360 + drift * 0.3 + Math.cos(t * 0.31) * 16, top: -210 + Math.sin(t * 0.27) * 14, width: 560, height: 520, borderRadius: 14, background: 'linear-gradient(200deg, #F6EFDD, #DCCFAE)', transform: `rotate(${-24 + Math.cos(t * 0.21) * 1.5}deg)`, filter: 'blur(34px)', opacity: 0.3 }} />
    </AbsoluteFill>
  );

/**
 * The desk at night, for the one reel that is not a countdown: almost
 * dark, in the deep end of the same olive, with one desk lamp. `lamp`
 * (0–1) is how far it is on. Its light falls in a cone from the top left
 * onto a warm pool on the desk; far lights are soft discs behind; the
 * frame's edge goes to black.
 */
export const NightBackdrop = ({ t, frame, lamp = 1, drift = 0 }: { t: number; frame: number; lamp?: number; drift?: number }) => {
  const breathe = 1 + Math.sin(t * 1.7) * 0.015 + Math.sin(t * 5.3) * 0.006;
  const on = lamp * breathe;
  return (
    <AbsoluteFill style={{ overflow: 'hidden', background: '#0D100A' }}>
      <AbsoluteFill style={{ background: 'radial-gradient(120% 80% at 42% 46%, #2A3320 0%, #1B2114 46%, #0C0F09 100%)' }} />
      {/* Paper left out on the desk, barely there until the lamp finds it. */}
      <div style={{ position: 'absolute', left: -150 - drift * 0.05, top: 980, width: 560, height: 700, transform: 'rotate(-13deg)', background: '#E9E2CF', opacity: 0.05 + 0.07 * on, filter: 'blur(5px)', borderRadius: 6 }} />
      <div style={{ position: 'absolute', right: -190 + drift * 0.04, top: 420, width: 520, height: 640, transform: 'rotate(11deg)', background: '#E9E2CF', opacity: 0.04 + 0.05 * on, filter: 'blur(7px)', borderRadius: 6 }} />
      {/* Lights a long way off, out of focus. */}
      {Array.from({ length: 9 }, (_, i) => {
        const size = 70 + hash(i + 40) * 150;
        return (
          <div
            key={i}
            style={{
              position: 'absolute',
              left: hash(i + 41) * 1180 - 60 - drift * 0.03 * (1 + hash(i + 44)),
              top: 240 + hash(i + 42) * 900 + Math.sin(t * 0.3 + i) * 10,
              width: size,
              height: size,
              borderRadius: '50%',
              background: i % 3 === 0 ? 'rgba(255,196,120,0.9)' : i % 3 === 1 ? 'rgba(174,186,136,0.9)' : 'rgba(255,236,196,0.9)',
              filter: `blur(${22 + hash(i + 43) * 16}px)`,
              opacity: (0.06 + hash(i + 45) * 0.09) * (0.7 + 0.3 * Math.sin(t * (0.5 + hash(i + 46)) + i * 2)),
            }}
          />
        );
      })}
      {/* The lamp's cone, and the pool it makes on the desk. */}
      <AbsoluteFill style={{ clipPath: 'polygon(6% 15%, 24% 12%, 100% 78%, 62% 100%, 0% 100%, 0% 46%)', background: 'linear-gradient(140deg, rgba(255,214,140,0.5) 0%, rgba(255,214,140,0.16) 45%, rgba(255,214,140,0) 85%)', filter: 'blur(46px)', opacity: 0.55 * on }} />
      <AbsoluteFill style={{ background: `radial-gradient(60% 40% at 44% 50%, rgba(255,210,130,${0.34 * on}) 0%, rgba(255,196,110,${0.12 * on}) 45%, rgba(255,196,110,0) 75%)` }} />
      <Grain frame={frame} opacity={0.12} />
      <AbsoluteFill style={{ background: `radial-gradient(105% 80% at 46% 46%, rgba(0,0,0,0) 42%, rgba(4,6,2,${0.72 - 0.14 * on}) 100%)` }} />
    </AbsoluteFill>
  );
};

/** The lamp itself, leaning in from the top left: arm, shade, and the glow under the shade. */
export const DeskLamp = ({ t, lamp = 1 }: { t: number; lamp?: number }) => {
  const sway = Math.sin(t * 0.6) * 0.4;
  return (
    <div style={{ position: 'absolute', left: -96, top: 44, width: 420, height: 320, transform: `rotate(${sway}deg)`, transformOrigin: '0% 0%', pointerEvents: 'none' }}>
      <div style={{ position: 'absolute', left: -30, top: 60, width: 250, height: 22, borderRadius: 11, background: 'linear-gradient(to bottom, #4A5338, #20261A)', transform: 'rotate(18deg)', transformOrigin: '0% 50%', boxShadow: '0 10px 18px rgba(0,0,0,0.5)' }} />
      <div style={{ position: 'absolute', left: 196, top: 118, width: 34, height: 34, borderRadius: 17, background: 'radial-gradient(circle at 35% 30%, #6E7A52, #252B1C)' }} />
      <div style={{ position: 'absolute', left: 150, top: 120, width: 240, height: 140, transform: 'rotate(24deg)', transformOrigin: '30% 20%' }}>
        {/* The glow inside the shade, seen from underneath. */}
        <div style={{ position: 'absolute', left: 6, right: 6, bottom: -26, height: 60, borderRadius: '50%', background: `radial-gradient(ellipse at 50% 30%, rgba(255,240,200,${0.98 * lamp}) 0%, rgba(255,208,120,${0.75 * lamp}) 40%, rgba(255,190,90,0) 75%)`, filter: 'blur(6px)' }} />
        <div style={{ position: 'absolute', inset: 0, clipPath: 'polygon(28% 0%, 72% 0%, 100% 100%, 0% 100%)', background: 'linear-gradient(100deg, #58633F 0%, #3A432B 45%, #1C2115 100%)' }} />
        <div style={{ position: 'absolute', inset: 0, clipPath: 'polygon(28% 0%, 72% 0%, 100% 100%, 0% 100%)', background: `linear-gradient(to top, rgba(255,214,140,${0.5 * lamp}) 0%, rgba(255,214,140,0) 40%)` }} />
      </div>
    </div>
  );
};

/** The lens and the vignette over everything, for one look across the whole piece. */
export const Grade = ({ frame }: { frame: number }) => (
  <>
    <Grain frame={frame + 31} opacity={0.06} />
    <AbsoluteFill style={{ background: 'radial-gradient(150% 110% at 50% 40%, rgba(0,0,0,0) 66%, rgba(24,26,12,0.12) 100%)', pointerEvents: 'none' }} />
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

/**
 * Dust in the light: small soft specks drifting slowly up and across.
 * `front` draws the few, larger, out-of-focus ones nearer the lens.
 */
export const Motes = ({ t, front = false }: { t: number; front?: boolean }) => {
  const count = front ? 7 : 26;
  return (
    <AbsoluteFill style={{ pointerEvents: 'none' }}>
      {Array.from({ length: count }, (_, i) => {
        const k = i + (front ? 100 : 0);
        const size = front ? 14 + hash(k) * 16 : 3 + hash(k) * 6;
        const speed = 10 + hash(k + 1) * 22;
        const x = ((hash(k + 2) * 1180 + Math.sin(t * 0.4 + k) * 40 + t * (hash(k + 3) - 0.5) * 30) % 1180) - 50;
        const y = 1900 - ((hash(k + 4) * 2000 + t * speed) % 2000);
        const twinkle = 0.5 + 0.5 * Math.sin(t * (0.8 + hash(k + 5)) + k);
        return (
          <div
            key={i}
            style={{
              position: 'absolute',
              left: x,
              top: y,
              width: size,
              height: size,
              borderRadius: '50%',
              background: 'rgba(255,248,224,0.9)',
              filter: `blur(${front ? 5 + hash(k + 6) * 4 : 1 + hash(k + 6) * 1.5}px)`,
              opacity: (front ? 0.16 : 0.22 + 0.25 * hash(k + 7)) * twinkle,
            }}
          />
        );
      })}
    </AbsoluteFill>
  );
};
