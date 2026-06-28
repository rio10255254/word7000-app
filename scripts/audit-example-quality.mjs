import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const projectRoot = path.resolve(__dirname, '..');
const wordsPath = path.join(projectRoot, 'src', 'data', 'words.ts');

const source = fs.readFileSync(wordsPath, 'utf8');
const match = source.match(/export const sampleWords: WordEntry\[\] = ([\s\S]+);\s*$/);
if (!match) {
  throw new Error(`Could not read sampleWords from ${wordsPath}`);
}

const words = JSON.parse(match[1]);
const highRiskPatterns = [
  {
    label: 'generic-explained-after-event',
    pattern: /\bexplained the [a-z]+ after the (meeting|lesson|interview|workshop|trip|review|practice|discussion|training|visit|trial|festival|inspection|presentation|debate|rehearsal)\b/i,
  },
  {
    label: 'generic-treated-important',
    pattern: /\btreated the [a-z]+ as important\b/i,
  },
  {
    label: 'generic-easy-to-find',
    pattern: /\bwas easy to find in the\b/i,
  },
  {
    label: 'generic-detail-in-object',
    pattern: /\bnoticed an? [a-z]+ detail in the\b/i,
  },
  {
    label: 'generic-helped-next-step',
    pattern: /\bhelped us [a-z]+ the next step\b/i,
  },
  {
    label: 'generic-carefully-object',
    pattern: /\bPlease [a-z]+ the (plan|report|schedule|project|message|lesson|file|room|budget|map|letter|ticket|device|garden|contract|display) carefully\b/i,
  },
  {
    label: 'zh-generic-explained',
    pattern: /在.+後說明了/,
  },
  {
    label: 'zh-treated-important',
    pattern: /視為重要/,
  },
  {
    label: 'zh-easy-to-find',
    pattern: /裡很容易找到/,
  },
  {
    label: 'zh-helped-next-step',
    pattern: /幫助我們.+下一步/,
  },
];

const flagged = words.flatMap((word) => {
  const text = `${word.example} ${word.exampleZh}`;
  return highRiskPatterns
    .filter(({ pattern }) => pattern.test(text))
    .map(({ label }) => ({
      id: word.id,
      word: word.word,
      label,
      partOfSpeech: word.partOfSpeech,
      meaningZh: word.meaningZh,
      example: word.example,
      exampleZh: word.exampleZh,
    }));
});

const byLabel = flagged.reduce((counts, item) => {
  counts[item.label] = (counts[item.label] ?? 0) + 1;
  return counts;
}, {});

console.log(JSON.stringify({ total: words.length, flagged: flagged.length, byLabel, samples: flagged.slice(0, 40) }, null, 2));

if (flagged.length > 0) {
  process.exitCode = 1;
}
