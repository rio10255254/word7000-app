import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const projectRoot = path.resolve(__dirname, '..');
const wordsPath = path.join(projectRoot, 'src', 'data', 'words.ts');
const dataDir = path.join(projectRoot, 'src', 'data');
const outputDir = path.join(projectRoot, 'exports', 'example-review', 'core4-14-2026-07-02');
const chunksDir = path.join(outputDir, 'chunks');
const coreDir = path.join(outputDir, 'by-core');
const targetLevels = Array.from({ length: 11 }, (_, index) => index + 4);
const chunkSize = 250;

function readWords() {
  const source = fs.readFileSync(wordsPath, 'utf8');
  const match = source.match(/export const sampleWords: WordEntry\[] = ([\s\S]*?);\n$/);
  if (!match) {
    throw new Error(`Unable to parse sampleWords from ${wordsPath}`);
  }
  return JSON.parse(match[1]);
}

function readApprovedWords() {
  const reviewFiles = fs
    .readdirSync(dataDir)
    .filter((filename) => /^reviewed-examples.*\.json$/.test(filename))
    .map((filename) => path.join(dataDir, filename));

  return new Set(
    reviewFiles.flatMap((reviewPath) =>
      JSON.parse(fs.readFileSync(reviewPath, 'utf8'))
        .filter((row) => row.status === 'approved')
        .map((row) => row.word),
    ),
  );
}

function reviewItem(word) {
  return {
    id: word.id,
    group: word.group,
    word: word.word,
    partOfSpeech: word.partOfSpeech,
    meaningZh: word.meaningZh,
    currentExample: word.example,
    currentExampleZh: word.exampleZh,
  };
}

function markdownBatch(title, batchId, items) {
  return `# ${title}

Use the rules in ../PROMPT.md.

Return JSON only. Do not explain.

Batch id: \`${batchId}\`

\`\`\`json
${JSON.stringify({ batch: batchId, items }, null, 2)}
\`\`\`
`;
}

const prompt = `# Word7000 Example Generation Prompt

You are helping polish a vocabulary app.

Input is a JSON object with:
- batch: a batch id
- items: vocabulary items

Return JSON only, with the same number of rows and the same order:

[
  {
    "word": "example",
    "example": "A natural English sentence.",
    "exampleZh": "自然的繁體中文翻譯。",
    "status": "approved",
    "batch": "same batch id from input"
  }
]

Rules:
1. The English example must contain the exact word exactly as given, as a standalone word. Do not use only a variant. If the word is "decide", the example must include "decide", not only "decided".
2. Use one natural sentence. Keep it short, usually 4 to 12 words.
3. Use the main everyday meaning from meaningZh. If there are many meanings, choose the most useful one for learners.
4. The Chinese translation must be Traditional Chinese, natural for Taiwan users, and must translate the whole sentence, not just the word.
5. Do not write meta sentences like "The word means..." or "This is an example of...".
6. Do not use awkward templates like "a report about..." unless it is genuinely natural.
7. Avoid repeated sentence frames. Make the batch feel human-written.
8. For sensitive words, use neutral, non-graphic, learner-safe examples.
9. Keep punctuation simple. No Markdown. No comments.
10. If a word is a weekday, month, number, pronoun, preposition, or function word, make a natural everyday sentence using that exact word.

Before returning, check:
- every input word appears exactly once in output
- every English example contains the exact word
- every row has word, example, exampleZh, status, batch
- output is valid JSON
`;

const words = readWords();
const approvedWords = readApprovedWords();
const missing = words.filter((word) => targetLevels.includes(Number(word.group.replace('Core ', ''))) && !approvedWords.has(word.word));
const items = missing.map(reviewItem);
const byCore = new Map();

for (const item of items) {
  const rows = byCore.get(item.group) ?? [];
  rows.push(item);
  byCore.set(item.group, rows);
}

fs.mkdirSync(chunksDir, { recursive: true });
fs.mkdirSync(coreDir, { recursive: true });

fs.writeFileSync(path.join(outputDir, 'PROMPT.md'), prompt, 'utf8');
fs.writeFileSync(path.join(outputDir, 'all-missing-core4-14.json'), JSON.stringify({ generatedAt: '2026-07-02', total: items.length, items }, null, 2), 'utf8');

const manifest = {
  generatedAt: '2026-07-02',
  levels: targetLevels.map((level) => `Core ${level}`),
  totalMissing: items.length,
  chunkSize,
  byCore: {},
  chunks: [],
};

for (const [group, rows] of Array.from(byCore.entries()).sort((a, b) => Number(a[0].replace('Core ', '')) - Number(b[0].replace('Core ', '')))) {
  const level = Number(group.replace('Core ', ''));
  const coreId = `core${String(level).padStart(2, '0')}`;
  const batchId = `gpt-review-${coreId}-full-2026-07-02`;
  const jsonName = `${coreId}-full.json`;
  const markdownName = `${coreId}-full.md`;

  fs.writeFileSync(path.join(coreDir, jsonName), JSON.stringify({ batch: batchId, items: rows }, null, 2), 'utf8');
  fs.writeFileSync(path.join(coreDir, markdownName), markdownBatch(`Word7000 ${group} Full Batch`, batchId, rows), 'utf8');

  manifest.byCore[group] = {
    total: rows.length,
    json: `by-core/${jsonName}`,
    markdown: `by-core/${markdownName}`,
  };

  for (let start = 0; start < rows.length; start += chunkSize) {
    const chunkRows = rows.slice(start, start + chunkSize);
    const part = Math.floor(start / chunkSize) + 1;
    const chunkId = `${coreId}-part${String(part).padStart(2, '0')}`;
    const chunkBatchId = `gpt-review-${chunkId}-2026-07-02`;
    const chunkJson = `${chunkId}.json`;
    const chunkMd = `${chunkId}.md`;

    fs.writeFileSync(path.join(chunksDir, chunkJson), JSON.stringify({ batch: chunkBatchId, items: chunkRows }, null, 2), 'utf8');
    fs.writeFileSync(path.join(chunksDir, chunkMd), markdownBatch(`Word7000 ${group} Part ${part}`, chunkBatchId, chunkRows), 'utf8');

    manifest.chunks.push({
      group,
      part,
      total: chunkRows.length,
      json: `chunks/${chunkJson}`,
      markdown: `chunks/${chunkMd}`,
    });
  }
}

const readme = `# Word7000 GPT Example Review Export

This folder contains the words that still need reviewed examples from Core 4 through Core 14.

Recommended workflow:

1. Open \`PROMPT.md\`.
2. Upload or paste one Markdown batch from \`chunks/\` into GPT.
3. Ask GPT to return JSON only.
4. Save the returned JSON and send it back for import and validation.

You can also use the larger files in \`by-core/\` if your GPT session can handle about 500 rows at once.

Counts:

${Object.entries(manifest.byCore)
  .map(([group, info]) => `- ${group}: ${info.total} words`)
  .join('\n')}

Total missing words exported: ${items.length}
`;

fs.writeFileSync(path.join(outputDir, 'README.md'), readme, 'utf8');
fs.writeFileSync(path.join(outputDir, 'manifest.json'), JSON.stringify(manifest, null, 2), 'utf8');

console.log(`Exported ${items.length} words to ${outputDir}`);
