import { describe, expect, test, vi } from 'vitest';
import { deleteAuthenticatedAccount } from './accountDeletion';

describe('account deletion', () => {
  test('uses the authenticated backend deletion endpoint', async () => {
    const invoke = vi.fn(async () => ({ data: { deleted: true }, error: null }));
    const result = await deleteAuthenticatedAccount({ functions: { invoke } } as never);

    expect(result).toEqual({ message: 'Deleted', ok: true });
    expect(invoke).toHaveBeenCalledWith('delete-account', { body: {}, method: 'POST' });
  });

  test('does not report success when the backend rejects deletion', async () => {
    const result = await deleteAuthenticatedAccount({
      functions: { invoke: async () => ({ data: null, error: { message: 'Unauthorized' } }) },
    } as never);

    expect(result).toEqual({ message: 'Unauthorized', ok: false });
  });
});
