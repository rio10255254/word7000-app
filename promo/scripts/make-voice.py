#!/usr/bin/env python3
"""Speak 小笨貓's lines for the IG reels (src/reels/episodes.json).

Uses Kokoro-82M v1.1-zh (Apache-2.0, https://huggingface.co/hexgrad/Kokoro-82M-v1.1-zh),
which runs on a CPU. Each line's `say` (or its `text`) becomes
public/reels/voice/<episode>-<n>.wav at 24 kHz; scripts/make-reels.py
times the reels from these files and mixes them with the music.

Kokoro needs Python 3.10–3.12:

    uv venv -p 3.12 .venv-voice
    uv pip install --python .venv-voice/bin/python torch "kokoro>=0.9.4" "misaki[zh]" soundfile \
        "en_core_web_sm @ https://github.com/explosion/spacy-models/releases/download/en_core_web_sm-3.8.0/en_core_web_sm-3.8.0-py3-none-any.whl"
    .venv-voice/bin/python scripts/make-voice.py [ep01 ep02 …]
"""
import json
import sys
from pathlib import Path

import numpy as np
import soundfile as sf
from kokoro import KModel, KPipeline

ROOT = Path(__file__).resolve().parent.parent
SCRIPT = json.loads((ROOT / "src" / "reels" / "episodes.json").read_text())
OUT = ROOT / "public" / "reels" / "voice"
REPO = "hexgrad/Kokoro-82M-v1.1-zh"


def main():
    wanted = set(sys.argv[1:])
    OUT.mkdir(parents=True, exist_ok=True)
    model = KModel(repo_id=REPO).eval()
    english = KPipeline(lang_code="a", repo_id=REPO, model=False)
    # English words in a line ("all", "metallic") are read with English phonemes.
    chinese = KPipeline(lang_code="z", repo_id=REPO, model=model, en_callable=lambda t: next(english(t)).phonemes)
    for episode in SCRIPT["episodes"]:
        if (wanted and episode["id"] not in wanted) or episode.get("voice") is False:
            continue
        for n, line in enumerate(episode["lines"]):
            text = line.get("say", line["text"])
            audio = np.concatenate([r.audio.numpy() for r in chinese(text, voice=SCRIPT["voice"], speed=SCRIPT["speed"])])
            path = OUT / f"{episode['id']}-{n}.wav"
            sf.write(path, audio, 24000)
            print(f"{path.relative_to(ROOT)}: {len(audio) / 24000:.2f}s  {text}")


if __name__ == "__main__":
    main()
