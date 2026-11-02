#!/usr/bin/env python3
"""Builds the conversation questions for the Taiwan Mandarin bank.

Source: content/taiwan-mandarin/speaking.json — for chosen words, a question
in Taiwan Mandarin (with its English), and a two-sentence model answer that
uses the word. Output: the Core package's speaking-zh.json, read by
SpeakingPractice for learners of Chinese.

    python3 scripts/build-taiwan-speaking.py [--check]
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / 'content/taiwan-mandarin/speaking.json'
WORDS = ROOT / 'ios/Word7000/Resources/words-zh.json'
OUT = ROOT / 'ios/Packages/Word7000Core/Sources/Word7000Core/Resources/speaking-zh.json'
LATIN = re.compile(r'[A-Za-z]')


def build() -> dict:
    words = {w['id']: w for w in json.loads(WORDS.read_text())}
    records = []
    seen = set()
    for row in json.loads(SOURCE.read_text()):
        word = words.get(row['id'])
        assert word and word['meaningZh'] == row['word'], f'not in the bank: {row["id"]} {row["word"]}'
        q, a = row['questionZh'], row['answerZh']
        assert 8 <= len(q) <= 40 and q[-1] in '？。' and not LATIN.search(q), f'question: {row["word"]} {q}'
        assert row['word'] in a and 16 <= len(a) <= 80 and a[-1] in '。！？' and not LATIN.search(a), f'answer: {row["word"]} {a}'
        assert row['questionEn'].strip() and row['answerEn'].strip(), f'English: {row["word"]}'
        assert q not in seen, f'duplicate question: {q}'
        seen.add(q)
        records.append({k: row[k] for k in ('id', 'word', 'questionZh', 'questionEn', 'answerZh', 'answerEn')})
    records.sort(key=lambda r: r['id'])
    return {'schemaVersion': 1, 'records': records}


def main() -> None:
    text = json.dumps(build(), ensure_ascii=False, indent=1) + '\n'
    if '--check' in sys.argv:
        if not OUT.exists() or OUT.read_text() != text:
            sys.exit(f'{OUT} is stale. Run python3 scripts/build-taiwan-speaking.py')
    else:
        OUT.write_text(text)
    print(json.dumps({'questions': text.count('"questionZh"')}))


if __name__ == '__main__':
    main()
