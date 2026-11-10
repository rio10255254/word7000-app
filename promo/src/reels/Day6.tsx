import { type RefObject, useMemo } from 'react';
import { ThreeCanvas } from '@remotion/three';
import { AbsoluteFill, Html5Audio, staticFile, useCurrentFrame } from 'remotion';
import * as THREE from 'three';
import { FONT } from '../fonts';
import script from './episodes.json';
import timings from './timing.json';
import { REEL_FPS } from './Reel';
import { Caption } from './Intro';
import { CAPTION_TOP, Peek } from './Teaser';
import { CountdownEnd, DaysStamp, StampCard } from './Countdown';
import { Backdrop, Grade, InkFilters, Motes } from './finish';
import {
  Card,
  type CatMaps,
  CatSource,
  CatStandee,
  F_SANS,
  F_SERIF,
  F_SERIF_TC,
  PAL,
  PHONE,
  Phone3D,
  Rig,
  type Shot,
  Tap3D,
  back,
  canvasTexture,
  catTextures,
  faceGeometry,
  imageTexture,
  inOut,
  label,
  land,
  onScreen,
  out,
  paper,
  ramp,
  roundedRect,
  shotAt,
  slabGeometry,
  useHolder,
  usePrepared,
  wornInk,
} from './three/kit';

/**
 * 11/10, six days to go: the study plan, acted out on a desk in 3D.
 *
 * Cover (the days-left card and 傻貓 peeking, as every day of the
 * countdown opens). Then the camera drops onto the desk: a deck of word
 * cards fans out and five turn over, right or wrong, and a label says
 * where you start. Across to the phone on the real plan screen: a tap on
 * the date, and a tear-off calendar jumps out of the glass and flips to
 * the day. The camera lifts: the calendar lands at the far end of the
 * desk, a paper road unrolls to it from the phone, milestones stand up
 * along it one beat at a time, a counter runs up to the day's words, and
 * 傻貓 hops the whole way to the flag.
 *
 * The copy on every object is in the episode's `scene` in episodes.json.
 */

const BEAT = 0.5;
const PI = Math.PI;

type Slot = { start: number; length: number };
type Scene = {
  cards: [string, string, boolean][];
  cardFont: 'serif' | 'tc';
  level: [string, string];
  tap: [[number, number, number, number], [number, number]];
  phoneLook: number;
  pages: [string, string, string, string][];
  calendarTag: string;
  stones: string[];
  counter: [string, string, string];
  flag: string;
};
type Episode = {
  id: string;
  days: number;
  app: string;
  label: string;
  screen: string;
  dayWords: [string, string];
  note: string;
  outro: string;
  lines: { text: string }[];
  scene: Scene;
};

// ── where things are on the desk (x right, y up, z towards the viewer) ──
const FAN = { x: 1.7, z: 3.7, radius: 2.5, step: (13.6 * PI) / 180 };
const CARD = { w: 0.6, h: 0.84 };
const DECK = { x: 0.6, z: 2.5 };
const PHONE_AT = { x: -1.15, z: 2.3, turn: 0.16, tilt: 0.2 };
const PHONE_Y = PHONE.depth / 2 + (PHONE.h / 2 + PHONE.rim) * Math.sin(PHONE_AT.tilt);
const CAL = { w: 1.3, h: 1.5, head: 0.3 };
const CAL_STAND = { x: 1.5, z: -2.6, lean: -0.2, turn: -0.14, scale: 1.2 };
const ROAD_POINTS: [number, number][] = [
  [-1.1, 1.15],
  [-0.2, 0.75],
  [0.95, 0.25],
  [0.6, -0.7],
  [-0.75, -1.0],
  [-0.7, -1.9],
  [0.4, -2.2],
  [0.95, -2.55],
];
const ROAD_W = 0.44;
const STONE_AT = [0.2, 0.42, 0.63, 0.84];
const COUNTER_AT = { x: -1.3, z: 0.25 };

/** A point in the phone's own space, in the world. */
const phoneMatrix = new THREE.Matrix4()
  .makeTranslation(PHONE_AT.x, PHONE_Y, PHONE_AT.z)
  .multiply(new THREE.Matrix4().makeRotationY(PHONE_AT.turn))
  .multiply(new THREE.Matrix4().makeRotationX(-PI / 2 + PHONE_AT.tilt));
const fromPhone = (x: number, y: number) => new THREE.Vector3(...onScreen(x, y, 0.02)).applyMatrix4(phoneMatrix);

const roadCurve = new THREE.CatmullRomCurve3(
  ROAD_POINTS.map(([x, z]) => new THREE.Vector3(x, 0, z * 0.84 + 0.18)),
  false,
  'catmullrom',
  0.5,
);

// ───────────────────────── textures ─────────────────────────

