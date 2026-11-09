// Writes the word list the native iOS app bundles (ios/Word7000/Resources/words.json)
// from src/data/words.ts, so both apps always ship the same reviewed data.
//   node scripts/export-native-words.mjs          write the file
//   node scripts/export-native-words.mjs --check  fail if it is out of date
//
// Each word also gets `exampleZhCue` from content/example-cues.json: the part
// of `exampleZh` that translates the word, highlighted above a fill-in-the-
// blank question. "context|cue" pins a cue that appears more than once (the
// cue right after the context is the one meant). A cue that no longer matches
// its sentence, because the sentence was edited, is left out and listed so it
// can be annotated again; an empty cue means the word has no visible
// counterpart in the translation.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const source = fs.readFileSync(path.join(root, 'src/data/words.ts'), 'utf8');
const start = source.indexOf('= [', source.indexOf('export const sampleWords')) + 2;
const end = source.lastIndexOf(']');
const words = JSON.parse(source.slice(start, end + 1));
const cues = JSON.parse(fs.readFileSync(path.join(root, 'content/example-cues.json'), 'utf8'));
const keys = ['id', 'word', 'partOfSpeech', 'pronunciation', 'meaningZh', 'supplementalMeaningZh', 'example', 'exampleZh', 'exampleZhCue', 'group'];
const stale = [];
const compact = words.map((word) => {
  const cue = cues[word.id];
  const entry = { ...word };
  if (cue) {
    if (word.exampleZh.includes(cue.replace('|', ''))) entry.exampleZhCue = cue;
    else stale.push(word.id);
  }
  return Object.fromEntries(keys.filter((key) => entry[key] !== undefined).map((key) => [key, entry[key]]));
});
const output = `${JSON.stringify(compact)}\n`;
const target = path.join(root, 'ios/Word7000/Resources/words.json');

if (stale.length) {
  console.warn(`${stale.length} cue(s) in content/example-cues.json no longer match their sentence and were left out: ${stale.join(', ')}`);
}
if (process.argv.includes('--check')) {
  const current = fs.existsSync(target) ? fs.readFileSync(target, 'utf8') : '';
  if (current.replace(/\r\n/g, '\n') !== output) {
    console.error('ios/Word7000/Resources/words.json is out of date. Run: node scripts/export-native-words.mjs');
    process.exit(1);
  }
  console.log(`words.json is current (${compact.length} words).`);
} else {
  fs.mkdirSync(path.dirname(target), { recursive: true });
  fs.writeFileSync(target, output);
  console.log(`Wrote ${compact.length} words to ${path.relative(root, target)} (${(output.length / 1024).toFixed(0)} KB).`);
}
