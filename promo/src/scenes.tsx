import { AbsoluteFill, Img, interpolate, staticFile } from 'remotion';
import { useFrame } from './time';
import { Desk, Halftone, InkLoops, K, Paper, Stamp, Tape, torn } from './collage';
import { SERIF } from './fonts';
import { Mascot } from './Mascot';
import {
  BlurIn,
  C,
  Headline,
  Hopping,
  Scene,
  clamp,
  easeOut,
  headline,
  usePop,
  useSlap,
  useStampPress,
} from './kit';

/**
 * Scenes the cut opens and closes with: the hook, the cat's introduction and
 * the end card. (They began in a 10-second teaser, since retired.)
 */

/* ───────────────────────── 1. 又在滑手機？ ───────────────────────── */

export const HookScene = () => {
  const frame = useFrame();
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

/* ───────────────────────── 2. 認識一下，小笨貓。 ───────────────────────── */

export const MeetScene = ({ stampText = ['毒舌', '陪讀'], caption }: { stampText?: [string, string]; caption?: string }) => {
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
          小笨貓。
        </BlurIn>
        {caption ? (
          <>
            <br />
            <BlurIn delay={16} rise={16} style={{ fontSize: 50, fontWeight: 700, color: C.clay, marginTop: 8 }}>
              {caption}
            </BlurIn>
          </>
        ) : null}
      </div>
      <Stamp
        size={250}
        angle={-12}
        style={{ right: 80, top: 1480, opacity: stamp.opacity, transform: `rotate(-12deg) scale(${stamp.scale})` }}
      >
        <div style={{ fontWeight: 900, fontSize: 54, lineHeight: 1.15 }}>
          {stampText[0]}
          <br />
          {stampText[1]}
        </div>
      </Stamp>
    </Scene>
  );
};


/* ───────────────────────── 6. 片尾 ───────────────────────── */

export const EndScene = ({ footnote }: { footnote?: string }) => {
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
        <div style={{ fontWeight: 900, fontSize: 150, letterSpacing: '0.04em', marginTop: 72 }}>
          <BlurIn delay={5}>單字貓</BlurIn>
        </div>
        <div style={{ fontWeight: 700, fontSize: 52, marginTop: 16, color: C.inkSoft }}>
          <BlurIn delay={10} rise={16}>
            和小笨貓一起背 7000 單字。
          </BlurIn>
        </div>
      </AbsoluteFill>
      <Stamp size={230} angle={-14} style={{ right: 70, top: 800, opacity: stamp.opacity, transform: `rotate(-14deg) scale(${stamp.scale})` }}>
        <div style={{ lineHeight: 1.05 }}>
          <div style={{ fontFamily: SERIF, fontWeight: 800, fontSize: 64 }}>7000</div>
          <div style={{ fontWeight: 900, fontSize: 34 }}>單字</div>
        </div>
      </Stamp>
      {footnote ? (
        <div style={{ position: 'absolute', left: 0, right: 0, bottom: 120, textAlign: 'center', fontSize: 30, fontWeight: 500, color: C.inkFaint }}>
          <BlurIn delay={16} rise={10}>
            {footnote}
          </BlurIn>
        </div>
      ) : null}
      {/* Not required (the Iowa samples are free for any use), but credited all the same. */}
      <div style={{ position: 'absolute', left: 0, right: 0, bottom: 64, textAlign: 'center', fontSize: 22, fontWeight: 500, color: C.inkFaint, opacity: 0.85 }}>
        <BlurIn delay={18} rise={6}>
          Guitar samples: University of Iowa Electronic Music Studios
        </BlurIn>
      </div>
    </Scene>
  );
};
