# Word7000 Notices

## Vocabulary Data

The bundled vocabulary data in `src/data/words.ts` is generated from the ECDICT English-Chinese dictionary project:

- Source project: https://github.com/skywind3000/ECDICT
- Local source file used during generation: `.codex-run/ecdict.csv`
- Generated output: `src/data/words.ts`
- Source license: MIT
- Transformation date: 2026-06-28
- Transformation: filtered to 7000 single-word English entries, removed dictionary-domain noise lines, converted Simplified Chinese text to Traditional Chinese, normalized fields, and assigned app groups.

The generated app data is intended as a first-pass vocabulary base. Before final App Store release, review the word list and definitions for educational quality, local terminology preference, and any content policy concerns. The first five words are curated manually to keep the onboarding study flow natural.

## Chinese Conversion

Simplified-to-Traditional conversion is performed during data generation with `opencc-js`:

- Source project: https://github.com/nk2028/opencc-js
- Package license: MIT

## Expo project template

Parts of the original React Native app were generated from the Expo project
template, which is provided under the MIT License:

```
The MIT License (MIT)

Copyright (c) 2015-present 650 Industries, Inc. (aka Expo)

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```
