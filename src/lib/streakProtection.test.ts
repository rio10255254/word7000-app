import { describe, expect, test } from 'vitest';
import {
  addDays, markKnown, markQuizCorrect, markReview, mergeProgressStates, normalizeProgressForDate,
  toggleFavorite, type ProgressState,
} from './progress';

function progress(values: Partial<ProgressState> = {}): ProgressState {
  return {
    dailyTarget: 20, streak: 5, studiedToday: 0,
    dailyProgressDate: '2026-10-01', lastStudyDate: '2026-10-01', words: {}, ...values,
  };
}

describe('shared streak protection', () => {
  test.each([markKnown, markQuizCorrect, markReview])('every grading path covers one missed day exactly once', (grade) => {
    const original = progress({ studiedToday: 12 });
    const normalized = normalizeProgressForDate(original, '2026-10-03');
    expect(normalized).toMatchObject({ streak: 5, streakFreezeDate: '2026-10-02', studiedToday: 0 });
    expect(normalizeProgressForDate(normalized, '2026-10-03')).toEqual(normalized);
    const studied = grade(normalized, 'word', '2026-10-03');
    expect(studied).toMatchObject({ streak: 6, studiedToday: 1, lastStudyDate: '2026-10-03' });
    expect(grade(studied, 'word', '2026-10-03')).toMatchObject({ streak: 6, studiedToday: 1 });
    expect(toggleFavorite(studied, 'other')).toMatchObject({ streak: 6, streakFreezeDate: '2026-10-02' });
    expect(original).toEqual(progress({ studiedToday: 12 }));
  });

  test('a second missed day in the cooldown breaks the streak but does not clear its usage', () => {
    const studied = markKnown(progress(), 'a', '2026-10-03');
    const expired = normalizeProgressForDate(studied, '2026-10-05');
    expect(expired).toMatchObject({ streak: 0, streakFreezeDate: '2026-10-02' });
    expect(markKnown(expired, 'b', '2026-10-05').streak).toBe(1);
  });

  test.each([
    ['2026-10-08', 0, '2026-10-02'],
    ['2026-10-09', 5, '2026-10-09'],
    ['2026-10-10', 5, '2026-10-10'],
  ])('cooldown is measured between missed days: %s', (missed, streak, freeze) => {
    const last = missed === '2026-10-08' ? '2026-10-07' : missed === '2026-10-09' ? '2026-10-08' : '2026-10-09';
    const today = missed === '2026-10-08' ? '2026-10-09' : missed === '2026-10-09' ? '2026-10-10' : '2026-10-11';
    expect(normalizeProgressForDate(progress({ lastStudyDate: last, streakFreezeDate: '2026-10-02' }), today))
      .toMatchObject({ streak, streakFreezeDate: freeze });
  });

  test.each([
    ['2026-12-31', '2027-01-02', '2027-01-01'],
    ['2028-02-28', '2028-03-01', '2028-02-29'],
    ['2026-03-07', '2026-03-09', '2026-03-08'],
  ])('calendar boundaries use whole days: %s', (lastStudyDate, today, freeze) => {
    expect(markKnown(progress({ lastStudyDate }), 'a', today)).toMatchObject({ streak: 6, streakFreezeDate: freeze });
  });

  test('neither two missed days nor a zero streak can earn protection', () => {
    expect(normalizeProgressForDate(progress(), '2026-10-04')).toMatchObject({ streak: 0 });
    expect(normalizeProgressForDate(progress({ streak: 0 }), '2026-10-03').streakFreezeDate).toBeUndefined();
    expect(markKnown(progress(), 'a', '2026-10-04').streak).toBe(1);
  });
});

