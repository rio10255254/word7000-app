import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const projectRoot = path.resolve(__dirname, '..');
const dataDir = path.join(projectRoot, 'src', 'data');
const wordsPath = path.join(dataDir, 'words.ts');
const source = fs.readFileSync(wordsPath, 'utf8');
const wordsMatch = source.match(/export const sampleWords: WordEntry\[\] = ([\s\S]+);\s*$/);

if (!wordsMatch) {
  throw new Error(`Could not read sampleWords from ${wordsPath}`);
}

const words = JSON.parse(wordsMatch[1]);
const groupByWord = new Map(words.map((entry) => [entry.word, entry.group]));
const reviewedFiles = fs
  .readdirSync(dataDir)
  .filter((filename) => /^reviewed-examples.*\.json$/.test(filename))
  .sort();
const reviewedByWord = new Map();

for (const filename of reviewedFiles) {
  const rows = JSON.parse(fs.readFileSync(path.join(dataDir, filename), 'utf8'));
  if (!Array.isArray(rows)) {
    throw new Error(`Reviewed examples must be an array: ${filename}`);
  }

  for (const row of rows) {
    if (!groupByWord.has(row.word)) {
      throw new Error(`Unknown reviewed word in ${filename}: ${row.word}`);
    }
    if (reviewedByWord.has(row.word)) {
      throw new Error(`Duplicate reviewed word: ${row.word}`);
    }
    reviewedByWord.set(row.word, row);
  }
}

if (reviewedByWord.size !== words.length) {
  const missing = words.filter((entry) => !reviewedByWord.has(entry.word)).map((entry) => entry.word);
  throw new Error(`Expected ${words.length} reviewed words, found ${reviewedByWord.size}. Missing: ${missing.slice(0, 20).join(', ')}`);
}

for (let level = 1; level <= 14; level += 1) {
  const group = `Core ${level}`;
  const rows = words
    .filter((entry) => entry.group === group)
    .map((entry) => reviewedByWord.get(entry.word));

  if (rows.length !== 500) {
    throw new Error(`${group} must contain 500 reviewed rows, found ${rows.length}`);
  }

  fs.writeFileSync(
    path.join(dataDir, `reviewed-examples-core${level}.json`),
    `${JSON.stringify(rows, null, 2)}\n`,
    'utf8',
  );
}

for (const filename of reviewedFiles) {
  if (!/^reviewed-examples-core(?:[1-9]|1[0-4])\.json$/.test(filename)) {
    fs.unlinkSync(path.join(dataDir, filename));
  }
}

console.log('Consolidated 7000 reviewed examples into 14 canonical Core files.');
