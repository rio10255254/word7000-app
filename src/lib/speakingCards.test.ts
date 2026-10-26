import { describe, expect, test } from 'vitest';
import fs from 'node:fs';
import path from 'node:path';
import type { WordEntry } from '../data/words';
import { indexSpeakingCards, reviewedCardFor, speakingPromptFor, speakingSessionPool, type SpeakingCard } from './speakingCards';

const adapt: WordEntry = {
  id: 'w0001', word: 'adapt', partOfSpeech: 'vt / vi', pronunciation: '/ә\'dæpt/', meaningZh: '適應', supplementalMeaningZh: '調整；改編',
  example: 'Children adapt to new bus routes after a few rainy mornings.', exampleZh: '連續幾個下雨的早晨後，孩子們逐漸習慣了新的公車路線。', group: 'Core 1',
};
const brief: WordEntry = { ...adapt, id: 'w0002', word: 'brief', meaningZh: '簡短的', example: 'Mina sent a brief voice message before boarding the train.', exampleZh: '美娜上車前傳了一段簡短的語音訊息。' };
const card: SpeakingCard = {
  id: 'w0001-reviewed-1', word: 'adapt', keywordZh: '適應',
  question: 'When have you had to adapt to a new rule, place, or routine?',
  answerEn: 'I had to adapt when I entered a new school. The schedule felt confusing at first.',
  answerZh: '我進入新學校時必須適應。一開始作息讓我覺得很混亂。',
};
const index = indexSpeakingCards([card]);

describe('speaking cards on the web', () => {
  test('asks the reviewed question with its own answer, in both practice directions', () => {
    expect(speakingPromptFor(adapt, 'english', index)).toMatchObject({
      keyword: 'adapt', question: card.question, referenceAnswer: card.answerEn, referenceTranslation: card.answerZh,
    });
    const chinese = speakingPromptFor(adapt, 'chinese', index);
    expect(chinese).toMatchObject({ keyword: '適應', question: card.question, referenceAnswer: card.answerZh, referenceTranslation: card.answerEn });
    expect(chinese.keywordPronunciation).not.toBe('');
  });

  test('falls back to a sentence of the learner\'s own, compared with the reviewed example', () => {
    const english = speakingPromptFor(brief, 'english', index);
    expect(english.question).toContain('“brief”');
    expect(english.referenceAnswer).toBe(brief.example);
    expect(english.referenceTranslation).toBe(brief.exampleZh);
    const chinese = speakingPromptFor(brief, 'chinese', null);
    expect(chinese.keyword).toBe('簡短的');
    expect(chinese.referenceAnswer).toBe(brief.exampleZh);
    for (const prompt of [english, chinese]) {
      expect(`${prompt.question} ${prompt.referenceAnswer} ${prompt.referenceTranslation}`).not.toMatch(/I would add one personal reason|我會再補上/);
    }
  });

  test('only matches a card made for that very word', () => {
    expect(reviewedCardFor(adapt, index)).toBe(card);
    expect(reviewedCardFor({ ...adapt, id: 'w9999' }, index)).toBeNull();
    expect(reviewedCardFor(adapt, null)).toBeNull();
  });

  test('builds speaking sessions from words with reviewed questions when there are enough', () => {
    expect(speakingSessionPool([adapt, brief], index, 1)).toEqual([adapt]);
    expect(speakingSessionPool([adapt, brief], index, 2)).toEqual([adapt, brief]);
    expect(speakingSessionPool([brief], index, 10)).toEqual([brief]);
    expect(speakingSessionPool([adapt, brief], null, 1)).toEqual([adapt, brief]);
  });

  test('ships the same reviewed cards as the native app', () => {
    const native = JSON.parse(fs.readFileSync(path.join(process.cwd(), 'ios/Packages/Word7000Core/Sources/Word7000Core/Resources/speaking-prompts.json'), 'utf8'));
    const web = JSON.parse(fs.readFileSync(path.join(process.cwd(), 'src/data/speaking-cards.json'), 'utf8'));
    expect(web).toEqual(native.records);
  });
});
