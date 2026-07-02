import type { ProgressState } from './progress';
import { isProgressState } from './progressStorage';
import { isCustomSetState, type CustomSetState } from './customSets';

export type CloudProgressResult = {
  ok: boolean;
  message: string;
};

export type CloudProgressLoadResult = {
  customSets: CustomSetState | null;
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
      maybeSingle: () => Promise<ProfileLoadResponse>;
    };
  };
  upsert: (payload: { custom_sets?: CustomSetState; id: string; progress?: ProgressState; updated_at: string }) => {
    throwOnError: () => Promise<unknown>;
  };
};

type ProfileLoadResponse = {
  data: { custom_sets?: unknown; progress?: unknown } | null;
  error: { message?: string } | null;
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
  const primary = await loadProfileRow(client, userId, 'progress, custom_sets');

  if (primary.error && isMissingCustomSetsColumn(primary.error.message)) {
    return profileRowToLoadResult(await loadProfileRow(client, userId, 'progress'));
  }

  return profileRowToLoadResult(primary);
}

async function loadProfileRow(
  client: CloudProgressClient,
  userId: string,
  columns: string,
): Promise<ProfileLoadResponse> {
  return client.from('profiles').select(columns).eq('id', userId).maybeSingle();
}

function profileRowToLoadResult({ data, error }: ProfileLoadResponse): CloudProgressLoadResult {
  if (error) {
    return {
      customSets: null,
      errorMessage: error.message ?? 'Load failed',
      found: false,
      progress: null,
    };
  }

  if (!data) {
    return {
      customSets: null,
      errorMessage: null,
      found: false,
      progress: null,
    };
  }

  const progress = isProgressState(data.progress) ? data.progress : null;
  const customSets = isCustomSetState(data.custom_sets) ? data.custom_sets : null;

  return {
    customSets,
    errorMessage: null,
    found: true,
    progress,
  };
}

function isMissingCustomSetsColumn(message?: string): boolean {
  return Boolean(message && /custom_sets|column/i.test(message));
}

function errorMessageFromUnknown(error: unknown): string | undefined {
  if (error instanceof Error) {
    return error.message;
  }

  if (error && typeof error === 'object' && 'message' in error) {
    const message = (error as { message?: unknown }).message;
    return typeof message === 'string' ? message : undefined;
  }

  return undefined;
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
      message: errorMessageFromUnknown(error) ?? 'Save failed',
    };
  }
}

export async function saveCloudCustomSets(
  client: CloudProgressClient,
  userId: string,
  customSets: CustomSetState,
): Promise<CloudProgressResult> {
  try {
    await client
      .from('profiles')
      .upsert({
        custom_sets: customSets,
        id: userId,
        updated_at: new Date().toISOString(),
      })
      .throwOnError();

    return {
      ok: true,
      message: 'Saved',
    };
  } catch (error) {
    if (isMissingCustomSetsColumn(errorMessageFromUnknown(error))) {
      return {
        ok: true,
        message: 'Custom sets sync pending schema update',
      };
    }

    return {
      ok: false,
      message: errorMessageFromUnknown(error) ?? 'Save failed',
    };
  }
}

export async function recordDailyActiveUser(
  client: CloudProgressClient,
  userId: string,
  now = new Date(),
): Promise<CloudProgressResult> {
  const seenAt = now.toISOString();
  const activityDate = localActivityDate(now);

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

export function localActivityDate(now = new Date()): string {
  const localTime = now.getTime() - now.getTimezoneOffset() * 60_000;
  return new Date(localTime).toISOString().slice(0, 10);
}
