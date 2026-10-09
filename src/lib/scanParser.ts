/**
 * Turns text recognised on a photo of a vocabulary sheet into word / meaning
 * pairs. The meaning is the one printed on the paper; nothing is translated.
 *
 * Coordinates are normalised to the image (0..1) with the origin at the top
 * left, which is what the native scanner returns.
 */
export type ScannedLine = {
  height: number;
  text: string;
  width: number;
  x: number;
  y: number;
};

export type ScannedWordCandidate = {
  /** Stable within one scan, used as the list key while reviewing. */
  key: string;
  meaningZh: string;
  partOfSpeech: string;
  word: string;
};

type Segment = { kind: 'latin' | 'cjk'; text: string };

type ParsedLine = {
  line: ScannedLine;
  pairs: Array<{ meaningZh: string; partOfSpeech: string; word: string }>;
  /** English headword with no meaning on the same line. */
  pendingWord: { partOfSpeech: string; word: string } | null;
  /** The line is nothing but a Chinese meaning. */
  meaningOnly: string | null;
};

const CJK = /[㐀-䶿一-鿿豈-﫿]/;
const LATIN = /[A-Za-z]/;
const POS_TOKENS = new Set([
  'n', 'v', 'vt', 'vi', 'a', 'adj', 'ad', 'adv', 'prep', 'conj', 'pron', 'phr', 'num', 'int', 'interj', 'art', 'aux',
]);
const MAX_HEADWORD_TOKENS = 4;

export function parseScannedLines(lines: ScannedLine[]): ScannedWordCandidate[] {
  const ordered = [...lines]
    .map((line) => ({ ...line, text: normaliseText(line.text) }))
    .filter((line) => line.text.length > 0)
    .sort((left, right) => left.y - right.y || left.x - right.x);
  const parsed = ordered.map(parseLine);
  const usedMeaning = new Set<number>();
  const results: Array<{ meaningZh: string; partOfSpeech: string; word: string }> = [];

  parsed.forEach((entry, index) => {
    results.push(...entry.pairs);
    if (!entry.pendingWord) {
      return;
    }
    const partnerIndex = findMeaningPartner(parsed, index, usedMeaning);
    if (partnerIndex === null) {
      return;
    }
    usedMeaning.add(partnerIndex);
    results.push({ ...entry.pendingWord, meaningZh: parsed[partnerIndex].meaningOnly ?? '' });
  });

  const seen = new Set<string>();
  return results.flatMap((result, index) => {
    const dedupeKey = result.word.toLowerCase();
    if (!result.meaningZh || seen.has(dedupeKey)) {
      return [];
    }
    seen.add(dedupeKey);
    return [{ ...result, key: `${index}-${dedupeKey}` }];
  });
}

/**
 * A headword without a meaning on its own line is paired with a meaning-only
 * line either on the same row to its right (a two-column table) or directly
 * below it (word on one line, meaning under it).
 */
function findMeaningPartner(parsed: ParsedLine[], index: number, used: Set<number>): number | null {
  const source = parsed[index].line;
  const sourceCenter = source.y + source.height / 2;
  let sameRow: { distance: number; index: number } | null = null;
  let below: { distance: number; index: number } | null = null;

  parsed.forEach((candidate, candidateIndex) => {
    if (candidateIndex === index || !candidate.meaningOnly || used.has(candidateIndex)) {
      return;
    }
    const line = candidate.line;
    const center = line.y + line.height / 2;
    const rowTolerance = Math.max(source.height, line.height) * 0.6;
    if (Math.abs(center - sourceCenter) <= rowTolerance && line.x > source.x) {
      const distance = line.x - (source.x + source.width);
      if (!sameRow || distance < sameRow.distance) {
        sameRow = { distance, index: candidateIndex };
      }
      return;
    }
    const gap = line.y - (source.y + source.height);
    const lineHeight = Math.max(source.height, 0.005);
    if (gap >= -lineHeight * 0.3 && gap <= lineHeight * 1.6 && Math.abs(line.x - source.x) <= 0.15) {
      if (!below || gap < below.distance) {
        below = { distance: gap, index: candidateIndex };
      }
    }
  });

  const match = (sameRow ?? below) as { index: number } | null;
  if (!match) {
    return null;
  }
  // The headword has to be the closest unclaimed word to that meaning;
  // otherwise a word further up would steal the meaning of the word under it.
  const claimant = closestPendingWord(parsed, match.index, used);
  return claimant === index ? match.index : null;
}

function closestPendingWord(parsed: ParsedLine[], meaningIndex: number, used: Set<number>): number | null {
  const meaning = parsed[meaningIndex].line;
  const meaningCenter = meaning.y + meaning.height / 2;
  let best: { index: number; score: number } | null = null;
  parsed.forEach((candidate, candidateIndex) => {
    if (!candidate.pendingWord || used.has(candidateIndex)) {
      return;
    }
    const line = candidate.line;
    const center = line.y + line.height / 2;
    const rowTolerance = Math.max(meaning.height, line.height) * 0.6;
    const sameRow = Math.abs(center - meaningCenter) <= rowTolerance && meaning.x > line.x;
    const gap = meaning.y - (line.y + line.height);
    const above = gap >= -line.height * 0.3 && gap <= Math.max(line.height, 0.005) * 1.6 && Math.abs(meaning.x - line.x) <= 0.15;
    if (!sameRow && !above) {
      return;
    }
    const score = sameRow ? meaning.x - (line.x + line.width) : 10 + gap;
    if (!best || score < best.score) {
      best = { index: candidateIndex, score };
    }
  });
  return (best as { index: number } | null)?.index ?? null;
}

