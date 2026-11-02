#!/usr/bin/env python3
"""Compose the promo soundtracks from src/timeline.json.

A chill lo-fi piano piece: a real grand piano (Salamander Grand Piano V3
samples by Alexander Holm, CC BY 3.0; see assets/salamander/CREDITS.md),
played softly on jazzy seventh chords
(Fmaj9 → Em7 → Dm9 → Cmaj9) with a sparse melody, a round sub bass,
laid-back boom-bap drums with swung hats, room reverb, vinyl crackle and a
touch of tape wobble.

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
SWING = 0.12  # how late the off-beat eighths fall, in beats
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
    # Tape flutter: the read position drifts a hair ahead and behind.
    pos = (np.arange(n) * ratio) * (1 + 0.0016 * np.sin(2 * np.pi * 0.45 * t + note))
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
    f = 48 + 70 * np.exp(-t / 0.03)
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
    boom = np.sin(2 * np.pi * (34 + 30 * np.exp(-t / 0.06)) * t) * np.exp(-t / 0.45)
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


# ── Song ─────────────────────────────────────────────────────────────────────

# Fmaj9 → Em7 → Dm9 → Cmaj9: (bass note, piano voicing).
CHORDS = [
    (41, [53, 64, 67, 69, 72]),
    (40, [52, 62, 67, 71, 74]),
    (38, [50, 60, 64, 65, 69]),
    (36, [48, 59, 62, 64, 67]),
]
# A sparse four-bar tune: (bar, beat, note, beats).
TUNE = [
    (0, 0, 76, 1), (0, 1.5, 79, 0.5), (0, 2, 81, 2),
    (1, 0.5, 79, 1), (1, 2, 76, 1), (1, 3, 74, 1),
    (2, 0, 72, 1.5), (2, 1.5, 74, 0.5), (2, 2, 76, 1), (2, 3, 81, 1),
    (3, 0, 79, 2), (3, 2.5, 76, 0.5), (3, 3, 74, 1),
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
    breakdown = sec(find("breakdown")["start"]) if find("breakdown") else None
    end = sec(find("end")["start"]) if find("end") else seconds
    groove_end = breakdown if breakdown is not None else end
    changes = sorted(sec(s["start"]) for s in scenes if s["turn"])

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

    def in_groove(t):
        return drop <= t < groove_end

    for start, stop, ci in segments:
        bass_note, voicing = CHORDS[ci]
        length = stop - start
        groove = in_groove(start)
        # Piano: the rolled chord, then a soft upper-voice answer on the "and" of 3.
        place(keys, chord(voicing, length + 1.2, 0.62 if groove else 0.5), start)
        answer = start + 2.5 * BEAT + SWING * BEAT
        if answer + 0.3 < stop:
            place(keys, chord(voicing[-3:], 1.6, 0.36, roll=0.01), answer)
        # Sub bass under the groove; a held root in the breakdown.
        if groove or (breakdown is not None and breakdown <= start < end):
            place(low, sub(bass_note, length), start, 0.55 if groove else 0.4)

    # The tune, phrase by phrase on the bar grid, in the groove and the breakdown.
    for k, bar_start in enumerate(bar_lines):
        if bar_start < drop or bar_start >= end:
            continue
        phrase_bar = (k - 1) % 4  # bar_lines[1] is the drop bar
        for b, beat, note, beats in TUNE:
            at = bar_start + beat * BEAT
            if b == phrase_bar and at < end and not any(abs(at - c) < BEAT * 0.6 for c in changes):
                place(keys, piano(note + 12, 0.6 + beats * BEAT, 0.45), at, 1.0)

    # Drums: kick on 1 and the "and" of 2, snare on 2 and 4, swung hats.
    kicks = []
    for k, bar_start in enumerate(bar_lines):
        for beat8 in range(8):
            beat = beat8 / 2
            at = bar_start + beat * BEAT + (SWING * BEAT if beat8 % 2 else 0)
            if at < 0 or at >= end:
                continue
            # Drop out for the half beat before every scene change.
            if any(c - BEAT * 0.5 - 0.01 <= at < c - 0.01 for c in changes):
                continue
            if in_groove(at):
                if beat8 in (0, 3) or (beat8 == 5 and k % 2):
                    place(drums, kick(), at, 0.75)
                    kicks.append(at)
                if beat8 in (2, 6):
                    place(drums, snare(), at, 0.38)
                place(drums, hat(), at, 0.1 if beat8 % 2 else 0.065)
            elif breakdown is not None and breakdown <= at < end and beat8 % 2 == 0:
                place(drums, rim() if beat8 in (2, 6) else hat(), at, 0.12 if beat8 in (2, 6) else 0.05)

    # Every scene change: a reversed chord swells in, then the kick and a low hit land.
    for s in scenes:
        if not s["turn"]:
            continue
        at = sec(s["start"])
        nxt = next((ci for a, _, ci in segments if abs(a - at) < 0.01), 0)
        swell = reverse_swell(CHORDS[nxt][1], BEAT)
        place(keys, swell, at - BEAT, 0.3)
        place(drums, kick(), at, 0.9)
        kicks.append(at)
        place(fx, low_hit(), at, 0.45 if s.get("music") in ("drop", "end") else 0.3)
        kind = s.get("enter")
        if kind in ("push", "zoom", "pull"):
            place(fx, whoosh(sec(s["turn"]) * 1.1), at - 0.04, 0.12)
        elif kind == "circle":
            place(fx, pop(), at, 0.22)
        for accent in s.get("accents", []):
            when = at + sec(js_round(accent["at"] * FRAME_SCALE))
            sound = {"stamp": stamp, "tap": tap, "ding": ding}[accent["sfx"]]()
            place(fx, sound, when, {"stamp": 0.4, "tap": 0.14, "ding": 0.15}[accent["sfx"]])
    # The first scene's accents (it has no transition in).
    for s in scenes:
        if not s["turn"] and not s["nested"]:
            for accent in s.get("accents", []):
                when = sec(s["start"]) + sec(js_round(accent["at"] * FRAME_SCALE))
                place(fx, {"stamp": stamp, "tap": tap, "ding": ding}[accent["sfx"]](), when, 0.3)

    # The end: one last rolled Cmaj9 left to ring, with a high answer.
    if end < seconds:
        place(keys, chord([36, 48, 55, 59, 62, 64, 67, 71], 4.0, 0.6, roll=0.035), end)
        place(keys, piano(84, 3.0, 0.4), end + 2 * BEAT, 0.6)
        place(low, sub(36, seconds - end + 0.5), end, 0.4)

    # Keys and bass ease under each kick: a gentle pump.
    duck = np.ones(n)
    for k in kicks:
        i = int(k * SR)
        m = min(n - i, int(0.35 * SR))
        if m > 0:
            duck[i : i + m] = np.minimum(duck[i : i + m], 1 - 0.28 * np.exp(-np.arange(m) / SR / 0.11))

    ir = room()
    keys_wet = fftconvolve(keys, ir)[:n]
    drums_wet = fftconvolve(drums, ir)[:n]
    mix = (keys * 0.8 + keys_wet * 0.45) * duck + low * duck + drums + drums_wet * 0.12 + fx + fftconvolve(fx, ir)[:n] * 0.2
    # Intro: the piano alone, a little muffled, like it's coming from the next room.
    if drop > 0:
        i = int(drop * SR)
        mix[:i] = lowpass(mix[:i], 1800) * 1.25
    mix[: len(mix)] += crackle(len(mix))
    mix = lowpass(mix, 11000)  # lo-fi top end

    mix = mix[: int(seconds * SR)]
    t = np.arange(len(mix)) / SR
    mix *= np.clip((seconds - t) / 1.5, 0, 1)
    mix = np.tanh(1.2 * mix / (np.max(np.abs(mix)) + 1e-9)) * 0.89 / np.tanh(1.2)
    right = 0.8 * mix + 0.2 * np.roll(lowpass(mix, 6000), int(0.014 * SR))
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
