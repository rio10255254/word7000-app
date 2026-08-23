import type { CustomSetState } from './customSets';
import { isCustomSetState } from './customSets';
import type { ProgressState } from './progress';
import { isProgressState, type StorageLike } from './progressStorage';

const OUTBOX_STORAGE_KEY = 'word7000-sync-outbox-v1';

export type UserMemorySnapshot = {
  customSets: CustomSetState;
  progress: ProgressState;
};

export type UserMemoryDirtyFields = {
  customSets?: boolean;
  progress?: boolean;
};

export type UserMemorySyncResult = {
  message: string;
  ok: boolean;
};

export type UserMemorySyncStatus = 'idle' | 'pending' | 'syncing' | 'saved' | 'error';

type StoredOutbox = UserMemorySnapshot & {
  dirty: Required<UserMemoryDirtyFields>;
  queuedAt: string;
  version: 1;
};

type UserMemorySyncQueueOptions = {
  flushDelayMs?: number;
  maxRetryDelayMs?: number;
  persistDelayMs?: number;
  retryDelayMs?: number;
  saveAll: (snapshot: UserMemorySnapshot) => Promise<UserMemorySyncResult>;
  saveCustomSets: (customSets: CustomSetState) => Promise<UserMemorySyncResult>;
  saveProgress: (progress: ProgressState) => Promise<UserMemorySyncResult>;
  storage?: StorageLike;
  userId: string;
};

export function userMemoryOutboxKey(userId: string): string {
  return `${OUTBOX_STORAGE_KEY}:user:${userId}`;
}

export function loadUserMemoryOutbox(storage: StorageLike | undefined, userId: string): StoredOutbox | null {
  if (!storage) {
    return null;
  }

  try {
    const raw = storage.getItem(userMemoryOutboxKey(userId));
    if (!raw) {
      return null;
    }
    const parsed: unknown = JSON.parse(raw);
    return isStoredOutbox(parsed) ? parsed : null;
  } catch {
    return null;
  }
}

export function clearUserMemoryOutbox(storage: StorageLike | undefined, userId: string): void {
  try {
    storage?.removeItem?.(userMemoryOutboxKey(userId));
  } catch {
    // A stale outbox is safer than interrupting the app when storage is unavailable.
  }
}

export class UserMemorySyncQueue {
  private readonly flushDelayMs: number;
  private readonly maxRetryDelayMs: number;
  private readonly persistDelayMs: number;
  private readonly retryDelayMs: number;
  private readonly listeners = new Set<() => void>();
  private readonly options: UserMemorySyncQueueOptions;
  private disposed = false;
  private flushPromise: Promise<UserMemorySyncResult> | null = null;
  private pending: StoredOutbox | null = null;
  private persistTimer: ReturnType<typeof setTimeout> | null = null;
  private retryAttempt = 0;
  private status: UserMemorySyncStatus = 'idle';
  private timer: ReturnType<typeof setTimeout> | null = null;

  constructor(options: UserMemorySyncQueueOptions) {
    this.options = options;
    this.flushDelayMs = options.flushDelayMs ?? 900;
    this.maxRetryDelayMs = options.maxRetryDelayMs ?? 5 * 60_000;
    this.persistDelayMs = options.persistDelayMs ?? 250;
    this.retryDelayMs = options.retryDelayMs ?? 3000;
  }

  subscribe = (listener: () => void): (() => void) => {
    this.listeners.add(listener);
    return () => this.listeners.delete(listener);
  };

  getStatus = (): UserMemorySyncStatus => this.status;

  restore(): UserMemorySnapshot | null {
    const stored = loadUserMemoryOutbox(this.options.storage, this.options.userId);
    if (!stored) {
      return null;
    }

    this.pending = stored;
    this.setStatus('pending');
    this.schedule(0);
    return { customSets: stored.customSets, progress: stored.progress };
  }

  enqueue(snapshot: UserMemorySnapshot, dirty: UserMemoryDirtyFields): void {
    if (this.disposed || (!dirty.progress && !dirty.customSets)) {
      return;
    }

    this.pending = {
      customSets: snapshot.customSets,
      dirty: {
        customSets: Boolean(this.pending?.dirty.customSets || dirty.customSets),
        progress: Boolean(this.pending?.dirty.progress || dirty.progress),
      },
      progress: snapshot.progress,
      queuedAt: new Date().toISOString(),
      version: 1,
    };
    this.schedulePersist();
    this.setStatus('pending');
    this.schedule(this.flushDelayMs);
  }

