import type { CSSProperties } from 'react';
import { useId } from 'react';
import { useCurrentFrame, useVideoConfig } from 'remotion';

/**
 * 小笨貓 — the app's ginger cat, ported shape-for-shape from
 * ios/Word7000/Design/Mascot.swift (claude/friendly-darwin-obc3r1).
 * Drawn on a 100×100 square; `size` scales it.
 */
export type Mood = 'idle' | 'smug' | 'happy' | 'annoyed';

const TOP = '#FAC48F';
const BOTTOM = '#E38A57';
const CREAM = '#FFF2DB';
const INNER_EAR = '#FAB3A8';
const NOSE = '#ED8585';
const INK = '#2B1A12';
const BLUSH = '#F28073';
const GOLD = '#FFDB66';
const AMBER = '#FF994D';

/** Cloud-edged squircle: MascotFluff(tufts: 20, puff: 0.015, roundness: 0.9, settle: 0.92). */
function fluffPath(cx: number, cy: number, rx: number, ry: number) {
  const tufts = 20;
  const puff = 0.015;
  const roundness = 0.9;
  const settle = 0.92;
  const pt = (angle: number, scale: number) => {
    const c = Math.cos(angle);
    const s = Math.sin(angle);
    const x = Math.sign(c) * Math.abs(c) ** roundness;
    let y = Math.sign(s) * Math.abs(s) ** roundness;
    if (y > 0) y *= settle;
    return `${(cx + x * rx * scale).toFixed(2)} ${(cy + y * ry * scale).toFixed(2)}`;
  };
  const step = (2 * Math.PI) / tufts;
  let d = `M${pt(0, 1 - puff)}`;
  for (let i = 0; i < tufts; i++) {
    const from = i * step;
    d += ` Q${pt(from + step / 2, 1 + puff)} ${pt(from + step, 1 - puff)}`;
  }
  return `${d} Z`;
}

const BODY = fluffPath(50, 57, 45, 37);

/** Ear with a softly rounded tip, in a w×h box at (x, y). */
const earPath = (x: number, y: number, w: number, h: number) =>
  `M${x} ${y + h} L${x + w * 0.36} ${y + h * 0.14} Q${x + w / 2} ${y - h * 0.04} ${x + w * 0.64} ${y + h * 0.14} L${x + w} ${y + h} Z`;

const blinking = (t: number) => {
  const cycle = t % 4.6;
  if (cycle < 0.13) return true;
  return cycle > 0.3 && cycle < 0.42 && Math.floor(t / 4.6) % 3 === 0;
};

const Eye = ({ cx, side, mood, blink, clipId }: { cx: number; side: number; mood: Mood; blink: boolean; clipId: string }) => {
  if (mood === 'happy') {
    return <path d={`M${cx - 6} 52.5 Q${cx} 42.5 ${cx + 6} 52.5`} fill="none" stroke={INK} strokeWidth={3.5} strokeLinecap="round" />;
  }
  if (mood === 'annoyed') {
    const dir = side < 0 ? 1 : -1;
    return (
      <path
        d={`M${cx - 4.25 * dir} 45.5 L${cx + 4.25 * dir} 50 L${cx - 4.25 * dir} 54.5`}
        fill="none"
        stroke={INK}
        strokeWidth={2.6}
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    );
  }
  // Heavy-lidded resting face (idle), lower and slanted in when smug.
  const d = 11;
  const lid = mood === 'smug' ? 0.58 : 0.4;
  const tilt = mood === 'smug' ? side * -8 : 0;
  const top = 50 - d / 2;
  const lidY = top + d * lid;
  return (
    <g transform={blink ? `translate(0 50) scale(1 0.15) translate(0 -50)` : undefined}>
      <clipPath id={clipId}>
        <rect x={cx - d} y={lidY} width={d * 2} height={d} />
      </clipPath>
      <g clipPath={`url(#${clipId})`}>
        <circle cx={cx} cy={50} r={d / 2} fill={INK} />
        <circle cx={cx + 2.31} cy={lidY + 0.66 + 1.43} r={1.43} fill="#fff" />
      </g>
      <rect
        x={cx - (d * 1.3) / 2}
        y={lidY - 1.2}
        width={d * 1.3}
        height={2.4}
        rx={1.2}
        fill={INK}
        transform={`rotate(${tilt} ${cx} ${lidY})`}
      />
    </g>
  );
};