const buildMaps = async (episode: Episode, holder: RefObject<HTMLDivElement | null>) => {
  const s = episode.scene;
  for (let i = 0; i < 40 && !holder.current?.querySelector('svg'); i++) await new Promise((r) => setTimeout(r, 25));
  const [screen, cats] = await Promise.all([imageTexture(`${episode.screen}.jpg`), catTextures(holder.current!)]);
  const wordFont = s.cardFont === 'tc' ? F_SERIF_TC : F_SERIF;
  const wordWeight = s.cardFont === 'tc' ? 900 : 800;

  const desk = canvasTexture(1024, 1024, (ctx, w, h) => paper(ctx, w, h, PAL.olive, 11, 1.1));
  desk.wrapS = desk.wrapT = THREE.RepeatWrapping;
  desk.repeat.set(9, 9);

  // The word cards: the app's ruled index card on the front, the meaning and a mark on the back.
  const cardFront = s.cards.map(([word], i) =>
    canvasTexture(480, 672, (ctx, w, h) => {
      paper(ctx, w, h, PAL.cream, 20 + i);
      ctx.strokeStyle = 'rgba(150,180,200,0.55)';
      ctx.lineWidth = 2;
      for (let y = 120; y < h - 30; y += 46) {
        ctx.beginPath();
        ctx.moveTo(0, y);
        ctx.lineTo(w, y);
        ctx.stroke();
      }
      ctx.strokeStyle = 'rgba(227,151,135,0.9)';
      ctx.beginPath();
      ctx.moveTo(52, 0);
      ctx.lineTo(52, h);
      ctx.stroke();
      ctx.fillStyle = PAL.cream;
      ctx.fillRect(70, 250, w - 90, 150);
      label(ctx, word, w / 2 + 16, 322, wordFont, s.cardFont === 'tc' ? 150 : 96, PAL.ink, w - 130, wordWeight);
    }),
  );
  const cardBack = s.cards.map(([, meaning, right], i) =>
    canvasTexture(480, 672, (ctx, w, h) => {
      paper(ctx, w, h, right ? '#EEF2E2' : '#F8E6DA', 40 + i);
      label(ctx, meaning, w / 2, 150, s.cardFont === 'tc' ? F_SERIF : F_SANS, 76, PAL.ink, w - 80, s.cardFont === 'tc' ? 800 : 900);
      const color = right ? PAL.sage : PAL.clay;
      ctx.strokeStyle = color;
      ctx.lineWidth = 22;
      ctx.lineCap = 'round';
      ctx.lineJoin = 'round';
      ctx.beginPath();
      ctx.arc(w / 2, 420, 132, 0, PI * 2);
      ctx.stroke();
      ctx.lineWidth = 30;
      ctx.beginPath();
      if (right) {
        ctx.moveTo(w / 2 - 66, 424);
        ctx.lineTo(w / 2 - 16, 474);
        ctx.lineTo(w / 2 + 70, 368);
      } else {
        ctx.moveTo(w / 2 - 56, 364);
        ctx.lineTo(w / 2 + 56, 476);
        ctx.moveTo(w / 2 + 56, 364);
        ctx.lineTo(w / 2 - 56, 476);
      }
      ctx.stroke();
      wornInk(ctx, w, h, 5 + i, 0.5);
      ctx.globalCompositeOperation = 'destination-over';
      paper(ctx, w, h, right ? '#EEF2E2' : '#F8E6DA', 40 + i);
    }),
  );

  // Where you start, as a stamped label.
  const level = canvasTexture(900, 330, (ctx, w, h) => {
    paper(ctx, w, h, PAL.cream, 61);
    const layer = document.createElement('canvas');
    layer.width = w;
    layer.height = h;
    const ink = layer.getContext('2d')!;
    ink.strokeStyle = PAL.clay;
    ink.lineWidth = 9;
    ink.beginPath();
    ink.roundRect(22, 22, w - 44, h - 44, 30);
    ink.stroke();
    ink.fillStyle = PAL.sage;
    ink.beginPath();
    ink.arc(120, h / 2, 62, 0, PI * 2);
    ink.fill();
    ink.strokeStyle = PAL.cream;
    ink.lineWidth = 16;
    ink.lineCap = 'round';
    ink.lineJoin = 'round';
    ink.beginPath();
    ink.moveTo(90, h / 2 + 2);
    ink.lineTo(112, h / 2 + 26);
    ink.lineTo(152, h / 2 - 24);
    ink.stroke();
    label(ink, s.level[0], 530, 102, F_SANS, 50, PAL.sage, 620, 900);
    label(ink, s.level[1], 530, 208, F_SERIF_TC, 96, PAL.clay, 640, 900);
    wornInk(ink, w, h, 8, 0.45);
    ctx.drawImage(layer, 0, 0);
  });

  // The calendar: a clay header per page (it changes as the pages turn) and the pages.
  const head = s.pages.map(([a, b], i) =>
    canvasTexture(832, 192, (ctx, w, h) => {
      paper(ctx, w, h, PAL.clay, 70 + i, 0.6);
      label(ctx, b ? `${a}　${b}` : a, w / 2, h / 2 + 16, b ? F_SERIF_TC : F_SANS, b ? 84 : 72, '#FFF6E8', w - 120, 900);
    }),
  );
  const pages = s.pages.map(([, , big, small], i) =>
    canvasTexture(768, 704, (ctx, w, h) => {
      paper(ctx, w, h, PAL.cream, 80 + i);
      label(ctx, big, w / 2, small ? 300 : 340, F_SERIF, big.length > 2 ? 250 : 400, PAL.ink, w - 110, 800);
      if (small) label(ctx, small, w / 2, 560, F_SANS, 84, 'rgba(43,38,32,0.72)', w - 300, 700);
    }),
  );
  const blank = canvasTexture(256, 256, (ctx, w, h) => paper(ctx, w, h, PAL.cream, 99));
  const board = canvasTexture(256, 256, (ctx, w, h) => paper(ctx, w, h, '#D9CDB0', 98));
  const tag = canvasTexture(560, 250, (ctx, w, h) => {
    paper(ctx, w, h, PAL.cream, 97);
    const layer = document.createElement('canvas');
    layer.width = w;
    layer.height = h;
    const ink = layer.getContext('2d')!;
    ink.strokeStyle = PAL.clay;
    ink.lineWidth = 12;
    ink.beginPath();
    ink.roundRect(20, 20, w - 40, h - 40, 34);
    ink.stroke();
    label(ink, s.calendarTag, w / 2, h / 2 + 8, F_SERIF_TC, 128, PAL.clay, w - 100, 900);
    wornInk(ink, w, h, 12, 0.5);
    ctx.drawImage(layer, 0, 0);
  });

  // The road: cream paper with a dashed centre line, tiled along its length.
  const road = canvasTexture(256, 256, (ctx, w, h) => {
    paper(ctx, w, h, '#F6EEDC', 51);
    ctx.fillStyle = PAL.clay;
    ctx.fillRect(w / 2 - 9, 40, 18, 150);
    ctx.fillStyle = 'rgba(88,100,59,0.5)';
    ctx.fillRect(0, 0, 9, h);
    ctx.fillRect(w - 9, 0, 9, h);
  });
  road.wrapT = THREE.RepeatWrapping;

  const stoneColors = [PAL.peach, PAL.mustard, PAL.sageLight, PAL.cream];
  const stones = s.stones.map((text, i) =>
    canvasTexture(640, 384, (ctx, w, h) => {
      paper(ctx, w, h, stoneColors[i % 4], 30 + i);
      ctx.strokeStyle = 'rgba(43,38,32,0.5)';
      ctx.lineWidth = 6;
      ctx.setLineDash([18, 14]);
      ctx.beginPath();
      ctx.roundRect(26, 26, w - 52, h - 52, 26);
      ctx.stroke();
      label(ctx, text, w / 2, h / 2 + 8, F_SERIF_TC, 150, PAL.ink, w - 120, 900);
    }),
  );
  const flag = canvasTexture(512, 320, (ctx, w, h) => {
    paper(ctx, w, h, PAL.clay, 77, 0.6);
    label(ctx, s.flag, w * 0.42, h / 2 + 6, F_SERIF_TC, 150, '#FFF6E8', w * 0.62, 900);
  });
  const counter = (value: number) =>
    canvasTexture(768, 608, (ctx, w, h) => {
      paper(ctx, w, h, PAL.cream, 55);
      label(ctx, s.counter[0], w / 2, 96, F_SANS, 78, 'rgba(43,38,32,0.78)', w - 120, 900);
      // Two flip tiles for the digits.
      const text = String(value).padStart(2, ' ');
      [0, 1].forEach((k) => {
        const x = w / 2 - 190 + k * 200;
        ctx.fillStyle = '#2F2A24';
        ctx.beginPath();
        ctx.roundRect(x, 160, 180, 270, 26);
        ctx.fill();
        ctx.fillStyle = 'rgba(255,255,255,0.07)';
        ctx.fillRect(x, 160, 180, 135);
        ctx.fillStyle = 'rgba(0,0,0,0.5)';
        ctx.fillRect(x, 292, 180, 5);
        if (text[k] !== ' ') label(ctx, text[k], x + 90, 302, F_SERIF, 230, '#FFD98C', undefined, 800);
      });
      label(ctx, s.counter[2], w / 2, 516, F_SANS, 84, PAL.clay, w - 120, 900);
    });
  const sheets = [
    canvasTexture(512, 640, (ctx, w, h) => {
      ctx.fillStyle = 'rgba(240,244,222,0.2)';
      ctx.fillRect(0, 0, w, h);
      ctx.strokeStyle = 'rgba(255,255,240,0.3)';
      ctx.lineWidth = 2;
      for (let x = 0; x <= w; x += 32) {
        ctx.beginPath();
        ctx.moveTo(x, 0);
        ctx.lineTo(x, h);
        ctx.stroke();
      }
      for (let y = 0; y <= h; y += 32) {
        ctx.beginPath();
        ctx.moveTo(0, y);
        ctx.lineTo(w, y);
        ctx.stroke();
      }
    }),
    canvasTexture(512, 512, (ctx, w, h) => {
      ctx.fillStyle = 'rgba(250,246,230,0.18)';
      ctx.fillRect(0, 0, w, h);
      ctx.strokeStyle = 'rgba(255,255,240,0.32)';
      ctx.lineWidth = 2;
      for (let y = 40; y <= h; y += 52) {
        ctx.beginPath();
        ctx.moveTo(0, y);
        ctx.lineTo(w, y);
        ctx.stroke();
      }
    }),
  ];
  return { screen, cats, desk, cardFront, cardBack, level, head, pages, blank, board, tag, road, stones, flag, counter, sheets };
};
type Maps = Awaited<ReturnType<typeof buildMaps>>;

