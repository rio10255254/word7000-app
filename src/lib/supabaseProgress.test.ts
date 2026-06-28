import { describe, expect, test } from 'vitest';
import {
  createDisabledCloudProgress,
  isSupabaseConfigured,
  loadCloudProgress,
  saveCloudProgress,
  type CloudProgressClient,
} from './supabaseProgress';
import type { ProgressState } from './progress';

function progressState(studiedToday: number): ProgressState {
  return {
    dailyTarget: 20,
    streak: 1,
    studiedToday,
    words: {},
  };
}

function fakeClient(cloudProgress: ProgressState | null): CloudProgressClient {
  return {
    from(tableName: string) {
      expect(tableName).toBe('profiles');

      return {
        select() {
          return {
            eq(columnName: string, userId: string) {
              expect(columnName).toBe('id');
              expect(userId).toBe('user-1');

              return {
                async maybeSingle() {
                  return {
                    data: cloudProgress ? { progress: cloudProgress } : null,
                    error: null,
                  };
                },
              };
            },
          };
        },
        upsert(payload: { id: string; progress: ProgressState; updated_at: string }) {
          expect(payload.id).toBe('user-1');
          expect(payload.progress.studiedToday).toBe(4);
          expect(payload.updated_at).toMatch(/^\d{4}-\d{2}-\d{2}T/);

          return {
            async throwOnError() {
              return { data: null, error: null };
            },
          };
        },
      };
    },
  };
}

describe('Supabase progress sync', () => {
  test('detects whether public Supabase settings are configured', () => {
    expect(isSupabaseConfigured('https://project.supabase.co', 'anon-key')).toBe(true);
    expect(isSupabaseConfigured('', 'anon-key')).toBe(false);
    expect(isSupabaseConfigured('https://project.supabase.co', '')).toBe(false);
  });

  test('returns local progress when cloud sync is disabled', async () => {
    const disabled = createDisabledCloudProgress(progressState(2));

    expect(await disabled.load()).toEqual(progressState(2));
    await expect(disabled.save(progressState(3))).resolves.toEqual({
      ok: false,
      message: 'Supabase is not configured',
    });
  });

  test('loads cloud progress for the signed-in user', async () => {
    await expect(loadCloudProgress(fakeClient(progressState(9)), 'user-1', progressState(1))).resolves.toEqual(
      progressState(9),
    );
  });

  test('keeps local progress when no cloud row exists yet', async () => {
    await expect(loadCloudProgress(fakeClient(null), 'user-1', progressState(5))).resolves.toEqual(progressState(5));
  });

  test('saves progress to the signed-in user row', async () => {
    await expect(saveCloudProgress(fakeClient(null), 'user-1', progressState(4))).resolves.toEqual({
      ok: true,
      message: 'Saved',
    });
  });
});

