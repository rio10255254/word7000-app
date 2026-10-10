import fs from 'node:fs';
import path from 'node:path';
import { describe, expect, test } from 'vitest';
import { sampleWords, type WordEntry } from './data/words';
import {
  chineseMeaningDisplay,
  chineseMeaningPinyin,
  conciseChineseMeaning,
  supplementalChineseMeaning,
} from './lib/chineseDisplay';
import { buildConversationPrompt } from './lib/conversationPrompts';

/**
 * Golden results for the Swift ports of chineseDisplay.ts and
 * conversationPrompts.ts, replayed by
 * ios/Packages/Word7000Core/Tests/Word7000CoreTests/ChineseParityTests.swift.
 * Pinyin is kept separate because the Swift side uses the system
 * transliterator instead of pinyin-pro, so heteronyms can differ.
 * Run with UPDATE_NATIVE_FIXTURES=1 after an intentional rule change.
 */
const fixturePath = path.join(process.cwd(), 'ios/Packages/Word7000Core/Tests/Word7000CoreTests/parity-chinese.json');

const exactQuestionWords = ['be', 'and', 'of', 'to', 'have', 'for', 'that', 'he', 'you', 'with', 'on', 'do', 'not', 'they', 'this', 'at', 'say', 'but', 'by', 'we'];

// One word per topic branch, so every branch of the question builders is replayed.
const topicTerms = ['政治', 'vote', '適應', '調整', '問題', '危險', '情緒', '快樂', 'love', '朋友', '團隊', '工作', '學習'];

function pickWords(): WordEntry[] {
  const picked = new Map<string, WordEntry>();
  const add = (word: WordEntry | undefined) => {
    if (word && !picked.has(word.id)) {
      picked.set(word.id, word);
    }
  };

  for (let index = 0; index < sampleWords.length; index += 140) {
    add(sampleWords[index]);
  }
  add(sampleWords[sampleWords.length - 1]);
  for (const exact of exactQuestionWords) {
    add(sampleWords.find((word) => word.word.toLowerCase() === exact));
  }
  for (const term of topicTerms) {
    add(sampleWords.find((word) => `${word.word.toLowerCase()} ${word.meaningZh.toLowerCase()}`.includes(term)));
  }
  for (const pos of ['adv', 'a', 'v', 'n', 'prep', 'conj']) {
    add(sampleWords.find((word, index) => index > 3000 && word.partOfSpeech.toLowerCase().split(/[\/,;]/)[0]?.trim() === pos));
  }
  return [...picked.values()];
}

function buildFixtures() {
  const words = pickWords();
  const pinyinTexts = new Set<string>(['調整', '敢於', '調整好；敢於說', '綠色', '女人']);
  const cases = words.map((word) => {
    const english = buildConversationPrompt(word, 'english');
    const chinese = buildConversationPrompt(word, 'chinese');
    const display = chineseMeaningDisplay(word.meaningZh);
    pinyinTexts.add(word.meaningZh);
    pinyinTexts.add(display.primary);
    pinyinTexts.add(chinese.keyword);
    return {
      id: word.id,
      word: word.word,
      concise: conciseChineseMeaning(word.meaningZh),
      supplemental: supplementalChineseMeaning(word.meaningZh),
      english,
      chinese,
    };
  });
  const pinyin = [...pinyinTexts].map((text) => ({ text, pinyin: chineseMeaningPinyin(text) }));
  return { cases, pinyin };
}

describe('native Chinese parity fixtures', () => {
  test('the Swift Chinese display and speaking prompts replay the same golden results', () => {
    const fixtures = `${JSON.stringify(buildFixtures(), null, 1)}\n`;
    if (process.env.UPDATE_NATIVE_FIXTURES === '1' || !fs.existsSync(fixturePath)) {
      fs.mkdirSync(path.dirname(fixturePath), { recursive: true });
      fs.writeFileSync(fixturePath, fixtures);
    }
    expect(fs.readFileSync(fixturePath, 'utf8')).toBe(fixtures);
  });
});
