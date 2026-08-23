import { describe, expect, test } from 'vitest';
import fs from 'node:fs';
import path from 'node:path';
import { sampleWords } from './data/words';
import { buildQuizSession, buildStudySession, computeStats, filterWords, type ProgressState } from './lib/progress';

const emptyProgress: ProgressState = {
  dailyTarget: 20,
  streak: 1,
  studiedToday: 0,
  words: {},
};

describe('representative 7000-word performance', () => {
  test('keeps common library, study, and quiz preparation comfortably responsive', () => {
    expect(sampleWords).toHaveLength(7000);

    filterWords(sampleWords, emptyProgress, 'tion', 'all', { sort: 'alphabetical' });
    const startedAt = performance.now();
    for (let index = 0; index < 20; index += 1) {
      filterWords(sampleWords, emptyProgress, index % 2 === 0 ? 'tion' : '生活', 'all', {
        initial: index % 3 === 0 ? 'A' : 'all',
        level: 'all',
        sort: 'alphabetical',
      });
      buildStudySession(sampleWords.slice(0, 400), `study-${index}`);
      buildQuizSession(sampleWords, 50, `quiz-${index}`);
      computeStats(sampleWords, emptyProgress);
    }
    const durationMs = performance.now() - startedAt;

    expect(durationMs).toBeLessThan(750);
  });

  test('keeps expensive summaries and hidden tabs frozen while studying', () => {
    const appSource = fs.readFileSync(path.join(process.cwd(), 'App.tsx'), 'utf8');
    expect(appSource).toContain("activeTab === 'home' || activeTab === 'profile'");
    expect(appSource).toContain('HomeScreenPropsContext.Provider value={homeScreenProps}');
    expect(appSource).toContain('StudyScreenPropsContext.Provider value={studyScreenProps}');
    expect(appSource).toContain('progressStorageWriterRef.current?.enqueue(progress)');
    expect(appSource).toContain('StreakReminderRegistrationQueue');
    expect(appSource).toContain('NATIVE_UPDATE_CHECK_COOLDOWN_MS = 15 * 60_000');
    expect(appSource).not.toContain('setInterval(refreshClock, 30_000)');
  });
});
