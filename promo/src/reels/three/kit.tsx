import { type ReactNode, type RefObject, useEffect, useLayoutEffect, useMemo, useRef, useState } from 'react';
import { useThree } from '@react-three/fiber';
import { Easing, Freeze, continueRender, delayRender, interpolate, staticFile } from 'remotion';
import * as THREE from 'three';
import { Mascot, type Mood } from '../../Mascot';

/**
 * The paper-craft 3D kit the launch countdown is built from: card stock
 * with thickness, textures drawn on a 2D canvas in the reels' own fonts, an
 * iPhone made of plain geometry around a real screenshot, 傻貓 as a
 * die-cut standee, and a camera that moves between written stops.
 *
 * Nothing here keeps time: every value comes from the frame the scene is
 * given, so any frame renders the same on any worker.
 */

export const PAL = {
  olive: '#879763',
  oliveLight: '#AEBA88',
  oliveDark: '#58643B',
  clay: '#C96442',
  cream: '#FBF6EA',
  creamEdge: '#E4DAC2',
  ink: '#2B2620',
  sage: '#6E8F5E',
  gold: '#FFC861',
  peach: '#F3C9A8',
  mustard: '#E6BE62',
  sageLight: '#C5D4B2',
};
export const F_SANS = '"Noto Sans TC"';
export const F_SERIF = '"Noto Serif"';
export const F_SERIF_TC = '"Noto Serif TC"';

export const clamp = { extrapolateLeft: 'clamp', extrapolateRight: 'clamp' } as const;
export const inOut = Easing.bezier(0.65, 0, 0.35, 1);
export const out = Easing.bezier(0.16, 1, 0.3, 1);
export const back = Easing.out(Easing.back(1.7));
/** 0 → 1 between `a` and `b` seconds. */
export const ramp = (t: number, a: number, b: number, easing: (n: number) => number = out) => interpolate(t, [a, b], [0, 1], { ...clamp, easing });
/** A landing with weight: overshoots, squashes, settles. 0 before `at`. */
export const land = (t: number, at: number, length = 0.42) => {
  const p = (t - at) / length;
  if (p <= 0) return 0;
  if (p >= 1) return 1;
  return 1 - Math.exp(-6 * p) * Math.cos(p * Math.PI * 2.4);
};

const hash = (n: number) => {
  const v = Math.sin(n * 127.1 + 311.7) * 43758.5453;
  return v - Math.floor(v);
};

// ───────────────────────── textures ─────────────────────────

export type Draw = (ctx: CanvasRenderingContext2D, w: number, h: number) => void;

export const canvasTexture = (w: number, h: number, draw: Draw) => {
  const canvas = document.createElement('canvas');
  canvas.width = w;
  canvas.height = h;
  const ctx = canvas.getContext('2d')!;
  draw(ctx, w, h);
  const texture = new THREE.CanvasTexture(canvas);
  texture.colorSpace = THREE.SRGBColorSpace;
  texture.anisotropy = 8;
  return texture;
};

/** Paper: a flat colour with fibre and speckle, so light has something to catch. */
export const paper = (ctx: CanvasRenderingContext2D, w: number, h: number, color: string, seed = 1, strength = 1) => {
  ctx.fillStyle = color;
  ctx.fillRect(0, 0, w, h);
  const count = Math.round((w * h) / 90);
  for (let i = 0; i < count; i++) {
    const x = hash(i * 3 + seed) * w;
    const y = hash(i * 3 + 1 + seed) * h;
    const dark = hash(i * 3 + 2 + seed) > 0.5;
    ctx.fillStyle = dark ? `rgba(70,56,30,${0.05 * strength})` : `rgba(255,255,255,${0.1 * strength})`;
    const s = 1 + hash(i + seed * 7) * 2.2;
    ctx.fillRect(x, y, s, s);
  }
  for (let i = 0; i < count / 40; i++) {
    const x = hash(i * 5 + seed + 0.3) * w;
    const y = hash(i * 5 + 1 + seed) * h;
    const a = hash(i * 5 + 2 + seed) * Math.PI;
    const l = 8 + hash(i * 5 + 3 + seed) * 22;
    ctx.strokeStyle = `rgba(90,72,40,${0.06 * strength})`;
    ctx.lineWidth = 1;
    ctx.beginPath();
    ctx.moveTo(x, y);
    ctx.lineTo(x + Math.cos(a) * l, y + Math.sin(a) * l);
    ctx.stroke();
  }
};

