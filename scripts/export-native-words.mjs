// Writes the word list the native iOS app bundles (ios/Word7000/Resources/words.json)
// from src/data/words.ts, so both apps always ship the same reviewed data.
//   node scripts/export-native-words.mjs          write the file
//   node scripts/export-native-words.mjs --check  fail if it is out of date
import fs from 'node:fs';
import path from 'node:path';

const root = path.resolve(path.dirname(new URL(import.meta.url).pathname), '..');
const source = fs.readFileSync(path.join(root, 'src/data/words.ts'), 'utf8');
const start = source.indexOf('= [', source.indexOf('export const sampleWords')) + 2;
const end = source.lastIndexOf(']');
const words = JSON.parse(source.slice(start, end + 1));
const keys = ['id', 'word', 'partOfSpeech', 'pronunciation', 'meaningZh', 'supplementalMeaningZh', 'example', 'exampleZh', 'group'];
const compact = words.map((word) => Object.fromEntries(keys.filter((key) => word[key] !== undefined).map((key) => [key, word[key]])));
const output = `${JSON.stringify(compact)}\n`;
const target = path.join(root, 'ios/Word7000/Resources/words.json');

if (process.argv.includes('--check')) {
  const current = fs.existsSync(target) ? fs.readFileSync(target, 'utf8') : '';
  if (current !== output) {
    console.error('ios/Word7000/Resources/words.json is out of date. Run: node scripts/export-native-words.mjs');
    process.exit(1);
  }
  console.log(`words.json is current (${compact.length} words).`);
} else {
  fs.mkdirSync(path.dirname(target), { recursive: true });
  fs.writeFileSync(target, output);
  console.log(`Wrote ${compact.length} words to ${path.relative(root, target)} (${(output.length / 1024).toFixed(0)} KB).`);
}