// ───────────────────────── pieces ─────────────────────────

/** A calendar page mid-turn: hinged along its top edge, curling as it lifts. */
const TurningPage = ({ w, h, angle, curl, map, blank }: { w: number; h: number; angle: number; curl: number; map: THREE.Texture; blank: THREE.Texture }) => {
  const geometry = useMemo(() => {
    const rows = 14;
    const g = new THREE.BufferGeometry();
    const pos: number[] = [];
    const uv: number[] = [];
    const index: number[] = [];
    let y = 0;
    let z = 0;
    for (let k = 0; k <= rows; k++) {
      if (k > 0) {
        const a = angle + curl * ((k - 0.5) / rows);
        y -= (Math.cos(a) * h) / rows;
        z += (Math.sin(a) * h) / rows;
      }
      pos.push(-w / 2, y, z, w / 2, y, z);
      uv.push(0, 1 - k / rows, 1, 1 - k / rows);
      if (k < rows) index.push(k * 2, k * 2 + 2, k * 2 + 1, k * 2 + 1, k * 2 + 2, k * 2 + 3);
    }
    g.setAttribute('position', new THREE.Float32BufferAttribute(pos, 3));
    g.setAttribute('uv', new THREE.Float32BufferAttribute(uv, 2));
    g.setIndex(index);
    g.computeVertexNormals();
    return g;
  }, [w, h, angle, curl]);
  return (
    <>
      <mesh geometry={geometry} castShadow>
        <meshStandardMaterial map={map} roughness={0.92} side={THREE.FrontSide} />
      </mesh>
      <mesh geometry={geometry}>
        <meshStandardMaterial map={blank} roughness={0.92} side={THREE.BackSide} />
      </mesh>
    </>
  );
};

