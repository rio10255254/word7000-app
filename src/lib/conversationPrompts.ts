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

type PromptContext = {
  chineseKeyword: string;
  primaryChineseKeyword: string;
  word: WordEntry;
  wordLower: string;
  meaningLower: string;
};

function includesAny(source: string, terms: readonly string[]) {
  return terms.some((term) => source.includes(term));
}

function primaryPartOfSpeech(partOfSpeech: string) {
  return partOfSpeech.toLowerCase().split(/[\/,;]/)[0]?.trim() ?? '';
}

const englishExactQuestions: Record<string, string> = {
  be: 'How would you describe the kind of person you want to be in the future?',
  and: 'What are two things you like to do, and why do they fit together?',
  of: 'What is one part of your daily life that feels important to you?',
  to: 'Where would you like to go to learn something new?',
  have: 'What is something useful you have learned recently?',
  for: 'What is one goal you are working for this year?',
  that: 'What is one decision that changed your day recently?',
  he: 'Who is a person you admire, and what does he do well?',
  you: 'What is something you want to improve this month?',
  with: 'Who do you like to spend time with, and what do you usually do together?',
  on: 'What is something on your desk or table right now, and why is it there?',
  do: 'What do you usually do when you need to focus?',
  not: 'What is one habit you try not to do too often?',
  they: 'Who are people you trust, and why do they matter to you?',
  this: 'What is one thing this week that made you feel proud?',
  at: 'Where do you usually feel most focused at school, work, or home?',
  say: 'What would you say to a friend who feels nervous?',
  but: 'What is something difficult but worth doing?',
  by: 'What is one skill you improved by practicing?',
  we: 'What is something we can do to make a team work better?',
};

function pickChineseKeyword(context: PromptContext, preferred: readonly string[]) {
  return preferred.find((term) => context.chineseKeyword.includes(term)) ?? context.primaryChineseKeyword;
}

const chineseExactQuestionBuilders: Record<string, (context: PromptContext) => string> = {
  be: (context) => `How would you use ${pickChineseKeyword(context, ['是'])} to describe who you are or what something is?`,
  and: (context) => `What two ideas could you connect with ${pickChineseKeyword(context, ['和', '與'])}?`,
  of: (context) => `How would you use ${pickChineseKeyword(context, ['的'])} to describe something that belongs to someone?`,
  to: (context) => `How would you use ${pickChineseKeyword(context, ['到'])} to say where you are going?`,
  have: (context) => `What is something you can say you ${pickChineseKeyword(context, ['有'])} in your life?`,
  for: (context) => `How would you use ${pickChineseKeyword(context, ['為'])} to explain who something is for?`,
  that: (context) => `How would you use ${pickChineseKeyword(context, ['那'])} to point to something far from you?`,
  he: (context) => `How would you introduce someone using ${pickChineseKeyword(context, ['他'])}?`,
  you: (context) => `What friendly question could you ask with ${pickChineseKeyword(context, ['你'])}?`,
  with: (context) => `How would you use ${pickChineseKeyword(context, ['和'])} to talk about someone you spend time with?`,
  on: (context) => `How would you use ${pickChineseKeyword(context, ['在'])} to say where something is?`,
  do: (context) => `What is something you often ${pickChineseKeyword(context, ['做'])} on a normal day?`,
  not: (context) => `What is one thing you would say you ${pickChineseKeyword(context, ['不'])} want to do?`,
  they: (context) => `How would you describe a group of people using ${pickChineseKeyword(context, ['他們'])}?`,
  this: (context) => `How would you use ${pickChineseKeyword(context, ['這'])} to talk about something near you?`,
  at: (context) => `How would you use ${pickChineseKeyword(context, ['在'])} to say where something happens?`,
  say: (context) => `What would you ${pickChineseKeyword(context, ['說'])} to encourage a friend?`,
  but: (context) => `How would you use ${pickChineseKeyword(context, ['但是'])} to show two different ideas?`,
  by: (context) => `How would you use ${pickChineseKeyword(context, ['由', '被'])} to explain who did something?`,
  we: (context) => `What is something ${pickChineseKeyword(context, ['我們'])} can do together?`,
};