  async flush(): Promise<UserMemorySyncResult> {
    if (this.flushPromise) {
      return this.flushPromise;
    }
    if (!this.pending || this.disposed) {
      return { message: 'Nothing to sync', ok: true };
    }

    this.clearTimer();
    this.persistPendingNow();
    const batch = this.pending;
    this.pending = null;
    this.setStatus('syncing');
    this.flushPromise = this.saveBatch(batch)
      .then((result) => {
        if (result.ok) {
          this.retryAttempt = 0;
          if (this.pending) {
            this.schedulePersist();
            this.setStatus('pending');
            this.schedule(this.flushDelayMs);
          } else {
            clearUserMemoryOutbox(this.options.storage, this.options.userId);
            this.setStatus('saved');
          }
          return result;
        }

        this.restoreFailedBatch(batch);
        return result;
      })
      .catch((error: unknown) => {
        this.restoreFailedBatch(batch);
        return {
          message: error instanceof Error ? error.message : 'Sync failed',
          ok: false,
        };
      })
      .finally(() => {
        this.flushPromise = null;
      });

    return this.flushPromise;
  }

  dispose(): void {
    this.disposed = true;
    this.clearTimer();
    this.persistPendingNow();
    this.clearPersistTimer();
    this.listeners.clear();
  }

  private saveBatch(batch: StoredOutbox): Promise<UserMemorySyncResult> {
    if (batch.dirty.progress && batch.dirty.customSets) {
      return this.options.saveAll(batch);
    }
    if (batch.dirty.progress) {
      return this.options.saveProgress(batch.progress);
    }
    return this.options.saveCustomSets(batch.customSets);
  }

  private restoreFailedBatch(batch: StoredOutbox): void {
    const newest = this.pending ?? batch;
    this.pending = {
      ...newest,
      dirty: {
        customSets: Boolean(batch.dirty.customSets || this.pending?.dirty.customSets),
        progress: Boolean(batch.dirty.progress || this.pending?.dirty.progress),
      },
    };
    this.persistPendingNow();
    this.setStatus('error');
    const retryDelay = Math.min(this.retryDelayMs * 2 ** this.retryAttempt, this.maxRetryDelayMs);
    this.retryAttempt += 1;
    this.schedule(retryDelay);
  }

  private schedulePersist(): void {
    this.clearPersistTimer();
    if (this.persistDelayMs <= 0) {
      this.persistPendingNow();
      return;
    }
    this.persistTimer = setTimeout(() => {
      this.persistTimer = null;
      this.persistPendingNow();
    }, this.persistDelayMs);
  }

  private persistPendingNow(): void {
    this.clearPersistTimer();
    if (!this.pending) {
      return;
    }
    try {
      this.options.storage?.setItem(userMemoryOutboxKey(this.options.userId), JSON.stringify(this.pending));
    } catch {
      // The queue remains in memory and retries even if persistent storage is unavailable.
    }
  }

  private schedule(delayMs: number): void {
    if (this.disposed) {
      return;
    }
    this.clearTimer();
    this.timer = setTimeout(() => {
      this.timer = null;
      void this.flush();
    }, delayMs);
  }

  private clearTimer(): void {
    if (this.timer) {
      clearTimeout(this.timer);
      this.timer = null;
    }
  }

  private clearPersistTimer(): void {
    if (this.persistTimer) {
      clearTimeout(this.persistTimer);
      this.persistTimer = null;
    }
  }

  private setStatus(status: UserMemorySyncStatus): void {
    if (this.status === status) {
      return;
    }
    this.status = status;
    this.listeners.forEach((listener) => listener());
  }
}

function isStoredOutbox(value: unknown): value is StoredOutbox {
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    return false;
  }

  const outbox = value as Partial<StoredOutbox>;
  return (
    outbox.version === 1 &&
    typeof outbox.queuedAt === 'string' &&
    isProgressState(outbox.progress) &&
    isCustomSetState(outbox.customSets) &&
    Boolean(outbox.dirty && typeof outbox.dirty.progress === 'boolean' && typeof outbox.dirty.customSets === 'boolean')
  );
}