/**
 * The tear-off calendar. `flips` are the times its pages turn; the ring
 * is drawn round the last page's number at `ringAt`, and the tag is
 * stamped on at `tagAt`.
 */
const Calendar3D = ({ t, maps, flips, ringAt, tagAt }: { t: number; maps: Maps; flips: number[]; ringAt: number; tagAt: number }) => {
  const { w, h, head } = CAL;
  const pw = w - 0.1;
  const ph = h - head - 0.1;
  const hinge = h / 2 - head - 0.015;
  const FLIP = 0.36;
  // The page on top, and the one turning away above it.
  let top = 0;
  flips.forEach((at, i) => {
    if (t >= at) top = i + 1;
  });
  const turning = flips.findIndex((at) => t >= at && t < at + FLIP);
  const p = turning < 0 ? 0 : (t - flips[turning]) / FLIP;
  const headIndex = turning >= 0 && p < 0.45 ? turning : top;
  const geo = useMemo(() => {
    const header = roundedRect(w + 0.04, head, 0.05);
    const pad = roundedRect(pw, ph, 0.02);
    const loop: THREE.Vector3[] = [];
    for (let i = 0; i <= 60; i++) {
      const a = -0.5 + (i / 60) * (PI * 2 + 0.75);
      const r = 1 + 0.07 * Math.sin(a * 2 + 1) - 0.1 * (i / 60);
      loop.push(new THREE.Vector3(Math.cos(a) * 0.44 * r, Math.sin(a) * 0.33 * r, 0));
    }
    return {
      header: slabGeometry(header, 0.1),
      headerFace: faceGeometry(header, w + 0.04, head),
      pad: slabGeometry(pad, 0.07),
      padFace: faceGeometry(pad, pw, ph),
      ring: new THREE.TubeGeometry(new THREE.CatmullRomCurve3(loop), 120, 0.017, 6, false),
    };
  }, [w, head, pw, ph]);
  const ring = ramp(t, ringAt, ringAt + 0.4, inOut);
  geo.ring.setDrawRange(0, Math.floor(120 * ring) * 6 * 6);
  const tagP = ramp(t, tagAt - 0.12, tagAt, (n) => n * n * n);
  const tagSettle = land(t, tagAt, 0.3);
  const last = maps.pages.length - 1;
  return (
    <group>
      <Card w={w} h={h} r={0.05} depth={0.05} front={maps.board} edge="#C4B690" backColor="#C4B690" />
      <mesh geometry={geo.pad} position={[0, hinge - ph / 2, 0.06]} castShadow receiveShadow>
        <meshStandardMaterial color={PAL.creamEdge} roughness={0.95} />
      </mesh>
      <mesh geometry={geo.padFace} position={[0, hinge - ph / 2, 0.0965]} receiveShadow>
        <meshStandardMaterial map={maps.pages[Math.min(top, last)]} roughness={0.92} />
      </mesh>
      {turning >= 0 ? (
        <group position={[0, hinge, 0.1]}>
          <TurningPage w={pw} h={ph} angle={inOut(p) * PI * 0.93} curl={Math.sin(p * PI) * 0.9} map={maps.pages[turning]} blank={maps.blank} />
        </group>
      ) : null}
      {/* The header binds the pages; two rings hold it. */}
      <mesh geometry={geo.header} position={[0, h / 2 - head / 2, 0.055]} castShadow receiveShadow>
        <meshStandardMaterial color="#B3542F" roughness={0.9} />
      </mesh>
      <mesh geometry={geo.headerFace} position={[0, h / 2 - head / 2, 0.1065]}>
        <meshStandardMaterial map={maps.head[Math.min(headIndex, last)]} roughness={0.9} />
      </mesh>
      {[-0.34, 0.34].map((x) => (
        <mesh key={x} position={[x, h / 2 + 0.005, 0.03]} rotation={[0, PI / 2, 0]} castShadow>
          <torusGeometry args={[0.085, 0.017, 10, 28]} />
          <meshStandardMaterial color="#9A948A" metalness={0.6} roughness={0.35} />
        </mesh>
      ))}
      {ring > 0 ? (
        <mesh geometry={geo.ring} position={[0, hinge - ph / 2 + 0.1, 0.105]}>
          <meshStandardMaterial color={PAL.clay} roughness={0.7} />
        </mesh>
      ) : null}
      {t >= tagAt - 0.12 ? (
        <group position={[w / 2 - 0.1, hinge - ph - 0.05, 0.1 + (1 - tagP) * 0.7]} rotation={[0, 0, 0.14]} scale={(1.5 - 0.5 * tagP) * (0.94 + 0.06 * tagSettle)}>
          <Card w={0.62} h={0.28} r={0.04} depth={0.02} front={maps.tag} />
        </group>
      ) : null}
    </group>
  );
};

