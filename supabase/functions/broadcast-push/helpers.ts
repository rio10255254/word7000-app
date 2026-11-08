// Pure helpers for broadcast-push, kept apart from Deno.serve so tests can import them.

/**
 * Whether the caller sent the shared secret. Both sides are hashed first, so
 * the comparison takes the same time whatever the lengths or the first
 * differing byte.
 */
export async function sameSecret(given: string | null, expected: string): Promise<boolean> {
  if (!expected) return false;
  const encoder = new TextEncoder();
  const [a, b] = await Promise.all([given ?? '', expected].map((value) =>
    crypto.subtle.digest('SHA-256', encoder.encode(value))));
  const left = new Uint8Array(a), right = new Uint8Array(b);
  let difference = given == null ? 1 : 0;
  for (let index = 0; index < left.length; index++) difference |= left[index] ^ right[index];
  return difference === 0;
}

export type Page<T> = { data: T[] | null; error: unknown };

/**
 * Every row of a query, page by page. PostgREST returns at most its max_rows
 * (1000 on Supabase) whatever limit is asked for, so one request only ever saw
 * the first thousand phones. Pages advance by what actually came back, so a
 * server cap smaller than `size` cannot end the reading early; it ends on an
 * empty page. Rows seen twice (a phone registered while reading shifts the
 * pages) are kept once, by `key`.
 */
export async function readAllPages<T>(
  page: (from: number, to: number) => PromiseLike<Page<T>>,
  key: (row: T) => string,
  size = 1000,
): Promise<{ rows: T[]; error: unknown }> {
  const rows: T[] = [];
  const seen = new Set<string>();
  for (let from = 0; ;) {
    const { data, error } = await page(from, from + size - 1);
    if (error) return { rows, error };
    if (!data || data.length === 0) return { rows, error: null };
    for (const row of data) {
      if (seen.has(key(row))) continue;
      seen.add(key(row));
      rows.push(row);
    }
    from += data.length;
  }
}
