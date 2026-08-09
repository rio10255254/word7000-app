import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const projectRoot = path.resolve(__dirname, '..');
const dataDir = path.join(projectRoot, 'src', 'data');
const wordsPath = path.join(dataDir, 'words.ts');
const source = fs.readFileSync(wordsPath, 'utf8');
const match = source.match(/export const sampleWords: WordEntry\[\] = ([\s\S]+);\s*$/);

if (!match) {
  throw new Error(`Could not read sampleWords from ${wordsPath}`);
}

const words = JSON.parse(match[1]);
const requestedPaths = process.argv.slice(2).map((input) => path.resolve(projectRoot, input));
const reviewPaths = requestedPaths.length > 0
  ? requestedPaths
  : fs
      .readdirSync(dataDir)
      .filter((filename) => /^reviewed-meanings-core(?:[1-9]|1[0-4])\.json$/.test(filename))
      .sort((a, b) => Number(a.match(/\d+/)?.[0]) - Number(b.match(/\d+/)?.[0]))
      .map((filename) => path.join(dataDir, filename));

if (reviewPaths.length === 0) {
  throw new Error('No reviewed meaning files were found.');
}

const separators = /[；;，,、]/;
const parts = (value = '') => value.split(separators).map((part) => part.trim()).filter(Boolean);
const normalize = (value) => value.replace(/[\s（）()「」『』]/g, '').toLowerCase();
const seenWords = new Set();
let total = 0;

for (const reviewPath of reviewPaths) {
  const filename = path.basename(reviewPath);
  const coreMatch = filename.match(/^reviewed-meanings-core(\d+)\.json$/);
  if (!coreMatch) {
    throw new Error(`Unexpected reviewed meaning filename: ${filename}`);
  }

  const core = Number(coreMatch[1]);
  const expectedWords = words.filter((word) => word.group === `Core ${core}`);
  const rows = JSON.parse(fs.readFileSync(reviewPath, 'utf8'));

  if (!Array.isArray(rows) || rows.length !== 500) {
    throw new Error(`${filename} must contain exactly 500 rows.`);
  }

  rows.forEach((row, index) => {
    const expected = expectedWords[index];
    const primary = row.primaryMeaningZh?.trim() ?? '';
    const supplemental = row.supplementalMeaningZh?.trim() ?? '';
    const primaryParts = parts(primary);
    const supplementalParts = parts(supplemental);
    const allParts = [...primaryParts, ...supplementalParts].map(normalize);

    if (row.word !== expected?.word) {
      throw new Error(`${filename} row ${index + 1} must be ${expected?.word}; found ${row.word}.`);
    }
    if (seenWords.has(row.word)) {
      throw new Error(`Duplicate reviewed word: ${row.word}`);
    }
    seenWords.add(row.word);
    if (!primary || primaryParts.length !== 1) {
      throw new Error(`${filename} ${row.word} must have exactly 1 primary meaning.`);
    }
    if (supplementalParts.length > 3) {
      throw new Error(`${filename} ${row.word} must have no more than 3 supplemental meanings.`);
    }
    if (primary.length > 28 || supplemental.length > 48) {
      throw new Error(`${filename} ${row.word} has an overlong meaning.`);
    }
    if (/[，,、;]/.test(`${primary}${supplemental}`)) {
      throw new Error(`${filename} ${row.word} must use full-width semicolons between meanings.`);
    }
    if (new Set(allParts).size !== allParts.length) {
      throw new Error(`${filename} ${row.word} repeats a meaning.`);
    }
    if (row.status !== 'approved' || !row.batch?.trim()) {
      throw new Error(`${filename} ${row.word} must be approved and include a batch label.`);
    }
  });

  total += rows.length;
}

console.log(`Validated ${total} reviewed meanings across ${reviewPaths.length} files.`);
