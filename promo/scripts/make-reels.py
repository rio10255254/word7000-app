#!/usr/bin/env python3
"""Time and mix the IG reels: 小笨貓's voice over a light groove.

Reads src/reels/episodes.json and the voice lines that scripts/make-voice.py
spoke (public/reels/voice/<episode>-<n>.wav). Each line gets a slot that
starts on a beat and lasts until its words have been said and a breath
after; the end card follows, with the chorus hook "D C B♭" as the sound
logo every episode ends on. Writes:

- src/reels/timing.json: the slots, in seconds, for src/reels/Reel.tsx
- public/reels/<episode>.mp3: voice, music and effects mixed

The instruments are the soundtrack's (scripts/make-music.py). Needs numpy,
scipy and ffmpeg.
"""
import importlib.util
import json
import math
import sys
from pathlib import Path

import numpy as np
from scipy.signal import resample_poly

ROOT = Path(__file__).resolve().parent.parent
_spec = importlib.util.spec_from_file_location("music", ROOT / "scripts" / "make-music.py")
m = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(m)

SR = m.SR
SCRIPT = json.loads((ROOT / "src" / "reels" / "episodes.json").read_text())
VOICE = ROOT / "public" / "reels" / "voice"
BEAT = 0.5  # 120 bpm
LEAD_IN = 0.12  # the voice starts just after the card lands on the beat
BREATH = 0.3
END_BEATS = 6  # the end card: the sound logo, then a held B♭

# One chord a bar from the soundtrack's loop, vi–IV–I–V.
LOOP = [m.GM, m.EB, m.BB, m.F_]


