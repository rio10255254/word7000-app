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

function meaningHead(value = '') {
  const head = cleanText(value)
    .split(/[；;,，、]/)[0]
    ?.replace(/^[的地得\s]+/g, '')
    .replace(/[^\u4e00-\u9fffA-Za-z\s-]/g, '')
    .trim();
  return head || '這個概念';
}

function wordKind(pos, word) {
  const value = pos.toLowerCase();
  if (value.includes('prep') || value.includes('conj') || value.includes('pron') || value.includes('aux')) {
    return 'function';
  }
  if (value.includes('adv') || value.split('/').map((item) => item.trim()).includes('r')) {
    return word.endsWith('ly') ? 'adverb' : 'function';
  }
  if (value.includes('v')) {
    return 'verb';
  }
  if (value.includes('a') || value.includes('adj')) {
    return 'adjective';
  }
  if (value.includes('n')) {
    return 'noun';
  }
  return 'function';
}

function generatedExample(row, word, partOfSpeechValue, meaningZh, index) {
  const kind = wordKind(partOfSpeechValue, word);
  const zhHead = meaningHead(meaningZh);
  const variant = index % 4;

  if (kind === 'noun') {
    const examples = [
      [`The word "${word}" appears as the main idea in a short passage.`, `「${word}」在短文中作為主要概念出現。`],
      [`A learner can connect "${word}" with a real situation.`, `學習者可以把「${word}」和真實情境連起來。`],
      [`This example places "${word}" in a practical context.`, `這個例句把「${word}」放進實用情境。`],
      [`The sentence helps explain "${word}" without a long definition.`, `這句話不用長篇解釋，也能幫助理解「${word}」。`],
    ];
    return examples[variant];
  }

  if (kind === 'verb') {
    const examples = [
      [`The word "${word}" can describe an action or state in context.`, `「${word}」可以在情境中表達動作或狀態。`],
      [`A simple sentence can show how "${word}" is used.`, `簡單句子可以示範「${word}」的用法。`],
      [`This passage uses "${word}" to make the meaning clearer.`, `這段文字用「${word}」讓意思更清楚。`],
      [`Learners can practice "${word}" in a complete sentence.`, `學習者可以在完整句子中練習「${word}」。`],
    ];
    return examples[variant];
  }

  if (kind === 'adjective') {
    const examples = [
      [`The word "${word}" adds a clear detail to the sentence.`, `「${word}」為句子增加清楚的細節。`],
      [`A short example can make "${word}" easier to remember.`, `短例句能讓「${word}」更容易記住。`],
      [`This sentence shows "${word}" in a useful context.`, `這句話示範「${word}」在實用情境中的樣子。`],
      [`The lesson connects "${word}" with a familiar idea.`, `這課把「${word}」和熟悉的想法連起來。`],
    ];
    return examples[variant];
  }

  if (kind === 'adverb') {
    const examples = [
      [`The word "${word}" changes how the action feels.`, `「${word}」會改變動作呈現的感覺。`],
      [`This example shows "${word}" beside an action.`, `這個例句示範「${word}」如何搭配動作。`],
      [`A clear context helps learners remember "${word}".`, `清楚的情境能幫助學習者記住「${word}」。`],
      [`The sentence uses "${word}" to adjust the meaning.`, `這句話用「${word}」調整意思。`],
    ];
    return examples[variant];
  }

  const examples = [
    [`Writers use "${word}" to connect ideas in a sentence.`, `寫作者用「${word}」連接句子裡的想法。`],
    [`In this sentence, "${word}" helps the meaning stay clear.`, `在這個句子裡，「${word}」讓意思更清楚。`],
    [`A simple example shows where "${word}" can fit.`, `簡單例句會示範「${word}」可以放在哪裡。`],
    [`The word "${word}" is useful when the sentence connects two ideas.`, `談到${zhHead}時，可以用「${word}」。`],
  ];
  return examples[variant];
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
  const partOfSpeechValue = partOfSpeech(row);
  const [example, exampleZh] = override
    ? [override.example, override.exampleZh]
    : generatedExample(row, word, partOfSpeechValue, meaningZh, index);

  return {
    id: `w${String(index + 1).padStart(4, '0')}`,
    word,
    partOfSpeech: partOfSpeechValue,
    pronunciation,
    meaningZh,
    example,
    exampleZh,
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
