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
import { FONT } from './fonts';

const C = {
  blue: '#2563EB',
  blueDeep: '#1D4ED8',
  ink: '#0B0F19',
  page: '#F2F2F7',
  label: '#1C1C1E',
  labelSecondary: '#6C6C70',
  green: '#34C759',
  greenSoft: '#EAF9EE',
  white: '#FFFFFF',
};

// Scene timing in frames (30 fps). Total = 300 frames = 10 seconds.
const SCENES = [
  { id: 'count', from: 0, duration: 54 },
  { id: 'notThisTime', from: 54, duration: 36 },
  { id: 'card', from: 90, duration: 66 },
  { id: 'quiz', from: 156, duration: 60 },
  { id: 'speak', from: 216, duration: 36 },
  { id: 'end', from: 252, duration: 48 },
] as const;

export const TEASER_DURATION = SCENES[SCENES.length - 1].from + SCENES[SCENES.length - 1].duration;

const easeOut = Easing.bezier(0.16, 1, 0.3, 1);

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
  const t = interpolate(frame, [delay, delay + duration], [0, 1], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
    easing: easeOut,
  });
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

/** Gentle push-in so every hard cut lands with a little energy. */
const Scene = ({ background, children }: { background: string; children: ReactNode }) => {
  const frame = useCurrentFrame();
  const scale = interpolate(frame, [0, 18], [1.06, 1], { extrapolateRight: 'clamp', easing: easeOut });
  return (
    <AbsoluteFill style={{ background, fontFamily: FONT, overflow: 'hidden' }}>
      <AbsoluteFill style={{ transform: `scale(${scale})` }}>{children}</AbsoluteFill>
    </AbsoluteFill>
  );
};

const headline: CSSProperties = {
  fontWeight: 900,
  fontSize: 128,
  lineHeight: 1.12,
  letterSpacing: '-0.02em',
};

const usePop = (delay: number, damping = 13) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  return spring({ frame: frame - delay, fps, config: { damping, stiffness: 170, mass: 0.8 } });
};

const AppIcon = ({ size, style }: { size: number; style?: CSSProperties }) => (
  <Img
    src={staticFile('icon.png')}
    style={{
      width: size,
      height: size,
      borderRadius: size * 0.225,
      boxShadow: `0 ${size * 0.12}px ${size * 0.3}px rgba(37, 99, 235, 0.35)`,
      ...style,
    }}
  />
);

/* ───────────────────────── Scene 1: 7000 個單字。背了又忘？ ───────────────────────── */

const CountScene = () => {
  const frame = useCurrentFrame();
  const progress = interpolate(frame, [0, 26], [0, 1], {
    extrapolateRight: 'clamp',
    easing: Easing.bezier(0.33, 0, 0.1, 1),
  });
  const count = Math.round(progress * 7000);
  const glow = interpolate(frame, [0, 30], [0.2, 0.55], { extrapolateRight: 'clamp' });
  const fadeCount = interpolate(frame, [0, 8], [0, 1], { extrapolateRight: 'clamp' });

  return (
    <Scene background={C.ink}>
      <AbsoluteFill
        style={{
          background: `radial-gradient(circle at 50% 42%, rgba(37,99,235,${glow}) 0%, rgba(37,99,235,0) 55%)`,
        }}
      />
      <AbsoluteFill style={{ alignItems: 'center', justifyContent: 'center', color: C.white }}>
        <div
          style={{
            fontWeight: 900,
            fontSize: 300,
            letterSpacing: '-0.04em',
            fontVariantNumeric: 'tabular-nums',
            opacity: fadeCount,
            filter: `blur(${(1 - fadeCount) * 18}px)`,
            lineHeight: 1,
          }}
        >
          {count.toLocaleString('en-US').replace(',', '')}
        </div>
        <div style={{ ...headline, fontSize: 96, marginTop: 24 }}>
          <BlurIn delay={18}>個單字。</BlurIn>
        </div>
        <div style={{ ...headline, fontSize: 96, marginTop: 120, color: 'rgba(255,255,255,0.55)' }}>
          <BlurIn delay={32}>背了</BlurIn>
          <BlurIn delay={36}>又忘？</BlurIn>
        </div>
      </AbsoluteFill>
    </Scene>
  );
};

/* ───────────────────────── Scene 2: 這次，不一樣。 ───────────────────────── */