def load_voice(path):
    """A spoken line, trimmed of the model's silence, at the mix's rate, and polished."""
    import soundfile as sf

    audio, rate = sf.read(path)
    level = np.abs(audio)
    loud = np.where(level > 0.02 * level.max())[0]
    audio = audio[max(0, loud[0] - int(0.03 * rate)) : loud[-1] + int(0.08 * rate)]
    audio = resample_poly(audio, SR // 100, rate // 100)
    # Clean and present: no rumble, a little body, clarity at 3 kHz, air on top.
    audio = m.highpass(audio, 90)
    audio = m.peaking(audio, 220, 1.5, 0.9)
    audio = m.peaking(audio, 3200, 2.5, 1.0)
    audio = m.high_shelf(audio, 8000, 2.0)
    # Gentle compression so every word sits at the same level.
    env = np.sqrt(np.maximum(m.lowpass(audio**2, 20), 0) + 1e-9)
    gain = np.minimum(1.0, (env / (env.max() * 0.35)) ** -0.45)
    audio = audio * gain
    return audio / np.abs(audio).max() * 0.9


def layout(episode):
    """Slots on the beat grid: (start, length, voice) per line, then the end card."""
    slots, t = [], 0.0
    for n, line in enumerate(episode["lines"]):
        if "beats" in line:  # a silent shot, as long as written
            length = line["beats"] * BEAT
            slots.append({"start": t, "length": length, "voiceStart": t, "voiceLength": 0.0, "audio": np.zeros(1)})
            t += length
            continue
        voice = load_voice(VOICE / f"{episode['id']}-{n}.wav")
        length = math.ceil((LEAD_IN + len(voice) / SR + BREATH) / BEAT) * BEAT
        slots.append({"start": t, "length": length, "voiceStart": t + LEAD_IN, "voiceLength": len(voice) / SR, "audio": voice})
        t += length
    return slots, t


def wrong():
    """A soft "nope": two short low buzzes."""
    n = int(0.32 * SR)
    t = np.arange(n) / SR
    out = np.zeros(n)
    for at in (0.0, 0.14):
        k = (t >= at) & (t < at + 0.11)
        tt = t[k] - at
        out[k] += m.lowpass(np.sign(np.sin(2 * np.pi * 155 * tt)), 1200) * np.exp(-tt / 0.06)
    return out * 0.6


def groove(seconds):
    """A light, bouncy bed under the voice: guitar chucks, marimba, bass and hand drums."""
    n = int((seconds + 2) * SR)
    gtr, mar, bass, drums = (np.zeros(n) for _ in range(4))
    bars = math.ceil(seconds / (4 * BEAT))
    for b in range(bars):
        bass_note, shape, _, _ = LOOP[b % 4]
        start = b * 4 * BEAT
        # Guitar: a soft strum on 1, chucks on the backbeats, upstrokes in between.
        m.place(gtr, m.strum(shape, BEAT * 1.4, 0.45), start)
        for beat in (1, 3):
            m.place(gtr, m.chuck(shape), start + beat * BEAT, 0.8)
        for half in (1.5, 2.5, 3.5):
            m.place(gtr, m.strum(shape, BEAT * 0.4, 0.3, up=True), start + half * BEAT + m.SWING)
        # Marimba on the off-beats: the top of the chord, island style (3-3-2).
        top = sorted(n_ for n_ in shape)[-3:]
        for eighth in (0, 3, 6):
            for note in top[-2:]:
                m.place(mar, m.marimba(note + 12, 0.45), start + eighth * BEAT / 2, 0.5)
        # Bass: root on 1, a bounce before 3.
        m.place(bass, m.ebass(bass_note, BEAT * 1.3), start)
        m.place(bass, m.ebass(bass_note + 12, BEAT * 0.4), start + 1.5 * BEAT)
        m.place(bass, m.ebass(bass_note, BEAT * 1.2), start + 2 * BEAT)
        # Drums: soft kick on 1 and 3, clap on 2 and 4, shaker eighths, a conga.
        for beat in (0, 2):
            m.place(drums, m.kick(), start + beat * BEAT, 0.55)
        for beat in (1, 3):
            m.place(drums, m.clap(), start + beat * BEAT, 0.28)
        for eighth in range(8):
            m.place(drums, m.shaker(), start + eighth * BEAT / 2 + (m.SWING if eighth % 2 else 0), 0.22)
        m.place(drums, m.one_shot("conga"), start + 3.5 * BEAT, 0.3)
    return gtr * 0.9 + mar * 0.55 + bass * 0.5 + drums


def logo(at, bus, tune):
    """The sound logo: the chorus hook's first cell, D–C–B♭, landing on a B♭ chord."""
    for beat, note, beats in [(0, 86, 0.5), (0.5, 84, 1.0), (1.5, 82, 2.5)]:
        m.place(tune, m.lead(note, beats * BEAT * 0.9, 0.75), at + beat * BEAT)
        m.place(tune, m.marimba(note - 12, 0.7), at + beat * BEAT, 0.8)
    m.place(bus, m.strum(m.BB[1], BEAT * 4, 0.55), at + 1.5 * BEAT)
    m.place(bus, m.pad(m.BB[3], BEAT * 4.5), at + 1.5 * BEAT, 0.5)
    m.place(bus, m.ebass(m.BB[0] - 12, BEAT * 3.5), at + 1.5 * BEAT, 0.6)
    m.place(bus, m.kick(), at + 1.5 * BEAT, 0.6)
    for i, note in enumerate([82, 86, 89, 94]):
        m.place(tune, m.glock(note, 0.4), at + 1.5 * BEAT + 0.6 + i * 0.12, 0.35)


def mix(episode):
    slots, body = layout(episode)
    total = body + END_BEATS * BEAT
    n = int(total * SR)
    voice, sfx, band, tune = (np.zeros(n + SR) for _ in range(4))
    music = groove(body)[: n + SR]
    music = np.pad(music, (0, n + SR - len(music)))
    # The groove gives way to the end card: a quick fade over the last beat.
    fade = np.ones(n + SR)
    a, b = int((body - BEAT) * SR), int(body * SR)
    fade[a:b] = np.linspace(1, 0, b - a)
    fade[b:] = 0
    music *= fade
    sounds = {"pop": (m.pop, 0.4), "tap": (m.tap, 0.9), "whoosh": (lambda: m.whoosh(BEAT), 0.45), "ding": (m.ding, 0.5), "stamp": (m.stamp, 0.5), "wrong": (wrong, 0.7)}
    for slot, line in zip(slots, episode["lines"]):
        m.place(voice, slot["audio"], slot["voiceStart"])
        for beat, name in line.get("cues", []):
            make, gain = sounds[name]
            m.place(sfx, make(), slot["start"] + beat * BEAT, gain)
        if "cues" in line:
            continue
        m.place(sfx, m.pop(), slot["start"], 0.35)
        if line.get("tap"):
            m.place(sfx, m.tap(), slot["start"] + 0.05, 0.9)
        if line.get("sfx") == "wrong":
            m.place(sfx, wrong(), slot["start"] + 0.1, 0.7)
    m.place(sfx, m.whoosh(BEAT), body - BEAT, 0.5)
    logo(body, band, tune)

    # Duck the music under the voice (about −10 dB while the cat talks).
    if np.abs(voice).max() > 0:
        env = m.lowpass(np.abs(voice), 8)
        music *= 1 - 0.68 * np.clip(env / (env.max() * 0.25), 0, 1)
    else:
        music *= 1.5  # no voice: the music carries the reel
    tune = m.echo(m.bright_not_harsh(tune), BEAT * 0.75, 0.25, 2)

    def stereo(x, width=0.0):
        return np.stack([x * (1 - width), x * (1 + width)], axis=1)

    out = stereo(voice * 0.95) + stereo(music * 0.42) + stereo(sfx * 0.6) + stereo(band * 0.5) + stereo(m.widen(tune * 0.5))
    out = out[:n]
    out[-int(0.25 * SR) :] *= np.linspace(1, 0, int(0.25 * SR))[:, None]
    out *= 0.89 / np.abs(out).max()
    timing = {
        "total": round(total, 3),
        "end": round(body, 3),
        "slots": [{k: round(v, 3) for k, v in s.items() if k != "audio"} for s in slots],
    }
    return out, timing


def main():
    wanted = set(sys.argv[1:])
    path = ROOT / "src" / "reels" / "timing.json"
    timings = json.loads(path.read_text()) if path.exists() else {}
    for episode in SCRIPT["episodes"]:
        if wanted and episode["id"] not in wanted:
            continue
        stereo, timing = mix(episode)
        out = ROOT / "public" / "reels" / f"{episode['id']}.mp3"
        m.write_mp3(stereo, out)
        timings[episode["id"]] = timing
        print(f"{episode['id']}: {timing['total']:.2f}s -> {out.relative_to(ROOT)}")
    path.write_text(json.dumps(timings, indent=2) + "\n")


if __name__ == "__main__":
    main()
