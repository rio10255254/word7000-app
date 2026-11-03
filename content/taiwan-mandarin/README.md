# Taiwan Mandarin word bank

The words learners of Chinese study in the app (`words.json`), in bands that
follow the structure of Taiwan's TOCFL vocabulary levels: 準備級, 入門級,
基礎級, 進階級. Written for this app, not copied from any official list.

Each word has its Taiwan reading (教育部《重編國語辭典修訂本》, one syllable per
character), an English gloss and an everyday example in Taiwan Mandarin with
its English translation.

How it was made:

1. Headwords per band, Taiwan usage and readings.
2. Glosses, readings and examples for every word.
3. A second, stricter pass by a reviewer writing as a Taiwanese teacher of
   Chinese to foreigners: naturalness, Taiwan usage, band fit, glosses and
   readings. Its corrections are kept in `reviews/` (and folded into
   `words.json`), so each change has a reason.

Not yet done: comparison with the official TOCFL list, and a review by a
human teacher.

Build the app's files after changing it:

    python3 scripts/build-taiwan-words.py
    python3 scripts/build-chinese-pinyin.py   # needs pypinyin, opencc-python-reimplemented
