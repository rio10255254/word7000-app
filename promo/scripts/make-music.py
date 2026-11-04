#!/usr/bin/env python3
"""Compose the promo soundtrack from src/timeline.json.

A sunset tropical-house piece, after the owner's picture for it: sunshine,
palm trees, a purple sunset, wine, a beach. Light and bouncy at 120 bpm in
B-flat, on the warm vi–IV–I–V loop of house and tropical pop
(Gm7 → Ebmaj7 → B♭ → F):

- sunshine: the tune high on a real soprano recorder, with glockenspiel glints
- palm trees: marimba on the off-beats, congas and bongos
- purple sunset: a soft, warm synth pad under everything
- wine: an echo on the tune that floats, over a bouncy groove
- the beach: real waves (an ocean drum) under the intro, the dip and the end

It still follows the reference's arc and its layers: a soft intro, a verse
that grows, a pre-chorus climb, the fullest chorus, a quiet dip, a warm end;
the tune is call and response, highest at the chorus, and its phrases fall.
The tune follows what research and producers say makes pop hooks stick: a
two-to-five-note cell repeated with small changes, mostly pentatonic and
stepwise, syncopated, stated early and often, teased at half speed before
the chorus, and carried by the marimba in the chorus as tropical drops are. Instruments are real
samples — acoustic guitar (University of Iowa, free for any use), soprano
recorder, glockenspiel, marimba, hand drums and ocean drum (VCSL, CC0); see
assets/*/CREDITS.md — with a synthesised pad, bass and kick.

Scene changes are the rhythm of the piece. The scenes are laid out exactly
as src/transitions.tsx lays them out, so every transition starts on a
strong beat, and at each one the drums drop out for the half beat before
it, a reversed strum swells into it, and the kick and a low hit land on it
as the chords move on.

Writes public/audio/full.mp3. Needs numpy, scipy and ffmpeg.
"""
import json
import math
import subprocess
import sys
import tempfile
import wave
from pathlib import Path

import numpy as np
from scipy.signal import butter, fftconvolve, lfilter, sosfilt

ROOT = Path(__file__).resolve().parent.parent
TIMELINE = json.loads((ROOT / "src" / "timeline.json").read_text())

SR = 44100
OUTPUT_FPS = 60
FRAME_SCALE = 1.2 * (60 / 30)  # time.ts: SPEED × OUTPUT_FPS / AUTHORED_FPS
BPM = TIMELINE["bpm"]
HOLD = TIMELINE["hold"]
BEAT_FRAMES = round(OUTPUT_FPS * 60 / BPM)
GRID = TIMELINE.get("quantizeBeats", 1) * BEAT_FRAMES
BAR_PHASE = TIMELINE.get("barPhaseBeats", 0) * BEAT_FRAMES
BEAT = BEAT_FRAMES / OUTPUT_FPS  # seconds
BAR = BEAT * 4
SWING = 0.04  # a touch of lilt on the off-beats
rng = np.random.default_rng(7000)


def js_round(x):
    return math.floor(x + 0.5)


def ceil_to(frames, unit):
    return math.ceil(frames / unit) * unit


# ── Timeline, exactly as transitions.tsx lays it out ──────────────────────────


def turn_frames(entry):
    return entry.get("turnBeats", 1) * BEAT_FRAMES


def raw_frames(entry):
    if "steps" in entry:
        return track_layout(entry["steps"])[2]
    return js_round((entry["duration"] + HOLD) * FRAME_SCALE)


def track_layout(entries):
    starts, lengths, t = [], [], 0
    for i, e in enumerate(entries):
        starts.append(t)
        if i + 1 < len(entries):
            nxt = entries[i + 1]
            advance = ceil_to(raw_frames(e) - turn_frames(nxt), GRID)
            # A scene that opens a new section of the song waits for the next bar line.
            while nxt.get("onBar") and (t + advance - BAR_PHASE) % (4 * BEAT_FRAMES) != 0:
                advance += GRID
            lengths.append(advance + turn_frames(nxt))
            t += advance
        else:
            lengths.append(ceil_to(raw_frames(e), BEAT_FRAMES))
    return starts, lengths, t + lengths[-1]


def flatten(entries, offset=0):
    """Every scene (nested ones too) with its start and transition, in output frames."""
    starts, _, total = track_layout(entries)
    out = []
    for i, (e, start) in enumerate(zip(entries, starts)):
        out.append({**e, "start": offset + start, "turn": turn_frames(e) if i else 0, "nested": offset > 0})
        if "steps" in e:
            out.extend(s for s in flatten(e["steps"], offset + start) if s["turn"])
    return out if offset else (out, total)


# ── Sound helpers ────────────────────────────────────────────────────────────


def midi(n):
    return 440.0 * 2 ** ((n - 69) / 12)


def place(bus, sig, at, gain=1.0):
    i = int(round(at * SR))
    if i >= len(bus) or i + len(sig) <= 0:
        return
    if i < 0:
        sig, i = sig[-i:], 0
    end = min(len(bus), i + len(sig))
    bus[i:end] += sig[: end - i] * gain


def lowpass(x, hz, order=2):
    return sosfilt(butter(order, hz, "low", fs=SR, output="sos"), x)


def highpass(x, hz, order=2):
    return sosfilt(butter(order, hz, "high", fs=SR, output="sos"), x)


def bandpass(x, lo, hi, order=2):
    return sosfilt(butter(order, [lo, hi], "band", fs=SR, output="sos"), x)