const NotThisTimeScene = () => {
  const pop = usePop(12, 11);
  return (
    <Scene background={C.page}>
      <AbsoluteFill style={{ alignItems: 'center', justifyContent: 'center', color: C.label }}>
        <AppIcon
          size={300}
          style={{
            transform: `scale(${pop}) rotate(${(1 - pop) * -14}deg)`,
            opacity: Math.min(1, pop * 1.4),
            marginBottom: 110,
          }}
        />
        <div style={{ ...headline, textAlign: 'center' }}>
          <BlurIn delay={0}>這次，</BlurIn>
          <br />
          <BlurIn delay={6}>不一樣。</BlurIn>
        </div>
      </AbsoluteFill>
    </Scene>
  );
};

/* ───────────────────────── Scene 3: 單字卡 + 例句 ───────────────────────── */

const SpeakerIcon = ({ color, pulse }: { color: string; pulse: number }) => (
  <svg width="64" height="64" viewBox="0 0 24 24" fill="none">
    <path d="M4 9.5v5h3.5L12 18.5v-13L7.5 9.5H4z" fill={color} />
    <path
      d="M15.5 9a4 4 0 0 1 0 6"
      stroke={color}
      strokeWidth="1.9"
      strokeLinecap="round"
      opacity={0.4 + pulse * 0.6}
    />
    <path
      d="M18 6.5a7.5 7.5 0 0 1 0 11"
      stroke={color}
      strokeWidth="1.9"
      strokeLinecap="round"
      opacity={pulse}
    />
  </svg>
);

const CardScene = () => {
  const frame = useCurrentFrame();
  const rise = usePop(4, 16);
  const highlight = interpolate(frame, [44, 54], [0, 1], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
    easing: easeOut,
  });
  const pulse = (Math.sin(frame / 3) + 1) / 2;

  return (
    <Scene background={C.blue}>
      <AbsoluteFill
        style={{
          background: `radial-gradient(circle at 80% 10%, rgba(255,255,255,0.18), rgba(255,255,255,0) 45%)`,
        }}
      />
      <div style={{ position: 'absolute', top: 230, left: 96, color: C.white }}>
        <div style={headline}>
          <BlurIn delay={0}>每個字，</BlurIn>
          <br />
          <BlurIn delay={6}>都有例句。</BlurIn>
        </div>
      </div>

      <div
        style={{
          position: 'absolute',
          left: 72,
          right: 72,
          top: 760,
          background: C.white,
          borderRadius: 64,
          padding: '72px 72px 80px',
          boxShadow: '0 40px 120px rgba(10, 30, 90, 0.35)',
          transform: `translateY(${(1 - rise) * 700}px) rotate(${(1 - rise) * 6}deg)`,
          color: C.label,
        }}
      >
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
          <div style={{ display: 'flex', alignItems: 'baseline', gap: 28 }}>
            <span style={{ fontWeight: 900, fontSize: 132, letterSpacing: '-0.03em' }}>attend</span>
            <span
              style={{
                fontWeight: 700,
                fontSize: 40,
                color: C.blue,
                background: 'rgba(37,99,235,0.10)',
                borderRadius: 999,
                padding: '6px 22px',
              }}
            >
              v.
            </span>
          </div>
          <SpeakerIcon color={C.blue} pulse={frame > 14 ? pulse : 0} />
        </div>

        <div style={{ fontWeight: 900, fontSize: 92, marginTop: 20, color: C.blue }}>
          <BlurIn delay={18} rise={20}>
            出席
          </BlurIn>
        </div>

        <div style={{ height: 2, background: 'rgba(60,60,67,0.12)', margin: '48px 0' }} />

        <BlurIn delay={28} rise={20} style={{ display: 'block' }}>
          <div style={{ fontWeight: 500, fontSize: 46, lineHeight: 1.45 }}>
            Nearly all my classmates will{' '}
            <span
              style={{
                fontWeight: 900,
                backgroundImage: `linear-gradient(transparent 58%, rgba(37,99,235,0.28) 58%)`,
                backgroundSize: `${highlight * 100}% 100%`,
                backgroundRepeat: 'no-repeat',
                color: highlight > 0.2 ? C.blueDeep : C.label,
              }}
            >
              attend
            </span>{' '}
            the school concert on Friday evening.
          </div>
        </BlurIn>
        <BlurIn delay={36} rise={16} style={{ display: 'block' }}>
          <div style={{ fontWeight: 500, fontSize: 40, lineHeight: 1.5, marginTop: 24, color: C.labelSecondary }}>
            我幾乎所有同學都會出席週五晚上的學校音樂會。
          </div>
        </BlurIn>
      </div>
    </Scene>
  );
};

