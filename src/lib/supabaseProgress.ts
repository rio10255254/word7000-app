import type { ProgressState } from './progress';
import { isProgressState } from './progressStorage';

export type CloudProgressResult = {
  ok: boolean;
  message: string;
};

export type CloudProgressClient = {
  from: (tableName: 'profiles') => {
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
  const { data, error } = await client.from('profiles').select('progress').eq('id', userId).maybeSingle();

  if (error) {
    return fallback;
  }

  return isProgressState(data?.progress) ? data.progress : fallback;
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

