import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';

const source = process.argv[2];
if (!source) throw new Error('Pass the reviewed w0001-w0100 source JSON path.');
const original = fs.readFileSync(source);
const input = JSON.parse(original);
const vocabulary = JSON.parse(fs.readFileSync('ios/Word7000/Resources/words.json', 'utf8'));
const byWord = new Map(vocabulary.map(word => [word.word.toLowerCase(), word]));

// First variants of these 100 records were read together with both answers.
// Sense labels are explicit: an incidental Chinese word is not a valid match.
const keywords = {
  adapt:'適應', brief:'簡短', contrast:'對比', expand:'擴展', precise:'精確', be:'成為', and:'和', of:'的', to:'到',
  have:'有', for:'為了', that:'那個', he:'他', you:'你', with:'和', on:'上面', do:'做', not:'不', they:'他們', this:'這個',
  at:'在', say:'說', but:'但是', by:'旁邊', we:'我們', his:'他的', from:'從', or:'或', as:'視為', what:'什麼',
  their:'他們的', would:'會', go:'去', which:'哪一個', get:'變得', if:'如果', all:'所有', her:'她', there:'那裡', one:'一個',
  my:'我的', time:'時間', about:'關於', year:'年', when:'當…時', see:'看到', some:'一些', think:'認為', into:'變成', could:'可以',
  out:'出去', people:'人', your:'你的', come:'來', its:'它的', then:'然後', now:'現在', other:'其他', more:'更多', than:'比',
  like:'喜歡', no:'不', how:'怎麼', also:'也', first:'第一', look:'看', give:'給', our:'我們的', only:'只能', new:'新的',
  way:'方法', want:'想要', good:'好', day:'一天', very:'非常', man:'男人', any:'任何', find:'找', because:'因為', many:'許多',
  thing:'東西', should:'應該', here:'這裡', tell:'告訴', them:'他們', back:'回去', after:'之後', through:'穿過', child:'孩子', between:'之間',
  over:'超過', woman:'女性', still:'仍然', life:'生活', work:'工作', too:'太', become:'成為', need:'需要', world:'世界', own:'自己的',
};

