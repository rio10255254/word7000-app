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
import { FONT, SERIF } from './fonts';
import { Bubble, Mascot } from './Mascot';

// The warm palette of the current beta (ios/Word7000/Design/Theme.swift, WarmTone).
const C = {
  paper: '#F3EEE4',
  ivory: '#FBF8F2',
  khaki: '#E2D8C6',
  khakiFill: '#E9E1D2',
  ink: '#2B2620',
  inkSoft: '#7A6F62',
  inkFaint: '#B0A595',
  clay: '#C96442',
  sage: '#6E8F5E',
  brick: '#B4483A',
  umber: 'rgba(89,61,31,1)',
  heroTop: '#C98C5E',
  heroBottom: '#995E3B',
  white: '#FFFFFF',
};

// Scene timing in frames (30 fps). Total = 300 frames = 10 seconds.
const SCENES = [
  { id: 'hook', from: 0, duration: 60 },
  { id: 'meet', from: 60, duration: 33 },
  { id: 'card', from: 93, duration: 60 },
  { id: 'quiz', from: 153, duration: 57 },
  { id: 'today', from: 210, duration: 48 },
  { id: 'end', from: 258, duration: 42 },
] as const;

export const TEASER_DURATION = SCENES[SCENES.length - 1].from + SCENES[SCENES.length - 1].duration;

const easeOut = Easing.bezier(0.16, 1, 0.3, 1);
const clamp = { extrapolateLeft: 'clamp', extrapolateRight: 'clamp' } as const;

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

/** Warm paper with its grain and two soft glows, like the app's page background. */
const Paper = ({ tint = C.paper, glow = 'rgba(201,100,66,0.10)' }: { tint?: string; glow?: string }) => (
  <AbsoluteFill style={{ background: tint }}>
    <AbsoluteFill
      style={{
        background: `radial-gradient(circle at 85% 8%, ${glow}, transparent 45%), radial-gradient(circle at 10% 90%, rgba(201,138,46,0.10), transparent 50%)`,
      }}
    />
    <AbsoluteFill
      style={{
        backgroundImage: `url(${staticFile('paper-grain.png')})`,
        backgroundSize: '430px 430px',
        opacity: 0.55,
        mixBlendMode: 'multiply',
      }}
    />
  </AbsoluteFill>
);

