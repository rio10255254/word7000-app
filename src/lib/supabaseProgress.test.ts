import { describe, expect, test } from 'vitest';
import {
  createDisabledCloudProgress,
  deleteCloudUserData,
  isSupabaseConfigured,
  loadCloudProgress,
  loadCloudProgressRecord,
  localActivityDate,
  recordDailyActiveUser,
  saveCloudCustomSets,
  saveCloudProgress,
  saveCloudUserMemory,
  type CloudProgressClient,
} from './supabaseProgress';
import type { ProgressState } from './progress';
import type { CustomSetState } from './customSets';

function progressState(studiedToday: number): ProgressState {
  return {
    dailyTarget: 20,
    streak: 1,
    studiedToday,
    words: {},
  };
}

const customSetState: CustomSetState = {
  customWords: [
    {
      example: 'I felt jetlag after the long flight.',
      exampleZh: '長途飛行後我覺得有時差疲勞。',
      group: 'Custom',
      id: 'custom-jetlag',
      meaningZh: '時差疲勞',
      partOfSpeech: 'n',
      pronunciation: '/jetlag/',
      word: 'jetlag',
    },
  ],
  sets: [
    {
      color: '#2563eb',
      createdAt: '2026-07-02T06:00:00.000Z',
      id: 'set-travel',
      name: '旅行英文',
      sortOrder: 1,
      updatedAt: '2026-07-02T06:05:00.000Z',
      wordIds: ['custom-jetlag'],
    },
  ],
};

function fakeClient(cloudProgress: ProgressState | null, cloudCustomSets: CustomSetState | null = null): CloudProgressClient {
  return {
    from(tableName: string) {
      if (tableName === 'daily_active_users') {
        return {
          upsert(
            payload: { activity_date: string; last_seen_at: string; user_id: string },
            options?: { onConflict?: string },
          ) {
            expect(payload.user_id).toBe('user-1');
            expect(payload.activity_date).toBe('2026-07-01');
            expect(payload.last_seen_at).toBe('2026-07-01T01:02:03.000Z');
            expect(options?.onConflict).toBe('user_id,activity_date');

            return {
              async throwOnError() {
                return { data: null, error: null };
              },
            };
          },
        };
      }

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
                    data: cloudProgress || cloudCustomSets
                      ? { custom_sets: cloudCustomSets, progress: cloudProgress }
                      : null,
                    error: null,
                  };
                },
              };
            },
          };
        },
        upsert(payload: { custom_sets?: CustomSetState; id: string; progress?: ProgressState; updated_at: string }) {
          expect(payload.id).toBe('user-1');
          if (payload.progress) {
            expect(payload.progress.studiedToday).toBe(4);
          }
          if (payload.custom_sets) {
            expect(payload.custom_sets).toEqual(customSetState);
          }
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

  test('reports whether a signed-in user already has cloud progress', async () => {
    await expect(loadCloudProgressRecord(fakeClient(progressState(9)), 'user-1')).resolves.toEqual({
      customSets: null,
      errorMessage: null,
      found: true,
      progress: progressState(9),
    });

    await expect(loadCloudProgressRecord(fakeClient(null), 'user-1')).resolves.toEqual({
      customSets: null,
      errorMessage: null,
      found: false,
      progress: null,
    });
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

  test('loads and saves custom vocabulary sets for the signed-in user', async () => {
    await expect(loadCloudProgressRecord(fakeClient(progressState(9), customSetState), 'user-1')).resolves.toEqual({
      customSets: customSetState,
      errorMessage: null,
      found: true,
      progress: progressState(9),
    });

    await expect(saveCloudCustomSets(fakeClient(null), 'user-1', customSetState)).resolves.toEqual({
      ok: true,
      message: 'Saved',
    });
  });

  test('saves progress and custom vocabulary sets together after sign-in', async () => {
    await expect(saveCloudUserMemory(fakeClient(null), 'user-1', progressState(4), customSetState)).resolves.toEqual({
      ok: true,
      message: 'Saved',
    });
  });

  test('does not surface the Supabase schema-cache error while custom sets column is pending', async () => {
    const client: CloudProgressClient = {
      from(tableName: string) {
        expect(tableName).toBe('profiles');

        return {
          select() {
            return {
              eq() {
                return {
                  async maybeSingle() {
                    return { data: null, error: null };
                  },
                };
              },
            };
          },
          upsert() {
            return {
              async throwOnError() {
                throw new Error("Could not find the 'custom_sets' column of 'profiles' in the schema cache");
              },
            };
          },
        };
      },
    };

    await expect(saveCloudCustomSets(client, 'user-1', customSetState)).resolves.toEqual({
      ok: true,
      message: 'Custom sets sync pending schema update',
    });
  });

  test('keeps loading progress if the custom sets column has not been created yet', async () => {
    const selectedColumns: string[] = [];
    const client: CloudProgressClient = {
      from(tableName: string) {
        expect(tableName).toBe('profiles');

        return {
          select(columns?: string) {
            selectedColumns.push(columns ?? '');

            return {
              eq(columnName: string, userId: string) {
                expect(columnName).toBe('id');
                expect(userId).toBe('user-1');

                return {
                  async maybeSingle() {
                    if (columns?.includes('custom_sets')) {
                      return {
                        data: null,
                        error: { message: 'column profiles.custom_sets does not exist' },
                      };
                    }

                    return {
                      data: { progress: progressState(8) },
                      error: null,
                    };
                  },
                };
              },
            };
          },
          upsert() {
            return {
              async throwOnError() {
                return { data: null, error: null };
              },
            };
          },
        };
      },
    };

    await expect(loadCloudProgressRecord(client, 'user-1')).resolves.toEqual({
      customSets: null,
      errorMessage: null,
      found: true,
      progress: progressState(8),
    });
    expect(selectedColumns).toEqual(['progress, custom_sets', 'progress']);
  });

  test('records one daily active row per signed-in user and date', async () => {
    await expect(
      recordDailyActiveUser(fakeClient(null), 'user-1', new Date('2026-07-01T01:02:03.000Z')),
    ).resolves.toEqual({
      ok: true,
      message: 'Recorded',
    });
  });

  test('deletes a signed-in user profile and activity rows for account data removal', async () => {
    const deletedTables: string[] = [];
    const client = {
      from(tableName: string) {
        deletedTables.push(tableName);

        return {
          delete() {
            return {
              eq(columnName: string, userId: string) {
                expect(userId).toBe('user-1');
                expect(['id', 'user_id']).toContain(columnName);

                return {
                  async throwOnError() {
                    return { data: null, error: null };
                  },
                };
              },
            };
          },
        };
      },
    } as unknown as CloudProgressClient;

    await expect(deleteCloudUserData(client, 'user-1')).resolves.toEqual({
      ok: true,
      message: 'Deleted',
    });
    expect(deletedTables).toEqual(['daily_active_users', 'profiles']);
  });

  test('uses the device local date for daily activity', () => {
    const timezoneOffset = Date.prototype.getTimezoneOffset;

    try {
      Date.prototype.getTimezoneOffset = () => -480;

      expect(localActivityDate(new Date('2026-06-30T18:00:00.000Z'))).toBe('2026-07-01');
    } finally {
      Date.prototype.getTimezoneOffset = timezoneOffset;
    }
  });
});