const fixes = {
  contrast: {
    answerEn:'My weekdays are packed with classes and deadlines. In contrast, my weekends are slower and more flexible.',
    answerZh:'我的平日忙著上課和趕作業。週末則步調較慢、安排也比較自由，和週間形成明顯的對比。',
  },
  expand: {
    question:'What would you like to learn to expand your knowledge?',
    answerEn:'I would like to learn some astronomy to expand my knowledge of the night sky. Then I could recognize more stars on camping trips.',
    answerZh:'我想學一點天文學，擴展自己對夜空的了解。這樣露營時，就能認出更多星星。',
  },
  precise: {answerZh:'指路或告知開會時間時，資訊精確很重要。一個小錯誤，就可能讓人遲到或走錯地方。'},
  to: {
    answerEn:'I would like to walk to a quiet cafe or a park. Getting away from my usual desk helps me relax.',
    answerZh:'我想散步到安靜的咖啡廳或公園。離開平常工作的書桌，能讓我放鬆心情。',
  },
  have: {
    question:'What useful things do you always have in your bag?',
    answerEn:'I always have a water bottle and a small notebook in my bag. They are useful when I am out for the day.',
    answerZh:'我的包包裡總是有水壺和一本小筆記本。出門一整天時，它們都很實用。',
  },
  for: {
    question:'What are you preparing for this month?',
    answerEn:'I am preparing for a short trip with my family. I am checking train times so we do not have to rush on the day.',
    answerZh:'為了這個月的家庭小旅行，我正在做準備。我會先查好火車時刻，這樣出發當天就不用趕時間。',
  },
  that: {
    question:'Someone points to a place in your town. What could you tell them about that place?',
    answerEn:'That park has a lovely walking path by the river. I often go there in the evening when the weather is cooler.',
    answerZh:'那個公園有一條很漂亮的河濱步道。傍晚天氣比較涼的時候，我常去那裡散步。',
  },
  you: {answerZh:'我會在重要日子的前一晚準備好包包、確認行程，讓自己更安心。你也可以透過事先準備，減少臨時狀況帶來的壓力。'},
  with: {answerZh:'想放鬆時，我喜歡和不用凡事比較的人相處。跟他們在一起，我可以安靜，也可以開點玩笑，不必擔心被批評。'},
  on: {answerZh:'讀書時，我通常把筆記本、筆和水放在桌子上面。桌面上多餘的東西太多，我就容易分心。'},
  at: {
    question:'Where do you usually meet a friend before going out together?',
    answerEn:'We usually meet at the station near my home. It is easy to find, and we can take the train from there.',
    answerZh:'我們通常在我家附近的車站碰面。那裡很好找，也方便一起搭火車出發。',
  },
  by: {
    question:'Where would you choose to sit in a cafe, and why?',
    answerEn:'I would sit by the window because I like natural light. I can also watch people walking past while I drink my coffee.',
    answerZh:'我會坐在窗戶旁邊，因為我喜歡自然光。喝咖啡時，也可以看看外面經過的人。',
  },
  his: {answerZh:'他的優點之一是有耐心。即使氣氛緊張，他也願意仔細聽別人說話。'},
  or: {
    answerEn:'I prefer to study alone when I am reading or writing. When I get stuck, I like to discuss the problem with a classmate.',
    answerZh:'閱讀或寫作時，我比較喜歡自己讀書。遇到卡住的地方，我則喜歡找同學討論。',
  },
  what: {
    question:'How do you decide what to do first on a busy morning?',
    answerEn:'I write down what needs to be finished that day. Then I choose the task with the nearest deadline.',
    answerZh:'我會先寫下今天需要完成什麼，再選出截止時間最近的那件事。這樣比較容易安排順序。',
  },
  go: {answerZh:'想整理思緒時，我喜歡去外面隨意走走。走動一下，往往能讓原本糾結的想法慢慢清楚。'},
  which: {
    question:'What would you ask before choosing between several courses?',
    answerEn:'I would ask which course suits a beginner. I would also check which one fits my schedule.',
    answerZh:'我會先問哪一個課程適合初學者，再看看哪一個比較符合我的時間安排。',
  },
  get: {
    question:'What would you like to get better at this year?',
    answerEn:'I want to get better at cooking. If I learn a few simple dishes, I can make dinner without relying on takeout.',
    answerZh:'我想讓自己的廚藝變得更好。學會幾道簡單的菜，就不用每次晚餐都靠外帶。',
  },
  all: {answerZh:'當所有事情都很急時，我會先把它們寫下來，再決定從哪一件開始。列出清單後，就比較能看清楚該怎麼安排。'},
  my: {
    question:'What part of your daily routine do you value most?',
    answerEn:'I value my quiet time before bed. It gives me a chance to put my thoughts in order and sleep more peacefully.',
    answerZh:'我很珍惜睡前屬於我的安靜時間。這段時間讓我整理思緒，也睡得更安穩。',
  },
  time: {answerZh:'沒有事情要趕的時候，我喜歡放慢步調，自己安排時間。我可能會閱讀、散步或整理房間，不必一直看時鐘。'},
  about: {answerZh:'關於學習習慣，我可以聊很久。我喜歡想想哪些習慣有效、哪些行不通，以及背後的原因。'},
  into: {answerZh:'每晚寫一句話，慢慢就能變成穩定的習慣。這個起點很小，容易做到，也比較能持續下去。'},
  out: {
    answerEn:'When I feel burned out, I step out for a short walk and take a break from my screen. A little fresh air helps me feel refreshed.',
    answerZh:'覺得筋疲力盡時，我會走出去散步，暫時離開螢幕。呼吸一點新鮮空氣，能讓精神恢復一些。',
  },
  your: {
    question:'What advice would you give a friend who is nervous before an exam?',
    answerEn:'Prepare your notes the night before and get enough sleep. Give yourself a little extra time in the morning so you do not feel rushed.',
    answerZh:'前一晚先整理好你的筆記，也要睡飽。早上多留一點時間給自己，就比較不會手忙腳亂。',
  },
  other: {answerZh:'和其他我認識的人相比，我需要更多安靜的時間。我也喜歡和人相處，但社交活動太密集時就容易累。'},
  than: {
    question:'Which place is better for studying: your home or a library?',
    answerEn:'The library is quieter than my home. I can concentrate for longer because there are fewer interruptions.',
    answerZh:'圖書館比我家安靜。因為比較少被打斷，我能專心更久。',
  },
  how: {
    answerEn:'I first learn how to do one small part of the skill. Once I understand that part, I add another step and keep practicing.',
    answerZh:'我會先學會其中一小部分該怎麼做，理解之後再多加一個步驟，繼續練習。',
  },
  look: {
    question:'What do you check before choosing a place to study?',
    answerEn:'I look at the lighting and tables first. A bright space with a comfortable seat helps me concentrate.',
    answerZh:'我會先看看燈光和桌椅。光線充足、座位舒服的地方，能讓我比較專心。',
  },
  give: {answerZh:'我會給剛進新學校或新公司的人一個建議：有問題早點問，也多觀察大家怎麼做事。了解環境後，就能少犯一些小錯。'},
  new: {answerZh:'我想養成一個新的習慣，每天晚上複習筆記。這樣就能及早消化內容，不會越積越多。'},
  want: {answerZh:'我想要更了解自己為什麼會逃避一些重要的事。找出原因之後，也許就比較容易改變這個習慣。'},
  any: {
    question:'How would you help a friend if you did not have any free time that day?',
    answerEn:'If I did not have any free time, I would explain that honestly. I could offer to help the next day or suggest someone else to ask.',
    answerZh:'如果那天沒有任何空檔，我會坦白說明。我可以約隔天幫忙，或建議他找其他人問問。',
  },
  here: {
    question:'Someone visiting your neighborhood asks where to have lunch. What would you say?',
    answerEn:'There is a good noodle shop here, just around the corner. It serves a small menu, but everything is freshly made.',
    answerZh:'這裡轉角有一間不錯的麵店。菜單的選擇不多，但每一道都是現做的。',
  },
  back: {
    question:'Which place would you like to visit again on a future trip?',
    answerEn:'I would love to go back to the small town where my grandparents grew up. I want to walk through the old market again.',
    answerZh:'我想再回去祖父母長大的小鎮，重新逛逛那裡的老市場。',
  },
  after: {answerZh:'完成一件困難的事之後，我通常會先休息一下，再開始下一件。我需要一點時間讓思緒慢下來。'},
  through: {
    question:'What route would you recommend for a short walk near your home?',
    answerEn:'I would walk through the park and follow the path to the river. The trees provide shade, so it is pleasant even on a warm day.',
    answerZh:'我會先穿過公園，再沿著步道走到河邊。沿路有樹蔭，天氣暖的時候走起來也很舒服。',
  },
  between: {answerZh:'我會設定收工時間，讓工作和休息之間保持平衡。沒有這條界線，工作很容易占滿一整天。'},
  become: {answerZh:'五年後，我希望成為一個更穩定、對方向更有把握的人。我不求一切完美，但希望更相信自己。'},
};