const Mouth = ({ mood }: { mood: Mood }) => {
  switch (mood) {
    case 'happy':
      return <path d="M44 59.5 L56 59.5 Q50 71.5 44 59.5 Z" fill={INK} />;
    case 'smug':
      return <path d="M45 62.5 Q50 65.7 55 60.5" fill="none" stroke={INK} strokeWidth={2.2} strokeLinecap="round" />;
    case 'annoyed':
      return (
        <path
          d="M45.5 63.8 L47.75 61.2 L50 63.8 L52.25 61.2 L54.5 63.8"
          fill="none"
          stroke={INK}
          strokeWidth={2}
          strokeLinecap="round"
          strokeLinejoin="round"
        />
      );
    default:
      return (
        <path
          d="M45.5 61.2 Q47.75 66.4 50 61.2 Q52.25 66.4 54.5 61.2"
          fill="none"
          stroke={INK}
          strokeWidth={2}
          strokeLinecap="round"
          strokeLinejoin="round"
        />
      );
  }
};

const Sparkle = ({ x, y, size, wave }: { x: number; y: number; size: number; wave: number }) => {
  const s = size * (0.6 + 0.4 * wave);
  return (
    <path
      d={`M${x} ${y - s} Q${x} ${y} ${x + s} ${y} Q${x} ${y} ${x} ${y + s} Q${x} ${y} ${x - s} ${y} Q${x} ${y} ${x} ${y - s} Z`}
      fill="url(#sparkle)"
      opacity={0.5 + 0.5 * wave}
    />
  );
};

export const Mascot = ({
  mood = 'idle',
  size = 300,
  blush = false,
  sparkles = false,
  /** Seconds offset so two cats on screen don't blink together. */
  phase = 0,
}: {
  mood?: Mood;
  size?: number;
  blush?: boolean;
  sparkles?: boolean;
  phase?: number;
}) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const t = frame / fps + phase + 1;
  const uid = useId().replace(/:/g, '');

  const breathe = Math.sin(t * 2.1) * 0.022;
  const opensEyes = mood === 'idle' || mood === 'smug';
  const blink = opensEyes && blinking(t);
  const tailSway = mood === 'happy' ? Math.sin(t * 6) * 14 : Math.sin(t * 2.6) * 6;
  const droop = mood === 'happy' ? -4 : mood === 'smug' ? 8 : mood === 'annoyed' ? 14 : 0;
  const quiver = Math.sin(t * 2.1) * 2;
  const cheek = blush ? 0.9 : mood === 'happy' ? 0.5 : 0;
  const sx = 1 - breathe * 0.6;
  const sy = 1 + breathe;

  return (
    <svg width={size} height={size} viewBox="0 0 100 100" style={{ overflow: 'visible' }}>
      <defs>
        <linearGradient id={`fur${uid}`} x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor={TOP} />
          <stop offset="1" stopColor={BOTTOM} />
        </linearGradient>
        <linearGradient id={`tail${uid}`} gradientUnits="userSpaceOnUse" x1="0" y1="0" x2="0" y2="100">
          <stop offset="0" stopColor={TOP} />
          <stop offset="1" stopColor={BOTTOM} />
        </linearGradient>
        <linearGradient id="sparkle" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor={GOLD} />
          <stop offset="1" stopColor={AMBER} />
        </linearGradient>
        <filter id={`soft${uid}`} x="-50%" y="-50%" width="200%" height="200%">
          <feGaussianBlur stdDeviation="2.5" />
        </filter>
        <filter id={`bodyShadow${uid}`} x="-30%" y="-30%" width="160%" height="170%">
          <feDropShadow dx="0" dy="4" stdDeviation="3.5" floodColor={BOTTOM} floodOpacity="0.3" />
        </filter>
      </defs>

      <ellipse cx={50} cy={94} rx={29} ry={4} fill="rgba(0,0,0,0.14)" filter={`url(#soft${uid})`} />

      <g transform={`translate(50 100) scale(${sx} ${sy}) translate(-50 -100)`}>
        <path
          d="M74 86 Q104 84 98 52"
          fill="none"
          stroke={`url(#tail${uid})`}
          strokeWidth={12}
          strokeLinecap="round"
          transform={`rotate(${tailSway} 74 86)`}
        />
        {[-1, 1].map((side) => {
          const cx = 50 + side * 23;
          const cy = 17;
          return (
            <g key={side} transform={`rotate(${side * (18 + droop)} ${cx} ${cy + 10})`}>
              <path d={earPath(cx - 11, cy - 10, 22, 20)} fill={`url(#fur${uid})`} />
              <path d={earPath(cx - 5.5, cy - 5.5, 11, 12)} fill={INNER_EAR} />
            </g>
          );
        })}

        <g filter={`url(#bodyShadow${uid})`}>
          <path d={BODY} fill={`url(#fur${uid})`} />
          <path d="M46 23 Q47.6 14.9 50 14 Q49.6 18.5 51.6 16.7 Q52.4 20.3 54 23 Z" fill={TOP} />
          <path d="M90 57.75 L96.5 60.69 L91.95 63.21 L96.18 65.94 L90 68.25 Z" fill={TOP} />
          <path d="M10 57.75 L3.5 60.69 L8.05 63.21 L3.82 65.94 L10 68.25 Z" fill={TOP} />
        </g>
        <path d="M45.5 70.2 L47.75 66.2 L50 70.2 L52.25 66.2 L54.5 70.2 Z" fill={CREAM} />
        <ellipse cx={50} cy={79} rx={17} ry={10} fill={CREAM} />
        <ellipse cx={35} cy={92} rx={7} ry={3.5} fill={CREAM} />
        <ellipse cx={65} cy={92} rx={7} ry={3.5} fill={CREAM} />

        <Eye cx={36} side={-1} mood={mood} blink={blink} clipId={`eyeL${uid}`} />
        <Eye cx={64} side={1} mood={mood} blink={blink} clipId={`eyeR${uid}`} />
        <ellipse cx={27} cy={58} rx={5} ry={2.5} fill={BLUSH} opacity={cheek} />
        <ellipse cx={73} cy={58} rx={5} ry={2.5} fill={BLUSH} opacity={cheek} />
        {[-1, 1].map((side) =>
          [-8, 8].map((angle, i) => {
            const cx = 50 + side * 27;
            const cy = 60 + (i === 0 ? -1.75 : 1.75);
            return (
              <rect
                key={`${side}${angle}`}
                x={cx - 6}
                y={cy - 0.5}
                width={12}
                height={1}
                rx={0.5}
                fill={INK}
                opacity={0.35}
                transform={`rotate(${side * (angle - quiver)} ${cx} ${cy})`}
              />
            );
          }),
        )}
        <path d="M47.75 56.1 L52.25 56.1 L50 58.9 Z" fill={NOSE} stroke={NOSE} strokeWidth={1.2} strokeLinejoin="round" />
        <Mouth mood={mood} />
      </g>

      {sparkles
        ? [
            { x: 14, y: 14, s: 6, i: 0 },
            { x: 88, y: 8, s: 8, i: 1 },
            { x: 92, y: 40, s: 6, i: 2 },
          ].map(({ x, y, s, i }) => (
            <Sparkle key={i} x={x} y={y} size={s} wave={Math.abs(Math.sin(t * 2 + i * 2.1))} />
          ))
        : null}
    </svg>
  );
};

