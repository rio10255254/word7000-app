import { type ReactNode, useEffect, useLayoutEffect, useMemo, useRef, useState } from 'react';
import { useThree } from '@react-three/fiber';
import { Easing, continueRender, delayRender, interpolate, staticFile } from 'remotion';
import * as THREE from 'three';
import { RGBELoader } from 'three/examples/jsm/loaders/RGBELoader.js';

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

// ───────────────────────── materials ─────────────────────────

/** Fired clay with a satin glaze: the solid, coloured things. */
export const Enamel = ({ color, rough = 0.32 }: { color: string; rough?: number }) => <meshPhysicalMaterial color={color} roughness={rough} clearcoat={0.7} clearcoatRoughness={0.25} />;
/** Soft-touch: matte, a little sheen at grazing angles. */
export const Matte = ({ color, map }: { color?: string; map?: THREE.Texture }) => <meshPhysicalMaterial color={color ?? '#ffffff'} map={map ?? null} roughness={0.72} sheen={0.5} sheenColor="#fff3df" sheenRoughness={0.6} />;
export const Chrome = ({ color = '#d9d6cf', rough = 0.18 }: { color?: string; rough?: number }) => <meshStandardMaterial color={color} metalness={1} roughness={rough} envMapIntensity={1.6} />;
/** Glass you look through: mostly reflection. */
export const Glass = ({ opacity = 0.16 }: { opacity?: number }) => <meshPhysicalMaterial color="#ffffff" transparent opacity={opacity} roughness={0.03} metalness={0} envMapIntensity={2.2} clearcoat={1} depthWrite={false} />;

// ───────────────────────── the phone ─────────────────────────

export const SCREEN_W = 1206;
export const SCREEN_H = 2622;
/** The screen is 1 unit wide. */
export const PHONE = { w: 1, h: SCREEN_H / SCREEN_W, depth: 0.105, rim: 0.04, radius: 0.137 };
/** A point on the screenshot, in the phone's own space. */
export const onScreen = (x: number, y: number, lift = 0.004): [number, number, number] => [(x / SCREEN_W - 0.5) * PHONE.w, (0.5 - y / SCREEN_H) * PHONE.h, PHONE.depth / 2 + lift];

/**
 * An iPhone 17 Pro, modelled: a titanium frame with rounded edges, the
 * glass over a real screenshot, the Dynamic Island, the keys, and on the
 * back the camera plateau with its three lenses.
 */
const glareMap = canvasTexture(512, 512, (ctx, w, h) => {
  const g = ctx.createLinearGradient(0, 0, w, 0);
  g.addColorStop(0.3, 'rgba(255,250,235,0)');
  g.addColorStop(0.47, 'rgba(255,250,235,0.13)');
  g.addColorStop(0.53, 'rgba(255,250,235,0.16)');
  g.addColorStop(0.7, 'rgba(255,250,235,0)');
  ctx.fillStyle = g;
  ctx.fillRect(0, 0, w, h);
});
glareMap.wrapS = glareMap.wrapT = THREE.ClampToEdgeWrapping;
glareMap.rotation = -0.5;
glareMap.center.set(0.5, 0.5);
const glareTexture = (p: number) => {
  glareMap.offset.set(1.3 - p * 2.6, 0);
  return glareMap;
};

/** The phone's colour: Cosmic Orange, close to the reels' clay. */
const BODY = '#C9693A';

