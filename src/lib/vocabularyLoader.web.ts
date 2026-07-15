import type { WordEntry } from '../data/words';

export async function loadBundledVocabulary(): Promise<WordEntry[]> {
  const vocabulary = await import('../data/words');
  return vocabulary.sampleWords;
}