/* ───────────────────────── Scene 4: 測驗 ───────────────────────── */

const OPTIONS = ['濃郁的', '出席', '抱怨', '允許'];
const CORRECT = 1;
const TAP_AT = 34;

const QuizScene = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const answered = frame >= TAP_AT;
  const tapPress = spring({ frame: frame - TAP_AT, fps, config: { damping: 9, stiffness: 260 } });
  const cursorIn = interpolate(frame, [22, TAP_AT], [0, 1], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
    easing: easeOut,
  });
  const cursorFade = interpolate(frame, [TAP_AT + 6, TAP_AT + 14], [1, 0], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
  const ripple = interpolate(frame, [TAP_AT, TAP_AT + 14], [0, 1], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
    easing: easeOut,
  });

  const gridTop = 980;
  const cell = { w: 444, h: 220, gap: 48 };

  return (
    <Scene background={C.page}>
      <div style={{ position: 'absolute', top: 230, left: 96, color: C.label }}>
        <div style={headline}>
          <BlurIn delay={0}>考一下，</BlurIn>
          <br />
          <BlurIn delay={6}>就記住。</BlurIn>
        </div>
      </div>

      <div
        style={{
          position: 'absolute',
          top: 690,
          left: 96,
          right: 96,
          display: 'flex',
          alignItems: 'baseline',
          gap: 24,
          color: C.label,
        }}
      >
        <BlurIn delay={8}>
          <span style={{ fontWeight: 900, fontSize: 110, letterSpacing: '-0.03em' }}>attend</span>
        </BlurIn>
        <BlurIn delay={11}>
          <span style={{ fontWeight: 700, fontSize: 52, color: C.labelSecondary }}>是什麼意思？</span>
        </BlurIn>
      </div>

      {OPTIONS.map((label, index) => {
        const col = index % 2;
        const row = Math.floor(index / 2);
        const isCorrect = index === CORRECT;
        const appear = spring({
          frame: frame - (12 + index * 3),
          fps,
          config: { damping: 15, stiffness: 180 },
        });
        const press = isCorrect && answered ? 1 - (1 - tapPress) * 0.08 : 1;
        const pressDip = isCorrect ? interpolate(frame, [TAP_AT - 3, TAP_AT], [1, 0.94], {
          extrapolateLeft: 'clamp',
          extrapolateRight: 'clamp',
        }) : 1;
        const dim = answered && !isCorrect ? 0.45 : 1;
        return (
          <div
            key={label}
            style={{
              position: 'absolute',
              left: 96 + col * (cell.w + cell.gap),
              top: gridTop + row * (cell.h + cell.gap),
              width: cell.w,
              height: cell.h,
              borderRadius: 48,
              background: isCorrect && answered ? C.green : C.white,
              color: isCorrect && answered ? C.white : C.label,
              boxShadow: '0 18px 50px rgba(28,28,30,0.08)',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              gap: 20,
              fontWeight: 900,
              fontSize: 72,
              opacity: appear * dim,
              transform: `translateY(${(1 - appear) * 80}px) scale(${(answered ? press : pressDip)})`,
            }}
          >
            {isCorrect && answered ? (
              <svg width="64" height="64" viewBox="0 0 24 24">
                <path
                  d="M5 12.5l4.5 4.5L19 7.5"
                  fill="none"
                  stroke={C.white}
                  strokeWidth="3"
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  strokeDasharray={24}
                  strokeDashoffset={24 * (1 - ripple)}
                />
              </svg>
            ) : null}
            {label}
          </div>
        );
      })}

      {/* Finger tap */}
      <div
        style={{
          position: 'absolute',
          left: 96 + cell.w + cell.gap + cell.w / 2 - 50,
          top: gridTop + cell.h / 2 - 50 + (1 - cursorIn) * 260,
          width: 100,
          height: 100,
          borderRadius: 999,
          background: 'rgba(28,28,30,0.22)',
          border: '4px solid rgba(255,255,255,0.9)',
          opacity: cursorIn * cursorFade,
          transform: `scale(${answered ? 0.8 : 1})`,
        }}
      />
      <div
        style={{
          position: 'absolute',
          left: 96 + cell.w + cell.gap + cell.w / 2 - 160,
          top: gridTop + cell.h / 2 - 160,
          width: 320,
          height: 320,
          borderRadius: 999,
          border: `6px solid ${C.green}`,
          opacity: answered ? (1 - ripple) * 0.8 : 0,
          transform: `scale(${0.4 + ripple * 0.8})`,
        }}
      />

      <div style={{ position: 'absolute', top: gridTop + 2 * (cell.h + cell.gap) + 40, left: 96 }}>
        {answered ? (
          <BlurIn delay={TAP_AT + 4} rise={20}>
            <span style={{ fontWeight: 700, fontSize: 56, color: '#1F8A3B' }}>答對了！</span>
          </BlurIn>
        ) : null}
      </div>
    </Scene>
  );
};