# ── Sampled instruments ──────────────────────────────────────────────────────
# Acoustic guitar: University of Iowa Musical Instrument Samples (free for any use).
# Soprano recorder, glockenspiel, marimba, hand drums, ocean drum: VCSL (CC0).

NAMES = {"C": 0, "Cs": 1, "D": 2, "Ds": 3, "E": 4, "F": 5, "Fs": 6, "G": 7, "Gs": 8, "A": 9, "As": 10, "B": 11}
_banks = {}


def _decode(path):
    raw = subprocess.run(
        ["ffmpeg", "-v", "error", "-i", str(path), "-f", "s16le", "-ac", "1", "-ar", str(SR), "-"],
        capture_output=True,
        check=True,
    ).stdout
    return np.frombuffer(raw, dtype="<i2").astype(np.float64) / 32768


def bank(folder):
    """note number → recording, trimmed to its onset and normalised."""
    if folder not in _banks:
        notes = {}
        for f in (ROOT / "assets" / folder).glob("*.mp3"):
            name = f.stem.rstrip("0123456789")
            note = 12 * (int(f.stem[len(name) :]) + 1) + NAMES[name]
            audio = _decode(f)
            onset = int(np.argmax(np.abs(audio) > 0.02 * np.max(np.abs(audio))))
            audio = audio[max(0, onset - 16) :]
            notes[note] = audio / (np.max(np.abs(audio)) + 1e-9)
        _banks[folder] = notes
    return _banks[folder]


def sampled(folder, note, length):
    notes = bank(folder)
    source = min(notes, key=lambda k: abs(k - note))
    ratio = 2 ** ((note - source) / 12)
    src = notes[source]
    n = max(1, min(int(length * SR), int(len(src) / ratio) - 1))
    return np.interp(np.arange(n) * ratio, np.arange(len(src)), src)


def guitar(note, length=1.0, velocity=0.6):
    """One string, stopped cleanly at `length` (damped when the next strum lands)."""
    out = sampled("iowa-guitar", note, length)
    t = np.arange(len(out)) / SR
    release = np.clip((length - t) / 0.035, 0, 1)
    return lowpass(out * release, 1700 + 3300 * velocity) * (0.3 + 0.9 * velocity)


def marimba(note, velocity=0.6):
    """A marimba note: warm wood, the island colour."""
    out = sampled("vcsl-marimba", note, 1.2)
    return lowpass(out, 2500 + 5000 * velocity) * (0.25 + 0.8 * velocity)


_one_shots = {}


def one_shot(name):
    """A single recorded hit (hand drums) or the ocean bed, from assets/vcsl-percussion."""
    if name not in _one_shots:
        _one_shots[name] = _decode(ROOT / "assets" / "vcsl-percussion" / f"{name}.mp3")
    return _one_shots[name]


def pad(notes, length):
    """A warm, slow synth pad: detuned saws, softly filtered, breathing in and out."""
    n = int(length * SR)
    t = np.arange(n) / SR
    out = np.zeros(n)
    for note in notes:
        for detune in (-0.08, 0.0, 0.09):
            f = midi(note) * 2 ** (detune / 12)
            out += 2 * ((t * f + rng.random()) % 1.0) - 1
    out = lowpass(out / (3 * len(notes)), 1400, 2)
    shape = np.clip(t / 0.35, 0, 1) * np.clip((length - t) / 0.4, 0, 1)
    return out * shape


def peaking(x, hz, gain_db, q=1.0):
    """A bell EQ (RBJ cookbook): cut or boost around `hz`."""
    a = 10 ** (gain_db / 40)
    w = 2 * np.pi * hz / SR
    alpha = np.sin(w) / (2 * q)
    b = [1 + alpha * a, -2 * np.cos(w), 1 - alpha * a]
    den = [1 + alpha / a, -2 * np.cos(w), 1 - alpha / a]
    return lfilter(np.array(b) / den[0], np.array(den) / den[0], x)


def high_shelf(x, hz, gain_db):
    """Lift (or lower) everything above `hz`: the "air" on top."""
    a = 10 ** (gain_db / 40)
    w = 2 * np.pi * hz / SR
    alpha = np.sin(w) / 2 * np.sqrt(2)
    cw = np.cos(w)
    b = [a * ((a + 1) + (a - 1) * cw + 2 * np.sqrt(a) * alpha), -2 * a * ((a - 1) + (a + 1) * cw), a * ((a + 1) + (a - 1) * cw - 2 * np.sqrt(a) * alpha)]
    den = [(a + 1) - (a - 1) * cw + 2 * np.sqrt(a) * alpha, 2 * ((a - 1) - (a + 1) * cw), (a + 1) - (a - 1) * cw - 2 * np.sqrt(a) * alpha]
    return lfilter(np.array(b) / den[0], np.array(den) / den[0], x)


def tame(x, lo, hi, threshold, ratio=3.0):
    """A resonance tamer: only when the band lo–hi rings loud is it pulled down."""
    band = bandpass(x, lo, hi, 2)
    env_ = lowpass(np.abs(band), 30, 1)
    over = np.maximum(env_ / threshold, 1.0)
    reduce = over ** (1 / ratio - 1)  # gain < 1 only above the threshold
    return x - band + band * reduce


