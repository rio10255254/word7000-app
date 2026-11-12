import { useMemo } from 'react';
import * as THREE from 'three';
import { PAL, canvasTexture, roundedRect } from './kit';

/**
 * Things made for the last two reels, built from primitives (no models):
 * a wood-handled rubber stamp, a tin of cat food with a paper label, and
 * the app's icon as a thick glossy tile. Like everything in the kit they
 * keep no time of their own.
 */

// ───────────────────────── the rubber stamp ─────────────────────────

const woodGrain = () =>
  canvasTexture(256, 512, (ctx, w, h) => {
    ctx.fillStyle = '#B27A45';
    ctx.fillRect(0, 0, w, h);
    // Long streaks down the handle, a little darker and lighter than the wood.
    for (let i = 0; i < 90; i++) {
      const x = (Math.sin(i * 12.9898) * 43758.5453) % 1;
      const xx = (x < 0 ? x + 1 : x) * w;
      ctx.strokeStyle = i % 3 ? `rgba(92,52,22,${0.05 + (i % 7) * 0.02})` : `rgba(240,200,150,${0.06 + (i % 5) * 0.02})`;
      ctx.lineWidth = 1 + (i % 4);
      ctx.beginPath();
      ctx.moveTo(xx, 0);
      ctx.bezierCurveTo(xx + 8, h * 0.3, xx - 8, h * 0.7, xx + 4, h);
      ctx.stroke();
    }
  });

/** The stamp's outline from its foot up to the knob: (radius, height). */
const HANDLE: [number, number][] = [
  [0.0, 0.06],
  [0.245, 0.06],
  [0.25, 0.075],
  [0.25, 0.13],
  [0.235, 0.15],
  [0.13, 0.19],
  [0.085, 0.26],
  [0.07, 0.36],
  [0.072, 0.44],
  [0.1, 0.52],
  [0.135, 0.59],
  [0.15, 0.66],
  [0.145, 0.72],
  [0.115, 0.775],
  [0.06, 0.805],
  [0.0, 0.81],
];
export const STAMP_HEIGHT = 0.81;
/** The rubber's radius: what it prints. */
export const STAMP_PAD = 0.236;

/**
 * A round rubber stamp with a turned, varnished wood handle, standing on
 * its rubber at the origin with the handle up +y. `press` (0–1) squeezes
 * the rubber as it lands.
 */
export const RubberStamp = ({ press = 0 }: { press?: number }) => {
  const made = useMemo(() => {
    const grain = woodGrain();
    grain.wrapS = grain.wrapT = THREE.RepeatWrapping;
    return {
      grain,
      handle: new THREE.LatheGeometry(
        HANDLE.map(([r, y]) => new THREE.Vector2(r, y)),
        56,
      ),
    };
  }, []);
  const squeeze = 1 - 0.45 * press;
  return (
    <group>
      {/* The rubber, inked. */}
      <mesh position={[0, 0.03 * squeeze, 0]} scale={[1 + 0.05 * press, squeeze, 1 + 0.05 * press]}>
        <cylinderGeometry args={[STAMP_PAD, STAMP_PAD, 0.06, 56]} />
        <meshStandardMaterial color="#B5502F" roughness={0.9} metalness={0} />
      </mesh>
      <group position={[0, -0.06 * 0.45 * press, 0]}>
        <mesh geometry={made.handle}>
          <meshPhysicalMaterial map={made.grain} color="#ffffff" roughness={0.42} metalness={0} clearcoat={0.55} clearcoatRoughness={0.25} envMapIntensity={1.1} />
        </mesh>
        {/* A brass band where the handle meets the foot. */}
        <mesh position={[0, 0.152, 0]} rotation={[Math.PI / 2, 0, 0]}>
          <torusGeometry args={[0.232, 0.012, 14, 64]} />
          <meshStandardMaterial color="#E2B45A" roughness={0.28} metalness={1} envMapIntensity={1.4} />
        </mesh>
      </group>
    </group>
  );
};

// ───────────────────────── the cat can ─────────────────────────

/** A fish, as on the app's own can. */
const fish = (ctx: CanvasRenderingContext2D, x: number, y: number, s: number, color: string) => {
  ctx.save();
  ctx.translate(x, y);
  ctx.scale(s, s);
  ctx.fillStyle = color;
  ctx.beginPath();
  ctx.ellipse(0, 0, 30, 17, 0, 0, Math.PI * 2);
  ctx.fill();
  ctx.beginPath();
  ctx.moveTo(-24, 0);
  ctx.lineTo(-48, -17);
  ctx.lineTo(-48, 17);
  ctx.closePath();
  ctx.fill();
  ctx.fillStyle = '#FBF6EA';
  ctx.beginPath();
  ctx.arc(14, -4, 3.6, 0, Math.PI * 2);
  ctx.fill();
  ctx.restore();
};