/** The road, laid on the desk from its start as far as `progress` (0–1). */
const Road = ({ progress, map }: { progress: number; map: THREE.Texture }) => {
  const SEG = 260;
  const geometry = useMemo(() => {
    const build = (width: number, y: number) => {
      const g = new THREE.BufferGeometry();
      const pos: number[] = [];
      const uv: number[] = [];
      const index: number[] = [];
      const length = roadCurve.getLength();
      for (let i = 0; i <= SEG; i++) {
        const u = i / SEG;
        const p = roadCurve.getPointAt(u);
        const d = roadCurve.getTangentAt(u);
        const nx = -d.z;
        const nz = d.x;
        pos.push(p.x - (nx * width) / 2, y, p.z - (nz * width) / 2, p.x + (nx * width) / 2, y, p.z + (nz * width) / 2);
        uv.push(0, (u * length) / 0.36, 1, (u * length) / 0.36);
        if (i < SEG) index.push(i * 2, i * 2 + 1, i * 2 + 2, i * 2 + 1, i * 2 + 3, i * 2 + 2);
      }
      g.setAttribute('position', new THREE.Float32BufferAttribute(pos, 3));
      g.setAttribute('uv', new THREE.Float32BufferAttribute(uv, 2));
      g.setIndex(index);
      g.computeVertexNormals();
      return g;
    };
    return { paper: build(ROAD_W, 0.016), under: build(ROAD_W + 0.07, 0.006) };
  }, []);
  const count = Math.floor(SEG * progress) * 6;
  geometry.paper.setDrawRange(0, count);
  geometry.under.setDrawRange(0, count);
  if (progress <= 0) return null;
  return (
    <>
      <mesh geometry={geometry.under}>
        <meshBasicMaterial color="#3d4627" transparent opacity={0.32} side={THREE.DoubleSide} depthWrite={false} />
      </mesh>
      <mesh geometry={geometry.paper} receiveShadow>
        <meshStandardMaterial map={map} roughness={0.95} side={THREE.DoubleSide} />
      </mesh>
    </>
  );
};

/** A milestone: a card on a folded foot, lying back until it stands up at `at`. */
const Stone = ({ t, at, map, x, z, turn }: { t: number; at: number; map: THREE.Texture; x: number; z: number; turn: number }) => {
  if (t < at - 0.02) return null;
  const up = land(t, at, 0.5);
  return (
    <group position={[x, 0.01, z]} rotation={[0, turn, 0]}>
      <group rotation={[(-PI / 2) * (1 - up) - 0.14 * up, 0, 0]}>
        <group position={[0, 0.33, 0]}>
          <Card w={0.96} h={0.57} r={0.06} depth={0.04} front={map} />
        </group>
      </group>
      <mesh position={[0, 0.012, -0.1]} rotation={[-PI / 2, 0, 0]} receiveShadow castShadow>
        <planeGeometry args={[0.62, 0.3]} />
        <meshStandardMaterial color={PAL.creamEdge} roughness={0.95} side={THREE.DoubleSide} />
      </mesh>
    </group>
  );
};

// ───────────────────────── the scene ─────────────────────────

