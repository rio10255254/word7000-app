import type { WordEntry } from '../data/words';

type VocabularyModule = typeof import('../data/words');

export function loadBundledVocabulary(): Promise<WordEntry[]> {
  const vocabulary = require('../data/words') as VocabularyModule;
  return Promise.resolve(vocabulary.sampleWords);
}