/** Gentle push-in so every hard cut lands with a little energy. */
const Scene = ({ background, children }: { background: ReactNode; children: ReactNode }) => {
  const frame = useCurrentFrame();
  const scale = interpolate(frame, [0, 18], [1.06, 1], { extrapolateRight: 'clamp', easing: easeOut });
  return (
    <AbsoluteFill style={{ fontFamily: FONT, overflow: 'hidden' }}>
      {background}
      <AbsoluteFill style={{ transform: `scale(${scale})` }}>{children}</AbsoluteFill>
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

const Headline = ({ lines, color = C.ink, top = 210 }: { lines: string[]; color?: string; top?: number }) => (
  <div style={{ position: 'absolute', top, left: 96, right: 96, ...headline, color }}>
    {lines.map((line, i) => (
      <div key={line}>
        <BlurIn delay={i * 6}>{line}</BlurIn>
      </div>
    ))}
  </div>
);

/** A bubble that pops out of the cat. */
const PopBubble = ({
  delay,
  origin,
  children,
  style,
}: {
  delay: number;
  origin: string;
  children: ReactNode;
  style?: CSSProperties;
}) => {
  const pop = usePop(delay, 11, 220);
  return (
    <div
      style={{
        position: 'absolute',
        transform: `scale(${pop})`,
        transformOrigin: origin,
        opacity: Math.min(1, pop * 2),
        ...style,
      }}
    >
      {children}
    </div>
  );
};

/** A squash-and-stretch hop, as the app's Mascot does when it is tapped. */
const useHop = (at: number) => {
  const frame = useCurrentFrame();
  const f = frame - at;
  if (f < 0 || f > 22) return { sx: 1, sy: 1, lift: 0 };
  const sy = interpolate(f, [0, 3, 8, 12, 22], [1, 0.86, 1.08, 0.9, 1], clamp);
  const sx = interpolate(f, [0, 3, 8, 12, 22], [1, 1.1, 0.94, 1.08, 1], clamp);
  const lift = interpolate(f, [0, 3, 8, 12], [0, 0, -0.22, 0], clamp);
  return { sx, sy, lift };
};

const Hopping = ({ at, size, children }: { at: number[]; size: number; children: ReactNode }) => {
  const frame = useCurrentFrame();
  const current = [...at].reverse().find((a) => frame >= a) ?? -100;
  const { sx, sy, lift } = useHop(current);
  return (
    <div style={{ transform: `translateY(${lift * size}px) scale(${sx}, ${sy})`, transformOrigin: '50% 100%' }}>
      {children}
    </div>
  );
};

/* ───────────────────────── 1. 又在滑手機？ ───────────────────────── */

const HookScene = () => {
  const rise = usePop(8, 14, 120);
  return (
    <Scene background={<Paper />}>
      <Headline lines={['又在', '滑手機？']} />
      <div
        style={{
          position: 'absolute',
          left: 260,
          top: 1140,
          transform: `translateY(${(1 - rise) * 900}px)`,
        }}
      >
        <Hopping at={[40]} size={560}>
          <Mascot mood="smug" size={560} />
        </Hopping>
      </div>
      <PopBubble delay={24} origin="80% 100%" style={{ left: 120, top: 880 }}>
        <Bubble text={'你滑手機的時間\n夠背十個字了。'} fontSize={54} style={{ whiteSpace: 'pre-line', textAlign: 'left' }} />
      </PopBubble>
    </Scene>
  );
};

/* ───────────────────────── 2. 認識一下，小字團。 ───────────────────────── */

const MeetScene = () => {
  const pop = usePop(0, 10, 200);
  return (
    <Scene
      background={<Paper tint={C.clay} glow="rgba(255,220,180,0.25)" />}
    >
      <AbsoluteFill style={{ alignItems: 'center', justifyContent: 'center' }}>
        <div style={{ transform: `scale(${pop})`, marginTop: -120 }}>
          <Hopping at={[2, 16]} size={600}>
            <Mascot mood="happy" size={600} sparkles blush />
          </Hopping>
        </div>
        <div style={{ ...headline, color: C.white, textAlign: 'center', marginTop: 90 }}>
          <BlurIn delay={4} style={{ fontSize: 72, fontWeight: 700, opacity: 0.8 }}>
            認識一下，
          </BlurIn>
          <br />
          <BlurIn delay={9} style={{ fontSize: 168 }}>
            小字團。
          </BlurIn>
        </div>
      </AbsoluteFill>
    </Scene>
  );
};

/* ───────────────────────── 3. 單字卡 ───────────────────────── */

const Speaker = ({ color = C.clay, size = 64 }: { color?: string; size?: number }) => (
  <svg width={size} height={size} viewBox="0 0 24 24" fill="none">
    <path d="M4 9.5v5h3.5L12 18.5v-13L7.5 9.5H4z" fill={color} />
    <path d="M15.5 9a4 4 0 0 1 0 6M18 6.5a7.5 7.5 0 0 1 0 11" stroke={color} strokeWidth="1.9" strokeLinecap="round" />
  </svg>
);

const Star = ({ size = 60 }: { size?: number }) => (
  <svg width={size} height={size} viewBox="0 0 24 24" fill="none">
    <path
      d="M12 3.5l2.6 5.3 5.8.8-4.2 4.1 1 5.8L12 16.8l-5.2 2.7 1-5.8-4.2-4.1 5.8-.8L12 3.5z"
      stroke={C.inkFaint}
      strokeWidth="1.6"
      strokeLinejoin="round"
    />
  </svg>
);

const Check = ({ color, size = 52, draw = 1 }: { color: string; size?: number; draw?: number }) => (
  <svg width={size} height={size} viewBox="0 0 24 24">
    <path
      d="M5 12.5l4.5 4.5L19 7.5"
      fill="none"
      stroke={color}
      strokeWidth="2.8"
      strokeLinecap="round"
      strokeLinejoin="round"
      strokeDasharray={24}
      strokeDashoffset={24 * (1 - draw)}
    />
  </svg>
);

const Cross = ({ color, size = 52 }: { color: string; size?: number }) => (
  <svg width={size} height={size} viewBox="0 0 24 24">
    <path d="M6.5 6.5l11 11M17.5 6.5l-11 11" stroke={color} strokeWidth="2.6" strokeLinecap="round" />
  </svg>
);

const Chip = ({ children, color, bg }: { children: ReactNode; color: string; bg: string }) => (
  <span style={{ fontSize: 34, fontWeight: 700, color, background: bg, borderRadius: 999, padding: '6px 22px' }}>{children}</span>
);

const FLIP_AT = 22;
const KNOW_AT = 40;

const CardScene = () => {
  const frame = useCurrentFrame();
  const rise = usePop(2, 16);
  // Flip: squeeze to 0 then open on the back.
  const flip = interpolate(frame, [FLIP_AT, FLIP_AT + 5, FLIP_AT + 10], [1, 0, 1], { ...clamp, easing: Easing.inOut(Easing.quad) });
  const back = frame >= FLIP_AT + 5;
  const showPress = interpolate(frame, [FLIP_AT - 4, FLIP_AT - 1, FLIP_AT + 2], [1, 0.94, 1], clamp);
  const knowPress = interpolate(frame, [KNOW_AT - 3, KNOW_AT, KNOW_AT + 4], [1, 0.93, 1], clamp);
  const knowFlash = interpolate(frame, [KNOW_AT, KNOW_AT + 10], [1, 0], clamp);
  const buttonsIn = interpolate(frame, [FLIP_AT + 4, FLIP_AT + 12], [0, 1], { ...clamp, easing: easeOut });

  const cardTop = 650;
  const cardHeight = 950;

  return (
    <Scene background={<Paper />}>
      <Headline lines={['一張卡，', '一個字。']} top={140} />

      {/* The little cat riding on top of the card, as in the study screen. */}
      <div style={{ position: 'absolute', left: 96, top: cardTop - 170, transform: `translateY(${(1 - rise) * 900}px)` }}>
        <Hopping at={[KNOW_AT + 2]} size={180}>
          <Mascot mood={frame >= KNOW_AT ? 'happy' : 'idle'} size={180} phase={1.3} />
        </Hopping>
      </div>
      <PopBubble delay={KNOW_AT + 4} origin="0% 50%" style={{ left: 300, top: cardTop - 128 }}>
        <Bubble text="好喔，記住了。永遠。" fontSize={42} pointing="left" />
      </PopBubble>

      <div
        style={{
          position: 'absolute',
          left: 64,
          right: 64,
          top: cardTop,
          height: cardHeight,
          transform: `translateY(${(1 - rise) * 900}px) scaleX(${flip})`,
        }}
      >
        <div
          style={{
            position: 'absolute',
            inset: 0,
            background: C.ivory,
            borderRadius: 76,
            border: `3px solid ${C.khaki}`,
            boxShadow: '0 3px 3px rgba(89,61,31,0.06), 0 18px 40px rgba(89,61,31,0.12)',
            padding: '56px 64px',
            color: C.ink,
          }}
        >
          <div style={{ display: 'flex', alignItems: 'center', gap: 18 }}>
            <Chip color={C.clay} bg="rgba(201,100,66,0.12)">新字</Chip>
            <span style={{ fontSize: 34, fontWeight: 500, color: C.inkSoft }}>Core 3</span>
            <div style={{ flex: 1 }} />
            <Star />
            <div style={{ width: 24 }} />
            <Speaker />
          </div>

          {!back ? (
            <AbsoluteFill style={{ alignItems: 'center', justifyContent: 'center' }}>
              <div style={{ fontFamily: SERIF, fontWeight: 800, fontSize: 190, letterSpacing: '-0.01em' }}>attend</div>
              <div style={{ position: 'absolute', bottom: 70, fontSize: 36, color: C.inkFaint, fontWeight: 500 }}>
                點一下看答案
              </div>
            </AbsoluteFill>
          ) : (
            <div style={{ marginTop: 36 }}>
              <div style={{ textAlign: 'center' }}>
                <div style={{ fontFamily: SERIF, fontWeight: 800, fontSize: 124 }}>attend</div>
                <div style={{ fontFamily: SERIF, fontSize: 42, color: C.inkSoft }}>v. /əˈtend/</div>
              </div>
              <div style={{ height: 3, background: C.khaki, margin: '36px 0 28px' }} />
              <div style={{ fontSize: 34, fontWeight: 700, color: C.clay }}>中文</div>
              <div style={{ fontSize: 84, fontWeight: 900, marginTop: 0 }}>
                <BlurIn delay={FLIP_AT + 6} rise={16}>
                  出席
                </BlurIn>
              </div>
              <div style={{ display: 'flex', alignItems: 'center', marginTop: 24 }}>
                <span style={{ fontSize: 32, fontWeight: 700, color: C.inkSoft }}>例句</span>
                <div style={{ flex: 1 }} />
                <Speaker size={52} />
              </div>
              <BlurIn delay={FLIP_AT + 9} rise={14} style={{ display: 'block' }}>
                <div style={{ fontFamily: SERIF, fontSize: 42, lineHeight: 1.42, marginTop: 6 }}>
                  Nearly all my classmates will <b style={{ color: C.clay }}>attend</b> the school concert on Friday evening.
                </div>
                <div style={{ fontSize: 34, lineHeight: 1.5, marginTop: 10, color: C.inkSoft }}>
                  我幾乎所有同學都會出席週五晚上的學校音樂會。
                </div>
              </BlurIn>
            </div>
          )}
        </div>
      </div>

      {/* Bottom buttons: 看答案, then 不熟 / 認識. */}
      <div style={{ position: 'absolute', left: 64, right: 64, top: cardTop + cardHeight + 44, height: 140 }}>
        {!back ? (
          <div
            style={{
              height: '100%',
              borderRadius: 999,
              background: C.clay,
              color: C.white,
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
                border: `3px solid ${C.khaki}`,
                color: C.brick,
                fontSize: 52,
                fontWeight: 700,
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                gap: 12,
              }}
            >
              <Cross color={C.brick} size={46} />
              不熟
            </div>
            <div
              style={{
                flex: 1,
                borderRadius: 999,
                background: C.sage,
                color: C.white,
                fontSize: 52,
                fontWeight: 700,
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                gap: 12,
                transform: `scale(${knowPress})`,
                boxShadow: `0 0 0 ${knowFlash * 26}px rgba(110,143,94,${knowFlash * 0.35})`,
              }}
            >
              <Check color={C.white} size={46} />
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

  const listTop = 820;
  const row = 150;
  const gap = 26;

  return (
    <Scene background={<Paper />}>
      <Headline lines={['答錯了？', '準備被吐槽。']} top={170} />

      <div style={{ position: 'absolute', top: 600, left: 0, right: 0, textAlign: 'center', color: C.ink }}>
        <BlurIn delay={6}>
          <span style={{ fontFamily: SERIF, fontWeight: 800, fontSize: 150 }}>which</span>
        </BlurIn>
      </div>

      {OPTIONS.map((label, index) => {
        const appear = spring({ frame: frame - (8 + index * 2), fps, config: { damping: 15, stiffness: 190 } });
        const isWrong = answered && index === WRONG;
        const isRight = answered && index === RIGHT;
        const dim = answered && !isWrong && !isRight ? 0.5 : 1;
        const press = index === WRONG ? interpolate(frame, [TAP_AT - 3, TAP_AT, TAP_AT + 3], [1, 0.96, 1], clamp) : 1;
        return (
          <div
            key={label}
            style={{
              position: 'absolute',
              left: 64,
              right: 64,
              top: listTop + index * (row + gap),
              height: row,
              borderRadius: 40,
              background: isWrong ? '#F2DCD6' : isRight ? '#DDE6D3' : C.ivory,
              border: `3px solid ${isWrong ? 'rgba(180,72,58,0.45)' : isRight ? 'rgba(110,143,94,0.5)' : C.khaki}`,
              color: C.ink,
              display: 'flex',
              alignItems: 'center',
              padding: '0 48px',
              fontSize: 54,
              fontWeight: 700,
              opacity: appear * dim,
              transform: `translateY(${(1 - appear) * 70}px) translateX(${isWrong ? shake : 0}px) scale(${press})`,
            }}
          >
            {label}
            <div style={{ flex: 1 }} />
            {isWrong ? (
              <div style={{ width: 60, height: 60, borderRadius: 999, background: C.brick, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                <Cross color={C.white} size={40} />
              </div>
            ) : null}
            {isRight ? (
              <div style={{ width: 60, height: 60, borderRadius: 999, background: C.sage, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                <Check color={C.white} size={42} draw={draw} />
              </div>
            ) : null}
          </div>
        );
      })}

      <div style={{ position: 'absolute', right: 70, top: 1500, transform: `translateY(${(1 - catRise) * 500}px)` }}>
        <Mascot mood="smug" size={330} phase={2.2} />
      </div>
      <PopBubble delay={TAP_AT + 12} origin="100% 50%" style={{ right: 420, top: 1600 }}>
        <Bubble text="蛤？你是來亂的嗎？" fontSize={50} pointing="right" />
      </PopBubble>
    </Scene>
  );
};

/* ───────────────────────── 5. 今天的單字 ───────────────────────── */

const Flame = ({ size = 34 }: { size?: number }) => (
  <svg width={size} height={size} viewBox="0 0 24 24">
    <path d="M12 2.5c1 3.5 5.5 5.5 5.5 11a5.5 5.5 0 0 1-11 0c0-2.6 1.4-4.2 2.6-5.4.2 1.6.9 2.6 1.9 3C11 8.5 10.5 5.5 12 2.5z" fill="#FFB347" />
  </svg>
);

const Target = ({ size = 34 }: { size?: number }) => (
  <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="#FFF4E6" strokeWidth="2">
    <circle cx="12" cy="12" r="9" />
    <circle cx="12" cy="12" r="5" />
    <circle cx="12" cy="12" r="1.4" fill="#FFF4E6" />
  </svg>
);

const TodayScene = () => {
  const frame = useCurrentFrame();
  const cardIn = usePop(2, 16);
  const ring = interpolate(frame, [6, 26], [0, 7 / 20], { ...clamp, easing: easeOut });
  const count = Math.round(ring * 20);
  const r = 120;
  const circumference = 2 * Math.PI * r;
  const cardTop = 820;

  return (
    <Scene background={<Paper />}>
      <Headline lines={['每天的進度，', '牠都盯著。']} top={170} />

      <div style={{ position: 'absolute', right: 80, top: cardTop - 250, transform: `translateY(${(1 - cardIn) * 900}px)` }}>
        <Mascot mood="smug" size={300} phase={0.4} />
      </div>
      <PopBubble delay={12} origin="100% 60%" style={{ right: 360, top: cardTop - 210 }}>
        <Bubble text={'才 7 個？笑死。\n還差 13 個。'} fontSize={48} pointing="right" style={{ whiteSpace: 'pre-line' }} />
      </PopBubble>

      <div
        style={{
          position: 'absolute',
          left: 64,
          right: 64,
          top: cardTop,
          height: 600,
          borderRadius: 76,
          background: `linear-gradient(160deg, ${C.heroTop}, ${C.heroBottom})`,
          boxShadow: '0 30px 70px rgba(89,61,31,0.32)',
          transform: `translateY(${(1 - cardIn) * 900}px)`,
          padding: 64,
          color: '#FFF4E6',
          overflow: 'hidden',
        }}
      >
        <div style={{ position: 'absolute', inset: 0, background: 'radial-gradient(circle at 20% 0%, rgba(255,255,255,0.22), transparent 55%)' }} />
        <div style={{ display: 'flex', alignItems: 'center', gap: 56, position: 'relative' }}>
          <svg width={2 * r + 40} height={2 * r + 40} viewBox={`0 0 ${2 * r + 40} ${2 * r + 40}`}>
            <circle cx={r + 20} cy={r + 20} r={r} fill="none" stroke="rgba(255,244,230,0.22)" strokeWidth={22} />
            <circle
              cx={r + 20}
              cy={r + 20}
              r={r}
              fill="none"
              stroke="#FFF4E6"
              strokeWidth={22}
              strokeLinecap="round"
              strokeDasharray={circumference}
              strokeDashoffset={circumference * (1 - ring)}
              transform={`rotate(-90 ${r + 20} ${r + 20})`}
            />
            <text x={r + 20} y={r + 32} textAnchor="middle" fontFamily={SERIF} fontWeight={800} fontSize={104} fill="#FFF4E6">
              {count}
            </text>
            <text x={r + 20} y={r + 86} textAnchor="middle" fontFamily={FONT} fontWeight={500} fontSize={30} fill="rgba(255,244,230,0.75)">
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
                <span
                  key={text}
                  style={{
                    display: 'flex',
                    alignItems: 'center',
                    gap: 8,
                    fontSize: 30,
                    fontWeight: 700,
                    background: 'rgba(255,244,230,0.18)',
                    borderRadius: 999,
                    padding: '8px 20px',
                  }}
                >
                  {icon}
                  {text}
                </span>
              ))}
            </div>
          </div>
        </div>
        <div
          style={{
            position: 'relative',
            marginTop: 48,
            height: 130,
            borderRadius: 999,
            background: '#FFF8EE',
            color: '#73452A',
            fontSize: 50,
            fontWeight: 700,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            gap: 18,
          }}
        >
          繼續學習 →
        </div>
      </div>
    </Scene>
  );
};

/* ───────────────────────── 6. 片尾 ───────────────────────── */

const EndScene = () => {
  const pop = usePop(0, 12);
  return (
    <Scene background={<Paper />}>
      <AbsoluteFill style={{ alignItems: 'center', justifyContent: 'center', color: C.ink }}>
        <Img
          src={staticFile('icon.png')}
          style={{
            width: 320,
            height: 320,
            borderRadius: 72,
            boxShadow: '0 30px 70px rgba(89,61,31,0.35)',
            transform: `scale(${pop}) rotate(${(1 - pop) * -10}deg)`,
          }}
        />
        <div style={{ fontFamily: SERIF, fontWeight: 800, fontSize: 140, marginTop: 72 }}>
          <BlurIn delay={5}>Word7000</BlurIn>
        </div>
        <div style={{ fontWeight: 700, fontSize: 52, marginTop: 18, color: C.inkSoft }}>
          <BlurIn delay={11} rise={16}>
            和小字團一起背 7000 單字。
          </BlurIn>
        </div>
      </AbsoluteFill>
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
  <AbsoluteFill style={{ background: C.paper }}>
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
