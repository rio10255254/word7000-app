import fs from 'node:fs';
import path from 'node:path';
import { describe, expect, it } from 'vitest';
// @ts-expect-error The builder is a plain ES module script.
import { appCourse, candidatesFrom, chunk, entryProblem, mergeEntries } from '../scripts/build-chinese-course.mjs';

const root = path.resolve(__dirname, '..');
const courseFile = path.join(root, 'content/chinese/course.json');
const appFile = path.join(root, 'ios/Packages/Word7000Core/Sources/Word7000Core/Resources/chinese-course.json');

const good = {
  hanzi: '喜歡', english: 'like; be fond of', partOfSpeech: 'verb', measureWord: '', level: 1,
  example: '我很喜歡喝茶。', exampleEnglish: 'I really like tea.', question: '你喜歡吃什麼？',
  questionEnglish: 'What do you like to eat?', answer: '我喜歡吃牛肉麵。', answerEnglish: 'I like beef noodles.',
  sources: ['w1'], order: 0,
};

describe('Chinese course builder', () => {
  it('turns the English list into one candidate per Chinese sense', () => {
    const candidates = candidatesFrom([
      { id: 'w1', word: 'like', partOfSpeech: 'v', meaningZh: '喜歡', supplementalMeaningZh: '像' },
      { id: 'w2', word: 'love', partOfSpeech: 'v', meaningZh: '喜歡；愛', supplementalMeaningZh: '' },
      { id: 'w3', word: 'OK', partOfSpeech: 'a', meaningZh: 'OK', supplementalMeaningZh: '' },
    ]);
    expect(candidates).toHaveLength(1);
    expect(candidates[0].english.map((word: { word: string }) => word.word)).toEqual(['like', 'love']);
    expect(chunk(Array.from({ length: 30 }, (_, index) => ({ key: String(index) })), 25)).toHaveLength(2);
  });

  it('accepts a learner entry and rejects the usual mistakes', () => {
    expect(entryProblem(good)).toBeNull();
    expect(entryProblem({ ...good, hanzi: '簡短的東西們好' })).toMatch(/hanzi/);
    expect(entryProblem({ ...good, example: '他很愛喝茶。' })).toMatch(/example/);
    expect(entryProblem({ ...good, example: '我在下班以後常常跟同事一起去夜市喜歡吃東西。' })).toMatch(/example/);
    expect(entryProblem({ ...good, question: '你喜歡吃什麼' })).toMatch(/question/);
    expect(entryProblem({ ...good, answer: '牛肉麵。' })).toMatch(/answer/);
    expect(entryProblem({ ...good, measureWord: '個個' })).toMatch(/measure/);
    expect(entryProblem({ ...good, level: 7 })).toMatch(/level/);
    expect(entryProblem(good, () => true)).toMatch(/Simplified/);
  });

  it('merges entries that share a headword, keeping the lower level', () => {
    const merged = mergeEntries([
      { ...good, level: 2, english: 'like', sources: ['w1'], order: 0 },
      { ...good, level: 1, english: 'be fond of', sources: ['w2'], order: 5 },
      { ...good, hanzi: '茶', level: 1, english: 'tea', sources: ['w3'], order: 3 },
    ]);
    expect(merged.map((entry: { hanzi: string }) => entry.hanzi)).toEqual(['茶', '喜歡']);
    expect(merged[1]).toMatchObject({ level: 1, english: 'like; be fond of', sources: ['w1', 'w2'] });
  });

  it('keeps the app file in step with the reviewed course', async () => {
    if (!fs.existsSync(courseFile)) return;
    const { entries } = JSON.parse(fs.readFileSync(courseFile, 'utf8'));
    const expected = `${JSON.stringify(await appCourse(entries))}\n`;
    expect(fs.readFileSync(appFile, 'utf8') === expected).toBe(true);
    for (const entry of entries) expect(entryProblem(entry), entry.hanzi).toBeNull();
  }, 120_000);
});
