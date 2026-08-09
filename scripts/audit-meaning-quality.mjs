import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const projectRoot = path.resolve(__dirname, '..');
const wordsPath = path.join(projectRoot, 'src', 'data', 'words.ts');
const reportPath = path.join(projectRoot, '.codex-run', 'meaning-quality-audit.json');
const source = fs.readFileSync(wordsPath, 'utf8');
const match = source.match(/export const sampleWords: WordEntry\[\] = ([\s\S]+);\s*$/);

if (!match) {
  throw new Error(`Could not read sampleWords from ${wordsPath}`);
}

const words = JSON.parse(match[1]);
const issues = [];
const separators = /[；;，,、]/;
const forbiddenNoise = /(網絡|電腦術語|在線|諸如此類|參見|同義詞)/u;

function parts(value = '') {
  return value
    .split(separators)
    .map((part) => part.trim())
    .filter(Boolean);
}

function normalized(value) {
  return value.replace(/[\s（）()「」『』]/g, '').toLowerCase();
}

function addIssue(word, label, details = '') {
  issues.push({
    id: word.id,
    word: word.word,
    group: word.group,
    label,
    details,
    meaningZh: word.meaningZh,
    supplementalMeaningZh: word.supplementalMeaningZh,
    example: word.example,
    exampleZh: word.exampleZh,
  });
}

for (const word of words) {
  const primary = word.meaningZh?.trim() ?? '';
  const supplemental = word.supplementalMeaningZh?.trim() ?? '';
  const primaryParts = parts(primary);
  const supplementalParts = parts(supplemental);
  const allParts = [...primaryParts, ...supplementalParts];
  const normalizedParts = allParts.map(normalized);

  if (!primary) {
    addIssue(word, 'missing-primary-meaning');
  }
  if (primaryParts.length !== 1) {
    addIssue(word, 'too-many-primary-meanings', `${primaryParts.length} meanings`);
  }
  if (supplementalParts.length > 3) {
    addIssue(word, 'too-many-supplemental-meanings', `${supplementalParts.length} meanings`);
  }
  if (primary.length > 28) {
    addIssue(word, 'primary-meaning-too-long', `${primary.length} characters`);
  }
  if (supplemental.length > 48) {
    addIssue(word, 'supplemental-meaning-too-long', `${supplemental.length} characters`);
  }
  if (/[，,、;]/.test(`${primary}${supplemental}`)) {
    addIssue(word, 'nonstandard-meaning-separator');
  }
  if (forbiddenNoise.test(`${primary} ${supplemental}`)) {
    addIssue(word, 'dictionary-noise');
  }
  if (new Set(normalizedParts).size !== normalizedParts.length) {
    addIssue(word, 'duplicate-meaning');
  }
}

const reviewedFiles = fs
  .readdirSync(path.join(projectRoot, 'src', 'data'))
  .filter((filename) => /^reviewed-meanings-core(?:[1-9]|1[0-4])\.json$/.test(filename));

if (reviewedFiles.length !== 14) {
  issues.push({ label: 'reviewed-file-count', details: `${reviewedFiles.length} files; expected 14` });
}

const uniqueIssues = Array.from(new Map(issues.map((issue) => [`${issue.id ?? 'dataset'}:${issue.label}`, issue])).values());
const byLabel = uniqueIssues.reduce((counts, issue) => {
  counts[issue.label] = (counts[issue.label] ?? 0) + 1;
  return counts;
}, {});
const byCore = uniqueIssues.reduce((counts, issue) => {
  const group = issue.group ?? 'Dataset';
  counts[group] = (counts[group] ?? 0) + 1;
  return counts;
}, {});
const report = {
  totalWords: words.length,
  affectedWords: new Set(uniqueIssues.map((issue) => issue.id).filter(Boolean)).size,
  totalIssues: uniqueIssues.length,
  byLabel,
  byCore,
  issues: uniqueIssues,
};

fs.mkdirSync(path.dirname(reportPath), { recursive: true });
fs.writeFileSync(reportPath, `${JSON.stringify(report, null, 2)}\n`, 'utf8');
console.log(JSON.stringify({ ...report, issues: uniqueIssues.slice(0, 50), reportPath }, null, 2));

if (uniqueIssues.length > 0) {
  process.exitCode = 1;
}
