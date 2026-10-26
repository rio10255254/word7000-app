import { describe, expect, it } from 'vitest';
import fs from 'node:fs';
import { chunkSpeaking, chunkWords, correctionsFrom, exampleProblem, meaningProblem, readSpeaking, requestFor, speakingCorrectionsFrom, speakingProblem, speakingRequestFor } from './claude-review-words.mjs';

const word = (id, text, core = 1, overrides = {}) => ({
  id, word: text, core, group: `Core ${core}`, partOfSpeech: 'n', meaningZh: '公車', supplementalMeaningZh: '巴士',
  example: `We waited for the ${text} near the school gate today.`, exampleZh: '我們今天在校門附近等公車。', ...overrides,
});

describe('Claude word review', () => {
  it('splits each Core into requests of twenty words with stable ids', () => {
    const words = [...Array.from({ length: 45 }, (_, index) => word(`a${index}`, `w${index}`, 1)), word('b0', 'bus', 2)];
    const chunks = chunkWords(words);
    expect(chunks.map((chunk) => [chunk.id, chunk.words.length])).toEqual([['core1-001', 20], ['core1-002', 20], ['core1-003', 5], ['core2-001', 1]]);
  });

  it('asks for structured output and sends the entries as data', () => {
    const request = requestFor({ id: 'core1-001', words: [word('a1', 'bus')] }, 'claude-opus-5-5', 'medium');
    expect(request.custom_id).toBe('core1-001');
    expect(request.params.model).toBe('claude-opus-5-5');
    expect(request.params.output_config).toMatchObject({ effort: 'medium', format: { type: 'json_schema' } });
    expect(request.params).not.toHaveProperty('temperature');
    expect(JSON.parse(request.params.messages[0].content).entries[0]).toEqual({
      word: 'bus', partOfSpeech: 'n', meaningZh: '公車', supplementalMeaningZh: '巴士',
      example: 'We waited for the bus near the school gate today.', exampleZh: '我們今天在校門附近等公車。',
    });
  });

  it('checks replacements against the rules the apply scripts enforce', () => {
    expect(meaningProblem('公車', '巴士；客運')).toBeNull();
    expect(meaningProblem('公車，巴士', '')).not.toBeNull();
    expect(meaningProblem('公車', '一；二；三；四')).not.toBeNull();
    expect(exampleProblem('bus', 'We waited for the bus near the school gate today.', '我們今天在校門附近等公車。')).toBeNull();
    expect(exampleProblem('bus', 'The bus came.', '公車來了，大家都上車了。')).toMatch(/English/);
    expect(exampleProblem('bus', 'We waited for the train near the school gate today.', '我們今天在校門附近等公車。')).toMatch(/contain/);
    expect(exampleProblem('bus', 'We waited for the bus near the school gate today', '我們今天在校門附近等公車。')).toMatch(/punctuation/);
  });

  it('keeps only changed, valid fields and sets the rest aside', () => {
    const current = [word('a1', 'bus'), word('a2', 'video', 1, { meaningZh: '視頻', supplementalMeaningZh: '' })];
    const found = correctionsFrom(current, [
      // Example fixed, meaning copied unchanged.
      { word: 'Bus', meaningZh: '公車', supplementalMeaningZh: '巴士', example: 'We waited for the bus near the school gate after class.', exampleZh: '下課後我們在校門附近等公車。', reason: '補上時間' },
      // Meaning fixed, but the new example breaks the length rule.
      { word: 'video', meaningZh: '影片', supplementalMeaningZh: '', example: 'Nice video!', exampleZh: '好影片！', reason: '視頻是中國用語' },
      { word: 'train', meaningZh: '火車', supplementalMeaningZh: '', example: '', exampleZh: '', reason: 'x' },
    ]);
    expect(found.meanings).toEqual([{ core: 1, word: 'video', reason: '視頻是中國用語', primaryMeaningZh: '影片', supplementalMeaningZh: '', before: { primaryMeaningZh: '視頻', supplementalMeaningZh: '' } }]);
    expect(found.examples.map((row) => [row.word, row.example])).toEqual([['bus', 'We waited for the bus near the school gate after class.']]);
    expect(found.rejected.map((row) => [row.word, row.problem])).toEqual([['video', 'English is 2 words; expected 8-22'], ['train', 'not in this request']]);
  });

  describe('speaking cards', () => {
    const vocabulary = JSON.parse(fs.readFileSync('ios/Word7000/Resources/words.json', 'utf8'));
    const cards = readSpeaking();
    const card = cards[0];

    it('reads all 600 cards and asks about them in requests of twenty', () => {
      expect(cards).toHaveLength(600);
      expect(chunkSpeaking(cards)).toHaveLength(30);
      const request = speakingRequestFor(chunkSpeaking(cards)[0], 'claude-sonnet-5-5', 'medium');
      expect(request.custom_id).toBe('speaking-001');
      expect(JSON.parse(request.params.messages[0].content).cards[0]).toEqual({
        word: card.word, keywordZh: card.keywordZh, question: card.question, answerEn: card.answerEn, answerZh: card.answerZh,
      });
    });

    it('checks cards against the rules the speaking library build enforces', () => {
      expect(speakingProblem(card, vocabulary)).toBeNull();
      expect(speakingProblem({ ...card, answerEn: 'Too short.' }, vocabulary)).toMatch(/target|length|development/);
      expect(speakingProblem({ ...card, answerZh: '沒有關鍵字的翻譯。' }, vocabulary)).toMatch(/Chinese target/);
    });

    it('keeps changed, valid cards and sets the rest aside', () => {
      const better = `${card.answerEn} It took a few weeks, but now it feels normal.`;
      const found = speakingCorrectionsFrom([card, cards[1]], [
        { word: card.word, keywordZh: card.keywordZh, question: card.question, answerEn: better, answerZh: card.answerZh, reason: '補充' },
        { word: cards[1].word, keywordZh: cards[1].keywordZh, question: cards[1].question, answerEn: cards[1].answerEn, answerZh: cards[1].answerZh, reason: '沒改' },
        { word: card.word, keywordZh: card.keywordZh, question: 'Why?', answerEn: card.answerEn, answerZh: card.answerZh, reason: '重複' },
      ], vocabulary);
      expect(found.speaking.map((row) => [row.word, row.answerEn])).toEqual([[card.word, better]]);
      expect(found.speaking[0].before.answerEn).toBe(card.answerEn);
      expect(found.rejected.map((row) => row.problem)).toEqual(['reported twice']);
    });
  });
});
