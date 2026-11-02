#!/usr/bin/env python3
"""Compose the promo soundtracks from src/timeline.json.

A sweet, bouncy pop piece in the manner of a rom-com drama OST, written to
the feel of the reference the owner chose (about 118 bpm, B-flat major,
warm and soft-drummed, straight eighths), with its own original tune and
chords: a real grand piano (Salamander Grand Piano V3 samples by Alexander
Holm, CC BY 3.0; see assets/salamander/CREDITS.md) comping in eighths on
Ebmaj7 → F → Gm7 → B♭, a round electric bass, a soft kick, claps and a
shaker, and a light room.

The energy follows the reference's arc: a gentle intro, a verse from the
cat's introduction, a fuller chorus with a counter-melody from the
`chorus` scene, a quiet dip at the lock screen, and a warm ending.

Scene changes are the rhythm of the piece. The scenes are laid out exactly
as src/transitions.tsx lays them out, so every transition starts on a
strong beat, and at each one:
  - the drums drop out for the half beat before it,
  - a reversed piano chord swells into it,
  - the kick and a low hit land on it, and the piano moves to a new chord.

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


# ── Piano: Salamander Grand Piano V3 samples (Alexander Holm, CC BY 3.0) ─────

SAMPLES = ROOT / "assets" / "salamander"
NAMES = {"C": 0, "Ds": 3, "Fs": 6, "A": 9}
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
            name, octave = f.stem.rstrip("0123456789"), int(f.stem.lstrip("ACDFGs"))
            note = 12 * (octave + 1) + NAMES[name]
            audio = _decode(f)
            onset = int(np.argmax(np.abs(audio) > 0.01 * np.max(np.abs(audio))))
            _sample_cache[note] = audio[max(0, onset - 32) :]
    return _sample_cache


def piano(note, length=3.0, velocity=0.6):
    """The nearest recorded note, repitched, with a damper at the end and a lo-fi tone."""
    bank = _samples()
    source = min(bank, key=lambda k: abs(k - note))
    ratio = 2 ** ((note - source) / 12)
    src = bank[source]
    n = min(int(length * SR), int(len(src) / ratio) - 1)
    t = np.arange(n) / SR
    pos = np.arange(n) * ratio
    out = np.interp(pos, np.arange(len(src)), src)
    release = np.clip((length - t) / 0.3, 0, 1)
    # Softer playing is quieter and darker, like a lighter touch on the keys.
    tone = lowpass(out * release, 1800 + 4200 * velocity)
    return tone * (0.35 + 0.9 * velocity) * 3.0


def chord(notes, length, velocity, roll=0.018):
    """A rolled chord: the notes come in one after another, bottom up."""
    n = int((length + roll * len(notes)) * SR)
    out = np.zeros(n)
    for i, note in enumerate(sorted(notes)):
        v = velocity * (0.85 if i == 0 else 0.7)
        place(out, piano(note, length, v), i * roll)
    return out


def reverse_swell(notes, length):
    """The next chord played backwards: it swells up into the downbeat."""
    tail = chord(notes, length * 1.6, 0.55, roll=0.0)
    tail = tail[: int(length * SR)]
    swell = tail[::-1] * np.linspace(0, 1, len(tail)) ** 1.5
    return swell


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
    return piano(96, 2.0, 0.5) + piano(91, 2.0, 0.4)


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

# Ebmaj7 → F → Gm7 → B♭ (IV–V–vi–I in B-flat): (bass note, piano voicing).
CHORDS = [
    (39, [51, 62, 65, 67, 70]),  # Ebmaj7: Eb3 D4 F4 G4 Bb4
    (41, [53, 60, 65, 69, 72]),  # F: F3 C4 F4 A4 C5
    (43, [55, 62, 65, 70, 74]),  # Gm7: G3 D4 F4 Bb4 D5
    (46, [58, 62, 65, 70, 72]),  # B♭(add9): Bb3 D4 F4 Bb4 C5
]
# An original, bouncy four-bar tune in B-flat: (bar, beat, note, beats).
TUNE = [
    (0, 0, 79, 0.5), (0, 0.5, 77, 0.5), (0, 1, 75, 1), (0, 2.5, 74, 0.5), (0, 3, 75, 1),
    (1, 0, 77, 1.5), (1, 1.5, 72, 0.5), (1, 2, 77, 1), (1, 3, 81, 1),
    (2, 0, 82, 0.5), (2, 0.5, 81, 0.5), (2, 1, 77, 1), (2, 2.5, 74, 0.5), (2, 3, 77, 1),
    (3, 0, 79, 2), (3, 2.5, 82, 0.5), (3, 3, 84, 1),
]
# A chorus counter-line, an octave up, sparse: (bar, beat, note, beats).
COUNTER = [(0, 1.5, 87, 1), (1, 1.5, 89, 1), (2, 1.5, 89, 1), (3, 1.5, 91, 1.5)]


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
    groove_end = breakdown if breakdown is not None else end
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

    for start, stop, ci in segments:
        bass_note, voicing = CHORDS[ci]
        part = section(start)
        length = stop - start
        # Piano: a rolled chord on the change, then bouncy eighth-note comping.
        place(keys, chord(voicing, min(length, BAR) + 0.4, 0.55 if part == "intro" else 0.62), start)
        if part in ("verse", "chorus"):
            # Off-beat stabs in the verse; fuller, busier comping in the chorus.
            hits = (1.5, 2.5, 3.5) if part == "verse" else (1, 1.5, 2.5, 3, 3.5)
            for bar_offset in np.arange(0, length, BAR):
                for beat in hits:
                    at = start + bar_offset + beat * BEAT
                    if at < stop - 0.05:
                        place(keys, chord(voicing[1:], BEAT / 2 + 0.2, 0.5 if beat % 1 else 0.42, roll=0.004), at, 0.75)
        elif part == "dip":
            place(keys, chord(voicing[-3:], length, 0.4, roll=0.03), start + BEAT, 0.6)
        # Bass: root on 1, a skip on the "and" of 2, the fifth on 3, a pickup on 4-and.
        if part in ("verse", "chorus"):
            for beat, step, beats in ((0, 0, 1.2), (1.5, 0, 0.4), (2, 7, 0.9), (3.5, 12, 0.4)):
                at = start + beat * BEAT
                if at < stop - 0.05:
                    place(low, ebass(bass_note + step, beats * BEAT), at, 0.8)
        elif part == "dip":
            place(low, ebass(bass_note, length), start, 0.4)

    # The tune in verse and chorus; the counter-line joins in the chorus.
    for k, bar_start in enumerate(bar_lines):
        part = section(bar_start)
        if part not in ("verse", "chorus", "dip"):
            continue
        phrase_bar = (k - 1) % 4
        for b, beat, note, beats in TUNE:
            at = bar_start + beat * BEAT
            if b == phrase_bar and at < end and not any(abs(at - c) < BEAT * 0.5 for c in changes):
                place(keys, piano(note, 0.4 + beats * BEAT, 0.5), at, 1.05 if part != "dip" else 0.7)
        if part == "chorus":
            for b, beat, note, beats in COUNTER:
                at = bar_start + beat * BEAT
                if b == phrase_bar and at < end:
                    place(keys, piano(note, 0.5 + beats * BEAT, 0.38), at, 0.7)

    # Drums: soft kick on 1 and 3, claps on 2 and 4, a shaker in eighths (sixteenths in the chorus).
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
                if step % 2 == 0:  # a steady eighth-note pulse, like the reference
                    place(drums, shaker(), at, 0.15 if step % 4 == 2 else 0.1)
            elif part == "dip" and step % 4 == 0:
                place(drums, shaker(), at, 0.05)

    # Every scene change: a reversed chord swells in, then the kick and a low hit land.
    for s in scenes:
        if not s["turn"]:
            continue
        at = sec(s["start"])
        nxt = next((ci for a, _, ci in segments if abs(a - at) < 0.01), 0)
        place(keys, reverse_swell(CHORDS[nxt][1], BEAT), at - BEAT, 0.35)
        place(drums, kick(), at, 0.85)
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
            place(fx, sound, when, {"stamp": 0.4, "tap": 0.14, "ding": 0.15}[accent["sfx"]])
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

    # The end: a bright Bb add9 left to ring, with a little answer up high.
    if end < seconds:
        place(keys, chord([46, 58, 62, 65, 69, 72, 74], 4.0, 0.62, roll=0.03), end, 1.3)
        place(keys, piano(82, 2.5, 0.45), end + BEAT, 0.8)
        place(keys, piano(86, 2.5, 0.42), end + 1.5 * BEAT, 0.7)
        place(low, ebass(34, min(3.0, seconds - end + 0.5)), end, 0.5)

    # Keys and bass ease under each kick: a light pump.
    duck = np.ones(n)
    for k in kicks:
        i = int(k * SR)
        m = min(n - i, int(0.25 * SR))
        if m > 0:
            duck[i : i + m] = np.minimum(duck[i : i + m], 1 - 0.18 * np.exp(-np.arange(m) / SR / 0.08))

    ir = room(1.6)
    keys_wet = fftconvolve(keys, ir)[:n]
    mix = ((keys * 0.85 + keys_wet * 0.3) * duck + low * duck + drums + fftconvolve(drums, ir)[:n] * 0.08) * gain + fx
    # Intro: the piano alone, a touch softer.
    if drop > 0:
        i = int(drop * SR)
        mix[:i] = lowpass(mix[:i], 3500)
    mix = lowpass(mix, 8000)  # warm, like the reference: little air on top

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
