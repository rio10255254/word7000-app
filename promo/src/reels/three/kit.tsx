import { type ReactNode, useEffect, useLayoutEffect, useMemo, useRef, useState } from 'react';
import { useThree } from '@react-three/fiber';
import { Easing, continueRender, delayRender, interpolate, staticFile } from 'remotion';
import * as THREE from 'three';
import { GLTFLoader } from 'three/examples/jsm/loaders/GLTFLoader.js';
import { RGBELoader } from 'three/examples/jsm/loaders/RGBELoader.js';

/**
 * The 3D kit the launch countdown is built from: an iPhone model around
 * a real screenshot, a photo studio to light it, and
 * pieces of the interface that lift off its glass.
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
export const clamp = { extrapolateLeft: 'clamp', extrapolateRight: 'clamp' } as const;
export const inOut = Easing.bezier(0.65, 0, 0.35, 1);
export const out = Easing.bezier(0.16, 1, 0.3, 1);
/** 0 → 1 between `a` and `b` seconds. */
export const ramp = (t: number, a: number, b: number, easing: (n: number) => number = out) => interpolate(t, [a, b], [0, 1], { ...clamp, easing });
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
 * Everything a scene draws with, made once before its first frame: holds
 * the render until whatever `build` loads is there.
 */
export const usePrepared = <T,>(build: () => Promise<T>): T | null => {
  const [made, setMade] = useState<T | null>(null);
  const advance = useThree((s) => s.advance);
  const hold = useRef<number | null>(null);
  useEffect(() => {
    hold.current = delayRender('Preparing the 3D scene', { timeoutInMilliseconds: 120000 });
    let live = true;
    build()
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

// ───────────────────────── materials ─────────────────────────

/** Glass you look through: mostly reflection. */
export const Glass = ({ opacity = 0.16 }: { opacity?: number }) => <meshPhysicalMaterial color="#ffffff" transparent opacity={opacity} roughness={0.03} metalness={0} envMapIntensity={2.2} clearcoat={1} depthWrite={false} />;

// ───────────────────────── the phone ─────────────────────────

export const SCREEN_W = 1206;
export const SCREEN_H = 2622;
/** The screen is 1 unit wide. */
export const PHONE = { w: 1, h: SCREEN_H / SCREEN_W, depth: 0.105, radius: 0.137 };
/** A point on the screenshot, in the phone's own space. */
export const onScreen = (x: number, y: number, lift = 0.004): [number, number, number] => [(x / SCREEN_W - 0.5) * PHONE.w, (0.5 - y / SCREEN_H) * PHONE.h, PHONE.depth / 2 + lift];

const glareMap = canvasTexture(512, 512, (ctx, w, h) => {
  const g = ctx.createLinearGradient(0, 0, w, 0);
  g.addColorStop(0.3, 'rgba(255,250,235,0)');
  g.addColorStop(0.47, 'rgba(255,250,235,0.07)');
  g.addColorStop(0.53, 'rgba(255,250,235,0.09)');
  g.addColorStop(0.7, 'rgba(255,250,235,0)');
  ctx.fillStyle = g;
  ctx.fillRect(0, 0, w, h);
});
glareMap.rotation = -0.5;
glareMap.center.set(0.5, 0.5);
const glareTexture = (p: number) => {
  glareMap.offset.set(1.3 - p * 2.6, 0);
  return glareMap;
};

/** The model's own display, which the real screenshot replaces. */
const DISPLAY = 'baf05346569e3be49c2a';

/**
 * The phone itself: "iPhone 16 - Free" by wimell (Sketchfab, Free
 * Standard), without its textures, sized so its display is
 * exactly the screenshot's rectangle on z = depth / 2.
 */
export const loadPhone = async () => {
  const gltf = await new GLTFLoader().loadAsync(staticFile('models/iphone-16/iphone-16.gltf'));
  const model = gltf.scene;
  model.updateMatrixWorld(true);
  const display = model.getObjectByName(DISPLAY);
  if (!display) throw new Error('the phone model has no display');
  const box = new THREE.Box3().setFromObject(display);
  const all = new THREE.Box3().setFromObject(model);
  const size = box.getSize(new THREE.Vector3());
  const mid = box.getCenter(new THREE.Vector3());
  display.visible = false;
  const sx = PHONE.w / size.x;
  const sy = PHONE.h / size.y;
  const holder = new THREE.Group();
  model.scale.set(sx, sy, sx);
  model.position.set(-mid.x * sx, -mid.y * sy, PHONE.depth / 2 + 0.0003 - all.max.z * sx);
  holder.add(model);
  return holder;
};

/**
 * The phone: the model, with a real screenshot where its display was,
 * the Dynamic Island, whatever lifts off the glass, and a softbox's glare.
 */
export const Phone3D = ({ model, screen, glare = -1, children }: { model: THREE.Object3D; screen: THREE.Texture; glare?: number; children?: ReactNode }) => {
  const { w, h, depth, radius } = PHONE;
  const geo = useMemo(
    () => ({
      glass: faceGeometry(roundedRect(w, h, radius), w, h),
      island: new THREE.ShapeGeometry(roundedRect(0.312, 0.091, 0.0455), 10),
    }),
    [w, h, radius],
  );
  const z = depth / 2;
  return (
    <group>
      <primitive object={model} />
      <mesh geometry={geo.glass} position={[0, 0, z + 0.0015]}>
        <meshBasicMaterial map={screen} toneMapped={false} />
      </mesh>
      <mesh geometry={geo.island} position={[0, h / 2 - 0.0737, z + 0.0025]} renderOrder={6}>
        <meshBasicMaterial color="#030303" />
      </mesh>
      {children}
      <mesh geometry={geo.glass} position={[0, 0, z + 0.006]} renderOrder={7}>
        <Glass opacity={0.1} />
      </mesh>
      {/* A softbox passing over the glass: `glare` runs 0 → 1 across it. */}
      {glare > 0 && glare < 1 ? (
        <mesh geometry={geo.glass} position={[0, 0, z + 0.007]} renderOrder={8}>
          <meshBasicMaterial map={glareTexture(glare)} transparent blending={THREE.AdditiveBlending} depthWrite={false} toneMapped={false} />
        </mesh>
      ) : null}
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
    scene.environmentIntensity = 0.8;
    scene.environmentRotation.set(0, turn, 0);
    scene.background = null;
  });
  return (
    <>
      <directionalLight position={[-6, 7, 7]} intensity={1.7} color="#FFEBCB" />
      <directionalLight position={[7, 3, -5]} intensity={1.6} color="#FFD9A0" />
      <directionalLight position={[-7, -2, -6]} intensity={0.8} color="#FFF4E0" />
    </>
  );
};

// ───────────────────────── on the glass ─────────────────────────

const glassGeometry = faceGeometry(roundedRect(PHONE.w, PHONE.h, PHONE.radius), PHONE.w, PHONE.h);

/** Another screen over the phone's own, at `opacity`: a cross-fade from one screenshot to the next, or a dimmer. */
export const ScreenLayer = ({ map, opacity, color, over = false }: { map?: THREE.Texture; opacity: number; color?: string; over?: boolean }) =>
  opacity <= 0 ? null : (
    <mesh geometry={glassGeometry} position={[0, 0, PHONE.depth / 2 + (over ? 0.0021 : 0.0017)]} renderOrder={over ? 3 : 1}>
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
      <mesh geometry={geometry} position={[cx, cy, PHONE.depth / 2 + 0.0019]} renderOrder={2}>
        <meshBasicMaterial color={ground} transparent opacity={Math.min(1, lift * 9)} toneMapped={false} depthWrite={false} />
      </mesh>
      <mesh position={[cx + lift * 0.1, cy - lift * 0.14, z]} scale={[w * 1.5, h * 2.3, 1]} renderOrder={4}>
        <planeGeometry args={[1, 1]} />
        <meshBasicMaterial map={shadowMap} transparent opacity={Math.min(0.42, lift * 1.4)} depthWrite={false} toneMapped={false} />
      </mesh>
      <mesh geometry={geometry} position={[cx, cy, z + lift]} scale={1 + lift * 0.12} renderOrder={5}>
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
