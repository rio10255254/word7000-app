import type { WordEntry } from '../data/words';
import { chineseMeaningPinyin, conciseChineseMeaning } from './chineseDisplay';
import type { ConversationPromptCard, ConversationPromptMode } from './conversationPrompts';

/** One reviewed question with its own model answer (content/speaking, same as the native app). */
export type SpeakingCard = {
  id: string;
  word: string;
  keywordZh: string;
  question: string;
  answerEn: string;
  answerZh: string;
};

export type SpeakingCardIndex = ReadonlyMap<string, SpeakingCard>;

export function indexSpeakingCards(cards: readonly SpeakingCard[]): SpeakingCardIndex {
  return new Map(cards.map((card) => [card.word.toLowerCase(), card]));
}

/** Kept out of the first load; speaking practice is opened by few sessions. */
export async function loadSpeakingCards(): Promise<SpeakingCardIndex> {
  const cards = (await import('../data/speaking-cards.json')).default as SpeakingCard[];
  return indexSpeakingCards(cards);
}

export function reviewedCardFor(word: WordEntry, index: SpeakingCardIndex | null): SpeakingCard | null {
  const card = index?.get(word.word.toLowerCase());
  return card && card.id.startsWith(`${word.id}-`) ? card : null;
}

/**
 * The reviewed question when the word has one, as in the native app.
 * Otherwise the learner says one sentence of their own and compares it with
 * the word's reviewed example, which is never padded into a fake answer.
 */
export function speakingPromptFor(
  word: WordEntry,
  mode: ConversationPromptMode,
  index: SpeakingCardIndex | null,
): ConversationPromptCard {
  const card = reviewedCardFor(word, index);
  const chinese = mode === 'chinese';
  if (card) {
    return {
      keyword: chinese ? card.keywordZh : card.word,
      keywordPronunciation: chinese ? chineseMeaningPinyin(card.keywordZh) : '',
      question: card.question,
      questionSupport: chinese
        ? `Answer in Chinese and try to use “${card.keywordZh}”.`
        : `試著用 ${card.word} 回答兩到三句，說出自己的經驗或想法。`,
      referenceAnswer: chinese ? card.answerZh : card.answerEn,
      referenceTranslation: chinese ? card.answerEn : card.answerZh,
    };
  }

  const keyword = conciseChineseMeaning(word.meaningZh).split('；')[0]?.trim() || word.meaningZh;
  if (chinese) {
    return {
      keyword,
      keywordPronunciation: chineseMeaningPinyin(keyword),
      question: `Say one sentence in Chinese about your own day, school or plans, using “${keyword}”.`,
      questionSupport: `English hint: “${word.word}”. Then compare your sentence with the example.`,
      referenceAnswer: word.exampleZh,
      referenceTranslation: word.example,
    };
  }
  return {
    keyword: word.word,
    keywordPronunciation: '',
    question: `Say one sentence about your own day, school or plans, using “${word.word}”.`,
    questionSupport: `試著用 ${word.word} 說一句跟自己有關的話，再和例句比較。`,
    referenceAnswer: word.example,
    referenceTranslation: word.exampleZh,
  };
}

/**
 * Words for a speaking session: the ones with reviewed questions when there
 * are enough of them, so most sessions ask real questions.
 */
export function speakingSessionPool(words: WordEntry[], index: SpeakingCardIndex | null, count: number): WordEntry[] {
  const withQuestions = words.filter((word) => reviewedCardFor(word, index));
  return withQuestions.length >= Math.min(count, words.length) && withQuestions.length > 0 ? withQuestions : words;
}