/** Text centred on (x, y), shrunk to fit `max` wide. */
export const label = (ctx: CanvasRenderingContext2D, text: string, x: number, y: number, font: string, size: number, color: string, max?: number, weight = 900) => {
  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';
  let s = size;
  ctx.font = `${weight} ${s}px ${font}`;
  if (max) {
    const wide = ctx.measureText(text).width;
    if (wide > max) {
      s = (s * max) / wide;
      ctx.font = `${weight} ${s}px ${font}`;
    }
  }
  ctx.fillStyle = color;
  ctx.fillText(text, x, y);
};

/** Ink that did not take everywhere: knocks specks out of what is already drawn. */
export const wornInk = (ctx: CanvasRenderingContext2D, w: number, h: number, seed = 3, amount = 1) => {
  ctx.save();
  ctx.globalCompositeOperation = 'destination-out';
  for (let i = 0; i < (w * h) / 260; i++) {
    ctx.fillStyle = `rgba(0,0,0,${0.5 * amount})`;
    const s = 1 + hash(i + seed * 13) * 3;
    ctx.fillRect(hash(i * 2 + seed) * w, hash(i * 2 + 1 + seed) * h, s, s);
  }
  ctx.restore();
};

const loadImage = (src: string) =>
  new Promise<HTMLImageElement>((resolve, reject) => {
    const img = new Image();
    img.onload = () => resolve(img);
    img.onerror = () => reject(new Error(`could not load ${src}`));
    img.src = src;
  });

export const imageTexture = async (file: string) => {
  const img = await loadImage(staticFile(file));
  const texture = new THREE.Texture(img);
  texture.colorSpace = THREE.SRGBColorSpace;
  texture.anisotropy = 8;
  texture.needsUpdate = true;
  return texture;
};

/**
 * Everything a scene draws with, made once before its first frame: waits
 * for the fonts (with every character the textures use) and whatever
 * `build` loads, holding the render until it is all there.
 */
