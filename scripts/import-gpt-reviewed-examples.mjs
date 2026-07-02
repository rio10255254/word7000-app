import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const projectRoot = path.resolve(__dirname, '..');
const sourceDir = path.join(projectRoot, 'exports', 'example-review', 'core4-14-2026-07-02', 'GPT', 'Long');
const expectedPath = path.join(projectRoot, 'exports', 'example-review', 'core4-14-2026-07-02', 'all-missing-core4-14.json');
const dataDir = path.join(projectRoot, 'src', 'data');
const targetLevels = Array.from({ length: 11 }, (_, index) => index + 4);
const manualOverrides = new Map([
  ['liberal', ['She has liberal views on education.', '她對教育持開明觀點。']],
  ['negotiation', ['The negotiation ended after three hours.', '談判在三小時後結束。']],
  ['dispute', ['The dispute was settled peacefully.', '這場爭議和平解決。']],
  ['communist', ['They discussed communist history in class.', '他們在課堂上討論共產主義歷史。']],
  ['sanction', ['The country faced a new sanction.', '該國面臨新的制裁。']],
  ['theme', ['The party had a beach theme.', '這場派對以海灘為主題。']],
  ['socialist', ['He joined a socialist party.', '他加入了一個社會主義政黨。']],
  ['commissioner', ['The commissioner announced new rules.', '專員宣布了新規定。']],
  ['ruling', ['The court issued a ruling yesterday.', '法院昨天作出裁決。']],
  ['medium', ['Email can be an effective communication medium.', '電子郵件可以是有效的溝通媒介。']],
  ['unique', ['Each child has a style that is unique.', '每個孩子都有獨特的風格。']],
  ['honest', ['Please be honest with me.', '請對我誠實。']],
  ['uniform', ['The school uniform is blue.', '這件校服是藍色的。']],
  ['honour', ['It was my honour to meet you.', '能見到你是我的榮幸。']],
  ['speaker', ['The speaker explained the plan clearly.', '講者清楚地說明了計畫。']],
  ['unpopular', ['The unpopular policy was changed.', '那項不得人心的政策被改變了。']],
  ['unbeaten', ['The unbeaten team reached the final.', '那支不敗球隊進入了決賽。']],
  ['undoubted', ['Her skill was undoubted.', '她的能力毫無疑問。']],
  ['trait', ['Patience is a valuable trait.', '耐心是一項寶貴特質。']],
  ['conjunction', ['Use a conjunction to join the clauses.', '用連接詞把子句連起來。']],
  ['install', ['Please install the app before class.', '請在上課前安裝這個應用程式。']],
  ['homeless', ['The city opened a shelter for homeless families.', '市政府為無家可歸的家庭開設了收容中心。']],
  ['homework', ['I finished my homework before dinner.', '我在晚餐前完成了作業。']],
  ['hometown', ['He visits his hometown every summer.', '他每年夏天都會回故鄉。']],
  ['whereas', ['I like tea, whereas my sister prefers coffee.', '我喜歡茶，而我妹妹比較喜歡咖啡。']],
  ['albeit', ['The room was small, albeit comfortable.', '房間雖小，但很舒適。']],
  ['thereby', ['The new rule saved time, thereby reducing stress.', '新規則節省了時間，因此減少了壓力。']],
  ['whereby', ['They created a system whereby students can ask questions online.', '他們建立了一套系統，讓學生可以在線上提問。']],
  ['provided', ['You can join the trip provided you sign up today.', '只要你今天報名，就可以參加這趟旅行。']],
  ['ourselves', ['We made the cake ourselves.', '我們自己做了這個蛋糕。']],
  ['beneath', ['The cat slept beneath the table.', '貓睡在桌子底下。']],
  ['quiz', ['The quiz has ten short questions.', '這份小考有十題簡短的題目。']],
  ['compound', ['Water is not a compound of oxygen alone.', '水不是只由氧組成的化合物。']],
  ['proportion', ['A large proportion of students chose English.', '很大比例的學生選擇了英文。']],
  ['optional', ['The final question is optional.', '最後一題是選答題。']],
  ['crow', ['The child watched the crow from the fence.', '孩子從圍欄旁看著那隻烏鴉。']],
  ['varied', ['The menu offers varied choices.', '菜單提供多樣化的選擇。']],
  ['ideological', ['The debate became ideological.', '這場辯論變得帶有意識形態色彩。']],
  ['bleed', ['His nose began to bleed.', '他的鼻子開始流血。']],
  ['insure', ['You should insure the car.', '你應該替這輛車投保。']],
  ['whatsoever', ['There was no doubt whatsoever.', '完全沒有任何疑問。']],
  ['enclose', ['Please enclose a copy of your passport.', '請附上一份護照影本。']],
  ['denounce', ['They denounce the violence publicly.', '他們公開譴責暴力。']],
  ['slash', ['The store will slash prices tomorrow.', '這家店明天會大幅降價。']],
  ['disguise', ['He tried to disguise his voice.', '他試著掩飾自己的聲音。']],
  ['repay', ['I will repay the loan next month.', '我下個月會償還貸款。']],
  ['consolidate', ['The company will consolidate its offices.', '公司將整合辦公室。']],
  ['envisage', ['Can you envisage a better future?', '你能想像更好的未來嗎？']],
  ['incidentally', ['Incidentally, I saw your brother yesterday.', '順便一提，我昨天看到你哥哥。']],
  ['migrate', ['Many birds migrate south in winter.', '許多鳥類冬天會往南遷徙。']],
  ['conquer', ['She hopes to conquer her fear.', '她希望克服恐懼。']],
  ['bloom', ['The flowers bloom in spring.', '花朵在春天盛開。']],
  ['erode', ['Rain can erode the soil.', '雨水會侵蝕土壤。']],
  ['pierce', ['The needle can pierce the cloth.', '針可以刺穿布料。']],
  ['dine', ['We will dine at the hotel tonight.', '我們今晚會在飯店用餐。']],
  ['aggregate', ['The system will aggregate the results.', '系統會彙整結果。']],
  ['adore', ['Children adore this cartoon.', '孩子們很喜愛這部卡通。']],
  ['commute', ['I commute by train every day.', '我每天搭火車通勤。']],
  ['misunderstand', ['Please do not misunderstand my question.', '請不要誤解我的問題。']],
  ['topple', ['Strong winds may topple the tree.', '強風可能會吹倒那棵樹。']],
  ['veto', ['The president may veto the bill.', '總統可能否決這項法案。']],
  ['mar', ['One stain can mar the dress.', '一個污漬就會破壞這件洋裝。']],
  ['unify', ['The song helped unify the crowd.', '這首歌幫助凝聚群眾。']],
  ['subsidize', ['The city will subsidize bus fares.', '市政府會補助公車票價。']],
  ['oust', ['Voters may oust the mayor.', '選民可能罷免市長。']],
  ['assassinate', ['The plot to assassinate the leader failed.', '刺殺領袖的陰謀失敗了。']],
  ['proliferate', ['Fake accounts can proliferate quickly.', '假帳號可能迅速增加。']],
  ['anymore', ['I do not live there anymore.', '我不再住那裡了。']],
  ['evidently', ['Evidently, the plan failed.', '顯然，這個計畫失敗了。']],
  ['sooner', ['The sooner we leave, the better.', '我們越早離開越好。']],
  ['devalue', ['Inflation can devalue savings.', '通貨膨脹會使存款貶值。']],
  ['reorganize', ['They will reorganize the office.', '他們會重新整理辦公室。']],
  ['pr', ['The company hired a PR team.', '公司聘請了一支公關團隊。']],
  ['rc', ['The RC car moved quickly.', '遙控車移動得很快。']],
  ['tempted', ['She felt tempted to buy the shoes.', '她很想買那雙鞋。']],
  ['even', ['Even children can understand this rule.', '連孩子都能理解這條規則。']],
  ['count', ['Please count the chairs.', '請數一數椅子。']],
  ['injure', ['Do not injure your back.', '不要傷到你的背。']],
  ['happily', ['The children played happily outside.', '孩子們在外面開心地玩。']],
  ['sew', ['She can sew a button.', '她會縫鈕扣。']],
  ['sideways', ['The sign was hanging sideways after the storm.', '暴風雨後，那個招牌歪向一邊掛著。']],
  ['complicate', ['Do not complicate the problem.', '不要把問題弄複雜。']],
  ['indoors', ['We stayed indoors during the storm.', '暴風雨期間我們待在室內。']],
  ['disappoint', ['I do not want to disappoint you.', '我不想讓你失望。']],
  ['annoy', ['Loud noise can annoy neighbors.', '噪音會惹惱鄰居。']],
  ['equally', ['The money was divided equally.', '錢被平均分配。']],
  ['privately', ['She spoke to him privately.', '她私下和他談話。']],
  ['comfortably', ['The room fits four people comfortably.', '這個房間能讓四個人舒服入住。']],
  ['calmly', ['She calmly answered the question.', '她冷靜地回答問題。']],
  ['harry', ['Debt collectors continued to harry him.', '討債人持續騷擾他。']],
  ['embody', ['This statue can embody hope.', '這座雕像能體現希望。']],
  ['activate', ['Press the button to activate the alarm.', '按下按鈕啟動警報。']],
  ['summarize', ['Please summarize the report.', '請概述這份報告。']],
  ['dangle', ['The keys dangle from her bag.', '鑰匙從她的包包上晃來晃去。']],
  ['broaden', ['Travel can broaden your mind.', '旅行能拓展你的視野。']],
  ['contradict', ['The facts contradict his story.', '事實與他的說法矛盾。']],
  ['devastate', ['The flood may devastate the village.', '洪水可能摧毀村莊。']],
  ['unlock', ['This key can unlock the gate.', '這把鑰匙能打開大門。']],
  ['elicit', ['The question may elicit honest answers.', '這個問題可能引出誠實的回答。']],
  ['hitherto', ['Hitherto, the plan has worked.', '到目前為止，這個計畫一直有效。']],
  ['collision', ['The collision damaged both cars.', '這次碰撞損壞了兩輛車。']],
  ['nationality', ['Please write your nationality on the form.', '請在表格上填寫你的國籍。']],
  ['bowling', ['We went bowling after dinner.', '我們晚餐後去打保齡球。']],
  ['secrecy', ['The plan was kept in secrecy.', '這個計畫被保密。']],
  ['fundamentalism', ['The book discusses religious fundamentalism.', '這本書討論宗教基要主義。']],
  ['garbage', ['Please take out the garbage tonight.', '今晚請把垃圾拿出去。']],
  ['spelling', ['Check the spelling before you send the email.', '寄出電子郵件前請檢查拼字。']],
  ['wrapping', ['The gift wrapping was bright red.', '禮物包裝是鮮紅色的。']],
  ['identification', ['You need identification to enter the building.', '你需要身分證明才能進入大樓。']],
  ['correlation', ['The study found a correlation between sleep and memory.', '研究發現睡眠和記憶之間有相關性。']],
  ['jurisdiction', ["This case is outside the court's jurisdiction.", '這個案件不在該法院的管轄權內。']],
  ['consistency', ['Her consistency helped the team trust her work.', '她的穩定表現讓團隊信任她的工作。']],
  ['repetition', ['Repetition can help you remember new words.', '重複能幫助你記住新單字。']],
  ['documentation', ['The project needs clear documentation.', '這個專案需要清楚的文件。']],
  ['undertaking', ['Building the bridge was a major undertaking.', '建造這座橋是一項重大工程。']],
  ['fusion', ['Jazz fusion mixes jazz with other styles.', '爵士融合樂把爵士和其他風格混合在一起。']],
  ['proximity', ['The house is popular because of its proximity to the station.', '這棟房子受歡迎是因為它靠近車站。']],
  ['nuisance', ['The broken alarm became a nuisance.', '壞掉的警報器成了麻煩。']],
  ['quotation', ['She used a quotation from the poem.', '她引用了那首詩中的一句話。']],
  ['diversion', ['The road diversion added twenty minutes to the trip.', '道路改道讓行程多花了二十分鐘。']],
  ['comprehension', ['Reading improves comprehension.', '閱讀能提升理解力。']],
  ['intrusion', ['The loud noise was an intrusion into our quiet evening.', '那陣噪音打擾了我們安靜的夜晚。']],
  ['outgoing', ['She has an outgoing personality.', '她個性外向。']],
  ['antiquity', ['The vase dates from antiquity.', '這個花瓶可追溯到古代。']],
  ['sophistication', ['The design shows great sophistication.', '這個設計展現出高度精緻感。']],
  ['mythology', ['Greek mythology includes many famous gods.', '希臘神話包含許多著名的神。']],
  ['constellation', ['Orion is a well-known constellation.', '獵戶座是著名的星座。']],
  ['solitude', ['He enjoyed the solitude of the mountains.', '他喜歡山中的獨處。']],
  ['avoidance', ['Avoidance will not solve the problem.', '逃避無法解決問題。']],
  ['demolish', ['Workers will demolish the old wall.', '工人會拆除那面舊牆。']],
  ['subscribe', ['I subscribe to this magazine.', '我訂閱這本雜誌。']],
  ['cram', ['Do not cram for the exam tonight.', '今晚不要臨時抱佛腳準備考試。']],
  ['equate', ['Do not equate price with quality.', '不要把價格和品質畫上等號。']],
  ['impair', ['Lack of sleep can impair judgment.', '睡眠不足會損害判斷力。']],
  ['alleviate', ['This medicine can alleviate pain.', '這種藥可以減輕疼痛。']],
  ['syllable', ['Each syllable has a clear sound.', '每個音節都有清楚的聲音。']],
  ['implicate', ['The evidence may implicate him.', '證據可能牽連到他。']],
  ['simplify', ['Please simplify the instructions.', '請簡化說明。']],
  ['whichever', ['Choose whichever seat you like.', '選你喜歡的任何座位。']],
  ['validate', ['The test can validate the result.', '這項測試可以驗證結果。']],
  ['plainly', ['She explained the rule plainly.', '她清楚地解釋了規則。']],
  ['converge', ['The paths converge near the river.', '這些小路在河邊會合。']],
  ['perpetuate', ['Repeating rumors can perpetuate harm.', '重複謠言可能延續傷害。']],
  ['despise', ['Do not despise small efforts.', '不要輕視小小的努力。']],
  ['mislead', ['False labels can mislead customers.', '錯誤標示可能誤導顧客。']],
  ['defer', ['We should defer the decision.', '我們應該延後決定。']],
  ['simulate', ['The program can simulate traffic.', '這個程式可以模擬交通。']],
  ['beware', ['Beware of wet floors.', '小心濕滑地板。']],
  ['sever', ['The storm may sever power lines.', '暴風雨可能切斷電線。']],
  ['augment', ['Extra training can augment his skills.', '額外訓練能增強他的技能。']],
  ['redeem', ['You can redeem this coupon today.', '你今天可以兌換這張優惠券。']],
]);

