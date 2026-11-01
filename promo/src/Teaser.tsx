import type { CSSProperties, ReactElement, ReactNode } from 'react';
import {
  AbsoluteFill,
  Easing,
  Img,
  Sequence,
  interpolate,
  spring,
  staticFile,
  useCurrentFrame,
  useVideoConfig,
} from 'remotion';
import { COLLAGE, Desk, Halftone, InkLoops, K, Paper, Stamp, Tape, torn } from './collage';
import { FONT, SERIF } from './fonts';
import { Bubble, Mascot } from './Mascot';

// The beta's warm palette (Theme.swift, WarmTone) — the collage style shares it.
const C = {
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

// Scene timing in frames (30 fps). Total = 300 frames = 10 seconds.
const SCENES = [
  { id: 'hook', from: 0, duration: 60 },
  { id: 'meet', from: 60, duration: 36 },
  { id: 'card', from: 96, duration: 60 },
  { id: 'quiz', from: 156, duration: 54 },
  { id: 'today', from: 210, duration: 48 },
  { id: 'end', from: 258, duration: 42 },
] as const;

export const TEASER_DURATION = SCENES[SCENES.length - 1].from + SCENES[SCENES.length - 1].duration;

const easeOut = Easing.bezier(0.16, 1, 0.3, 1);
const clamp = { extrapolateLeft: 'clamp', extrapolateRight: 'clamp' } as const;

/* ───────────────────────── Motion helpers ───────────────────────── */

/** Text that sharpens out of a blur while rising — the core motion of the piece. */
const BlurIn = ({
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
  const frame = useCurrentFrame();
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

const usePop = (delay: number, damping = 13, stiffness = 170) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  return spring({ frame: frame - delay, fps, config: { damping, stiffness, mass: 0.8 } });
};

/** A piece of paper slapped down onto the desk: drops from a little above, slightly more tilted. */
const useSlap = (delay: number) => {
  const frame = useCurrentFrame();
  const t = interpolate(frame, [delay, delay + 7], [0, 1], { ...clamp, easing: Easing.in(Easing.quad) });
  return { opacity: Math.min(1, t * 3), scale: 1.12 - 0.12 * t, extraTilt: (1 - t) * 4 };
};

/** A rubber stamp pressed on: big and faint, then down hard. */
const useStampPress = (delay: number) => {
  const frame = useCurrentFrame();
  const t = interpolate(frame, [delay, delay + 5], [0, 1], { ...clamp, easing: Easing.in(Easing.cubic) });
  const settle = interpolate(frame, [delay + 5, delay + 9], [0.94, 1], clamp);
  return { opacity: t, scale: frame < delay + 5 ? 1.8 - 0.86 * t : settle };
};

/** Gentle push-in so every hard cut lands with a little energy. */
const Scene = ({ background, children }: { background: ReactNode; children: ReactNode }) => {
  const frame = useCurrentFrame();
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

const headline: CSSProperties = {
  fontWeight: 900,
  fontSize: 128,
  lineHeight: 1.14,
  letterSpacing: '-0.01em',
  color: C.ink,
};

const Headline = ({ lines, top = 170 }: { lines: string[]; top?: number }) => (
  <div style={{ position: 'absolute', top, left: 96, right: 96, ...headline }}>
    {lines.map((line, i) => (
      <div key={line}>
        <BlurIn delay={i * 6}>{line}</BlurIn>
      </div>
    ))}
  </div>
);

/** A bubble that pops out of the cat. */
const PopBubble = ({ delay, origin, children, style }: { delay: number; origin: string; children: ReactNode; style?: CSSProperties }) => {
  const pop = usePop(delay, 11, 220);
  return (
    <div style={{ position: 'absolute', transform: `scale(${pop})`, transformOrigin: origin, opacity: Math.min(1, pop * 2), ...style }}>
      {children}
    </div>
  );
};

/** A squash-and-stretch hop, as the app's Mascot does when it is tapped. */
const Hopping = ({ at, size, children }: { at: number[]; size: number; children: ReactNode }) => {
  const frame = useCurrentFrame();
  const current = [...at].reverse().find((a) => frame >= a) ?? -100;
  const f = frame - current;
  const active = f >= 0 && f <= 22;
  const sy = active ? interpolate(f, [0, 3, 8, 12, 22], [1, 0.86, 1.08, 0.9, 1], clamp) : 1;
  const sx = active ? interpolate(f, [0, 3, 8, 12, 22], [1, 1.1, 0.94, 1.08, 1], clamp) : 1;
  const lift = active ? interpolate(f, [0, 3, 8, 12], [0, 0, -0.22, 0], clamp) : 0;
  return <div style={{ transform: `translateY(${lift * size}px) scale(${sx}, ${sy})`, transformOrigin: '50% 100%' }}>{children}</div>;
};

/* ───────────────────────── Small icons ───────────────────────── */

const Speaker = ({ color = C.clay, size = 60 }: { color?: string; size?: number }) => (
  <svg width={size} height={size} viewBox="0 0 24 24" fill="none">
    <path d="M4 9.5v5h3.5L12 18.5v-13L7.5 9.5H4z" fill={color} />
    <path d="M15.5 9a4 4 0 0 1 0 6M18 6.5a7.5 7.5 0 0 1 0 11" stroke={color} strokeWidth="1.9" strokeLinecap="round" />
  </svg>
);

const Star = ({ size = 56 }: { size?: number }) => (
  <svg width={size} height={size} viewBox="0 0 24 24" fill="none">
    <path d="M12 3.5l2.6 5.3 5.8.8-4.2 4.1 1 5.8L12 16.8l-5.2 2.7 1-5.8-4.2-4.1 5.8-.8L12 3.5z" stroke={C.inkFaint} strokeWidth="1.6" strokeLinejoin="round" />
  </svg>
);

const Check = ({ color, size = 46, draw = 1 }: { color: string; size?: number; draw?: number }) => (
  <svg width={size} height={size} viewBox="0 0 24 24">
    <path d="M5 12.5l4.5 4.5L19 7.5" fill="none" stroke={color} strokeWidth="2.8" strokeLinecap="round" strokeLinejoin="round" strokeDasharray={24} strokeDashoffset={24 * (1 - draw)} />
  </svg>
);

const Cross = ({ color, size = 46 }: { color: string; size?: number }) => (
  <svg width={size} height={size} viewBox="0 0 24 24">
    <path d="M6.5 6.5l11 11M17.5 6.5l-11 11" stroke={color} strokeWidth="2.6" strokeLinecap="round" />
  </svg>
);

/* ───────────────────────── 1. 又在滑手機？ ───────────────────────── */

const HookScene = () => {
  const frame = useCurrentFrame();
  const rise = usePop(8, 14, 120);
  const draw = interpolate(frame, [10, 22], [0, 1], { ...clamp, easing: easeOut });
  const scrap = useSlap(22);
  return (
    <Scene background={<Desk kind="desk" />}>
      <Headline lines={['又在', '滑手機？']} />
      {/* A hurried charcoal underline under 滑手機. */}
      <InkLoops width={430} height={46} count={4} strokeWidth={6} draw={draw} style={{ left: 96, top: 480 }} />

      <div style={{ position: 'absolute', left: 260, top: 1150, transform: `translateY(${(1 - rise) * 900}px)` }}>
        <Hopping at={[40]} size={560}>
          <Mascot mood="smug" size={560} />
        </Hopping>
      </div>

      {/* Its line, on a torn scrap of ruled paper taped to the desk. */}
      <div
        style={{
          position: 'absolute',
          left: 100,
          top: 790,
          width: 640,
          height: 290,
          opacity: scrap.opacity,
          transform: `rotate(${-2.5 - scrap.extraTilt}deg) scale(${scrap.scale})`,
        }}
      >
        <Paper kind="ruled" style={{ inset: 0, clipPath: torn(640, 290, ['bottom', 'right'], 4) }}>
          <div style={{ position: 'absolute', left: 110, top: 46, fontSize: 56, fontWeight: 900, lineHeight: `${26 * K}px`, color: C.ink }}>
            你滑手機的時間
            <br />
            夠背十個字了。
          </div>
        </Paper>
        <Tape width={58} angle={-6} style={{ left: 250, top: -26 }} />
      </div>
    </Scene>
  );
};

/* ───────────────────────── 2. 認識一下，小字團。 ───────────────────────── */

const MeetScene = () => {
  const slap = useSlap(0);
  const pop = usePop(4, 10, 200);
  const stamp = useStampPress(16);
  const w = 820;
  const h = 860;
  return (
    <Scene background={<Desk kind="graph" />}>
      {/* A torn cut of peach paper, halftone in its corner, taped down. */}
      <div
        style={{
          position: 'absolute',
          left: (1080 - w) / 2,
          top: 230,
          width: w,
          height: h,
          opacity: slap.opacity,
          transform: `rotate(${-3 - slap.extraTilt}deg) scale(${slap.scale})`,
        }}
      >
        <Paper kind="peach" style={{ inset: 0, clipPath: torn(w, h, ['bottom', 'left'], 5, 6) }}>
          <Halftone width={300} height={200} color="rgba(43,38,32,0.16)" style={{ right: 0, top: 0 }} />
        </Paper>
        <Tape width={70} angle={-8} style={{ left: 40, top: -24 }} />
        <Tape width={70} angle={7} style={{ right: 40, top: -24 }} />
      </div>
      <div style={{ position: 'absolute', left: 240, top: 300, transform: `scale(${pop})`, transformOrigin: '50% 100%' }}>
        <Hopping at={[6, 20]} size={600}>
          <Mascot mood="happy" size={600} sparkles blush />
        </Hopping>
      </div>

      <div style={{ position: 'absolute', left: 96, top: 1180, ...headline }}>
        <BlurIn delay={6} style={{ fontSize: 72, fontWeight: 700, color: C.inkSoft }}>
          認識一下，
        </BlurIn>
        <br />
        <BlurIn delay={10} style={{ fontSize: 176 }}>
          小字團。
        </BlurIn>
      </div>
      <Stamp
        size={250}
        angle={-12}
        style={{ right: 80, top: 1480, opacity: stamp.opacity, transform: `rotate(-12deg) scale(${stamp.scale})` }}
      >
        <div style={{ fontWeight: 900, fontSize: 54, lineHeight: 1.15 }}>
          毒舌
          <br />
          陪讀
        </div>
      </Stamp>
    </Scene>
  );
};

/* ───────────────────────── 3. 索引卡 ───────────────────────── */

const FLIP_AT = 22;
const KNOW_AT = 40;

const CardScene = () => {
  const frame = useCurrentFrame();
  const rise = usePop(2, 16);
  const flip = interpolate(frame, [FLIP_AT, FLIP_AT + 5, FLIP_AT + 10], [1, 0, 1], { ...clamp, easing: Easing.inOut(Easing.quad) });
  const back = frame >= FLIP_AT + 5;
  const showPress = interpolate(frame, [FLIP_AT - 4, FLIP_AT - 1, FLIP_AT + 2], [1, 0.94, 1], clamp);
  const knowPress = interpolate(frame, [KNOW_AT - 3, KNOW_AT, KNOW_AT + 4], [1, 0.93, 1], clamp);
  const buttonsIn = interpolate(frame, [FLIP_AT + 4, FLIP_AT + 12], [0, 1], { ...clamp, easing: easeOut });

  const top = 660;
  const left = 64;
  const w = 1080 - left * 2;
  const h = 930;
  const enter = `translateY(${(1 - rise) * 1000}px)`;
  // Text sits clear of the red margin (28 pt) plus the app's 16 pt inset.
  const pad = 28 * K + 16 * K;

  return (
    <Scene background={<Desk kind="desk" />}>
      <Headline lines={['一張卡，', '一個字。']} top={140} />

      {/* Graph paper for the next card, peeking out underneath. */}
      <Paper kind="graph" style={{ left, top: top + 24, width: w, height: h, transform: `${enter} rotate(2.2deg) scaleX(0.92)` }} />

      <div style={{ position: 'absolute', left, top, width: w, height: h, transform: `${enter} rotate(-0.8deg) scaleX(${flip})` }}>
        <Paper kind="ruled" style={{ inset: 0, boxShadow: `inset 0 0 0 ${K}px rgba(43,38,32,0.12)` }}>
          <div style={{ position: 'absolute', left: pad, right: 56, top: 50, color: C.ink }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 18 }}>
              <span style={{ fontSize: 34, fontWeight: 700, color: C.clay, background: 'rgba(201,100,66,0.12)', padding: '4px 18px' }}>新字</span>
              <span style={{ fontSize: 34, fontWeight: 500, color: C.inkSoft }}>Core 3</span>
              <div style={{ flex: 1 }} />
              <Star />
              <div style={{ width: 20 }} />
              <Speaker />
            </div>
          </div>
          {!back ? (
            <>
              <div style={{ position: 'absolute', left: pad, right: 0, top: 330, textAlign: 'center', fontFamily: SERIF, fontWeight: 800, fontSize: 190, color: C.ink }}>
                attend
              </div>
              <div style={{ position: 'absolute', left: pad, right: 0, bottom: 64, textAlign: 'center', fontSize: 36, color: C.inkFaint, fontWeight: 500 }}>
                點一下看答案
              </div>
            </>
          ) : (
            <div style={{ position: 'absolute', left: pad, right: 56, top: 150, color: C.ink }}>
              <div style={{ fontFamily: SERIF, fontWeight: 800, fontSize: 124, lineHeight: 1.1 }}>attend</div>
              <div style={{ fontFamily: SERIF, fontSize: 42, color: C.inkSoft, marginTop: 6 }}>v. /əˈtend/</div>
              <div style={{ fontSize: 34, fontWeight: 700, color: C.clay, marginTop: 44 }}>中文</div>
              <div style={{ fontSize: 88, fontWeight: 900, lineHeight: 1.2, position: 'relative' }}>
                <BlurIn delay={FLIP_AT + 6} rise={16}>
                  出席
                </BlurIn>
                <InkLoops
                  width={190}
                  height={30}
                  count={3}
                  color={C.clay}
                  strokeWidth={5}
                  draw={interpolate(frame, [FLIP_AT + 12, FLIP_AT + 22], [0, 1], clamp)}
                  style={{ left: 0, top: 100 }}
                />
              </div>
              <div style={{ display: 'flex', alignItems: 'center', marginTop: 40 }}>
                <span style={{ fontSize: 32, fontWeight: 700, color: C.inkSoft }}>例句</span>
                <div style={{ flex: 1 }} />
                <Speaker size={50} />
              </div>
              <BlurIn delay={FLIP_AT + 9} rise={14} style={{ display: 'block' }}>
                <div style={{ fontFamily: SERIF, fontSize: 42, lineHeight: 1.42, marginTop: 6 }}>
                  Nearly all my classmates will <b style={{ color: C.clay }}>attend</b> the school concert on Friday evening.
                </div>
                <div style={{ fontSize: 34, lineHeight: 1.5, marginTop: 10, color: C.inkSoft }}>我幾乎所有同學都會出席週五晚上的學校音樂會。</div>
              </BlurIn>
            </div>
          )}
        </Paper>
        <Tape width={74} angle={3} style={{ left: w / 2 - 37 * K, top: -27 }} />
      </div>

      {/* The cat sits on the card's top edge. */}
      <div style={{ position: 'absolute', left: 96, top: top - 172, transform: enter }}>
        <Hopping at={[KNOW_AT + 2]} size={180}>
          <Mascot mood={frame >= KNOW_AT ? 'happy' : 'idle'} size={180} phase={1.3} />
        </Hopping>
      </div>
      <PopBubble delay={KNOW_AT + 4} origin="0% 50%" style={{ left: 300, top: top - 132 }}>
        <Bubble text="好喔，記住了。永遠。" fontSize={42} pointing="left" />
      </PopBubble>

      <div style={{ position: 'absolute', left, right: left, top: top + h + 48, height: 140 }}>
        {!back ? (
          <div
            style={{
              height: '100%',
              borderRadius: 999,
              background: C.clay,
              color: '#fff',
              fontSize: 52,
              fontWeight: 700,
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              transform: `scale(${showPress})`,
              opacity: rise,
            }}
          >
            看答案
          </div>
        ) : (
          <div style={{ display: 'flex', gap: 28, height: '100%', opacity: buttonsIn, transform: `translateY(${(1 - buttonsIn) * 40}px)` }}>
            <div
              style={{
                flex: 1,
                borderRadius: 999,
                background: C.ivory,
                border: `3px solid rgba(43,38,32,0.25)`,
                color: C.brick,
                fontSize: 52,
                fontWeight: 700,
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                gap: 12,
              }}
            >
              <Cross color={C.brick} />
              不熟
            </div>
            <div
              style={{
                flex: 1,
                borderRadius: 999,
                background: C.sage,
                color: '#fff',
                fontSize: 52,
                fontWeight: 700,
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                gap: 12,
                transform: `scale(${knowPress})`,
              }}
            >
              <Check color="#fff" />
              認識
            </div>
          </div>
        )}
      </div>
    </Scene>
  );
};

/* ───────────────────────── 4. 測驗 + 吐槽 ───────────────────────── */

const OPTIONS = ['說法', '前景', '價格', '哪一個'];
const TILTS = [-0.7, 0.5, -0.4, 0.8];
const WRONG = 0;
const RIGHT = 3;
const TAP_AT = 22;

const QuizScene = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const answered = frame >= TAP_AT;
  const shake = answered ? Math.sin((frame - TAP_AT) * 2.2) * interpolate(frame, [TAP_AT, TAP_AT + 10], [16, 0], clamp) : 0;
  const draw = interpolate(frame, [TAP_AT + 2, TAP_AT + 10], [0, 1], clamp);
  const catRise = usePop(TAP_AT + 6, 12, 200);
  const scrap = useSlap(4);

  const listTop = 900;
  const row = 146;
  const gap = 30;

  return (
    <Scene background={<Desk kind="desk" />}>
      <Headline lines={['答錯了？', '準備被吐槽。']} top={140} />

      {/* The question on a torn scrap of graph paper. */}
      <div style={{ position: 'absolute', left: 64, top: 560, width: 952, height: 270, opacity: scrap.opacity, transform: `rotate(${-0.6 - scrap.extraTilt}deg) scale(${scrap.scale})` }}>
        <Paper kind="graph" style={{ inset: 0, clipPath: torn(952, 270, ['bottom'], 2, 5) }}>
          <div style={{ position: 'absolute', inset: 0, display: 'flex', alignItems: 'center', justifyContent: 'center', fontFamily: SERIF, fontWeight: 800, fontSize: 150, color: C.ink }}>
            which
          </div>
          <div style={{ position: 'absolute', right: 44, top: 36 }}>
            <Speaker size={56} />
          </div>
        </Paper>
      </div>

      {OPTIONS.map((label, index) => {
        const appear = spring({ frame: frame - (8 + index * 2), fps, config: { damping: 15, stiffness: 190 } });
        const isWrong = answered && index === WRONG;
        const isRight = answered && index === RIGHT;
        const tint = isWrong ? 'rgba(180,72,58,0.18)' : isRight ? 'rgba(110,143,94,0.18)' : null;
        const dim = answered && !isWrong && !isRight ? 0.5 : 1;
        const press = index === WRONG ? interpolate(frame, [TAP_AT - 3, TAP_AT, TAP_AT + 3], [1, 0.96, 1], clamp) : 1;
        return (
          <div
            key={label}
            style={{
              position: 'absolute',
              left: 64,
              width: 952,
              top: listTop + index * (row + gap),
              height: row,
              opacity: appear * dim,
              transform: `translateY(${(1 - appear) * 70}px) translateX(${isWrong ? shake : 0}px) rotate(${TILTS[index]}deg) scale(${press})`,
            }}
          >
            {/* A strip of paper with an ink edge, tinted once answered. */}
            <Paper kind="ivory" grain={0.5} style={{ inset: 0, boxShadow: `inset 0 0 0 ${1.5 * K}px rgba(43,38,32,${tint ? 0.8 : 0.55})` }}>
              {tint ? <div style={{ position: 'absolute', inset: 0, background: tint }} /> : null}
              <div style={{ position: 'absolute', inset: 0, display: 'flex', alignItems: 'center', padding: '0 48px', fontSize: 54, fontWeight: 700, color: C.ink }}>
                {label}
                <div style={{ flex: 1 }} />
                {isWrong ? (
                  <div style={{ width: 60, height: 60, borderRadius: 999, background: C.brick, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                    <Cross color="#fff" size={40} />
                  </div>
                ) : null}
                {isRight ? (
                  <div style={{ width: 60, height: 60, borderRadius: 999, background: C.sage, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                    <Check color="#fff" size={42} draw={draw} />
                  </div>
                ) : null}
              </div>
            </Paper>
          </div>
        );
      })}

      <div style={{ position: 'absolute', right: 70, top: 1560, transform: `translateY(${(1 - catRise) * 500}px)` }}>
        <Mascot mood="smug" size={320} phase={2.2} />
      </div>
      <PopBubble delay={TAP_AT + 12} origin="100% 50%" style={{ right: 410, top: 1660 }}>
        <Bubble text="蛤？你是來亂的嗎？" fontSize={50} pointing="right" />
      </PopBubble>
    </Scene>
  );
};

/* ───────────────────────── 5. 今天：拼貼主卡 + 練習 ───────────────────────── */

const Flame = ({ size = 34 }: { size?: number }) => (
  <svg width={size} height={size} viewBox="0 0 24 24">
    <path d="M12 2.5c1 3.5 5.5 5.5 5.5 11a5.5 5.5 0 0 1-11 0c0-2.6 1.4-4.2 2.6-5.4.2 1.6.9 2.6 1.9 3C11 8.5 10.5 5.5 12 2.5z" fill="#FFB347" />
  </svg>
);

const Target = ({ size = 34 }: { size?: number }) => (
  <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke={C.cream} strokeWidth="2">
    <circle cx="12" cy="12" r="9" />
    <circle cx="12" cy="12" r="5" />
    <circle cx="12" cy="12" r="1.4" fill={C.cream} />
  </svg>
);

const ReviewIcon = () => (
  <svg width="46" height="46" viewBox="0 0 24 24" fill="none" stroke="#fff" strokeWidth="2.4" strokeLinecap="round" strokeLinejoin="round">
    <path d="M4.5 12a7.5 7.5 0 1 0 2.2-5.3" />
    <path d="M4.5 4.5v4h4" />
  </svg>
);

const QuizIcon = () => (
  <svg width="46" height="46" viewBox="0 0 24 24" fill="none" stroke="#fff" strokeWidth="2.4" strokeLinecap="round" strokeLinejoin="round">
    <path d="M4 7l1.5 1.5L8 6M4 15l1.5 1.5L8 14M11 7.5h9M11 15.5h9" />
  </svg>
);

const TodayScene = () => {
  const frame = useCurrentFrame();
  const slap = useSlap(2);
  const ring = interpolate(frame, [8, 28], [0, 7 / 20], { ...clamp, easing: easeOut });
  const count = Math.round(ring * 20);
  const r = 116;
  const circumference = 2 * Math.PI * r;
  const loops = interpolate(frame, [10, 22], [0, 1], clamp);
  const tileA = useSlap(10);
  const tileB = useSlap(14);

  const top = 760;
  const w = 952;
  const h = 620;

  return (
    <Scene background={<Desk kind="desk" />}>
      <Headline lines={['每天的進度，', '牠都盯著。']} top={140} />

      <div style={{ position: 'absolute', left: 64, top, width: w, height: h, opacity: slap.opacity, transform: `rotate(${-slap.extraTilt}deg) scale(${slap.scale})` }}>
        {/* A strip of graph paper peeking out behind its right edge. */}
        <Paper kind="graph" style={{ right: -32, top: 22, width: 96 * K, height: h, transform: 'rotate(3deg)' }} />
        {/* A cut of leather, torn along its bottom. */}
        <div style={{ position: 'absolute', inset: 0, clipPath: torn(w, h, ['bottom'], 3, 5), background: 'linear-gradient(135deg, #C98C5E, #995E3B)' }}>
          <div
            style={{
              position: 'absolute',
              inset: 0,
              backgroundImage: `url(${staticFile('paper-grain.png')})`,
              backgroundSize: `${160 * K}px ${160 * K}px`,
              mixBlendMode: 'overlay',
            }}
          />
          <Halftone width={110 * K} height={60 * K} color="rgba(0,0,0,0.18)" style={{ left: 0, bottom: 0 }} />
          <InkLoops width={70 * K} height={16 * K} count={3} color="rgba(255,240,219,0.55)" draw={loops} style={{ right: 18 * K, top: 14 * K }} />
          <div style={{ position: 'absolute', left: 56, top: 70, right: 56, display: 'flex', alignItems: 'center', gap: 48, color: C.cream }}>
            <svg width={2 * r + 40} height={2 * r + 40}>
              <circle cx={r + 20} cy={r + 20} r={r} fill="none" stroke="rgba(255,244,230,0.22)" strokeWidth={22} />
              <circle
                cx={r + 20}
                cy={r + 20}
                r={r}
                fill="none"
                stroke={C.cream}
                strokeWidth={22}
                strokeLinecap="round"
                strokeDasharray={circumference}
                strokeDashoffset={circumference * (1 - ring)}
                transform={`rotate(-90 ${r + 20} ${r + 20})`}
              />
              <text x={r + 20} y={r + 32} textAnchor="middle" fontFamily={SERIF} fontWeight={800} fontSize={100} fill={C.cream}>
                {count}
              </text>
              <text x={r + 20} y={r + 84} textAnchor="middle" fontFamily={FONT} fontWeight={500} fontSize={30} fill="rgba(255,244,230,0.75)">
                / 20 個
              </text>
            </svg>
            <div>
              <div style={{ fontSize: 60, fontWeight: 900 }}>今天的單字</div>
              <div style={{ fontSize: 34, fontWeight: 500, opacity: 0.8, marginTop: 10 }}>8 個待複習・5 個新字</div>
              <div style={{ display: 'flex', gap: 16, marginTop: 24 }}>
                {[
                  { icon: <Flame />, text: '2 天' },
                  { icon: <Target />, text: '差 13 個' },
                ].map(({ icon, text }) => (
                  <span key={text} style={{ display: 'flex', alignItems: 'center', gap: 8, fontSize: 30, fontWeight: 700, background: 'rgba(255,244,230,0.18)', borderRadius: 999, padding: '8px 20px' }}>
                    {icon}
                    {text}
                  </span>
                ))}
              </div>
            </div>
          </div>
          <div
            style={{
              position: 'absolute',
              left: 56,
              right: 56,
              bottom: 64,
              height: 130,
              borderRadius: 999,
              background: '#FFF8EE',
              color: '#73452A',
              fontSize: 50,
              fontWeight: 700,
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
            }}
          >
            繼續學習 →
          </div>
        </div>
        <Tape width={62} angle={-7} style={{ left: 18 * K, top: -27 }} />
      </div>

      <div style={{ position: 'absolute', right: 70, top: top - 236 }}>
        <Mascot mood="smug" size={290} phase={0.4} />
      </div>
      <PopBubble delay={14} origin="100% 60%" style={{ right: 350, top: top - 200 }}>
        <Bubble text={'才 7 個？笑死。\n還差 13 個。'} fontSize={46} pointing="right" style={{ whiteSpace: 'pre-line' }} />
      </PopBubble>

      {/* Practice tiles, each cut from its own paper. */}
      {[
        { kind: 'ruled' as const, tilt: -0.5, title: '複習不熟的字', sub: '練到熟為止', tint: C.brick, icon: <ReviewIcon />, s: tileA, tape: true },
        { kind: 'graph' as const, tilt: 0.6, title: '小測驗', sub: '10 題', tint: C.slate, icon: <QuizIcon />, s: tileB, tape: false },
      ].map((tile, i) => (
        <div
          key={tile.title}
          style={{
            position: 'absolute',
            left: 64 + i * (461 + 30),
            top: top + h + 70,
            width: 461,
            height: 220,
            opacity: tile.s.opacity,
            transform: `rotate(${tile.tilt - tile.s.extraTilt}deg) scale(${tile.s.scale})`,
          }}
        >
          <Paper kind={tile.kind} style={{ inset: 0, boxShadow: `inset 0 0 0 ${K}px rgba(43,38,32,0.16)` }}>
            <div style={{ position: 'absolute', left: tile.kind === 'ruled' ? 28 * K + 20 : 34, right: 16, top: 0, bottom: 0, display: 'flex', alignItems: 'center', gap: 16 }}>
              <div style={{ flexShrink: 0, width: 80, height: 80, borderRadius: '50%', background: tile.tint, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>{tile.icon}</div>
              <div style={{ color: C.ink }}>
                <div style={{ fontSize: 38, fontWeight: 900, lineHeight: 1.2, whiteSpace: 'nowrap' }}>{tile.title}</div>
                <div style={{ fontSize: 30, fontWeight: 500, color: C.inkSoft, marginTop: 4 }}>{tile.sub}</div>
              </div>
            </div>
          </Paper>
          {tile.tape ? <Tape width={58} angle={-4} style={{ left: 461 / 2 - 29 * K, top: -24 }} /> : null}
        </div>
      ))}
    </Scene>
  );
};

/* ───────────────────────── 6. 片尾 ───────────────────────── */

const EndScene = () => {
  const slap = useSlap(0);
  const stamp = useStampPress(14);
  return (
    <Scene background={<Desk kind="desk" />}>
      <AbsoluteFill style={{ alignItems: 'center', justifyContent: 'center', color: C.ink }}>
        <div style={{ position: 'relative', opacity: slap.opacity, transform: `rotate(${-2 - slap.extraTilt}deg) scale(${slap.scale})` }}>
          <Img src={staticFile('icon-collage.png')} style={{ width: 360, height: 360, display: 'block', boxShadow: `0 0 0 ${K}px rgba(43,38,32,0.16)` }} />
          <Tape width={60} angle={-38} style={{ left: -50, top: 20 }} />
          <Tape width={60} angle={38} style={{ right: -50, bottom: 22 }} />
        </div>
        <div style={{ fontFamily: SERIF, fontWeight: 800, fontSize: 140, marginTop: 80 }}>
          <BlurIn delay={5}>Word7000</BlurIn>
        </div>
        <div style={{ fontWeight: 700, fontSize: 52, marginTop: 16, color: C.inkSoft }}>
          <BlurIn delay={10} rise={16}>
            和小字團一起背 7000 單字。
          </BlurIn>
        </div>
      </AbsoluteFill>
      <Stamp size={230} angle={-14} style={{ right: 70, top: 800, opacity: stamp.opacity, transform: `rotate(-14deg) scale(${stamp.scale})` }}>
        <div style={{ lineHeight: 1.05 }}>
          <div style={{ fontFamily: SERIF, fontWeight: 800, fontSize: 64 }}>7000</div>
          <div style={{ fontWeight: 900, fontSize: 34 }}>單字</div>
        </div>
      </Stamp>
    </Scene>
  );
};

const COMPONENTS: Record<(typeof SCENES)[number]['id'], () => ReactElement> = {
  hook: HookScene,
  meet: MeetScene,
  card: CardScene,
  quiz: QuizScene,
  today: TodayScene,
  end: EndScene,
};

export const Teaser = () => (
  <AbsoluteFill style={{ background: COLLAGE.desk }}>
    {SCENES.map(({ id, from, duration }) => {
      const Component = COMPONENTS[id];
      return (
        <Sequence key={id} from={from} durationInFrames={duration} name={id}>
          <Component />
        </Sequence>
      );
    })}
  </AbsoluteFill>
);
