import type { CSSProperties, ReactNode } from 'react';
import { staticFile } from 'remotion';

/**
 * The "紙張拼貼" (paper collage) app style, ported from
 * ios/Word7000/Design/Collage.swift (claude/friendly-darwin-obc3r1):
 * graph paper, ruled index cards with a red margin, masking tape, torn
 * edges, halftone, loose charcoal lines and rubber stamps. No drop shadows.
 *
 * Sizes are the app's points × K, the scale of a 402 pt iPhone to 1080 px.
 */
export const K = 1080 / 402;

export const COLLAGE = {
  desk: '#F3EEE4',
  ink: '#2B2620',
  gridLine: '#C9D9D2',
  ruleLine: '#BCD0DE',
  margin: '#E39787',
  tape: '#ECE0C4',
  clay: '#C96442',
};

export type PaperKind = 'graph' | 'ruled' | 'ivory' | 'peach' | 'mustard' | 'sage';

const PAPER: Record<PaperKind, string> = {
  graph: '#F2F4EC',
  ruled: '#FBF8F2',
  ivory: '#FBF8F2',
  peach: '#F2CDB0',
  mustard: '#DDB04E',
  sage: '#DCE5D0',
};

const grid = 14 * K;
const rule = 26 * K;
const marginX = 28 * K;

const paperPattern = (kind: PaperKind): CSSProperties => {
  if (kind === 'graph') {
    const line = 0.6 * K;
    return {
      backgroundImage: `linear-gradient(to right, ${COLLAGE.gridLine} ${line}px, transparent ${line}px), linear-gradient(to bottom, ${COLLAGE.gridLine} ${line}px, transparent ${line}px)`,
      backgroundSize: `${grid}px ${grid}px`,
    };
  }
  if (kind === 'ruled') {
    const line = 0.8 * K;
    const m = 1.2 * K;
    return {
      backgroundImage: `linear-gradient(to right, transparent ${marginX}px, ${COLLAGE.margin} ${marginX}px, ${COLLAGE.margin} ${marginX + m}px, transparent ${marginX + m}px), repeating-linear-gradient(to bottom, transparent 0, transparent ${rule - line}px, ${COLLAGE.ruleLine} ${rule - line}px, ${COLLAGE.ruleLine} ${rule}px)`,
    };
  }
  return {};
};

/** A sheet of paper, with the app's faint grain multiplied over it. */
export const Paper = ({
  kind,
  style,
  grain = 0.6,
  children,
}: {
  kind: PaperKind;
  style?: CSSProperties;
  grain?: number;
  children?: ReactNode;
}) => (
  <div style={{ position: 'absolute', background: PAPER[kind], ...paperPattern(kind), ...style }}>
    <div
      style={{
        position: 'absolute',
        inset: 0,
        backgroundImage: `url(${staticFile('paper-grain.png')})`,
        backgroundSize: `${160 * K}px ${160 * K}px`,
        opacity: grain,
        mixBlendMode: 'multiply',
        pointerEvents: 'none',
      }}
    />
    {children}
  </div>
);

/** The bare desk paper behind every screen. */
export const Desk = ({ kind = 'ivory' as PaperKind | 'desk' }: { kind?: PaperKind | 'desk' }) =>
  kind === 'desk' ? (
    <Paper kind="ivory" grain={0.8} style={{ inset: 0, background: COLLAGE.desk }} />
  ) : (
    <Paper kind={kind} grain={0.8} style={{ inset: 0 }} />
  );

type Edge = 'top' | 'right' | 'bottom' | 'left';

