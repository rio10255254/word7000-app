import type { CSSProperties, ReactNode } from 'react';
import { AbsoluteFill, Easing, interpolate, spring } from 'remotion';
import { AUTHORED_FPS, useFrame } from './time';
import { FONT } from './fonts';
import { Mascot, type Mood } from './Mascot';
import { K, Paper } from './collage';

// The beta's warm palette (Theme.swift, WarmTone) — the collage style shares it.
export const C = {
  ink: '#2B2620',
  inkSoft: '#7A6F62',
  inkFaint: '#B0A595',
  clay: '#C96442',
  sage: '#6E8F5E',
  brick: '#B4483A',
  slate: '#5B6B8C',
  ivory: '#FBF8F2',
  cream: '#FFF4E6',
};

export const easeOut = Easing.bezier(0.16, 1, 0.3, 1);
export const clamp = { extrapolateLeft: 'clamp', extrapolateRight: 'clamp' } as const;

/* ───────────────────────── Motion helpers ───────────────────────── */

/** Text that sharpens out of a blur while rising — the core motion of the piece. */
export const BlurIn = ({
  children,
  delay = 0,
  duration = 14,
  rise = 36,
  style,
}: {
  children: ReactNode;
  delay?: number;
  duration?: number;
  rise?: number;
  style?: CSSProperties;
}) => {
  const frame = useFrame();
  const t = interpolate(frame, [delay, delay + duration], [0, 1], { ...clamp, easing: easeOut });
  return (
    <span
      style={{
        display: 'inline-block',
        opacity: t,
        filter: `blur(${(1 - t) * 22}px)`,
        transform: `translateY(${(1 - t) * rise}px)`,
        ...style,
      }}
    >
      {children}
    </span>
  );
};

export const usePop = (delay: number, damping = 13, stiffness = 170) => {
  const frame = useFrame();
  const fps = AUTHORED_FPS;
  return spring({ frame: frame - delay, fps, config: { damping, stiffness, mass: 0.8 } });
};

/** A piece of paper slapped down onto the desk: drops from a little above, slightly more tilted. */
export const useSlap = (delay: number) => {
  const frame = useFrame();
  const t = interpolate(frame, [delay, delay + 7], [0, 1], { ...clamp, easing: Easing.in(Easing.quad) });
  return { opacity: Math.min(1, t * 3), scale: 1.12 - 0.12 * t, extraTilt: (1 - t) * 4 };
};

/** A rubber stamp pressed on: big and faint, then down hard. */
export const useStampPress = (delay: number) => {
  const frame = useFrame();
  const t = interpolate(frame, [delay, delay + 5], [0, 1], { ...clamp, easing: Easing.in(Easing.cubic) });
  const settle = interpolate(frame, [delay + 5, delay + 9], [0.94, 1], clamp);
  return { opacity: t, scale: frame < delay + 5 ? 1.8 - 0.86 * t : settle };
};

/** Gentle push-in so every hard cut lands with a little energy. */
export const Scene = ({ background, children }: { background: ReactNode; children: ReactNode }) => {
  const frame = useFrame();
  const scale = interpolate(frame, [0, 18], [1.05, 1], { extrapolateRight: 'clamp', easing: easeOut });
  return (
    <AbsoluteFill style={{ fontFamily: FONT, overflow: 'hidden' }}>
      <AbsoluteFill style={{ transform: `scale(${scale})` }}>
        {background}
        {children}
      </AbsoluteFill>
    </AbsoluteFill>
  );
};

export const headline: CSSProperties = {
  fontWeight: 900,
  fontSize: 128,
  lineHeight: 1.14,
  letterSpacing: '-0.01em',
  color: C.ink,
};

export const Headline = ({ lines, top = 170 }: { lines: string[]; top?: number }) => (
  <div style={{ position: 'absolute', top, left: 96, right: 96, ...headline }}>
    {lines.map((line, i) => (
      <div key={line}>
        <BlurIn delay={i * 6}>{line}</BlurIn>
      </div>
    ))}
  </div>
);

/** A bubble that pops out of the cat. */
export const PopBubble = ({ delay, origin, children, style }: { delay: number; origin: string; children: ReactNode; style?: CSSProperties }) => {
  const pop = usePop(delay, 11, 220);
  return (
    <div style={{ position: 'absolute', transform: `scale(${pop})`, transformOrigin: origin, opacity: Math.min(1, pop * 2), ...style }}>
      {children}
    </div>
  );
};

/** A squash-and-stretch hop, as the app's Mascot does when it is tapped. */
export const Hopping = ({ at, size, children }: { at: number[]; size: number; children: ReactNode }) => {
  const frame = useFrame();
  const current = [...at].reverse().find((a) => frame >= a) ?? -100;
  const f = frame - current;
  const active = f >= 0 && f <= 22;
  const sy = active ? interpolate(f, [0, 3, 8, 12, 22], [1, 0.86, 1.08, 0.9, 1], clamp) : 1;
  const sx = active ? interpolate(f, [0, 3, 8, 12, 22], [1, 1.1, 0.94, 1.08, 1], clamp) : 1;
  const lift = active ? interpolate(f, [0, 3, 8, 12], [0, 0, -0.22, 0], clamp) : 0;
  return <div style={{ transform: `translateY(${lift * size}px) scale(${sx}, ${sy})`, transformOrigin: '50% 100%' }}>{children}</div>;
};

