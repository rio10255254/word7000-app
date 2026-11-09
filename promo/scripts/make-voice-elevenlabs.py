#!/usr/bin/env python3
"""Speak 傻貓's lines with ElevenLabs, for reels whose script asks for it.

An episode in src/reels/episodes.json with "voice": {"engine": "elevenlabs",
"voiceId": …, "model": …} gets every line that has a `say` spoken to
public/reels/voice/<episode>-<n>.mp3. `say` may carry ElevenLabs audio tags
such as [smug]; they steer the delivery and are not read out.

The API key is taken from ELEVENLABS_API_KEY, or added on the way out by the
cloud session's network proxy when one is configured there.

    python3 scripts/make-voice-elevenlabs.py teaser
"""
import json
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SCRIPT = json.loads((ROOT / "src" / "reels" / "episodes.json").read_text())
OUT = ROOT / "public" / "reels" / "voice"


def speak(text, voice, path):
    body = {"text": text, "model_id": voice.get("model", "eleven_v4"), "language_code": voice.get("language", "zh")}
    if "settings" in voice:
        body["voice_settings"] = voice["settings"]
    key = os.environ.get("ELEVENLABS_API_KEY", "set-by-proxy")
    url = f"https://api.elevenlabs.io/v1/text-to-speech/{voice['voiceId']}?output_format=mp3_44100_128"
    code = subprocess.run(
        ["curl", "-sS", "-m", "120", "-o", str(path), "-w", "%{http_code}", "-X", "POST", url,
         "-H", f"xi-api-key: {key}", "-H", "Content-Type: application/json", "-d", json.dumps(body)],
        capture_output=True, text=True, check=True,
    ).stdout
    if code != "200":
        raise SystemExit(f"ElevenLabs answered {code}: {path.read_text(errors='replace')[:300]}")


def main():
    wanted = set(sys.argv[1:])
    OUT.mkdir(parents=True, exist_ok=True)
    for episode in SCRIPT["episodes"]:
        voice = episode.get("voice")
        if not isinstance(voice, dict) or voice.get("engine") != "elevenlabs" or (wanted and episode["id"] not in wanted):
            continue
        for n, line in enumerate(episode["lines"]):
            if "say" not in line:
                continue
            path = OUT / f"{episode['id']}-{n}.mp3"
            speak(line["say"], voice, path)
            print(f"{path.relative_to(ROOT)}  {line['say']}")
        if "outroSay" in episode:
            path = OUT / f"{episode['id']}-outro.mp3"
            speak(episode["outroSay"], voice, path)
            print(f"{path.relative_to(ROOT)}  {episode['outroSay']}")


if __name__ == "__main__":
    main()
