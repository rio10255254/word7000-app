import type { CSSProperties, ReactElement, ReactNode } from 'react';
import { AbsoluteFill, Img, Sequence, interpolate, spring, staticFile, useVideoConfig } from 'remotion';
import { scaleScenes, scaledLength, useFrame } from './time';
import { Desk, InkLoops, K, Paper, Stamp, Tape, torn } from './collage';
import { FONT, HAND, SERIF } from './fonts';
import {
  BlurIn,
  BulbIcon,
  C,
  CatSays,
  Check,
  Cross,
  Footnote,
  Headline,
  LearnerSays,
  MicIcon,
  PaperButton,
  PopBubble,
  Scene,
  SparkleIcon,
  Speaker,
  Typewriter,
  TypingDots,
  clamp,
  easeOut,
  usePop,
  useSlap,
  useStampPress,
} from './kit';
import { Bubble, Mascot } from './Mascot';
import { EndScene, HookScene, MeetScene } from './Teaser';

/**
 * The 30-second cut. Most of it is the AI — 小笨貓 is the face of every
 * online AI answer in the app — then scanning, making the app your own,
 * and the daily reminder. Every line the cat says, every label and every
 * button is copy from the beta (claude/friendly-darwin-obc3r1).
 */
const SCENES = [
  { id: 'hook', from: 0, duration: 60 },
  { id: 'meet', from: 60, duration: 42 },
  { id: 'explain', from: 102, duration: 105 },
  { id: 'ask', from: 207, duration: 90 },
  { id: 'why', from: 297, duration: 80 },
  { id: 'coach', from: 377, duration: 93 },
  { id: 'analysis', from: 470, duration: 78 },
  { id: 'scan', from: 548, duration: 90 },
  { id: 'style', from: 638, duration: 78 },
  { id: 'settings', from: 716, duration: 72 },
  { id: 'reminder', from: 788, duration: 64 },
  { id: 'end', from: 852, duration: 48 },
] as const;

export const FULL_DURATION = scaledLength(SCENES[SCENES.length - 1].from + SCENES[SCENES.length - 1].duration);

const L = 64; // page gutter
const W = 1080 - L * 2;

const fadeIn = (frame: number, at: number, length = 6) => interpolate(frame, [at, at + length], [0, 1], clamp);
const fadeOut = (frame: number, at: number, length = 5) => interpolate(frame, [at, at + length], [1, 0], clamp);

const Label = ({ children, color = C.inkSoft, style }: { children: ReactNode; color?: string; style?: CSSProperties }) => (
  <div style={{ fontSize: 32, fontWeight: 700, color, ...style }}>{children}</div>
);

/* ───────────────────────── AI 1. 小笨貓解說 ───────────────────────── */

const ExplainScene = () => {
  const frame = useFrame();
  const slap = useSlap(2);
  const pad = 44 * K;
  const answerAt = 34;
  return (
    <Scene background={<Desk kind="desk" />}>
      <Headline lines={['不懂？', '叫牠講到懂。']} top={140} />

      <div style={{ position: 'absolute', left: L, top: 500, width: W, height: 420, opacity: slap.opacity, transform: `rotate(${-0.8 - slap.extraTilt}deg) scale(${slap.scale})` }}>
        <Paper kind="ruled" style={{ inset: 0, boxShadow: `inset 0 0 0 ${K}px rgba(43,38,32,0.12)` }}>
          <div style={{ position: 'absolute', left: pad, right: 56, top: 44, display: 'flex', alignItems: 'center', gap: 18 }}>
            <span style={{ fontSize: 32, fontWeight: 700, color: C.clay, background: 'rgba(201,100,66,0.12)', padding: '4px 18px' }}>新字</span>
            <span style={{ fontSize: 32, fontWeight: 500, color: C.inkSoft }}>Core 3</span>
            <div style={{ flex: 1 }} />
            <Speaker size={54} />
          </div>
          <div style={{ position: 'absolute', left: pad, top: 120, color: C.ink }}>
            <div style={{ fontFamily: SERIF, fontWeight: 800, fontSize: 112, lineHeight: 1.1 }}>attend</div>
            <div style={{ fontFamily: SERIF, fontSize: 40, color: C.inkSoft }}>v. /əˈtend/</div>
          </div>
          <div style={{ position: 'absolute', right: 70, top: 170, fontSize: 96, fontWeight: 900, color: C.ink }}>出席</div>
        </Paper>
        <Tape width={74} angle={3} style={{ left: W / 2 - 37 * K, top: -27 }} />
      </div>

      <div style={{ opacity: fadeIn(frame, 8) * fadeOut(frame, 22) }}>
        <PaperButton pressAt={17} style={{ left: L, top: 1000, width: W, height: 130 }}>
          <SparkleIcon />
          叫小笨貓解說：用法、搭配與例句
        </PaperButton>
      </div>

      {frame >= 22 ? (
        <div style={{ position: 'absolute', left: L, right: L, top: 1000, opacity: fadeIn(frame, 22, 4) }}>
          <CatSays mood={frame < answerAt ? 'idle' : 'smug'} size={130}>
            {frame < answerAt ? (
              <span style={{ color: C.inkSoft }}>
                小笨貓翻一下筆記……別催。 <TypingDots />
              </span>
            ) : (
              <>
                <Typewriter start={answerAt} cps={50} text="attend 就是「出席」，開會、上課、典禮這種正式場合用；跟朋友出去玩，說 go to 就好。" />
                <div style={{ marginTop: 20, opacity: fadeIn(frame, 70) }}>
                  <Label color={C.clay}>常見搭配</Label>
                  <div style={{ display: 'flex', flexWrap: 'wrap', gap: 14, marginTop: 12 }}>
                    {[
                      ['attend a meeting', '開會'],
                      ['attend school', '上學'],
                      ['attend to', '處理'],
                    ].map(([en, zh], i) => (
                      <span
                        key={en}
                        style={{
                          fontSize: 34,
                          background: '#FBF8F2',
                          boxShadow: `inset 0 0 0 2px rgba(43,38,32,0.35)`,
                          padding: '8px 18px',
                          opacity: fadeIn(frame, 72 + i * 4, 5),
                          transform: `translateY(${(1 - fadeIn(frame, 72 + i * 4, 5)) * 16}px)`,
                        }}
                      >
                        <span style={{ fontFamily: SERIF, fontWeight: 700 }}>{en}</span> <span style={{ color: C.inkSoft }}>{zh}</span>
                      </span>
                    ))}
                  </div>
                </div>
              </>
            )}
          </CatSays>
          <div style={{ marginTop: 26, marginLeft: 150, fontSize: 36, fontWeight: 700, color: C.clay, opacity: fadeIn(frame, 86) }}>↻ 聽不懂，換個講法</div>
        </div>
      ) : null}

      <Footnote delay={88} style={{ top: 1790 }}>
        背後是 Claude 線上 AI，可能有誤。
      </Footnote>
    </Scene>
  );
};

