#!/usr/bin/env python3
"""Builds the reviewed pinyin lexicon the app uses for learners of Chinese.

The system's Mandarin transliteration reads each character on its own, so
words with more than one reading (銀行, 重複, 覺得, 調整, 音樂…) come out wrong.
This reads every Chinese meaning, example sentence and speaking text with
phrase context instead (pypinyin over the simplified form, which its phrase
dictionary covers), and writes one entry per text.

    pip install pypinyin opencc-python-reimplemented
    python3 scripts/build-chinese-pinyin.py
"""
import json
import re
from pathlib import Path

from opencc import OpenCC
from pypinyin import Style, lazy_pinyin

ROOT = Path(__file__).resolve().parent.parent
WORDS = ROOT / 'ios/Word7000/Resources/words.json'
SPEAKING = ROOT / 'ios/Packages/Word7000Core/Sources/Word7000Core/Resources/speaking-prompts.json'
OUT = ROOT / 'ios/Packages/Word7000Core/Sources/Word7000Core/Resources/pinyin-lexicon.json'

SEPARATORS = re.compile(r'[；;，,、]')
HAN = re.compile(r'[㐀-䶿一-鿿豈-﫿]')
PUNCTUATION = {'，': ',', '。': '.', '！': '!', '？': '?', '；': ';', '：': ':', '、': ',',
               '「': '"', '」': '"', '『': '"', '』': '"', '（': '(', '）': ')', '…': '…', '—': '—'}
# Readings Taiwan uses where the dictionary gives the mainland one.
TAIWAN = {'垃圾': ['lè', 'sè'], '星期': ['xīng', 'qí'], '期間': ['qí', 'jiān'], '危險': ['wéi', 'xiǎn']}

to_simplified = OpenCC('t2s')


TAIWAN_WORDS = ROOT / 'ios/Word7000/Resources/words-zh.json'


def read(text: str) -> str:
    """Toned pinyin, one syllable per character, punctuation kept in ASCII."""
    simplified = to_simplified.convert(text)
    if len(simplified) != len(text):
        simplified = ''.join(to_simplified.convert(ch) for ch in text)
    syllables = lazy_pinyin(simplified, style=Style.TONE, errors=lambda chars: list(chars))
    if len(syllables) != len(text):
        return ''
    for phrase, reading in TAIWAN.items():
        start = text.find(phrase)
        while start != -1:
            syllables[start:start + len(phrase)] = reading
            start = text.find(phrase, start + len(phrase))
    return render(text, syllables)


def render(text: str, syllables: list) -> str:
    """One syllable per character, punctuation kept in ASCII."""
    out = ''
    for ch, syllable in zip(text, syllables):
        if HAN.match(ch):
            out += (' ' if out and not out.endswith((' ', '"', '(')) else '') + syllable
        elif ch in PUNCTUATION:
            mark = PUNCTUATION[ch]
            out += mark + (' ' if mark in ',.!?;:)' else '')
        elif ch.isspace():
            out += ' '
        else:
            out += ('' if not out or out.endswith(' ') or not ch.isalnum() else ' ') + ch
    return re.sub(r'\s+', ' ', out).strip()


def main() -> None:
    words = json.loads(WORDS.read_text())
    texts: set[str] = set()
    for word in words:
        for field in ('meaningZh', 'supplementalMeaningZh'):
            for part in SEPARATORS.split(word.get(field) or ''):
                if HAN.search(part.strip()):
                    texts.add(part.strip())
        if HAN.search(word.get('exampleZh') or ''):
            texts.add(word['exampleZh'].strip())
    for record in json.loads(SPEAKING.read_text())['records']:
        for field in ('keywordZh', 'answerZh', 'questionZh'):
            value = (record.get(field) or '').strip()
            if HAN.search(value):
                texts.add(value)
                texts.update(part for part in value.split('…') if HAN.search(part))
    lexicon = {text: reading for text in sorted(texts) if (reading := read(text))}
    # The Taiwan Mandarin bank brings its own reviewed readings; its examples
    # take the headword's reading wherever the headword appears.
    if TAIWAN_WORDS.exists():
        for entry in json.loads(TAIWAN_WORDS.read_text()):
            head, reading = entry['meaningZh'], entry['pronunciation']
            lexicon[head] = reading
            example = entry['exampleZh']
            sentence = read(example)
            if not sentence:
                continue
            syllables = lazy_pinyin(to_simplified.convert(example), style=Style.TONE, errors=lambda chars: list(chars))
            if len(syllables) == len(example):
                start = example.find(head)
                while start != -1:
                    syllables[start:start + len(head)] = reading.split(' ')
                    start = example.find(head, start + len(head))
                sentence = render(example, syllables)
            lexicon[example] = sentence
    taiwan_speaking = ROOT / 'ios/Packages/Word7000Core/Sources/Word7000Core/Resources/speaking-zh.json'
    if taiwan_speaking.exists():
        heads = {e['meaningZh']: e['pronunciation'] for e in json.loads(TAIWAN_WORDS.read_text())}
        for record in json.loads(taiwan_speaking.read_text())['records']:
            for text in (record['questionZh'], record['answerZh']):
                syllables = lazy_pinyin(to_simplified.convert(text), style=Style.TONE, errors=lambda chars: list(chars))
                if len(syllables) != len(text):
                    continue
                head = record['word']
                start = text.find(head)
                while start != -1 and head in heads:
                    syllables[start:start + len(head)] = heads[head].split(' ')
                    start = text.find(head, start + len(head))
                lexicon[text] = render(text, syllables)
    lexicon = dict(sorted(lexicon.items()))
    OUT.write_text(json.dumps(lexicon, ensure_ascii=False, separators=(',', ':'), sort_keys=True) + '\n')
    print(json.dumps({'entries': len(lexicon), 'bytes': OUT.stat().st_size}))


if __name__ == '__main__':
    main()
