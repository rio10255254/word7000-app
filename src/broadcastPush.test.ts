import fs from 'node:fs';
import path from 'node:path';
import { describe, expect, it } from 'vitest';
import { readAllPages, sameSecret } from '../supabase/functions/broadcast-push/helpers';

describe('broadcast-push', () => {
  it('accepts only the exact shared secret', async () => {
    expect(await sameSecret('s3cret-value', 's3cret-value')).toBe(true);
    for (const given of [null, '', 's3cret-valu', 's3cret-value ', 'S3cret-value', 'x'.repeat(500)]) {
      expect(await sameSecret(given, 's3cret-value')).toBe(false);
    }
    // No configured secret never matches, not even an empty header.
    expect(await sameSecret('', '')).toBe(false);
    expect(await sameSecret(null, '')).toBe(false);
  });

  it('reads every phone past the server row cap, once each', async () => {
    const tokens = Array.from({ length: 2_345 }, (_, index) => ({ token: `t${String(index).padStart(5, '0')}` }));
    const asked: [number, number][] = [];
    // A server that never returns more than 1000 rows, whatever is asked for.
    const server = (cap: number) => async (from: number, to: number) => {
      asked.push([from, to]);
      return { data: tokens.slice(from, Math.min(to + 1, from + cap)), error: null };
    };
    const all = await readAllPages(server(1000), (row) => row.token);
    expect(all.error).toBeNull();
    expect(all.rows).toHaveLength(2_345);
    expect(asked[0]).toEqual([0, 999]);
    // A lower cap than the page size does not end the reading early.
    const capped = await readAllPages(server(300), (row) => row.token);
    expect(capped.rows.map((row) => row.token)).toEqual(tokens.map((row) => row.token));
  });

  it('keeps a row seen twice once, and stops on an error', async () => {
    const pages = [[{ token: 'a' }, { token: 'b' }], [{ token: 'b' }, { token: 'c' }], []];
    const result = await readAllPages(async () => ({ data: pages.shift() ?? [], error: null }), (row) => row.token, 2);
    expect(result.rows.map((row) => row.token)).toEqual(['a', 'b', 'c']);
    const failed = await readAllPages(async () => ({ data: null, error: { message: 'down' } }), (row: { token: string }) => row.token);
    expect(failed.error).toEqual({ message: 'down' });
  });

  it('refuses callers without the service key before doing anything, and the workflow sends it', () => {
    const source = fs.readFileSync(path.join(process.cwd(), 'supabase/functions/broadcast-push/index.ts'), 'utf8');
    const guard = source.indexOf("request.headers.get('x-broadcast-secret')");
    expect(guard).toBeGreaterThan(0);
    expect(source).toContain("Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')");
    expect(source.indexOf("error: 'unauthorized'")).toBeLessThan(source.indexOf("from('announcements')"));
    expect(source).not.toContain('.limit(100_000)');
    const script = fs.readFileSync(path.join(process.cwd(), 'scripts/remote-control.sh'), 'utf8');
    expect(script).toContain('-H "x-broadcast-secret: ${BROADCAST_PUSH_SECRET:-$service}"');
  });
});
