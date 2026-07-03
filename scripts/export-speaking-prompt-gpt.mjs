import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const projectRoot = path.resolve(__dirname, '..');
const wordsPath = path.join(projectRoot, 'src', 'data', 'words.ts');
const outputDate = '2026-07-03';
const outputDir = path.join(projectRoot, 'exports', 'speaking-prompt-gpt', outputDate);
const byCoreDir = path.join(outputDir, 'by-core');
const chunksDir = path.join(outputDir, 'chunks-100');

function clean(value) {
  return String(value ?? '').replace(/\r?\n/g, ' ').trim();
}

function primaryMeaning(value) {
  const text = clean(value);
  return text.split(/[；;，,、]/)[0]?.trim() || text;
}

function readWords() {
  const source = fs.readFileSync(wordsPath, 'utf8');
  const match = source.match(/export const sampleWords: WordEntry\[] = ([\s\S]*?);\s*$/);

  if (!match) {
    throw new Error(`Unable to parse sampleWords from ${wordsPath}`);
  }

  return JSON.parse(match[1]);
}

function toJsonl(rows) {
  return `${rows.map((row) => JSON.stringify(row)).join('\n')}\n`;
}

function writePromptFile() {
  const prompt = `# Word7000 口說題庫生成任務

你會收到一個 JSONL 檔案，每一行是一個單字。請為每個單字產生自然、像真人老師會問的口說練習題。

## 目標
- 題目要像開放式口說題，不要像字典造句。
- 題目本身要自然、具體、可回答。
- 不要使用「Use this word in your answer」這種模板當題目。
- 不要硬塞中文意思造成怪句。
- 每個題目應該讓學習者能回答 2 到 4 句。
- 對抽象字，要問觀點、經驗、選擇、原因或現實情境。
- 對基礎功能字，例如 be / and / of / to，要問自然的生活問題，不要照詞性硬套。

## 每個單字請產生 4 題
1. english_1：英文單字模式，英文題目，題目中自然包含英文單字。
2. english_2：英文單字模式，另一個不同角度的英文題目。
3. chinese_1：中文單字模式，英文介面題目，可以自然包含中文關鍵詞。
4. chinese_2：中文單字模式，另一個不同角度的英文題目。

## 輸出格式
請只輸出 JSON array，不要 Markdown，不要說明文字。每個單字一個物件，格式如下：

[
  {
    "id": "w0001",
    "word": "adapt",
    "meaningZh": "適應；調整；改編",
    "prompts": {
      "english": [
        {
          "question": "When have you had to adapt to a new rule, place, or routine?",
          "hint": "Answer in 2-4 sentences and use adapt naturally.",
          "sampleAnswer": "I had to adapt when I changed schools. At first I felt nervous, but a clear daily routine helped me feel more comfortable.",
          "sampleTranslationZh": "我轉學時必須適應。一開始我很緊張，但清楚的日常規律幫助我更自在。"
        }
      ],
      "chinese": [
        {
          "question": "When have you needed to 適應 a new place, rule, or routine?",
          "hint": "Answer in Chinese if possible and include 適應 once.",
          "sampleAnswerZh": "我剛進新學校時需要適應新的作息。後來我每天提前準備，就比較不緊張了。",
          "sampleTranslationEn": "When I first entered a new school, I needed to adapt to a new routine. Later, I prepared earlier every day, so I felt less nervous."
        }
      ]
    }
  }
]

## 品質規則
- 不要每題都問同一種 What is a situation...。
- 不要產生政治敏感攻擊、仇恨、成人或血腥內容。
- political 這類字可以問公共議題，例如：What do you think is the most important political issue in your community or country right now?
- 問題可以貼近台灣生活，但不要假設使用者一定住在台灣；可用 your community or country。
- 如果單字有多個意思，優先使用最常見的一到兩個意思。
- sampleAnswer 要自然，不要像機器翻譯。
- 每個輸出物件的 id 必須和輸入完全一致。
- 不要漏掉任何輸入單字。
`;

  fs.writeFileSync(path.join(outputDir, 'PROMPT_FOR_GPT.md'), prompt, 'utf8');
}

