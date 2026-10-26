import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const destination = 'ios/Packages/Word7000Core/Sources/Word7000Core/Resources/speaking-prompts.json';
// The web app reads the same reviewed cards, without the provenance fields.
const webDestination = 'src/data/speaking-cards.json';
const fields = ['id', 'word', 'keywordZh', 'question', 'answerEn', 'answerZh'];
const tokens = text => text.toLowerCase().match(/[a-z]+/g) ?? [];

export function validateRecords(records, vocabulary, expectedCount = 600) {
  if (records.length !== expectedCount) throw new Error(`Expected ${expectedCount} questions, found ${records.length}`);
  const words = new Map(vocabulary.map(word => [word.word, word]));
  const seen = new Map(['id', 'word', 'question', 'answerEn', 'answerZh'].map(field => [field, new Set()]));
  for (const record of records) {
    for (const field of fields) {
      if (typeof record[field] !== 'string' || !record[field].trim()) throw new Error(`Missing ${field}: ${record.word}`);
      if (record[field] !== record[field].trim() || /[\r\n]/.test(record[field])) throw new Error(`Unexpected whitespace: ${record.word}.${field}`);
    }
    const word = words.get(record.word);
    if (!word || record.id !== `${word.id}-reviewed-1`) throw new Error(`Vocabulary identity mismatch: ${record.word}`);
    for (const [field, values] of seen) {
      const value = record[field].toLowerCase().replace(/\s+/g, ' ');
      if (values.has(value)) throw new Error(`Duplicate ${field}: ${record.word}`);
      values.add(value);
    }
    if (/\p{Script=Han}/u.test(record.question + record.answerEn)) throw new Error(`Mixed English text: ${record.word}`);
    if (!/[?]$/.test(record.question) && !/^(Describe|Imagine|Explain|Discuss|Tell)\b/.test(record.question)) throw new Error(`Incomplete question: ${record.word}`);
    if (tokens(record.question).length < 6 || tokens(record.question).length > 60) throw new Error(`Question length: ${record.word}`);
    const answerWords = tokens(record.answerEn);
    if (!answerWords.includes(record.word)) throw new Error(`Missing English target: ${record.word}`);
    if (answerWords.length < 16 || answerWords.length > 90) throw new Error(`Answer length: ${record.word}`);
    if ((record.answerEn.match(/[.!?](?:\s|$)/g) ?? []).length < 2) throw new Error(`Answer needs context and development: ${record.word}`);
    if (!/\p{Script=Han}/u.test(record.keywordZh) || !record.keywordZh.split('…').every(part => record.answerZh.includes(part))) {
      throw new Error(`Missing Chinese target: ${record.word}`);
    }
    if ([record.question, record.answerEn, record.answerZh].some(text => /lorem ipsum|placeholder|I would add one personal reason|我會再補上一個|What is a situation where you can use/i.test(text))) {
      throw new Error(`Placeholder wording: ${record.word}`);
    }
  }
}

export function buildLibrary() {
  const sourceText = file => fs.readFileSync(path.join(root, file), 'utf8').replace(/\r\n/g, '\n');
  const read = file => JSON.parse(sourceText(file));
  const vocabulary = read('ios/Word7000/Resources/words.json');
  const byWord = new Map(vocabulary.map(word => [word.word, word]));
  const plan = read('content/speaking/expansion-plan.json');
  const sources = ['content/speaking/base-reviewed.json'];
  const records = [...read(sources[0]).records];
  for (const [topic, plannedWords] of Object.entries(plan)) {
    const file = `content/speaking/topics/${topic}.json`;
    sources.push(file);
    const rows = read(file);
    if (rows.length !== 24 || JSON.stringify(rows.map(row => row[0])) !== JSON.stringify(plannedWords)) {
      throw new Error(`Topic is incomplete or its word order changed: ${topic}`);
    }
    for (const row of rows) {
      if (!Array.isArray(row) || row.length !== 5) throw new Error(`Invalid editorial row: ${topic}`);
      const [word, keywordZh, question, answerEn, answerZh] = row;
      const entry = byWord.get(word);
      if (!entry) throw new Error(`Unknown word: ${word}`);
      records.push({ id: `${entry.id}-reviewed-1`, word, keywordZh, question, answerEn, answerZh });
    }
  }
  validateRecords(records, vocabulary);
  records.sort((a, b) => a.id.localeCompare(b.id));
  const groups = {};
  for (const record of records) {
    const group = byWord.get(record.word).group;
    groups[group] = (groups[group] ?? 0) + 1;
  }
  if (Object.keys(groups).length !== 14) throw new Error('Questions must remain available across all fourteen levels');
  return {
    schemaVersion: 1,
    reviewedAt: '2026-10-20',
    sources: sources.map(file => ({ file, sha256: crypto.createHash('sha256').update(sourceText(file)).digest('hex') })),
    coverage: { words: records.length, addedTopics: Object.keys(plan).length, levels: groups },
    records,
  };
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const document = buildLibrary();
  const outputs = [
    [destination, JSON.stringify(document, null, 2) + '\n'],
    [webDestination, JSON.stringify(document.records) + '\n'],
  ];
  for (const [file, output] of outputs) {
    if (process.argv.includes('--check')) {
      const current = fs.existsSync(path.join(root, file)) ? fs.readFileSync(path.join(root, file), 'utf8').replace(/\r\n/g, '\n') : '';
      if (current !== output) throw new Error(`${file} is stale. Run node scripts/build-native-speaking-library.mjs`);
    } else {
      fs.writeFileSync(path.join(root, file), output);
    }
  }
  console.log(JSON.stringify({ questions: document.records.length, newQuestions: 480, topics: 20, levels: document.coverage.levels, checked: process.argv.includes('--check') }));
}
