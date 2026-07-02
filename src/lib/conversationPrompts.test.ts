import { describe, expect, test } from 'vitest';
import { buildConversationPrompt } from './conversationPrompts';
import type { WordEntry } from '../data/words';

const adaptWord: WordEntry = {
  id: 'adapt',
  word: 'adapt',
  pronunciation: '/əˈdæpt/',
  partOfSpeech: 'v',
  meaningZh: '適應；調整；改編',
  example: 'Students adapt quickly to a new routine.',
  exampleZh: '學生很快適應新的作息。',
  group: 'Core 1',
};

describe('conversation prompt cards', () => {
  test('builds an English speaking card that asks the learner to use the English word', () => {
    const prompt = buildConversationPrompt(adaptWord, 'english');

    expect(prompt.keyword).toBe('adapt');
    expect(prompt.keywordPronunciation).toBe('');
    expect(prompt.question).toContain('Use "adapt"');
    expect(prompt.question).toContain('適應');
    expect(prompt.referenceAnswer).toContain('Students adapt quickly');
    expect(prompt.referenceTranslation).toContain('學生很快適應新的作息');
  });

  test('builds a Chinese speaking card with pinyin and an English instruction', () => {
    const prompt = buildConversationPrompt(adaptWord, 'chinese');

    expect(prompt.keyword).toBe('適應');
    expect(prompt.keywordPronunciation).toBe('shi ying');
    expect(prompt.question).toContain('Use "適應"');
    expect(prompt.questionSupport).toContain('adapt');
    expect(prompt.referenceAnswer).toContain('學生很快適應新的作息');
    expect(prompt.referenceTranslation).toContain('Students adapt quickly');
  });
});