const extra = [
  ['political','政治','What political issue most affects daily life in your community?','Housing is an important political issue in my city. I would like local leaders to explain how they plan to make rent more affordable.','在我住的城市，居住問題是很重要的政治議題。我希望地方首長能說明，打算怎麼讓租金更容易負擔。'],
  ['environment','環境','What is one change that could improve the environment in your neighborhood?','Planting more trees could improve the environment around my apartment. They would provide shade and make summer walks more comfortable.','多種一些樹，能改善我家附近的環境。有了樹蔭，夏天散步也會舒服一點。'],
  ['technology','科技','What technology has made an everyday task easier for you?','Navigation technology makes it easier for me to travel to unfamiliar places. I still check the route before leaving so I understand where I am going.','導航科技讓我更容易到不熟悉的地方。不過出發前，我還是會先看過路線，知道自己要往哪裡走。'],
  ['opportunity','機會','What opportunity would you like to try, even if it feels a little intimidating?','I would like an opportunity to speak at a local event. I might feel nervous, but it would help me practice sharing my ideas.','我想找個機會在社區活動中上台分享。雖然可能會緊張，卻能練習把自己的想法說出來。'],
  ['challenge','挑戰','What challenge have you learned to handle better recently?','Cooking dinner after a busy day used to be a challenge for me. Preparing a few ingredients on Sunday has made it much easier.','忙了一天還要煮晚餐，以前對我是一大挑戰。現在我會先在星期天備好一些食材，平日就輕鬆多了。'],
  ['confident','有自信','What helps you feel confident before trying something new?','I feel more confident when I can practice the first step beforehand. I do not need to know everything, but a little preparation helps.','事先練習過第一個步驟，我就會比較有自信。不必什麼都會，但做一點準備很有幫助。'],
  ['decision','決定','What decision do you like to discuss with someone before making it?','I like to discuss a big purchase before making a decision. Another person may notice a cost or problem that I have missed.','買比較貴的東西之前，我喜歡先和別人討論，再做決定。對方可能會注意到我漏看的費用或問題。'],
  ['responsibility','責任','What responsibility do you share with the people you live with?','Keeping the kitchen clean is a shared responsibility in our home. We take turns washing the dishes so one person does not have to do everything.','維持廚房清潔是我們共同的責任。我們輪流洗碗，讓家事不會全落在同一個人身上。'],
  ['reliable','可靠','What makes someone a reliable teammate?','A reliable teammate explains what they can do and follows through. If they need help or extra time, they tell the team early.','可靠的隊友會說清楚自己能做什麼，也會把答應的事做好。需要幫忙或更多時間時，他會提早讓大家知道。'],
  ['budget','預算','How would you plan a weekend outing on a small budget?','I would set a budget for food and transport first. Then I would choose a free activity, such as visiting a park or walking along the coast.','我會先訂好飲食和交通的預算，再選一個免費的活動，例如逛公園或到海邊散步。'],
  ['healthy','健康','What healthy habit is easy for you to keep on a busy day?','Taking a short walk after lunch is a healthy habit I can usually keep. It gives me a break from sitting and helps me feel refreshed.','午餐後散步一下，是我通常能維持的健康習慣。這讓我暫時離開座位，也能換個心情。'],
  ['curious','好奇','What are you curious about when you visit a new place?','I am curious about the food people eat every day. Visiting a small market often teaches me more than going straight to a famous restaurant.','到新的地方時，我很好奇當地人平常都吃什麼。逛逛小市場，往往比直接去知名餐廳更有收穫。'],
  ['patient','有耐心','When have you needed to be patient while helping someone learn?','I needed to be patient when I taught my grandfather to use a new phone. Repeating the steps slowly helped him feel comfortable asking questions.','教爺爺使用新手機時，我需要更有耐心。慢慢重複步驟，能讓他比較安心地提出問題。'],
  ['creative','有創意','How would you make a simple birthday gift feel personal?','I would try a creative gift, such as a small book of shared memories. A few photos and handwritten notes can make it feel special.','我會準備一份有創意的禮物，例如記錄共同回憶的小冊子。放幾張照片、寫些話，就能讓禮物很有心意。'],
  ['respect','尊重','How can people show respect when they disagree?','People can show respect by letting the other person finish speaking. They can explain a different view without making the disagreement personal.','意見不同時，可以先讓對方把話說完，表達尊重。說明自己的看法就好，不必把討論變成人身批評。'],
  ['community','社區','What would help newcomers feel welcome in your community?','A small welcome event could help newcomers meet people in the community. Sharing practical information about shops and transport would also be useful.','辦一場小型歡迎活動，可以幫助新住戶認識社區裡的人。分享附近商店和交通的實用資訊，也會很有幫助。'],
  ['improve','改善','What small change would improve your morning routine?','Getting my bag ready the night before would improve my morning routine. I could leave home calmly instead of searching for things.','前一晚先準備好包包，可以改善我早上的生活節奏。出門前就能從容一點，不用一直找東西。'],
  ['mistake','錯誤','How would you respond after sending someone the wrong information?','I would explain the mistake as soon as I noticed it. Then I would send the correct information and check whether they needed anything else.','發現錯誤後，我會盡快說明，再把正確資訊傳過去，也確認對方是否還需要其他協助。'],
  ['balance','平衡','How do you find a balance between making plans and leaving time to rest?','I find a balance by planning one main activity each day. I leave some free time around it so the day does not feel rushed.','我每天只安排一項主要活動，在規劃和休息之間取得平衡。前後留點空檔，一整天就不會太匆忙。'],
  ['experience','經驗','What experience changed the way you think about learning?','Helping a classmate was an important experience for me. Explaining a topic showed me which parts I understood and which parts I needed to review.','幫同學解惑是對我很重要的經驗。在說明的過程中，我會發現哪些地方真的懂了，哪些還需要複習。'],
];