const englishTailCleanups = [
  /,\s*because the added context made the meaning clearer for learners\.$/i,
  /,\s*which made the sentence feel more realistic and easier to remember\.$/i,
  /,\s*and that small detail made the sentence less mechanical\.$/i,
  /,\s*and the extra detail made the example sound more natural\.$/i,
  /,\s*after the teacher asked for a fuller and more natural sentence\.$/i,
  /,\s*while still keeping the main meaning easy to follow\.$/i,
  /,\s*because one overlooked detail can affect the whole result\.$/i,
  /,\s*but the detail became important later in the discussion\.$/i,
  /,\s*and someone asked a follow-up question a few minutes later\.$/i,
  /,\s*so someone asked a follow-up question a few minutes later\.$/i,
  /,\s*and people noticed the detail immediately\.$/i,
  /,\s*so the detail became important later in the discussion\.$/i,
  /,\s*but everyone knew where to find it the next morning\.$/i,
  /,\s*and everyone noticed the flavor before the meal was over\.$/i,
  /,\s*and it had a beautiful view of the river\.$/i,
  /,\s*and the situation felt more realistic after that\.$/i,
  /,\s*and people remembered the moment because it changed the plan\.$/i,
  /,\s*so people remembered the moment because it changed the plan\.$/i,
  /,\s*but people remembered the moment because it changed the plan\.$/i,
  /,\s*and the group wrote it down before anyone forgot\.$/i,
  /,\s*and the detail became important later in the discussion\.$/i,
  /,\s*but the detail became important later in the discussion\.$/i,
  /,\s*and the cook made one final adjustment before serving it\.$/i,
  /,\s*but the cook made one final adjustment before serving it\.$/i,
  /,\s*but someone asked a follow-up question a few minutes later\.$/i,
  /,\s*so the cook made one final adjustment before serving it\.$/i,
];

