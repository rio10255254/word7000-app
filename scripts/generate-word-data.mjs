import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { parse } from 'csv-parse/sync';
import OpenCC from 'opencc-js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const projectRoot = path.resolve(__dirname, '..');
const sourcePath = path.join(projectRoot, '.codex-run', 'ecdict.csv');
const outputPath = path.join(projectRoot, 'src', 'data', 'words.ts');
const reviewedExamplesPath = path.join(projectRoot, 'src', 'data', 'reviewed-examples.json');
const reviewedExamplesExtraPaths = [
  path.join(projectRoot, 'src', 'data', 'reviewed-examples-core2-a.json'),
  path.join(projectRoot, 'src', 'data', 'reviewed-examples-core2-b.json'),
  path.join(projectRoot, 'src', 'data', 'reviewed-examples-core2-c.json'),
  path.join(projectRoot, 'src', 'data', 'reviewed-examples-core3-a.json'),
  path.join(projectRoot, 'src', 'data', 'reviewed-examples-core3-b.json'),
  path.join(projectRoot, 'src', 'data', 'reviewed-examples-core3-c.json'),
  path.join(projectRoot, 'src', 'data', 'reviewed-examples-core3-d.json'),
];
const TARGET_COUNT = 7000;
const convertToTraditional = OpenCC.Converter({ from: 'cn', to: 'tw' });

function loadReviewedExamples() {
  const paths = [reviewedExamplesPath, ...reviewedExamplesExtraPaths].filter((reviewPath) => fs.existsSync(reviewPath));
  if (paths.length === 0) {
    return new Map();
  }

  const rows = paths.flatMap((reviewPath) => {
    const fileRows = JSON.parse(fs.readFileSync(reviewPath, 'utf8'));
    if (!Array.isArray(fileRows)) {
      throw new Error(`Reviewed examples must be an array: ${reviewPath}`);
    }
    return fileRows.map((row) => ({ ...row, sourcePath: reviewPath }));
  });

  const reviewed = new Map();
  rows.forEach((row, index) => {
    const word = row.word?.trim().toLowerCase();
    const example = row.example?.trim();
    const exampleZh = row.exampleZh?.trim();
    const status = row.status?.trim();

    if (!word || !example || !exampleZh || status !== 'approved') {
      throw new Error(`Invalid reviewed example at row ${index + 1} in ${row.sourcePath}`);
    }
    if (reviewed.has(word)) {
      throw new Error(`Duplicate reviewed example for word: ${word}`);
    }

    reviewed.set(word, { example, exampleZh });
  });

  return reviewed;
}

const reviewedExamples = loadReviewedExamples();

const seedOverrides = new Map(
  [
    [
      'adapt',
      {
        meaningZh: '適應；調整；改編',
        example: 'Students adapt quickly to a clear routine.',
        exampleZh: '學生很快適應清楚的規律。',
      },
    ],
    [
      'brief',
      {
        meaningZh: '簡短的；摘要；簡報',
        example: 'The teacher gave a brief explanation.',
        exampleZh: '老師做了簡短的說明。',
      },
    ],
    [
      'contrast',
      {
        meaningZh: '對比；差異；形成對照',
        example: 'The chart shows a contrast between the two plans.',
        exampleZh: '圖表顯示兩個計畫之間的對比。',
      },
    ],
    [
      'expand',
      {
        meaningZh: '擴大；展開；詳述',
        example: 'The company plans to expand next year.',
        exampleZh: '公司計畫明年擴大規模。',
      },
    ],
    [
      'precise',
      {
        meaningZh: '精確的；明確的',
        example: 'A precise answer saves time.',
        exampleZh: '精確的回答能節省時間。',
      },
    ],
  ],
);

