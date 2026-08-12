import type { User as SupabaseUser } from '@supabase/supabase-js';
import { isCustomSetState, type CustomSetState } from './customSets';
import type { ProgressState } from './progress';
import { isProgressState, type StorageLike } from './progressStorage';

export const ACCOUNT_PROTECTION_PROMPT_STORAGE_KEY = 'word7000-account-protection-prompt-v1';
export const PERMANENT_ACCOUNT_USED_STORAGE_KEY = 'word7000-permanent-account-used-v1';
export const PENDING_ACCOUNT_UPGRADE_STORAGE_KEY = 'word7000-pending-account-upgrade-v1';

export type AccountUpgradeReason = 'customSets' | 'dataTools' | 'protectProgress';

export type PendingAccountUpgrade = {
  createdAt: string;
  customSets: CustomSetState;
  progress: ProgressState;
  sourceUserId: string | null;
};

export function isAnonymousUser(user: Pick<SupabaseUser, 'is_anonymous'> | null | undefined): boolean {
  return user?.is_anonymous === true;
}

export function isIdentityAlreadyLinkedError(error: unknown): boolean {
  if (!error || typeof error !== 'object') {
    return false;
  }

  const candidate = error as { code?: unknown; message?: unknown };
  const code = typeof candidate.code === 'string' ? candidate.code : '';
  const message = typeof candidate.message === 'string' ? candidate.message : '';
  return code === 'identity_already_exists' || /already (?:linked|registered)|identity.*another user/i.test(message);
}

export function shouldPromptToProtectProgress(storage: StorageLike | undefined): boolean {
  return storage?.getItem(ACCOUNT_PROTECTION_PROMPT_STORAGE_KEY) !== 'seen';
}

export function markProgressProtectionPromptSeen(storage: StorageLike | undefined): void {
  try {
    storage?.setItem(ACCOUNT_PROTECTION_PROMPT_STORAGE_KEY, 'seen');
  } catch {
    // A failed preference write should never interrupt studying.
  }
}

export function hasUsedPermanentAccount(storage: StorageLike | undefined): boolean {
  return storage?.getItem(PERMANENT_ACCOUNT_USED_STORAGE_KEY) === 'yes';
}

export function markPermanentAccountUsed(storage: StorageLike | undefined): void {
  try {
    storage?.setItem(PERMANENT_ACCOUNT_USED_STORAGE_KEY, 'yes');
  } catch {
    // Sign-in remains valid even if this device preference cannot be saved.
  }
}

export function savePendingAccountUpgrade(
  storage: StorageLike | undefined,
  snapshot: Omit<PendingAccountUpgrade, 'createdAt'>,
  now = new Date(),
): void {
  try {
    storage?.setItem(
      PENDING_ACCOUNT_UPGRADE_STORAGE_KEY,
      JSON.stringify({
        ...snapshot,
        createdAt: now.toISOString(),
      } satisfies PendingAccountUpgrade),
    );
  } catch {
    // The in-memory session can still complete even when storage is unavailable.
  }
}

export function loadPendingAccountUpgrade(storage: StorageLike | undefined): PendingAccountUpgrade | null {
  if (!storage) {
    return null;
  }

  try {
    const stored = storage.getItem(PENDING_ACCOUNT_UPGRADE_STORAGE_KEY);
    if (!stored) {
      return null;
    }

    const parsed: unknown = JSON.parse(stored);
    return isPendingAccountUpgrade(parsed) ? parsed : null;
  } catch {
    return null;
  }
}

export function clearPendingAccountUpgrade(storage: StorageLike | undefined): void {
  try {
    storage?.removeItem?.(PENDING_ACCOUNT_UPGRADE_STORAGE_KEY);
  } catch {
    // Cleanup is best-effort; a merged snapshot is idempotent if loaded again.
  }
}

function isPendingAccountUpgrade(value: unknown): value is PendingAccountUpgrade {
  if (!value || typeof value !== 'object') {
    return false;
  }

  const candidate = value as Partial<PendingAccountUpgrade>;
  return (
    typeof candidate.createdAt === 'string' &&
    (candidate.sourceUserId === null || typeof candidate.sourceUserId === 'string') &&
    isProgressState(candidate.progress) &&
    isCustomSetState(candidate.customSets)
  );
}
