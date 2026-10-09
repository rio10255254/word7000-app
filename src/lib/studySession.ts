export type StudyGrade = 'known' | 'review';

export type StudySession = {
  /** Card ids in the order they will be shown, including re-queued misses. */
  cardIds: string[];
  index: number;
  /** Distinct words in the session as it was built, for the summary. */
  initialCount: number;
  knownIds: string[];
  /** What the session was built from; a different key means rebuild. */
  sourceKey: string;
  reviewIds: string[];
  requeued: Record<string, number>;
};

// A missed card comes back a few cards later, while the answer is still fresh
// enough to be worth a second look but not so soon that it is just recalled
// from the screen a moment ago.
export const STUDY_REQUEUE_GAP = 4;
const MAX_REQUEUES_PER_CARD = 2;

export function createStudySession(cardIds: string[], sourceKey: string): StudySession {
  const unique = Array.from(new Set(cardIds));
  return {
    cardIds: unique,
    index: 0,
    initialCount: unique.length,
    knownIds: [],
    reviewIds: [],
    requeued: {},
    sourceKey,
  };
}

export function currentStudyCardId(session: StudySession | null): string | null {
  if (!session) {
    return null;
  }
  return session.cardIds[session.index] ?? null;
}

export function upcomingStudyCardId(session: StudySession | null): string | null {
  if (!session) {
    return null;
  }
  return session.cardIds[session.index + 1] ?? null;
}

export function isStudySessionComplete(session: StudySession | null): boolean {
  return Boolean(session) && session!.index >= session!.cardIds.length;
}

export function gradeStudyCard(session: StudySession, cardId: string, grade: StudyGrade): StudySession {
  if (session.cardIds[session.index] !== cardId) {
    return session;
  }

  let cardIds = session.cardIds;
  let requeued = session.requeued;
  const timesRequeued = session.requeued[cardId] ?? 0;
  if (grade === 'review' && timesRequeued < MAX_REQUEUES_PER_CARD) {
    const insertAt = Math.min(cardIds.length, session.index + 1 + STUDY_REQUEUE_GAP);
    cardIds = [...cardIds.slice(0, insertAt), cardId, ...cardIds.slice(insertAt)];
    requeued = { ...requeued, [cardId]: timesRequeued + 1 };
  }

  // The summary reports each word once, by the last answer given for it.
  const knownIds = session.knownIds.filter((id) => id !== cardId);
  const reviewIds = session.reviewIds.filter((id) => id !== cardId);
  if (grade === 'known') {
    knownIds.push(cardId);
  } else {
    reviewIds.push(cardId);
  }

  return {
    ...session,
    cardIds,
    index: session.index + 1,
    knownIds,
    requeued,
    reviewIds,
  };
}

export function studySessionProgress(session: StudySession | null): { done: number; total: number } {
  if (!session) {
    return { done: 0, total: 0 };
  }
  return { done: Math.min(session.index, session.cardIds.length), total: session.cardIds.length };
}
