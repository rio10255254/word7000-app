import fs from 'node:fs';
import path from 'node:path';
import { describe, expect, test } from 'vitest';
import { sampleWords } from './data/words';
import {
  buildQuizOptions,
  buildQuizSession,
  buildStudyQueue,
  buildStudySession,
  computeStats,
  filterWords,
  markKnown,
  markQuizCorrect,
  markReview,
  mergeProgressStates,
  normalizeProgressForDate,
  toggleFavorite,
  type ProgressState,
} from './lib/progress';
import { linesFromPlainText, parseScannedLines } from './lib/scanParser';
import { createStudySession, gradeStudyCard } from './lib/studySession';

/**
 * The native iOS app re-implements the learning rules in Swift. These golden
 * results, computed by the TypeScript engine, are replayed by the Swift tests
 * (ios/Packages/Word7000Core/Tests) so both apps make the same decisions.
 * Run with UPDATE_NATIVE_FIXTURES=1 after an intentional rule change.
 */
const fixturePath = path.join(process.cwd(), 'ios/Packages/Word7000Core/Tests/Word7000CoreTests/parity.json');

function buildFixtures() {
  const words = sampleWords;
  const ids = words.map((word) => word.id);
  const empty: ProgressState = { dailyTarget: 20, streak: 0, studiedToday: 0, words: {} };

  // A learner's history across a few days, one step at a time.
  const steps: Array<{ op: string; wordId: string; today: string; at: string }> = [
    { op: 'known', wordId: 'w0001', today: '2026-06-01', at: '2026-06-01T08:00:00.000Z' },
    { op: 'review', wordId: 'w0002', today: '2026-06-01', at: '2026-06-01T08:01:00.000Z' },
    { op: 'known', wordId: 'w0001', today: '2026-06-01', at: '2026-06-01T08:02:00.000Z' },
    { op: 'quiz', wordId: 'w0003', today: '2026-06-02', at: '2026-06-02T09:00:00.000Z' },
    { op: 'favorite', wordId: 'w0003', today: '2026-06-02', at: '2026-06-02T09:01:00.000Z' },
    { op: 'known', wordId: 'w0002', today: '2026-06-02', at: '2026-06-02T09:02:00.000Z' },
    { op: 'review', wordId: 'w0001', today: '2026-06-05', at: '2026-06-05T10:00:00.000Z' },
    { op: 'known', wordId: 'w0004', today: '2026-06-05', at: '2026-06-05T10:01:00.000Z' },
    { op: 'favorite', wordId: 'w0004', today: '2026-06-05', at: '2026-06-05T10:02:00.000Z' },
    { op: 'favorite', wordId: 'w0003', today: '2026-06-05', at: '2026-06-05T10:03:00.000Z' },
    { op: 'known', wordId: 'w0002', today: '2026-06-06', at: '2026-06-06T07:00:00.000Z' },
  ];
  const history: ProgressState[] = [];
  let state = empty;
  for (const step of steps) {
    state =
      step.op === 'known' ? markKnown(state, step.wordId, step.today, step.at)
        : step.op === 'review' ? markReview(state, step.wordId, step.today, step.at)
          : step.op === 'quiz' ? markQuizCorrect(state, step.wordId, step.today, step.at)
            : toggleFavorite(state, step.wordId, step.at);
    history.push(state);
  }

  const otherDevice = markReview(markKnown(empty, 'w0005', '2026-06-06', '2026-06-06T11:00:00.000Z'), 'w0002', '2026-06-06', '2026-06-06T12:00:00.000Z');
  const merged = mergeProgressStates(state, otherDevice);

  const queueState = history[history.length - 1];
  const libraryState = toggleFavorite(markReview(markKnown(queueState, 'w0100', '2026-06-06', '2026-06-06T13:00:00.000Z'), 'w0200', '2026-06-06', '2026-06-06T13:05:00.000Z'), 'w0100', '2026-06-06T13:06:00.000Z');

  const queries: Array<{ query: string; filter: 'all' | 'favorites' | 'review' | 'mastered' | 'new'; level?: string; initial?: string; sort?: 'default' | 'alphabetical' }> = [
    { query: 'ab', filter: 'all' },
    { query: '放棄', filter: 'all' },
    { query: 'the bus', filter: 'all' },
    { query: '', filter: 'favorites' },
    { query: '', filter: 'review' },
    { query: '', filter: 'mastered' },
    { query: '', filter: 'new', level: 'Core 3', initial: 'c' },
    { query: '', filter: 'all', sort: 'alphabetical' },
    { query: 're', filter: 'all', sort: 'alphabetical' },
  ];

  const scanLines = [
    [{ height: 0.03, text: 'abandon v. 放棄；遺棄', width: 0.3, x: 0.1, y: 0.1 }],
    [
      { height: 0.03, text: '1. ability (n.) 能力', width: 0.3, x: 0.1, y: 0.1 },
      { height: 0.03, text: '２．ａｂｓｅｎｔ　adj. 缺席的', width: 0.3, x: 0.1, y: 0.15 },
      { height: 0.03, text: '③ look forward to 期待', width: 0.3, x: 0.1, y: 0.2 },
    ],
    [
      { height: 0.03, text: 'meaning', width: 0.2, x: 0.55, y: 0.1 },
      { height: 0.03, text: 'benefit', width: 0.2, x: 0.1, y: 0.1 },
      { height: 0.03, text: '好處；利益', width: 0.2, x: 0.55, y: 0.2 },
      { height: 0.03, text: 'capture', width: 0.2, x: 0.1, y: 0.2 },
      { height: 0.03, text: '捕獲', width: 0.2, x: 0.55, y: 0.1 },
    ],
    [{ height: 0.03, text: 'fierce a. 兇猛的 gather v. 聚集', width: 0.9, x: 0.05, y: 0.1 }],
    [{ height: 0.03, text: 'colour/color n./v. 顏色；著色', width: 0.3, x: 0.1, y: 0.1 }],
    [
      { height: 0.03, text: 'harvest n. 收成', width: 0.3, x: 0.1, y: 0.1 },
      { height: 0.03, text: 'The farmers celebrated the harvest.', width: 0.8, x: 0.1, y: 0.14 },
      { height: 0.03, text: '農夫們慶祝收成。', width: 0.5, x: 0.1, y: 0.18 },
      { height: 0.03, text: 'He left early. 他很早離開。', width: 0.8, x: 0.1, y: 0.22 },
    ],
    [
      { height: 0.03, text: 'kettle', width: 0.3, x: 0.1, y: 0.1 },
      { height: 0.03, text: 'ladder', width: 0.3, x: 0.1, y: 0.135 },
      { height: 0.03, text: '梯子', width: 0.3, x: 0.1, y: 0.17 },
    ],
    [{ height: 0.03, text: '- explain（sth）v. 解釋（sth）', width: 0.6, x: 0.1, y: 0.1 }],
    linesFromPlainText('abandon v. 放棄\n\nbenefit\n好處\nThe benefit is clear.\n'),
  ];

  let session = createStudySession(['a', 'b', 'c', 'd', 'e', 'f', 'g'], 'k');
  const sessionGrades: Array<[string, 'known' | 'review']> = [['a', 'review'], ['b', 'known'], ['c', 'review'], ['d', 'known'], ['e', 'known'], ['a', 'review'], ['f', 'known']];
  for (const [id, grade] of sessionGrades) {
    session = gradeStudyCard(session, id, grade);
  }

  return {
    steps,
    history,
    otherDevice,
    merged,
    normalized: normalizeProgressForDate(state, '2026-06-09'),
    stats: computeStats(words, libraryState, '2026-06-06'),
    statsLater: computeStats(words, libraryState, '2026-06-20'),
    studySession: buildStudySession(words.slice(0, 30), 'seed-1').map((word) => word.id),
    quizSessionSmall: buildQuizSession(words.slice(0, 30), 20, 'seed-2').map((word) => word.id),
    quizSessionLarge: buildQuizSession(words, 20, 'seed-3').map((word) => word.id),
    quizOptions: ['w0001', 'w0050', 'w3000', 'w6999'].map((wordId) => ({
      wordId,
      meaning: buildQuizOptions(words, wordId, 'seed-4', 'meaning'),
      word: buildQuizOptions(words, wordId, 'seed-4', 'word'),
    })),
    studyQueue: buildStudyQueue(words.slice(0, 40), queueState, '2026-06-06', { limit: 12, seed: 'seed-5' }).map((word) => word.id),
    libraryState,
    library: queries.map((query) => ({
      ...query,
      ids: filterWords(words, libraryState, query.query, query.filter, { initial: query.initial, level: query.level, sort: query.sort })
        .slice(0, 25)
        .map((word) => word.id),
    })),
    scans: scanLines.map((lines) => ({ lines, result: parseScannedLines(lines) })),
    sessionGrades,
    session,
    idCount: ids.length,
  };
}

describe('native parity fixtures', () => {
  test('the Swift engine replays the same golden results', () => {
    const fixtures = `${JSON.stringify(buildFixtures(), null, 1)}\n`;
    if (process.env.UPDATE_NATIVE_FIXTURES === '1' || !fs.existsSync(fixturePath)) {
      fs.mkdirSync(path.dirname(fixturePath), { recursive: true });
      fs.writeFileSync(fixturePath, fixtures);
    }
    expect(fs.readFileSync(fixturePath, 'utf8')).toBe(fixtures);
  });
});
