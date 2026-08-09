import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const projectRoot = path.resolve(__dirname, '..');
const wordsPath = path.join(projectRoot, 'src', 'data', 'words.ts');
const reportPath = path.join(projectRoot, '.codex-run', 'taiwan-chinese-example-audit.json');
const source = fs.readFileSync(wordsPath, 'utf8');
const match = source.match(/export const sampleWords: WordEntry\[\] = ([\s\S]+);\s*$/);

if (!match) {
  throw new Error(`Could not read sampleWords from ${wordsPath}`);
}

const words = JSON.parse(match[1]);
const issues = [];
const hardPatterns = [
  ['mainland-usage', /(?<!探)(視頻|軟件|硬件|打印|鼠標|硬盤|公交車|出租車|土豆|西紅柿|文件夾|服務器|網絡|短信|郵箱)/u],
  ['literal-account-for', /可以解釋.+原因/u],
  ['literal-smell-order', /(聞起來有|花園聞得到)/u],
  ['literal-alternative-order', /擁擠公車外的替代選擇/u],
  ['literal-test-as', /測試.+作為/u],
  ['overformal-ending', /以.+作結/u],
  ['unnatural-service-hours', /(診所|髮廊).+營業到很晚/u],
  ['medical-collocation', /認出(症候群|疾病|病症)/u],
  ['literal-challenge', /對.+都是?強大挑戰/u],
  ['non-taiwan-part-term', /替換零件/u],
  ['missing-modifier', /吃力學生/u],
  ['awkward-time-unit', /一個早上/u],
  ['literal-dinner-stop', /晚餐.+停了/u],
  ['awkward-steam-noun', /胡椒香蒸氣/u],
  ['literal-trait-order', /最冷靜的特質/u],
  ['literal-trail-continuation', /步道續行路段/u],
  ['literal-benefit-frame', /額外輔導對.+有益/u],
  ['formal-survivor-term', /強暴倖存者/u],
  ['literal-paperwork-frame', /病患文書作業/u],
  ['awkward-weather-count', /幾個雨天後/u],
  ['awkward-until-near', /直到接近/u],
  ['taiwan-nurse-title', /護士/u],
  ['literal-visit-frequency', /探視頻率/u],
  ['mainland-food-order', /點單/u],
  ['mainland-pineapple-bun', /菠蘿包/u],
  ['ambiguous-whole-meal', /整頓(?:晚餐|飯)/u],
  ['literal-missing-ticket', /失蹤車票/u],
  ['compressed-bubble-tea', /濃珍奶/u],
  ['missing-frame-noun', /裂框/u],
  ['missing-sleeping-particle', /睡狗/u],
  ['literal-rice-bowl-top', /飯碗上/u],
  ['mainland-vinyl-floor', /乙烯基地板/u],
  ['mainland-cyclist-term', /自行車騎士/u],
  ['wrong-shrine-collocation', /神壇.+陡坡/u],
  ['literal-value-experience', /旅行對青少年可能是寶貴的經驗/u],
  ['literal-special-day', /對我們家是特別的一天/u],
  ['literal-frozen-state', /運送後仍是冷凍狀態/u],
  ['literal-dawn-thing', /黎明最棒的地方是安靜的港口/u],
  ['literal-whose-order', /櫃台旁的是誰的雨傘/u],
  ['literal-decision-factor', /我們決定中的最大因素/u],
  ['missing-de-water', /乾淨水是製作安全豆腐/u],
  ['literal-family-reconciliation', /拜訪的目的是家人和解/u],
  ['literal-recognize-smell', /認得那是.+廚房的味道/u],
  ['literal-relation-frame', /我和新娘是母親那邊的親戚/u],
  ['literal-icy-stream', /穿過那條冰溪對我們/u],
  ['literal-fallen-bamboo', /延誤部分是倒下/u],
  ['literal-cotton', /襯衫是棉的/u],
  ['literal-inner-sense', /相信內心的是非感/u],
  ['literal-philosophy', /人生觀是慢慢煮/u],
  ['literal-foolish-venture', /淹水橋是愚蠢冒險/u],
  ['literal-bus-assumption', /假定證明是錯的/u],
  ['literal-empty-villa', /推測空別墅裡的燈光是怎麼回事/u],
  ['literal-tofu-attraction', /主要賣點是百年豆腐攤/u],
  ['literal-watery-soup', /湯太水是嚴重侮辱/u],
  ['literal-fishing-colony', /小漁民殖民地/u],
  ['literal-missing-key-puzzle', /失蹤鑰匙整週都是謎/u],
  ['literal-rent-contention', /主要論點是租金漲得不公平/u],
  ['literal-manifestation', /顫抖的手是深層焦慮的顯現/u],
  ['literal-apron-smell', /圍裙聞起來都是蒜味/u],
  ['literal-honeymoon-passive', /蜜月是在.+健行中度過/u],
  ['neem-oil-typo', /塗印楝油/u],
  ['nearest-mistranslation', /^最近(?:的)?診所/u],
  ['recently-missing-pause', /^最近更多家庭/u],
  ['literal-overnight-order', /一夜間改善/u],
  ['wrong-wolf-counter', /一匹狼/u],
  ['literal-wet-laundry-order', /濕衣物整個早上滴在/u],
  ['wrong-dough-collocation', /麵團發起前/u],
  ['literal-horrible-smell', /可怕臭味/u],
  ['literal-water-illusion', /造成有水的錯覺/u],
  ['literal-brake-light-order', /煞車燈故障，騎這輛機車/u],
  ['literal-blind-corner', /視線死角巷口/u],
  ['literal-unlucky-bounce', /不幸的彈跳/u],
  ['literal-solar-module', /太陽能組件供應山屋照明/u],
  ['literal-sunday-chore', /週日雜務/u],
  ['literal-aerial-photo', /空拍照片拍出森林掩蓋/u],
  ['literal-instinct-order', /直覺告訴她在浪變高/u],
  ['literal-repeated-calls', /反覆來電終於叫醒/u],
  ['compressed-wet-umbrella-smell', /濕傘味/u],
  ['literal-lab-smell', /實驗室裡滿是咖啡味/u],
  ['literal-vineyard-smell', /葡萄園裡滿是濕葉子的氣味/u],
  ['literal-plaster-smell', /滿是油漆和濕灰泥/u],
  ['literal-car-smell', /車內聞起來像咖啡和濕外套/u],
  ['literal-pear-soup-smell', /梨湯聞起來就更溫暖香甜/u],
];

for (const word of words) {
  for (const [label, pattern] of hardPatterns) {
    if (pattern.test(word.exampleZh)) {
      issues.push({
        id: word.id,
        word: word.word,
        group: word.group,
        label,
        example: word.example,
        exampleZh: word.exampleZh,
      });
    }
  }
}

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
console.log(JSON.stringify({ ...report, issues: uniqueIssues.slice(0, 80), reportPath }, null, 2));

if (uniqueIssues.length > 0) {
  process.exitCode = 1;
}