function buildEnglishQuestion(context: PromptContext) {
  const { meaningLower, primaryChineseKeyword, word, wordLower } = context;
  const topicSource = `${wordLower} ${meaningLower}`;
  const exactQuestion = englishExactQuestions[wordLower];

  if (exactQuestion) {
    return exactQuestion;
  }

  if (includesAny(topicSource, ['politic', 'government', 'election', 'democracy', 'vote', 'policy', '政治', '政府', '選舉', '民主', '政黨'])) {
    return 'What do you think is the most important political issue in your community or country right now?';
  }

  if (includesAny(topicSource, ['adapt', 'adjust', 'accommodate', '適應', '調整'])) {
    return `When have you had to ${word.word} to a new rule, place, or routine?`;
  }

  if (includesAny(topicSource, ['problem', 'risk', 'danger', 'challenge', '困難', '問題', '危險', '挑戰', '風險'])) {
    return `What is a real problem where ${word.word} would be an important idea to explain?`;
  }

  if (includesAny(topicSource, ['emotion', 'happy', 'sad', 'angry', 'fear', 'love', 'hope', '情緒', '快樂', '悲傷', '生氣', '害怕', '希望'])) {
    return `When might someone feel ${word.word}, and what should they do next?`;
  }

  if (includesAny(topicSource, ['friend', 'family', 'relationship', 'team', '朋友', '家庭', '關係', '團隊'])) {
    return `How can ${word.word} affect a friendship, family, or team?`;
  }

  if (includesAny(topicSource, ['work', 'job', 'study', 'school', 'learn', '工作', '職業', '學習', '學校'])) {
    return `How could ${word.word} matter at work or in school?`;
  }

  const part = primaryPartOfSpeech(word.partOfSpeech);
  if (part.startsWith('v')) {
    return `When would someone need to ${word.word} in real life?`;
  }

  if (part.startsWith('adv')) {
    return `How could someone act ${word.word} in a real conversation or situation?`;
  }

  if (part.startsWith('a')) {
    return `Can you describe a ${word.word} situation you have seen or heard about?`;
  }

  return `Why might ${word.word} be important when people talk about ${primaryChineseKeyword}?`;
}

function buildChineseModeQuestion(context: PromptContext) {
  const { meaningLower, primaryChineseKeyword, word, wordLower } = context;
  const topicSource = `${wordLower} ${meaningLower}`;
  const exactQuestionBuilder = chineseExactQuestionBuilders[wordLower];

  if (exactQuestionBuilder) {
    return exactQuestionBuilder(context);
  }

  if (includesAny(topicSource, ['politic', 'government', 'election', 'democracy', 'vote', 'policy', '政治', '政府', '選舉', '民主', '政黨'])) {
    return `What 政治 issue do people around you talk about most often?`;
  }

  if (includesAny(topicSource, ['adapt', 'adjust', 'accommodate', '適應', '調整'])) {
    return `When have you needed to ${primaryChineseKeyword} a new place, rule, or routine?`;
  }

  if (includesAny(topicSource, ['problem', 'risk', 'danger', 'challenge', '困難', '問題', '危險', '挑戰', '風險'])) {
    return `What real-life 問題 could you explain with ${primaryChineseKeyword}?`;
  }

  if (includesAny(topicSource, ['emotion', 'happy', 'sad', 'angry', 'fear', 'love', 'hope', '情緒', '快樂', '悲傷', '生氣', '害怕', '希望'])) {
    return `When might someone feel ${primaryChineseKeyword}, and why?`;
  }

  const part = primaryPartOfSpeech(word.partOfSpeech);
  if (part.startsWith('v')) {
    return `When would someone need to ${primaryChineseKeyword} in everyday life?`;
  }

  if (part.startsWith('adv')) {
    return `How could someone do something ${primaryChineseKeyword} in real life?`;
  }

  if (part.startsWith('a')) {
    return `Can you describe a ${primaryChineseKeyword} situation?`;
  }

  return `Why is ${primaryChineseKeyword} useful in real conversation?`;
}

export function buildConversationPrompt(word: WordEntry, mode: ConversationPromptMode): ConversationPromptCard {
  const chineseKeyword = conciseChineseMeaning(word.meaningZh);
  const primaryChineseKeyword = chineseKeyword.split(/[；;，,、]/)[0]?.trim() || chineseKeyword;
  const context: PromptContext = {
    chineseKeyword,
    primaryChineseKeyword,
    word,
    wordLower: word.word.toLowerCase(),
    meaningLower: word.meaningZh.toLowerCase(),
  };

  if (mode === 'chinese') {
    return {
      keyword: primaryChineseKeyword,
      keywordPronunciation: chineseMeaningPinyin(primaryChineseKeyword),
      question: buildChineseModeQuestion(context),
      questionSupport: `Try to answer in Chinese and include "${primaryChineseKeyword}" once. English hint: "${word.word}".`,
      referenceAnswer: `${word.exampleZh} 我會再補上一個自己的原因或例子，讓回答更像真實對話。`.trim(),
      referenceTranslation: `${word.example} I would add one personal reason or example to make the answer sound natural.`.trim(),
    };
  }

  return {
    keyword: word.word,
    keywordPronunciation: '',
    question: buildEnglishQuestion(context),
    questionSupport: `Try to answer in 2-3 sentences and include "${word.word}" naturally.`,
    referenceAnswer: `${word.example} I would add one personal reason or example to make the answer sound natural.`.trim(),
    referenceTranslation: `${word.exampleZh} 我會再補上一個自己的原因或例子，讓回答聽起來更自然。`.trim(),
  };
}