/* ───────────────────────── AI 2. 問小笨貓 ───────────────────────── */

const PRESETS = ['常見的錯誤用法是什麼？', '跟意思相近的字有什麼不同？', '口語和正式場合都能用嗎？'];

const AskScene = () => {
  const frame = useFrame();
  const { fps } = useVideoConfig();
  const answerAt = 40;
  const asked = frame >= 22;
  return (
    <Scene background={<Desk kind="desk" />}>
      <Headline lines={['想問什麼，', '直接問。']} top={140} />

      <div style={{ position: 'absolute', left: L, right: L, top: 480, display: 'flex', alignItems: 'baseline', gap: 24 }}>
        <BlurIn delay={4}>
          <span style={{ fontFamily: SERIF, fontWeight: 800, fontSize: 96, color: C.ink }}>attend</span>
        </BlurIn>
        <BlurIn delay={6}>
          <span style={{ fontSize: 44, fontWeight: 900, color: C.clay }}>問小笨貓</span>
        </BlurIn>
      </div>

      {PRESETS.map((q, i) => {
        const appear = spring({ frame: frame - (6 + i * 3), fps, config: { damping: 15, stiffness: 190 } });
        const dim = fadeOut(frame, i === 0 ? 21 : 22, 4);
        return (
          <div key={q} style={{ opacity: appear * dim, transform: `translateY(${(1 - appear) * 60}px) rotate(${[-0.6, 0.5, -0.4][i]}deg)` }}>
            <PaperButton pressAt={i === 0 ? 18 : -100} color={C.ink} style={{ left: L, top: 640 + i * 116, width: W, height: 96 }}>
              <span style={{ fontSize: 40 }}>{q}</span>
            </PaperButton>
          </div>
        );
      })}

      {asked ? (
        <PopBubble delay={22} origin="100% 50%" style={{ left: L, right: L, top: 640 }}>
          <LearnerSays>常見的錯誤用法是什麼？</LearnerSays>
        </PopBubble>
      ) : null}

      {frame >= 26 ? (
        <div style={{ position: 'absolute', left: L, right: L, top: 800, opacity: fadeIn(frame, 26, 4) }}>
          <CatSays mood={frame < answerAt ? 'idle' : 'smug'} size={130} phase={0.7}>
            {frame < answerAt ? (
              <span style={{ color: C.inkSoft }}>
                嗯……這題問得還可以。 <TypingDots />
              </span>
            ) : (
              <>
                <Typewriter start={answerAt} cps={50} text="attend 後面直接接活動，不用加 to：" />
                <div style={{ marginTop: 18, fontFamily: SERIF, fontSize: 46, lineHeight: 1.6 }}>
                  <div style={{ opacity: fadeIn(frame, 58), display: 'flex', alignItems: 'center', gap: 14 }}>
                    <Cross color={C.brick} size={44} />
                    <span style={{ color: C.brick, textDecoration: 'line-through' }}>attend to the meeting</span>
                  </div>
                  <div style={{ opacity: fadeIn(frame, 63), display: 'flex', alignItems: 'center', gap: 14 }}>
                    <Check color={C.sage} size={44} />
                    <span style={{ color: '#4E6B40', fontWeight: 700 }}>attend the meeting</span>
                  </div>
                </div>
                <div style={{ marginTop: 14 }}>
                  <Typewriter start={68} cps={50} text="attend to 是「處理」，意思不一樣喔。" />
                </div>
              </>
            )}
          </CatSays>
        </div>
      ) : null}

      <div style={{ opacity: fadeIn(frame, 30) }}>
        <Paper kind="ivory" grain={0.5} style={{ left: L, top: 1700, width: W, height: 120, boxShadow: `inset 0 0 0 ${1.5 * K}px rgba(43,38,32,0.45)` }}>
          <div style={{ position: 'absolute', inset: 0, display: 'flex', alignItems: 'center', padding: '0 40px', fontSize: 38, color: C.inkFaint }}>
            問小笨貓關於這個字的問題
            <div style={{ flex: 1 }} />
            <div style={{ width: 76, height: 76, borderRadius: '50%', background: C.clay, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
              <svg width="40" height="40" viewBox="0 0 24 24" fill="none" stroke="#fff" strokeWidth="2.6" strokeLinecap="round" strokeLinejoin="round">
                <path d="M12 19V5M5.5 11.5L12 5l6.5 6.5" />
              </svg>
            </div>
          </div>
        </Paper>
      </div>
    </Scene>
  );
};

/* ───────────────────────── AI 3. 小笨貓，我為什麼錯？ ───────────────────────── */

const WhyScene = () => {
  const frame = useFrame();
  const scrap = useSlap(2);
  const answered = frame >= 8;
  const answerAt = 36;
  const options = ['說法', '前景', '價格', '哪一個'];
  return (
    <Scene background={<Desk kind="desk" />}>
      <Headline lines={['答錯了，', '牠說你錯在哪。']} top={140} />

      <div style={{ position: 'absolute', left: L, top: 490, width: W, height: 200, opacity: scrap.opacity, transform: `rotate(${-0.6 - scrap.extraTilt}deg) scale(${scrap.scale})` }}>
        <Paper kind="graph" style={{ inset: 0, clipPath: torn(W, 200, ['bottom'], 2, 5) }}>
          <div style={{ position: 'absolute', inset: 0, display: 'flex', alignItems: 'center', justifyContent: 'center', fontFamily: SERIF, fontWeight: 800, fontSize: 120, color: C.ink }}>
            which
          </div>
        </Paper>
      </div>

      {options.map((label, i) => {
        const wrong = answered && i === 0;
        const right = answered && i === 3;
        const tint = wrong ? 'rgba(180,72,58,0.18)' : right ? 'rgba(110,143,94,0.18)' : undefined;
        return (
          <div key={label} style={{ opacity: fadeIn(frame, 3 + i * 2) * (answered && !wrong && !right ? 0.45 : 1), transform: `rotate(${[-0.7, 0.5, -0.4, 0.8][i]}deg)` }}>
            <PaperButton tint={tint} color={C.ink} pressAt={i === 0 ? 8 : -100} style={{ left: L + (i % 2) * (W / 2 + 12), top: 740 + Math.floor(i / 2) * 140, width: W / 2 - 12, height: 116 }}>
              {label}
              {wrong ? <Cross color={C.brick} size={44} /> : null}
              {right ? <Check color={C.sage} size={44} /> : null}
            </PaperButton>
          </div>
        );
      })}

      <div style={{ opacity: fadeIn(frame, 12) * fadeOut(frame, 24) }}>
        <PaperButton pressAt={20} style={{ left: L, top: 1060, width: W, height: 130 }}>
          <SparkleIcon />
          小笨貓，我為什麼錯？
        </PaperButton>
      </div>

      {frame >= 24 ? (
        <div style={{ position: 'absolute', left: L, right: L, top: 1060, opacity: fadeIn(frame, 24, 4) }}>
          <CatSays mood={frame < answerAt ? 'annoyed' : 'smug'} size={130} phase={1.1}>
            {frame < answerAt ? (
              <span style={{ color: C.inkSoft }}>
                蛤，選這個？我來解釋。 <TypingDots />
              </span>
            ) : (
              <>
                <div style={{ fontWeight: 900, color: C.clay, marginBottom: 6 }}>小笨貓說你錯在這：</div>
                <Typewriter start={answerAt + 2} cps={52} text="which 是「哪一個」，用在幾個選項裡挑一個。你選的「說法」比較像 saying，意思差很遠。" />
              </>
            )}
          </CatSays>
        </div>
      ) : null}
      <PopBubble delay={70} origin="100% 50%" style={{ right: 300, top: 1660 }}>
        <Bubble text="沒關係，我會記得你錯了。" fontSize={42} pointing="right" />
      </PopBubble>
      <div style={{ position: 'absolute', right: 70, top: 1600, opacity: fadeIn(frame, 66) }}>
        <Mascot mood="smug" size={220} phase={2.6} />
      </div>
    </Scene>
  );
};

/* ───────────────────────── AI 4. 口說教練 ───────────────────────── */

const CoachScene = () => {
  const frame = useFrame();
  const prompt = useSlap(2);
  const recording = frame >= 12 && frame < 40;
  const typed = frame >= 40;
  const suggestion = useSlap(52);
  return (
    <Scene background={<Desk kind="desk" />}>
      <Headline lines={['開口說，', 'AI 幫你改。']} top={140} />

      {/* The question, on torn peach — the speaking paper in the collage. */}
      <div style={{ position: 'absolute', left: L, top: 480, width: W, height: 290, opacity: prompt.opacity, transform: `rotate(${0.6 - prompt.extraTilt}deg) scale(${prompt.scale})` }}>
        <Paper kind="peach" style={{ inset: 0, clipPath: torn(W, 290, ['bottom'], 7, 5) }}>
          <div style={{ position: 'absolute', left: 52, right: 52, top: 40 }}>
            <div style={{ display: 'flex', alignItems: 'center' }}>
              <span style={{ fontSize: 40, fontWeight: 900, color: C.clay }}>口說教練</span>
              <span style={{ fontFamily: SERIF, fontWeight: 700, fontSize: 40, color: C.inkSoft, marginLeft: 20 }}>subject</span>
              <div style={{ flex: 1 }} />
              <Speaker size={54} />
            </div>
            <div style={{ fontFamily: SERIF, fontSize: 52, lineHeight: 1.35, color: C.ink, marginTop: 18 }}>Which subject would you like to revisit as an adult?</div>
          </div>
        </Paper>
      </div>

      <Label style={{ position: 'absolute', left: L + 8, top: 810 }}>你的回答</Label>
      <Paper kind="ivory" grain={0.5} style={{ left: L, top: 860, width: W, height: 230, boxShadow: `inset 0 0 0 ${1.5 * K}px rgba(43,38,32,0.45)` }}>
        {!typed ? (
          <div style={{ position: 'absolute', inset: 0, display: 'flex', alignItems: 'center', padding: '0 44px', gap: 28 }}>
            <div
              style={{
                width: 120,
                height: 120,
                borderRadius: '50%',
                background: recording ? C.brick : C.clay,
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                boxShadow: recording ? `0 0 0 ${14 + Math.sin(frame / 2) * 8}px rgba(180,72,58,0.2)` : 'none',
                transform: `scale(${interpolate(frame, [9, 12, 15], [1, 0.9, 1], clamp)})`,
              }}
            >
              <MicIcon />
            </div>
            {recording ? (
              <div style={{ display: 'flex', alignItems: 'center', gap: 8, flex: 1 }}>
                {Array.from({ length: 30 }, (_, i) => {
                  const h = 16 + 70 * Math.abs(Math.sin(frame * 0.5 + i * 0.8) * Math.cos(frame * 0.21 + i * 0.3));
                  return <div key={i} style={{ width: 10, height: h, borderRadius: 5, background: C.brick, opacity: 0.75 }} />;
                })}
                <span style={{ fontSize: 34, color: C.inkSoft, marginLeft: 12, fontVariantNumeric: 'tabular-nums' }}>0:0{Math.min(4, Math.floor((frame - 12) / 7))}</span>
              </div>
            ) : (
              <span style={{ fontSize: 44, fontWeight: 700, color: C.clay }}>錄音</span>
            )}
          </div>
        ) : (
          <div style={{ position: 'absolute', left: 48, right: 48, top: 56, fontFamily: SERIF, fontSize: 52, color: C.ink }}>
            <Typewriter start={40} cps={40} text="I want study history again." />
          </div>
        )}
      </Paper>

      <div style={{ position: 'absolute', left: L + 8, top: 1130, display: 'flex', alignItems: 'center', gap: 10, opacity: fadeIn(frame, 50) }}>
        <SparkleIcon size={38} />
        <Label color={C.clay}>AI 建議</Label>
      </div>
      <div style={{ position: 'absolute', left: L, top: 1190, width: W, height: 380, opacity: suggestion.opacity, transform: `rotate(${-0.5 - suggestion.extraTilt}deg) scale(${suggestion.scale})` }}>
        <Paper kind="sage" style={{ inset: 0 }}>
          <div style={{ position: 'absolute', left: 48, right: 48, top: 40 }}>
            <Label>更自然的說法</Label>
            <div style={{ fontFamily: SERIF, fontSize: 54, fontWeight: 700, color: C.ink, marginTop: 8 }}>
              <Typewriter start={58} cps={40} text="I'd love to study history again." />
            </div>
            <div style={{ fontSize: 38, color: C.inkSoft, marginTop: 6, opacity: fadeIn(frame, 74) }}>我很想再讀一次歷史。</div>
            <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginTop: 26, fontSize: 38, color: C.ink, opacity: fadeIn(frame, 78) }}>
              <BulbIcon />
              want 後面要接 to：<span style={{ fontFamily: SERIF, fontWeight: 700 }}>want to study</span>
            </div>
          </div>
        </Paper>
        <Tape width={58} angle={5} style={{ right: 80, top: -24 }} />
      </div>

      <div style={{ position: 'absolute', right: 70, top: 1600, opacity: fadeIn(frame, 80) }}>
        <Mascot mood="happy" size={230} phase={0.3} />
      </div>
      <PopBubble delay={82} origin="100% 50%" style={{ right: 320, top: 1680 }}>
        <Bubble text="嗯，有在讀喔。" fontSize={44} pointing="right" />
      </PopBubble>
    </Scene>
  );
};

