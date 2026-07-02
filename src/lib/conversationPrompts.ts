import type { WordEntry } from '../data/words';
import { chineseMeaningPinyin, conciseChineseMeaning } from './chineseDisplay';

export type ConversationPromptMode = 'english' | 'chinese';

export type ConversationPromptCard = {
  keyword: string;
  keywordPronunciation: string;
  question: string;
  questionSupport: string;
  referenceAnswer: string;
  referenceTranslation: string;
};

export function buildConversationPrompt(word: WordEntry, mode: ConversationPromptMode): ConversationPromptCard {
  const chineseKeyword = conciseChineseMeaning(word.meaningZh);
  const primaryChineseKeyword = chineseKeyword.split(/[；;，,、]/)[0]?.trim() || chineseKeyword;

  if (mode === 'chinese') {
    return {
      keyword: primaryChineseKeyword,
      keywordPronunciation: chineseMeaningPinyin(primaryChineseKeyword),
      question: `Use "${primaryChineseKeyword}" in your answer. Tell a short personal story connected to this idea.`,
      questionSupport: `Answer in Chinese first. If you want a hint, connect it with the English word "${word.word}".`,
      referenceAnswer: `${word.exampleZh} 我也可以補充一個自己的經驗，讓回答更像真實對話。`,
      referenceTranslation: `${word.example} I can add a personal detail to make the answer feel like a real conversation.`,
    };
  }

  return {
    keyword: word.word,
    keywordPronunciation: '',
    question: `Use "${word.word}" in your answer. Talk about a real situation related to: ${chineseKeyword}.`,
    questionSupport: '先用 2-3 句回答，不用追求完美，重點是把單字說出口。',
    referenceAnswer: `${word.example} I can add one personal detail to make the answer sound natural.`,
    referenceTranslation: `${word.exampleZh} 我可以再加上一個自己的細節，讓回答聽起來更自然。`,
  };
}