export const usePrepared = <T,>(text: string, build: () => Promise<T>): T | null => {
  const [made, setMade] = useState<T | null>(null);
  const advance = useThree((s) => s.advance);
  const hold = useRef<number | null>(null);
  useEffect(() => {
    hold.current = delayRender('Preparing the 3D scene', { timeoutInMilliseconds: 120000 });
    let live = true;
    Promise.all([
      document.fonts.load(`900 64px ${F_SANS}`, text),
      document.fonts.load(`700 64px ${F_SANS}`, text),
      document.fonts.load(`900 64px ${F_SERIF_TC}`, text),
      document.fonts.load(`800 64px ${F_SERIF}`, text),
      document.fonts.load(`700 64px ${F_SERIF}`, text),
    ])
      .then(build)
      .then((value) => {
        if (live) setMade(value);
      })
      .catch((error) => {
        console.error('3D scene failed to prepare', error);
        if (hold.current !== null) continueRender(hold.current);
        hold.current = null;
      });
    return () => {
      live = false;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);
  // The canvas only draws when the frame changes: draw once more now that
  // there is something to draw, and only then let the frame be captured.
  useEffect(() => {
    if (!made || hold.current === null) return;
    advance(performance.now());
    continueRender(hold.current);
    hold.current = null;
  }, [made, advance]);
  return made;
};

// ───────────────────────── geometry ─────────────────────────

export const roundedRect = (w: number, h: number, r: number) => {
  const s = new THREE.Shape();
  const x = -w / 2;
  const y = -h / 2;
  r = Math.min(r, w / 2, h / 2);
  s.moveTo(x + r, y);
  s.lineTo(x + w - r, y);
  s.quadraticCurveTo(x + w, y, x + w, y + r);
  s.lineTo(x + w, y + h - r);
  s.quadraticCurveTo(x + w, y + h, x + w - r, y + h);
  s.lineTo(x + r, y + h);
  s.quadraticCurveTo(x, y + h, x, y + h - r);
  s.lineTo(x, y + r);
  s.quadraticCurveTo(x, y, x + r, y);
  return s;
};

/** A flat face in a shape's outline, with the texture stretched over its bounding box. */
export const faceGeometry = (shape: THREE.Shape, w: number, h: number) => {
  const g = new THREE.ShapeGeometry(shape, 8);
  const pos = g.attributes.position;
  const uv = g.attributes.uv;
  for (let i = 0; i < pos.count; i++) uv.setXY(i, pos.getX(i) / w + 0.5, pos.getY(i) / h + 0.5);
  return g;
};

/** The same outline with thickness, centred on z = 0. */
export const slabGeometry = (shape: THREE.Shape, depth: number, bevel = 0) => {
  const g = new THREE.ExtrudeGeometry(shape, { depth: depth - bevel * 2, bevelEnabled: bevel > 0, bevelSize: bevel, bevelThickness: bevel, bevelSegments: 3, curveSegments: 8 });
  g.translate(0, 0, -(depth - bevel * 2) / 2);
  return g;
};

/**
 * A piece of card stock: `w` × `h`, `depth` thick, printed on the front
 * (+z) and, if given, on the back. Its edge shows the board's core.
 */
export const Card = ({
  w,
  h,
  r = 0.04,
  depth = 0.03,
  front,
  backMap,
  edge = PAL.creamEdge,
  backColor = PAL.cream,
  shadow = true,
}: {
  w: number;
  h: number;
  r?: number;
  depth?: number;
  front: THREE.Texture;
  backMap?: THREE.Texture;
  edge?: string;
  backColor?: string;
  shadow?: boolean;
}) => {
  const [slab, face] = useMemo(() => {
    const shape = roundedRect(w, h, r);
    return [slabGeometry(shape, depth), faceGeometry(shape, w, h)];
  }, [w, h, r, depth]);
  return (
    <group>
      <mesh geometry={slab} castShadow={shadow} receiveShadow>
        <meshStandardMaterial color={edge} roughness={0.95} />
      </mesh>
      <mesh geometry={face} position={[0, 0, depth / 2 + 0.0015]} receiveShadow>
        <meshStandardMaterial map={front} roughness={0.92} />
      </mesh>
      <mesh geometry={face} position={[0, 0, -depth / 2 - 0.0015]} rotation={[0, Math.PI, 0]} receiveShadow>
        <meshStandardMaterial map={backMap ?? null} color={backMap ? '#ffffff' : backColor} roughness={0.92} />
      </mesh>
    </group>
  );
};

/** A strip of washi tape lying on whatever is under it. */
export const Tape3D = ({ w = 0.5, h = 0.14, color = '#ECE0C4', opacity = 0.78 }: { w?: number; h?: number; color?: string; opacity?: number }) => (
  <mesh receiveShadow>
    <planeGeometry args={[w, h]} />
    <meshStandardMaterial color={color} transparent opacity={opacity} roughness={0.8} />
  </mesh>
);

// ───────────────────────── the phone ─────────────────────────

export const SCREEN_W = 1206;
export const SCREEN_H = 2622;
/** The screen is 1 unit wide. */
export const PHONE = { w: 1, h: SCREEN_H / SCREEN_W, depth: 0.075, rim: 0.045, radius: 0.137 };
/** A point on the screenshot, in the phone's own space. */
export const onScreen = (x: number, y: number, lift = 0.004): [number, number, number] => [(x / SCREEN_W - 0.5) * PHONE.w, (0.5 - y / SCREEN_H) * PHONE.h, PHONE.depth / 2 + lift];

/**
 * An iPhone 17 Pro around a real screenshot: titanium band, black bezel,
 * side keys, the Dynamic Island, a soft glare across the glass.
 */
export const Phone3D = ({ screen, glare = 0, children }: { screen: THREE.Texture; glare?: number; children?: ReactNode }) => {
  const { w, h, depth, rim, radius } = PHONE;
  const geo = useMemo(() => {
    const body = roundedRect(w + rim * 2, h + rim * 2, radius + rim);
    const bezel = roundedRect(w + rim * 1.3, h + rim * 1.3, radius + rim * 0.65);
    const glass = roundedRect(w, h, radius);
    const island = roundedRect(0.312, 0.091, 0.0455);
    return {
      body: slabGeometry(body, depth, 0.012),
      bezel: new THREE.ShapeGeometry(bezel, 8),
      glass: faceGeometry(glass, w, h),
      island: new THREE.ShapeGeometry(island, 8),
    };
  }, [w, h, depth, rim, radius]);
  const glareMap = useMemo(
    () =>
      canvasTexture(256, 512, (ctx, cw, ch) => {
        const g = ctx.createLinearGradient(0, ch, cw, 0);
        g.addColorStop(0.3, 'rgba(255,255,255,0)');
        g.addColorStop(0.47, 'rgba(255,255,255,0.16)');
        g.addColorStop(0.62, 'rgba(255,255,255,0)');
        ctx.fillStyle = g;
        ctx.fillRect(0, 0, cw, ch);
      }),
    [],
  );
  glareMap.offset.set(glare, glare * 0.5);
  const key = (side: 1 | -1, y: number, length: number) => (
    <mesh position={[side * (w / 2 + rim + 0.004), y, 0]} castShadow>
      <boxGeometry args={[0.014, length, 0.03]} />
      <meshStandardMaterial color="#6b665e" metalness={0.5} roughness={0.4} />
    </mesh>
  );
  const z = depth / 2;
  return (
    <group>
      <mesh geometry={geo.body} castShadow receiveShadow>
        <meshStandardMaterial color="#7d776d" metalness={0.55} roughness={0.38} />
      </mesh>
      {key(-1, 0.52, 0.12)}
      {key(-1, 0.3, 0.19)}
      {key(-1, 0.07, 0.19)}
      {key(1, 0.24, 0.28)}
      <mesh geometry={geo.bezel} position={[0, 0, z + 0.001]}>
        <meshStandardMaterial color="#0b0a09" roughness={0.3} />
      </mesh>
      <mesh geometry={geo.glass} position={[0, 0, z + 0.002]}>
        <meshBasicMaterial map={screen} toneMapped={false} />
      </mesh>
      <mesh geometry={geo.island} position={[0, h / 2 - 0.0737, z + 0.003]}>
        <meshBasicMaterial color="#050505" />
      </mesh>
      {children}
      <mesh geometry={geo.glass} position={[0, 0, z + 0.012]}>
        <meshBasicMaterial map={glareMap} transparent depthWrite={false} blending={THREE.AdditiveBlending} />
      </mesh>
    </group>
  );
};

/** A fingertip's ripple on the glass at a screenshot point. */
export const Tap3D = ({ t, at, x, y }: { t: number; at: number; x: number; y: number }) => {
  const age = t - at;
  if (age < 0 || age > 0.55) return null;
  const p = age / 0.55;
  const s = 0.04 + 0.16 * out(p);
  return (
    <group position={onScreen(x, y, 0.008)}>
      <mesh scale={s}>
        <ringGeometry args={[0.78, 1, 40]} />
        <meshBasicMaterial color={PAL.clay} transparent opacity={0.85 * (1 - p)} depthWrite={false} />
      </mesh>
      <mesh scale={0.045 * (1 - 0.4 * p)}>
        <circleGeometry args={[1, 32]} />
        <meshBasicMaterial color={PAL.clay} transparent opacity={0.4 * (1 - p)} depthWrite={false} />
      </mesh>
    </group>
  );
};

// ───────────────────────── 傻貓 as a standee ─────────────────────────

const MOODS: Mood[] = ['smug', 'happy', 'cheeky'];
export type CatMaps = Record<string, THREE.Texture>;

/**
 * 傻貓, drawn once per mood off-screen so it can be printed on card. Put
 * this in the DOM (outside the canvas) and read the textures from
 * `catTextures(ref)` once mounted.
 */
export const CatSource = ({ holder }: { holder: RefObject<HTMLDivElement | null> }) => (
  <div ref={holder} style={{ position: 'absolute', left: -4000, top: 0, width: 600, height: 600, opacity: 0, pointerEvents: 'none' }}>
    <Freeze frame={14}>
      {MOODS.map((mood) => (
        <div key={mood} data-mood={mood}>
          <Mascot mood={mood} size={512} next />
        </div>
      ))}
    </Freeze>
  </div>
);

export const catTextures = async (holder: HTMLDivElement): Promise<CatMaps> => {
  const maps: CatMaps = {};
  for (const mood of MOODS) {
    const svg = holder.querySelector(`[data-mood="${mood}"] svg`)!.cloneNode(true) as SVGSVGElement;
    // The ground shadow under the cat belongs to the 2D reels; the standee casts a real one.
    svg.querySelector('ellipse')?.remove();
    svg.setAttribute('xmlns', 'http://www.w3.org/2000/svg');
    svg.setAttribute('viewBox', '-14 -14 128 128');
    svg.setAttribute('width', '896');
    svg.setAttribute('height', '896');
    const img = await loadImage(`data:image/svg+xml;charset=utf-8,${encodeURIComponent(new XMLSerializer().serializeToString(svg))}`);
    maps[mood] = canvasTexture(896, 896, (ctx, w, h) => {
      // A die-cut edge: the cat's outline, fattened, in bare card.
      const ring = 15;
      for (let i = 0; i < 28; i++) {
        const a = (i / 28) * Math.PI * 2;
        ctx.drawImage(img, Math.cos(a) * ring, Math.sin(a) * ring, w, h);
      }
      ctx.globalCompositeOperation = 'source-in';
      ctx.fillStyle = PAL.cream;
      ctx.fillRect(0, 0, w, h);
      ctx.globalCompositeOperation = 'source-over';
      ctx.drawImage(img, 0, 0, w, h);
    });
  }
  return maps;
};

/**
 * The standee: printed card with a die-cut edge and a little thickness,
 * standing on the desk at its feet. `squash` > 0 presses it down (a
 * landing); `lean` tips it sideways.
 */
export const CatStandee = ({ map, size = 1, squash = 0, lean = 0 }: { map: THREE.Texture; size?: number; squash?: number; lean?: number }) => {
  const depthMaterial = useMemo(() => new THREE.MeshDepthMaterial({ depthPacking: THREE.RGBADepthPacking, map, alphaTest: 0.5 }), [map]);
  const sy = 1 - 0.22 * squash;
  const sx = 1 + 0.16 * squash;
  // The feet sit about 0.2 of the texture above its lower edge.
  return (
    <group rotation={[0, 0, lean]} scale={[size * sx, size * sy, size]}>
      <group position={[0, 0.5 - 0.17, 0]}>
        {[-0.02, -0.013, -0.006].map((z, i) => (
          <mesh key={i} position={[0, 0, z]}>
            <planeGeometry args={[1, 1]} />
            <meshStandardMaterial map={map} color={PAL.creamEdge} alphaTest={0.5} side={THREE.DoubleSide} roughness={1} />
          </mesh>
        ))}
        <mesh castShadow customDepthMaterial={depthMaterial}>
          <planeGeometry args={[1, 1]} />
          <meshStandardMaterial map={map} alphaTest={0.5} side={THREE.DoubleSide} roughness={0.9} />
        </mesh>
      </group>
    </group>
  );
};

// ───────────────────────── camera ─────────────────────────

export type Shot = { at: number; pos: [number, number, number]; look: [number, number, number]; fov?: number; ease?: (n: number) => number };

const mix3 = (a: number[], b: number[], p: number): [number, number, number] => [a[0] + (b[0] - a[0]) * p, a[1] + (b[1] - a[1]) * p, a[2] + (b[2] - a[2]) * p];

/** Where the camera is at `t`: eased from one written stop to the next. */
export const shotAt = (shots: Shot[], t: number) => {
  let i = 0;
  while (i < shots.length - 1 && t >= shots[i + 1].at) i++;
  const a = shots[i];
  const b = shots[Math.min(i + 1, shots.length - 1)];
  const p = b === a ? 0 : (b.ease ?? inOut)(Math.min(1, Math.max(0, (t - a.at) / (b.at - a.at))));
  return { pos: mix3(a.pos, b.pos, p), look: mix3(a.look, b.look, p), fov: (a.fov ?? 30) + ((b.fov ?? 30) - (a.fov ?? 30)) * p };
};

/** Points the canvas's camera, with a hand-held drift so nothing is ever dead still. */
export const Rig = ({ t, shots, drift = 1 }: { t: number; shots: Shot[]; drift?: number }) => {
  const camera = useThree((s) => s.camera) as THREE.PerspectiveCamera;
  const { pos, look, fov } = shotAt(shots, t);
  useLayoutEffect(() => {
    const d = drift * 0.02 * pos[1];
    camera.position.set(pos[0] + Math.sin(t * 0.7) * d, pos[1] + Math.sin(t * 0.53 + 1) * d * 0.5, pos[2] + Math.cos(t * 0.61) * d);
    camera.fov = fov;
    camera.up.set(0, 1, 0);
    camera.lookAt(look[0], look[1], look[2]);
    camera.updateProjectionMatrix();
    camera.updateMatrixWorld();
  });
  return null;
};

export const useHolder = () => useRef<HTMLDivElement>(null);
