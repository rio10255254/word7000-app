#!/usr/bin/env python3
"""Compose the promo soundtracks from src/timeline.json.

A sweet, bouncy pop piece in the manner of a rom-com drama OST, written to
the feel of the reference the owner chose (about 118 bpm, B-flat major,
warm and soft-drummed, straight eighths), with its own original tune and
chords: a strummed acoustic guitar (University of Iowa samples, free for any
use; see assets/iowa-guitar/CREDITS.md) on Ebmaj7 → F → Gm7 → B♭ in real
guitar shapes, tight pop strumming with muted chucks on 2 and 4 and each
strum damped as the next comes in, fingerpicking in the soft parts, the tune
on single strings, a round electric bass, a soft kick, claps and a shaker,
and a small room.

The energy follows the reference's arc: a gentle intro, a verse from the
cat's introduction, a fuller chorus with a counter-melody from the
`chorus` scene, a quiet dip at the lock screen, and a warm ending.

Scene changes are the rhythm of the piece. The scenes are laid out exactly
as src/transitions.tsx lays them out, so every transition starts on a
strong beat, and at each one:
  - the drums drop out for the half beat before it,
  - a reversed strum swells into it,
  - the kick and a low hit land on it, and the guitar moves to a new chord.

Writes public/audio/full.mp3 and public/audio/teaser.mp3.
Needs numpy, scipy and ffmpeg.
"""
import json
import math
import subprocess
import sys
import tempfile
import wave
from pathlib import Path

import numpy as np
from scipy.signal import butter, fftconvolve, sosfilt

ROOT = Path(__file__).resolve().parent.parent
TIMELINE = json.loads((ROOT / "src" / "timeline.json").read_text())

SR = 44100
OUTPUT_FPS = 60
FRAME_SCALE = 1.2 * (60 / 30)  # time.ts: SPEED × OUTPUT_FPS / AUTHORED_FPS
BPM = TIMELINE["bpm"]
HOLD = TIMELINE["hold"]
BEAT_FRAMES = round(OUTPUT_FPS * 60 / BPM)
GRID = TIMELINE.get("quantizeBeats", 1) * BEAT_FRAMES
BEAT = BEAT_FRAMES / OUTPUT_FPS  # seconds
BAR = BEAT * 4
SWING = 0.0  # straight eighths, like the reference
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


# ── Guitar: University of Iowa acoustic guitar samples (free for any use) ────

SAMPLES = ROOT / "assets" / "iowa-guitar"
NAMES = {"C": 0, "Cs": 1, "D": 2, "Ds": 3, "E": 4, "F": 5, "Fs": 6, "G": 7, "Gs": 8, "A": 9, "As": 10, "B": 11}
_sample_cache = {}


def _decode(path):
    raw = subprocess.run(
        ["ffmpeg", "-v", "error", "-i", str(path), "-f", "s16le", "-ac", "1", "-ar", str(SR), "-"],
        capture_output=True,
        check=True,
    ).stdout
    return np.frombuffer(raw, dtype="<i2").astype(np.float64) / 32768


def _samples():
    if not _sample_cache:
        for f in SAMPLES.glob("*.mp3"):
            name, octave = f.stem.rstrip("0123456789"), int(f.stem[len(f.stem.rstrip("0123456789")) :])
            note = 12 * (octave + 1) + NAMES[name]
            audio = _decode(f)
            onset = int(np.argmax(np.abs(audio) > 0.02 * np.max(np.abs(audio))))
            audio = audio[max(0, onset - 16) :]
            _sample_cache[note] = audio / (np.max(np.abs(audio)) + 1e-9)
    return _sample_cache