/* ───────────────────────── AI 5. 學習分析 ───────────────────────── */

const AnalysisScene = () => {
  const frame = useFrame();
  const verdictAt = 26;
  const papers = [useSlap(34), useSlap(41), useSlap(48)];
  const go = usePop(56, 14);
  return (
    <Scene background={<Desk kind="desk" />}>
      <Headline lines={['每天一次，', '牠幫你抓弱點。']} top={140} />

      <div style={{ opacity: fadeIn(frame, 2) * fadeOut(frame, 13) }}>
        <PaperButton pressAt={9} style={{ left: L, top: 490, width: W, height: 130 }}>
          <SparkleIcon />
          讓小笨貓評評我最近學得怎樣
        </PaperButton>
      </div>

      {frame >= 13 ? (
        <div style={{ position: 'absolute', left: L, right: L, top: 480, opacity: fadeIn(frame, 13, 4) }}>
          <CatSays mood={frame < verdictAt ? 'idle' : 'smug'} size={130} phase={1.9}>
            {frame < verdictAt ? (
              <span style={{ color: C.inkSoft }}>
                讓我看看你最近有多混…… <TypingDots />
              </span>
            ) : (
              <Typewriter start={verdictAt} cps={45} text="看完了。嗯……我們需要談談。" style={{ fontWeight: 700 }} />
            )}
          </CatSays>
        </div>
      ) : null}

      {[
        { kind: 'sage' as const, top: 730, h: 200, tilt: -0.6, label: '做得好的地方', body: <div style={{ fontSize: 42, marginTop: 8 }}>連續 5 天都有練，測驗正確率 82%。</div> },
        {
          kind: 'peach' as const,
          top: 960,
          h: 230,
          tilt: 0.7,
          label: '這幾個字要加油',
          body: (
            <div style={{ display: 'flex', gap: 16, marginTop: 14 }}>
              {['abandon', 'objective', 'attend'].map((w) => (
                <span key={w} style={{ fontFamily: SERIF, fontWeight: 700, fontSize: 44, background: C.ivory, padding: '6px 22px', boxShadow: 'inset 0 0 0 2px rgba(43,38,32,0.3)' }}>
                  {w}
                </span>
              ))}
            </div>
          ),
        },
        { kind: 'graph' as const, top: 1220, h: 200, tilt: -0.4, label: '接下來幾天', body: <div style={{ fontSize: 42, marginTop: 8 }}>每天先清掉 8 個待複習，再學新字。</div> },
      ].map((p, i) => (
        <div key={p.label} style={{ position: 'absolute', left: L, top: p.top, width: W, height: p.h, opacity: papers[i].opacity, transform: `rotate(${p.tilt - papers[i].extraTilt}deg) scale(${papers[i].scale})` }}>
          <Paper kind={p.kind} style={{ inset: 0, boxShadow: `inset 0 0 0 ${K}px rgba(43,38,32,0.14)` }}>
            <div style={{ position: 'absolute', left: 48, right: 48, top: 36, color: C.ink }}>
              <Label color={C.ink} style={{ fontWeight: 900 }}>
                {p.label}
              </Label>
              {p.body}
            </div>
          </Paper>
        </div>
      ))}

      <div
        style={{
          position: 'absolute',
          left: L,
          right: L,
          top: 1470,
          height: 130,
          borderRadius: 999,
          background: C.clay,
          color: '#fff',
          fontSize: 48,
          fontWeight: 700,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          transform: `scale(${go})`,
        }}
      >
        現在練習這 3 個字
      </div>
      <Footnote delay={60} style={{ top: 1650 }}>
        根據最近 14 天的紀錄，背後是 Claude 線上 AI，可能有誤。
      </Footnote>
    </Scene>
  );
};

