import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const projectRoot = path.resolve(__dirname, '..');
const inputArg = process.argv[2];

if (!inputArg) {
  throw new Error('Usage: node scripts/apply-meaning-corrections.mjs <corrections.json>');
}

const corrections = JSON.parse(fs.readFileSync(path.resolve(projectRoot, inputArg), 'utf8'));
const parts = (value = '') => value.split(/[；;，,、]/).map((part) => part.trim()).filter(Boolean);
const files = new Map();
const seen = new Set();

if (!Array.isArray(corrections) || corrections.length === 0) {
  throw new Error('Corrections must be a non-empty array.');
}

for (const correction of corrections) {
  const core = Number(correction.core);
  const word = correction.word?.trim().toLowerCase();
  const primary = correction.primaryMeaningZh?.trim();
  const supplemental = correction.supplementalMeaningZh?.trim() ?? '';
  const key = `${core}:${word}`;

  if (!Number.isInteger(core) || core < 1 || core > 14 || !word || !primary) {
    throw new Error(`Invalid correction: ${JSON.stringify(correction)}`);
  }
  if (seen.has(key)) {
    throw new Error(`Duplicate correction: ${key}`);
  }
  seen.add(key);
  if (parts(primary).length !== 1 || parts(supplemental).length > 3) {
    throw new Error(`${key} has too many meanings.`);
  }
  if (primary.length > 28 || supplemental.length > 48 || /[，,、;]/.test(`${primary}${supplemental}`)) {
    throw new Error(`${key} does not meet the reviewed meaning format.`);
  }

  const filePath = path.join(projectRoot, 'src', 'data', `reviewed-meanings-core${core}.json`);
  const rows = files.get(filePath) ?? JSON.parse(fs.readFileSync(filePath, 'utf8'));
  const row = rows.find((item) => item.word === word);
  if (!row) {
    throw new Error(`Unknown reviewed word: ${key}`);
  }

  row.primaryMeaningZh = primary;
  row.supplementalMeaningZh = supplemental;
  files.set(filePath, rows);
}

for (const [filePath, rows] of files) {
  fs.writeFileSync(filePath, `${JSON.stringify(rows, null, 2)}\n`, 'utf8');
}

console.log(`Applied ${corrections.length} meaning corrections across ${files.size} Core files.`);