def guitar(note, length=1.0, velocity=0.6):
    """One string: the nearest recorded note, repitched, stopped cleanly at `length`."""
    bank = _samples()
    source = min(bank, key=lambda k: abs(k - note))
    ratio = 2 ** ((note - source) / 12)
    src = bank[source]
    n = min(int(length * SR), int(len(src) / ratio) - 1)
    t = np.arange(n) / SR
    out = np.interp(np.arange(n) * ratio, np.arange(len(src)), src)
    # The string is damped quickly when the next strum comes: that keeps it tight.
    release = np.clip((length - t) / 0.035, 0, 1)
    return lowpass(out * release, 1700 + 3300 * velocity) * (0.3 + 0.9 * velocity)


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


# ── Song ─────────────────────────────────────────────────────────────────────

# Ebmaj7 → F → Gm7 → B♭ (IV–V–vi–I in B-flat), voiced as real guitar shapes:
# (bass note, strings low to high).
CHORDS = [
    (39, [51, 58, 62, 67, 70]),  # Ebmaj7, x-6-8-7-8-6
    (41, [41, 48, 53, 57, 60, 65]),  # F, barre at 1
    (43, [43, 50, 53, 58, 62, 67]),  # Gm7, barre at 3
    (46, [46, 53, 58, 62, 65]),  # B♭, A-shape barre at 1
]
# Strumming on the eighths of a bar: D down, U up, C muted chuck, - rest.
VERSE = "D-CU-UCU"
CHORUS = "D-CUDUCU"
# Fingerpicked eighths for the intro and the lock-screen dip (string indices).
PICK = [0, 2, 3, 4, 2, 3, 4, 3]
# An original, bouncy four-bar tune in B-flat, played on single strings: (bar, beat, note, beats).
TUNE = [
    (0, 0, 67, 0.5), (0, 0.5, 65, 0.5), (0, 1, 63, 1), (0, 2.5, 62, 0.5), (0, 3, 63, 1),
    (1, 0, 65, 1.5), (1, 1.5, 60, 0.5), (1, 2, 65, 1), (1, 3, 69, 1),
    (2, 0, 70, 0.5), (2, 0.5, 69, 0.5), (2, 1, 65, 1), (2, 2.5, 62, 0.5), (2, 3, 65, 1),
    (3, 0, 67, 2), (3, 2.5, 70, 0.5), (3, 3, 72, 1),
]


