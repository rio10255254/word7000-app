import { describe, expect, test } from 'vitest';
import {
  chineseMeaningDisplay,
  chineseMeaningPinyin,
  conciseChineseMeaning,
  supplementalChineseMeaning,
} from './chineseDisplay';

describe('Chinese word display helpers', () => {
  test('keeps only the first two Chinese meanings as the primary display', () => {
    expect(conciseChineseMeaning('適應；調整；改編')).toBe('適應；調整');
    expect(conciseChineseMeaning('看見, 查看, 參觀, 理解')).toBe('看見；查看');
  });

  test('moves the remaining Chinese meanings into a supplemental display', () => {
    expect(supplementalChineseMeaning('適應；調整；改編')).toBe('改編');
    expect(supplementalChineseMeaning('看見, 查看, 參觀, 理解')).toBe('參觀；理解');
    expect(supplementalChineseMeaning('香蕉')).toBe('');
  });

  test('adds pinyin for the concise Chinese meaning', () => {
    const display = chineseMeaningDisplay('中文；漢語；中國話');

    expect(display.primary).toBe('中文；漢語');
    expect(display.supplemental).toBe('中國話');
    expect(display.pinyin).toBe('zhong wen han yu');
  });

  test('normalizes tone marks so pinyin is easy to scan in compact cards', () => {
    expect(chineseMeaningPinyin('適應；調整')).toBe('shi ying tiao zheng');
  });
});