const fixedExamples = new Map(
  [
    ['be', ['I want to be ready before noon.', '我想在中午前準備好。']],
    ['and', ['Tea and coffee are on the table.', '茶和咖啡都在桌上。']],
    ['of', ['The cover of the book is blue.', '那本書的封面是藍色的。']],
    ['to', ['She walked to the station after lunch.', '她午餐後走到車站。']],
    ['have', ['We have enough time for one more question.', '我們還有足夠時間再問一個問題。']],
    ['for', ['This seat is for the new student.', '這個座位是給新學生的。']],
    ['that', ['That answer changed the whole discussion.', '那個答案改變了整場討論。']],
    ['he', ['He closed the window before leaving.', '他離開前關上窗戶。']],
    ['you', ['You can finish this lesson tonight.', '你今晚可以完成這一課。']],
    ['with', ['She wrote the note with a black pen.', '她用黑筆寫下那張便條。']],
    ['on', ['The keys are on the kitchen table.', '鑰匙在廚房桌上。']],
    ['do', ['Please do the first exercise again.', '請再做一次第一題練習。']],
    ['not', ['The answer is not correct yet.', '這個答案還不正確。']],
    ['they', ['They arrived before the class began.', '他們在課開始前抵達。']],
    ['this', ['This plan solves the main problem.', '這個計畫解決了主要問題。']],
    ['at', ['Meet me at the library at three.', '三點在圖書館見我。']],
    ['say', ['Please say your name clearly.', '請清楚說出你的名字。']],
    ['but', ['The task is hard, but it is possible.', '這件事很難，但是可以做到。']],
    ['by', ['The report was written by a student.', '這份報告是由一位學生寫的。']],
    ['we', ['We checked the answer together.', '我們一起檢查了答案。']],
    ['his', ['His notebook was full of examples.', '他的筆記本寫滿了例子。']],
    ['from', ['The train from Taipei arrived early.', '從台北來的火車提早到了。']],
    ['or', ['You can answer now or after class.', '你可以現在回答，或下課後回答。']],
    ['as', ['She works as a nurse in the city.', '她在城裡擔任護理師。']],
    ['what', ['What happened after the meeting?', '會議後發生了什麼事？']],
    ['their', ['Their idea helped the team move faster.', '他們的想法幫助團隊更快前進。']],
    ['would', ['I would choose the shorter route.', '我會選擇比較短的路線。']],
    ['go', ['We go to the same school every day.', '我們每天去同一所學校。']],
    ['which', ['Which answer sounds more natural?', '哪個答案聽起來比較自然？']],
    ['get', ['I need to get a ticket before noon.', '我需要在中午前拿到票。']],
    ['if', ['Call me if the plan changes.', '如果計畫改變，請打給我。']],
    ['all', ['All students must bring a notebook.', '所有學生都必須帶筆記本。']],
    ['her', ['Her speech made the room quiet.', '她的演講讓全場安靜下來。']],
    ['there', ['There is a small cafe near the school.', '學校附近有一間小咖啡館。']],
    ['one', ['One student raised a hand.', '一位學生舉起了手。']],
    ['my', ['My phone rang during the break.', '我的手機在休息時間響了。']],
    ['when', ['Tell me when the bus arrives.', '公車到站時告訴我。']],
    ['some', ['Some people prefer quiet rooms.', '有些人比較喜歡安靜的房間。']],
    ['into', ['She put the letter into her bag.', '她把信放進包包裡。']],
    ['could', ['Could you open the door for me?', '你可以幫我開門嗎？']],
    ['out', ['The dog ran out of the yard.', '那隻狗跑出了院子。']],
    ['your', ['Your answer was clear and careful.', '你的回答清楚又仔細。']],
    ['come', ['Come to my desk after class.', '下課後到我的桌邊來。']],
    ['its', ['The bird cleaned its wings.', '那隻鳥清理了它的翅膀。']],
    ['then', ['Finish the form, then sign your name.', '先填完表格，然後簽名。']],
    ['now', ['Now we can start the next lesson.', '現在我們可以開始下一課。']],
    ['than', ['This bag is lighter than mine.', '這個包包比我的輕。']],
    ['no', ['No cars were parked outside.', '外面沒有停車。']],
    ['how', ['How did you solve the problem?', '你是怎麼解決這個問題的？']],
    ['also', ['She also brought a map.', '她也帶了一張地圖。']],
    ['because', ['I stayed home because it rained.', '因為下雨，我待在家裡。']],
    ['should', ['You should read the question twice.', '你應該把題目讀兩次。']],
    ['here', ['Please put the books here.', '請把書放在這裡。']],
    ['through', ['We walked through the old market.', '我們穿過那座老市場。']],
    ['between', ['The cafe is between two banks.', '那間咖啡館在兩家銀行之間。']],
    ['over', ['A bridge crosses over the river.', '一座橋橫跨河流上方。']],
    ['too', ['This box is too heavy to carry.', '這個箱子太重，搬不動。']],
    ['must', ['You must wear a helmet here.', '你在這裡必須戴安全帽。']],
    ['under', ['The cat slept under the chair.', '貓睡在椅子下面。']],
    ['off', ['Turn off the light before bed.', '睡前把燈關掉。']],
    ['yes', ['Yes, the answer is correct.', '是的，答案是正確的。']],
    ['oh', ['Oh, I forgot my notebook.', '喔，我忘了帶筆記本。']],
    ['however', ['The road was long; however, we arrived early.', '路很長；然而，我們提早到了。']],
    ['without', ['He left without his umbrella.', '他沒帶傘就離開了。']],
    ['before', ['Wash your hands before dinner.', '晚餐前先洗手。']],
    ['both', ['Both answers are acceptable.', '兩個答案都可以接受。']],
    ['away', ['The station is two blocks away.', '車站在兩個街區外。']],
    ['the', ['The blue notebook is on the desk.', '那本藍色筆記本在桌上。']],
    ['it', ['It started to rain after lunch.', '午餐後開始下雨了。']],
    ['she', ['She finished the report before dinner.', '她在晚餐前完成了報告。']],
    ['who', ['Who left the message on my desk?', '誰把訊息留在我的桌上？']],
    ['our', ['Our class starts at nine.', '我們的課九點開始。']],
    ['them', ['Please give them the new schedule.', '請把新的時程表給他們。']],
    ['me', ['Can you send me the file tonight?', '你今晚可以把檔案寄給我嗎？']],
    ['about', ['We talked about the plan after class.', '我們下課後談了那個計畫。']],
    ['first', ['First, read the question carefully.', '首先，仔細閱讀題目。']],
    ['more', ['We need more time to finish the work.', '我們需要更多時間完成這項工作。']],
    ['good', ['A good habit makes learning easier.', '好習慣會讓學習更容易。']],
    ['after', ['Call me after the meeting ends.', '會議結束後打電話給我。']],
    ['still', ['The room was still quiet after the test.', '考試後房間仍然很安靜。']],
    ['put', ['Please put the keys on the table.', '請把鑰匙放在桌上。']],
    ['feel', ['I can feel the cold wind outside.', '我能感覺到外面的冷風。']],
    ['high', ['The mountain is too high to climb today.', '這座山今天太高，不適合攀登。']],
    ['most', ['Most students finished the quiz early.', '大多數學生提早完成了測驗。']],
    ['much', ['There is not much time left.', '剩下的時間不多了。']],
    ['show', ['Please show me your answer.', '請把你的答案給我看。']],
    ['why', ['Why did the train stop here?', '火車為什麼停在這裡？']],
    ['always', ['She always checks her work twice.', '她總是把作業檢查兩次。']],
    ['see', ['I can see the mountains from my window.', '我可以從窗戶看到山。']],
    ['other', ['Please use the other door.', '請走另一扇門。']],
    ['look', ['Look at the picture carefully.', '仔細看這張圖片。']],
    ['back', ['He hurt his back while lifting the box.', '他搬箱子時傷到了背。']],
    ['need', ['We need more time to finish the work.', '我們需要更多時間完成這項工作。']],
    ['same', ['We live on the same street.', '我們住在同一條街上。']],
    ['keep', ['Please keep the door closed.', '請保持門關著。']],
    ['big', ['They live in a big house near the park.', '他們住在公園附近的一棟大房子裡。']],
    ['line', ['Please write your name on this line.', '請把你的名字寫在這一行。']],
    ['sit', ['Please sit near the window.', '請坐在窗戶旁邊。']],
    ['name', ['Write your name at the top of the page.', '把你的名字寫在頁面上方。']],
    ['nothing', ['Nothing changed after the meeting.', '會議後什麼都沒有改變。']],
    ['idea', ['Her idea helped the team solve the problem.', '她的想法幫助團隊解決了問題。']],
    ['mr', ['Mr. Lin will join the meeting today.', '林先生今天會參加會議。']],
    ['allow', ['The teacher will allow one more question.', '老師會允許再問一個問題。']],
    ['bad', ['The bad weather delayed the train.', '壞天氣讓火車誤點。']],
    ['development', ['The development of the city was fast.', '這座城市的發展很快。']],
    ['war', ['The war changed many families forever.', '戰爭永遠改變了許多家庭。']],
    ['offer', ['The company made a generous offer.', '公司提出了一個優厚的提議。']],
    ['expect', ['We expect the bus to arrive soon.', '我們預期公車很快會到。']],
    ['girl', ['The girl smiled at her teacher.', '那個女孩對老師微笑。']],
    ['sure', ['Are you sure about your answer?', '你確定你的答案嗎？']],
    ['force', ['The wind hit the window with great force.', '風以很大的力量吹打窗戶。']],
    ['learn', ['Children learn new words every day.', '孩子們每天學習新單字。']],
    ['spend', ['I spend thirty minutes reading each night.', '我每晚花三十分鐘閱讀。']],
    ['enough', ['We have enough chairs for everyone.', '我們有足夠的椅子給每個人。']],
    ['walk', ['We walk to school every morning.', '我們每天早上走路去學校。']],
    ['class', ['Our class starts at nine.', '我們的課九點開始。']],
    ['build', ['They will build a new bridge next year.', '他們明年會建一座新橋。']],
    ['boy', ['The boy carried his bag to school.', '那個男孩背著書包去學校。']],
    ['action', ['Quick action saved the project.', '快速行動拯救了這個專案。']],
    ['less', ['This box has less sugar than that one.', '這盒糖比那盒少。']],
    ['decision', ['The final decision came after lunch.', '最後的決定是在午餐後做出的。']],
    ['matter', ['This matter needs careful attention.', '這件事需要仔細處理。']],
    ['return', ['Her return surprised the whole team.', '她的回來讓整個團隊很驚訝。']],
    ['agree', ['I agree with your suggestion.', '我同意你的建議。']],
    ['raise', ['The school will raise money for new books.', '學校會為新書募款。']],
    ['general', ['The general rule is easy to understand.', '一般規則很容易理解。']],
    ['international', ['The international meeting begins tomorrow.', '國際會議明天開始。']],
    ['clear', ['Her clear explanation helped everyone.', '她清楚的說明幫助了每個人。']],
    ['provide', ['The school will provide lunch today.', '學校今天會提供午餐。']],
    ['fact', ['The fact surprised everyone in the room.', '這個事實讓房間裡每個人都很驚訝。']],
    ['believe', ['I believe this answer is correct.', '我相信這個答案是正確的。']],
    ['eye', ['Her left eye was red after swimming.', '她游泳後左眼發紅。']],
    ['business', ['His family runs a small business.', '他的家人經營一間小公司。']],
    ['follow', ['Please follow the signs to the exit.', '請跟著指標走到出口。']],
    ['power', ['The storm cut power to the town.', '暴風雨讓鎮上停電。']],
    ['crow', ['The child watched the crow from the fence.', '孩子從圍欄旁看著那隻烏鴉。']],
    ['never', ['I never drink coffee at night.', '我晚上從不喝咖啡。']],
    ['where', ['Where did you put my notebook?', '你把我的筆記本放在哪裡？']],
    ['something', ['Something moved behind the curtain.', '窗簾後面有東西動了一下。']],
    ['against', ['The ladder leaned against the wall.', '梯子靠在牆上。']],
    ['again', ['Please try again after a short break.', '短暫休息後請再試一次。']],
    ['us', ['The teacher asked us to wait outside.', '老師要我們在外面等。']],
    ['during', ['No phones are allowed during the test.', '考試期間不准使用手機。']],
    ['often', ['We often study together after school.', '我們常常放學後一起讀書。']],
    ['yet', ['The answer is not ready yet.', '答案還沒準備好。']],
    ['although', ['Although it was late, we kept working.', '雖然時間很晚，我們還是繼續工作。']],
    ['since', ['I have known her since high school.', '我從高中就認識她。']],
    ['almost', ['The bus is almost full.', '公車幾乎坐滿了。']],
    ['later', ['I will call you later tonight.', '我今晚晚一點會打給你。']],
    ['though', ['The road was narrow, though it was safe.', '這條路很窄，不過很安全。']],
    ['whether', ['I do not know whether he will come.', '我不知道他會不會來。']],
    ['already', ['She has already finished her homework.', '她已經完成作業了。']],
    ['together', ['They cooked dinner together on Sunday.', '他們星期天一起做晚餐。']],
    ['ever', ['Have you ever visited this museum?', '你曾經參觀過這座博物館嗎？']],
    ['around', ['The children ran around the playground.', '孩子們繞著遊樂場跑。']],
    ['until', ['Wait here until the rain stops.', '在這裡等到雨停。']],
    ['quite', ['The answer was quite clear.', '這個答案相當清楚。']],
    ['anything', ['Do you need anything from the store?', '你需要我從商店帶什麼嗎？']],
    ['among', ['She found her bag among the boxes.', '她在箱子堆中找到自己的包包。']],
    ['perhaps', ['Perhaps we should leave earlier.', '也許我們應該早一點出發。']],
    ['once', ['I met him once at a conference.', '我曾在一場會議上見過他一次。']],
    ['ago', ['They moved here two years ago.', '他們兩年前搬到這裡。']],
    ['across', ['The cafe is across the street.', '咖啡館在街對面。']],
    ['behind', ['The garden is behind the house.', '花園在房子後面。']],
    ['including', ['Ten people joined, including my sister.', '包含我妹妹在內，共有十個人參加。']],
    ['in', ['The ticket is in my bag.', '票在我的包包裡。']],
    ['data', ['The data supports our conclusion.', '這些資料支持我們的結論。']],
    ['therefore', ['The road was closed; therefore, we walked.', '道路封閉了，所以我們改用走的。']],
    ['thus', ['The bridge was closed; thus, we took another road.', '橋封閉了，因此我們改走另一條路。']],
    ['indeed', ['The test was difficult indeed.', '那場考試確實很難。']],
    ['otherwise', ['Bring an umbrella; otherwise, you may get wet.', '帶把傘，否則你可能會淋濕。']],
    ['please', ['Please close the door quietly.', '請輕輕把門關上。']],
    ['instead', ['I stayed home instead of going out.', '我沒有出門，而是待在家裡。']],
    ['unless', ['We will wait unless the storm gets worse.', '除非暴風雨變大，否則我們會等。']],
    ['someone', ['Someone left a jacket on the chair.', '有人把外套留在椅子上。']],
    ['everybody', ['Everybody stood up when the bell rang.', '鈴聲響起時，每個人都站了起來。']],
    ['somewhere', ['I left my keys somewhere in the office.', '我把鑰匙忘在辦公室某個地方。']],
    ['beside', ['She sat beside her brother.', '她坐在哥哥旁邊。']],
    ['meanwhile', ['Meanwhile, the children played outside.', '同時，孩子們在外面玩。']],
    ['moreover', ['The plan is simple; moreover, it is cheap.', '這個計畫很簡單，而且成本低。']],
    ['via', ['We sent the document via email.', '我們透過電子郵件寄出文件。']],
    ['abroad', ['She studied abroad for one year.', '她到國外讀了一年書。']],
    ['aloud', ['Read the sentence aloud once.', '把這個句子大聲讀一遍。']],
    ['whereas', ['I like tea, whereas my sister prefers coffee.', '我喜歡茶，而我妹妹比較喜歡咖啡。']],
    ['albeit', ['The room was small, albeit comfortable.', '房間雖小，但很舒適。']],
    ['nevertheless', ['It was raining; nevertheless, we went out.', '當時正在下雨，不過我們還是出門了。']],
    ['nonetheless', ['The work was hard; nonetheless, she finished it.', '工作很難，但她還是完成了。']],
    ['thereby', ['The new rule saved time, thereby reducing stress.', '新規則節省了時間，因此減少了壓力。']],
    ['whereby', ['They created a system whereby students can ask questions online.', '他們建立了一套系統，讓學生可以在線上提問。']],
    ['provided', ['You can join the trip provided you sign up today.', '只要你今天報名，就可以參加這趟旅行。']],
    ['considering', ['Considering the weather, we should leave early.', '考慮到天氣，我們應該早點出發。']],
    ['regarding', ['She sent an email regarding the meeting.', '她寄了一封關於會議的電子郵件。']],
    ['concerning', ['He asked a question concerning the new rule.', '他問了一個關於新規則的問題。']],
    ['versus', ['The chart compares cost versus quality.', '這張圖比較成本與品質。']],
    ['likewise', ['Her brother is kind, and she is likewise generous.', '她哥哥很善良，她也同樣慷慨。']],
    ['altogether', ['There were twenty students altogether.', '總共有二十位學生。']],
    ['beneath', ['The cat slept beneath the table.', '貓睡在桌子底下。']],
    ['underneath', ['The letter was hidden underneath the book.', '那封信藏在書下面。']],
    ['ourselves', ['We made the cake ourselves.', '我們自己做了這個蛋糕。']],
    ['sideways', ['The sign was hanging sideways after the storm.', '暴風雨後，那個招牌歪向一邊掛著。']],
    ['backward', ['He took one backward step.', '他向後退了一步。']],
    ['upwards', ['Smoke rose upwards from the roof.', '煙從屋頂向上升起。']],
    ['downwards', ['The path slopes downwards near the river.', '小路在河邊向下傾斜。']],
    ['share', ['She owns a small share of the company.', '她擁有那家公司的一小部分股份。']],
    ['install', ['Please install the app before class.', '請在上課前安裝這個應用程式。']],
    ['shareholder', ['Each shareholder received a copy of the report.', '每位股東都收到一份報告。']],
    ['homeless', ['The city opened a shelter for homeless families.', '市政府為無家可歸的家庭開設了收容中心。']],
    ['home', ['I stayed home because the weather was bad.', '因為天氣不好，我待在家裡。']],
    ['homework', ['I finished my homework before dinner.', '我在晚餐前完成了作業。']],
    ['hometown', ['He visits his hometown every summer.', '他每年夏天都會回故鄉。']],
    ['suit', ['This dark suit is for formal meetings.', '這套深色西裝適合正式會議。']],
    ['object', ['A small object was lying under the chair.', '椅子下方有一個小物品。']],
    ['option', ['The cheapest option is not always the best.', '最便宜的選項不一定總是最好的。']],
    ['quiz', ['The quiz has ten short questions.', '這份小考有十題簡短的題目。']],
    ['operation', ['The operation of the machine is simple.', '這台機器的操作很簡單。']],
    ['compound', ['Water is not a compound of oxygen alone.', '水不是只由氧組成的化合物。']],
    ['proportion', ['A large proportion of students chose English.', '很大比例的學生選擇了英文。']],
    ['optional', ['The final question is optional.', '最後一題是選答題。']],
    ['accurate', ['The accurate report helped us avoid a mistake.', '準確的報告幫助我們避免錯誤。']],
    ['agriculture', ['Agriculture supports many rural families.', '農業支持許多農村家庭。']],
    ['annual', ['The annual report was published in March.', '年度報告在三月發布。']],
    ['appearance', ['Her appearance on stage surprised the crowd.', '她在舞台上露面讓觀眾很驚訝。']],
    ['authority', ['The local authority approved the plan.', '地方當局批准了這項計畫。']],
    ['aware', ['She became aware of the mistake immediately.', '她立刻察覺到那個錯誤。']],
    ['brand', ['This brand is popular with young customers.', '這個品牌很受年輕顧客歡迎。']],
    ['cup', ['She poured tea into a small cup.', '她把茶倒進一個小杯子裡。']],
    ['earlier', ['The earlier train left before sunrise.', '較早的火車在日出前離開。']],
    ['eastern', ['The eastern coast is famous for its sunrise.', '東部海岸以日出聞名。']],
    ['electrical', ['The electrical system needs regular checks.', '電力系統需要定期檢查。']],
    ['entire', ['The entire team stayed until the work was done.', '整個團隊都留下來直到工作完成。']],
    ['finally', ['The train finally arrived after midnight.', '火車終於在午夜後抵達。']],
    ['icon', ['Tap the icon to open the app.', '點一下圖標來打開應用程式。']],
    ['immediate', ['The immediate problem is a lack of time.', '眼前的問題是時間不足。']],
    ['launch', ['The company will launch a new app next month.', '公司下個月會推出新的應用程式。']],
    ['old', ['The old bridge needs careful repair.', '那座老橋需要仔細維修。']],
    ['only', ['Only one ticket remained at the desk.', '櫃台只剩下一張票。']],
    ['ordinary', ['It was an ordinary day at school.', '那是在學校裡平凡的一天。']],
    ['outdoor', ['The outdoor concert started after sunset.', '戶外音樂會在日落後開始。']],
    ['own', ['She wrote her own answer.', '她寫下自己的答案。']],
    ['pollute', ['Factories can pollute the river if waste is not treated.', '如果廢水沒有處理，工廠可能會汙染河流。']],
    ['scan', ['Please scan the code at the entrance.', '請在入口掃描代碼。']],
    ['splash', ['Rainwater can splash onto your shoes.', '雨水可能會濺到你的鞋子上。']],
    ['syllable', ['Each syllable has one clear vowel sound.', '每個音節都有一個清楚的母音聲音。']],
    ['tilt', ['The picture began to tilt on the wall.', '牆上的照片開始傾斜。']],
    ['whirl', ['Leaves whirl in the wind after the storm.', '暴風雨後，樹葉在風中旋轉。']],
    ['word', ['Please write one word on each line.', '請在每一行寫一個單字。']],
  ],
);