const World = ({ id, holder }: { id: string; holder: RefObject<HTMLDivElement | null> }) => {
  const t = useCurrentFrame() / REEL_FPS;
  const episode = script.episodes.find((e) => e.id === id)! as unknown as Episode;
  const s = episode.scene;
  const timing = (timings as Record<string, { total: number; end: number; slots: Slot[] }>)[id];
  const [, deal, plan, route] = timing.slots.map((slot) => slot.start);
  const end = timing.end;
  const maps = usePrepared(JSON.stringify(s) + '0123456789', () => buildMaps(episode, holder));

  // ── the camera's stops ──
  const look = fromPhone(603, s.phoneLook);
  const shots: Shot[] = [
    { at: deal - 0.35, pos: [FAN.x - 0.4, 16, FAN.z + 9], look: [FAN.x, 0, FAN.z - 0.05] },
    { at: deal + 0.55, pos: [FAN.x, 10.1, FAN.z + 5.75], look: [FAN.x, 0, FAN.z - 0.05], ease: out },
    { at: plan - 0.12, pos: [FAN.x + 0.1, 9.5, FAN.z + 5.4], look: [FAN.x, 0, FAN.z - 0.07], ease: (n) => n },
    { at: plan + 0.5, pos: [look.x + 0.35, look.y + 5.3, look.z + 2.5], look: [look.x + 0.03, look.y, look.z - 0.34] },
    { at: route - 0.1, pos: [look.x + 0.3, look.y + 5.0, look.z + 2.35], look: [look.x + 0.03, look.y, look.z - 0.34], ease: (n) => n },
    { at: route + 0.65, pos: [0.7, 15.0, 11.6], look: [0.16, 0, 0.2] },
    { at: end + 0.4, pos: [0.6, 14.2, 11.0], look: [0.16, 0, 0.18], ease: (n) => n },
  ];
  const cam = shotAt(shots, t);

  if (!maps) return null;

  // ── slot 1: the level check ──
  const gather = ramp(t, deal + 6.9 * BEAT, deal + 7.7 * BEAT, inOut);
  const cards = s.cards.map((_, i) => {
    const a = (i - (s.cards.length - 1) / 2) * FAN.step;
    const drop = ramp(t, deal + 0.25 + i * 0.03, deal + 0.5 + i * 0.03, (n) => n * n);
    const fan = ramp(t, deal + BEAT + i * 0.04, deal + 2 * BEAT + i * 0.04, out);
    const flipAt = deal + (2.5 + i * 0.5) * BEAT;
    const flip = ramp(t, flipAt, flipAt + 0.34, inOut);
    const fx = FAN.x + FAN.radius * Math.sin(a) * fan;
    const fz = FAN.z + FAN.radius * (1 - Math.cos(a)) * fan;
    const gx = DECK.x + (i - 2) * 0.012;
    const gz = DECK.z + (i % 2) * 0.014;
    return {
      x: fx + (gx - fx) * gather,
      z: fz + (gz - fz) * gather,
      y: 0.02 + i * 0.034 + (1 - drop) * 3.2 + Math.sin(flip * PI) * 0.46 + Math.sin(gather * PI) * (0.25 + 0.05 * i),
      turn: -a * fan * (1 - gather) + gather * (0.5 + (i - 2) * 0.05),
      flip: flip * PI,
      visible: t >= deal + 0.2,
    };
  });
  const levelAt = deal + 6 * BEAT;
  const levelP = ramp(t, levelAt - 0.14, levelAt, (n) => n * n);
  const levelLand = land(t, levelAt, 0.3);

  // ── slot 2: the calendar leaves the phone ──
  const popAt = plan + 2 * BEAT;
  const flips = s.pages.slice(1).map((_, i) => plan + (3 + i * 0.5) * BEAT);
  const from = fromPhone(s.tap[1][0], s.tap[1][1]);
  const hover = new THREE.Vector3(look.x + 0.04, look.y + 0.95, look.z - 0.5);
  const stand = new THREE.Vector3(CAL_STAND.x, (CAL.h / 2) * CAL_STAND.scale * Math.cos(CAL_STAND.lean) + 0.02, CAL_STAND.z);
  const pop = ramp(t, popAt, popAt + 0.42, back);
  const fly = ramp(t, route, route + BEAT, inOut);
  const calLand = land(t, route + BEAT, 0.35);
  const calPos = from.clone().lerp(hover, pop).lerp(stand, fly);
  calPos.y += Math.sin(fly * PI) * 1.6 + (fly < 1 ? Math.sin(t * 1.9) * 0.03 * pop : 0);
  const hoverPitch = -0.95;
  const HOVER_SCALE = 0.57;
  const calPitch = hoverPitch + (CAL_STAND.lean - hoverPitch) * fly;
  const calScale = pop * (HOVER_SCALE + (CAL_STAND.scale - HOVER_SCALE) * fly) * (fly >= 1 ? 0.94 + 0.06 * calLand : 1);

  // ── slot 3: the road ──
  const stoneTimes = STONE_AT.map((_, i) => route + (2 + i) * BEAT);
  const roadKeys: [number, number][] = [[route + 0.6 * BEAT, 0], ...STONE_AT.map((u, i): [number, number] => [stoneTimes[i] - 0.08, u + 0.03]), [route + 6 * BEAT - 0.05, 1]];
  let progress = 0;
  for (let i = 0; i < roadKeys.length - 1; i++) {
    const [ta, ua] = roadKeys[i];
    const [tb, ub] = roadKeys[i + 1];
    if (t >= ta) progress = ua + (ub - ua) * ramp(t, ta, tb, inOut);
  }
  const stones = STONE_AT.map((u, i) => {
    const p = roadCurve.getPointAt(u);
    const d = roadCurve.getTangentAt(u);
    const side = i % 2 === 0 ? -1 : 1;
    // Stand on the far side of the road where there is one, so the card does not cover it.
    let nx = -d.z * side;
    let nz = d.x * side;
    if (nz > 0.2) {
      nx = -nx;
      nz = -nz;
    }
    return { x: p.x + nx * 0.7, z: p.z + nz * 0.7 };
  });
  const counterAt = route + 4.5 * BEAT;
  const counterUp = land(t, counterAt, 0.45);
  const target = Number(s.counter[1]);
  const count = Math.round(target * ramp(t, route + 5 * BEAT, route + 6 * BEAT - 0.06, (n) => n));
  const flagAt = route + 6 * BEAT;
  const flagUp = land(t, flagAt, 0.5);
  const roadEnd = roadCurve.getPointAt(1);

  // 傻貓: watching the check, then hopping the road a stop at a time.
  const stops: { at: number; x: number; z: number }[] = [
    { at: route + 1.2 * BEAT, x: roadCurve.getPointAt(0.04).x, z: roadCurve.getPointAt(0.04).z },
    ...STONE_AT.map((u, i) => ({ at: stoneTimes[i] + 0.5 * BEAT, x: roadCurve.getPointAt(u).x, z: roadCurve.getPointAt(u).z })),
  ];
  stops[stops.length - 1].at = flagAt - 0.5 * BEAT;
  stops.push({ at: flagAt + 0.5 * BEAT, x: roadEnd.x - 0.1, z: roadEnd.z + 0.72 });
  const HOP = 0.3;
  let cat = { x: stops[0].x, z: stops[0].z, y: 0, squash: 0 };
  stops.forEach((stop, i) => {
    if (i === 0 || t < stop.at - HOP) return;
    const prev = stops[i - 1];
    const p = ramp(t, stop.at - HOP, stop.at, (n) => n);
    cat = { x: prev.x + (stop.x - prev.x) * p, z: prev.z + (stop.z - prev.z) * p, y: Math.sin(p * PI) * 0.7, squash: p >= 1 ? Math.max(0, 1 - (t - stop.at) / 0.22) * Math.cos((t - stop.at) * 22) : 0 };
  });
  const catIn = ramp(t, stops[0].at - 0.2, stops[0].at + 0.15, back);
  const happy = t >= stops[stops.length - 1].at - 0.05;
  const cheer = happy ? Math.abs(Math.sin((t - stops[stops.length - 1].at) * 7)) * Math.exp(-(t - stops[stops.length - 1].at) * 1.4) * 0.3 : 0;
  const faceCamera = (x: number, z: number) => Math.atan2(cam.pos[0] - x, cam.pos[2] - z);

  const watcher = { x: FAN.x - 1.15, z: FAN.z - 1.3 };
  const watcherIn = ramp(t, deal + 1.2 * BEAT, deal + 1.2 * BEAT + 0.35, back) * (1 - ramp(t, plan - 0.1, plan + 0.2, (n) => n));
  // It flinches at each wrong card.
  const flinch = s.cards.reduce((sum, [, , right], i) => {
    const at = deal + (2.5 + i * 0.5) * BEAT + 0.3;
    return sum + (right || t < at ? 0 : Math.max(0, 1 - (t - at) / 0.3));
  }, 0);

  return (
    <>
      <Rig t={t} shots={shots} />
      <ambientLight intensity={1.75} color="#FFF3DF" />
      <directionalLight
        position={[-6.5, 11, 4.5]}
        intensity={1.95}
        color="#FFF1D6"
        castShadow
        shadow-mapSize={[2048, 2048]}
        shadow-bias={-0.0005}
        shadow-normalBias={0.02}
        shadow-radius={5}
        shadow-camera-left={-6}
        shadow-camera-right={6}
        shadow-camera-top={8}
        shadow-camera-bottom={-8}
        shadow-camera-near={1}
        shadow-camera-far={34}
      />

      {/* The desk, and two sheets of paper lying on it. */}
      <mesh rotation={[-PI / 2, 0, 0]} receiveShadow>
        <planeGeometry args={[70, 70]} />
        <meshStandardMaterial map={maps.desk} roughness={1} />
      </mesh>
      <mesh position={[-2.3, 0.004, 4.6]} rotation={[-PI / 2, 0, 0.3]} receiveShadow>
        <planeGeometry args={[3.2, 4]} />
        <meshStandardMaterial map={maps.sheets[0]} transparent roughness={1} depthWrite={false} />
      </mesh>
      <mesh position={[2.6, 0.004, -0.6]} rotation={[-PI / 2, 0, -0.22]} receiveShadow>
        <planeGeometry args={[3.4, 3.4]} />
        <meshStandardMaterial map={maps.sheets[1]} transparent roughness={1} depthWrite={false} />
      </mesh>

      {/* The word cards. */}
      {cards.map((c, i) =>
        c.visible ? (
          <group key={i} position={[c.x, c.y, c.z]} rotation={[0, c.turn, 0]}>
            <group rotation={[-PI / 2, 0, 0]}>
              <group rotation={[0, c.flip, 0]}>
                <Card w={CARD.w} h={CARD.h} r={0.035} depth={0.028} front={maps.cardFront[i]} backMap={maps.cardBack[i]} />
              </group>
            </group>
          </group>
        ) : null,
      )}
      {t >= levelAt - 0.14 && gather < 1 ? (
        <group position={[FAN.x + 0.42, 0.03 + (1 - levelP) * 1.2, FAN.z - 1.2]} rotation={[0, 0.07, 0]} scale={(1.25 - 0.25 * levelP) * (0.95 + 0.05 * levelLand) * (1 - gather)}>
          <group rotation={[-PI / 2, 0, 0]}>
            <Card w={1.75} h={0.64} r={0.06} depth={0.03} front={maps.level} />
          </group>
        </group>
      ) : null}
      {watcherIn > 0.01 ? (
        <group position={[watcher.x, 0, watcher.z]} rotation={[0, faceCamera(watcher.x, watcher.z), 0]} scale={watcherIn}>
          <CatStandee map={maps.cats.smug} size={1.1} squash={flinch * 0.6} lean={-0.06 - flinch * 0.1} />
        </group>
      ) : null}

      {/* The phone, on the plan screen. */}
      <group position={[PHONE_AT.x, PHONE_Y, PHONE_AT.z]} rotation={[0, PHONE_AT.turn, 0]}>
        <group rotation={[-PI / 2 + PHONE_AT.tilt, 0, 0]}>
          <Phone3D screen={maps.screen} glare={Math.sin(t * 0.5) * 0.12}>
            <Tap3D t={t} at={plan + BEAT} x={(s.tap[0][0] + s.tap[0][2]) / 2} y={(s.tap[0][1] + s.tap[0][3]) / 2} />
            <Tap3D t={t} at={popAt - 0.06} x={s.tap[1][0]} y={s.tap[1][1]} />
          </Phone3D>
        </group>
      </group>
      {/* What the phone leans on. */}
      <mesh position={[PHONE_AT.x - 0.17 * Math.sin(PHONE_AT.turn) * 5, 0.1, PHONE_AT.z - 0.86]} rotation={[0, PHONE_AT.turn + 0.1, 0]} castShadow receiveShadow>
        <boxGeometry args={[0.7, 0.2, 0.42]} />
        <meshStandardMaterial color={PAL.mustard} roughness={0.95} />
      </mesh>

      {/* The calendar. */}
      {t >= popAt ? (
        <group position={calPos} rotation={[calPitch, CAL_STAND.turn * fly + Math.sin(t * 1.3) * 0.04 * (1 - fly), Math.sin(t * 1.1) * 0.02 * (1 - fly)]} scale={calScale}>
          <Calendar3D t={t} maps={maps} flips={flips} ringAt={plan + 5 * BEAT} tagAt={plan + 6 * BEAT} />
        </group>
      ) : null}

      {/* The road to the day, and what stands along it. */}
      <Road progress={progress} map={maps.road} />
      {stones.map((st, i) => (
        <Stone key={i} t={t} at={stoneTimes[i]} map={maps.stones[i]} x={st.x} z={st.z} turn={faceCamera(st.x, st.z) * 0.6} />
      ))}
      {t >= counterAt - 0.02 ? (
        <group position={[COUNTER_AT.x, 0.01, COUNTER_AT.z]} rotation={[0, 0.2, 0]}>
          <group rotation={[(-PI / 2) * (1 - counterUp) - 0.3 * counterUp, 0, 0]}>
            <group position={[0, 0.6, 0]}>
              <CounterCard value={count} maps={maps} />
            </group>
          </group>
        </group>
      ) : null}
      {t >= flagAt - 0.02 ? (
        <group position={[roadEnd.x - 0.3, 0, roadEnd.z + 0.12]} scale={[0.85, 0.85 * flagUp, 0.85]}>
          <mesh position={[0, 0.6, 0]} castShadow>
            <cylinderGeometry args={[0.022, 0.022, 1.2, 10]} />
            <meshStandardMaterial color="#8A6A45" roughness={0.8} />
          </mesh>
          <mesh position={[0.33, 1.0, 0]} rotation={[0, -0.25 + Math.sin(t * 3) * 0.06, 0]} castShadow>
            <FlagGeometry />
            <meshStandardMaterial map={maps.flag} roughness={0.9} side={THREE.DoubleSide} />
          </mesh>
        </group>
      ) : null}
      {catIn > 0.01 && t >= route ? (
        <group position={[cat.x, cat.y + cheer, cat.z]} rotation={[0, faceCamera(cat.x, cat.z), 0]} scale={catIn}>
          <CatStandee map={happy ? maps.cats.happy : maps.cats.smug} size={1.2} squash={cat.squash} lean={Math.sin(t * 2.2) * 0.04} />
        </group>
      ) : null}
    </>
  );
};

