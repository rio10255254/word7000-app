import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const projectRoot = path.resolve(__dirname, '..');
const wordsPath = path.join(projectRoot, 'src', 'data', 'words.ts');
const outputDir = path.join(projectRoot, '.codex-run', 'example-review-packets');
const source = fs.readFileSync(wordsPath, 'utf8');
const match = source.match(/export const sampleWords: WordEntry\[\] = ([\s\S]+);\s*$/);

if (!match) {
  throw new Error(`Could not read sampleWords from ${wordsPath}`);
}

const words = JSON.parse(match[1]);
fs.mkdirSync(outputDir, { recursive: true });

for (let core = 1; core <= 14; core += 1) {
  const group = `Core ${core}`;
  const rows = words
    .filter((word) => word.group === group)
    .map((word) => ({
      id: word.id,
      word: word.word,
      partOfSpeech: word.partOfSpeech,
      meaningZh: word.meaningZh,
      currentExample: word.example,
      currentExampleZh: word.exampleZh,
    }));

  if (rows.length !== 500) {
    throw new Error(`${group} must contain exactly 500 words; found ${rows.length}`);
  }

  const filename = `core${String(core).padStart(2, '0')}.json`;
  fs.writeFileSync(path.join(outputDir, filename), `${JSON.stringify(rows, null, 2)}\n`, 'utf8');
}

console.log(`Exported 14 review packets with ${words.length} total words to ${outputDir}.`);
