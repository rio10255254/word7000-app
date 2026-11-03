#!/usr/bin/env python3
"""Builds the Taiwan Mandarin word bank learners of Chinese study.

Source: content/taiwan-mandarin/words.json, the reviewed list in TOCFL-style
bands (準備級, 入門級, 基礎級, 進階級), each word with its Taiwan reading
(教育部《重編國語辭典修訂本》), an English gloss and an everyday Taiwan
example. Output: ios/Word7000/Resources/words-zh.json in the app's
WordEntry shape, where the Chinese is the meaning learners of Chinese are
shown and the English gloss is the answer. The bands are spread over the
fourteen levels the learning engine paces new words by.

    python3 scripts/build-taiwan-words.py [--check]
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / 'content/taiwan-mandarin/words.json'
OUT = ROOT / 'ios/Word7000/Resources/words-zh.json'

# Which of the engine's fourteen levels each band covers. The engine starts a
# new learner around level 4 and draws a level or two above, so the novice
# band spans levels 1-5: a beginner meets 準備級 and early 入門級 words first.
BAND_LEVELS = {'準備級': (1, 5), '入門級': (6, 7), '基礎級': (8, 10), '進階級': (11, 14)}
HAN = re.compile(r'^[㐀-䶿一-鿿豈-﫿]+$')
SYLLABLE = re.compile(r"^[a-zāáǎàēéěèīíǐìōóǒòūúǔùǖǘǚǜü]+$")


def validate(entry: dict) -> None:
    word = entry['word']
    assert HAN.match(word), f'not all Han: {word}'
    syllables = entry['pinyin'].split(' ')
    assert len(syllables) == len(word), f'pinyin syllables: {word} {entry["pinyin"]}'
    assert all(SYLLABLE.match(s) for s in syllables), f'pinyin: {word} {entry["pinyin"]}'
    assert entry['gloss'].strip() and len(entry['gloss']) <= 60, f'gloss: {word}'
    example = entry['example']
    assert word in example and re.search(r'[。？！]$', example) and not re.search(r'[A-Za-z]', example), f'example: {word} {example}'
    assert entry['exampleEn'].strip(), f'exampleEn: {word}'
    assert entry['band'] in BAND_LEVELS, f'band: {word}'


def build() -> list:
    words = json.loads(SOURCE.read_text())
    seen = set()
    for entry in words:
        validate(entry)
        assert entry['word'] not in seen, f'duplicate: {entry["word"]}'
        seen.add(entry['word'])
    out = []
    for band, (first, last) in BAND_LEVELS.items():
        rows = [w for w in words if w['band'] == band]
        span = last - first + 1
        for index, entry in enumerate(rows):
            level = first + min(span - 1, index * span // max(1, len(rows)))
            out.append({
                'word': entry['gloss'],
                'partOfSpeech': entry['pos'],
                'pronunciation': entry['pinyin'],
                'meaningZh': entry['word'],
                'example': entry['exampleEn'],
                'exampleZh': entry['example'],
                'group': f'Core {level}',
            })
    for index, entry in enumerate(out):
        entry['id'] = f't{index + 1:04d}'
    order = ['id', 'word', 'partOfSpeech', 'pronunciation', 'meaningZh', 'example', 'exampleZh', 'group']
    return [{key: entry[key] for key in order} for entry in out]


def main() -> None:
    text = json.dumps(build(), ensure_ascii=False, indent=1) + '\n'
    if '--check' in sys.argv:
        if not OUT.exists() or OUT.read_text() != text:
            sys.exit(f'{OUT} is stale. Run python3 scripts/build-taiwan-words.py')
    else:
        OUT.write_text(text)
    print(json.dumps({'words': text.count('"id"')}))


if __name__ == '__main__':
    main()
