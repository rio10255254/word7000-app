#!/usr/bin/env node
// WordCat Next: synthesizes the app's short sound effects (answers, stars,
// stamps, a finished day) as 16-bit mono WAV files, so they need no outside
// recordings and can be tuned here. Run after changing them:
//   node scripts/make-sound-effects.mjs
// Writes ios/Word7000/Resources/Sounds/sfx-*.wav.
import { mkdirSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const rate = 44100;
const out = join(dirname(fileURLToPath(import.meta.url)), '..', 'ios', 'Word7000', 'Resources', 'Sounds');

// A struck note: a few partials, each dying away faster than the one below,
// after a few milliseconds' attack so it does not click.
function bell(buffer, start, freq, { decay = 0.25, amp = 1, partials = [[1, 1], [2, 0.32], [3, 0.1], [4.2, 0.04]], glide = 0, attack = 0.004 } = {}) {
  const from = Math.round(start * rate);
  const length = Math.round((decay * 7 + attack) * rate);
  for (let i = 0; i < length && from + i < buffer.length; i++) {
    const t = i / rate;
    const envelope = (t < attack ? t / attack : 1) * Math.exp(-(t - Math.min(t, attack)) / decay);
    // A glide bends the pitch over the first tenth of a second (negative: down).
    const bend = 1 + glide * Math.min(1, t / 0.1);
    let value = 0;
    for (const [ratio, level] of partials) {
      value += level * Math.sin(2 * Math.PI * freq * ratio * bend * t) * Math.exp(-t * (ratio - 1) * 3);
    }
    buffer[from + i] += amp * envelope * value;
  }
}

// A short burst of soft noise, like paper or a rubber stamp meeting it.
function tap(buffer, start, { decay = 0.012, amp = 0.3, smooth = 0.35 } = {}) {
  const from = Math.round(start * rate);
  let last = 0;
  let seed = 7;
  for (let i = 0; i < Math.round(decay * 8 * rate) && from + i < buffer.length; i++) {
    seed = (seed * 16807) % 2147483647;
    const noise = (seed / 2147483647) * 2 - 1;
    last += smooth * (noise - last); // one-pole low-pass: duller, not hissing
    const attack = Math.min(1, i / (0.001 * rate)); // 1 ms, so it does not click
    buffer[from + i] += amp * attack * last * Math.exp(-(i / rate) / decay);
  }
}

function render(seconds, draw, peak) {
  const buffer = new Float64Array(Math.round(seconds * rate));
  draw(buffer);
  // Fade the last 20 ms, then bring the loudest sample to `peak`.
  const fade = Math.round(0.02 * rate);
  for (let i = 0; i < fade; i++) buffer[buffer.length - 1 - i] *= i / fade;
  const max = buffer.reduce((m, v) => Math.max(m, Math.abs(v)), 0) || 1;
  return buffer.map((v) => (v / max) * peak);
}

function wav(samples) {
  const data = Buffer.alloc(samples.length * 2);
  samples.forEach((v, i) => data.writeInt16LE(Math.round(Math.max(-1, Math.min(1, v)) * 32767), i * 2));
  const head = Buffer.alloc(44);
  head.write('RIFF', 0);
  head.writeUInt32LE(36 + data.length, 4);
  head.write('WAVE', 8);
  head.write('fmt ', 12);
  head.writeUInt32LE(16, 16);
  head.writeUInt16LE(1, 20); // PCM
  head.writeUInt16LE(1, 22); // mono
  head.writeUInt32LE(rate, 24);
  head.writeUInt32LE(rate * 2, 28);
  head.writeUInt16LE(2, 32);
  head.writeUInt16LE(16, 34);
  head.write('data', 36);
  head.writeUInt32LE(data.length, 40);
  return Buffer.concat([head, data]);
}

const note = (name) => {
  const names = { C: -9, D: -7, E: -5, F: -4, G: -2, A: 0, B: 2 };
  const [, letter, sharp, octave] = name.match(/^([A-G])(#?)(\d)$/);
  return 440 * 2 ** ((names[letter] + (sharp ? 1 : 0) + (Number(octave) - 4) * 12) / 12);
};

const sounds = {
  // Right: two bright notes up a fifth, quick.
  correct: render(0.62, (b) => {
    bell(b, 0, note('C6'), { decay: 0.09, amp: 0.8 });
    bell(b, 0.075, note('G6'), { decay: 0.17, amp: 1 });
  }, 0.42),
  // Wrong: two soft, round notes stepping down, nothing like a buzzer.
  wrong: render(0.55, (b) => {
    // The second partial carries it on a phone's small speaker.
    const round = [[1, 1], [2, 0.3], [3, 0.06]];
    bell(b, 0, note('A4'), { decay: 0.08, amp: 0.9, partials: round });
    bell(b, 0.1, note('E4'), { decay: 0.14, amp: 1, partials: round, glide: -0.02 });
  }, 0.34),
  // Stars: one glinting note each, climbing a major chord.
  ...Object.fromEntries(['C6', 'E6', 'G6'].map((name, index) => [`star${index + 1}`, render(0.75, (b) => {
    const shimmer = [[1, 1], [2.003, 0.38], [3.01, 0.12], [5.02, 0.05]];
    bell(b, 0, note(name), { decay: 0.16 + index * 0.03, amp: 1, partials: shimmer });
    bell(b, 0.012, note(name) * 2, { decay: 0.03, amp: 0.22, partials: [[1, 1]] });
  }, 0.38 + index * 0.03)])),
  // Stamp: a dull thud pitched where a phone's speaker can play it, and the
  // paper's slap.
  stamp: render(0.32, (b) => {
    bell(b, 0, 210, { decay: 0.05, amp: 1, partials: [[1, 1], [2, 0.45], [3, 0.15]], glide: -0.3, attack: 0.002 });
    tap(b, 0, { decay: 0.01, amp: 0.7, smooth: 0.5 });
  }, 0.6),
  // A finished round or day: a rising chord in four notes, the last ringing.
  complete: render(1.5, (b) => {
    ['C5', 'E5', 'G5'].forEach((name, index) => bell(b, index * 0.085, note(name), { decay: 0.12, amp: 0.75 }));
    bell(b, 0.255, note('C6'), { decay: 0.32, amp: 1 });
    bell(b, 0.255, note('E6'), { decay: 0.26, amp: 0.3 });
  }, 0.42),
};

mkdirSync(out, { recursive: true });
for (const [name, samples] of Object.entries(sounds)) {
  const file = join(out, `sfx-${name}.wav`);
  writeFileSync(file, wav(samples));
  console.log(`${file.replace(/^.*ios\//, 'ios/')}  ${(samples.length / rate).toFixed(2)} s`);
}
