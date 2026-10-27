// Writes the tone-marked pinyin the native app shows in Learn Chinese mode
// (ios/Packages/Word7000Core/Sources/Word7000Core/Resources/pinyin-readings.json):
// one reading for every Chinese sense, example sentence and speaking card.
//
// Characters with more than one reading (長大 zhǎng, 銀行 háng, 還是 hái, 乾淨 gān)
// need the whole word. The system transliterator and pinyin-pro both read
// Traditional characters one at a time, so the text is converted to Simplified
// first (same length, character for character) and read as words there. Taiwan's
// standard readings then replace the mainland ones where they differ, since the
// app speaks with a Taiwan voice.
//
//   node scripts/build-pinyin-readings.mjs          write the file (needs npm ci)
//   node scripts/build-pinyin-readings.mjs --check  fail if a text has no reading
//                                                   (no dependencies, for the Mac CI)
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const wordsFile = path.join(root, 'ios/Word7000/Resources/words.json');
const speakingFile = path.join(root, 'ios/Packages/Word7000Core/Sources/Word7000Core/Resources/speaking-prompts.json');
const target = path.join(root, 'ios/Packages/Word7000Core/Sources/Word7000Core/Resources/pinyin-readings.json');

// ChineseDisplay.meaningParts: split on ；;，,、, trim, drop empty parts and repeats.
export function meaningParts(meaning) {
  return [...new Set(String(meaning ?? '').split(/[；;，,、]/).map((part) => part.trim()).filter(Boolean))];
}

const han = /[〇㐀-䶿一-鿿豈-﫿\u{20000}-\u{323af}]/u;

/** Every text the app shows pinyin for. */
export function textsToRead(words, speaking) {
  const texts = new Set();
  const add = (text) => { if (han.test(text ?? '')) texts.add(text.trim()); };
  for (const word of words) {
    for (const part of [...meaningParts(word.meaningZh), ...meaningParts(word.supplementalMeaningZh)]) add(part);
    add(word.exampleZh);
  }
  for (const record of speaking.records) {
    add(record.keywordZh);
    add(record.answerZh);
  }
  return [...texts].sort();
}

// Taiwan's Ministry of Education readings that differ from the mainland ones
// for characters common in the word list. Whole words first.
const TAIWAN_WORDS = new Map([
  ['垃圾', ['lè', 'sè']],
  ['頭髮', ['tóu', 'fǎ']],
  ['理髮', ['lǐ', 'fǎ']],
  // Words the reader gets wrong in context.
  ['有空', ['yǒu', 'kòng']],
  ['沒空', ['méi', 'kòng']],
  ['旅行', ['lǚ', 'xíng']],
  ['中文', ['zhōng', 'wén']],
  ['長得', ['zhǎng', 'de']],
  ['睡不著', ['shuì', 'bù', 'zháo']],
  ['睡著', ['shuì', 'zháo']],
]);
const TAIWAN_CHARACTERS = new Map([
  ['期', 'qí'], ['危', 'wéi'], ['微', 'wéi'], ['企', 'qì'], ['質', 'zhí'], ['液', 'yì'],
  ['擁', 'yǒng'], ['暫', 'zhàn'], ['息', 'xí'], ['惜', 'xí'], ['昔', 'xí'], ['夕', 'xì'],
  ['檔', 'dàng'], ['綜', 'zòng'], ['播', 'bò'], ['頻', 'pín'], ['髮', 'fǎ'],
  // Read one way in Traditional text (隻 is the measure word, 只 only).
  ['誰', 'shéi'], ['姊', 'jiě'], ['只', 'zhǐ'], ['喔', 'ō'],
  ['突', 'tú'], ['究', 'jiù'], ['叔', 'shú'], ['署', 'shù'], ['傍', 'bāng'], ['血', 'xiě'],
]);
// 得 after a verb, before how it was done (跑得很快, 說得好), is de.
const DE_FOLLOWERS = new Set([...'很好太非常不真快慢多清滿更越']);

const PUNCTUATION = new Map(Object.entries({
  '，': ',', '。': '.', '！': '!', '？': '?', '：': ':', '；': ';', '、': ',',
  '「': '“', '」': '”', '『': '‘', '』': '’', '（': '(', '）': ')', '…': '…', '—': '—', '～': '~',
}));
const OPENING = new Set(['“', '‘', '(']);