const canLabel = (word: string) =>
  canvasTexture(1024, 256, (ctx, w, h) => {
    ctx.fillStyle = '#F6EEDC';
    ctx.fillRect(0, 0, w, h);
    ctx.fillStyle = PAL.clay;
    ctx.fillRect(0, 0, w, 34);
    ctx.fillRect(0, h - 34, w, 34);
    ctx.fillStyle = '#E3B95B';
    ctx.fillRect(0, 34, w, 8);
    ctx.fillRect(0, h - 42, w, 8);
    const cjk = /[㐀-鿿]/.test(word);
    // The label reads the same from any side: twice round the tin.
    for (const x0 of [0, w / 2]) {
      fish(ctx, x0 + 92, h / 2, 1.25, PAL.clay);
      ctx.fillStyle = PAL.ink;
      ctx.textAlign = 'left';
      ctx.textBaseline = 'middle';
      ctx.font = cjk ? '900 92px "Noto Sans TC"' : '800 80px "Noto Serif"';
      ctx.fillText(word, x0 + 158, h / 2 + 4);
    }
  });

const lidTexture = () =>
  canvasTexture(256, 256, (ctx, w, h) => {
    ctx.fillStyle = '#D8D3C6';
    ctx.fillRect(0, 0, w, h);
    // Pressed rings in the lid.
    for (const r of [112, 96, 60]) {
      ctx.strokeStyle = 'rgba(70,64,52,0.35)';
      ctx.lineWidth = 3;
      ctx.beginPath();
      ctx.arc(w / 2, h / 2, r, 0, Math.PI * 2);
      ctx.stroke();
      ctx.strokeStyle = 'rgba(255,255,255,0.5)';
      ctx.lineWidth = 2;
      ctx.beginPath();
      ctx.arc(w / 2, h / 2 + 2, r, 0, Math.PI * 2);
      ctx.stroke();
    }
    // The fish, printed on the lid.
    fish(ctx, w / 2 + 44, h / 2 + 30, 0.9, '#B5502F');
  });

export const CAN = { r: 0.092, h: 0.11 };

/**
 * A small tin with a paper label round it and a ring-pull on the lid,
 * standing on the origin with its lid up +y. `word` is what the app calls it.
 */
export const CatCan = ({ word }: { word: string }) => {
  const made = useMemo(() => ({ label: canLabel(word), lid: lidTexture() }), [word]);
  const { r, h } = CAN;
  const metal = <meshStandardMaterial color="#D9D4C8" roughness={0.3} metalness={1} envMapIntensity={1.3} />;
  return (
    <group position={[0, h / 2, 0]}>
      <mesh>
        <cylinderGeometry args={[r * 0.985, r * 0.985, h * 0.86, 56, 1, true]} />
        <meshStandardMaterial map={made.label} roughness={0.78} metalness={0} />
      </mesh>
      {/* The tin above and below the label. */}
      <mesh>
        <cylinderGeometry args={[r * 0.97, r * 0.97, h, 56, 1, true]} />
        {metal}
      </mesh>
      {[1, -1].map((side) => (
        <group key={side} position={[0, (side * h) / 2, 0]}>
          <mesh rotation={[(-side * Math.PI) / 2, 0, 0]}>
            <circleGeometry args={[r * 0.97, 56]} />
            <meshStandardMaterial map={made.lid} roughness={0.32} metalness={1} envMapIntensity={1.3} />
          </mesh>
          <mesh rotation={[Math.PI / 2, 0, 0]}>
            <torusGeometry args={[r * 0.985, r * 0.045, 12, 56]} />
            {metal}
          </mesh>
        </group>
      ))}
      {/* The ring-pull. */}
      <group position={[r * 0.18, h / 2 + r * 0.03, 0]}>
        <mesh rotation={[Math.PI / 2, 0, 0]}>
          <torusGeometry args={[r * 0.24, r * 0.05, 10, 32]} />
          {metal}
        </mesh>
        <mesh position={[-r * 0.36, 0, 0]}>
          <boxGeometry args={[r * 0.3, r * 0.04, r * 0.2]} />
          {metal}
        </mesh>
      </group>
    </group>
  );
};

// ───────────────────────── the app's icon ─────────────────────────

/**
 * The icon as an object: a thick rounded tile, the artwork under a clear
 * coat on its face, the olive running round its sides. 1 unit wide,
 * facing +z.
 */
export const IconTile = ({ map, depth = 0.16 }: { map: THREE.Texture; depth?: number }) => {
  const made = useMemo(() => {
    const shape = roundedRect(1, 1, 0.225);
    const face = new THREE.ShapeGeometry(roundedRect(0.985, 0.985, 0.218), 12);
    const pos = face.attributes.position;
    const uv = face.attributes.uv;
    for (let i = 0; i < pos.count; i++) uv.setXY(i, pos.getX(i) / 0.985 + 0.5, pos.getY(i) / 0.985 + 0.5);
    const body = new THREE.ExtrudeGeometry(shape, { depth: depth - 0.04, bevelEnabled: true, bevelSize: 0.02, bevelThickness: 0.02, bevelSegments: 4, curveSegments: 12 });
    body.translate(0, 0, -(depth - 0.04) / 2);
    return { face, body };
  }, [depth]);
  return (
    <group>
      <mesh geometry={made.body}>
        <meshPhysicalMaterial color="#7D8C58" roughness={0.38} metalness={0} clearcoat={0.7} clearcoatRoughness={0.2} envMapIntensity={1.1} />
      </mesh>
      <mesh geometry={made.face} position={[0, 0, depth / 2 + 0.0012]}>
        <meshPhysicalMaterial map={map} roughness={0.55} metalness={0} clearcoat={0.55} clearcoatRoughness={0.12} envMapIntensity={0.45} />
      </mesh>
    </group>
  );
};