const CounterCard = ({ value, maps }: { value: number; maps: Maps }) => {
  const map = useMemo(() => maps.counter(value), [maps, value]);
  return <Card w={1.4} h={1.11} r={0.07} depth={0.045} front={map} />;
};

const FlagGeometry = () => {
  const geometry = useMemo(() => {
    const shape = new THREE.Shape();
    shape.moveTo(-0.33, -0.2);
    shape.lineTo(0.33, -0.2);
    shape.lineTo(0.2, 0);
    shape.lineTo(0.33, 0.2);
    shape.lineTo(-0.33, 0.2);
    shape.closePath();
    return faceGeometry(shape, 0.66, 0.4);
  }, []);
  return <primitive object={geometry} attach="geometry" />;
};

export const Day6 = ({ id }: { id: string }) => {
  const frame = useCurrentFrame();
  const t = frame / REEL_FPS;
  const episode = script.episodes.find((e) => e.id === id)! as unknown as Episode;
  const timing = (timings as Record<string, { total: number; end: number; slots: Slot[] }>)[id];
  const deal = timing.slots[1].start;
  const end = timing.end;
  const holder = useHolder();

  const coverOut = ramp(t, deal - 0.14, deal + 0.3, inOut);
  const sceneIn = ramp(t, deal - 0.2, deal + 0.15, (n) => n);
  const sceneOut = ramp(t, end - 0.15, end + 0.35, inOut);
  const mounted = t >= deal - 0.5 && t <= end + 0.4;
  const stamp = <DaysStamp days={episode.days} words={episode.dayWords} note={episode.note} />;

  return (
    <AbsoluteFill style={{ fontFamily: FONT, overflow: 'hidden', background: PAL.olive }}>
      <Html5Audio src={staticFile(`reels/${id}.mp3`)} />
      <InkFilters />
      <CatSource holder={holder} />
      {sceneIn < 1 || sceneOut > 0 ? <Backdrop t={t} frame={frame} /> : null}

      {mounted ? (
        <AbsoluteFill style={{ opacity: sceneIn * (1 - sceneOut), filter: sceneOut > 0 ? `blur(${sceneOut * 14}px)` : undefined }}>
          <ThreeCanvas width={1080} height={1920} shadows flat dpr={1} gl={{ antialias: true }} camera={{ fov: 30, near: 0.5, far: 90, position: [0, 12, 10] }}>
            <World id={id} holder={holder} />
          </ThreeCanvas>
          {/* The lens: the far edge and the caption band fall out of focus, and the corners darken. */}
          <AbsoluteFill style={{ backdropFilter: 'blur(5px)', WebkitMaskImage: 'linear-gradient(to bottom, #000 0, transparent 250px)', maskImage: 'linear-gradient(to bottom, #000 0, transparent 250px)' }} />
          <AbsoluteFill style={{ backdropFilter: 'blur(9px)', WebkitMaskImage: 'linear-gradient(to bottom, transparent 1360px, #000 1470px)', maskImage: 'linear-gradient(to bottom, transparent 1360px, #000 1470px)' }} />
          <AbsoluteFill style={{ background: 'linear-gradient(to bottom, rgba(52,60,30,0) 1340px, rgba(52,60,30,0.34) 1500px, rgba(52,60,30,0.5) 1920px)' }} />
          <AbsoluteFill style={{ background: 'radial-gradient(120% 95% at 46% 40%, rgba(255,244,214,0.1) 0%, rgba(0,0,0,0) 45%, rgba(30,34,14,0.3) 100%)' }} />
        </AbsoluteFill>
      ) : null}
      <Motes t={t} />

      {/* The cover: the days left, stamped on a card; it tips back onto the desk as the camera drops. */}
      {coverOut < 1 ? (
        <div style={{ position: 'absolute', inset: 0, opacity: 1 - coverOut, transform: `perspective(1500px) translateY(${-coverOut * 260}px) rotateX(${coverOut * 62}deg) scale(${1 - 0.25 * coverOut})`, transformOrigin: '50% 30%' }}>
          <StampCard t={t} at={0} stampAt={0} top={300}>
            {stamp}
          </StampCard>
        </div>
      ) : null}
      <Peek t={t} at={0} until={deal + 0.3} side={1} mood="smug" y={760} outAt={deal - 0.12} />

      <Motes t={t} front />
      {episode.lines.map((line, i) => (
        <Caption key={i} text={line.text} start={timing.slots[i].start} length={timing.slots[i].length} t={t} first={i === 0} label={episode.label} top={CAPTION_TOP} size={62} glass />
      ))}
      <CountdownEnd t={t} end={end} episode={episode} stamp={stamp} />
      <Grade frame={frame} />
    </AbsoluteFill>
  );
};