/**
 * One reading per character of `text`, null for characters that are not
 * Chinese: whole words read in context, then Taiwan's standard readings.
 */
export function makeSyllableReader({ pinyin, toSimplified }) {
  return function syllablesOf(text) {
    const characters = [...text];
    const simplified = [...toSimplified(text)];
    const source = simplified.length === characters.length ? simplified.join('') : text;
    const syllables = pinyin(source, { type: 'array', nonZh: 'removed', toneSandhi: true });
    const readings = [];
    let next = 0;
    for (const character of characters) readings.push(han.test(character) ? syllables[next++] ?? '' : null);
    for (let index = 0; index < characters.length; index += 1) {
      for (const [word, sounds] of TAIWAN_WORDS) {
        if (characters.slice(index, index + word.length).join('') === word) {
          sounds.forEach((sound, offset) => { readings[index + offset] = sound; });
        }
      }
    }
    characters.forEach((character, index) => {
      if (TAIWAN_CHARACTERS.has(character) && !TAIWAN_WORDS.has(characters.slice(index - 1, index + 1).join(''))
        && !TAIWAN_WORDS.has(characters.slice(index, index + 2).join(''))) {
        readings[index] = TAIWAN_CHARACTERS.get(character);
      }
      if (character === '得' && index > 0 && han.test(characters[index - 1]) && DE_FOLLOWERS.has(characters[index + 1])
        && !TAIWAN_WORDS.has(characters.slice(index - 1, index + 1).join(''))) {
        readings[index] = 'de';
      }
    });

    return readings;
  };
}

/**
 * Tone-marked pinyin for `text`: syllables separated by spaces, Chinese
 * punctuation turned into its Latin form, other text kept as it is.
 */
export function makeReader({ pinyin, toSimplified }) {
  const syllablesOf = makeSyllableReader({ pinyin, toSimplified });
  return function read(text) {
    const characters = [...text];
    const readings = syllablesOf(text);

    let out = '';
    let latin = '';
    const append = (piece, { space = true } = {}) => {
      if (!piece) return;
      if (space && out && !/[\s“‘(]$/.test(out)) out += ' ';
      out += piece;
    };
    const flushLatin = () => { if (latin.trim()) append(latin.trim()); latin = ''; };
    characters.forEach((character, index) => {
      if (readings[index] !== null) { flushLatin(); append(readings[index]); return; }
      const mark = PUNCTUATION.get(character);
      if (mark) {
        flushLatin();
        if (OPENING.has(mark)) append(mark);
        else out += mark;
        return;
      }
      if (/\s/.test(character)) { flushLatin(); return; }
      latin += character;
    });
    flushLatin();
    return out.replace(/\s+/g, ' ').trim();
  };
}

function load() {
  return {
    words: JSON.parse(fs.readFileSync(wordsFile, 'utf8')),
    speaking: JSON.parse(fs.readFileSync(speakingFile, 'utf8')),
  };
}

async function main() {
  const { words, speaking } = load();
  const texts = textsToRead(words, speaking);
  if (process.argv.includes('--check')) {
    const readings = JSON.parse(fs.readFileSync(target, 'utf8')).readings ?? {};
    const missing = texts.filter((text) => !readings[text]);
    if (missing.length) {
      console.error(`${missing.length} texts have no pinyin, e.g. ${missing.slice(0, 5).join(' | ')}`);
      console.error('Run: node scripts/build-pinyin-readings.mjs');
      process.exit(1);
    }
    console.log(`All ${texts.length} Chinese texts have pinyin.`);
    return;
  }
  const { pinyin } = await import('pinyin-pro');
  const OpenCC = await import('opencc-js');
  const toSimplified = OpenCC.Converter({ from: 't', to: 'cn' });
  const read = makeReader({ pinyin, toSimplified });
  const readings = Object.fromEntries(texts.map((text) => [text, read(text)]));
  fs.writeFileSync(target, `${JSON.stringify({ schemaVersion: 1, readings })}\n`);
  console.log(`Wrote ${texts.length} readings to ${path.relative(root, target)}.`);
}

if (process.argv[1] === fileURLToPath(import.meta.url)) await main();
