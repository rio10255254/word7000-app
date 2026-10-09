import { describe, expect, test } from 'vitest';
import { linesFromPlainText, parseScannedLines, type ScannedLine } from './scanParser';

function line(text: string, x: number, y: number, width = 0.3, height = 0.03): ScannedLine {
  return { height, text, width, x, y };
}

function pairs(lines: ScannedLine[]) {
  return parseScannedLines(lines).map(({ meaningZh, partOfSpeech, word }) => ({ meaningZh, partOfSpeech, word }));
}

describe('scan parser', () => {
  test('reads a word and its printed meaning on the same line', () => {
    expect(pairs([line('abandon v. 放棄；遺棄', 0.1, 0.1)])).toEqual([
      { meaningZh: '放棄；遺棄', partOfSpeech: 'v', word: 'abandon' },
    ]);
  });

  test('handles numbering, brackets around the part of speech and full-width text', () => {
    expect(pairs([
      line('1. ability (n.) 能力', 0.1, 0.1),
      line('２．ａｂｓｅｎｔ　adj. 缺席的', 0.1, 0.15),
      line('③ look forward to 期待', 0.1, 0.2),
    ])).toEqual([
      { meaningZh: '能力', partOfSpeech: 'n', word: 'ability' },
      { meaningZh: '缺席的', partOfSpeech: 'adj', word: 'absent' },
      { meaningZh: '期待', partOfSpeech: '', word: 'look forward to' },
    ]);
  });

  test('pairs a two-column table where words and meanings are separate lines', () => {
    expect(pairs([
      line('meaning', 0.55, 0.1, 0.2),
      line('benefit', 0.1, 0.1, 0.2),
      line('好處；利益', 0.55, 0.2, 0.2),
      line('capture', 0.1, 0.2, 0.2),
      line('捕獲', 0.55, 0.1, 0.2),
    ])).toEqual([
      { meaningZh: '捕獲', partOfSpeech: '', word: 'benefit' },
      { meaningZh: '好處；利益', partOfSpeech: '', word: 'capture' },
    ]);
  });

  test('pairs a meaning printed under its word', () => {
    expect(pairs([
      line('decline', 0.1, 0.1),
      line('下降；婉拒', 0.1, 0.135),
      line('elect', 0.1, 0.2),
      line('選舉', 0.1, 0.235),
    ])).toEqual([
      { meaningZh: '下降；婉拒', partOfSpeech: '', word: 'decline' },
      { meaningZh: '選舉', partOfSpeech: '', word: 'elect' },
    ]);
  });

  test('splits two pairs that the recogniser merged into one line', () => {
    expect(pairs([line('fierce a. 兇猛的 gather v. 聚集', 0.05, 0.1, 0.9)])).toEqual([
      { meaningZh: '兇猛的', partOfSpeech: 'a', word: 'fierce' },
      { meaningZh: '聚集', partOfSpeech: 'v', word: 'gather' },
    ]);
  });

  test('ignores example sentences and their translations', () => {
    expect(pairs([
      line('harvest n. 收成', 0.1, 0.1),
      line('The farmers celebrated the harvest.', 0.1, 0.14, 0.8),
      line('農夫們慶祝收成。', 0.1, 0.18, 0.5),
      line('He left early. 他很早離開。', 0.1, 0.22, 0.8),
    ])).toEqual([{ meaningZh: '收成', partOfSpeech: 'n', word: 'harvest' }]);
  });

  test('drops words with no meaning and keeps the first copy of a repeated word', () => {
    expect(pairs([
      line('ignore', 0.1, 0.1),
      line('journey n. 旅程', 0.1, 0.3),
      line('journey n. 旅行', 0.1, 0.4),
      line('第三課', 0.6, 0.6),
    ])).toEqual([{ meaningZh: '旅程', partOfSpeech: 'n', word: 'journey' }]);
  });

  test('keeps multiple parts of speech and alternate spellings readable', () => {
    expect(pairs([line('colour/color n./v. 顏色；著色', 0.1, 0.1)])).toEqual([
      { meaningZh: '顏色；著色', partOfSpeech: 'n / v', word: 'colour' },
    ]);
  });

  test('does not let a word above steal the meaning of the word directly below', () => {
    expect(pairs([
      line('kettle', 0.1, 0.1),
      line('ladder', 0.1, 0.135),
      line('梯子', 0.1, 0.17),
    ])).toEqual([{ meaningZh: '梯子', partOfSpeech: '', word: 'ladder' }]);
  });
});

describe('pasted text', () => {
  test('parses copied lines in order, including meanings on the next line', () => {
    expect(pairs(linesFromPlainText('abandon v. 放棄\n\nbenefit\n好處\nThe benefit is clear.\n'))).toEqual([
      { meaningZh: '放棄', partOfSpeech: 'v', word: 'abandon' },
      { meaningZh: '好處', partOfSpeech: '', word: 'benefit' },
    ]);
  });
});