def widen(x, depth=0.004, rate=0.9):
    """Two slightly delayed, slowly wavering copies: wider and softer than one point of sound."""
    n = len(x)
    t = np.arange(n) / SR
    out = x.copy()
    for i, base in enumerate((0.011, 0.017)):
        d = (base + depth * np.sin(2 * np.pi * rate * t + i * 2.1)) * SR
        out += 0.45 * np.interp(np.arange(n) - d, np.arange(n), x, left=0)
    return out / 1.6


def bright_not_harsh(x):
    """Bright from harmonics and air, not from the 2–5 kHz the ear is sharpest to."""
    warm = np.tanh(2.2 * x) / np.tanh(2.2)  # gentle saturation: richer overtones
    y = 0.6 * x + 0.4 * warm
    y = tame(y, 900, 1700, threshold=0.05)  # hold back the ringing of long high notes
    y = peaking(y, 2800, -5, q=1.4)  # the ear's most sensitive band
    y = peaking(y, 4000, -3, q=1.2)
    y = high_shelf(y, 7500, 5)  # air: sparkle without bite
    return y


def echo(x, delay, feedback=0.35, repeats=3, tone=4500):
    """A soft echo: each repeat quieter and a little darker."""
    out = x.copy()
    step = int(delay * SR)
    tap = x
    for r in range(1, repeats + 1):
        tap = lowpass(tap, tone) * feedback
        shifted = np.zeros_like(x)
        shifted[step * r :] = tap[: len(x) - step * r]
        out += shifted
    return out


def lead(note, length, velocity=0.7):
    """The tune on a real soprano recorder: airy and bright, like a clear whistle."""
    out = sampled("vcsl-recorder", note, length + 0.12)
    t = np.arange(len(out)) / SR
    shape = np.clip(t / 0.012, 0, 1) * np.clip((length + 0.1 - t) / 0.08, 0, 1)
    return highpass(out * shape, 350) * velocity


def glock(note, velocity=0.6):
    """A real glockenspiel note: the sparkle on top."""
    out = sampled("vcsl-glockenspiel", note, 2.0)
    return out * (0.2 + 0.8 * velocity)


def strum(notes, length, velocity, up=False):
    """A strum across the strings: down from the low string, or up across the top ones."""
    order = sorted(notes)
    if up:
        order = order[-4:][::-1]
    gap = (0.007 if up else 0.011) * (1.25 - velocity * 0.5)
    out = np.zeros(int((length + gap * len(order)) * SR) + 1)
    for i, note in enumerate(order):
        v = velocity * (0.8 if up else 1.0) * (0.9 + 0.1 * rng.random())
        place(out, guitar(note, max(0.02, length - i * gap), v), i * gap)
    return out


def chuck(notes):
    """A muted strum: the strings slapped and stopped at once, a percussive "chk"."""
    n = int(0.06 * SR)
    t = np.arange(n) / SR
    body = np.zeros(n)
    for i, note in enumerate(sorted(notes)):
        place(body, guitar(note, 0.045, 0.5), i * 0.004, 0.35)
    slap = bandpass(rng.uniform(-1, 1, n), 700, 3500) * np.exp(-t / 0.012)
    return lowpass(body + 0.5 * slap, 3500)


def reverse_swell(notes, length):
    """The next chord strummed backwards: it swells up into the downbeat."""
    ring = np.zeros(int(length * 1.6 * SR))
    for note in sorted(notes):
        place(ring, guitar(note, length * 1.6, 0.55), 0)
    ring = ring[: int(length * SR)]
    return ring[::-1] * np.linspace(0, 1, len(ring)) ** 1.5


# ── Drums and texture ────────────────────────────────────────────────────────


def kick():
    n = int(0.5 * SR)
    t = np.arange(n) / SR
    f = midi(34) + 70 * np.exp(-t / 0.03)  # settles on B-flat, in key
    body = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.25)
    knock = lowpass(rng.uniform(-1, 1, n), 1200) * np.exp(-t / 0.006) * 0.25
    return lowpass(body + knock, 3000)


def snare():
    n = int(0.35 * SR)
    t = np.arange(n) / SR
    noise = bandpass(rng.uniform(-1, 1, n), 900, 5000) * np.exp(-t / 0.075)
    tone = np.sin(2 * np.pi * 185 * t) * np.exp(-t / 0.045)
    return lowpass(0.75 * noise + 0.45 * tone, 4500)


def rim():
    n = int(0.08 * SR)
    t = np.arange(n) / SR
    return bandpass(rng.uniform(-1, 1, n), 1500, 4500) * np.exp(-t / 0.012) + np.sin(2 * np.pi * 820 * t) * np.exp(-t / 0.01)


def hat(open_=False):
    n = int((0.22 if open_ else 0.05) * SR)
    t = np.arange(n) / SR
    return lowpass(highpass(rng.uniform(-1, 1, n), 6500, 4), 10000) * np.exp(-t / (0.08 if open_ else 0.014))


def sub(note, length):
    n = int(length * SR)
    t = np.arange(n) / SR
    f = midi(note)
    tone = np.sin(2 * np.pi * f * t) + 0.18 * np.sin(4 * np.pi * f * t)
    return tone * np.clip(t / 0.02, 0, 1) * np.clip((length - t) / 0.08, 0, 1) * np.exp(-t / (length * 0.9))


def low_hit(length=1.8):
    n = int(length * SR)
    t = np.arange(n) / SR
    boom = np.sin(2 * np.pi * (midi(29) + 30 * np.exp(-t / 0.06)) * t) * np.exp(-t / 0.45)  # F, in key
    air = lowpass(highpass(rng.uniform(-1, 1, n), 3000), 9000) * np.exp(-t / 0.5) * 0.12
    return boom + air


