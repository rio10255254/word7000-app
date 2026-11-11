#!/usr/bin/env node
// Render countdown reels on a machine with a GPU.
//   node scripts/render-local.mjs d6 d6-en
// Output goes to out/<id>.mp4. Pass --gl=<backend> to override (default: angle).
// On a laptop with two GPUs Windows gives headless Chrome the integrated one
// unless told otherwise: see "在自己的電腦算繪" in README.md.
import { spawnSync } from 'node:child_process';
import { mkdirSync } from 'node:fs';

const args = process.argv.slice(2);
const gl = (args.find((a) => a.startsWith('--gl=')) ?? '--gl=angle').slice(5);
const ids = args.filter((a) => !a.startsWith('--'));
// Anything else (--concurrency=8, --frames=0-120, ...) goes to Remotion as written.
const extra = args.filter((a) => a.startsWith('--') && !a.startsWith('--gl='));
if (!ids.length) {
  console.error('usage: node scripts/render-local.mjs <episode id> [...] [--gl=angle|vulkan|swangle]');
  process.exit(1);
}
mkdirSync('out', { recursive: true });
for (const id of ids) {
  const started = Date.now();
  const r = spawnSync('npx', ['remotion', 'render', `Reel-${id}`, `out/${id}.mp4`, `--gl=${gl}`, '--timeout=300000', ...extra], { stdio: 'inherit', shell: true });
  if (r.status !== 0) process.exit(r.status ?? 1);
  console.log(`${id}: ${Math.round((Date.now() - started) / 1000)} s -> out/${id}.mp4`);
}
