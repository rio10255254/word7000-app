import type { ProgressState } from './progress';
import { isProgressState } from './progressStorage';

export type CloudProgressResult = {
  ok: boolean;
  message: string;
};

export type CloudProgressLoadResult = {
  errorMessage: string | null;
  found: boolean;
  progress: ProgressState | null;
};

type ProfilesTableQuery = {
  select: (columns?: string) => {
    eq: (
      columnName: 'id',
      userId: string,
    ) => {
      maybeSingle: () => Promise<{ data: { progress?: unknown } | null; error: { message?: string } | null }>;
    };
  };
  upsert: (payload: { id: string; progress: ProgressState; updated_at: string }) => {
    throwOnError: () => Promise<unknown>;
  };
};

type DailyActiveUsersTableQuery = {
  upsert: (
    payload: { activity_date: string; last_seen_at: string; user_id: string },
    options?: { onConflict?: string },
  ) => {
    throwOnError: () => Promise<unknown>;
  };
};

export type CloudProgressClient = {
  from: {
    (tableName: 'profiles'): ProfilesTableQuery;
    (tableName: 'daily_active_users'): DailyActiveUsersTableQuery;
  };
};

export function isSupabaseConfigured(url?: string, anonKey?: string): boolean {
  return Boolean(url?.trim() && anonKey?.trim());
}

export function createDisabledCloudProgress(localProgress: ProgressState) {
  return {
    load: async () => localProgress,
    save: async (): Promise<CloudProgressResult> => ({
      ok: false,
      message: 'Supabase is not configured',
    }),
  };
}

export async function loadCloudProgress(
  client: CloudProgressClient,
  userId: string,
  fallback: ProgressState,
): Promise<ProgressState> {
  const result = await loadCloudProgressRecord(client, userId);

  return result.progress ?? fallback;
}

export async function loadCloudProgressRecord(
  client: CloudProgressClient,
  userId: string,
): Promise<CloudProgressLoadResult> {
  const { data, error } = await client.from('profiles').select('progress').eq('id', userId).maybeSingle();

  if (error) {
    return {
      errorMessage: error.message ?? 'Load failed',
      found: false,
      progress: null,
    };
  }

  if (!isProgressState(data?.progress)) {
    return {
      errorMessage: null,
      found: false,
      progress: null,
    };
  }

  return {
    errorMessage: null,
    found: true,
    progress: data.progress,
  };
}

export async function saveCloudProgress(
  client: CloudProgressClient,
  userId: string,
  progress: ProgressState,
): Promise<CloudProgressResult> {
  try {
    await client
      .from('profiles')
      .upsert({
        id: userId,
        progress,
        updated_at: new Date().toISOString(),
      })
      .throwOnError();

    return {
      ok: true,
      message: 'Saved',
    };
  } catch (error) {
    return {
      ok: false,
      message: error instanceof Error ? error.message : 'Save failed',
    };
  }
}

export async function recordDailyActiveUser(
  client: CloudProgressClient,
  userId: string,
  now = new Date(),
): Promise<CloudProgressResult> {
  const seenAt = now.toISOString();
  const activityDate = seenAt.slice(0, 10);

  try {
    await client
      .from('daily_active_users')
      .upsert(
        {
          activity_date: activityDate,
          last_seen_at: seenAt,
          user_id: userId,
        },
        {
          onConflict: 'user_id,activity_date',
        },
      )
      .throwOnError();

    return {
      ok: true,
      message: 'Recorded',
    };
  } catch (error) {
    return {
      ok: false,
      message: error instanceof Error ? error.message : 'Activity save failed',
    };
  }
}
