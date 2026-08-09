const meaningSeparatorPattern = /[；;，,、]/;
const meaningPartsCache = new Map<string, string[]>();
const pinyinCache = new Map<string, string>();
const displayCache = new Map<string, ChineseMeaningDisplay>();
let pinyinReady = false;

type ChineseMeaningDisplay = {
  primary: string;
  supplemental: string;
  pinyin: string;
};

function getPinyinTools(): typeof import('pinyin-pro') {
  const tools = require('pinyin-pro') as typeof import('pinyin-pro');
  if (!pinyinReady) {
    tools.customPinyin({
      調整: 'tiao zheng',
      敢於: 'gan yu',
    });
    pinyinReady = true;
  }
  return tools;
}

function meaningParts(meaning: string): string[] {
  const cached = meaningPartsCache.get(meaning);
  if (cached) {
    return cached;
  }

  const parts = meaning
    .split(meaningSeparatorPattern)
    .map((part) => part.trim())
    .filter(Boolean)
    .filter((part, index, parts) => parts.indexOf(part) === index);
  meaningPartsCache.set(meaning, parts);
  return parts;
}

export function conciseChineseMeaning(meaning: string): string {
  const parts = meaningParts(meaning);
  return parts.length > 0 ? parts.slice(0, 2).join('；') : meaning.trim();
}

export function supplementalChineseMeaning(meaning: string): string {
  return meaningParts(meaning).slice(2).join('；');
}

export function chineseMeaningPinyin(meaning: string): string {
  const cached = pinyinCache.get(meaning);
  if (cached !== undefined) {
    return cached;
  }

  const { pinyin } = getPinyinTools();
  const prepared = meaningParts(meaning)
    .map((part) => pinyin(part, { toneType: 'none', type: 'array', nonZh: 'removed' }).join(' '))
    .filter(Boolean)
    .join('；');
  pinyinCache.set(meaning, prepared);
  return prepared;
}

export function chineseMeaningDisplay(meaning: string): ChineseMeaningDisplay {
  const cached = displayCache.get(meaning);
  if (cached) {
    return cached;
  }

  const primary = conciseChineseMeaning(meaning);
  const display = {
    primary,
    supplemental: supplementalChineseMeaning(meaning),
    pinyin: chineseMeaningPinyin(primary),
  };
  displayCache.set(meaning, display);
  return display;
}