const contextActors = [
  'teacher',
  'manager',
  'doctor',
  'designer',
  'engineer',
  'student',
  'neighbor',
  'guide',
  'coach',
  'editor',
  'artist',
  'driver',
  'researcher',
  'assistant',
  'nurse',
  'visitor',
];
const zhActors = [
  '老師',
  '經理',
  '醫生',
  '設計師',
  '工程師',
  '學生',
  '鄰居',
  '嚮導',
  '教練',
  '編輯',
  '藝術家',
  '司機',
  '研究員',
  '助理',
  '護理師',
  '訪客',
];
const contextObjects = [
  'plan',
  'report',
  'schedule',
  'project',
  'message',
  'lesson',
  'file',
  'room',
  'budget',
  'map',
  'letter',
  'ticket',
  'device',
  'garden',
  'contract',
  'display',
];
const zhObjects = [
  '計畫',
  '報告',
  '時程',
  '專案',
  '訊息',
  '課程',
  '檔案',
  '房間',
  '預算',
  '地圖',
  '信件',
  '票券',
  '裝置',
  '花園',
  '合約',
  '展示',
];
const contextEvents = [
  'meeting',
  'lesson',
  'interview',
  'workshop',
  'trip',
  'review',
  'practice',
  'discussion',
  'training',
  'visit',
  'trial',
  'festival',
  'inspection',
  'presentation',
  'debate',
  'rehearsal',
];
const zhEvents = [
  '會議',
  '課程',
  '面試',
  '工作坊',
  '旅程',
  '檢查',
  '練習',
  '討論',
  '訓練',
  '拜訪',
  '試驗',
  '節慶',
  '檢查',
  '簡報',
  '辯論',
  '排練',
];
const contextTimes = [
  'Friday',
  'noon',
  'the deadline',
  'the weekend',
  'class',
  'the review',
  'the trip',
  'the meeting',
  'sunset',
  'breakfast',
  'the interview',
  'the holiday',
  'the rehearsal',
  'the storm',
  'the exam',
  'the call',
];
const zhTimes = [
  '星期五',
  '中午',
  '期限',
  '週末',
  '上課',
  '檢查',
  '旅程',
  '會議',
  '日落',
  '早餐',
  '面試',
  '假期',
  '排練',
  '暴風雨',
  '考試',
  '通話',
];
const contextQualities = [
  'answer',
  'design',
  'method',
  'schedule',
  'note',
  'choice',
  'route',
  'rule',
  'pattern',
  'signal',
  'question',
  'example',
  'goal',
  'record',
  'layout',
  'habit',
];
const zhQualities = [
  '回答',
  '設計',
  '方法',
  '時程',
  '筆記',
  '選擇',
  '路線',
  '規則',
  '模式',
  '訊號',
  '問題',
  '例子',
  '目標',
  '紀錄',
  '版面',
  '習慣',
];