def whoosh(length):
    n = int(length * SR)
    t = np.arange(n) / SR
    noise = rng.uniform(-1, 1, n)
    out = np.zeros(n)
    hop = 512
    for i in range(0, n, hop):
        centre = 500 + 2600 * math.sin(math.pi * i / n)
        seg = noise[max(0, i - 2048) : i + hop]
        out[i : i + hop] = bandpass(seg, centre * 0.6, centre * 1.5)[-len(out[i : i + hop]) :]
    return out * np.sin(np.pi * np.clip(t / length, 0, 1)) ** 2


def pop():
    n = int(0.16 * SR)
    t = np.arange(n) / SR
    return np.sin(2 * np.pi * np.cumsum(260 + 600 * np.exp(-t / 0.02)) / SR) * np.exp(-t / 0.05)


def tap():
    n = int(0.05 * SR)
    t = np.arange(n) / SR
    return bandpass(rng.uniform(-1, 1, n), 1800, 5000) * np.exp(-t / 0.007)


def stamp():
    n = int(0.3 * SR)
    t = np.arange(n) / SR
    return np.sin(2 * np.pi * (65 + 50 * np.exp(-t / 0.02)) * t) * np.exp(-t / 0.08) + 0.5 * bandpass(
        rng.uniform(-1, 1, n), 300, 2500
    ) * np.exp(-t / 0.025)


def ding():
    out = np.zeros(int(1.6 * SR))
    place(out, guitar(74, 1.5, 0.6), 0)
    place(out, guitar(81, 1.4, 0.5), 0.1)
    return out


def crackle(n):
    """Vinyl: a soft hiss and scattered little pops."""
    hiss = lowpass(highpass(rng.normal(0, 1, n), 1500), 7000) * 0.012
    clicks = np.zeros(n)
    idx = rng.choice(n, size=int(n / SR * 9), replace=False)
    clicks[idx] = rng.uniform(0.15, 0.6, len(idx)) * rng.choice([-1, 1], len(idx))
    clicks = highpass(clicks, 2000) * 0.25
    return hiss + clicks


def room(length=2.4):
    """A soft room: decaying noise, darker as it fades."""
    n = int(length * SR)
    t = np.arange(n) / SR
    ir = rng.normal(0, 1, n) * np.exp(-t / 0.55)
    ir = lowpass(ir, 3500)
    ir[0] = 0
    return ir / np.sqrt(np.sum(ir**2))


def clap():
    n = int(0.3 * SR)
    t = np.arange(n) / SR
    burst = sum(
        np.roll(bandpass(rng.uniform(-1, 1, n), 900, 5000) * np.exp(-t / 0.012), int(d * SR)) for d in (0, 0.009, 0.019)
    )
    tail = bandpass(rng.uniform(-1, 1, n), 1000, 4000) * np.exp(-t / 0.09) * 0.4
    return lowpass(burst + tail, 6000)


def shaker():
    n = int(0.09 * SR)
    t = np.arange(n) / SR
    env_ = np.clip(t / 0.015, 0, 1) * np.exp(-t / 0.03)
    return lowpass(highpass(rng.uniform(-1, 1, n), 4000), 9000) * env_


def ebass(note, length):
    """A round finger-played electric bass: a little bite, then a warm body."""
    n = int(length * SR)
    t = np.arange(n) / SR
    f = midi(note)
    saw = 2 * ((t * f) % 1.0) - 1
    body = np.sin(2 * np.pi * f * t) * 0.8 + lowpass(saw, 900) * 0.5
    pluck_env = np.clip(t / 0.006, 0, 1) * (0.6 * np.exp(-t / 0.12) + 0.4 * np.exp(-t / 0.8))
    return lowpass(body * pluck_env * np.clip((length - t) / 0.05, 0, 1), 1600)


def tambourine():
    n = int(0.16 * SR)
    t = np.arange(n) / SR
    jingle = bandpass(rng.uniform(-1, 1, n), 5000, 11000) * (np.exp(-t / 0.05) + 0.4 * np.exp(-t / 0.012))
    return jingle


def riser(length):
    """Filtered noise sweeping up into a downbeat."""
    n = int(length * SR)
    noise = rng.uniform(-1, 1, n)
    out = np.zeros(n)
    hop = 1024
    for i in range(0, n, hop):
        centre = 500 * (12 ** (i / n))
        seg = noise[max(0, i - 4096) : i + hop]
        out[i : i + hop] = bandpass(seg, centre * 0.7, min(centre * 1.5, SR / 2 - 100))[-len(out[i : i + hop]) :]
    return out * (np.arange(n) / n) ** 2


# ── Song ─────────────────────────────────────────────────────────────────────
#
# A pop song first, the video second. The harmony is a fixed loop, one chord
# a bar, that scene changes never interrupt; the tune is written out note by
# note in four-bar phrases; the chorus is one short, rhythmic hook sung twice
# and brought home. The scenes that open the chorus, the dip and the end are
# placed on bar lines (timeline.json `onBar`), so the song's sections and the
# video's line up.

# (bass note, guitar shape low to high, chord tones, pad voicing)
EB = (39, [51, 58, 62, 67, 70], {3, 7, 10, 2}, [63, 67, 70, 74])  # Ebmaj7, x-6-8-7-8-6
F_ = (41, [41, 48, 53, 57, 60, 65], {5, 9, 0}, [60, 65, 69, 72])  # F, barre at 1
BB = (46, [46, 53, 58, 62, 65], {10, 2, 5}, [62, 65, 70, 74])  # B♭, A-shape barre at 1
GM = (43, [43, 50, 53, 58, 62, 67], {7, 10, 2, 5}, [62, 65, 70, 74])  # Gm7, barre at 3

