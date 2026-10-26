import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const projectRoot = path.resolve(__dirname, '..');
const wordsPath = path.join(projectRoot, 'src', 'data', 'words.ts');
const reportPath = path.join(projectRoot, '.codex-run', 'example-quality-audit.json');
const source = fs.readFileSync(wordsPath, 'utf8');
const match = source.match(/export const sampleWords: WordEntry\[\] = ([\s\S]+);\s*$/);

if (!match) {
  throw new Error(`Could not read sampleWords from ${wordsPath}`);
}

const words = JSON.parse(match[1]);
const issues = [];
const englishTokenCount = (value) => value.match(/[A-Za-z]+(?:['’-][A-Za-z]+)*/g)?.length ?? 0;
const chineseCharacterCount = (value) => value.match(/\p{Script=Han}/gu)?.length ?? 0;
const escapeRegex = (value) => value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

const riskPatterns = [
  ['english-meta-wording', /\b(this example|the example|the word|this word|the sentence|this sentence|the phrase|the meaning|the definition|learners?|works? in context|practical context|easier to remember|meaning clearer)\b/i],
  ['english-generic-detail', /\b(the detail became important|noticed an? [a-z]+ detail|one overlooked detail|asked a follow-up question)\b/i],
  ['english-generic-learning', /\b(the description became clearer|the sentence felt more|a simple note about|in the final paragraph|before you move on)\b/i],
  ['english-generic-action', /\b(helped us [a-z]+ the next step|was easy to find in the|treated [a-z]+ as a small detail)\b/i],
  ['english-awkward-collocation', /\b(visited the visit|attend the schedule|marry the project|reached the office before|listened particularly|answered extremely|worked plainly through)\b/i],
  ['chinese-placeholder', /(這個這個詞|這個詞|這個字)/u],
  ['chinese-meta-wording', /(這個例句|這個單字|這個句子|理解.*(用法|脈絡|上下文)|更容易記住這個|意思變得更清楚)/u],
  ['chinese-generic-scaffold', /(視為重要|在.+後說明了|裡很容易找到|幫助我們.+下一步|幾分鐘後有人提出了追問|這個細節在後續討論中變得重要)/u],
  ['chinese-broken-grammar', /(的的|一個小這個|很這個詞|地這個詞|用一句清楚的話這個詞)/u],
];

const requiredHeadwordForms = new Map([
  ['mr', /\bMr\./],
  ['mrs', /\bMrs\./],
  ['ms', /\bMs\./],
  ['tv', /\bTV\b/],
  ['aids', /\bAIDS\b/],
  ['tion', /\bTION\b/],
  ['cd', /\bCD\b/],
  ['gm', /\bGM\b/],
  ['bible', /\bBible\b/],
  ['hispanic', /\bHispanic\b/],
  ['marxist', /\bMarxist\b/],
  ['dna', /\bDNA\b/],
  ['pc', /\bPC\b/],
  ['victorian', /\bVictorian\b/],
  ['jan', /\bJan\./],
  ['protestant', /\bProtestant\b/],
  ['aug', /\bAug\./],
  ['nhs', /\bNHS\b/],
  ['raf', /\bRAF\b/],
  ['hindu', /\bHindu\b/],
  ['georgian', /\bGeorgian\b/],
  ['gnp', /\bGNP\b/],
  ['gp', /\bGP\b/],
  ['briton', /\bBriton\b/],
  ['min', /\bMin\./],
  ['op', /\bOP\b/],
  ['imf', /\bIMF\b/],
  ['scots', /\bScots\b/],
  ['itv', /\bITV\b/],
  ['lp', /\bLP\b/],
  ['gmt', /\bGMT\b/],
  ['midlands', /\bMidlands\b/],
  ['pr', /\bPR\b/],
  ['cia', /\bCIA\b/],
  ['sikh', /\bSikh\b/],
  ['ibid', /\bibid\./],
  ['vatican', /\bVatican\b/],
  ['fbi', /\bFBI\b/],
  ['abc', /\bABC\b/],
  ['fm', /\bFM\b/],
  ['kremlin', /\bKremlin\b/],
  ['nasa', /\bNASA\b/],
  ['ecu', /\bECU\b/],
  ['capt', /\bCapt\./],
  ['rc', /\bRC\b/],
  ['ext', /\bext\./],
  ['ple', /\bPLE\b/],
  ['whitehall', /\bWhitehall\b/],
  ['opec', /\bOPEC\b/],
]);

function addIssue(word, label, details = '') {
  issues.push({
    id: word.id,
    word: word.word,
    group: word.group,
    label,
    details,
    meaningZh: word.meaningZh,
    example: word.example,
    exampleZh: word.exampleZh,
  });
}

for (const word of words) {
  const englishLength = englishTokenCount(word.example);
  const chineseLength = chineseCharacterCount(word.exampleZh);
  const targetPattern = new RegExp(`(^|[^a-z])${escapeRegex(word.word)}([^a-z]|$)`, 'i');

  if (englishLength < 8) {
    addIssue(word, 'english-too-short', `${englishLength} words`);
  } else if (englishLength > 22) {
    addIssue(word, 'english-too-long', `${englishLength} words`);
  }
  if (chineseLength < 8) {
    addIssue(word, 'chinese-too-short', `${chineseLength} Han characters`);
  } else if (chineseLength > 42) {
    addIssue(word, 'chinese-too-long', `${chineseLength} Han characters`);
  }
  if (!targetPattern.test(word.example)) {
    addIssue(word, 'missing-headword');
  }
  const requiredHeadwordForm = requiredHeadwordForms.get(word.word.toLowerCase());
  if (requiredHeadwordForm && !requiredHeadwordForm.test(word.example)) {
    addIssue(word, 'incorrect-headword-capitalization');
  }
  if (!/[.!?]$/.test(word.example.trim())) {
    addIssue(word, 'english-missing-terminal-punctuation');
  }
  if (!/[。！？]$/.test(word.exampleZh.trim())) {
    addIssue(word, 'chinese-missing-terminal-punctuation');
  }

  const combined = `${word.example} ${word.exampleZh}`;
  for (const [label, pattern] of riskPatterns) {
    if (pattern.test(combined)) {
      addIssue(word, label);
    }
  }
}

function normalizedFrame(word) {
  return word.example
    .toLowerCase()
    .replace(new RegExp(`(^|[^a-z])${escapeRegex(word.word)}([^a-z]|$)`, 'gi'), '$1{word}$2')
    .replace(/\s+/g, ' ')
    .trim();
}

function openingFrame(word) {
  return (word.example.toLowerCase().match(/[a-z]+(?:['’-][a-z]+)*/g) ?? []).slice(0, 4).join(' ');
}

function flagRepeatedValues(label, valueForWord, allowedCount) {
  const values = new Map();
  for (const word of words) {
    const value = valueForWord(word);
    const matches = values.get(value) ?? [];
    matches.push(word);
    values.set(value, matches);
  }

  for (const [value, matches] of values) {
    if (value && matches.length > allowedCount) {
      for (const word of matches) {
        addIssue(word, label, `${matches.length} uses: ${value}`);
      }
    }
  }
}

flagRepeatedValues('duplicate-english-example', (word) => word.example.trim().toLowerCase(), 1);
flagRepeatedValues('duplicate-chinese-translation', (word) => word.exampleZh.trim(), 1);
flagRepeatedValues('repeated-replacement-frame', normalizedFrame, 2);
flagRepeatedValues('overused-four-word-opening', openingFrame, 8);

const uniqueIssues = Array.from(
  new Map(issues.map((issue) => [`${issue.id}:${issue.label}`, issue])).values(),
);
const byLabel = uniqueIssues.reduce((counts, issue) => {
  counts[issue.label] = (counts[issue.label] ?? 0) + 1;
  return counts;
}, {});
const byCore = uniqueIssues.reduce((counts, issue) => {
  counts[issue.group] = (counts[issue.group] ?? 0) + 1;
  return counts;
}, {});
const report = {
  totalWords: words.length,
  affectedWords: new Set(uniqueIssues.map((issue) => issue.id)).size,
  totalIssues: uniqueIssues.length,
  byLabel,
  byCore,
  issues: uniqueIssues,
};

fs.mkdirSync(path.dirname(reportPath), { recursive: true });
fs.writeFileSync(reportPath, `${JSON.stringify(report, null, 2)}\n`, 'utf8');
console.log(JSON.stringify({ ...report, issues: uniqueIssues.slice(0, 40), reportPath }, null, 2));

if (uniqueIssues.length > 0) {
  process.exitCode = 1;
}