function cleanText(value = '') {
  return convertToTraditional(value)
    .replace(/\\n/g, '\n')
    .replace(/\r/g, '\n')
    .replace(/[ \t]+/g, ' ')
    .replace(/\n{2,}/g, '\n')
    .trim();
}

function cleanMeaning(value = '') {
  const seenLines = new Set();
  const lines = cleanText(value)
    .split('\n')
    .filter((line) => !/^\[[^\]]+\]/.test(line.trim()))
    .map((line) =>
      line
        .replace(/^\[[^\]]+\]\s*/g, '')
        .replace(/^[a-z]+\.\s*/i, '')
        .replace(/\s+/g, ' ')
        .trim(),
    )
    .filter(Boolean)
    .filter((line) => !line.startsWith('網絡') && !line.startsWith('網路'))
    .filter((line) => {
      if (seenLines.has(line)) {
        return false;
      }
      seenLines.add(line);
      return true;
    });

  const joined = lines.join('；');
  return joined
    .replace(/[;；]{2,}/g, '；')
    .replace(/，/g, '，')
    .replace(/\s*；\s*/g, '；')
    .slice(0, 120)
    .replace(/[，,;；\s]+$/g, '');
}

function meaningHead(value = '') {
  const head = cleanText(value)
    .split(/[；;,，、]/)[0]
    ?.trim()
    .replace(/[^\u4e00-\u9fffA-Za-z\s-]/g, '')
    .trim();
  return head || '這個概念';
}

function zhAttributive(value) {
  return value.endsWith('的') ? value : `${value}的`;
}

function zhAdverbial(value) {
  return value.endsWith('地') ? value : `${value}地`;
}

function wordKind(pos, word, meaningZh = '') {
  const value = pos.toLowerCase();
  const tokens = value.split('/').map((item) => item.trim());
  const first = tokens[0] ?? '';

  if (first.includes('num')) {
    return 'number';
  }
  if (first.includes('prep') || first.includes('conj') || first.includes('pron') || first.includes('aux')) {
    return 'function';
  }
  if (first.includes('adv') || first === 'r') {
    return word.endsWith('ly') ? 'adverb' : 'function';
  }
  if (first.includes('v')) {
    return 'verb';
  }
  if (first === 'a' || first.includes('adj')) {
    return 'adjective';
  }
  if (first.includes('n')) {
    const canBeAdjective = tokens.some((token) => token === 'a' || token.includes('adj'));
    if (canBeAdjective && looksAdjectival(word) && meaningLooksAdjectival(meaningZh)) {
      return 'adjective';
    }
    return 'noun';
  }
  if (first === 'pl' || first.includes('abbr') || first === 'word') {
    return 'noun';
  }
  if (word.endsWith('ly')) {
    return 'adverb';
  }
  if (word.endsWith('ed')) {
    return 'adjective';
  }
  return 'noun';
}

function generatedExample(row, word, partOfSpeechValue, meaningZh, index) {
  const fixed = fixedExamples.get(word);
  if (fixed) {
    return fixed;
  }

  const kind = wordKind(partOfSpeechValue, word, meaningZh);
  const zhHead = meaningHead(meaningZh);
  const definition = cleanText(row.definition ?? '');
  const profile = semanticProfile(word, meaningZh, definition, partOfSpeechValue);

  if (kind === 'noun') {
    return nounExample(word, zhHead, profile, index);
  }

  if (kind === 'verb') {
    return verbExample(word, zhHead, profile, partOfSpeechValue, index);
  }

  if (kind === 'adjective') {
    return adjectiveExample(word, zhHead, profile, index);
  }

  if (kind === 'adverb') {
    return adverbExample(word, zhHead, index);
  }

  if (kind === 'number') {
    return numberExample(word, zhHead, index);
  }

  return functionExample(word, zhHead, profile, index);
}

