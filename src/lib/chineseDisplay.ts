import { customPinyin, pinyin } from 'pinyin-pro';

customPinyin({
  調整: 'tiao zheng',
});

const meaningSeparatorPattern = /[；;，,、]/;

function meaningParts(meaning: string): string[] {
  return meaning
    .split(meaningSeparatorPattern)
    .map((part) => part.trim())
    .filter(Boolean)
    .filter((part, index, parts) => parts.indexOf(part) === index);
}

export function conciseChineseMeaning(meaning: string): string {
  const parts = meaningParts(meaning);
  return parts.length > 0 ? parts.slice(0, 2).join('；') : meaning.trim();
}

export function supplementalChineseMeaning(meaning: string): string {
  return meaningParts(meaning).slice(2).join('；');
}

export function chineseMeaningPinyin(meaning: string): string {
  return pinyin(meaning, { toneType: 'none', type: 'array', nonZh: 'removed' }).join(' ');
}

export function chineseMeaningDisplay(meaning: string): {
  primary: string;
  supplemental: string;
  pinyin: string;
} {
  const primary = conciseChineseMeaning(meaning);
  return {
    primary,
    supplemental: supplementalChineseMeaning(meaning),
    pinyin: chineseMeaningPinyin(primary),
  };
}
