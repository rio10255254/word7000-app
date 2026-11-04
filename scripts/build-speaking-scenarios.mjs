// Builds the native app's everyday-scenario role-plays from their editorial
// source, after checking them. `--check` fails when the built file is stale.
//
//   node scripts/build-speaking-scenarios.mjs [--check]
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const source = 'content/speaking/scenarios.json';
const destination = 'ios/Packages/Word7000Core/Sources/Word7000Core/Resources/speaking-scenarios.json';
const turnsPerStage = 5;
const han = /\p{Script=Han}/u;
const hanCount = text => [...text].filter(c => han.test(c)).length;
const words = text => text.toLowerCase().match(/[a-z0-9']+/g) ?? [];

export function validate(document) {
  const fail = message => { throw new Error(message); };
  if (document.schemaVersion !== 1) fail('schemaVersion must be 1');
  if (!Array.isArray(document.scenarios) || document.scenarios.length === 0) fail('No scenarios');
  const ids = new Set();
  const seen = { partner: new Set(), reply: new Set() };
  const text = (value, where) => {
    if (!value || typeof value.zh !== 'string' || typeof value.en !== 'string') fail(`Missing text: ${where}`);
    for (const [lang, string] of Object.entries({ zh: value.zh, en: value.en })) {
      if (!string.trim() || string !== string.trim() || /[\r\n]/.test(string)) fail(`Whitespace: ${where}.${lang}`);
    }
    if (!han.test(value.zh) || /[A-Za-z]/.test(value.zh)) fail(`Chinese text: ${where}`);
    if (han.test(value.en)) fail(`English text: ${where}`);
  };
  for (const scenario of document.scenarios) {
    if (!/^[a-z]+$/.test(scenario.id) || ids.has(scenario.id)) fail(`Scenario id: ${scenario.id}`);
    ids.add(scenario.id);
    text(scenario.title, `${scenario.id}.title`);
    if (typeof scenario.icon !== 'string' || !scenario.icon) fail(`Icon: ${scenario.id}`);
    if (!Array.isArray(scenario.stages) || scenario.stages.length === 0) fail(`Stages: ${scenario.id}`);
    scenario.stages.forEach((stage, s) => {
      const where = `${scenario.id}-${s + 1}`;
      text(stage.title, `${where}.title`);
      if (stage.turns?.length !== turnsPerStage) fail(`${where} needs ${turnsPerStage} turns`);
      stage.turns.forEach((turn, t) => {
        const at = `${where}.${t + 1}`;
        for (const field of ['role', 'partner', 'reply', 'key', 'task']) text(turn[field], `${at}.${field}`);
        if (!/[。！？]$/.test(turn.partner.zh) || !/[.!?]$/.test(turn.partner.en)) fail(`Partner punctuation: ${at}`);
        if (!/[。！？]$/.test(turn.reply.zh) || !/[.!?]$/.test(turn.reply.en)) fail(`Reply punctuation: ${at}`);
        const replyHan = hanCount(turn.reply.zh), replyWords = words(turn.reply.en).length;
        if (replyHan < 2 || replyHan > 20) fail(`Reply length (zh ${replyHan}): ${at}`);
        if (replyWords < 2 || replyWords > 14) fail(`Reply length (en ${replyWords}): ${at}`);
        if (!turn.reply.zh.includes(turn.key.zh)) fail(`Key not in the Chinese reply: ${at}`);
        if (!` ${words(turn.reply.en).join(' ')} `.includes(` ${words(turn.key.en).join(' ')} `)) fail(`Key not in the English reply: ${at}`);
        if (!turn.task.zh.startsWith('換你說：') || !turn.task.en.startsWith('Your turn: ')) fail(`Task wording: ${at}`);
        for (const field of ['partner', 'reply']) {
          for (const value of [turn[field].zh, turn[field].en.toLowerCase()]) {
            if (seen[field].has(value)) fail(`Duplicate ${field}: ${at}`);
            seen[field].add(value);
          }
        }
      });
    });
  }
}

export function build() {
  const document = JSON.parse(fs.readFileSync(path.join(root, source), 'utf8'));
  validate(document);
  return `${JSON.stringify(document)}\n`;
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const output = build();
  const target = path.join(root, destination);
  if (process.argv.includes('--check')) {
    const current = fs.existsSync(target) ? fs.readFileSync(target, 'utf8') : '';
    if (current !== output) {
      console.error(`${destination} is stale; run node scripts/build-speaking-scenarios.mjs`);
      process.exit(1);
    }
    console.log('Speaking scenarios match their source.');
  } else {
    fs.writeFileSync(target, output);
    console.log(`Wrote ${destination}`);
  }
}