describe('legacy sync reconciliation', () => {
  const cases: Array<{ name: string; old: Partial<ProgressState>; incoming: Partial<ProgressState>; streak: number; freeze?: string; last?: string }> = [
    { name: 'continuous study must not spend protection on an older snapshot', old: {}, incoming: { lastStudyDate: '2026-10-03', dailyProgressDate: '2026-10-03', streak: 7 }, streak: 7, last: '2026-10-03' },
    { name: 'equal candidate does not allocate an unneeded protection', old: {}, incoming: { lastStudyDate: '2026-10-03', dailyProgressDate: '2026-10-03', streak: 6 }, streak: 6, last: '2026-10-03' },
    { name: 'legacy open keeps a protected count', old: { streakFreezeDate: '2026-10-02' }, incoming: { dailyProgressDate: '2026-10-03', streak: 0 }, streak: 5, freeze: '2026-10-02' },
    { name: 'legacy open can allocate an unused protection', old: {}, incoming: { dailyProgressDate: '2026-10-03', streak: 0 }, streak: 5, freeze: '2026-10-02' },
    { name: 'legacy study extends the protected count', old: { streakFreezeDate: '2026-10-02' }, incoming: { lastStudyDate: '2026-10-03', dailyProgressDate: '2026-10-03', streak: 1, studiedToday: 3 }, streak: 6, freeze: '2026-10-02', last: '2026-10-03' },
    { name: 'legacy study allocates available protection', old: {}, incoming: { lastStudyDate: '2026-10-03', dailyProgressDate: '2026-10-03', streak: 1 }, streak: 6, freeze: '2026-10-02', last: '2026-10-03' },
    { name: 'next-day study extends by one', old: {}, incoming: { lastStudyDate: '2026-10-02', dailyProgressDate: '2026-10-02', streak: 1 }, streak: 6, last: '2026-10-02' },
    { name: 'same-day reset cannot reduce a count', old: {}, incoming: { streak: 0, studiedToday: 10 }, streak: 5 },
    { name: 'cooldown prevents a second protected gap', old: { streakFreezeDate: '2026-09-28' }, incoming: { lastStudyDate: '2026-10-03', dailyProgressDate: '2026-10-03', streak: 1 }, streak: 1, freeze: '2026-09-28', last: '2026-10-03' },
    { name: 'expired open must not resurrect a count', old: { streakFreezeDate: '2026-10-02' }, incoming: { dailyProgressDate: '2026-10-04', streak: 0 }, streak: 0, freeze: '2026-10-02' },
    { name: 'distant study starts over', old: { streakFreezeDate: '2026-10-02', streak: 100 }, incoming: { lastStudyDate: '2026-10-04', dailyProgressDate: '2026-10-04', streak: 1 }, streak: 1, freeze: '2026-10-02', last: '2026-10-04' },
    { name: 'older freeze cannot overwrite newer usage', old: { streakFreezeDate: '2026-10-02' }, incoming: { streakFreezeDate: '2026-09-20', dailyProgressDate: '2026-10-03', streak: 0 }, streak: 5, freeze: '2026-10-02' },
    { name: 'newer freeze blocks another use in that week', old: { streakFreezeDate: '2026-09-20' }, incoming: { streakFreezeDate: '2026-09-28', dailyProgressDate: '2026-10-03', streak: 0 }, streak: 0, freeze: '2026-09-28' },
    { name: 'opening after the most recent study must not roll study date backward', old: { lastStudyDate: '2026-10-03', dailyProgressDate: '2026-10-03', streak: 6, streakFreezeDate: '2026-10-02' }, incoming: { dailyProgressDate: '2026-10-04', streak: 0 }, streak: 6, freeze: '2026-10-02', last: '2026-10-03' },
    { name: 'invalid freeze is ignored', old: { streakFreezeDate: '2026-10-02' }, incoming: { streakFreezeDate: '9999-99-99', dailyProgressDate: '2026-10-03', streak: 0 }, streak: 5, freeze: '2026-10-02' },
  ];

  test.each(cases)('$name, in either merge order and on repeated sync', ({ old, incoming, streak, freeze, last }) => {
    const a = progress(old);
    const b = progress(incoming);
    const snapshots = JSON.stringify([a, b]);
    for (const inputs of [[a, b], [b, a], [a, b, a, b]]) {
      const merged = mergeProgressStates(...inputs);
      expect(merged.streak).toBe(streak);
      expect(merged.lastStudyDate).toBe(last ?? '2026-10-01');
      expect(merged.streakFreezeDate).toBe(freeze);
      expect(mergeProgressStates(merged, a, b)).toMatchObject({ streak, lastStudyDate: last ?? '2026-10-01' });
      expect(mergeProgressStates(JSON.parse(JSON.stringify(merged)))).toEqual(merged);
    }
    expect(JSON.stringify([a, b])).toBe(snapshots);
  });

  test('daily settings and word data remain independent of the repaired count', () => {
    const incoming = markKnown(progress({ streak: 0, dailyTarget: 40 }), 'remote', '2026-10-03');
    const local = toggleFavorite(progress(), 'local');
    const merged = mergeProgressStates(local, incoming);
    expect(merged).toMatchObject({ streak: 6, dailyTarget: 40, studiedToday: 1, dailyProgressDate: '2026-10-03' });
    expect(merged.words.remote.status).toBe('mastered');
    expect(merged.words.local.favorite).toBe(true);
  });

  test('missing and null dates remain compatible with legacy JSON', () => {
    const legacy = JSON.parse('{"dailyTarget":20,"streak":0,"studiedToday":0,"words":{},"streakFreezeDate":null,"lastStudyDate":null,"dailyProgressDate":null}');
    expect(mergeProgressStates(progress({ streakFreezeDate: '2026-10-02' }), legacy).streakFreezeDate).toBe('2026-10-02');
    expect(mergeProgressStates()).toEqual({ dailyTarget: 20, streak: 0, studiedToday: 0, words: {} });
  });

  test('90-day study histories survive daily native and legacy sync without spending extra protection', () => {
    for (const pattern of [[true], [true, false], [true, true, false, false], [true, true, true, true, true, true, false], [true, false, false, false]]) {
      let state = progress({ streak: 0, lastStudyDate: undefined, dailyProgressDate: undefined });
      let count = 0;
      let last: number | undefined;
      let freeze: number | undefined;
      for (let day = 0; day < 90; day += 1) {
        const today = addDays('2026-10-01', day)!;
        const studying = pattern[day % pattern.length];
        const previous = state;
        const gap = last === undefined ? 0 : day - last;
        if (gap > 1) {
          if (count > 0 && gap === 2 && (freeze === day - 1 || freeze === undefined || day - 1 - freeze >= 7)) {
            freeze = day - 1;
          } else {
            count = 0;
          }
        }
        if (studying) {
          count += 1;
          last = day;
        }
        state = studying ? markKnown(previous, 'a', today) : normalizeProgressForDate(previous, today);
        expect(state.streak).toBe(count);
        expect(state.streakFreezeDate).toBe(freeze === undefined ? undefined : addDays('2026-10-01', freeze));

        const legacy: ProgressState = {
          ...state,
          streakFreezeDate: undefined,
          streak: studying ? (gap === 1 ? previous.streak + 1 : 1) : gap > 1 ? 0 : previous.streak,
        };
        for (const peer of [state, legacy]) {
          for (const inputs of [[previous, peer], [peer, previous]]) {
            const merged = mergeProgressStates(...inputs);
            expect(merged.streak, `${today}, studying=${studying}`).toBe(state.streak);
            expect(merged.streakFreezeDate, today).toBe(state.streakFreezeDate);
          }
        }
      }
    }
  });
});