const words = readWords();
const rows = words.map((word, index) => ({
  index: index + 1,
  id: clean(word.id),
  word: clean(word.word),
  partOfSpeech: clean(word.partOfSpeech),
  pronunciation: clean(word.pronunciation),
  meaningZh: clean(word.meaningZh),
  primaryMeaningZh: primaryMeaning(word.meaningZh),
  example: clean(word.example),
  exampleZh: clean(word.exampleZh),
  group: clean(word.group),
}));

fs.mkdirSync(byCoreDir, { recursive: true });
fs.mkdirSync(chunksDir, { recursive: true });

fs.writeFileSync(path.join(outputDir, 'word7000-speaking-prompt-input-all.jsonl'), toJsonl(rows), 'utf8');

const groups = [...new Set(rows.map((row) => row.group))].sort(
  (left, right) => Number(left.replace(/\D/g, '')) - Number(right.replace(/\D/g, '')),
);

for (const group of groups) {
  const groupNumber = String(Number(group.replace(/\D/g, ''))).padStart(2, '0');
  const groupRows = rows.filter((row) => row.group === group);
  fs.writeFileSync(path.join(byCoreDir, `core-${groupNumber}.jsonl`), toJsonl(groupRows), 'utf8');
}

const manifest = [];
let chunkIndex = 1;

for (let start = 0; start < rows.length; start += 100) {
  const chunkRows = rows.slice(start, start + 100);
  const fileName = `chunk-${String(chunkIndex).padStart(2, '0')}-${chunkRows[0].id}-to-${chunkRows[chunkRows.length - 1].id}.jsonl`;

  fs.writeFileSync(path.join(chunksDir, fileName), toJsonl(chunkRows), 'utf8');
  manifest.push({
    chunk: chunkIndex,
    file: `chunks-100/${fileName}`,
    startIndex: chunkRows[0].index,
    endIndex: chunkRows[chunkRows.length - 1].index,
    count: chunkRows.length,
    firstWord: chunkRows[0].word,
    lastWord: chunkRows[chunkRows.length - 1].word,
    groups: [...new Set(chunkRows.map((row) => row.group))],
  });

  chunkIndex += 1;
}

writePromptFile();

const readme = `# Word7000 Speaking Prompt GPT Export

Created: ${outputDate}
Total words: ${rows.length}

Recommended use:
1. Open PROMPT_FOR_GPT.md and copy the whole instruction into GPT.
2. Upload or paste one file from chunks-100 at a time.
3. Ask GPT to return only JSON array.
4. Save each returned result using the same chunk number, for example output-chunk-01.json.
5. Send the generated output files back so they can be validated and imported into Word7000.

Files:
- word7000-speaking-prompt-input-all.jsonl: all ${rows.length} words in one JSONL file.
- by-core/core-01.jsonl ... core-14.jsonl: 500 words per level.
- chunks-100/*.jsonl: 100 words per chunk, safest for GPT generation.
- manifest.json: chunk list and boundaries.
`;

fs.writeFileSync(path.join(outputDir, 'README.md'), readme, 'utf8');
fs.writeFileSync(
  path.join(outputDir, 'manifest.json'),
  JSON.stringify(
    {
      created: outputDate,
      totalWords: rows.length,
      recommendedPrompt: 'PROMPT_FOR_GPT.md',
      allFile: 'word7000-speaking-prompt-input-all.jsonl',
      byCoreDir: 'by-core',
      chunksDir: 'chunks-100',
      chunkSize: 100,
      chunks: manifest,
    },
    null,
    2,
  ),
  'utf8',
);

console.log(
  JSON.stringify(
    {
      outputDir,
      totalWords: rows.length,
      coreFiles: groups.length,
      chunkFiles: manifest.length,
      firstChunk: manifest[0],
      lastChunk: manifest[manifest.length - 1],
    },
    null,
    2,
  ),
);