export const Phone3D = ({ screen, glare = -1, children }: { screen: THREE.Texture; glare?: number; children?: ReactNode }) => {
  const { w, h, depth, rim, radius } = PHONE;
  const geo = useMemo(() => {
    const body = roundedRect(w + rim * 2, h + rim * 2, radius + rim);
    const glass = roundedRect(w, h, radius);
    const bezel = roundedRect(w + rim * 1.2, h + rim * 1.2, radius + rim * 0.6);
    const back = roundedRect(w + rim * 1.5, h + rim * 1.5, radius + rim * 0.75);
    const plateau = roundedRect(w + rim * 0.6, 0.5, 0.16);
    return {
      body: slabGeometry(body, depth, 0.028),
      bezel: new THREE.ShapeGeometry(bezel, 12),
      glass: faceGeometry(glass, w, h),
      back: new THREE.ShapeGeometry(back, 12),
      island: new THREE.ShapeGeometry(roundedRect(0.312, 0.091, 0.0455), 10),
      plateau: slabGeometry(plateau, 0.04, 0.012),
      inset: new THREE.ShapeGeometry(roundedRect(w - 0.1, h - 0.72, 0.1), 10),
    };
  }, [w, h, depth, rim, radius]);
  const z = depth / 2;
  const key = (side: 1 | -1, y: number, length: number) => (
    <mesh position={[side * (w / 2 + rim + 0.006), y, 0]} rotation={[0, 0, 0]} castShadow>
      <capsuleGeometry args={[0.011, length, 4, 10]} />
      <meshStandardMaterial color={BODY} metalness={0.9} roughness={0.3} envMapIntensity={1.25} />
    </mesh>
  );
  const lens = (x: number, y: number) => (
    <group position={[x, y, -z - 0.04]} rotation={[Math.PI / 2, 0, 0]}>
      <mesh castShadow>
        <cylinderGeometry args={[0.105, 0.11, 0.035, 40]} />
        <meshStandardMaterial color="#8E4526" metalness={0.95} roughness={0.25} envMapIntensity={1.4} />
      </mesh>
      <mesh position={[0, -0.019, 0]}>
        <cylinderGeometry args={[0.088, 0.088, 0.004, 40]} />
        <meshPhysicalMaterial color="#07090d" roughness={0.05} clearcoat={1} envMapIntensity={2.5} />
      </mesh>
      <mesh position={[0, -0.022, 0]}>
        <torusGeometry args={[0.05, 0.006, 8, 32]} />
        <meshStandardMaterial color="#1b2333" metalness={0.8} roughness={0.2} />
      </mesh>
      <mesh position={[0, -0.0225, 0]}>
        <cylinderGeometry args={[0.028, 0.028, 0.002, 24]} />
        <meshPhysicalMaterial color="#141d33" roughness={0.02} clearcoat={1} envMapIntensity={3} />
      </mesh>
    </group>
  );
  return (
    <group>
      <mesh geometry={geo.body}>
        <meshStandardMaterial color={BODY} metalness={0.9} roughness={0.36} envMapIntensity={1.25} />
      </mesh>
      {key(-1, 0.52, 0.09)}
      {key(-1, 0.3, 0.16)}
      {key(-1, 0.07, 0.16)}
      {key(1, 0.24, 0.26)}
      {/* The front: bezel, the screen itself, the island, and the glass over it. */}
      <mesh geometry={geo.bezel} position={[0, 0, z + 0.0005]}>
        <meshStandardMaterial color="#070707" roughness={0.25} />
      </mesh>
      <mesh geometry={geo.glass} position={[0, 0, z + 0.0015]}>
        <meshBasicMaterial map={screen} toneMapped={false} />
      </mesh>
      <mesh geometry={geo.island} position={[0, h / 2 - 0.0737, z + 0.0025]}>
        <meshBasicMaterial color="#030303" />
      </mesh>
      {children}
      <mesh geometry={geo.bezel} position={[0, 0, z + 0.006]}>
        <Glass opacity={0.1} />
      </mesh>
      {/* A softbox passing over the glass: `glare` runs 0 → 1 across it. */}
      {glare > 0 && glare < 1 ? (
        <mesh geometry={geo.glass} position={[0, 0, z + 0.007]}>
          <meshBasicMaterial map={glareTexture(glare)} transparent blending={THREE.AdditiveBlending} depthWrite={false} toneMapped={false} />
        </mesh>
      ) : null}
      {/* The bottom edge: the port and the speaker holes. */}
      <mesh position={[0, -h / 2 - rim - 0.001, 0]} rotation={[0, 0, Math.PI / 2]}>
        <capsuleGeometry args={[0.014, 0.085, 4, 10]} />
        <meshStandardMaterial color="#2a1a12" roughness={0.6} />
      </mesh>
      {[-0.3, -0.25, -0.2, 0.2, 0.25, 0.3].map((x) => (
        <mesh key={x} position={[x, -h / 2 - rim - 0.001, 0]}>
          <sphereGeometry args={[0.0095, 10, 8]} />
          <meshStandardMaterial color="#2a1a12" roughness={0.6} />
        </mesh>
      ))}
      {/* The back: frosted glass, the plateau, three lenses, the flash. */}
      <mesh geometry={geo.back} position={[0, 0, -z - 0.0005]} rotation={[0, Math.PI, 0]}>
        <meshStandardMaterial color={BODY} metalness={0.85} roughness={0.42} envMapIntensity={1.1} />
      </mesh>
      <mesh geometry={geo.inset} position={[0, -0.27, -z - 0.0012]} rotation={[0, Math.PI, 0]}>
        <meshStandardMaterial color="#BC5F31" metalness={0.8} roughness={0.6} envMapIntensity={0.9} />
      </mesh>
      <mesh geometry={geo.plateau} position={[0, h / 2 - 0.25, -z - 0.015]} castShadow>
        <meshStandardMaterial color={BODY} metalness={0.9} roughness={0.34} envMapIntensity={1.25} />
      </mesh>
      {lens(0.3, h / 2 - 0.15)}
      {lens(0.3, h / 2 - 0.36)}
      {lens(0.09, h / 2 - 0.255)}
      <mesh position={[-0.2, h / 2 - 0.15, -z - 0.037]} rotation={[Math.PI / 2, 0, 0]}>
        <cylinderGeometry args={[0.035, 0.035, 0.004, 24]} />
        <meshStandardMaterial color="#fff3cf" emissive="#ffe9b0" emissiveIntensity={0.25} roughness={0.3} />
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
    <group position={onScreen(x, y, 0.004)}>
      <mesh scale={s}>
        <ringGeometry args={[0.78, 1, 40]} />
        <meshBasicMaterial color={PAL.clay} transparent opacity={0.85 * (1 - p)} depthWrite={false} toneMapped={false} />
      </mesh>
      <mesh scale={0.045 * (1 - 0.4 * p)}>
        <circleGeometry args={[1, 32]} />
        <meshBasicMaterial color={PAL.clay} transparent opacity={0.4 * (1 - p)} depthWrite={false} toneMapped={false} />
      </mesh>
    </group>
  );
};