/* ───────────────────────── Scene 5: 口說 ───────────────────────── */

const BARS = 26;

const SpeakScene = () => {
  const frame = useCurrentFrame();
  const micPop = usePop(4, 12);
  const live = interpolate(frame, [8, 14], [0, 1], { extrapolateLeft: 'clamp', extrapolateRight: 'clamp' });

  return (
    <Scene background={C.ink}>
      <AbsoluteFill
        style={{
          background: 'radial-gradient(circle at 50% 70%, rgba(37,99,235,0.45), rgba(37,99,235,0) 50%)',
        }}
      />
      <div style={{ position: 'absolute', top: 230, left: 96, color: C.white }}>
        <div style={headline}>
          <BlurIn delay={0}>會念，</BlurIn>
          <br />
          <BlurIn delay={5}>才算會。</BlurIn>
        </div>
      </div>

      <div
        style={{
          position: 'absolute',
          top: 860,
          left: 0,
          right: 0,
          height: 360,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          gap: 14,
        }}
      >
        {Array.from({ length: BARS }, (_, i) => {
          const center = 1 - Math.abs(i - (BARS - 1) / 2) / (BARS / 2);
          const wobble =
            0.5 +
            0.5 * Math.sin(frame * 0.55 + i * 0.9) * Math.cos(frame * 0.23 + i * 0.37);
          const h = 24 + live * (40 + center * 280 * (0.35 + 0.65 * Math.abs(wobble)));
          return (
            <div
              key={i}
              style={{
                width: 22,
                height: h,
                borderRadius: 999,
                background: `rgba(255,255,255,${0.35 + center * 0.65})`,
              }}
            />
          );
        })}
      </div>

      <AbsoluteFill style={{ alignItems: 'center', justifyContent: 'flex-end', paddingBottom: 300 }}>
        <div
          style={{
            width: 200,
            height: 200,
            borderRadius: 999,
            background: C.blue,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            transform: `scale(${micPop})`,
            boxShadow: `0 0 0 ${18 + Math.sin(frame / 2.5) * 10}px rgba(37,99,235,0.28)`,
          }}
        >
          <svg width="96" height="96" viewBox="0 0 24 24" fill="none">
            <rect x="9" y="3" width="6" height="12" rx="3" fill={C.white} />
            <path d="M5.5 11a6.5 6.5 0 0 0 13 0M12 17.5V21" stroke={C.white} strokeWidth="2" strokeLinecap="round" />
          </svg>
        </div>
        <div style={{ marginTop: 44, fontWeight: 700, fontSize: 46, color: 'rgba(255,255,255,0.7)' }}>
          <BlurIn delay={10} rise={14}>
            口說練習
          </BlurIn>
        </div>
      </AbsoluteFill>
    </Scene>
  );
};

/* ───────────────────────── Scene 6: 片尾 ───────────────────────── */

const EndScene = () => {
  const pop = usePop(0, 12);
  return (
    <Scene background={C.white}>
      <AbsoluteFill style={{ alignItems: 'center', justifyContent: 'center', color: C.label }}>
        <AppIcon size={260} style={{ transform: `scale(${pop})` }} />
        <div style={{ fontWeight: 900, fontSize: 128, letterSpacing: '-0.03em', marginTop: 64 }}>
          <BlurIn delay={5}>Word7000</BlurIn>
        </div>
        <div style={{ fontWeight: 500, fontSize: 50, marginTop: 20, color: C.labelSecondary }}>
          <BlurIn delay={12} rise={16}>
            高中 7000 單字，每天一點點。
          </BlurIn>
        </div>
      </AbsoluteFill>
    </Scene>
  );
};

const COMPONENTS: Record<(typeof SCENES)[number]['id'], () => ReactElement> = {
  count: CountScene,
  notThisTime: NotThisTimeScene,
  card: CardScene,
  quiz: QuizScene,
  speak: SpeakScene,
  end: EndScene,
};

export const Teaser = () => (
  <AbsoluteFill style={{ background: C.ink }}>
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
