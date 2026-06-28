import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { parse } from 'csv-parse/sync';
import OpenCC from 'opencc-js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const projectRoot = path.resolve(__dirname, '..');
const sourcePath = path.join(projectRoot, '.codex-run', 'ecdict.csv');
const outputPath = path.join(projectRoot, 'src', 'data', 'words.ts');
const TARGET_COUNT = 7000;
const convertToTraditional = OpenCC.Converter({ from: 'cn', to: 'tw' });

const seedOverrides = new Map(
  [
    [
      'adapt',
      {
        meaningZh: '適應；調整；改編',
        example: 'Students adapt quickly to a clear routine.',
        exampleZh: '學生很快適應清楚的規律。',
      },
    ],
    [
      'brief',
      {
        meaningZh: '簡短的；摘要；簡報',
        example: 'The teacher gave a brief explanation.',
        exampleZh: '老師做了簡短的說明。',
      },
    ],
    [
      'contrast',
      {
        meaningZh: '對比；差異；形成對照',
        example: 'The chart shows a contrast between the two plans.',
        exampleZh: '圖表顯示兩個計畫之間的對比。',
      },
    ],
    [
      'expand',
      {
        meaningZh: '擴大；展開；詳述',
        example: 'The company plans to expand next year.',
        exampleZh: '公司計畫明年擴大規模。',
      },
    ],
    [
      'precise',
      {
        meaningZh: '精確的；明確的',
        example: 'A precise answer saves time.',
        exampleZh: '精確的回答能節省時間。',
      },
    ],
  ],
);

function cleanText(value = '') {
  return convertToTraditional(value)
    .replace(/\\n/g, '\n')
    .replace(/\r/g, '\n')
    .replace(/[ \t]+/g, ' ')
    .replace(/\n{2,}/g, '\n')
    .trim();
}

function cleanMeaning(value = '') {
  const seenLines = new Set();
  const lines = cleanText(value)
    .split('\n')
    .filter((line) => !/^\[[^\]]+\]/.test(line.trim()))
    .map((line) =>
      line
        .replace(/^\[[^\]]+\]\s*/g, '')
        .replace(/^[a-z]+\.\s*/i, '')
        .replace(/\s+/g, ' ')
        .trim(),
    )
    .filter(Boolean)
    .filter((line) => !line.startsWith('網絡') && !line.startsWith('網路'))
    .filter((line) => {
      if (seenLines.has(line)) {
        return false;
      }
      seenLines.add(line);
      return true;
    });

  const joined = lines.join('；');
  return joined
    .replace(/[;；]{2,}/g, '；')
    .replace(/，/g, '，')
    .replace(/\s*；\s*/g, '；')
    .slice(0, 120)
    .replace(/[，,;；\s]+$/g, '');
}

function partOfSpeech(row) {
  if (row.pos?.trim()) {
    return row.pos.trim();
  }

  const translation = row.translation ?? '';
  const matches = Array.from(translation.matchAll(/(?:^|\\n|\n)([a-z]+)\./gi)).map((match) => match[1].toLowerCase());
  const unique = Array.from(new Set(matches)).slice(0, 3);
  return unique.length > 0 ? unique.join(' / ') : 'word';
}

function score(row) {
  const collins = Number(row.collins || 0);
  const oxford = Number(row.oxford || 0);
  const bnc = Number(row.bnc || 0);
  const frq = Number(row.frq || 0);
  const tagBonus = row.tag ? 5000 : 0;
  const frequencyScore = (bnc > 0 ? 700000 / bnc : 0) + (frq > 0 ? 900000 / frq : 0);
  return collins * 100000 + oxford * 80000 + tagBonus + frequencyScore;
}

function isUsableWord(row) {
  const word = row.word?.trim().toLowerCase() ?? '';
  const meaning = cleanMeaning(row.translation);

  return (
    /^[a-z]{2,18}$/.test(word) &&
    meaning.length >= 2 &&
    !meaning.includes('=') &&
    !meaning.includes('見 ') &&
    !meaning.includes('參見') &&
    !meaning.includes('同義詞')
  );
}

function toEntry(row, index) {
  const word = row.word.trim().toLowerCase();
  const override = seedOverrides.get(word);
  const meaningZh = override?.meaningZh ?? cleanMeaning(row.translation);
  const pronunciation = row.phonetic?.trim() ? `/${row.phonetic.trim()}/` : '/-/';
  const group = `Core ${Math.floor(index / 500) + 1}`;

  return {
    id: `w${String(index + 1).padStart(4, '0')}`,
    word,
    partOfSpeech: partOfSpeech(row),
    pronunciation,
    meaningZh,
    example: override?.example ?? `Review "${word}" with this meaning: ${meaningZh}.`,
    exampleZh: override?.exampleZh ?? `「${word}」：${meaningZh}`,
    group,
  };
}

if (!fs.existsSync(sourcePath)) {
  throw new Error(`Missing source CSV: ${sourcePath}`);
}

const csv = fs.readFileSync(sourcePath, 'utf8');
const rows = parse(csv, {
  columns: true,
  bom: true,
  relax_quotes: true,
  skip_empty_lines: true,
});

const usable = rows
  .filter(isUsableWord)
  .sort((a, b) => score(b) - score(a) || a.word.localeCompare(b.word));

const selectedRows = [];
const seen = new Set();

for (const seed of seedOverrides.keys()) {
  const row = usable.find((candidate) => candidate.word?.trim().toLowerCase() === seed);
  if (!row) {
    throw new Error(`Seed word missing from source: ${seed}`);
  }
  selectedRows.push(row);
  seen.add(seed);
}

for (const row of usable) {
  const word = row.word.trim().toLowerCase();
  if (seen.has(word)) {
    continue;
  }
  selectedRows.push(row);
  seen.add(word);
  if (selectedRows.length === TARGET_COUNT) {
    break;
  }
}

if (selectedRows.length !== TARGET_COUNT) {
  throw new Error(`Expected ${TARGET_COUNT} words, got ${selectedRows.length}`);
}

const entries = selectedRows.map(toEntry);
const output = `export type WordEntry = {
  id: string;
  word: string;
  partOfSpeech: string;
  pronunciation: string;
  meaningZh: string;
  example: string;
  exampleZh: string;
  group: string;
};

export const sampleWords: WordEntry[] = ${JSON.stringify(entries, null, 2)};
`;

fs.writeFileSync(outputPath, output, 'utf8');
console.log(`Generated ${entries.length} words at ${outputPath}`);