// ───────────────────────── light ─────────────────────────

/** A real photo studio to reflect (Poly Haven's Studio Small 08, CC0), as an environment map. */
export const loadStudio = async (gl: THREE.WebGLRenderer) => {
  const hdr = await new RGBELoader().loadAsync(staticFile('hdri/studio_small_08_1k.hdr'));
  hdr.mapping = THREE.EquirectangularReflectionMapping;
  const pmrem = new THREE.PMREMGenerator(gl);
  const map = pmrem.fromEquirectangular(hdr).texture;
  pmrem.dispose();
  hdr.dispose();
  return map;
};

/** The studio in every reflection, turned by `turn` so its softboxes slide across the phone, and a warm key from up left. */
export const StudioLight = ({ env, turn = 0 }: { env: THREE.Texture; turn?: number }) => {
  const scene = useThree((s) => s.scene);
  useLayoutEffect(() => {
    scene.environment = env;
    scene.environmentIntensity = 1.0;
    scene.environmentRotation.set(0, turn, 0);
    scene.background = null;
  });
  return (
    <>
      <directionalLight position={[-6, 7, 7]} intensity={2.6} color="#FFEBCB" />
      <directionalLight position={[7, 3, -5]} intensity={2.4} color="#FFD9A0" />
      <directionalLight position={[-7, -2, -6]} intensity={1.2} color="#FFF4E0" />
    </>
  );
};

// ───────────────────────── on the glass ─────────────────────────