const chineseTailCleanups = [
  /，因為加入脈絡後，意思對學習者更清楚。$/u,
  /，這讓句子更有真實感，也更容易記住。$/u,
  /，而這個小細節讓句子比較不機械。$/u,
  /，而額外細節讓例句聽起來更自然。$/u,
  /，因為老師要求寫得更完整也更自然。$/u,
  /，同時仍保留容易理解的主要意思。$/u,
  /，因為一個被忽略的細節可能影響整個結果。$/u,
  /，但是這個細節在後續討論中變得重要。$/u,
  /，而且幾分鐘後有人提出了追問。$/u,
  /，所以幾分鐘後有人提出了追問。$/u,
  /，而且人們立刻注意到這個細節。$/u,
  /，所以這個細節在後續討論中變得重要。$/u,
  /，但大家第二天早上都知道去哪裡找它。$/u,
  /，而且大家在用餐結束前都注意到味道。$/u,
  /，而且房間可以看到美麗河景。$/u,
  /，而且那種情境之後感覺更真實。$/u,
  /，而且人們記得那一刻，因為它改變了計畫。$/u,
  /，所以人們記得那一刻，因為它改變了計畫。$/u,
  /，但是人們記得那一刻，因為它改變了計畫。$/u,
  /，而且小組在有人忘記前把它寫了下來。$/u,
  /，而且這個細節在後續討論中變得重要。$/u,
  /，但是這個細節在後續討論中變得重要。$/u,
  /，而且廚師在上菜前做了最後一次調整。$/u,
  /，但是廚師在上菜前做了最後一次調整。$/u,
  /，但是幾分鐘後有人提出了追問。$/u,
  /，所以廚師在上菜前做了最後一次調整。$/u,
];

