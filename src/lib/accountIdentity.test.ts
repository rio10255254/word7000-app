import { describe, expect, test } from 'vitest';
import { emptyCustomSetState } from './customSets';
import type { ProgressState } from './progress';
import {
  ACCOUNT_PROTECTION_PROMPT_STORAGE_KEY,
  PERMANENT_ACCOUNT_USED_STORAGE_KEY,
  accountUpgradeReasonForFilter,
  clearPendingAccountUpgrade,
  hasUsedPermanentAccount,
  isAnonymousUser,
  isIdentityAlreadyLinkedError,
  loadPendingAccountUpgrade,
  markPermanentAccountUsed,
  markProgressProtectionPromptSeen,
  savePendingAccountUpgrade,
  shouldPromptToProtectProgress,
} from './accountIdentity';

function memoryStorage() {
  const values = new Map<string, string>();
  return {
    getItem: (key: string) => values.get(key) ?? null,
    removeItem: (key: string) => values.delete(key),
    setItem: (key: string, value: string) => values.set(key, value),
  };
}

describe('account identity helpers', () => {
  test('requires an account only for the saved-words filter', () => {
    expect(accountUpgradeReasonForFilter('favorites')).toBe('favorites');
    expect(accountUpgradeReasonForFilter('all')).toBeNull();
    expect(accountUpgradeReasonForFilter('review')).toBeNull();
    expect(accountUpgradeReasonForFilter('mastered')).toBeNull();
    expect(accountUpgradeReasonForFilter('new')).toBeNull();
  });

  test('distinguishes temporary visitors from permanent accounts', () => {
    expect(isAnonymousUser({ is_anonymous: true })).toBe(true);
    expect(isAnonymousUser({ is_anonymous: false })).toBe(false);
    expect(isAnonymousUser(undefined)).toBe(false);
  });

  test('recognizes an identity that already belongs to a permanent account', () => {
    expect(isIdentityAlreadyLinkedError({ code: 'identity_already_exists' })).toBe(true);
    expect(isIdentityAlreadyLinkedError({ message: 'Identity is already linked to another user' })).toBe(true);
    expect(isIdentityAlreadyLinkedError({ message: 'Nonce mismatch' })).toBe(false);
  });

  test('shows the automatic protection prompt only once', () => {
    const storage = memoryStorage();
    expect(shouldPromptToProtectProgress(storage)).toBe(true);
    markProgressProtectionPromptSeen(storage);
    expect(storage.getItem(ACCOUNT_PROTECTION_PROMPT_STORAGE_KEY)).toBe('seen');
    expect(shouldPromptToProtectProgress(storage)).toBe(false);
  });

  test('remembers that returning users should use the normal sign-in flow', () => {
    const storage = memoryStorage();
    expect(hasUsedPermanentAccount(storage)).toBe(false);
    markPermanentAccountUsed(storage);
    expect(storage.getItem(PERMANENT_ACCOUNT_USED_STORAGE_KEY)).toBe('yes');
    expect(hasUsedPermanentAccount(storage)).toBe(true);
  });

  test('persists learning memory across an external sign-in round trip', () => {
    const storage = memoryStorage();
    const progress: ProgressState = {
      dailyTarget: 20,
      streak: 2,
      studiedToday: 4,
      words: {},
    };
    savePendingAccountUpgrade(
      storage,
      {
        customSets: emptyCustomSetState,
        progress,
        sourceUserId: 'guest-1',
      },
      new Date('2026-08-13T02:00:00.000Z'),
    );

    expect(loadPendingAccountUpgrade(storage)).toEqual({
      createdAt: '2026-08-13T02:00:00.000Z',
      customSets: emptyCustomSetState,
      progress,
      sourceUserId: 'guest-1',
    });

    clearPendingAccountUpgrade(storage);
    expect(loadPendingAccountUpgrade(storage)).toBeNull();
  });
});