function semanticProfile(word, meaningZh, _definition, pos) {
  const primaryMeaning = meaningHead(meaningZh);
  const text = `${word} ${primaryMeaning} ${pos}`.toLowerCase();
  const has = (...terms) => terms.some((term) => hasSemanticTerm(text, term));

  if (
    /[人者員師商夫]$/.test(primaryMeaning) ||
    /(少年|選民|間諜)/.test(primaryMeaning) ||
    (primaryMeaning.endsWith('家') && !['國家', '家'].includes(primaryMeaning)) ||
    /^(translator|teacher|worker|specialist|student|doctor|nurse)$/.test(word)
  ) {
    if (!/(殺人|罪惡|罪行)/.test(primaryMeaning)) {
      return 'person';
    }
  }
  if (has('城市', '國家', '地區', '地方', '房間', '電影院', '教堂', '車站', '劇院', 'place', 'country', 'city', 'area', 'room', 'cinema', 'church', 'station', 'theater')) {
    return 'place';
  }
  if (has('公司', '政府', '組織', '學校', 'team', 'company', 'government', 'organization')) {
    return 'organization';
  }
  if (has('時間', '日期', '星期', '月份', '年度', '下午', '午後', 'day', 'time', 'period', 'season', 'afternoon')) {
    return 'time';
  }
  if (has('腹', '肚', '脊椎', '背骨', '骨', '牙', '齒', '眼', '耳', '鼻', 'body', 'belly', 'spine', 'bone', 'tooth', 'eye', 'ear')) {
    return 'body';
  }
  if (has('病', '痛', '傷', '醫', 'disease', 'pain', 'injury', 'medical')) {
    return 'health';
  }
  if (has('食物', '飯', '飲料', '肉', '茶', '水果', 'food', 'drink', 'meal', 'fruit')) {
    return 'food';
  }
  if (has('水', '河', '海', '山', '雨', '風', 'tree', 'river', 'water', 'weather', 'plant')) {
    return 'nature';
  }
  if (has('汽車', '車輛', '火車', '船', '飛機', 'train', 'car', 'ship', 'aircraft', 'vehicle')) {
    return 'vehicle';
  }
  if (has('工具', '機器', '設備', 'instrument', 'machine', 'device', 'tool')) {
    return 'tool';
  }
  if (has('錢', '價格', '費用', 'money', 'price', 'cost', 'payment')) {
    return 'money';
  }
  if (has('情緒', '恐懼', '愛', '怒', 'sad', 'happy', 'fear', 'emotion')) {
    return 'emotion';
  }
  if (has('說話', '講話', '問題', '信件', '訊息', '演說', 'speech', 'message', 'letter', 'write')) {
    return 'communication';
  }
  if (has('學', '科學', '藝術', '政治', '法律', 'field', 'science', 'art', 'law')) {
    return 'field';
  }
  if (has('材料', '金屬', '木', '布', 'stone', 'metal', 'wood', 'material')) {
    return 'material';
  }
  if (has('計畫', '方法', '制度', '政策', 'plan', 'method', 'policy', 'system')) {
    return 'method';
  }
  if (has('動物', '鳥', '魚', 'horse', 'animal', 'bird', 'fish')) {
    return 'animal';
  }
  if (has('移動', '走', '去', '來', 'move', 'travel', 'arrive', 'leave')) {
    return 'motion';
  }
  if (has('增加', '減少', '改變', '成長', 'change', 'increase', 'reduce', 'grow')) {
    return 'change';
  }
  if (has('建立', '製造', '創造', 'build', 'make', 'create', 'produce')) {
    return 'create';
  }
  if (has('破壞', '刪除', '移除', 'destroy', 'remove', 'delete')) {
    return 'remove';
  }
  if (has('看', '聽', '感覺', 'see', 'hear', 'feel', 'sense')) {
    return 'sense';
  }
  return 'general';
}

function hasSemanticTerm(text, term) {
  const normalized = term.toLowerCase();
  if (/^[a-z][a-z\s-]*$/.test(normalized)) {
    const escaped = escapeRegExp(normalized).replace(/\\ /g, '\\s+');
    return new RegExp(`(^|[^a-z])${escaped}([^a-z]|$)`, 'i').test(text);
  }

  return text.includes(normalized);
}