const englishPrefixCleanups = [
  /^After the situation changed unexpectedly,\s*/i,
  /^Although the situation changed unexpectedly,\s*/i,
  /^After the answer was not obvious at first,\s*/i,
  /^Although the answer was not obvious at first,\s*/i,
  /^After everyone looked at the details again,\s*/i,
  /^Although everyone looked at the details again,\s*/i,
  /^After the group discussed the matter for a while,\s*/i,
  /^Although the group discussed the matter for a while,\s*/i,
  /^After someone asked for a more concrete example,\s*/i,
];

const chinesePrefixCleanups = [
  /^在情況意外改變之後，/u,
  /^雖然情況意外改變，/u,
  /^在答案一開始並不明顯之後，/u,
  /^雖然答案一開始並不明顯，/u,
  /^在大家再次查看細節之後，/u,
  /^雖然大家再次查看細節，/u,
  /^在小組討論這件事一陣子之後，/u,
  /^雖然小組討論這件事一陣子，/u,
  /^在有人要求一個更具體的例子之後，/u,
];

function escapeRegex(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

function normalizeSentence(value) {
  return value.trim().replace(/\s+/g, ' ');
}

function polishEnglishSentence(value) {
  const normalized = normalizeSentence(value)
    .replace(/\bi\b/g, 'I')
    .replace(/\bi'm\b/gi, "I'm")
    .replace(/\bi've\b/gi, "I've");
  return normalized.charAt(0).toUpperCase() + normalized.slice(1);
}

function isLowQualityGeneratedFrame(example, exampleZh) {
  const combined = `${example} ${exampleZh}`;
  return (
    /\b(the word|this example|the example showed|works in context|remember the word|simple example|learner|meaning clearer|complete sentence|long definition|familiar idea)\b/i.test(
      combined,
    ) ||
    /^(A simple example|Her notes on|The article on|This problem is|The class returned to|The writer chose|The example showed)\b/i.test(
      example,
    ) ||
    /^The word .+ sounded informal/i.test(example) ||
    /(這個例句|這個單字|這個字聽起來|關於.+的筆記|的的)/u.test(exampleZh)
  );
}

function cleanGeneratedRow(row, expectedItem) {
  let example = normalizeSentence(row.example ?? '');
  let exampleZh = normalizeSentence(row.exampleZh ?? '');

  if (/,\s*which helped the class understand how the word works in context\.$/i.test(example)) {
    example = example.replace(/,\s*which helped the class understand how the word works in context\.$/i, '.');
    exampleZh = exampleZh.replace(/，這幫助[^。]*。?$/u, '。');
  }
  for (const pattern of englishTailCleanups) {
    example = example.replace(pattern, '.');
  }
  for (const pattern of chineseTailCleanups) {
    exampleZh = exampleZh.replace(pattern, '。');
  }
  for (const pattern of englishPrefixCleanups) {
    example = example.replace(pattern, '');
  }
  for (const pattern of chinesePrefixCleanups) {
    exampleZh = exampleZh.replace(pattern, '');
  }
  example = polishEnglishSentence(example);
  exampleZh = normalizeSentence(exampleZh);

  const normalizedWord = row.word?.trim().toLowerCase() ?? '';
  const override = manualOverrides.get(normalizedWord);
  if (override) {
    [example, exampleZh] = override;
  } else if (expectedItem && isLowQualityGeneratedFrame(example, exampleZh)) {
    example = normalizeSentence(expectedItem.currentExample);
    exampleZh = normalizeSentence(expectedItem.currentExampleZh);
  }

  return {
    word: normalizedWord,
    example,
    exampleZh,
    status: 'approved',
    batch: row.batch?.trim() || 'gpt-review-core4-14-2026-07-02',
  };
}

function exampleFrame(row) {
  return row.example
    .toLowerCase()
    .replace(new RegExp(`(^|[^a-z])${escapeRegex(row.word)}([^a-z]|$)`, 'gi'), '$1{word}$2');
}

function diversifyRepeatedFrames(rows, expectedByWord) {
  let diversifiedRows = rows;

  for (let pass = 0; pass < 5; pass += 1) {
    const frameIndexes = new Map();
    for (const [index, row] of diversifiedRows.entries()) {
      const frame = exampleFrame(row);
      const indexes = frameIndexes.get(frame) ?? [];
      indexes.push(index);
      frameIndexes.set(frame, indexes);
    }

    const repeatedFrames = Array.from(frameIndexes.entries()).filter(([, indexes]) => indexes.length > 35);
    if (repeatedFrames.length === 0) {
      return diversifiedRows;
    }

    let changed = false;
    diversifiedRows = diversifiedRows.map((row) => ({ ...row }));

    for (const [, indexes] of repeatedFrames) {
      for (const index of indexes.slice(35)) {
        const row = diversifiedRows[index];
        if (manualOverrides.has(row.word)) {
          continue;
        }
        const expectedItem = expectedByWord.get(row.word);
        if (!expectedItem) {
          continue;
        }
        const fallbackExample = normalizeSentence(expectedItem.currentExample);
        const fallbackExampleZh = normalizeSentence(expectedItem.currentExampleZh);
        if (row.example !== fallbackExample || row.exampleZh !== fallbackExampleZh) {
          diversifiedRows[index] = {
            ...row,
            example: fallbackExample,
            exampleZh: fallbackExampleZh,
          };
          changed = true;
        }
      }
    }

    if (!changed) {
      return diversifiedRows;
    }
  }

  return diversifiedRows;
}

function validateRows(rows, expectedItems) {
  const errors = [];
  const expectedByWord = new Map(expectedItems.map((item) => [item.word, item]));
  const expectedWords = new Set(expectedByWord.keys());
  const seen = new Set();

  for (const row of rows) {
    if (!expectedWords.has(row.word)) {
      errors.push(`Unexpected word: ${row.word}`);
    }
    if (seen.has(row.word)) {
      errors.push(`Duplicate word: ${row.word}`);
    }
    seen.add(row.word);

    if (!row.word || !row.example || !row.exampleZh || row.status !== 'approved' || !row.batch) {
      errors.push(`Missing required field: ${row.word || '(blank)'}`);
      continue;
    }

    const wordPattern = new RegExp(`(^|[^a-z])${escapeRegex(row.word)}([^a-z]|$)`, 'i');
    if (!wordPattern.test(row.example)) {
      errors.push(`Example does not contain exact word: ${row.word} -> ${row.example}`);
    }
    if (/[\u4e00-\u9fff]/.test(row.example)) {
      errors.push(`English example contains Chinese text: ${row.word}`);
    }
    if (!/[\u4e00-\u9fff]/.test(row.exampleZh)) {
      errors.push(`Chinese translation has no Chinese text: ${row.word}`);
    }
    if (
      /\b(the word|this example|the example showed|works in context|remember the word|simple example|learner|meaning clearer|complete sentence|long definition|familiar idea)\b/i.test(
        row.example,
      )
    ) {
      errors.push(`Meta example wording remains: ${row.word} -> ${row.example}`);
    }
    if (
      /(這個例句|這個單字|這個字聽起來|幫助.*(理解|了解).*(字|單字|語境|脈絡|上下文|用法)|關於.+的筆記|的的|辯論的)/u.test(
        row.exampleZh,
      )
    ) {
      errors.push(`Meta Chinese wording remains: ${row.word} -> ${row.exampleZh}`);
    }
    if (/^(A simple example|Her notes on|This problem is|The class returned to|The writer chose|The example showed)\b/i.test(row.example)) {
      errors.push(`Awkward generated frame remains: ${row.word} -> ${row.example}`);
    }
  }

  for (const expected of expectedItems) {
    if (!seen.has(expected.word)) {
      errors.push(`Missing expected word: ${expected.word}`);
    }
  }

  const frameCounts = new Map();
  for (const row of rows) {
    const frame = exampleFrame(row);
    frameCounts.set(frame, (frameCounts.get(frame) ?? 0) + 1);
  }
  for (const [frame, count] of frameCounts) {
    if (count > 35) {
      errors.push(`Repeated example frame remains (${count}): ${frame}`);
    }
  }

  return errors;
}

const expectedItems = JSON.parse(fs.readFileSync(expectedPath, 'utf8')).items.filter((item) =>
  targetLevels.includes(Number(item.group.replace('Core ', ''))),
);
const expectedByWordForImport = new Map(expectedItems.map((item) => [item.word, item]));

const sourceFiles = fs
  .readdirSync(sourceDir)
  .filter((filename) => /^core\d{2}_.*\.json$/.test(filename))
  .sort();

const importedRows = diversifyRepeatedFrames(
  sourceFiles.flatMap((filename) => {
    const rows = JSON.parse(fs.readFileSync(path.join(sourceDir, filename), 'utf8'));
    if (!Array.isArray(rows)) {
      throw new Error(`GPT review file must be an array: ${filename}`);
    }
    return rows.map((row) => cleanGeneratedRow(row, expectedByWordForImport.get(row.word?.trim().toLowerCase())));
  }),
  expectedByWordForImport,
);

const validationErrors = validateRows(importedRows, expectedItems);
if (validationErrors.length > 0) {
  console.error(validationErrors.slice(0, 80).join('\n'));
  throw new Error(`GPT reviewed examples failed validation: ${validationErrors.length} issue(s)`);
}

for (const level of targetLevels) {
  const group = `Core ${level}`;
  const expectedWordsForLevel = new Set(expectedItems.filter((item) => item.group === group).map((item) => item.word));
  const rowsForLevel = importedRows.filter((row) => expectedWordsForLevel.has(row.word));
  const outputPath = path.join(dataDir, `reviewed-examples-core${level}.json`);

  fs.writeFileSync(`${outputPath}`, `${JSON.stringify(rowsForLevel, null, 2)}\n`, 'utf8');
  console.log(`Imported ${rowsForLevel.length} rows -> ${outputPath}`);
}

console.log(`Imported ${importedRows.length} GPT reviewed examples.`);