def compose(name):
    scenes, total_frames = flatten(TIMELINE[name])
    seconds = total_frames / OUTPUT_FPS
    n = int(seconds * SR) + 3 * SR
    keys, low, drums, fx = np.zeros(n), np.zeros(n), np.zeros(n), np.zeros(n)
    sec = lambda frames: frames / OUTPUT_FPS

    top = [s for s in scenes if not s["nested"]]
    find = lambda tag: next((s for s in top if s.get("music") == tag), None)
    drop = sec(find("drop")["start"]) if find("drop") else 0.0
    chorus = sec(find("chorus")["start"]) if find("chorus") else None
    breakdown = sec(find("breakdown")["start"]) if find("breakdown") else None
    end = sec(find("end")["start"]) if find("end") else seconds
    changes = sorted(sec(s["start"]) for s in scenes if s["turn"])

    def section(t):
        if t < drop:
            return "intro"
        if t >= end:
            return "end"
        if breakdown is not None and t >= breakdown:
            return "dip"
        if chorus is not None and t >= chorus:
            return "chorus"
        return "verse"

    # The harmony moves at every bar line and at every scene change, so each
    # new scene arrives on a new chord. Bar lines put the drop on a downbeat.
    phase = drop % BAR
    bar_lines = [phase + k * BAR for k in range(-1, int(seconds / BAR) + 2)]
    marks = sorted({round(x, 4) for x in [0.0] + [b for b in bar_lines if 0 < b < end] + [c for c in changes if c < end]})
    segments = []
    for i, start in enumerate(marks):
        stop = marks[i + 1] if i + 1 < len(marks) else end
        if stop - start > 0.05:
            segments.append((start, stop, i % len(CHORDS)))

    eighth = BEAT / 2
    for start, stop, ci in segments:
        bass_note, shape = CHORDS[ci]
        part = section(start)
        length = stop - start
        # Eighth-note slots on the bar grid inside this chord.
        slots = []
        k = math.ceil(round((start - phase) / eighth, 6))
        while phase + k * eighth < stop - 0.02:
            slots.append((phase + k * eighth, k % 8))
            k += 1
        if part in ("verse", "chorus"):
            pattern = VERSE if part == "verse" else CHORUS
            hits = [(at, pattern[idx]) for at, idx in slots if pattern[idx] != "-"]
            # A chord always starts with a down-strum on its first slot.
            if slots and (not hits or hits[0][0] > slots[0][0]):
                hits.insert(0, (slots[0][0], "D"))
            elif hits:
                hits[0] = (hits[0][0], "D")
            loud = 0.75 if part == "chorus" else 0.62
            for j, (at, kind) in enumerate(hits):
                nxt = hits[j + 1][0] if j + 1 < len(hits) else stop
                if kind == "C":
                    place(keys, chuck(shape), at, 0.9)
                else:
                    accent = loud * (1.0 if kind == "D" else 0.78)
                    place(keys, strum(shape, nxt - at + 0.01, accent, up=kind == "U"), at, 1.0)
        else:
            # Intro and dip: fingerpicked, each note ringing to the next.
            for j, (at, idx) in enumerate(slots):
                note = shape[PICK[idx] % len(shape)]
                place(keys, guitar(note, eighth * 2.2, 0.48), at, 0.9 if part == "intro" else 0.7)
        # Bass: root on 1, a skip on the "and" of 2, the fifth on 3, a pickup on 4-and.
        if part in ("verse", "chorus"):
            for beat, step, beats in ((0, 0, 1.2), (1.5, 0, 0.4), (2, 7, 0.9), (3.5, 12, 0.4)):
                at = start + beat * BEAT
                if at < stop - 0.05:
                    place(low, ebass(bass_note + step, beats * BEAT), at, 0.8)
        elif part == "dip":
            place(low, ebass(bass_note, length), start, 0.4)

    # The tune on single strings, in verse, chorus and dip.
    for k, bar_start in enumerate(bar_lines):
        part = section(bar_start)
        if part not in ("verse", "chorus", "dip"):
            continue
        phrase_bar = (k - 1) % 4
        for b, beat, note, beats in TUNE:
            at = bar_start + beat * BEAT
            if b == phrase_bar and at < end and not any(abs(at - c) < BEAT * 0.5 for c in changes):
                place(keys, guitar(note, beats * BEAT + 0.08, 0.7), at, 1.25 if part != "dip" else 0.85)

    # Drums: soft kick on 1 and 3, claps on 2 and 4, a steady eighth-note shaker.
    kicks = []
    for k, bar_start in enumerate(bar_lines):
        for step in range(16):
            beat = step / 4
            at = bar_start + beat * BEAT
            if at < 0 or at >= end:
                continue
            part = section(at)
            # Drop out for the half beat before every scene change.
            if any(c - BEAT * 0.5 - 0.01 <= at < c - 0.01 for c in changes):
                continue
            if part in ("verse", "chorus"):
                if step in (0, 8) or (part == "chorus" and step == 14):
                    place(drums, kick(), at, 0.95)
                    kicks.append(at)
                if step in (4, 12):
                    place(drums, clap(), at, 0.58 if part == "chorus" else 0.46)
                if step % 2 == 0:
                    place(drums, shaker(), at, 0.15 if step % 4 == 2 else 0.1)
            elif part == "dip" and step % 4 == 0:
                place(drums, shaker(), at, 0.05)

    # Every scene change: a reversed strum swells in, then the kick and a low hit land.
    for s in scenes:
        if not s["turn"]:
            continue
        at = sec(s["start"])
        nxt = next((ci for a, _, ci in segments if abs(a - at) < 0.01), 0)
        place(keys, reverse_swell(CHORDS[nxt][1], BEAT), at - BEAT, 0.35)
        place(drums, kick(), at, 0.9)
        kicks.append(at)
        place(fx, low_hit(1.4), at, 0.4 if s.get("music") in ("drop", "chorus", "end") else 0.26)
        kind = s.get("enter")
        if kind in ("push", "zoom", "pull"):
            place(fx, whoosh(sec(s["turn"]) * 1.2), at - 0.05, 0.12)
        elif kind == "circle":
            place(fx, pop(), at, 0.22)
        for accent in s.get("accents", []):
            when = at + sec(js_round(accent["at"] * FRAME_SCALE))
            sound = {"stamp": stamp, "tap": tap, "ding": ding}[accent["sfx"]]()
            place(fx, sound, when, {"stamp": 0.4, "tap": 0.14, "ding": 0.25}[accent["sfx"]])
    for s in scenes:
        if not s["turn"] and not s["nested"]:
            for accent in s.get("accents", []):
                when = sec(s["start"]) + sec(js_round(accent["at"] * FRAME_SCALE))
                place(fx, {"stamp": stamp, "tap": tap, "ding": ding}[accent["sfx"]](), when, 0.3)

    # The energy arc of the reference: soft intro, steady verse, a lift in the
    # chorus, a clear dip at the lock screen, and a warm landing.
    level = {"intro": 0.62, "verse": 0.8, "chorus": 1.0, "dip": 0.42, "end": 0.85}
    times = np.arange(n) / SR
    gain = np.array([level[section(x)] for x in np.arange(0, n / SR, 0.01)])
    gain = np.interp(times, np.arange(len(gain)) * 0.01, np.convolve(gain, np.ones(25) / 25, mode="same"))

    # The end: one slow, ringing B♭ strum, and a last high note.
    if end < seconds:
        ring = np.zeros(int(3.5 * SR))
        for i, note in enumerate([46, 53, 58, 62, 65, 72]):
            place(ring, guitar(note, 3.0, 0.6), i * 0.03)
        place(keys, ring, end, 1.2)
        place(keys, guitar(74, 2.0, 0.55), end + BEAT, 1.0)
        place(low, ebass(34, min(3.0, seconds - end + 0.5)), end, 0.5)

    # Guitar and bass ease under each kick: a light pump.
    duck = np.ones(n)
    for k in kicks:
        i = int(k * SR)
        m = min(n - i, int(0.25 * SR))
        if m > 0:
            duck[i : i + m] = np.minimum(duck[i : i + m], 1 - 0.18 * np.exp(-np.arange(m) / SR / 0.08))

    ir = room(1.2)
    keys_wet = fftconvolve(keys, ir)[:n]
    mix = ((keys * 0.9 + keys_wet * 0.16) * duck + low * duck + drums + fftconvolve(drums, ir)[:n] * 0.06) * gain + fx
    if drop > 0:
        i = int(drop * SR)
        mix[:i] = lowpass(mix[:i], 4500)
    mix = lowpass(mix, 7000)  # warm, like the reference: little air on top

    mix = mix[: int(seconds * SR)]
    t = np.arange(len(mix)) / SR
    mix *= np.clip((seconds - t) / 1.2, 0, 1)
    mix = np.tanh(1.2 * mix / (np.max(np.abs(mix)) + 1e-9)) * 0.89 / np.tanh(1.2)
    right = 0.82 * mix + 0.18 * np.roll(lowpass(mix, 6000), int(0.012 * SR))
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
    for name in sys.argv[1:] or ["full", "teaser"]:
        stereo, scenes, seconds = compose(name)
        out = ROOT / "public" / "audio" / f"{name}.mp3"
        write_mp3(stereo, out)
        changes = ", ".join(f"{s['id']}@{s['start'] / BEAT_FRAMES:g}" for s in scenes if s["turn"])
        print(f"{name}: {seconds:.2f}s, {seconds / BEAT:g} beats at {BPM} bpm -> {out.relative_to(ROOT)}")
        print(f"  scene changes on beats: {changes}")


if __name__ == "__main__":
    main()