/* ───────────────────────── Small icons ───────────────────────── */

export const Speaker = ({ color = C.clay, size = 60 }: { color?: string; size?: number }) => (
  <svg width={size} height={size} viewBox="0 0 24 24" fill="none">
    <path d="M4 9.5v5h3.5L12 18.5v-13L7.5 9.5H4z" fill={color} />
    <path d="M15.5 9a4 4 0 0 1 0 6M18 6.5a7.5 7.5 0 0 1 0 11" stroke={color} strokeWidth="1.9" strokeLinecap="round" />
  </svg>
);

export const Star = ({ size = 56 }: { size?: number }) => (
  <svg width={size} height={size} viewBox="0 0 24 24" fill="none">
    <path d="M12 3.5l2.6 5.3 5.8.8-4.2 4.1 1 5.8L12 16.8l-5.2 2.7 1-5.8-4.2-4.1 5.8-.8L12 3.5z" stroke={C.inkFaint} strokeWidth="1.6" strokeLinejoin="round" />
  </svg>
);

export const Check = ({ color, size = 46, draw = 1 }: { color: string; size?: number; draw?: number }) => (
  <svg width={size} height={size} viewBox="0 0 24 24">
    <path d="M5 12.5l4.5 4.5L19 7.5" fill="none" stroke={color} strokeWidth="2.8" strokeLinecap="round" strokeLinejoin="round" strokeDasharray={24} strokeDashoffset={24 * (1 - draw)} />
  </svg>
);

export const Cross = ({ color, size = 46 }: { color: string; size?: number }) => (
  <svg width={size} height={size} viewBox="0 0 24 24">
    <path d="M6.5 6.5l11 11M17.5 6.5l-11 11" stroke={color} strokeWidth="2.6" strokeLinecap="round" />
  </svg>
);


export const Flame = ({ size = 34 }: { size?: number }) => (
  <svg width={size} height={size} viewBox="0 0 24 24">
    <path d="M12 2.5c1 3.5 5.5 5.5 5.5 11a5.5 5.5 0 0 1-11 0c0-2.6 1.4-4.2 2.6-5.4.2 1.6.9 2.6 1.9 3C11 8.5 10.5 5.5 12 2.5z" fill="#FFB347" />
  </svg>
);

export const Target = ({ size = 34 }: { size?: number }) => (
  <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke={C.cream} strokeWidth="2">
    <circle cx="12" cy="12" r="9" />
    <circle cx="12" cy="12" r="5" />
    <circle cx="12" cy="12" r="1.4" fill={C.cream} />
  </svg>
);

export const ReviewIcon = () => (
  <svg width="46" height="46" viewBox="0 0 24 24" fill="none" stroke="#fff" strokeWidth="2.4" strokeLinecap="round" strokeLinejoin="round">
    <path d="M4.5 12a7.5 7.5 0 1 0 2.2-5.3" />
    <path d="M4.5 4.5v4h4" />
  </svg>
);

export const QuizIcon = () => (
  <svg width="46" height="46" viewBox="0 0 24 24" fill="none" stroke="#fff" strokeWidth="2.4" strokeLinecap="round" strokeLinejoin="round">
    <path d="M4 7l1.5 1.5L8 6M4 15l1.5 1.5L8 14M11 7.5h9M11 15.5h9" />
  </svg>
);

/* ───────────────────────── AI conversation pieces ───────────────────────── */

/** Reveals `text` a few characters per frame from `start`, with a caret while typing. */
export const Typewriter = ({ text, start, cps = 40, style }: { text: string; start: number; cps?: number; style?: CSSProperties }) => {
  const frame = useFrame();
  const fps = AUTHORED_FPS;
  const chars = Array.from(text);
  const shown = Math.max(0, Math.min(chars.length, Math.floor(((frame - start) * cps) / fps)));
  const typing = shown > 0 && shown < chars.length;
  return (
    <span style={{ whiteSpace: 'pre-wrap', ...style }}>
      {chars.slice(0, shown).join('')}
      {typing ? <span style={{ opacity: 0.5 }}>▍</span> : null}
    </span>
  );
};

/** Three dots bouncing while the cat thinks. */
export const TypingDots = ({ color = C.inkSoft }: { color?: string }) => {
  const frame = useFrame();
  return (
    <span style={{ display: 'inline-flex', gap: 10, alignItems: 'center', height: 40 }}>
      {[0, 1, 2].map((i) => (
        <span
          key={i}
          style={{
            width: 14,
            height: 14,
            borderRadius: '50%',
            background: color,
            opacity: 0.4 + 0.6 * Math.max(0, Math.sin(frame / 3 - i * 0.9)),
            transform: `translateY(${-6 * Math.max(0, Math.sin(frame / 3 - i * 0.9))}px)`,
          }}
        />
      ))}
    </span>
  );
};