/** TornEdgeShape as a CSS clip-path for a w×h box: the same seed always tears the same way. */
export const torn = (w: number, h: number, edges: Edge[], seed = 1, depthPt = 4) => {
  const depth = depthPt * K;
  const step = 9 * K;
  const jag = (i: number, side: number) => {
    const v = Math.sin((i * 37 + side * 101 + seed * 13) * 12.9898) * 43758.5453;
    return (v - Math.floor(v)) * depth;
  };
  const pts: [number, number][] = [];
  pts.push([0, edges.includes('top') ? jag(0, 0) : 0]);
  if (edges.includes('top')) for (let x = step, i = 1; x < w; x += step, i++) pts.push([x, jag(i, 0)]);
  pts.push([w, 0]);
  if (edges.includes('right')) for (let y = step, i = 1; y < h; y += step, i++) pts.push([w - jag(i, 1), y]);
  pts.push([w, h]);
  if (edges.includes('bottom')) for (let x = w - step, i = 1; x > 0; x -= step, i++) pts.push([x, h - jag(i, 2)]);
  pts.push([0, h]);
  if (edges.includes('left')) for (let y = h - step, i = 1; y > 0; y -= step, i++) pts.push([jag(i, 3), y]);
  return `polygon(${pts.map(([x, y]) => `${x.toFixed(1)}px ${y.toFixed(1)}px`).join(', ')})`;
};

/** A strip of masking tape. */
export const Tape = ({ width = 64, angle = -6, style }: { width?: number; angle?: number; style?: CSSProperties }) => (
  <div
    style={{
      position: 'absolute',
      width: width * K,
      height: 20 * K,
      background: COLLAGE.tape,
      opacity: 0.82,
      transform: `rotate(${angle}deg)`,
      borderLeft: `${1.5 * K}px solid rgba(255,255,255,0.35)`,
      borderRight: `${1.5 * K}px solid rgba(255,255,255,0.35)`,
      ...style,
    }}
  />
);

/** A patch of printed halftone dots. */
export const Halftone = ({
  width,
  height,
  color = 'rgba(43,38,32,0.2)',
  style,
}: {
  width: number;
  height: number;
  color?: string;
  style?: CSSProperties;
}) => {
  const spacing = 6 * K;
  const r = 1.1 * K;
  const dots: ReactNode[] = [];
  for (let y = spacing / 2, row = 0; y < height; y += spacing * 0.87, row++) {
    for (let x = row % 2 === 0 ? spacing / 2 : spacing; x < width; x += spacing) {
      dots.push(<circle key={`${x}-${y}`} cx={x} cy={y} r={r} fill={color} />);
    }
  }
  return (
    <svg width={width} height={height} style={{ position: 'absolute', ...style }}>
      {dots}
    </svg>
  );
};

/** A charcoal scribble of loops, drawn on as `draw` goes 0 → 1. */
export const InkLoops = ({
  width,
  height,
  count = 4,
  color = COLLAGE.ink,
  strokeWidth = 1.6 * K,
  draw = 1,
  style,
}: {
  width: number;
  height: number;
  count?: number;
  color?: string;
  strokeWidth?: number;
  draw?: number;
  style?: CSSProperties;
}) => {
  const step = width / count;
  const y = height - height * 0.3;
  let d = `M0 ${y}`;
  for (let i = 0; i < count; i++) {
    const x = step * i;
    d += ` C${x + step * 0.2} 0 ${x + step * 0.9} 0 ${x + step * 0.7} ${y}`;
    d += ` Q${x + step * 0.5} ${height} ${x + step} ${y}`;
  }
  return (
    <svg width={width} height={height} style={{ position: 'absolute', overflow: 'visible', ...style }}>
      <path
        d={d}
        fill="none"
        stroke={color}
        strokeWidth={strokeWidth}
        strokeLinecap="round"
        pathLength={1}
        strokeDasharray={1}
        strokeDashoffset={1 - draw}
      />
    </svg>
  );
};

/** A rubber stamp: two rings round a short text, pressed on at an angle. */
export const Stamp = ({
  size,
  angle = -10,
  color = COLLAGE.clay,
  children,
  style,
}: {
  size: number;
  angle?: number;
  color?: string;
  children: ReactNode;
  style?: CSSProperties;
}) => (
  <div
    style={{
      position: 'absolute',
      width: size,
      height: size,
      borderRadius: '50%',
      border: `${Math.max(2, size * 0.04)}px solid ${color}`,
      transform: `rotate(${angle}deg)`,
      color,
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      textAlign: 'center',
      ...style,
    }}
  >
    <div
      style={{
        position: 'absolute',
        inset: size * 0.08,
        borderRadius: '50%',
        border: `${Math.max(1, size * 0.012)}px solid ${color}`,
        opacity: 0.8,
      }}
    />
    {children}
  </div>
);
