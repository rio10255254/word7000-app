import { describe, expect, test } from 'vitest';
import reviewedExamples from './reviewed-examples.json';
import reviewedExamplesCore2A from './reviewed-examples-core2-a.json';
import reviewedExamplesCore2B from './reviewed-examples-core2-b.json';
import reviewedExamplesCore2C from './reviewed-examples-core2-c.json';
import reviewedExamplesCore3A from './reviewed-examples-core3-a.json';
import reviewedExamplesCore3B from './reviewed-examples-core3-b.json';
import reviewedExamplesCore3C from './reviewed-examples-core3-c.json';
import reviewedExamplesCore3D from './reviewed-examples-core3-d.json';
import { sampleWords } from './words';

const allReviewedExamples = [
  ...reviewedExamples,
  ...reviewedExamplesCore2A,
  ...reviewedExamplesCore2B,
  ...reviewedExamplesCore2C,
  ...reviewedExamplesCore3A,
  ...reviewedExamplesCore3B,
  ...reviewedExamplesCore3C,
  ...reviewedExamplesCore3D,
];

describe('full vocabulary dataset', () => {
  test('contains exactly 7000 app-ready words', () => {
    expect(sampleWords).toHaveLength(7000);
  });

  test('is split into 14 complete 500-word levels', () => {
    const groupCounts = sampleWords.reduce<Record<string, number>>((counts, word) => {
      counts[word.group] = (counts[word.group] ?? 0) + 1;
      return counts;
    }, {});

    expect(Object.keys(groupCounts)).toHaveLength(14);
    for (let level = 1; level <= 14; level += 1) {
      expect(groupCounts[`Core ${level}`]).toBe(500);
    }
  });

  test('uses unique ids and unique lowercase words', () => {
    const ids = new Set(sampleWords.map((word) => word.id));
    const words = new Set(sampleWords.map((word) => word.word.toLowerCase()));

    expect(ids.size).toBe(sampleWords.length);
    expect(words.size).toBe(sampleWords.length);
  });

  test('has complete fields for every word', () => {
    const incomplete = sampleWords.filter(
      (word) =>
        !word.id.trim() ||
        !word.word.trim() ||
        !word.partOfSpeech.trim() ||
        !word.pronunciation.trim() ||
        !word.meaningZh.trim() ||
        !word.example.trim() ||
        !word.exampleZh.trim() ||
        !word.group.trim(),
    );

    expect(incomplete).toEqual([]);
  });

  test('applies approved reviewed examples to the built-in vocabulary', () => {
    const approvedRows = allReviewedExamples.filter((row) => row.status === 'approved');
    const seenWords = new Set<string>();

    for (const row of approvedRows) {
      expect(row.word.trim()).not.toBe('');
      expect(row.example.trim()).not.toBe('');
      expect(row.exampleZh.trim()).not.toBe('');
      expect(seenWords.has(row.word)).toBe(false);
      seenWords.add(row.word);

      const entry = sampleWords.find((word) => word.word === row.word);
      expect(entry).toMatchObject({
        example: row.example,
        exampleZh: row.exampleZh,
      });
    }
  });

  test('has approved reviewed examples for every Core 1 word', () => {
    const approvedWords = new Set(allReviewedExamples.filter((row) => row.status === 'approved').map((row) => row.word));
    const missingReviewedExamples = sampleWords.filter((word) => word.group === 'Core 1' && !approvedWords.has(word.word));

    expect(missingReviewedExamples.map((word) => word.word)).toEqual([]);
  });

  test('has approved reviewed examples for every Core 2 word', () => {
    const approvedWords = new Set(allReviewedExamples.filter((row) => row.status === 'approved').map((row) => row.word));
    const missingReviewedExamples = sampleWords.filter((word) => word.group === 'Core 2' && !approvedWords.has(word.word));

    expect(missingReviewedExamples.map((word) => word.word)).toEqual([]);
  });

  test('has approved reviewed examples for every Core 3 word', () => {
    const approvedWords = new Set(allReviewedExamples.filter((row) => row.status === 'approved').map((row) => row.word));
    const missingReviewedExamples = sampleWords.filter((word) => word.group === 'Core 3' && !approvedWords.has(word.word));

    expect(missingReviewedExamples.map((word) => word.word)).toEqual([]);
  });

  test('uses sentence examples instead of dictionary placeholder text', () => {
    const placeholderExamples = sampleWords.filter(
      (word) =>
        word.example.startsWith(`Review "${word.word}" with this meaning:`) ||
        word.exampleZh === `「${word.word}」：${word.meaningZh}`,
    );

    expect(placeholderExamples.slice(0, 20).map((word) => word.word)).toEqual([]);
  });

  test('uses contextual examples instead of meta-learning templates', () => {
    const metaPatterns = [
      /\bthe word\b/i,
      /\bsimple (sentence|example)\b/i,
      /\blearner/i,
      /\bcan show how\b/i,
      /\bpractical context\b/i,
      /\bmeaning clearer\b/i,
      /\bcomplete sentence\b/i,
      /\blong definition\b/i,
      /\bfamiliar idea\b/i,
    ];
    const metaExamples = sampleWords.filter((word) =>
      metaPatterns.some((pattern) => pattern.test(`${word.example} ${word.exampleZh}`)),
    );

    expect(metaExamples.slice(0, 20).map((word) => word.word)).toEqual([]);
  });

  test('keeps generated example frames varied across the full dataset', () => {
    const frameCounts = new Map<string, number>();

    for (const word of sampleWords) {
      const frame = word.example.toLowerCase().replaceAll(word.word.toLowerCase(), '{word}');
      frameCounts.set(frame, (frameCounts.get(frame) ?? 0) + 1);
    }

    const repeatedFrames = Array.from(frameCounts.entries())
      .filter(([, count]) => count > 35)
      .sort((a, b) => b[1] - a[1]);

    expect(repeatedFrames.slice(0, 10)).toEqual([]);
  });

  test('does not keep awkward generated scaffolding in examples or translations', () => {
    const awkwardPatterns = [
      /A note about [a-z]+ helped/i,
      /The report mentioned [a-z]+ before/i,
      /became important after/i,
      /pointed [a-z]+ the main entrance/i,
      /with a clear [a-z]+ during/i,
      /關於.+的筆記/,
      /標誌指向與.+相關/,
      /幫助處理/,
      /用清楚的.+於/,
    ];
    const awkwardExamples = sampleWords.filter((word) =>
      awkwardPatterns.some((pattern) => pattern.test(`${word.example} ${word.exampleZh}`)),
    );

    expect(awkwardExamples.slice(0, 20).map((word) => `${word.word}: ${word.example} / ${word.exampleZh}`)).toEqual([]);
  });

  test('does not keep high-risk generic examples that often produce unreasonable meanings', () => {
    const highRiskPatterns = [
      /\bexplained the [a-z]+ after the (meeting|lesson|interview|workshop|trip|review|practice|discussion|training|visit|trial|festival|inspection|presentation|debate|rehearsal)\b/i,
      /\btreated the [a-z]+ as important\b/i,
      /\bwas easy to find in the\b/i,
      /\bnoticed an? [a-z]+ detail in the\b/i,
      /\bhelped us [a-z]+ the next step\b/i,
      /\bPlease [a-z]+ the (plan|report|schedule|project|message|lesson|file|room|budget|map|letter|ticket|device|garden|contract|display) carefully\b/i,
      /在.+後說明了/,
      /視為重要/,
      /裡很容易找到/,
      /幫助我們.+下一步/,
    ];
    const highRiskExamples = sampleWords.filter((word) =>
      highRiskPatterns.some((pattern) => pattern.test(`${word.example} ${word.exampleZh}`)),
    );

    expect(highRiskExamples.slice(0, 40).map((word) => `${word.word}: ${word.example} / ${word.exampleZh}`)).toEqual([]);
  });

  test('does not keep broad generator scaffolds that read like stitched templates', () => {
    const broadTemplatePatterns = [
      /\bsaved the [a-z]+ for the final\b/i,
      /\bstudied [a-z]+ during the\b/i,
      /\bbecame a sign of the season\b/i,
      /\bwaited beside the [a-z]+ after\b/i,
      /\bmade [a-z]+ easier to discuss\b/i,
      /^The [a-z]+ changed after the (meeting|lesson|interview|workshop|trip|review|practice|discussion|training|visit|trial|festival|inspection|presentation|debate|rehearsal)\b/i,
      /\breached the office before\b/i,
      /\banswered questions after the\b/i,
      /\blearned how to [a-z]+ it after\b/i,
      /\bphotographed the [a-z]+ at sunrise\b/i,
      /\bannounced a new (room|display|budget|contract|garden|device|ticket|file|lesson|project|plan)\b/i,
      /\bwill [a-z]+ after the\b/i,
      /\bmay [a-z]+ after the\b/i,
      /把那段.+留給最後/,
      /在.+中學習/,
      /成了.+附近的季節象徵/,
      /在.+後於.+旁等待/,
      /讓.+在.+前更容易被討論/,
    ];
    const broadTemplateExamples = sampleWords.filter((word) =>
      broadTemplatePatterns.some((pattern) => pattern.test(`${word.example} ${word.exampleZh}`)),
    );

    expect(broadTemplateExamples.slice(0, 60).map((word) => `${word.word}: ${word.example} / ${word.exampleZh}`)).toEqual([]);
  });

  test('does not keep generic part-case-result frames from the generator', () => {
    const genericFramePatterns = [
      /\bnoticed an? [a-z]+ part of the\b/i,
      /\bfound the [a-z]+ case difficult to explain\b/i,
      /\bAn? [a-z]+ result changed the [a-z]+ before\b/i,
      /\basked (briefly|carefully|clearly|openly|quietly|together) about [a-z]+ during the\b/i,
      /\btalked (briefly|carefully|clearly|openly|quietly|together) about [a-z]+ during the\b/i,
    ];
    const genericFrameExamples = sampleWords.filter((word) =>
      genericFramePatterns.some((pattern) => pattern.test(`${word.example} ${word.exampleZh}`)),
    );

    expect(genericFrameExamples.slice(0, 80).map((word) => `${word.word}: ${word.example} / ${word.exampleZh}`)).toEqual([]);
  });

  test('does not keep sampled semantic mismatches from generated examples', () => {
    const semanticMismatchPatterns = [
      /\bvisited the visit\b/i,
      /\bThe road to the (drop|lift)\b/i,
      /\bThe (pattern|schedule) began to (attend|submit)\b/i,
      /\bThe answer sounded clearer neither\b/i,
      /\bShe moved admittedly through\b/i,
      /\bThe [a-z]+ will prosper a new\b/i,
      /\bThe kitchen smelled of (parasite|butcher|brandy)\b/i,
      /\bThe (brandy|butcher) tasted fresh after\b/i,
      /\bThe (forty|thirty|twenty|fifteen|twelve|ten|nine|eight|seven|six|five|four|three|two) answer was\b/i,
      /\bThe (size|essence|log) (felt smooth|stood out)\b/i,
      /\bA (glowing|vibrant) (choice|question)\b/i,
      /\b[Aa] [a-z]+ color made\b/i,
      /\bShe chose an? [a-z]+ option before\b/i,
      /\bThe [a-z]+ detail stood out\b/i,
      /\bThe [a-z]+ design caught\b/i,
      /\bThe [a-z]+ stood out in the (ticket|plan)\b/i,
      /\bThe answer sounded clearer\b/i,
      /\bThe message changed slightly after\b/i,
      /\bThe sentence felt natural with\b/i,
      /\bThe team used [a-z]+ to connect\b/i,
      /\bHe listened particularly\b/i,
      /\banswered extremely\b/i,
      /\bworked plainly through\b/i,
      /\battend the schedule\b/i,
      /\bmarry the project\b/i,
      /\bThe drink tasted fresh\b/i,
      /\bStudents explored artist\b/i,
      /鑰匙在.+在(之上|下面|裡面|外面|以內|後面)/,
    ];
    const semanticMismatches = sampleWords.filter((word) =>
      semanticMismatchPatterns.some((pattern) => pattern.test(`${word.example} ${word.exampleZh}`)),
    );

    expect(semanticMismatches.slice(0, 40).map((word) => `${word.word}: ${word.example} / ${word.exampleZh}`)).toEqual([]);
  });

  test('keeps Core 1 free of obvious template-generated example sentences', () => {
    const templatePatterns = [
      /\bincludes an? [a-z]+ for the\b/i,
      /\bclear example of [a-z]+ during\b/i,
      /\bchanged its plan before\b/i,
      /\basked about [a-z]+ before\b/i,
      /\bcontacted the [a-z]+ after\b/i,
      /\bvisited the [a-z]+ before\b/i,
      /\bShe gave an? [a-z]+ (answer|question|route|pattern|method) before\b/i,
      /\bThe [a-z]+ rule helped\b/i,
      /\bAn? [a-z]+ choice changed\b/i,
      /\bmay [a-z]+ before\b/i,
      /\bThe [a-z]+ will (let|lose|remove|imagine|withdraw) before\b/i,
      /\bWe discussed [a-z]+ in the .* before\b/i,
      /\bconnected [a-z]+ with daily life\b/i,
      /\bbegan to [a-z]+ during\b/i,
      /\bThe [a-z]+ (schedule|record|signal|habit|example|design) was easy to notice\b/i,
      /\brepaired the [a-z]+ before\b/i,
      /\bchecked the (year|day|thought|rise) before\b/i,
      /\bThe bus may (think|fail)\b/i,
      /\bThe (people|staff|security) answered questions after\b/i,
      /\bA map near .* marked the (give|wall)\b/i,
      /\bThe very meeting\b/i,
      /\bmade thing easier to discuss\b/i,
      /\btell the room\b/i,
      /\btable was made of drug\b/i,
      /\bhospital made the discussion difficult\b/i,
      /\bsaved the season\b/i,
      /\bclearer (soon|rather) the final edit\b/i,
      /\baccept the room after\b/i,
      /\btrade changed after the rehearsal\b/i,
      /\bA central room gave us space\b/i,
      /\bwaited beside the stage\b/i,
      /\bseek the message after\b/i,
      /\bfuture passed faster\b/i,
      /\bchose film for the new design\b/i,
      /\bplant became a sign of the season near the schedule\b/i,
      /\breduce the oil before\b/i,
      /\bA small claim changed the final price\b/i,
      /\bwith herself in the middle\b/i,
      /\beconomy covered the cost of the room\b/i,
      /\bwest changed after the review\b/i,
      /\bThe near road\b/i,
      /\bphotographed the east at sunrise\b/i,
      /\bmade design easier to discuss\b/i,
    ];
    const templateExamples = sampleWords.filter(
      (word) =>
        word.group === 'Core 1' &&
        templatePatterns.some((pattern) => pattern.test(`${word.example} ${word.exampleZh}`)),
    );

    expect(templateExamples.slice(0, 30).map((word) => `${word.word}: ${word.example} / ${word.exampleZh}`)).toEqual([]);
  });

  test('uses polished examples for words that exposed machine-generated phrasing', () => {
    const expectedExamples = new Map([
      ['first', ['First, read the question carefully.', '首先，仔細閱讀題目。']],
      ['share', ['She owns a small share of the company.', '她擁有那家公司的一小部分股份。']],
      ['install', ['Please install the app before class.', '請在上課前安裝這個應用程式。']],
      ['homeless', ['The city opened a shelter for homeless families.', '市政府為無家可歸的家庭開設了收容中心。']],
      ['homework', ['I finished my homework before dinner.', '我在晚餐前完成了作業。']],
      ['hometown', ['He visits his hometown every summer.', '他每年夏天都會回故鄉。']],
      ['suit', ['This dark suit is for formal meetings.', '這套深色西裝適合正式會議。']],
      ['object', ['A small object was lying under the chair.', '椅子下方有一個小物品。']],
      ['whereas', ['I like tea, whereas my sister prefers coffee.', '我喜歡茶，而我妹妹比較喜歡咖啡。']],
      ['albeit', ['The room was small, albeit comfortable.', '房間雖小，但很舒適。']],
      ['thereby', ['The new rule saved time, thereby reducing stress.', '新規則節省了時間，因此減少了壓力。']],
      ['whereby', ['They created a system whereby students can ask questions online.', '他們建立了一套系統，讓學生可以在線上提問。']],
      ['provided', ['You can join the trip provided you sign up today.', '只要你今天報名，就可以參加這趟旅行。']],
      ['ourselves', ['We made the cake ourselves.', '我們自己做了這個蛋糕。']],
      ['beneath', ['The cat slept beneath the table.', '貓睡在桌子底下。']],
      ['sideways', ['The sign was hanging sideways after the storm.', '暴風雨後，那個招牌歪向一邊掛著。']],
      ['option', ['The cheapest option is not always the best.', '最便宜的選項不一定總是最好的。']],
      ['quiz', ['The quiz has ten short questions.', '這份小考有十題簡短的題目。']],
      ['operation', ['The operation of the machine is simple.', '這台機器的操作很簡單。']],
      ['compound', ['Water is not a compound of oxygen alone.', '水不是只由氧組成的化合物。']],
      ['proportion', ['A large proportion of students chose English.', '很大比例的學生選擇了英文。']],
      ['optional', ['The final question is optional.', '最後一題是選答題。']],
      ['crow', ['The child watched the crow from the fence.', '孩子從圍欄旁看著那隻烏鴉。']],
      ['serious', ['This is a serious problem.', '這是一個嚴重的問題。']],
      ['acid', ['The scientist handled the acid carefully.', '科學家小心處理酸液。']],
      ['cinema', ['We met outside the cinema.', '我們在電影院外面見面。']],
      ['belly', ['The child had a pain in his belly.', '那個孩子肚子痛。']],
      ['variable', ['The result depends on one variable.', '結果取決於一個變數。']],
      ['probability', ['The probability of rain is high today.', '今天下雨的機率很高。']],
      ['credible', ['Her story sounded credible.', '她的說法聽起來可信。']],
      ['combined', ['The combined score was higher than expected.', '合併後的分數比預期高。']],
      ['thousand', ['About a thousand people attended the concert.', '大約一千人參加了音樂會。']],
      ['modern', ['Modern phones can take excellent photos.', '現代手機可以拍出很棒的照片。']],
      ['afternoon', ['I will call you this afternoon.', '我今天下午會打電話給你。']],
      ['insurance', ['Car insurance can be expensive.', '汽車保險可能很貴。']],
      ['complex', ['The instructions were too complex.', '這些說明太複雜了。']],
      ['schedule', ['The schedule changed yesterday.', '時程昨天改變了。']],
      ['fellow', ['He is a fellow student in my class.', '他是我班上的同學。']],
      ['interested', ['She is interested in history.', '她對歷史感興趣。']],
      ['settlement', ['The two sides reached a settlement.', '雙方達成了和解。']],
      ['voter', ['Each voter received a paper ballot.', '每位選民都拿到一張紙本選票。']],
      ['inflation', ['Inflation raised the price of food.', '通貨膨脹推高了食物價格。']],
      ['tradition', ['This tradition is over one hundred years old.', '這項傳統已有一百多年歷史。']],
      ['layer', ['Add another layer of paint.', '再加一層油漆。']],
      ['inquiry', ['The inquiry began on Monday.', '調查在星期一開始。']],
      ['behalf', ['I signed the form on her behalf.', '我代表她簽了表格。']],
      ['missile', ['The missile landed in the sea.', '飛彈落入海中。']],
      ['teenager', ['The teenager waited for the bus.', '那名青少年等著公車。']],
      ['naked', ['The baby was naked after the bath.', '寶寶洗完澡後光著身子。']],
      ['gasoline', ['The car ran out of gasoline.', '車子沒汽油了。']],
      ['passing', ['A passing car splashed water on us.', '一輛經過的車把水濺到我們身上。']],
      ['herb', ['A fresh herb grew by the kitchen window.', '一株新鮮香草長在廚房窗邊。']],
      ['spine', ['She injured her spine in the accident.', '她在事故中傷到了脊椎。']],
      ['crude', ['The crude oil was stored in large tanks.', '原油被儲存在大型油槽中。']],
      ['pork', ['She cooked pork for dinner.', '她晚餐煮了豬肉。']],
      ['spy', ['The spy sent a secret message.', '間諜送出了一則秘密訊息。']],
      ['presume', ['I presume the meeting is still on.', '我推測會議仍會照常舉行。']],
      ['fatigue', ['Fatigue made it hard to concentrate.', '疲勞讓人難以集中注意力。']],
      ['picnic', ['We had a picnic by the lake.', '我們在湖邊野餐。']],
      ['compliment', ['She smiled at the compliment.', '她聽到稱讚後笑了。']],
      ['developing', ['Developing countries need reliable infrastructure.', '開發中國家需要可靠的基礎建設。']],
      ['amuse', ['The story will amuse the children.', '這個故事會逗孩子們開心。']],
      ['reasoning', ['Her reasoning was clear and careful.', '她的推理清楚又謹慎。']],
      ['ford', ['They crossed the shallow ford on foot.', '他們步行穿過淺灘。']],
      ['socket', ['Plug the charger into the socket.', '把充電器插進插座。']],
      ['homicide', ['The police investigated the homicide.', '警方調查了這起殺人案。']],
      ['canopy', ['The tree canopy blocked the sun.', '樹冠遮住了陽光。']],
      ['flatten', ['Use a rolling pin to flatten the dough.', '用擀麵棍把麵團壓平。']],
      ['fellowship', ['The fellowship supports young researchers.', '這項獎助金支持年輕研究者。']],
      ['evening', ['We went for a walk in the evening.', '我們傍晚去散步。']],
      ['sea', ['The sea was calm this morning.', '今天早上海面很平靜。']],
      ['leg', ['He hurt his leg while running.', '他跑步時弄傷了腿。']],
      ['heavy', ['This box is too heavy to lift.', '這個箱子太重，搬不動。']],
      ['spray', ['Spray the plants with water.', '用水噴灑植物。']],
      ['pump', ['The pump moves water from the well.', '這台幫浦把井水抽上來。']],
      ['sandy', ['The beach was sandy and warm.', '海灘多沙又溫暖。']],
      ['astronomy', ['She studies astronomy at university.', '她在大學研究天文學。']],
      ['durable', ['This backpack is durable.', '這個背包很耐用。']],
      ['caller', ['The caller left a message.', '來電者留下了訊息。']],
      ['distributed', ['The teacher distributed the papers.', '老師發下考卷。']],
      ['maggot', ['A maggot was crawling on the fruit.', '一隻蛆在水果上爬。']],
      ['maternal', ['She has strong maternal instincts.', '她有強烈的母性本能。']],
      ['conjure', ['The magician tried to conjure a rabbit.', '魔術師試著變出一隻兔子。']],
      ['pianist', ['The pianist played a quiet song.', '鋼琴家演奏了一首安靜的曲子。']],
      ['nearly', ['We nearly missed the train.', '我們差點錯過火車。']],
      ['threaten', ['Dark clouds threaten rain.', '烏雲密布，像是要下雨。']],
      ['thirtieth', ['Her thirtieth birthday is next week.', '她的三十歲生日在下週。']],
      ['opposite', ['The bank is on the opposite side of the street.', '銀行在街道對面。']],
      ['dirty', ['Your shoes are dirty.', '你的鞋子髒了。']],
      ['primarily', ['This room is primarily used for meetings.', '這個房間主要用於開會。']],
      ['realistic', ['The plan is realistic.', '這個計畫很實際。']],
      ['just', ['The judge made a just decision.', '法官做出了公正的判決。']],
      ['accessible', ['The museum is accessible by bus.', '這座博物館搭公車可到。']],
      ['reminder', ['This note is a reminder to call Mom.', '這張便條提醒我要打電話給媽媽。']],
      ['embark', ['They will embark on a new project.', '他們將著手一個新專案。']],
      ['philosophical', ['She stayed calm and philosophical.', '她保持冷靜且豁達。']],
      ['paid', ['This is a paid position.', '這是一個有薪職位。']],
      ['awfully', ['I am awfully sorry.', '我非常抱歉。']],
      ['secular', ['The school offers secular education.', '這所學校提供世俗教育。']],
      ['optical', ['The optical sensor detects movement.', '光學感測器會偵測動作。']],
      ['plank', ['A loose plank creaked under his foot.', '一塊鬆動的木板在他腳下吱嘎作響。']],
      ['lighter', ['Do you have a lighter?', '你有打火機嗎？']],
      ['grave', ['They visited her grave.', '他們去她的墓前探望。']],
      ['ass', ['The farmer led the ass to water.', '農夫牽著驢去喝水。']],
      ['ultimate', ['Winning the final was his ultimate goal.', '贏得決賽是他的最終目標。']],
      ['cab', ['We took a cab to the airport.', '我們搭計程車去機場。']],
      ['colon', ['Use a colon before the list.', '在清單前使用冒號。']],
      ['cellar', ['The wine is stored in the cellar.', '酒儲存在地窖裡。']],
      ['solidarity', ['The workers showed solidarity.', '工人展現了團結。']],
      ['generator', ['The generator provides electricity.', '發電機提供電力。']],
      ['raf', ['The RAF helped defend Britain.', '英國皇家空軍協助防衛英國。']],
      ['accuse', ['They accuse him of lying.', '他們指控他說謊。']],
      ['blink', ['Do not blink during the photo.', '拍照時不要眨眼。']],
      ['typical', ['This is a typical mistake.', '這是典型錯誤。']],
      ['chord', ['Play the final chord softly.', '輕柔地彈出最後一個和弦。']],
      ['diagram', ['The diagram explains the process.', '這張圖表說明流程。']],
      ['memoir', ['She wrote a memoir about her childhood.', '她寫了一本關於童年的回憶錄。']],
      ['commonplace', ['Smartphones are now commonplace.', '智慧型手機如今很普遍。']],
      ['neglect', ['Do not neglect your health.', '不要忽視健康。']],
      ['girlfriend', ['His girlfriend called after lunch.', '他的女朋友午餐後打電話來。']],
      ['fund', ['The fund supports local students.', '這筆基金支持當地學生。']],
      ['city', ['Taipei is a busy city.', '台北是一座繁忙的城市。']],
      ['task', ['This task is difficult.', '這項任務很困難。']],
      ['advice', ['Her advice helped me.', '她的建議幫助了我。']],
      ['armed', ['Armed guards stood at the gate.', '武裝警衛站在門口。']],
      ['assess', ['The teacher will assess each project.', '老師會評估每個專案。']],
      ['literature', ['She studied French literature.', '她研究法國文學。']],
      ['recording', ['The recording was clear.', '錄音很清楚。']],
      ['catholic', ['He went to a Catholic school.', '他讀過天主教學校。']],
      ['foreigner', ['The foreigner asked for directions.', '那位外國人問路。']],
      ['grandchild', ['Her first grandchild was born in May.', '她第一個孫子在五月出生。']],
      ['momentum', ['The team gained momentum after the goal.', '球隊進球後氣勢上升。']],
      ['starter', ['The starter motor failed.', '啟動馬達故障。']],
      ['manifest', ["The ship's manifest listed every box.", '船上的貨物清單列出了每個箱子。']],
      ['bankrupt', ['The company went bankrupt last year.', '那家公司去年破產。']],
      ['publicize', ['They will publicize the event online.', '他們會在網路上宣傳活動。']],
      ['dwell', ['Many families dwell in this valley.', '許多家庭住在這個山谷。']],
      ['glossy', ['The magazine has a glossy cover.', '這本雜誌有亮面的封面。']],
    ]);

    for (const [word, [example, exampleZh]] of expectedExamples) {
      const entry = sampleWords.find((item) => item.word === word);
      expect(entry?.example).toBe(example);
      expect(entry?.exampleZh).toBe(exampleZh);
    }
  });

  test('uses each word directly inside its English example', () => {
    const missingWordExamples = sampleWords.filter((word) => {
      const pattern = new RegExp(`(^|[^a-z])${word.word.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}([^a-z]|$)`, 'i');
      return !pattern.test(word.example);
    });

    expect(missingWordExamples.slice(0, 20).map((word) => word.word)).toEqual([]);
  });

  test('keeps examples free of obvious grammar artifacts', () => {
    const grammarArtifacts = sampleWords.filter(
      (word) =>
        /^[a-z]/.test(word.example) ||
        /\b[Aa] [aeiou]/.test(word.example) ||
        /\b[Aa]n [^aeiou\s]/.test(word.example) ||
        /的的/.test(word.exampleZh),
    );

    expect(grammarArtifacts.slice(0, 20).map((word) => `${word.word}: ${word.example} / ${word.exampleZh}`)).toEqual([]);
  });

  test('keeps generated Chinese examples free of bad dictionary sense leakage', () => {
    const badSensePattern =
      /白痴|不介意|辯論的|醫生的|獨立自主者的|人的部分|特效藥|對手的案例|奇數的部分|字首的部分|牙科醫生的風險|外科醫生的風險|有勢力的人的部分/;
    const badSenseExamples = sampleWords.filter((word) => badSensePattern.test(word.exampleZh));

    expect(badSenseExamples.slice(0, 30).map((word) => `${word.word}: ${word.example} / ${word.exampleZh}`)).toEqual([]);
  });

  test('keeps English example sentences in English', () => {
    const mixedLanguageExamples = sampleWords.filter((word) => /[\u4e00-\u9fff]/.test(word.example));

    expect(mixedLanguageExamples.slice(0, 20).map((word) => word.word)).toEqual([]);
  });

  test('contains single-word English entries only', () => {
    const invalid = sampleWords.filter((word) => !/^[a-z]{2,18}$/.test(word.word));

    expect(invalid).toEqual([]);
  });

  test('keeps common words free of dictionary-domain noise', () => {
    const commonWords = sampleWords.filter((word) => ['be', 'for', 'it'].includes(word.word));
    const noisyPattern = /DOS|信息論|輸入終端|後端|總線|批處理/;

    expect(commonWords.map((word) => `${word.word}: ${word.meaningZh}`)).not.toEqual(
      expect.arrayContaining([expect.stringMatching(noisyPattern)]),
    );
  });

  test('keeps the first learning words stable for the home and study flow', () => {
    expect(sampleWords.slice(0, 5).map((word) => word.word)).toEqual([
      'adapt',
      'brief',
      'contrast',
      'expand',
      'precise',
    ]);
  });
});
