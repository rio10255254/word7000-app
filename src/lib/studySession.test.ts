import { describe, expect, test } from 'vitest';
import {
  createStudySession,
  currentStudyCardId,
  gradeStudyCard,
  isStudySessionComplete,
  STUDY_REQUEUE_GAP,
  studySessionProgress,
  upcomingStudyCardId,
} from './studySession';

const ids = ['a', 'b', 'c', 'd', 'e', 'f', 'g'];

describe('study session', () => {
  test('walks through the cards in order and finishes', () => {
    let session = createStudySession(['a', 'b'], 'key');
    expect(currentStudyCardId(session)).toBe('a');
    expect(upcomingStudyCardId(session)).toBe('b');

    session = gradeStudyCard(session, 'a', 'known');
    session = gradeStudyCard(session, 'b', 'known');

    expect(isStudySessionComplete(session)).toBe(true);
    expect(session.knownIds).toEqual(['a', 'b']);
    expect(studySessionProgress(session)).toEqual({ done: 2, total: 2 });
  });

  test('brings a missed card back a few cards later', () => {
    const session = gradeStudyCard(createStudySession(ids, 'key'), 'a', 'review');

    expect(session.cardIds[1 + STUDY_REQUEUE_GAP]).toBe('a');
    expect(session.cardIds).toHaveLength(ids.length + 1);
    expect(session.reviewIds).toEqual(['a']);
  });

  test('re-queues a stubborn card at most twice', () => {
    let session = createStudySession(['a'], 'key');
    session = gradeStudyCard(session, 'a', 'review');
    session = gradeStudyCard(session, 'a', 'review');
    session = gradeStudyCard(session, 'a', 'review');

    expect(isStudySessionComplete(session)).toBe(true);
    expect(session.cardIds).toEqual(['a', 'a', 'a']);
  });

  test('reports a word by its final answer', () => {
    let session = createStudySession(['a'], 'key');
    session = gradeStudyCard(session, 'a', 'review');
    session = gradeStudyCard(session, 'a', 'known');

    expect(session.knownIds).toEqual(['a']);
    expect(session.reviewIds).toEqual([]);
  });

  test('ignores a grade for a card that is not on screen', () => {
    const session = createStudySession(ids, 'key');

    expect(gradeStudyCard(session, 'c', 'known')).toBe(session);
  });

  test('drops duplicate ids when building', () => {
    expect(createStudySession(['a', 'a', 'b'], 'key').cardIds).toEqual(['a', 'b']);
  });
});
