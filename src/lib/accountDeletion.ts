import type { AppSupabaseClient } from './supabaseClient';

export type AccountDeletionResult = {
  message: string;
  ok: boolean;
};

export async function deleteAuthenticatedAccount(client: AppSupabaseClient): Promise<AccountDeletionResult> {
  try {
    const { data, error } = await client.functions.invoke('delete-account', {
      body: {},
      method: 'POST',
    });

    if (error) {
      return { message: error.message || 'Account deletion failed', ok: false };
    }
    if (data && typeof data === 'object' && 'error' in data && typeof data.error === 'string') {
      return { message: data.error, ok: false };
    }

    return { message: 'Deleted', ok: true };
  } catch (error) {
    return {
      message: error instanceof Error ? error.message : 'Account deletion failed',
      ok: false,
    };
  }
}
