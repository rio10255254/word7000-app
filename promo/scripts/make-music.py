#!/usr/bin/env python3
"""Compose the promo soundtracks from src/timeline.json.

An original, playful track in F major at the timeline's tempo: plucked
chords and a glockenspiel tune over bass and drums, with whooshes, pops
and stamps on the scene changes. The scene timing is computed the same
way as src/transitions.tsx (every scene a whole number of beats, every
transition one or more beats), so each change of scene lands on a beat.

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
from scipy.signal import butter, lfilter, sosfilt

ROOT = Path(__file__).resolve().parent.parent
TIMELINE = json.loads((ROOT / "src" / "timeline.json").read_text())

SR = 44100
OUTPUT_FPS = 60
FRAME_SCALE = 1.2 * (60 / 30)  # time.ts: SPEED × OUTPUT_FPS / AUTHORED_FPS
BPM = TIMELINE["bpm"]
HOLD = TIMELINE["hold"]
BEAT_FRAMES = round(OUTPUT_FPS * 60 / BPM)
BEAT = BEAT_FRAMES / OUTPUT_FPS  # seconds
BAR = BEAT * 4
rng = np.random.default_rng(7000)


def js_round(x):
    return math.floor(x + 0.5)


# ── Timeline, exactly as transitions.tsx lays it out ──────────────────────────


def step_frames(entry):
    if "steps" in entry:
        return track_frames(entry["steps"])
    raw = js_round((entry["duration"] + HOLD) * FRAME_SCALE)
    return math.ceil(raw / BEAT_FRAMES) * BEAT_FRAMES


def turn_frames(entry):
    return entry.get("turnBeats", 1) * BEAT_FRAMES


def track_frames(entries):
    return sum(step_frames(e) - (turn_frames(e) if i else 0) for i, e in enumerate(entries))


def layout(entries, offset=0):
    """Scene starts and transitions, flattened, in output frames."""
    scenes, t = [], 0
    for i, e in enumerate(entries):
        if i:
            t -= turn_frames(e)
        start = offset + t
        scenes.append({**e, "start": start, "turn": turn_frames(e) if i else 0, "nested": False})
        if "steps" in e:
            for inner in layout(e["steps"], start)[0]:
                if inner["start"] != start:  # the first inner beat comes in with its section
                    scenes.append({**inner, "nested": True})
        t += step_frames(e)
    return scenes, offset + t


# ── Instruments ──────────────────────────────────────────────────────────────


def midi(n):
    return 440.0 * 2 ** ((n - 69) / 12)


def env(n, attack, decay):
    t = np.arange(n) / SR
    a = np.clip(t / max(attack, 1e-4), 0, 1)
    return a * np.exp(-t / decay)


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


def pluck(freq, length=1.1, bright=0.6):
    """Karplus-Strong string: a ukulele-ish pluck."""
    n = int(length * SR)
    period = max(2, int(SR / freq))
    burst = np.zeros(n)
    burst[:period] = lowpass(rng.uniform(-1, 1, period), 1500 + 5000 * bright)
    a = np.zeros(period + 2)
    a[0], a[period], a[period + 1] = 1.0, -0.497, -0.497
    y = lfilter([1.0], a, burst)
    return y * env(n, 0.002, length * 0.45) / (np.max(np.abs(y)) + 1e-9)


def glock(freq, length=1.2):
    n = int(length * SR)
    t = np.arange(n) / SR
    tone = np.sin(2 * np.pi * freq * t) + 0.35 * np.sin(2 * np.pi * freq * 2.76 * t) * np.exp(-t / 0.08)
    return tone * env(n, 0.001, 0.38)


def pad(freqs, length):
    n = int(length * SR)
    t = np.arange(n) / SR
    out = np.zeros(n)
    for f in freqs:
        for detune in (-0.12, 0.0, 0.12):
            ff = f * 2 ** (detune / 12)
            out += 2 * ((t * ff) % 1.0) - 1  # saw
    out = lowpass(out / (len(freqs) * 3), 1100, 2)
    fade = np.minimum(1, np.minimum(t / 0.25, (length - t) / 0.35).clip(0))
    return out * fade


def bass(freq, length):
    n = int(length * SR)
    t = np.arange(n) / SR
    tone = np.sin(2 * np.pi * freq * t) + 0.3 * np.sin(4 * np.pi * freq * t) + 0.12 * np.sin(6 * np.pi * freq * t)
    return tone * env(n, 0.004, length * 0.6)


def kick():
    n = int(0.42 * SR)
    t = np.arange(n) / SR
    f = 45 + 110 * np.exp(-t / 0.035)
    body = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.22)
    click = highpass(rng.uniform(-1, 1, n), 3000) * np.exp(-t / 0.004) * 0.3
    return body + click


def snare():
    n = int(0.3 * SR)
    t = np.arange(n) / SR
    noise = bandpass(rng.uniform(-1, 1, n), 1200, 7000) * np.exp(-t / 0.09)
    tone = np.sin(2 * np.pi * 190 * t) * np.exp(-t / 0.05)
    clap = sum(np.roll(highpass(rng.uniform(-1, 1, n), 900) * np.exp(-t / 0.02), int(d * SR)) for d in (0, 0.011, 0.022))
    return 0.7 * noise + 0.5 * tone + 0.35 * clap


def hat(open_=False):
    n = int((0.25 if open_ else 0.06) * SR)
    t = np.arange(n) / SR
    return highpass(rng.uniform(-1, 1, n), 7000, 4) * np.exp(-t / (0.09 if open_ else 0.018))


def whoosh(length):
    n = int(length * SR)
    t = np.arange(n) / SR
    noise = rng.uniform(-1, 1, n)
    out = np.zeros(n)
    hop = 512
    for i in range(0, n, hop):  # a band sweeping up and back down
        p = i / n
        centre = 600 + 4200 * math.sin(math.pi * p)
        seg = noise[max(0, i - 2048) : i + hop]
        out[i : i + hop] = bandpass(seg, centre * 0.6, min(centre * 1.6, SR / 2 - 100))[-len(out[i : i + hop]) :]
    shape = np.sin(np.pi * np.clip(t / length, 0, 1)) ** 2
    return out * shape


def riser(length):
    n = int(length * SR)
    t = np.arange(n) / SR
    noise = rng.uniform(-1, 1, n)
    out = np.zeros(n)
    hop = 1024
    for i in range(0, n, hop):
        centre = 400 * (16 ** (i / n))
        seg = noise[max(0, i - 4096) : i + hop]
        out[i : i + hop] = bandpass(seg, centre * 0.7, min(centre * 1.5, SR / 2 - 100))[-len(out[i : i + hop]) :]
    return out * (t / length) ** 2


def pop():
    n = int(0.18 * SR)
    t = np.arange(n) / SR
    f = 320 + 900 * np.exp(-t / 0.02)
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.05)


def tap():
    n = int(0.06 * SR)
    t = np.arange(n) / SR
    return (np.sin(2 * np.pi * 1800 * t) * 0.5 + bandpass(rng.uniform(-1, 1, n), 2000, 6000)) * np.exp(-t / 0.008)


def stamp():
    n = int(0.35 * SR)
    t = np.arange(n) / SR
    thud = np.sin(2 * np.pi * (70 + 60 * np.exp(-t / 0.02)) * t) * np.exp(-t / 0.09)
    slap = bandpass(rng.uniform(-1, 1, n), 300, 3000) * np.exp(-t / 0.03)
    return thud + 0.6 * slap


def impact(length=2.5):
    n = int(length * SR)
    t = np.arange(n) / SR
    crash = highpass(rng.uniform(-1, 1, n), 4000) * np.exp(-t / 0.7) * 0.5
    boom = np.sin(2 * np.pi * (38 + 40 * np.exp(-t / 0.05)) * t) * np.exp(-t / 0.5)
    return crash + boom


def ding():
    return glock(midi(96), 1.4) * 0.8 + np.roll(glock(midi(89), 1.4), int(0.12 * SR)) * 0.8


# ── Song ─────────────────────────────────────────────────────────────────────

# I–V–vi–IV in F, one chord a bar.
CHORDS = [
    (41, [65, 69, 72, 77]),  # F
    (36, [64, 67, 72, 76]),  # C
    (38, [62, 65, 69, 74]),  # Dm
    (34, [62, 65, 70, 74]),  # Bb
]
# A four-bar tune: (bar, beat, midi note, length in beats).
TUNE = [
    (0, 0, 81, 1), (0, 1, 84, 1), (0, 2, 89, 1.5), (0, 3.5, 88, 0.5),
    (1, 0, 84, 1), (1, 1, 79, 1), (1, 2, 76, 1.5), (1, 3.5, 79, 0.5),
    (2, 0, 81, 1), (2, 1, 77, 1), (2, 2, 81, 1), (2, 3, 86, 1),
    (3, 0, 86, 1), (3, 1, 84, 1), (3, 2, 82, 1), (3, 3, 81, 1),
]
ARP = [0, 1, 2, 3, 2, 1, 2, 3]  # chord-tone order for eighth-note plucks


def compose(name):
    scenes, total_frames = layout(TIMELINE[name])
    seconds = total_frames / OUTPUT_FPS
    n = int(seconds * SR) + SR
    music, drums, fx = np.zeros(n), np.zeros(n), np.zeros(n)
    sec = lambda frames: frames / OUTPUT_FPS

    top = [s for s in scenes if not s["nested"]]
    find = lambda tag: next((s for s in top if s.get("music") == tag), None)
    drop = sec(find("drop")["start"]) if find("drop") else 0.0
    breakdown = sec(find("breakdown")["start"]) if find("breakdown") else None
    end = sec(find("end")["start"]) if find("end") else seconds
    groove_end = breakdown if breakdown is not None else end

    # Bar lines are set so the drop is a downbeat; the intro starts on a pickup.
    phase = drop % BAR
    bars = int(math.ceil(seconds / BAR)) + 1
    kicks = []
    for bar in range(-1, bars):
        t0 = phase + bar * BAR
        if t0 >= end:
            break
        root, notes = CHORDS[bar % 4]
        in_groove = drop <= t0 < groove_end
        # Plucked eighth-note arpeggio throughout; quieter and darker before the drop.
        for k, idx in enumerate(ARP):
            at = t0 + k * BEAT / 2
            if at < 0:
                continue
            if at >= end:
                break
            place(music, pluck(midi(notes[idx]), 0.9, 0.7 if in_groove else 0.45), at, 0.22 if in_groove else 0.42)
        # A soft pad under the intro and the breakdown.
        if not in_groove:
            place(music, pad([midi(x) for x in notes[:3]], BAR + 0.3), t0, 0.3)
        # Bass in the groove, a held root in the breakdown.
        if in_groove:
            for beat, length in ((0, 1.2), (1.5, 0.45), (2, 0.9), (3.5, 0.45)):
                place(music, bass(midi(root), length * BEAT), t0 + beat * BEAT, 0.42)
        elif breakdown is not None and t0 >= breakdown:
            place(music, bass(midi(root), BAR), t0, 0.3)
        # The tune: every phrase in the groove, and gently in the intro's second half.
        phrase_bar = bar % 4
        if in_groove or (t0 >= drop - 2 * BAR and t0 < drop):
            for b, beat, note, length in TUNE:
                if b == phrase_bar:
                    place(music, glock(midi(note), 0.4 + length * BEAT), t0 + beat * BEAT, 0.16 if in_groove else 0.24)
        # Drums.
        if in_groove:
            for beat in range(4):
                at = t0 + beat * BEAT
                if at >= groove_end:
                    break
                if beat in (0, 2):
                    place(drums, kick(), at, 0.95)
                    kicks.append(at)
                if beat in (1, 3):
                    place(drums, snare(), at, 0.42)
                place(drums, hat(), at, 0.08)
                place(drums, hat(), at + BEAT / 2, 0.14)
            if bar % 2 == 1 and t0 + 3.5 * BEAT < groove_end:
                place(drums, hat(True), t0 + 3.5 * BEAT, 0.1)
                place(drums, kick(), t0 + 3.5 * BEAT, 0.6)
                kicks.append(t0 + 3.5 * BEAT)
        elif breakdown is not None and breakdown <= t0 < end:
            for beat in range(4):
                place(drums, hat(), t0 + beat * BEAT + BEAT / 2, 0.06)

    # Sidechain pump: the music ducks under each kick.
    duck = np.ones(n)
    for k in kicks:
        i = int(k * SR)
        m = min(n - i, int(0.3 * SR))
        duck[i : i + m] = np.minimum(duck[i : i + m], 1 - 0.35 * np.exp(-np.arange(m) / SR / 0.09))
    music *= duck

    # Into the drop: a riser, then a hit with the first downbeat.
    if drop > 0:
        place(fx, riser(2 * BEAT), drop - 2 * BEAT, 0.28)
        place(fx, impact(), drop, 0.55)

    # Scene changes and in-scene moments.
    for s in scenes:
        start = sec(s["start"])
        turn = sec(s["turn"])
        kind = s.get("enter")
        if turn and kind:
            if kind in ("push", "zoom", "pull"):
                place(fx, whoosh(turn * 1.2), start - turn * 0.1, 0.32 if kind == "push" else 0.4)
            elif kind == "circle":
                place(fx, pop(), start, 0.45)
                place(fx, whoosh(turn), start, 0.2)
            elif kind == "dissolve":
                place(fx, riser(turn), start - turn * 0.4, 0.15)
        for accent in s.get("accents", []):
            at = start + sec(js_round(accent["at"] * FRAME_SCALE))
            sound = {"stamp": stamp, "tap": tap, "ding": ding}[accent["sfx"]]()
            place(fx, sound, at, {"stamp": 0.6, "tap": 0.25, "ding": 0.35}[accent["sfx"]])

    # The end card: one last hit and the tonic chord left to ring.
    if end < seconds:
        place(fx, impact(3.0), end, 0.45)
        place(drums, kick(), end, 0.9)
        for i, note in enumerate([53, 57, 60, 65, 69, 72]):
            place(music, pluck(midi(note), 3.5, 0.6), end + i * 0.03, 0.3)
        place(music, pad([midi(x) for x in (65, 69, 72)], seconds - end + 0.5), end, 0.32)
        place(music, glock(midi(89), 2.0), end + BEAT, 0.22)
        place(music, glock(midi(84), 2.0), end + 2 * BEAT, 0.18)

    mix = music + drums + fx
    mix = mix[: int(seconds * SR)]
    t = np.arange(len(mix)) / SR
    mix *= np.clip((seconds - t) / 1.2, 0, 1)  # fade out over the last 1.2 s
    mix = np.tanh(1.3 * mix / (np.max(np.abs(mix)) + 1e-9)) * 0.89 / np.tanh(1.3)
    # A touch of width: a slightly delayed, lowpassed copy on the right.
    left = mix
    right = 0.85 * mix + 0.15 * np.roll(lowpass(mix, 5000), int(0.012 * SR))
    stereo = np.stack([left, right], axis=1)
    return stereo, scenes, seconds


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
        print(f"{name}: {seconds:.2f}s, {seconds / BEAT:g} beats -> {out.relative_to(ROOT)}")
        print(f"  scene changes on beats: {changes}")


if __name__ == "__main__":
    main()