/** A line from the cat in a cream bubble (MascotBubble), tail pointing at it. */
export const Bubble = ({
  text,
  fontSize = 44,
  pointing = 'bottom',
  style,
}: {
  text: string;
  fontSize?: number;
  pointing?: 'bottom' | 'left' | 'right';
  style?: CSSProperties;
}) => {
  const tail = fontSize * 0.55;
  const tailStyle: CSSProperties =
    pointing === 'bottom'
      ? { left: '50%', bottom: -tail * 0.55, transform: 'translateX(-50%)', borderWidth: `${tail * 0.6}px ${tail * 0.55}px 0`, borderColor: '#FFFAF0 transparent transparent' }
      : pointing === 'left'
        ? { left: -tail * 0.55, top: '50%', transform: 'translateY(-50%)', borderWidth: `${tail * 0.55}px ${tail * 0.6}px ${tail * 0.55}px 0`, borderColor: 'transparent #FFFAF0 transparent transparent' }
        : { right: -tail * 0.55, top: '50%', transform: 'translateY(-50%)', borderWidth: `${tail * 0.55}px 0 ${tail * 0.55}px ${tail * 0.6}px`, borderColor: 'transparent transparent transparent #FFFAF0' };
  return (
    <div
      style={{
        position: 'relative',
        display: 'inline-block',
        background: '#FFFAF0',
        color: '#3B2619',
        fontWeight: 700,
        fontSize,
        lineHeight: 1.35,
        padding: `${fontSize * 0.42}px ${fontSize * 0.7}px`,
        borderRadius: fontSize * 0.75,
        boxShadow: '0 14px 36px rgba(59,38,25,0.18)',
        textAlign: 'center',
        ...style,
      }}
    >
      {text}
      <div style={{ position: 'absolute', width: 0, height: 0, borderStyle: 'solid', ...tailStyle }} />
    </div>
  );
};