const glassGeometry = faceGeometry(roundedRect(PHONE.w, PHONE.h, PHONE.radius), PHONE.w, PHONE.h);

/** Another screen over the phone's own, at `opacity`: a cross-fade from one screenshot to the next, or a dimmer. */
export const ScreenLayer = ({ map, opacity, color }: { map?: THREE.Texture; opacity: number; color?: string }) =>
  opacity <= 0 ? null : (
    <mesh geometry={glassGeometry} position={[0, 0, PHONE.depth / 2 + 0.0019]} renderOrder={1}>
      <meshBasicMaterial map={map ?? null} color={color ?? '#ffffff'} transparent opacity={opacity} toneMapped={false} depthWrite={false} />
    </mesh>
  );

const softShadow = () =>
  canvasTexture(256, 128, (ctx, w, h) => {
    ctx.filter = 'blur(18px)';
    ctx.fillStyle = 'rgba(40,32,20,0.75)';
    ctx.beginPath();
    ctx.roundRect(44, 44, w - 88, h - 88, 12);
    ctx.fill();
  });
let shadowMap: THREE.Texture | null = null;

/**
 * A piece of the interface lifted off the glass: the rectangle
 * (x0, y0)–(x1, y1) of the screenshot, floating `lift` above the screen
 * with the shadow it would cast on it. This is the exploded view.
 */
export const Lift = ({ map, crop, lift, radius = 44, ground }: { map: THREE.Texture; crop: [number, number, number, number]; lift: number; radius?: number; ground: string }) => {
  const [x0, y0, x1, y1] = crop;
  const w = ((x1 - x0) / SCREEN_W) * PHONE.w;
  const h = ((y1 - y0) / SCREEN_H) * PHONE.h;
  const geometry = useMemo(() => {
    const shape = roundedRect(w, h, (radius / SCREEN_W) * PHONE.w);
    const g = new THREE.ShapeGeometry(shape, 8);
    const pos = g.attributes.position;
    const uv = g.attributes.uv;
    for (let i = 0; i < pos.count; i++) uv.setXY(i, (x0 + (pos.getX(i) / w + 0.5) * (x1 - x0)) / SCREEN_W, 1 - (y0 + (0.5 - pos.getY(i) / h) * (y1 - y0)) / SCREEN_H);
    return g;
  }, [w, h, x0, y0, x1, y1, radius]);
  shadowMap ??= softShadow();
  if (lift <= 0.0005) return null;
  const [cx, cy, z] = onScreen((x0 + x1) / 2, (y0 + y1) / 2, 0.003);
  return (
    <>
      <mesh geometry={geometry} position={[cx, cy, z - 0.0008]} renderOrder={2}>
        <meshBasicMaterial color={ground} transparent opacity={Math.min(1, lift * 9)} toneMapped={false} depthWrite={false} />
      </mesh>
      <mesh position={[cx + lift * 0.1, cy - lift * 0.14, z]} scale={[w * 1.5, h * 2.3, 1]} renderOrder={3}>
        <planeGeometry args={[1, 1]} />
        <meshBasicMaterial map={shadowMap} transparent opacity={Math.min(0.42, lift * 1.4)} depthWrite={false} toneMapped={false} />
      </mesh>
      <mesh geometry={geometry} position={[cx, cy, z + lift]} scale={1 + lift * 0.12} renderOrder={4}>
        <meshBasicMaterial map={map} toneMapped={false} />
      </mesh>
    </>
  );
};

/** The colour of the screenshot at (x, y), as CSS: what is left where a piece lifts away. */
export const colorAt = (map: THREE.Texture, x: number, y: number) => {
  const canvas = document.createElement('canvas');
  canvas.width = canvas.height = 1;
  const ctx = canvas.getContext('2d')!;
  ctx.drawImage(map.image as HTMLImageElement, -x, -y);
  const [r, g, b] = ctx.getImageData(0, 0, 1, 1).data;
  return `rgb(${r},${g},${b})`;
};