function escapeRegExp(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

function looksAdjectival(word) {
  return /(able|ible|al|ant|ary|ent|ern|ful|ic|ive|less|ory|ous|some|y)$/.test(word);
}

function meaningLooksAdjectival(value = '') {
  const head = meaningHead(value);
  return (
    /的$/.test(head) ||
    /^(可|不|無|非|很|最)/.test(head) ||
    /(必要|重要|嚴重|簡單|困難|清楚|明顯|相同|不同|可能|自然|私人|個人|正式|普通|特殊|主要|完整|正確|錯誤|新鮮|便宜|昂貴|危險|安全|明亮|柔軟|乾燥|頻繁|理想|實際|巨大的?)$/.test(head)
  );
}

function nounExample(word, zhHead, profile, index) {
  const actor = pick(contextActors, word, index);
  const zhActor = pick(zhActors, word, index);
  const object = pick(contextObjects, word, index + 3);
  const zhObject = pick(zhObjects, word, index + 3);
  const event = pick(contextEvents, word, index + 5);
  const zhEvent = pick(zhEvents, word, index + 5);
  const time = pick(contextTimes, word, index + 7);
  const zhTime = pick(zhTimes, word, index + 7);
  const manner = pick(['briefly', 'carefully', 'clearly', 'openly', 'quietly', 'together'], word, index + 9);
  const zhManner = pick(['簡短地', '仔細地', '清楚地', '坦率地', '安靜地', '一起'], word, index + 9);
  const quality = pick(contextQualities, word, index + 11);
  const zhQuality = pick(zhQualities, word, index + 11);
  const zhTopic = `關於${zhHead}這方面`;
  const article = articleFor(word);

  const templates = {
    person: [
      [`The ${word} spoke with the ${actor} before ${time}.`, `那位${zhHead}在${zhTime}前和${zhActor}說話。`],
      [`${capitalize(article)}${word} joined the ${event} on time.`, `一位${zhHead}準時參加了${zhEvent}。`],
      [`The ${word} worked carefully with the ${actor}.`, `那位${zhHead}仔細地和${zhActor}合作。`],
    ],
    place: [
      [`The ${actor} found the ${word} without trouble.`, `${zhActor}順利找到了那個${zhHead}。`],
      [`The ${actor} visited the ${word} before ${time}.`, `${zhActor}在${zhTime}前拜訪了那個${zhHead}。`],
      [`The road to the ${word} was quiet before ${time}.`, `通往${zhHead}的路在${zhTime}前很安靜。`],
    ],
    organization: [
      [`The ${word} held a meeting this week.`, `那個${zhHead}這週開了一場會議。`],
      [`The ${actor} contacted the ${word} after the ${event}.`, `${zhActor}在${zhEvent}後聯絡了那個${zhHead}。`],
      [`The ${word} updated its plan before ${time}.`, `那個${zhHead}在${zhTime}前更新了計畫。`],
    ],
    time: [
      [`${capitalize(word)} felt unusually busy after the ${event}.`, `${zhEvent}後的${zhHead}感覺特別忙。`],
      [`We talked about ${word} during the ${event}.`, `我們在${zhEvent}期間談到${zhHead}。`],
      [`The ${actor} marked ${word} on the calendar.`, `${zhActor}把${zhHead}標在行事曆上。`],
    ],
    health: [
      [`The doctor discussed ${word} with the family.`, `醫生和家人討論了${zhHead}。`],
      [`The ${word} made the ${event} difficult after ${time}.`, `${zhHead}讓${zhTime}後的${zhEvent}變得困難。`],
      [`Early care can reduce the risk of ${word}.`, `早期照護可以降低${zhHead}的風險。`],
    ],
    body: [
      [`The doctor checked his ${word}.`, `醫生檢查了他的${zhHead}。`],
      [`She felt pain in her ${word} after the fall.`, `她跌倒後${zhHead}感到疼痛。`],
      [`He protected his ${word} during the game.`, `他在比賽中保護自己的${zhHead}。`],
    ],
    food: [
      [`The ${word} was served before dinner.`, `${zhHead}在晚餐前端上來。`],
      [`She put the ${word} on a clean plate.`, `她把${zhHead}放在乾淨的盤子上。`],
      [`The ${word} smelled good in the kitchen.`, `${zhHead}在廚房裡聞起來很香。`],
    ],
    nature: [
      [`The ${word} looked beautiful before ${time}.`, `${zhHead}在${zhTime}前看起來很美。`],
      [`We walked near the ${word} after the ${event}.`, `我們在${zhEvent}後到${zhHead}附近散步。`],
      [`The ${word} was easy to see near the ${object}.`, `${zhHead}在${zhObject}附近很容易看見。`],
    ],
    vehicle: [
      [`The ${word} stopped near the ${object} before ${time}.`, `${zhHead}在${zhTime}前停在${zhObject}附近。`],
      [`The ${actor} repaired the ${word} before the trip.`, `${zhActor}在旅程前修好了${zhHead}。`],
      [`The ${actor} boarded the ${word} before ${time}.`, `${zhActor}在${zhTime}前登上了${zhHead}。`],
    ],
    tool: [
      [`The ${actor} used the ${word} to finish the ${object}.`, `${zhActor}用${zhHead}完成${zhObject}。`],
      [`The ${word} made the work faster.`, `${zhHead}讓工作更快完成。`],
      [`She cleaned the ${word} after the ${event}.`, `她在${zhEvent}後清理了${zhHead}。`],
    ],
    money: [
      [`The ${word} was higher than expected.`, `${zhHead}比預期更高。`],
      [`The ${actor} checked the ${word} before signing.`, `${zhActor}在簽名前確認了${zhHead}。`],
      [`A small ${object} change affected the ${word}.`, `一個小小的${zhObject}變動影響了${zhHead}。`],
    ],
    emotion: [
      [`The ${word} faded after the honest talk.`, `坦白談話後，${zhHead}慢慢消退。`],
      [`Her ${word} was clear during the ${event}.`, `她在${zhEvent}中的${zhHead}很明顯。`],
      [`The ${actor} noticed the ${word} in his voice.`, `${zhActor}注意到他聲音裡的${zhHead}。`],
    ],
    communication: [
      [`The ${word} was clear during the ${event}.`, `${zhHead}在${zhEvent}中很清楚。`],
      [`The ${actor} saved the ${word} for later.`, `${zhActor}把${zhHead}留到之後。`],
      [`A short ${word} ended the confusion during the ${event}.`, `一段簡短的${zhHead}在${zhEvent}中結束了混亂。`],
    ],
    field: [
      [`Students explored ${word} during the ${event}.`, `學生在${zhEvent}中探索${zhHead}。`],
      [`The ${actor} linked ${word} to daily life.`, `${zhActor}把${zhHead}和日常生活連起來。`],
      [`A short ${event} discussion made ${word} easier to understand.`, `簡短的${zhEvent}討論讓${zhHead}更容易理解。`],
    ],
    material: [
      [`The ${object} was made of ${word}.`, `${zhObject}是用${zhHead}做的。`],
      [`The ${actor} chose ${word} for the new design.`, `${zhActor}為新設計選了${zhHead}。`],
      [`The ${word} felt smooth under the light.`, `${zhHead}在燈光下摸起來很光滑。`],
    ],
    animal: [
      [`The ${word} moved quietly through the grass.`, `${zhHead}安靜地穿過草地。`],
      [`${capitalize(article)}${word} appeared near the path.`, `一隻${zhHead}出現在小路旁。`],
      [`The child watched the ${word} from the fence.`, `孩子從圍欄旁看著${zhHead}。`],
    ],
    method: [
      [`The ${actor} chose this ${word} for the ${object}.`, `${zhActor}為${zhObject}選了這個${zhHead}。`],
      [`A clear ${word} kept the team organized.`, `清楚的${zhHead}讓團隊保持有條理。`],
      [`This ${word} helped guide the next step.`, `這個${zhHead}幫助引導下一步。`],
    ],
    general: [
      [`The ${actor} prepared a short report on ${word} before ${time}.`, `${zhActor}在${zhTime}前準備了一份${zhTopic}的短報告。`],
      [`The ${actor} led a class discussion about ${word} after the ${event}.`, `${zhActor}在${zhEvent}後帶領全班討論${zhHead}。`],
      [`The ${actor} explained ${word} during class before ${time}.`, `${zhActor}在${zhTime}前的課堂上解釋了${zhHead}。`],
      [`The ${actor} wrote a short note about ${word} after the ${event}.`, `${zhActor}在${zhEvent}後寫了一段${zhTopic}的短筆記。`],
      [`The ${actor} gave a brief talk about ${word} before ${time}.`, `${zhActor}在${zhTime}前做了一段${zhTopic}的簡短分享。`],
    ],
  };

  return pick(templates[profile] ?? templates.general, word, index);
}

function verbExample(word, zhHead, profile, pos, index) {
  const fixedVerbs = new Map([
    ['attend', ['She will attend the meeting tomorrow.', '她明天會參加會議。']],
    ['submit', ['Please submit the form by Friday.', '請在星期五前提交表格。']],
    ['marry', ['They plan to marry next spring.', '他們計畫明年春天結婚。']],
    ['prosper', ['Small businesses can prosper with support.', '小企業有了支持就能興盛。']],
    ['forget', ['Do not forget your keys.', '不要忘記你的鑰匙。']],
    ['listen', ['Please listen to the question carefully.', '請仔細聽這個問題。']],
    ['protect', ['We must protect the river from pollution.', '我們必須保護河流免受污染。']],
    ['deliver', ['The driver will deliver the package today.', '司機今天會送包裹。']],
    ['divide', ['Please divide the cake into six pieces.', '請把蛋糕分成六塊。']],
    ['except', ['Everyone came except Tom.', '除了湯姆以外，大家都來了。']],
    ['pray', ['They pray before dinner.', '他們晚餐前祈禱。']],
    ['sharpen', ['Please sharpen this pencil.', '請削尖這支鉛筆。']],
    ['extend', ['They plan to extend the deadline.', '他們計畫延長期限。']],
  ]);
  const fixed = fixedVerbs.get(word);
  if (fixed) {
    return fixed;
  }

  const actor = pick(contextActors, word, index);
  const zhActor = pick(zhActors, word, index);
  const object = pick(contextObjects, word, index + 2);
  const zhObject = pick(zhObjects, word, index + 2);
  const time = pick(contextTimes, word, index + 4);
  const zhTime = pick(zhTimes, word, index + 4);
  const event = pick(contextEvents, word, index + 6);
  const zhEvent = pick(zhEvents, word, index + 6);
  const quality = pick(contextQualities, word, index + 8);
  const zhQuality = pick(zhQualities, word, index + 8);
  const intransitive = /\bvi\b/i.test(pos) && !/\bvt\b/i.test(pos);

  const templates = {
    communication: [
      [`The ${actor} will ${word} the ${object} before ${time}.`, `${zhActor}會在${zhTime}前${zhHead}${zhObject}。`],
      [`Please ${word} the answer clearly.`, `請清楚地${zhHead}答案。`],
      [`They ${word} the ${object} after the ${event}.`, `他們在${zhEvent}後${zhHead}了${zhObject}。`],
    ],
    motion: [
      [`The ${actor} will ${word} before ${time}.`, `${zhActor}會在${zhTime}前${zhHead}。`],
      [`People began to ${word} near the station.`, `人們開始在車站附近${zhHead}。`],
      [`We watched the crowd ${word} across the street.`, `我們看著人群穿過街道${zhHead}。`],
    ],
    change: [
      [`The numbers may ${word} over time.`, `數字可能會隨時間${zhHead}。`],
      [`Small choices can ${word} the final result.`, `小選擇可能會${zhHead}最後結果。`],
      [`The price began to ${word} before summer.`, `價格在夏天前開始${zhHead}。`],
    ],
    create: [
      [`The ${actor} will ${word} a new ${object}.`, `${zhActor}會${zhHead}新的${zhObject}。`],
      [`They ${word} the design during the ${time}.`, `他們在${zhTime}期間${zhHead}了設計。`],
      [`The ${event} helped us ${word} better ${object}.`, `${zhEvent}幫助我們${zhHead}更好的${zhObject}。`],
    ],
    remove: [
      [`Workers had to ${word} the old ${object}.`, `工人必須${zhHead}舊的${zhObject}。`],
      [`The rule can ${word} unnecessary steps.`, `這條規則可以${zhHead}不必要的步驟。`],
      [`They decided to ${word} the plan before ${time}.`, `他們決定在${zhTime}前${zhHead}計畫。`],
    ],
    sense: [
      [`I can ${word} the change in the room.`, `我能${zhHead}房間裡的變化。`],
      [`The ${actor} tried to ${word} the signal.`, `${zhActor}試著${zhHead}訊號。`],
      [`She could ${word} the problem right away.`, `她立刻就能${zhHead}問題。`],
    ],
    general: intransitive
      ? [
          [`The ${actor} may ${word} before ${time}.`, `${zhActor}可能會在${zhTime}前${zhHead}。`],
          [`The ${actor} will ${word} during the ${event}.`, `${zhActor}會在${zhEvent}期間${zhHead}。`],
          [`The ${actor} began to ${word} during the ${event}.`, `${zhActor}在${zhEvent}期間開始${zhHead}。`],
        ]
      : [
          [`They tried to ${word} the ${object} before ${time}.`, `他們試著在${zhTime}前${zhHead}${zhObject}。`],
          [`Please ${word} the ${object} when you are ready.`, `準備好時，請${zhHead}${zhObject}。`],
          [`We need to ${word} the ${object} carefully before ${time}.`, `我們需要在${zhTime}前仔細${zhHead}${zhObject}。`],
          [`The ${event} helped us ${word} the ${object} more clearly.`, `${zhEvent}幫助我們更清楚地${zhHead}${zhObject}。`],
        ],
  };

  return pick(templates[profile] ?? templates.general, word, index);
}

function adjectiveExample(word, zhHead, profile, index) {
  const zhAdj = zhAttributive(zhHead);
  const quality = pick(contextQualities, word, index);
  const zhQuality = pick(zhQualities, word, index);
  const object = pick(contextObjects, word, index + 2);
  const zhObject = pick(zhObjects, word, index + 2);
  const actor = pick(contextActors, word, index + 4);
  const zhActor = pick(zhActors, word, index + 4);
  const event = pick(contextEvents, word, index + 6);
  const zhEvent = pick(zhEvents, word, index + 6);
  const time = pick(contextTimes, word, index + 8);
  const zhTime = pick(zhTimes, word, index + 8);
  const article = articleForAdjective(word);

  const templates = {
    emotion: [
      [`The ${word} child waited near the door.`, `那個${zhAdj}孩子在門邊等待。`],
      [`Her ${word} voice made everyone pause.`, `她${zhAdj}聲音讓大家停了下來。`],
      [`${capitalize(article)}${word} look crossed his face.`, `他臉上露出${zhAdj}表情。`],
    ],
    place: [
      [`The ${word} road led to a small village.`, `那條${zhAdj}路通往小村莊。`],
      [`${capitalize(article)}${word} room gave us space to work.`, `${zhAdj}房間讓我們有空間工作。`],
      [`The ${actor} chose ${article}${word} area for the event.`, `${zhActor}為活動選了${zhAdj}地區。`],
    ],
    time: [
      [`The ${word} meeting ended before lunch.`, `${zhAdj}會議在午餐前結束。`],
      [`${capitalize(article)}${word} schedule helped the team plan ahead.`, `${zhAdj}時程幫助團隊提前安排。`],
      [`The ${word} change surprised the office.`, `${zhAdj}變化讓辦公室很驚訝。`],
    ],
    material: [
      [`The ${word} surface reflected the light.`, `${zhAdj}表面反射了光線。`],
      [`${capitalize(article)}${word} frame held the picture in place.`, `${zhAdj}框架固定住照片。`],
      [`The ${object} used ${article}${word} finish.`, `${zhObject}用了${zhAdj}表面處理。`],
    ],
    general: [
      [`The ${actor} reviewed the ${word} case after the ${event}.`, `${zhActor}在${zhEvent}後檢視了這個${zhAdj}案例。`],
      [`${capitalize(article)}${word} situation required extra care before ${time}.`, `一個${zhAdj}情況在${zhTime}前需要額外處理。`],
      [`The ${actor} chose ${article}${word} method before ${time}.`, `${zhActor}在${zhTime}前選了一個${zhAdj}方法。`],
      [`The ${word} plan helped the team move forward after the ${event}.`, `${zhAdj}計畫在${zhEvent}後幫助團隊往前推進。`],
    ],
  };

  return pick(templates[profile] ?? templates.general, word, index);
}

function adverbExample(word, zhHead, index) {
  const fixedAdverbs = new Map([
    ['admittedly', ['Admittedly, the task is difficult.', '不可否認，這項任務很困難。']],
    ['furthermore', ['Furthermore, the plan saves time.', '此外，這個計畫能節省時間。']],
    ['particularly', ['This part is particularly important.', '這一部分特別重要。']],
    ['extremely', ['The weather was extremely cold.', '天氣非常寒冷。']],
    ['plainly', ['She explained the rule plainly.', '她清楚地解釋了規則。']],
  ]);
  const fixed = fixedAdverbs.get(word);
  if (fixed) {
    return fixed;
  }

  const actor = pick(contextActors, word, index);
  const zhActor = pick(zhActors, word, index);
  const event = pick(contextEvents, word, index + 2);
  const zhEvent = pick(zhEvents, word, index + 2);
  const object = pick(contextObjects, word, index + 4);
  const zhObject = pick(zhObjects, word, index + 4);
  const quality = pick(contextQualities, word, index + 6);
  const zhQuality = pick(zhQualities, word, index + 6);
  const zhAdv = zhAdverbial(zhHead);
  const qualityArticle = articleFor(quality);
  const templates = [
    [`The ${actor} answered ${word} during the ${event}.`, `${zhActor}在${zhEvent}中${zhAdv}回答。`],
    [`The ${actor} worked ${word} through the ${object}.`, `${zhActor}${zhAdv}完成了${zhObject}。`],
    [`The team finished the ${object} ${word}.`, `團隊${zhAdv}完成了${zhObject}。`],
    [`He listened ${word} before making ${qualityArticle}${quality}.`, `他在做${zhQuality}前${zhAdv}聆聽。`],
  ];

  return pick(templates, word, index);
}

function numberExample(word, zhHead, index) {
  const object = pick(contextObjects, word, index);
  const zhObject = pick(zhObjects, word, index);
  const templates = [
    [`The team prepared ${word} copies of the ${object}.`, `團隊準備了${zhHead}份${zhObject}。`],
    [`She waited ${word} minutes before calling again.`, `她等了${zhHead}分鐘才再打電話。`],
    [`The room had ${word} seats for guests.`, `房間裡有${zhHead}個座位給客人。`],
  ];

  return pick(templates, word, index);
}

function functionExample(word, zhHead, profile, index) {
  const object = pick(contextObjects, word, index);
  const zhObject = pick(zhObjects, word, index);
  const time = pick(contextTimes, word, index + 2);
  const zhTime = pick(zhTimes, word, index + 2);
  const prepositions = new Set([
    'above',
    'across',
    'along',
    'alongside',
    'amid',
    'among',
    'amongst',
    'around',
    'behind',
    'below',
    'beneath',
    'beside',
    'beyond',
    'inside',
    'onto',
    'outside',
    'throughout',
    'underneath',
    'upon',
    'within',
  ]);
  const conjunctions = new Set(['albeit', 'unless', 'whereas', 'whilst']);
  const fixedFunctionExamples = new Map([
    ['neither', ['Neither answer is correct.', '兩個答案都不正確。']],
    ['either', ['Either option is fine.', '兩個選項都可以。']],
    ['twice', ['I called twice yesterday.', '我昨天打了兩次電話。']],
    ['these', ['These books belong on this shelf.', '這些書應該放在這個書架上。']],
    ['those', ['Those shoes are still wet.', '那些鞋子還是濕的。']],
    ['sometimes', ['Sometimes the bus arrives early.', '公車有時會提早到。']],
    ['maybe', ['Maybe we should leave early.', '也許我們應該早點離開。']],
    ['myself', ['I made the cake myself.', '我自己做了這個蛋糕。']],
    ['whatever', ['Choose whatever you like.', '選你喜歡的任何東西。']],
    ['nor', ['He did not call, nor did he write.', '他沒有打電話，也沒有寫信。']],
    ['anyway', ['I was tired, but I went anyway.', '我很累，但還是去了。']],
    ['plus', ['Two plus three equals five.', '二加三等於五。']],
    ['furthermore', ['Furthermore, the plan saves time.', '此外，這個計畫能節省時間。']],
    ['so', ['It was late, so we went home.', '天晚了，所以我們回家。']],
    ['somehow', ['Somehow, we found the right address.', '不知怎麼地，我們找到了正確地址。']],
    ['elsewhere', ['They decided to stay elsewhere.', '他們決定住在別處。']],
    ['anywhere', ['You can sit anywhere.', '你可以坐在任何地方。']],
    ['apart', ['The two houses are far apart.', '那兩棟房子相距很遠。']],
    ['everywhere', ['Flowers were everywhere.', '到處都是花。']],
    ['whenever', ['Call me whenever you arrive.', '你什麼時候到，就什麼時候打給我。']],
    ['nowhere', ['The keys were nowhere to be found.', '鑰匙到處都找不到。']],
    ['till', ['Wait here till I return.', '在這裡等到我回來。']],
    ['afterwards', ['We had dinner afterwards.', '之後我們吃了晚餐。']],
    ['ought', ['You ought to rest.', '你應該休息。']],
    ['forth', ['He stepped forth to speak.', '他走上前發言。']],
    ['besides', ['Besides tea, we also served coffee.', '除了茶，我們也供應咖啡。']],
    ['forever', ['I will remember this day forever.', '我會永遠記得這一天。']],
    ['hence', ['The road was closed; hence, we turned back.', '道路封閉，因此我們折返。']],
    ['hers', ['The blue bag is hers.', '那個藍色包包是她的。']],
    ['wherever', ['Sit wherever you like.', '你喜歡坐哪裡就坐哪裡。']],
    ['backwards', ['He walked backwards slowly.', '他慢慢倒著走。']],
    ['thereafter', ['Thereafter, the rules changed.', '從那以後，規則改變了。']],
    ['whatsoever', ['There was no doubt whatsoever.', '完全沒有任何疑問。']],
    ['aboard', ['Everyone is aboard the train.', '每個人都在火車上。']],
    ['anymore', ['I do not live there anymore.', '我不再住在那裡了。']],
    ['pro', ['She is a pro at fixing bikes.', '她是修腳踏車的高手。']],
    ['ibid', ['The same source is cited ibid.', '同一來源以 ibid 標示。']],
    ['indoors', ['We stayed indoors because of the rain.', '因為下雨，我們待在室內。']],
    ['excluding', ['The price is ten dollars, excluding tax.', '價格是十美元，不含稅。']],
    ['hitherto', ['Hitherto, the plan has worked.', '到目前為止，這個計畫一直有效。']],
    ['oneself', ['One should take care of oneself.', '人應該照顧自己。']],
    ['whichever', ['Choose whichever seat you like.', '選你喜歡的任何座位。']],
    ['beforehand', ['Please call beforehand.', '請事先打電話。']],
    ['ashore', ['The sailors came ashore at dawn.', '水手們在黎明時上岸。']],
  ]);
  const pronouns = new Set([
    'anybody',
    'anyone',
    'everybody',
    'everyone',
    'none',
    'ours',
    'ourselves',
    'someone',
    'themselves',
    'whoever',
    'yours',
    'yourself',
  ]);

  const fixed = fixedFunctionExamples.get(word);
  if (fixed) {
    return fixed;
  }

  if (prepositions.has(word)) {
    const zhPrepositions = new Map([
      ['above', '在盒子上方'],
      ['across', '在盒子對面'],
      ['along', '沿著盒子旁邊'],
      ['alongside', '在盒子旁邊'],
      ['amid', '在盒子中間'],
      ['among', '在盒子之間'],
      ['amongst', '在盒子之間'],
      ['around', '在盒子周圍'],
      ['behind', '在盒子後面'],
      ['below', '在盒子下面'],
      ['beneath', '在盒子下面'],
      ['beside', '在盒子旁邊'],
      ['beyond', '在盒子另一邊'],
      ['inside', '在盒子裡'],
      ['onto', '到盒子上'],
      ['outside', '在盒子外面'],
      ['throughout', '遍布整個盒子'],
      ['underneath', '在盒子下面'],
      ['upon', '在盒子上'],
      ['within', '在盒子裡'],
    ]);
    return [`The keys are ${word} the box.`, `鑰匙${zhPrepositions.get(word) ?? `在盒子${zhHead}`}。`];
  }

  if (conjunctions.has(word)) {
    return [`${capitalize(word)} the task was hard, we finished it.`, `${zhHead}這件事很難，我們還是完成了。`];
  }

  if (pronouns.has(word)) {
    return [`${capitalize(word)} can join the meeting today.`, `${zhHead}今天都可以參加會議。`];
  }

  const templates = [
    [`The answer sounded clearer ${word} the final edit.`, `最後修改後，答案因${zhHead}而更清楚。`],
    [`The team used ${word} to connect two ideas.`, `團隊用${zhHead}連接兩個想法。`],
    [`The sentence felt natural with ${word} in the middle.`, `句子中間有${zhHead}時讀起來很自然。`],
    [`The message changed slightly after ${word} was added.`, `加上${zhHead}後，訊息稍微改變了。`],
  ];

  if (profile === 'motion') {
    return [`The path runs ${word} the old station.`, `這條路${zhHead}舊車站。`];
  }

  return pick(templates, word, index);
}

function articleFor(word) {
  if (word.endsWith('s') && !word.endsWith('ss')) {
    return '';
  }
  return /^[aeiou]/.test(word) ? 'an ' : 'a ';
}

function articleForAdjective(word) {
  return /^[aeiou]/.test(word) ? 'an ' : 'a ';
}

function capitalize(value) {
  return value.charAt(0).toUpperCase() + value.slice(1);
}

function pick(values, word, index) {
  return values[Math.abs(hashWord(`${word}:${index}:${values.length}`)) % values.length];
}

function hashWord(word) {
  let hash = 0;
  for (let index = 0; index < word.length; index += 1) {
    hash = (hash * 31 + word.charCodeAt(index)) | 0;
  }
  return hash;
}

function partOfSpeech(row) {
  if (row.pos?.trim()) {
    return row.pos.trim();
  }

  const translation = row.translation ?? '';
  const matches = Array.from(translation.matchAll(/(?:^|\\n|\n)([a-z]+)\./gi)).map((match) => match[1].toLowerCase());
  const unique = Array.from(new Set(matches)).slice(0, 3);
  return unique.length > 0 ? unique.join(' / ') : 'word';
}

function score(row) {
  const collins = Number(row.collins || 0);
  const oxford = Number(row.oxford || 0);
  const bnc = Number(row.bnc || 0);
  const frq = Number(row.frq || 0);
  const tagBonus = row.tag ? 5000 : 0;
  const frequencyScore = (bnc > 0 ? 700000 / bnc : 0) + (frq > 0 ? 900000 / frq : 0);
  return collins * 100000 + oxford * 80000 + tagBonus + frequencyScore;
}

function isUsableWord(row) {
  const word = row.word?.trim().toLowerCase() ?? '';
  const meaning = cleanMeaning(row.translation);

  return (
    /^[a-z]{2,18}$/.test(word) &&
    meaning.length >= 2 &&
    !meaning.includes('=') &&
    !meaning.includes('見 ') &&
    !meaning.includes('參見') &&
    !meaning.includes('同義詞')
  );
}

function toEntry(row, index) {
  const word = row.word.trim().toLowerCase();
  const reviewedExample = reviewedExamples.get(word);
  const override = seedOverrides.get(word);
  const meaningZh = override?.meaningZh ?? cleanMeaning(row.translation);
  const pronunciation = row.phonetic?.trim() ? `/${row.phonetic.trim()}/` : '/-/';
  const group = `Core ${Math.floor(index / 500) + 1}`;
  const partOfSpeechValue = partOfSpeech(row);
  const [example, exampleZh] = reviewedExample
    ? [reviewedExample.example, reviewedExample.exampleZh]
    : override
    ? [override.example, override.exampleZh]
    : generatedExample(row, word, partOfSpeechValue, meaningZh, index);

  return {
    id: `w${String(index + 1).padStart(4, '0')}`,
    word,
    partOfSpeech: partOfSpeechValue,
    pronunciation,
    meaningZh,
    example,
    exampleZh,
    group,
  };
}

if (!fs.existsSync(sourcePath)) {
  throw new Error(`Missing source CSV: ${sourcePath}`);
}

const csv = fs.readFileSync(sourcePath, 'utf8');
const rows = parse(csv, {
  columns: true,
  bom: true,
  relax_quotes: true,
  skip_empty_lines: true,
});

const usable = rows
  .filter(isUsableWord)
  .sort((a, b) => score(b) - score(a) || a.word.localeCompare(b.word));

const selectedRows = [];
const seen = new Set();

for (const seed of seedOverrides.keys()) {
  const row = usable.find((candidate) => candidate.word?.trim().toLowerCase() === seed);
  if (!row) {
    throw new Error(`Seed word missing from source: ${seed}`);
  }
  selectedRows.push(row);
  seen.add(seed);
}

for (const row of usable) {
  const word = row.word.trim().toLowerCase();
  if (seen.has(word)) {
    continue;
  }
  selectedRows.push(row);
  seen.add(word);
  if (selectedRows.length === TARGET_COUNT) {
    break;
  }
}

if (selectedRows.length !== TARGET_COUNT) {
  throw new Error(`Expected ${TARGET_COUNT} words, got ${selectedRows.length}`);
}

const entries = selectedRows.map(toEntry);
const output = `export type WordEntry = {
  id: string;
  word: string;
  partOfSpeech: string;
  pronunciation: string;
  meaningZh: string;
  example: string;
  exampleZh: string;
  group: string;
};

export const sampleWords: WordEntry[] = ${JSON.stringify(entries, null, 2)};
`;

fs.writeFileSync(outputPath, output, 'utf8');
console.log(`Generated ${entries.length} words at ${outputPath}`);