# vi–IV–I–V, the most familiar backbone of house and tropical pop, one chord a bar.
LOOP = [GM, EB, BB, F_]
PRE_CHORDS = [EB, F_, GM, F_]  # IV–V–vi–V: the lift into the chorus
CHORUS_CHORDS = [GM, EB, BB, F_, GM, EB, BB]  # the loop twice, home on I

# The tune, note by note: (beat, MIDI note, beats long), one list per bar.
# Written to what makes pop tunes stick: a cell of two to five notes repeated
# close together with a small change, small steps and a simple outline, the
# major pentatonic (B♭ C D F G) for the tune over full chords, syncopation,
# the hook stated early and often, and a tropical leap now and then. Phrases
# fall from high to low.
#
# Verse: a pentatonic cell, "G F D", answered and repeated; sung twice.
VERSE = [
    [(0.5, 79, 0.5), (1, 77, 0.5), (1.5, 74, 1), (3, 77, 0.5), (3.5, 79, 0.5)],  # G F D … F G
    [(0, 79, 1), (1, 77, 0.5), (1.5, 74, 1.5)],  # G F D
    [(0.5, 82, 0.5), (1, 79, 0.5), (1.5, 77, 1), (3, 74, 0.5), (3.5, 77, 0.5)],  # B♭ G F … D F
    [(0, 79, 1), (1, 77, 1), (2, 72, 2)],  # G F C: a question
]
VERSE_LAST = [(0, 84, 1), (1, 81, 1), (2, 77, 2)]  # C A F, into the pre-chorus
# Pre-chorus: the hook's cell at half speed, a tease of what is coming.
PRE = [
    [(0, 86, 1), (1, 84, 2), (3, 82, 1)],  # D — C — B♭
    [(0, 84, 1), (1, 81, 2), (3, 77, 1)],  # C — A — F
    [(0, 86, 1), (1, 84, 2), (3, 82, 1)],  # D — C — B♭
    [(0, 89, 1), (1, 87, 1), (2, 86, 1), (3, 84, 1)],  # F E♭ D C: into the chorus
]
# Chorus: the hook cell "D–C–B♭", syncopated, twice in a bar (the second time
# its last note changes), a leap up and a fall, the cell again home to B♭ —
# then the whole two-bar phrase once more, and home.
HOOK = [
    [(0, 86, 0.5), (0.5, 84, 1), (1.5, 82, 0.5), (2, 86, 0.5), (2.5, 84, 1), (3.5, 79, 0.5)],  # D C B♭, D C G
    [(0, 82, 0.5), (0.5, 89, 1), (1.5, 87, 0.5), (2, 86, 2)],  # B♭ ↑F E♭ D
    [(0, 86, 0.5), (0.5, 84, 1), (1.5, 82, 0.5), (2, 86, 0.5), (2.5, 84, 1), (3.5, 82, 0.5)],  # D C B♭, D C B♭
    [(0, 84, 0.5), (0.5, 81, 1), (1.5, 77, 0.5), (2, 81, 2)],  # C A F A
    [(0, 86, 0.5), (0.5, 84, 1), (1.5, 82, 0.5), (2, 86, 0.5), (2.5, 84, 1), (3.5, 79, 0.5)],  # D C B♭, D C G
    [(0, 82, 0.5), (0.5, 89, 1), (1.5, 87, 0.5), (2, 86, 2)],  # B♭ ↑F E♭ D
    [(0, 86, 0.5), (0.5, 84, 1), (1.5, 82, 2.5)],  # D C B♭: home
]
DIP = [HOOK[0], [(0, 82, 3.5)]]  # the hook once more, softly

# Guitar on the eighths of a bar: D down, U up, C muted chuck, - rest.
STRUM = {"verseA": "D-UU-U-U", "verseB": "D-UU-UCU", "pre": "D-D-D-DU", "chorus": "D-CU-UCU"}
PICK = [0, 2, 3, 4, 2, 3, 4, 3]
MARIMBA = {"verseA": (0, 3), "verseB": (0, 3, 6), "pre": (0, 2, 4, 6), "chorus": (0, 3, 6)}