/* ───────────────────────── 掃描單字表 ───────────────────────── */

const SCANNED = [
  { word: 'objectively', pos: 'adv.', zh: '客觀地' },
  { word: 'objective', pos: 'n.', zh: '目標' },
  { word: 'carefully', pos: 'adv.', zh: '小心地' },
];

const ScanScene = () => {
  const frame = useFrame();
  const { fps } = useVideoConfig();
  const review = frame >= 44;
  const sweep = interpolate(frame, [8, 34], [0, 1], clamp);
  const photo = { left: 110, top: 520, w: 860, h: 620 };
  const stamp = useStampPress(74);
  const rowTop = (i: number) => 150 + i * 150;

  return (
    <Scene background={<Desk kind="desk" />}>
      <Headline lines={['課本單字表，', '拍一下就好。']} top={140} />

      {!review ? (
        <>
          <div style={{ position: 'absolute', left: photo.left, top: photo.top, width: photo.w, height: photo.h, transform: 'rotate(2deg)' }}>
            <Paper kind="ruled" style={{ inset: 0, boxShadow: `inset 0 0 0 ${K}px rgba(43,38,32,0.12)` }}>
              {SCANNED.map((row, i) => {
                const seen = sweep * photo.h > rowTop(i) + 60;
                return (
                  <div
                    key={row.word}
                    style={{
                      position: 'absolute',
                      left: 110,
                      top: rowTop(i) - 6,
                      display: 'flex',
                      alignItems: 'baseline',
                      gap: 26,
                      color: '#2F3A5C',
                      padding: '4px 14px',
                      boxShadow: seen ? `0 0 0 4px ${C.clay}` : 'none',
                      background: seen ? 'rgba(201,100,66,0.08)' : 'transparent',
                    }}
                  >
                    <span style={{ fontFamily: HAND, fontSize: 76, fontWeight: 600 }}>{row.word}</span>
                    <span style={{ fontFamily: HAND, fontSize: 52 }}>{row.pos}</span>
                    <span style={{ fontSize: 50, fontWeight: 500 }}>{row.zh}</span>
                  </div>
                );
              })}
            </Paper>
            {/* The scan line. */}
            <div
              style={{
                position: 'absolute',
                left: -20,
                right: -20,
                top: sweep * photo.h - 4,
                height: 8,
                background: C.clay,
                boxShadow: `0 0 30px 10px rgba(201,100,66,0.35)`,
                opacity: frame >= 8 && frame <= 36 ? 1 : 0,
              }}
            />
          </div>
          {/* Viewfinder corners. */}
          {[
            [photo.left - 40, photo.top - 50, 'top left'],
            [photo.left + photo.w - 50, photo.top - 30, 'top right'],
            [photo.left - 60, photo.top + photo.h - 40, 'bottom left'],
            [photo.left + photo.w - 30, photo.top + photo.h - 20, 'bottom right'],
          ].map(([x, y, corner]) => {
            const c = String(corner);
            return (
              <div
                key={c}
                style={{
                  position: 'absolute',
                  left: Number(x),
                  top: Number(y),
                  width: 90,
                  height: 90,
                  borderColor: C.ink,
                  borderStyle: 'solid',
                  borderWidth: `${c.includes('top') ? 8 : 0}px ${c.includes('right') ? 8 : 0}px ${c.includes('bottom') ? 8 : 0}px ${c.includes('left') ? 8 : 0}px`,
                }}
              />
            );
          })}
          <div style={{ position: 'absolute', left: 0, right: 0, top: 1240, textAlign: 'center', fontSize: 42, fontWeight: 700, color: C.inkSoft, opacity: fadeIn(frame, 10) }}>
            正在手機上辨識… <TypingDots />
          </div>
        </>
      ) : (
        <>
          <Label style={{ position: 'absolute', left: L + 8, top: 480, opacity: fadeIn(frame, 44) }}>找到 3 個單字</Label>
          <Paper kind="ivory" grain={0.5} style={{ left: L, top: 540, width: W, height: 540, boxShadow: `inset 0 0 0 ${1.5 * K}px rgba(43,38,32,0.45)` }}>
            {SCANNED.map((row, i) => {
              const s = spring({ frame: frame - (45 + i * 3), fps, config: { damping: 15, stiffness: 200 } });
              return (
                <div
                  key={row.word}
                  style={{
                    position: 'absolute',
                    left: 44,
                    right: 44,
                    top: 30 + i * 170,
                    height: 150,
                    display: 'flex',
                    alignItems: 'center',
                    gap: 28,
                    borderBottom: i < 2 ? '2px solid rgba(43,38,32,0.15)' : 'none',
                    opacity: s,
                    transform: `translateX(${(1 - s) * 60}px)`,
                  }}
                >
                  <div style={{ width: 60, height: 60, borderRadius: '50%', background: C.clay, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                    <Check color="#fff" size={40} />
                  </div>
                  <div>
                    <div style={{ fontFamily: SERIF, fontWeight: 800, fontSize: 54, color: C.ink }}>{row.word}</div>
                    <div style={{ fontSize: 38, color: C.ink }}>{row.zh}</div>
                  </div>
                  <div style={{ flex: 1 }} />
                  <span style={{ fontFamily: SERIF, fontSize: 38, color: C.clay }}>{row.pos.replace('.', '')}</span>
                </div>
              );
            })}
          </Paper>
          <div style={{ position: 'absolute', left: L + 8, top: 1110, display: 'flex', alignItems: 'center', gap: 10, fontSize: 32, color: C.inkSoft, opacity: fadeIn(frame, 56) }}>
            <SparkleIcon size={34} />
            由 Apple Intelligence 從頁面整理，請確認
          </div>
          <div
            style={{
              position: 'absolute',
              left: L,
              right: L,
              top: 1200,
              height: 130,
              borderRadius: 999,
              background: C.clay,
              color: '#fff',
              fontSize: 48,
              fontWeight: 700,
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              opacity: fadeIn(frame, 60),
              transform: `scale(${interpolate(frame, [67, 70, 74], [1, 0.95, 1], clamp)})`,
            }}
          >
            存入字庫（3 個）
          </div>
          <Stamp size={240} angle={-12} color={C.sage} style={{ right: 90, top: 760, opacity: stamp.opacity, transform: `rotate(-12deg) scale(${stamp.scale})` }}>
            <div style={{ fontWeight: 900, fontSize: 58, lineHeight: 1.1 }}>
              已存入
              <br />
              <span style={{ fontSize: 38 }}>字庫</span>
            </div>
          </Stamp>
        </>
      )}

      <Footnote delay={76} style={{ top: 1420, textAlign: 'center', fontSize: 36, color: C.inkSoft }}>
        印刷、手寫都可以，在手機上辨識，照片不會上傳。
      </Footnote>
    </Scene>
  );
};

/* ───────────────────────── 客製化 1. App 風格 ───────────────────────── */

const LeatherThumb = ({ w }: { w: number }) => (
  <div style={{ position: 'absolute', inset: 0, background: '#F3EEE4', padding: w * 0.07, display: 'flex', flexDirection: 'column', gap: w * 0.05 }}>
    <div style={{ height: w * 0.42, borderRadius: w * 0.08, background: 'linear-gradient(135deg, #C58C5C, #734A30)', position: 'relative' }}>
      <svg width={w * 0.28} height={w * 0.28} style={{ position: 'absolute', left: w * 0.07, top: w * 0.07 }} viewBox="0 0 100 100">
        <circle cx="50" cy="50" r="42" fill="none" stroke="rgba(255,242,224,0.25)" strokeWidth="14" />
        <circle cx="50" cy="50" r="42" fill="none" stroke="#FFF2E0" strokeWidth="14" strokeDasharray={`${2 * Math.PI * 42 * 0.35} 999`} transform="rotate(-90 50 50)" strokeLinecap="round" />
      </svg>
    </div>
    <div style={{ height: w * 0.2, borderRadius: w * 0.06, background: C.ivory, boxShadow: '0 6px 16px rgba(89,61,31,0.10)' }} />
    <div style={{ height: w * 0.3, display: 'flex', gap: w * 0.05 }}>
      <div style={{ flex: 1, borderRadius: w * 0.06, background: C.ivory, boxShadow: '0 6px 16px rgba(89,61,31,0.10)' }} />
      <div style={{ flex: 1, borderRadius: w * 0.06, background: C.ivory, boxShadow: '0 6px 16px rgba(89,61,31,0.10)' }} />
    </div>
  </div>
);

const CollageThumb = ({ w }: { w: number }) => {
  const inner = w * 0.86;
  return (
    <div style={{ position: 'absolute', inset: 0, background: '#F3EEE4', padding: w * 0.07, display: 'flex', flexDirection: 'column', gap: w * 0.05 }}>
      <div style={{ height: w * 0.42, display: 'flex', position: 'relative' }}>
        <div style={{ flex: 1, background: 'linear-gradient(180deg, #C78A5C, #9C613B)', clipPath: torn(inner - w * 0.32, w * 0.42, ['right'], 2, 3) }} />
        <div style={{ width: w * 0.32, position: 'relative', transform: 'rotate(1.5deg)' }}>
          <Paper kind="graph" style={{ inset: 0 }} />
        </div>
        <InkLoops width={inner} height={w * 0.1} count={5} strokeWidth={4} style={{ left: 0, top: w * 0.16 }} />
      </div>
      <div style={{ height: w * 0.2, position: 'relative', transform: 'rotate(-1deg)' }}>
        <Paper kind="ruled" style={{ inset: 0 }} />
      </div>
      <div style={{ height: w * 0.3, display: 'flex', gap: w * 0.05 }}>
        <div style={{ flex: 1, position: 'relative', transform: 'rotate(1deg)' }}>
          <Paper kind="graph" style={{ inset: 0 }} />
        </div>
        <div style={{ flex: 1, position: 'relative', clipPath: torn((inner - w * 0.05) / 2, w * 0.3, ['bottom'], 5, 3) }}>
          <Paper kind="peach" style={{ inset: 0 }} />
        </div>
      </div>
    </div>
  );
};

const StyleScene = () => {
  const frame = useFrame();
  const chooseAt = 30;
  const collage = frame >= chooseAt;
  const flip = interpolate(frame, [chooseAt + 6, chooseAt + 11, chooseAt + 16], [1, 0, 1], clamp);
  const cardW = (W - 32) / 2;
  const thumbW = cardW - 40;
  const cards = [
    { id: 'leather', label: '皮革經典', detail: '暖紙與焦糖皮革，圓角卡片、柔和光影。', Thumb: LeatherThumb, on: !collage },
    { id: 'collage', label: '紙張拼貼', detail: '方格紙、索引卡、膠帶與手繪線。', Thumb: CollageThumb, on: collage },
  ];
  return (
    <Scene background={<Desk kind="desk" />}>
      <Headline lines={['你的 App，', '你的樣子。']} top={140} />
      {cards.map(({ id, label, detail, Thumb, on }, i) => {
        const appear = fadeIn(frame, 4 + i * 4, 8);
        const press = id === 'collage' ? interpolate(frame, [chooseAt - 3, chooseAt, chooseAt + 4], [1, 0.96, 1], clamp) : 1;
        return (
          <div
            key={id}
            style={{
              position: 'absolute',
              left: L + i * (cardW + 32),
              top: 480,
              width: cardW,
              height: 960,
              background: C.ivory,
              borderRadius: 40,
              boxShadow: on ? `inset 0 0 0 6px ${C.clay}` : 'inset 0 0 0 2px rgba(43,38,32,0.12)',
              opacity: appear,
              transform: `translateY(${(1 - appear) * 60}px) scale(${press})`,
            }}
          >
            <div style={{ position: 'absolute', left: 20, top: 20, width: thumbW, height: thumbW / 0.62, borderRadius: 26, overflow: 'hidden' }}>
              <Thumb w={thumbW} />
            </div>
            <div style={{ position: 'absolute', left: 28, right: 28, top: 20 + thumbW / 0.62 + 24, display: 'flex', alignItems: 'center' }}>
              <span style={{ fontSize: 46, fontWeight: 900, color: C.ink }}>{label}</span>
              <div style={{ flex: 1 }} />
              <div
                style={{
                  width: 52,
                  height: 52,
                  borderRadius: '50%',
                  background: on ? C.clay : 'transparent',
                  boxShadow: on ? 'none' : `inset 0 0 0 4px ${C.inkFaint}`,
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                }}
              >
                {on ? <Check color="#fff" size={36} /> : null}
              </div>
            </div>
            <div style={{ position: 'absolute', left: 28, right: 28, top: 20 + thumbW / 0.62 + 96, fontSize: 30, lineHeight: 1.4, color: C.inkSoft }}>{detail}</div>
          </div>
        );
      })}

      <div style={{ position: 'absolute', left: L, right: L, top: 1500, display: 'flex', alignItems: 'center', gap: 40, opacity: fadeIn(frame, 12) }}>
        <Img
          src={staticFile(frame >= chooseAt + 11 ? 'icon-collage.png' : 'icon.png')}
          style={{ width: 200, height: 200, borderRadius: 46, transform: `scaleX(${flip})`, boxShadow: '0 0 0 2px rgba(43,38,32,0.12)' }}
        />
        <div style={{ flex: 1 }}>
          <div style={{ display: 'flex', alignItems: 'center' }}>
            <span style={{ fontSize: 46, fontWeight: 900, color: C.ink }}>圖示跟著換</span>
            <div style={{ flex: 1 }} />
            <div style={{ width: 120, height: 72, borderRadius: 999, background: C.sage, position: 'relative' }}>
              <div style={{ position: 'absolute', right: 6, top: 6, width: 60, height: 60, borderRadius: '50%', background: '#fff' }} />
            </div>
          </div>
          <div style={{ fontSize: 32, color: C.inkSoft, marginTop: 10, lineHeight: 1.4 }}>換風格只改外觀，學習紀錄和小笨貓都一樣。</div>
        </div>
      </div>
    </Scene>
  );
};

/* ───────────────────────── 客製化 2. 設定 ───────────────────────── */

const Segmented = ({ options, selected, from, at }: { options: string[]; selected: number; from?: number; at?: number }) => {
  const frame = useFrame();
  const { fps } = useVideoConfig();
  const t = at === undefined || from === undefined ? 1 : spring({ frame: frame - at, fps, config: { damping: 16, stiffness: 220 } });
  const index = from === undefined ? selected : from + (selected - from) * t;
  const cell = 100 / options.length;
  return (
    <div style={{ position: 'relative', display: 'flex', background: 'rgba(43,38,32,0.07)', borderRadius: 999, padding: 6, width: 560 }}>
      <div
        style={{
          position: 'absolute',
          top: 6,
          bottom: 6,
          left: `calc(${index * cell}% + 6px)`,
          width: `calc(${cell}% - 12px)`,
          borderRadius: 999,
          background: '#fff',
          boxShadow: '0 2px 6px rgba(43,38,32,0.15)',
        }}
      />
      {options.map((o, i) => {
        const active = Math.round(index) === i;
        return (
          <div key={o} style={{ flex: 1, textAlign: 'center', position: 'relative', fontSize: 34, fontWeight: active ? 900 : 500, color: active ? C.ink : C.inkSoft, padding: '12px 0' }}>
            {o}
          </div>
        );
      })}
    </div>
  );
};

const SettingsScene = () => {
  const frame = useFrame();
  const { fps } = useVideoConfig();
  const remindOn = spring({ frame: frame - 50, fps, config: { damping: 16, stiffness: 220 } });
  const rows: { label: string; control: ReactNode }[] = [
    { label: '每日目標', control: <Segmented options={['10', '20', '30', '50']} from={1} selected={2} at={16} /> },
    { label: '學習語言', control: <Segmented options={['學英文', '學中文']} selected={0} /> },
    { label: '朗讀語速', control: <Segmented options={['慢速', '自然', '稍快']} from={1} selected={0} at={28} /> },
    {
      label: '單字集',
      control: (
        <div style={{ display: 'flex', gap: 12, width: 560, justifyContent: 'flex-end' }}>
          {['7000 單字', '掃描 10/31', '考前衝刺'].map((b, i) => {
            const on = frame >= 40 ? i === 2 : i === 0;
            return (
              <span key={b} style={{ fontSize: 30, fontWeight: 700, padding: '10px 18px', background: on ? C.clay : 'rgba(43,38,32,0.07)', color: on ? '#fff' : C.inkSoft, borderRadius: 999 }}>
                {b}
              </span>
            );
          })}
        </div>
      ),
    },
    {
      label: '學習提醒',
      control: (
        <div style={{ display: 'flex', alignItems: 'center', gap: 20, width: 560, justifyContent: 'flex-end' }}>
          <span style={{ fontSize: 34, color: C.inkSoft, opacity: remindOn }}>每天 12:00</span>
          <div style={{ width: 120, height: 72, borderRadius: 999, background: remindOn > 0.5 ? C.sage : 'rgba(43,38,32,0.15)', position: 'relative' }}>
            <div style={{ position: 'absolute', left: 6 + remindOn * 48, top: 6, width: 60, height: 60, borderRadius: '50%', background: '#fff', boxShadow: '0 2px 6px rgba(0,0,0,0.2)' }} />
          </div>
        </div>
      ),
    },
  ];
  return (
    <Scene background={<Desk kind="desk" />}>
      <Headline lines={['每個設定，', '都照你的。']} top={140} />
      <Paper kind="ivory" grain={0.5} style={{ left: L, top: 480, width: W, height: 5 * 186 + 20, boxShadow: `inset 0 0 0 ${1.5 * K}px rgba(43,38,32,0.4)` }}>
        {rows.map((row, i) => (
          <div
            key={row.label}
            style={{
              position: 'absolute',
              left: 44,
              right: 44,
              top: 10 + i * 186,
              height: 186,
              display: 'flex',
              alignItems: 'center',
              borderBottom: i < rows.length - 1 ? '2px solid rgba(43,38,32,0.12)' : 'none',
              opacity: fadeIn(frame, 3 + i * 3),
            }}
          >
            <span style={{ fontSize: 44, fontWeight: 900, color: C.ink }}>{row.label}</span>
            <div style={{ flex: 1 }} />
            {row.control}
          </div>
        ))}
      </Paper>
      <div style={{ position: 'absolute', right: 70, top: 1530, opacity: fadeIn(frame, 54) }}>
        <Mascot mood="smug" size={250} phase={1.4} />
      </div>
      <PopBubble delay={56} origin="100% 50%" style={{ right: 340, top: 1620 }}>
        <Bubble text="好啦，你很棒。滿意了吧？" fontSize={44} pointing="right" />
      </PopBubble>
    </Scene>
  );
};

/* ───────────────────────── 每日提醒：鎖定畫面 ───────────────────────── */

const ReminderScene = () => {
  const frame = useFrame();
  const { fps } = useVideoConfig();
  const card = spring({ frame: frame - 8, fps, config: { damping: 15, stiffness: 150 } });
  const left = Math.max(0, 11 * 3600 + 59 * 60 + 59 - Math.floor(frame / fps));
  const hh = Math.floor(left / 3600);
  const mm = String(Math.floor((left % 3600) / 60)).padStart(2, '0');
  const ss = String(left % 60).padStart(2, '0');
  return (
    <AbsoluteFill style={{ fontFamily: FONT, overflow: 'hidden' }}>
      <AbsoluteFill style={{ background: 'linear-gradient(170deg, #4A3426 0%, #8A5A3C 55%, #C98C5E 100%)' }} />
      <AbsoluteFill style={{ background: 'radial-gradient(circle at 20% 30%, rgba(255,220,180,0.25), transparent 40%), radial-gradient(circle at 80% 75%, rgba(242,205,176,0.3), transparent 45%)' }} />
      <div style={{ position: 'absolute', left: 0, right: 0, top: 230, textAlign: 'center', color: 'rgba(255,255,255,0.85)', fontSize: 50, fontWeight: 700 }}>11月3日 星期一</div>
      <div style={{ position: 'absolute', left: 0, right: 0, top: 290, textAlign: 'center', color: '#fff', fontSize: 280, fontWeight: 700, letterSpacing: '-0.02em', lineHeight: 1 }}>12:00</div>

      <div
        style={{
          position: 'absolute',
          left: 50,
          right: 50,
          top: 700,
          height: 330,
          borderRadius: 70,
          background: 'rgba(28,20,16,0.62)',
          backdropFilter: 'blur(30px)',
          padding: '44px 50px',
          color: '#fff',
          transform: `translateY(${(1 - card) * 600}px)`,
          opacity: card,
        }}
      >
        <div style={{ display: 'flex', alignItems: 'center', gap: 30 }}>
          <Img src={staticFile('icon-collage.png')} style={{ width: 110, height: 110, borderRadius: 26 }} />
          <div style={{ flex: 1 }}>
            <div style={{ fontSize: 46, fontWeight: 900 }}>單字不會自己背好喔</div>
            <div style={{ fontSize: 34, opacity: 0.75, marginTop: 4 }}>再學 13 個單字，完成今天目標</div>
          </div>
          <div style={{ fontSize: 46, fontWeight: 900, color: '#FFB347' }}>7/20</div>
        </div>
        <div style={{ height: 16, borderRadius: 8, background: 'rgba(255,255,255,0.2)', marginTop: 40, overflow: 'hidden' }}>
          <div style={{ width: `${(7 / 20) * 100}%`, height: '100%', background: '#FFB347', borderRadius: 8 }} />
        </div>
        <div style={{ display: 'flex', marginTop: 16, fontSize: 30, opacity: 0.75 }}>
          今日進度
          <div style={{ flex: 1 }} />
          <span style={{ fontVariantNumeric: 'tabular-nums' }}>
            {hh}:{mm}:{ss}
          </span>
        </div>
      </div>

      <div style={{ position: 'absolute', top: 1130, left: 96, right: 96, fontWeight: 900, fontSize: 128, lineHeight: 1.14, color: '#fff' }}>
        <div>
          <BlurIn delay={14}>每天中午，</BlurIn>
        </div>
        <div>
          <BlurIn delay={20}>牠會來敲你。</BlurIn>
        </div>
      </div>
      <div style={{ position: 'absolute', left: 70, top: 1540, opacity: fadeIn(frame, 30) }}>
        <Mascot mood="smug" size={260} phase={0.9} />
      </div>
      <PopBubble delay={34} origin="0% 50%" style={{ left: 350, top: 1620 }}>
        <Bubble text="明天同一時間，我會來找你。" fontSize={42} pointing="left" />
      </PopBubble>
    </AbsoluteFill>
  );
};

const COMPONENTS: Record<(typeof SCENES)[number]['id'], () => ReactElement> = {
  hook: HookScene,
  meet: () => <MeetScene stampText={['AI', '家教']} caption="嘴有點壞的 AI 單字家教" />,
  explain: ExplainScene,
  ask: AskScene,
  why: WhyScene,
  coach: CoachScene,
  analysis: AnalysisScene,
  scan: ScanScene,
  style: StyleScene,
  settings: SettingsScene,
  reminder: ReminderScene,
  end: () => <EndScene footnote="線上 AI 每日可用次數依方案而定。" />,
};

export const Full = () => (
  <AbsoluteFill style={{ background: '#F3EEE4' }}>
    {scaleScenes(SCENES).map(({ id, from, duration }) => {
      const Component = COMPONENTS[id];
      return (
        <Sequence key={id} from={from} durationInFrames={duration} name={id}>
          <Component />
        </Sequence>
      );
    })}
  </AbsoluteFill>
);
