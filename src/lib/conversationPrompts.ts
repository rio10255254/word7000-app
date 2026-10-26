export type ConversationPromptMode = 'english' | 'chinese';

/** One speaking-practice card; built by speakingCards.ts (and SpeakingPractice in the native app). */
export type ConversationPromptCard = {
  keyword: string;
  keywordPronunciation: string;
  question: string;
  questionSupport: string;
  referenceAnswer: string;
  referenceTranslation: string;
};
