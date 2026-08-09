import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const projectRoot = path.resolve(__dirname, '..');
const inputArg = process.argv[2];

if (!inputArg) {
  throw new Error('Usage: node scripts/apply-example-corrections.mjs <corrections.json>');
}

const inputPath = path.resolve(projectRoot, inputArg);
const corrections = JSON.parse(fs.readFileSync(inputPath, 'utf8'));
const englishTokenCount = (value) => value.match(/[A-Za-z]+(?:['’-][A-Za-z]+)*/g)?.length ?? 0;
const chineseCharacterCount = (value) => value.match(/\p{Script=Han}/gu)?.length ?? 0;
const escapeRegex = (value) => value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

if (!Array.isArray(corrections) || corrections.length === 0) {
  throw new Error('Corrections must be a non-empty array.');
}

const files = new Map();
const seen = new Set();

for (const correction of corrections) {
  const core = Number(correction.core);
  const word = correction.word?.trim().toLowerCase();
  const exampleZh = correction.exampleZh?.trim();
  const key = `${core}:${word}`;

  if (!Number.isInteger(core) || core < 1 || core > 14 || !word || !exampleZh) {
    throw new Error(`Invalid correction: ${JSON.stringify(correction)}`);
  }
  if (seen.has(key)) {
    throw new Error(`Duplicate correction: ${key}`);
  }
  seen.add(key);

  const filePath = path.join(projectRoot, 'src', 'data', `reviewed-examples-core${core}.json`);
  const rows = files.get(filePath) ?? JSON.parse(fs.readFileSync(filePath, 'utf8'));
  const row = rows.find((item) => item.word.trim().toLowerCase() === word);
  if (!row) {
    throw new Error(`Unknown reviewed word: ${key}`);
  }

  const example = correction.example?.trim() || row.example.trim();
  const englishLength = englishTokenCount(example);
  const chineseLength = chineseCharacterCount(exampleZh);
  const targetPattern = new RegExp(`(^|[^a-z])${escapeRegex(word)}([^a-z]|$)`, 'i');
  if (englishLength < 8 || englishLength > 22) {
    throw new Error(`${key} English length is ${englishLength}; expected 8-22.`);
  }
  if (chineseLength < 8 || chineseLength > 42) {
    throw new Error(`${key} Chinese length is ${chineseLength}; expected 8-42.`);
  }
  if (!targetPattern.test(example)) {
    throw new Error(`${key} does not contain the exact headword.`);
  }
  if (!/[.!?]$/.test(example) || !/[。！？]$/.test(exampleZh)) {
    throw new Error(`${key} is missing terminal punctuation.`);
  }

  row.example = example;
  row.exampleZh = exampleZh;
  files.set(filePath, rows);
}

for (const [filePath, rows] of files) {
  if (rows.length !== 500) {
    throw new Error(`${filePath} must retain exactly 500 rows.`);
  }
  fs.writeFileSync(filePath, `${JSON.stringify(rows, null, 2)}\n`, 'utf8');
}

console.log(`Applied ${corrections.length} validated corrections across ${files.size} Core files.`);
