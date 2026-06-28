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
