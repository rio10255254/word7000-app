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

const politicalWord: WordEntry = {
  id: 'political',
  word: 'political',
  pronunciation: '/pəˈlɪtɪkəl/',
  partOfSpeech: 'a',
  meaningZh: '政治的；政黨的',
  example: 'The political debate lasted two hours.',
  exampleZh: '這場政治辯論持續了兩個小時。',
  group: 'Core 4',
};

const quicklyWord: WordEntry = {
  id: 'quickly',
  word: 'quickly',
  pronunciation: '/ˈkwɪkli/',
  partOfSpeech: 'adv',
  meaningZh: '快速地',
  example: 'She quickly finished the task.',
  exampleZh: '她很快完成了任務。',
  group: 'Core 1',
};

const beWord: WordEntry = {
  id: 'be',
  word: 'be',
  pronunciation: '/bi:/',
  partOfSpeech: 'v',
  meaningZh: '是, 表示, 在',
  example: 'I want to be ready before noon.',
  exampleZh: '我想在中午前準備好。',
  group: 'Core 1',
};

const andWord: WordEntry = {
  id: 'and',
  word: 'and',
  pronunciation: '/ænd/',
  partOfSpeech: 'conj',
  meaningZh: '和, 與',
  example: 'Tea and coffee are on the table.',
  exampleZh: '茶和咖啡都在桌上。',
  group: 'Core 1',
};

describe('conversation prompt cards', () => {
  test('builds an English speaking card with a natural open question', () => {
    const prompt = buildConversationPrompt(adaptWord, 'english');

    expect(prompt.keyword).toBe('adapt');
    expect(prompt.keywordPronunciation).toBe('');
    expect(prompt.question).toBe('When have you had to adapt to a new rule, place, or routine?');
    expect(prompt.question).not.toContain('Use "adapt"');
    expect(prompt.question).not.toContain('related to:');
    expect(prompt.questionSupport).toContain('adapt');
    expect(prompt.referenceAnswer).toContain('Students adapt quickly');
    expect(prompt.referenceTranslation).toContain('學生很快適應新的作息');
  });

  test('builds a political speaking prompt around public issues', () => {
    const prompt = buildConversationPrompt(politicalWord, 'english');

    expect(prompt.keyword).toBe('political');
    expect(prompt.question).toBe('What do you think is the most important political issue in your community or country right now?');
    expect(prompt.question).toContain('political issue');
    expect(prompt.question).not.toContain('政治的');
    expect(prompt.questionSupport).toContain('political');
  });

  test('builds a natural English speaking prompt for adverbs', () => {
    const prompt = buildConversationPrompt(quicklyWord, 'english');

    expect(prompt.question).toBe('How could someone act quickly in a real conversation or situation?');
    expect(prompt.question).not.toContain('a quickly situation');
  });

  test('uses natural prompts for very common function words', () => {
    const bePrompt = buildConversationPrompt(beWord, 'english');
    const andPrompt = buildConversationPrompt(andWord, 'english');

    expect(bePrompt.question).toBe('How would you describe the kind of person you want to be in the future?');
    expect(bePrompt.question).not.toBe('When would someone need to be in real life?');
    expect(andPrompt.question).toBe('What are two things you like to do, and why do they fit together?');
  });

  test('builds a Chinese speaking card with pinyin and an English instruction', () => {
    const prompt = buildConversationPrompt(adaptWord, 'chinese');

    expect(prompt.keyword).toBe('適應');
    expect(prompt.keywordPronunciation).toBe('shi ying');
    expect(prompt.question).toBe('When have you needed to 適應 a new place, rule, or routine?');
    expect(prompt.questionSupport).toContain('adapt');
    expect(prompt.referenceAnswer).toContain('學生很快適應新的作息');
    expect(prompt.referenceTranslation).toContain('Students adapt quickly');
  });

  test('uses natural Chinese-mode prompts for common function words', () => {
    const prompt = buildConversationPrompt(beWord, 'chinese');

    expect(prompt.question).toBe('How would you use 是 to describe who you are or what something is?');
    expect(prompt.question).not.toContain('need to 是');
  });
});
