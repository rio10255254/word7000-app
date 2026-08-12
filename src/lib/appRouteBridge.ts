import { useSyncExternalStore } from 'react';
import type { WordEntry } from '../data/words';
import type { CustomSetSort, CustomSetState, CustomVocabSet } from './customSets';
import type { DeveloperVocabularySnapshot } from './developerVocabulary';
import type { ProgressState } from './progress';
import type { AccountUpgradeReason } from './accountIdentity';

export type AppStudyMode = 'english' | 'chinese';
export type AppThemeMode = 'light' | 'dark';

export type RouteManualCustomWordState = {
  example: string;
  exampleZh: string;
  meaningZh: string;
  supplementalMeaningZh: string;
  partOfSpeech: string;
  pronunciation: string;
  word: string;
};

export type AppRouteBridgeSnapshot = {
  accountBusy: boolean;
  accountReady: boolean;
  customSetMessage: string;
  customSetSort: CustomSetSort;
  customSetState: CustomSetState;
  customSets: CustomVocabSet[];
  developerMessage: string;
  developerVocabulary: DeveloperVocabularySnapshot | null;
  manualCustomWord: RouteManualCustomWordState;
  newSetName: string;
  progress: ProgressState;
  selectedCustomSetId: string | null;
  signedIn: boolean;
  streakReminderEnabled: boolean;
  studyMode: AppStudyMode;
  themeMode: AppThemeMode;
  vocabularyWords: WordEntry[];
  actions: {
    addManualCustomWord: () => void;
    addWordToSet: (word: WordEntry, setId: string) => void;
    clearDeveloperVocabulary: () => void;
    confirmDeleteAccountData: () => void;
    createCustomSet: () => void;
    createSetAndAddWord: (word: WordEntry, name: string) => void;
    exportVocabulary: () => void;
    favoriteWord: (wordId: string) => void;
    importCustomWords: () => void;
    importVocabulary: () => void;
    manualCustomWordChange: (field: keyof RouteManualCustomWordState, value: string) => void;
    newSetNameChange: (name: string) => void;
    openAppInfoLink: (url: string) => void;
    removeWordFromSet: (setId: string, word: WordEntry) => void;
    requestAccountUpgrade: (reason: AccountUpgradeReason, afterUpgrade?: () => void) => void;
    renameCustomSet: (setId: string, name: string) => void;
    restoreLibraryScroll: () => void;
    selectCustomSet: (setId: string | null) => void;
    setCustomSetSort: (sort: CustomSetSort) => void;
    setStreakReminderEnabled: (enabled: boolean) => void;
    setThemeMode: (themeMode: AppThemeMode) => void;
    startQuizSet: (setId: string) => void;
    startStudySet: (setId: string) => void;
    deleteCustomSet: (setId: string) => void;
  };
};

const listeners = new Set<() => void>();
let snapshot: AppRouteBridgeSnapshot | null = null;

export function setAppRouteBridgeSnapshot(nextSnapshot: AppRouteBridgeSnapshot | null): void {
  snapshot = nextSnapshot;
  listeners.forEach((listener) => listener());
}

export function getAppRouteBridgeSnapshot(): AppRouteBridgeSnapshot | null {
  return snapshot;
}

export function useAppRouteBridge(): AppRouteBridgeSnapshot | null {
  return useSyncExternalStore(subscribe, getAppRouteBridgeSnapshot, getAppRouteBridgeSnapshot);
}

export function useAppRouteThemeMode(): AppThemeMode {
  return useSyncExternalStore(
    subscribe,
    () => snapshot?.themeMode ?? 'light',
    () => snapshot?.themeMode ?? 'light',
  );
}

function subscribe(listener: () => void): () => void {
  listeners.add(listener);
  return () => listeners.delete(listener);
}