function parseLine(line: ScannedLine): ParsedLine {
  const text = stripLeadingNumbering(line.text);
  const segments = splitSegments(text);
  const pairs: ParsedLine['pairs'] = [];
  let pendingWord: ParsedLine['pendingWord'] = null;

  for (let index = 0; index < segments.length; index += 1) {
    const segment = segments[index];
    if (segment.kind !== 'latin') {
      continue;
    }
    const headword = parseHeadword(segment.text);
    if (!headword) {
      continue;
    }
    const next = segments[index + 1];
    if (next?.kind === 'cjk') {
      pairs.push({ ...headword, meaningZh: cleanMeaning(next.text) });
      index += 1;
    } else if (segments.length === 1) {
      pendingWord = headword;
    }
  }

  const meaningOnly = segments.length === 1 && segments[0].kind === 'cjk' ? cleanMeaning(segments[0].text) : null;
  return { line, meaningOnly: meaningOnly || null, pairs, pendingWord };
}

/**
 * Splits a line wherever it switches between Latin letters and Chinese
 * characters. Spaces, digits and punctuation stay with the run they follow,
 * so "v." stays with its word and "；" with its meaning.
 */
function splitSegments(text: string): Segment[] {
  const segments: Segment[] = [];
  for (const char of text) {
    const kind = CJK.test(char) ? 'cjk' : LATIN.test(char) ? 'latin' : null;
    const last = segments[segments.length - 1];
    if (!kind) {
      if (last) {
        last.text += char;
      }
      continue;
    }
    if (last && last.kind === kind) {
      last.text += char;
    } else if (last && kind === 'latin' && last.kind === 'cjk' && /[（(]\s*$/.test(last.text)) {
      // Latin inside a Chinese bracket, like 解釋（sth），belongs to the meaning.
      last.text += char;
    } else {
      segments.push({ kind, text: char });
    }
  }
  return segments.filter((segment) => segment.text.trim().length > 0);
}

function parseHeadword(text: string): { partOfSpeech: string; word: string } | null {
  const rawTokens = text.replace(/[()[\]{}]/g, ' ').split(/\s+/).filter(Boolean);
  const tokens = rawTokens
    .map((token) => token.replace(/^[^A-Za-z]+|[^A-Za-z'’./-]+$/g, ''))
    .filter(Boolean);
  if (tokens.length === 0) {
    return null;
  }

  const posTokens: string[] = [];
  while (tokens.length > 1 && isPosToken(tokens[tokens.length - 1])) {
    posTokens.unshift(...tokens.pop()!.toLowerCase().split(/[/.,&]+/).filter(Boolean));
    rawTokens.pop();
  }
  // "color/colour" is one headword with two spellings; keep the first.
  const words = tokens.map((token) => token.split('/')[0]).filter(Boolean);
  const cleaned = words.map((token) => token.replace(/\.$/, ''));
  // Example sentences sit on the same sheets. A capitalised run of three or
  // more words, or anything ending like a sentence, is not a headword.
  const lastRaw = rawTokens[rawTokens.length - 1] ?? '';
  const looksLikeSentence =
    (cleaned.length >= 2 && /[.?!]["”’']?$/.test(lastRaw)) ||
    (cleaned.length >= 3 && /^[A-Z]/.test(cleaned[0]));
  if (
    looksLikeSentence ||
    cleaned.length === 0 ||
    cleaned.length > MAX_HEADWORD_TOKENS ||
    !cleaned.every((token) => /^[A-Za-z][A-Za-z'’-]*$/.test(token)) ||
    !cleaned.some((token) => token.length >= 2)
  ) {
    return null;
  }
  return { partOfSpeech: posTokens.join(' / '), word: cleaned.join(' ') };
}

function isPosToken(token: string): boolean {
  return token
    .replace(/\.$/, '')
    .split(/[/.,&]+/)
    .filter(Boolean)
    .every((part) => POS_TOKENS.has(part.toLowerCase()));
}

function stripLeadingNumbering(text: string): string {
  return text.replace(/^\s*(?:[(（]?\d{1,3}[)）.、:]?|[①-⑳]|[•·・\-*])\s*/, '');
}

function cleanMeaning(text: string): string {
  return text
    .replace(/^[\s:=\-–—,，.。、]+/, '')
    .replace(/[\s,，.、:=\-–—]+$/, '')
    .replace(/\s+/g, ' ')
    .trim();
}

function normaliseText(text: string): string {
  return text
    // Full-width Latin letters, digits and ASCII punctuation to half-width.
    .replace(/[！-～]/g, (char) => {
      const half = String.fromCharCode(char.charCodeAt(0) - 0xfee0);
      // Keep Chinese-style separators that read better in a meaning.
      return /[；，：（）]/.test(char) ? char : half;
    })
    .replace(/　/g, ' ')
    .trim();
}

/**
 * Pasted text (for example copied with Live Text from the Photos app) has no
 * positions, only line order. Each line is laid out as its own row, so a word
 * with its meaning on the line below still pairs up.
 */
export function linesFromPlainText(text: string): ScannedLine[] {
  return text
    .split(/\r?\n/)
    .map((value) => value.trim())
    .filter(Boolean)
    .map((value, index) => ({ height: 0.03, text: value, width: 0.9, x: 0.05, y: 0.02 + index * 0.035 }));
}