const records = input.slice(0, 100).map(row => {
  const word = byWord.get(row.word.toLowerCase());
  if (!word || word.id !== row.id) throw new Error('Vocabulary changed: ' + row.id);
  const prompt = row.prompts.english[0];
  return {id:row.id + '-reviewed-1', word:row.word, keywordZh:keywords[row.word],
    question:prompt.question, answerEn:prompt.sampleAnswer, answerZh:prompt.sampleTranslationZh, ...fixes[row.word]};
});
for (const [word, keywordZh, question, answerEn, answerZh] of extra) {
  const entry = byWord.get(word);
  if (!entry) throw new Error('Unknown added word: ' + word);
  records.push({id:entry.id + '-reviewed-1', word, keywordZh, question, answerEn, answerZh});
}
const seen = new Set();
for (const record of records) {
  if (seen.has(record.id)) throw new Error('Duplicate prompt: ' + record.id);
  seen.add(record.id);
  if (!record.keywordZh || !record.question || !record.answerEn || !record.answerZh) throw new Error('Incomplete: ' + record.word);
  if (/\p{Script=Han}/u.test(record.question)) throw new Error('Mixed question language: ' + record.word);
  if (!record.answerEn.toLowerCase().split(/[^a-z']+/).includes(record.word.toLowerCase())) throw new Error('Missing English target: ' + record.word);
  if (!record.keywordZh.split('…').every(part => record.answerZh.includes(part))) throw new Error('Missing Chinese target: ' + record.word);
}
const destination = 'ios/Packages/Word7000Core/Sources/Word7000Core/Resources/speaking-prompts.json';
fs.mkdirSync(path.dirname(destination), {recursive:true});
fs.writeFileSync(destination, JSON.stringify({schemaVersion:1, reviewedAt:'2026-10-19', source:{file:path.basename(source),sha256:crypto.createHash('sha256').update(original).digest('hex')}, records},null,2)+'\n');
console.log(JSON.stringify({records:records.length,destination}));