/**
 * The cat saying something (CatSays in CatVoice.swift): its face beside a
 * bubble whose top-left corner points at it, tinted with the accent.
 */
export const CatSays = ({
  mood = 'idle',
  size = 120,
  children,
  style,
  phase = 0,
}: {
  mood?: Mood;
  size?: number;
  children: ReactNode;
  style?: CSSProperties;
  phase?: number;
}) => (
  <div style={{ display: 'flex', alignItems: 'flex-start', gap: 20, ...style }}>
    <div style={{ flexShrink: 0, marginTop: -size * 0.12 }}>
      <Mascot mood={mood} size={size} phase={phase} />
    </div>
    <div
      style={{
        flex: 1,
        background: 'rgba(201,100,66,0.09)',
        borderRadius: '12px 44px 44px 44px',
        padding: '28px 36px',
        fontSize: 42,
        lineHeight: 1.5,
        color: C.ink,
        fontWeight: 500,
      }}
    >
      {children}
    </div>
  </div>
);

/** What the learner asked, as their own clay bubble on the right (LearnerSays). */
export const LearnerSays = ({ children, style }: { children: ReactNode; style?: CSSProperties }) => (
  <div style={{ display: 'flex', justifyContent: 'flex-end', ...style }}>
    <div
      style={{
        background: C.clay,
        color: '#fff',
        fontWeight: 700,
        fontSize: 42,
        padding: '22px 34px',
        borderRadius: '44px 44px 12px 44px',
      }}
    >
      {children}
    </div>
  </div>
);

export const SparkleIcon = ({ color = C.clay, size = 44 }: { color?: string; size?: number }) => (
  <svg width={size} height={size} viewBox="0 0 24 24">
    <path d="M10 3c.6 3.6 2.4 5.4 6 6-3.6.6-5.4 2.4-6 6-.6-3.6-2.4-5.4-6-6 3.6-.6 5.4-2.4 6-6z" fill={color} />
    <path d="M18 13c.3 1.8 1.2 2.7 3 3-1.8.3-2.7 1.2-3 3-.3-1.8-1.2-2.7-3-3 1.8-.3 2.7-1.2 3-3z" fill={color} />
  </svg>
);

export const MicIcon = ({ color = '#fff', size = 52 }: { color?: string; size?: number }) => (
  <svg width={size} height={size} viewBox="0 0 24 24" fill="none">
    <rect x="9" y="3" width="6" height="12" rx="3" fill={color} />
    <path d="M5.5 11a6.5 6.5 0 0 0 13 0M12 17.5V21" stroke={color} strokeWidth="2" strokeLinecap="round" />
  </svg>
);

export const BulbIcon = ({ size = 40 }: { size?: number }) => (
  <svg width={size} height={size} viewBox="0 0 24 24">
    <path d="M12 3a6 6 0 0 0-3.5 10.9V16h7v-2.1A6 6 0 0 0 12 3z" fill="#E8A33A" />
    <rect x="9" y="17" width="6" height="2.2" rx="1" fill="#9A7A4A" />
    <rect x="10" y="19.8" width="4" height="1.8" rx="0.9" fill="#9A7A4A" />
  </svg>
);

/** A tappable strip of paper with an ink edge, the collage way; presses at `pressAt`. */
export const PaperButton = ({
  children,
  pressAt = -100,
  tint,
  color = C.clay,
  style,
}: {
  children: ReactNode;
  pressAt?: number;
  tint?: string;
  color?: string;
  style?: CSSProperties;
}) => {
  const frame = useFrame();
  const press = interpolate(frame, [pressAt - 3, pressAt, pressAt + 4], [1, 0.95, 1], clamp);
  const flash = interpolate(frame, [pressAt, pressAt + 10], [0.25, 0], clamp);
  return (
    <div style={{ position: 'absolute', transform: `scale(${press})`, ...style }}>
      <Paper kind="ivory" grain={0.5} style={{ inset: 0, boxShadow: `inset 0 0 0 ${1.5 * K}px rgba(43,38,32,0.55)` }}>
        {tint ? <div style={{ position: 'absolute', inset: 0, background: tint }} /> : null}
        <div style={{ position: 'absolute', inset: 0, background: `rgba(201,100,66,${frame >= pressAt ? flash : 0})` }} />
        <div
          style={{
            position: 'absolute',
            inset: 0,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            gap: 16,
            color,
            fontSize: 44,
            fontWeight: 700,
            fontFamily: FONT,
          }}
        >
          {children}
        </div>
      </Paper>
    </div>
  );
};

/** A small grey footnote, like the app's AI disclaimers. */
export const Footnote = ({ children, delay = 0, style }: { children: ReactNode; delay?: number; style?: CSSProperties }) => (
  <div style={{ position: 'absolute', left: 96, right: 96, fontSize: 30, color: C.inkFaint, fontWeight: 500, ...style }}>
    <BlurIn delay={delay} rise={10}>
      {children}
    </BlurIn>
  </div>
);