def compose(name):
    scenes, total_frames = flatten(TIMELINE[name])
    seconds = total_frames / OUTPUT_FPS
    n = int(seconds * SR) + 3 * SR
    gtr, tune, bells, mar, pads, low, drums, fx = (np.zeros(n) for _ in range(8))
    sec = lambda frames: frames / OUTPUT_FPS

    top = [s for s in scenes if not s["nested"]]
    find = lambda tag: next((s for s in top if s.get("music") == tag), None)
    drop = sec(find("drop")["start"]) if find("drop") else 0.0
    end = sec(find("end")["start"]) if find("end") else seconds
    chorus = sec(find("chorus")["start"]) if find("chorus") else end
    breakdown = sec(find("breakdown")["start"]) if find("breakdown") else end
    changes = sorted(sec(s["start"]) for s in scenes if s["turn"])

    bar_of = lambda t: math.floor((t - drop) / BAR + 1e-6)  # bar 0 is the verse's first bar
    chorus_bar, dip_bar, end_bar = bar_of(chorus), bar_of(breakdown), bar_of(end)
    pre_bar = chorus_bar - 4
    # The verse is sung over its last eight bars; any bar before that is the
    # band alone, under the cat's introduction.
    verse_bar = max(0, pre_bar - 8)

    def section_of(b):
        if b < 0:
            return "intro"
        if b >= end_bar:
            return "end"
        if b >= dip_bar:
            return "dip"
        if b >= chorus_bar:
            return "chorus"
        if b >= pre_bar:
            return "pre"
        return "verseA" if b < verse_bar + 4 else "verseB"

    section = lambda t: section_of(bar_of(t))

    def chords_of(b):
        part = section_of(b)
        if part == "intro":
            return EB
        if part == "chorus":
            i = b - chorus_bar
            # Past the written chorus, stay home on B♭ until the next section.
            return CHORUS_CHORDS[i] if i < len(CHORUS_CHORDS) else BB
        if part == "dip":
            return LOOP[(b - dip_bar) % 2]
        if part == "pre":
            return PRE_CHORDS[(b - pre_bar) % 4]
        if part == "end":
            return BB
        return LOOP[(b - verse_bar) % 4]

    # The chord grid: one chord a bar (two in a split bar), whatever the scenes do.
    first_bar = bar_of(0.0) - 1
    segments = []
    for b in range(first_bar, end_bar + 1):
        start, stop = drop + b * BAR, drop + (b + 1) * BAR
        if stop <= 0 or start >= end:
            continue
        chords = chords_of(b)
        if isinstance(chords[0], tuple):
            segments.append((max(0.0, start), start + BAR / 2, chords[0]))
            segments.append((start + BAR / 2, min(stop, end), chords[1]))
        else:
            segments.append((max(0.0, start), min(stop, end), chords))

    def chord_at(t):
        for a_, b_, ch in segments:
            if a_ - 1e-6 <= t < b_:
                return ch
        return BB

    eighth = BEAT / 2

    # ── Guitar, marimba, pad and bass, bar by bar ──
    for start, stop, chord in segments:
        bass_note, shape, tones, voicing = chord
        part = section(start + 0.01)
        length = stop - start
        slots = []
        k = math.ceil(round((start - drop) / eighth, 6))
        while drop + k * eighth < stop - 0.02:
            slots.append((drop + k * eighth + (SWING * BEAT if k % 2 else 0), k % 8))
            k += 1
        place(pads, pad(voicing, length + 0.3), start, {"intro": 0.5, "dip": 0.6, "chorus": 0.12}.get(part, 0.42))
        if part in STRUM:
            pattern = STRUM[part]
            hits = [(at, pattern[idx]) for at, idx in slots if pattern[idx] != "-"]
            if slots and (not hits or hits[0][0] > slots[0][0]):
                hits.insert(0, (slots[0][0], "D"))
            loud = {"verseA": 0.5, "verseB": 0.56, "pre": 0.62, "chorus": 0.66}[part]
            for j, (at, kind) in enumerate(hits):
                nxt = hits[j + 1][0] if j + 1 < len(hits) else stop
                if kind == "C":
                    place(gtr, chuck(shape), at, 0.8)
                else:
                    place(gtr, strum(shape, min(nxt - at, BEAT) + 0.01, loud * (1.0 if kind == "D" else 0.75), up=kind == "U"), at)
            for at, idx in slots:
                if idx in MARIMBA[part] and part != "chorus":  # in the chorus the marimba plays the hook
                    for note in voicing[1:]:
                        place(mar, marimba(note, 0.5), at, 0.5)
        elif part != "end":
            for at, idx in slots:
                place(gtr, guitar(shape[PICK[idx] % len(shape)], eighth * 2.2, 0.45), at, 0.75 if part == "intro" else 0.6)
        if part == "verseA":
            for beat, step, beats in ((0, 0, 1.2), (2, 0, 0.9), (3.5, 12, 0.4)):
                if start + beat * BEAT < stop - 0.05:
                    place(low, ebass(bass_note + step, beats * BEAT), start + beat * BEAT, 0.72)
        elif part in ("verseB", "pre"):
            for beat, step, beats in ((0, 0, 1.2), (1.5, 0, 0.4), (2, 7, 0.9), (3.5, 12, 0.4)):
                if start + beat * BEAT < stop - 0.05:
                    place(low, ebass(bass_note + step, beats * BEAT), start + beat * BEAT, 0.8)
        elif part == "chorus":
            for beat, step, beats in ((0, 0, 0.9), (1, 12, 0.4), (1.5, 0, 0.4), (2, 7, 0.9), (3, 12, 0.4), (3.5, 10, 0.4)):
                if start + beat * BEAT < stop - 0.05:
                    place(low, ebass(bass_note + step, beats * BEAT), start + beat * BEAT, 0.8)
        elif part == "dip":
            place(low, ebass(bass_note, length), start, 0.35)

    # ── The tune, bar by bar ──
    def tune_of(b):
        part = section_of(b)
        if part in ("verseA", "verseB"):
            v = b - verse_bar
            if v < 0:
                return []  # the band alone, under the cat's introduction
            return VERSE_LAST if v == 7 else VERSE[v % 4]
        if part == "pre":
            return PRE[(b - pre_bar) % 4]
        if part == "chorus":
            i = b - chorus_bar
            return HOOK[i] if i < len(HOOK) else []  # the last B♭ rings on
        if part == "dip":
            return DIP[(b - dip_bar) % len(DIP)]
        return []

    vel = {"verseA": 0.55, "verseB": 0.58, "pre": 0.62, "chorus": 0.7, "dip": 0.42}
    for b in range(0, end_bar):
        part = section_of(b)
        bar_start = drop + b * BAR
        for beat, note, beats in tune_of(b):
            at = bar_start + beat * BEAT
            # Short notes are played short and bouncy; long notes sing.
            hold = beats * BEAT * (0.62 if beats <= 0.5 else 0.92)
            place(tune, lead(note, hold, vel[part]), at)
            if part == "chorus":  # the marimba takes the hook too, an octave down
                place(mar, marimba(note - 12, 0.62), at, 0.8)
        # Sunshine: a glockenspiel glint on each chorus downbeat.
        if part == "chorus":
            place(bells, glock(chord_at(bar_start)[3][-1], 0.35), bar_start, 0.3)
        # A quick marimba run up at the end of every four bars: a little lift.
        if part in ("verseB", "chorus", "pre") and ((b - verse_bar) % 4 == 3 or (part == "chorus" and b - chorus_bar >= len(HOOK))):
            tones = sorted(chord_at(bar_start + 3 * BEAT)[3])
            for i, note in enumerate(tones):
                place(mar, marimba(note - 12, 0.55), bar_start + (3 + i / 4) * BEAT, 0.6)
        # Marimba answers the hook where it holds its long note.
        if part == "chorus" and (b - chorus_bar) in (1, 3):
            tones = chord_at(bar_start + 2.5 * BEAT)[3]
            for i, at_beat in enumerate((2.5, 3, 3.5)):
                place(mar, marimba(tones[-1 - i], 0.6), bar_start + at_beat * BEAT, 0.7)

    # Intro: the hook first heard on marimba, so the chorus feels like coming home.
    intro_bar = drop - BAR
    for beat, note, beats in HOOK[0]:
        at = intro_bar + beat * BEAT
        if at >= 0:
            place(mar, marimba(note - 12, 0.55), at, 0.85)

    # ── Drums and hand drums ──
    kicks = []
    conga, quinto, tumba = one_shot("conga"), one_shot("quinto"), one_shot("tumba")
    bongo_hi, bongo_lo = one_shot("bongo-high"), one_shot("bongo-low")
    pre_start = drop + pre_bar * BAR
    for b in range(first_bar, end_bar):
        bar_start = drop + b * BAR
        for step in range(16):
            at = bar_start + step / 4 * BEAT + (SWING * BEAT if step % 4 == 2 else 0)
            if at < 0 or at >= end:
                continue
            part = section(at)
            if any(c - BEAT * 0.5 - 0.01 <= at < c - 0.01 for c in changes):
                continue  # the drums drop out for the half beat before every scene change
            if part == "verseA":
                if step in (0, 8):
                    place(drums, kick(), at, 0.75)
                    kicks.append(at)
                if step in (4, 12):
                    place(drums, clap(), at, 0.28)
                if step % 4 == 2:
                    place(drums, shaker(), at, 0.11)
                if step == 14:
                    place(drums, conga, at, 0.3)
            elif part in ("verseB", "chorus"):
                if step % 4 == 0:
                    place(drums, kick(), at, 0.8 if part == "verseB" else 0.9)
                    kicks.append(at)
                if step in (4, 12):
                    place(drums, clap(), at, 0.4 if part == "verseB" else 0.5)
                if step % 2 == 0:
                    place(drums, shaker(), at, 0.12 if step % 4 == 2 else 0.07)
                if step in (6, 14):
                    place(drums, conga, at, 0.32)
                if step == 10:
                    place(drums, tumba, at, 0.35)
                if step in (3, 11) and part == "chorus":
                    place(drums, quinto, at, 0.22)
                if step in (1, 5, 9, 13):
                    place(drums, bongo_hi, at, 0.1 if part == "verseB" else 0.14)
                if step == 15 and part == "chorus":
                    place(drums, bongo_lo, at, 0.18)
                if part == "chorus" and step % 2 == 1:
                    place(drums, tambourine(), at, 0.05)
                if step % 4 == 2:  # the off-beat "tss" that makes it skip along
                    place(drums, hat(True), at, 0.06 if part == "verseB" else 0.08)
            elif part == "pre":
                last_bar = at >= chorus - BAR
                every = 1 if last_bar and at >= chorus - BAR / 2 else (2 if last_bar else 4)
                if step % every == 0:
                    place(drums, clap(), at, 0.2 + 0.25 * (at - pre_start) / max(0.1, chorus - pre_start))
                if step % 2 == 0:
                    place(drums, shaker(), at, 0.1)
                if step in (6, 14):
                    place(drums, conga, at, 0.3)
            elif part == "dip" and step % 4 == 2:
                place(drums, shaker(), at, 0.05)
    if pre_start < chorus:
        place(fx, riser(chorus - pre_start), pre_start, 0.2)

    # ── The beach: waves under the intro, the dip and the end ──
    ocean = one_shot("ocean")
    for a_, b_ in ((0.0, drop + BAR), (breakdown, seconds)):
        if b_ > a_:
            m = int((b_ - a_) * SR)
            ramp = np.arange(m) / SR
            bed = np.resize(ocean, m) * np.clip(ramp / 1.5, 0, 1) * np.clip((m / SR - ramp) / 1.5, 0, 1)
            place(fx, lowpass(bed, 5000), a_, 0.35)

    # ── Every scene change: a reversed strum swells in, the kick and a low hit land ──
    for s in scenes:
        if not s["turn"]:
            continue
        at = sec(s["start"])
        place(gtr, reverse_swell(chord_at(at + 0.01)[1], BEAT), at - BEAT, 0.3)
        place(drums, kick(), at, 0.9)
        kicks.append(at)
        place(fx, low_hit(1.4), at, 0.38 if s.get("music") in ("drop", "chorus", "end") else 0.22)
        kind = s.get("enter")
        if kind in ("push", "zoom", "pull"):
            place(fx, whoosh(sec(s["turn"]) * 1.2), at - 0.05, 0.1)
        elif kind == "circle":
            place(fx, pop(), at, 0.2)
        for accent in s.get("accents", []):
            when = at + sec(js_round(accent["at"] * FRAME_SCALE))
            sound = {"stamp": stamp, "tap": tap, "ding": ding}[accent["sfx"]]()
            place(fx, sound, when, {"stamp": 0.4, "tap": 0.14, "ding": 0.2}[accent["sfx"]])
    for s in scenes:
        if not s["turn"] and not s["nested"]:
            for accent in s.get("accents", []):
                when = sec(s["start"]) + sec(js_round(accent["at"] * FRAME_SCALE))
                place(fx, {"stamp": stamp, "tap": tap, "ding": ding}[accent["sfx"]](), when, 0.3)

    # ── The end: the hook's last phrase, home on B♭, ringing out ──
    if end < seconds:
        ring = np.zeros(int(3.5 * SR))
        for i, note in enumerate([46, 53, 58, 62, 65, 70]):
            place(ring, guitar(note, 3.0, 0.6), i * 0.035)
        place(gtr, ring, end, 1.2)
        place(pads, pad(BB[3], seconds - end + 0.5), end, 0.5)
        for beat, note, beats in HOOK[4][:3]:
            place(tune, lead(note, beats * BEAT * 0.92, 0.55), end + beat * BEAT, 0.9)
        place(tune, lead(82, 2.0, 0.55), end + 2 * BEAT, 0.9)
        for i, note in enumerate((82, 86, 89, 94)):
            place(bells, glock(note, 0.45), end + 2 * BEAT + i * eighth, 0.45)
        place(low, ebass(34, min(3.0, seconds - end + 0.5)), end, 0.5)

    level = {"intro": 0.62, "verseA": 0.74, "verseB": 0.82, "pre": 0.86, "chorus": 1.0, "dip": 0.45, "end": 0.85}
    times = np.arange(n) / SR
    gain = np.array([level[section(x)] for x in np.arange(0, n / SR, 0.01)])
    gain = np.interp(times, np.arange(len(gain)) * 0.01, np.convolve(gain, np.ones(25) / 25, mode="same"))

    duck = np.ones(n)
    for k in kicks:
        i = int(k * SR)
        m = min(n - i, int(0.32 * SR))
        if m > 0:
            duck[i : i + m] = np.minimum(duck[i : i + m], 1 - 0.38 * np.exp(-np.arange(m) / SR / 0.1))

    ir = room(2.2)
    tune = widen(bright_not_harsh(tune))
    bells = peaking(lowpass(bells, 6500), 2800, -6, q=1.2)
    tune_echo = echo(tune, 0.75 * BEAT, feedback=0.22, repeats=2, tone=3200)
    sources = gtr * 0.7 + mar * 0.65 + pads * 0.42 + tune_echo * 0.95 + bells * 0.4
    wet = fftconvolve(gtr * 0.12 + mar * 0.25 + pads * 0.3 + tune_echo * 0.3 + bells * 0.35, ir)[:n]
    # The tune is the backbone: it is not pumped by the kick, it sits on top.
    mix = ((sources - tune_echo * 0.95 + wet) * duck + tune_echo * 0.95 + low * duck + drums + fftconvolve(drums, ir)[:n] * 0.08) * gain + fx
    if drop > 0:
        i = int(drop * SR)
        mix[:i] = lowpass(mix[:i], 5000)
    mix = lowpass(mix, 12000)

    mix = mix[: int(seconds * SR)]
    t = np.arange(len(mix)) / SR
    mix *= np.clip((seconds - t) / 1.5, 0, 1)
    mix = np.tanh(1.2 * mix / (np.max(np.abs(mix)) + 1e-9)) * 0.89 / np.tanh(1.2)
    right = 0.8 * mix + 0.2 * np.roll(lowpass(mix, 6000), int(0.013 * SR))
    return np.stack([mix, right], axis=1), scenes, seconds


def write_mp3(stereo, path):
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(suffix=".wav") as tmp:
        with wave.open(tmp.name, "wb") as w:
            w.setnchannels(2)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes((np.clip(stereo, -1, 1) * 32767).astype("<i2").tobytes())
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", tmp.name, "-b:a", "192k", str(path)], check=True)


def main():
    for name in sys.argv[1:] or ["full"]:
        stereo, scenes, seconds = compose(name)
        out = ROOT / "public" / "audio" / f"{name}.mp3"
        write_mp3(stereo, out)
        changes = ", ".join(f"{s['id']}@{s['start'] / BEAT_FRAMES:g}" for s in scenes if s["turn"])
        print(f"{name}: {seconds:.2f}s, {seconds / BEAT:g} beats at {BPM} bpm -> {out.relative_to(ROOT)}")
        print(f"  scene changes on beats: {changes}")


if __name__ == "__main__":
    main()
