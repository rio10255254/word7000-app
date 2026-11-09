# 單字貓（Word7000）宣傳短片

用 [Remotion](https://www.remotion.dev/) 寫成的直式（1080×1920、9:16、60 fps）宣傳片 `Full`，長 50 秒，重點放在 AI 與客製化。

兩支都以 1.2 倍慢速播放，輸出 60 fps，設定都在 `src/time.ts`：`SPEED` 控制速度，`OUTPUT_FPS` 控制輸出幀率。場景以 30 fps 的格數撰寫，`useFrame()` 會換算成放慢後、60 fps 的時間軸。剪接點、打字和動畫一起等比例變慢，同時多出中間格，所以動作更順。要改速度或幀率，只要改這兩個數字。

轉場參考 App 廣告的手法，不用硬切，而是依內容選擇（`src/transitions.tsx`）：
- 從小笨貓身上擴散的圓
- 帶動態模糊的推移
- 鏡頭推進穿過畫面
- 從「存入字庫」按鈕擴散的圓
- 往上推，像往下捲設定頁
- 從上方拉下的鎖定畫面
- 模糊淡出到片尾

AI 五段共用同一張桌面。「小笨貓會」固定不動，下一行在原地換成「講到你懂。→ 有問必答。→ 抓出錯在哪。→ 幫你改口說。→ 抓你的弱點。」，內容在下面橫向推移。

每一幕在動畫結束後多停 `HOLD` 格，再停到下一個強拍（`quantizeBeats`：每 2 拍，也就是小節的第 1 或第 3 拍）才轉場。轉場佔 1 拍（片尾 2 拍），兩幕在轉場期間重疊。表中的時間是該幕開始進場到完全離開。

## 配樂

`scripts/make-music.py` 會照 `src/timeline.json` 作出一首原創的**日落熱帶浩室**風格曲子，輸出到 `public/audio/full.mp3`。速度每分鐘 120 拍，降 B 大調，輕快有彈性。

**意象**：照著「陽光、棕櫚樹、紫色晚霞、美酒、沙灘」來設計。

| 意象 | 做法 |
| --- | --- |
| 陽光 | 真實高音直笛在高音域吹主旋律，副歌疊上鐵琴，副歌和主歌 B 每小節第一拍加一點鐵琴亮音 |
| 棕櫚樹 | 馬林巴用 3-3-2 的島嶼節奏彈和弦，主歌 B 起加入康加鼓和邦哥鼓 |
| 紫色晚霞 | 溫暖的合成器長音鋪底；和弦是 Gm7 → Ebmaj7 → B♭ → F（vi–IV–I–V），溫暖、帶點懷舊 |
| 美酒 | 旋律帶附點八分音符的回音，有微醺的飄浮感；熱帶浩室特有的「抽吸感」（大鼓一下，其他聲音就退一下） |
| 沙灘 | 前奏、鎖定畫面和片尾底下有真實的海浪聲（海洋鼓的錄音） |

**先寫一首歌，再讓畫面配合**：旋律和和聲是先寫好的一首流行歌，不是隨畫面拼湊出來的。

- **固定的和聲骨架**：每小節一個和弦，Gm7 → Ebmaj7 → B♭ → F（vi–IV–I–V，浩室和熱帶流行最常見的進行之一）一直循環，換場不會打斷它。導歌改走 Eb → F → Gm → F 往上推；副歌把循環走兩次，最後停在 B♭ 主和弦收住。
- **逐音寫好的旋律**，以四小節為一句：
  - 每一句都**由高往下走**：聽起來放鬆、有落地和解決的感覺，適合陽光、晚霞的氛圍。往上走會累積張力，所以只留給導歌。
  - 主歌：一個五聲音階的三音小動機「G F D」，問一句、答一句，一句唱兩次。第一次停在 C，像在提問；第二次落在 C A F，接著進導歌。主歌前若多出小節（小笨貓登場那一刻），那一小節只有伴奏、沒有旋律。
  - 導歌：用半速**預告副歌的 hook**（D — C — B♭），最後一小節 F E♭ D C 帶進副歌。
  - 副歌：hook 是三個音的小動機「D C B♭」，切分節奏，一小節重複兩次，第二次只改最後一個音；接著往上大跳到 F 再落下。兩小節一句，整句再唱一次，最後回到 B♭。**馬林巴在副歌裡和直笛一起唱 hook**（低八度），鋪底退到後面，這是熱帶浩室 drop 的典型做法。
  - 前奏：先由馬林巴彈出 hook，到副歌出現時，耳朵會覺得「是這個」。
- **為什麼這樣寫**：參考了流行 hook 好記的共通特徵和熱帶浩室的編曲做法，旋律全部是原創的：
  - 2～5 個音的小動機在短時間內重複，並做小變化（[Lost Stories Academy](https://loststoriesacademy.com/blogs-and-tutorials/why-some-melodies-stay-in-your-head-theory-behind-catchy-hooks)、[Samplesound](https://www.samplesoundmusic.com/blogs/news/melody-writing-tips-craft-memorable-and-catchy-tunes)）。
  - 音程小、輪廓簡單、多用級進（[ZME Science](https://zmescience.com/feature-post/culture/art/what-makes-a-song-catchy)）；旋律九成以上是五聲音階，和弦用完整音階。
  - 切分節奏，hook 早出現、一再回來（[Musician Wave](https://www.musicianwave.com/what-makes-a-song-catchy/)）。
  - 導歌半速預告 hook（[MusicRadar](https://www.musicradar.com/how-to/how-to-tease-a-melody-for-maximum-musical-impact)）。
  - drop 不靠爆發，而是讓馬林巴主奏 hook、重點放在律動上，偶爾一個大跳（[Native Instruments](https://blog.native-instruments.com/tropical-house/)、[jamburgr](https://jamburgr-web.pages.dev/library/tropical-house)）。
  - vi–IV–I–V 進行（[Unison](https://unison.audio/house-chord-progressions/)）。
- **段落對齊小節**：開啟副歌（掃描）、收小（鎖定畫面）和片尾的那三幕，會等到小節線才換場（`timeline.json` 的 `onBar`）。所以歌的段落和影片的段落會同時開始，旋律也不會在換場時被挖掉。
- **層次**：主歌唱第二次時加入一層；導歌把大鼓抽掉、拍手越拍越密；副歌最滿。這個做法參考了常見的編曲原則，例如 [Avid](https://www.avid.com/resource-center/arranging-music-guide)、[Orphiq](https://orphiq.com/resources/how-to-arrange-a-song)。

| 小節 | 段落 | 和弦 | 旋律 |
| --- | --- | --- | --- |
| 1–4 | 主歌 A | Gm7 Ebmaj7 B♭ F | G F D F G／G F D／B♭ G F D F／G F C |
| 5–8 | 主歌 B | 同上 | 同一句再唱一次，最後一小節改成 C A F |
| 9–12 | 導歌 | Ebmaj7 F Gm7 F | D — C — B♭／C — A — F／D — C — B♭／F E♭ D C |
| 13–19 | 副歌 | Gm7 Ebmaj7 B♭ F Gm7 Ebmaj7 B♭ | D C B♭ D C G／B♭ ↑F E♭ D／D C B♭ D C B♭／C A F A／（前兩小節再一次）／D C B♭ |
| 20–21 | 收小 | Gm7 Ebmaj7 | 輕聲再唱一次 hook 的第一小節，停在 B♭ |

**明亮但不刺耳**：人耳對 2～5 kHz 最敏感，直笛在高音區拉長音時，又會在 1～1.7 kHz 嗡嗡共振。所以旋律聲部的明亮感改從泛音和高頻空氣感來，不從刺耳的頻段來：

- **輕微飽和**：讓直笛長出比較豐富的泛音。
- **共振壓制**：只在 0.9～1.7 kHz 響得太大聲時自動往下壓，其他時候不動。
- **削掉刺耳頻段**：2.8 kHz 和 4 kHz 各挖掉一點。
- **補空氣感**：7.5 kHz 以上提起 5 dB。
- **加寬**：加一點立體聲合唱，讓旋律不要像一個點那樣刺。
- **回音調暗**：回音的高頻收掉一些。
- **鐵琴**：不再高八度疊奏整條旋律，只在副歌每小節第一拍點一下，並削掉 2.8 kHz。

**活潑**：
- 旋律的短音彈得短而跳。
- 吉他和貝斯從主歌一開始就有彈性。
- 主歌後半和副歌加入反拍的開放 hi-hat。
- 每四小節結尾加一段馬林巴快速上行。

**樂器與取樣**（都是真實錄音，授權詳見 `assets/` 各資料夾的 `CREDITS.md`）：
- 原聲吉他：[University of Iowa MIS](https://theremin.music.uiowa.edu/MIS.html)，可用於任何專案、沒有限制。主歌只在反拍輕輕上刷，副歌刷得最密。
- 高音直笛、鐵琴、馬林巴、康加鼓、邦哥鼓、海洋鼓：[VCSL](https://github.com/sgossner/VCSL)，CC0 授權。
- 合成的部分：鋪底、電貝斯、大鼓、拍手、沙鈴、鈴鼓。
- 免費又授權乾淨、而且每個音都錄好的人聲口哨取樣找不到，所以主旋律用音色最接近口哨的直笛。

**段落與層次**

| 段落 | 吉他與馬林巴 | 主旋律 | 貝斯與鋪底 | 鼓 |
| --- | --- | --- | --- | --- |
| 前奏（開場） | 吉他分解和弦，馬林巴預告主題 | — | 鋪底 + 海浪 | — |
| 主歌 A（小笨貓登場起，4 小節） | 反拍輕刷，馬林巴稀疏點綴 | 直笛主歌 | 長音 | 大鼓 1、3 拍，拍手，偶爾康加 |
| 主歌 B（再 4 小節） | 刷得更滿，馬林巴 3-3-2 | 主歌再唱一次 | 彈跳的節奏 | 四拍都有大鼓，康加、低音康加、邦哥 |
| 導歌（4 小節） | 一直下刷，馬林巴加密 | 半速預告 hook | 彈跳的節奏 | 抽掉大鼓，拍手越拍越密，加上漸強的掃頻 |
| 副歌（掃描起，7 小節） | 最密的刷奏，馬林巴和直笛一起唱 hook | hook 一句唱兩次再回家，鐵琴點綴每小節第一拍 | 八度跳音 | 最滿：再加高音康加和鈴鼓 |
| 收小（鎖定畫面） | 分解和弦 | 輕聲的 hook | 長音、鋪底 + 海浪 | 只剩一點沙鈴 |
| 片尾 | 一記慢慢掃過的 B♭ | hook 的最後一句落在 B♭，鐵琴往上的琶音 | 鋪底 + 海浪 | — |

**換場就是節奏點**：影片和配樂用同一套規則排時間，每次換場都從強拍開始，而且每次換場都會：
1. 換場前半拍，鼓全部停住。
2. 下一個和弦的刷奏反轉過來往上湧，帶進換場。
3. 換場那一拍，大鼓加低頻重擊一起落下。和弦照固定的骨架走，不會因為換場跳掉。

推移、圓形擴散、蓋章、點按鈕和通知的音效都壓得很輕。

**取樣出處**：所有取樣庫都不要求標示出處（吉他沒有限制，直笛、鐵琴、馬林巴、手鼓和海洋鼓都是 CC0），但片尾畫面底部仍有一行小字致謝吉他取樣的來源。詳見 `assets/` 裡各資料夾的 `CREDITS.md`。

改了 `timeline.json` 裡的場景長度或轉場，就重新產生配樂，再輸出影片：

```bash
npm run music    # 需要 python3、numpy、scipy、ffmpeg
npm run render   # 只輸出完整版
```

## 使用方式

```bash
cd promo
npm install
npm run studio   # 在瀏覽器即時預覽、拖時間軸
npm run render           # 輸出 out/word7000-full-60fps.mp4
npm run typecheck
```

在雲端容器或沒有下載 Chrome 的環境，可改用現有的 Chromium：

```bash
npx remotion render Full out/word7000-full-60fps.mp4 --browser-executable=/opt/pw-browsers/chromium
```

## 結構

- `src/Full.tsx`：影片的場景與段落；`src/scenes.tsx`：開場、認識小笨貓和片尾三幕。每一幕的長度寫在 `src/timeline.json`（以 30 fps 的格數計）。
- `src/kit.tsx`：共用的動態效果（模糊浮現、紙片貼上、蓋章、打字機）和元件，例如小笨貓對話泡泡 `CatSays`、紙條按鈕。
- `src/collage.tsx`：App「紙張拼貼」風格的素材，從 `ios/Word7000/Design/Collage.swift`（`claude/friendly-darwin-obc3r1` 分支）移植而來，包括方格紙、橫線索引卡（含紅色邊線）、紙膠帶、撕邊、網點、炭筆線圈和橡皮章。這個風格沒有陰影，靠紙張彼此重疊做出層次。
- `src/Mascot.tsx`：吉祥物「小笨貓」，從 `Mascot.swift` 逐個形狀移植成 SVG。有 idle、smug、happy、annoyed 四種表情，也會呼吸、眨眼、甩尾巴。
- `src/fonts.ts`：中文用 Noto Sans TC，英文單字用 Noto Serif（代替 App 裡的 New York 襯線字）。文案有改時要更新裡面的字表。
- `public/icon-collage.png`：拼貼風格的 App icon。`public/icon.png` 是皮革風格的 icon，`public/paper-grain.png` 是紙張紋理。

尺寸換算是「App 的 pt × 1080/402」，也就是把 402pt 寬的 iPhone 放大到 1080px。小笨貓的台詞都是 App 裡實際會出現的句子。

## 分鏡（50 秒、100 拍，Full）

小笨貓就是 App 裡所有線上 AI 回答的化身，所以 AI 的段落都由牠來說。文案、按鈕和台詞都取自測試版。

| 時間 | 段落 | 畫面 |
| --- | --- | --- |
| 0.0–3.5s | 開場 | 「又在滑手機？」小笨貓：「你滑手機的時間夠背十個字了。」 |
| 3.0–6.5s | 開場 | 「認識一下，小笨貓。」嘴有點壞的 AI 單字家教，蓋「AI 家教」印章 |
| 6.0–11.5s | AI | 「不懂？叫牠講到懂。」點「叫小笨貓解說」，小笨貓說明 attend 的用法和常見搭配 |
| 11.0–16.5s | AI | 「想問什麼，直接問。」點預設問題「常見的錯誤用法是什麼？」：✗ attend to the meeting／✓ attend the meeting |
| 16.0–20.5s | AI | 「答錯了，牠說你錯在哪。」點「小笨貓，我為什麼錯？」 |
| 20.0–25.5s | AI | 「開口說，AI 幫你改。」口說教練：錄音後顯示文字，AI 給出更自然的說法和提示 |
| 25.0–29.5s | AI | 「每天一次，牠幫你抓弱點。」學習分析：做得好的地方、要加油的字、接下來幾天 |
| 29.0–34.5s | 掃描 | 「課本單字表，拍一下就好。」手寫單字表掃描後，由 Apple Intelligence 整理並存入字庫 |
| 34.0–38.5s | 客製化 | 「你的 App，你的樣子。」皮革經典切換成紙張拼貼，圖示跟著換 |
| 38.0–43.5s | 客製化 | 「每個設定，都照你的。」每日目標、學習語言、朗讀語速、單字集、學習提醒 |
| 43.0–47.5s | 提醒 | 鎖定畫面中午 12:00 的即時動態：「單字不會自己背好喔」。小笨貓：「明天同一時間，我會來找你。」 |
| 47.0–50.0s | 片尾 | 拼貼版 icon、「單字貓」、「7000 單字」印章 |

AI 的回答內容（解說、錯誤用法、分析結果、口說建議）是為影片寫的示範，App 實際會由 Claude 依當下的字和紀錄產生。

## IG 日更短片（小笨貓日記）

每天一支 9:16、約 15 秒的短片，一支只講一件事。主角是小笨貓：牠用自己的聲音說話，App 的真實畫面一張張貼上桌面，最後一律停在同一張片尾，配上副歌 hook 的前三個音「D–C–B♭」當聲音 logo。

| 集 | 主題 | 開場標題 | 台詞 |
| --- | --- | --- | --- |
| #1 | 第一次認識單字貓（不配音） | 欸，又在滑手機喔？ | 欸，又在滑手機喔？／我是 SillyCat，專門盯你背單字。／對，App 裡真的會這樣嗆你。／7000 單字，我陪你背完。／明天見，敢放我鴿子試試看。 |
| #1 英文版 | 給說英文、想學台灣華語的人 | Hey. Scrolling again? | Hey. Scrolling again?／I'm SillyCat. I make sure you study.／Yep. The app really roasts you.／Taiwan Mandarin, one word at a time.／See you tomorrow. Don't you dare ghost me. |
| #2 | 每日目標 | 一天只背 7 個／就想睡？ | 才 7 個？笑死。／每天背幾個，是你自己訂的。／說好 20 個，還差 13 個。／別看我。去按「繼續學習」。 |
| #3 | 答錯的時候 | all 是什麼意思？／答錯會被貓念 | 考你一題：all 是什麼意思？／你選了「金屬的」？／那是 metallic 的意思。／all 是「所有的」。記好，我不想說第二次。 |

- **腳本**：`src/reels/episodes.json`。`text` 是字幕，`say` 是給語音念的寫法（數字寫成國字、「著」寫成「着」才會念 zhe）；`shot` 和 `crop` 指定要貼哪張 App 截圖的哪一塊（截圖的像素座標），`tap` 是點擊位置。
- **截圖**：`public/shots/`，取自 CI 自動拍的 `native-screenshots` 分支（iOS 26、紙張拼貼、淺色）。App 改版後換新截圖即可。
- **配音**：`scripts/make-voice.py`，用 [Kokoro-82M v1.1-zh](https://huggingface.co/hexgrad/Kokoro-82M-v1.1-zh)（Apache-2.0，可商用，CPU 就能跑）的 `zf_017` 聲音。每句都用 Whisper 語音辨識檢查過。
- **配樂與混音**：`scripts/make-reels.py` 依每句話的長度把台詞排到拍點上（120 bpm），用主題曲的樂器（吉他、馬林巴、貝斯、手鼓）做一段輕快的伴奏，小笨貓說話時伴奏自動退後，片尾響起聲音 logo。同時寫出 `src/reels/timing.json` 給影片用。
- **第 1 集的畫面**：`src/reels/Intro.tsx`，像一顆鏡頭在拍一支手機：從 App 今天頁角落的小笨貓特寫開始（背景景深模糊），拉遠看到整支手機和「單字貓」名牌，推近到牠嗆你的那句「才 7 個？笑死」，跟著點擊換頁進單字卡，最後小笨貓從手機裡跳出來，片尾從牠身上圓形展開。畫面上一次只有一件事，每個轉場都在拍點上。台詞只用字幕：固定在畫面下方，左上角一個「SillyCat」小標籤說明是誰在講話，用深色底和淺色字，跟後面淺色的 App 畫面分開；字一個一個浮現，重點詞（`**詞**`）用蜜桃色標出來。拉遠看整支手機時，手機會停在字幕上方，不會被字幕壓住。
- **英文版**（`ep01-en`）：同一支片，換成 App 的英文介面截圖。App 的英文介面只出現在「學中文」模式，所以英文版的對象是想學台灣華語的人：今天頁的小笨貓說「Only 7? LOL. 13 to go.」，單字卡是「這 zhè／this」，名牌是「WordCat・Learn Taiwan Mandarin」。英文單字不會在字中間斷行。
- **第 2、3 集的畫面**：`src/reels/Reel.tsx`（舊版樣式，之後會照第 1 集重做）。重要內容都避開 Instagram 上方約 220px、下方約 380px 和右側按鈕列。第一格就是封面：標題和小笨貓都已經在畫面上。

```bash
# 只有改台詞時才需要重新配音（Kokoro 需要 Python 3.10–3.12）
uv venv -p 3.12 .venv-voice
uv pip install --python .venv-voice/bin/python torch "kokoro>=0.9.4" "misaki[zh]" soundfile \
  "en_core_web_sm @ https://github.com/explosion/spacy-models/releases/download/en_core_web_sm-3.8.0/en_core_web_sm-3.8.0-py3-none-any.whl"
npm run voice
npm run reels          # 排時間、配樂、混音
npm run render:reels   # 輸出 out/reel-ep01.mp4 …
```

## 11/16 上架前導片（`Reel-teaser`）

給 WordCat Next（2.0.2）11/16 正式上架前用的前導片，約 27 秒。整支片只講一句話：「11/16，有隻嘴賤的貓要搬進你的手機。」底色用新圖示的橄欖綠，貓叫傻貓（SillyCat），臉照新版 App：挑眉、眨眼、吐舌頭（`Mascot` 的 `next` 與 `cheeky`）。

| 時間 | 畫面 | 字幕／聲音 |
| --- | --- | --- |
| 0–2s | 傻貓從右邊探頭斜眼看你，左上角貼著「11.16」（封面） | 欸，你。 |
| 2–6s | 牠跳出來，手機從下面升上來，牠飛進今天頁單字卡的角落 | 11/16，我要搬進你的手機。（配樂從這裡進來） |
| 6–12s | 一拍一個畫面：今天的路 → 翻卡 increase → 拼字打對 → 考題選錯「抓到了！」 | 每天一條路，走完就收工。 |
| 12–17s | 餐廳情境：App 裡真人錄音的「Hi, welcome! How many in your party?」，學生的「Just two, thanks.」和 100% 隨聲音出現 | 開口說，真人陪你練。 |
| 17–20s | 「今天的份完成！」印章重重蓋下、畫面一閃一震 | 蓋章那一下，會上癮。 |
| 20–22s | 傻貓從左邊探頭吐舌頭，後面的考題糊掉 | 背不起來？我會笑你。 |
| 22–27.5s | 新圖示、WordCat 單字貓、蓋上「11.16」、App Store 上架、聲音 logo | 追蹤我們，上架當天通知你。 |

- **畫面**：`src/reels/Teaser.tsx`；截圖是 `lab-native-store-screenshots` 分支裡 WordCat Next 的 App Store 截圖（`public/next/`），圖示是新版的橄欖綠圖示（`public/icon-next.png`）。
- **配音**：傻貓用 ElevenLabs 的「Yu 小宇」（年輕、有活力的台灣口音男聲）和 eleven_v4 模型，`say` 裡的 `[smug]` 之類的標籤只控制語氣、不會念出來。`scripts/make-voice-elevenlabs.py teaser` 產生 `public/reels/voice/teaser-*.mp3`；金鑰從 `ELEVENLABS_API_KEY` 或雲端環境的代理帶入。
- **App 裡的真人錄音**：餐廳情境的兩句來自 App 的 `Resources/ScenarioAudio`（ElevenLabs 錄製），放在 `public/next/`。
- **字幕**：有自己的一條帶子（畫面下方約 1452–1580px），手機在它上面就淡掉，所以字幕永遠在橄欖綠的底上，不會疊在 App 的文字上混在一起。字幕框是深色底、奶油色字，重點詞用蜜桃色。
- **英文版**（`Reel-teaser-en`）：給美國、加拿大想學台灣華語的人。畫面換成 App 的英文介面截圖，餐廳情境改放 App 裡的中文真人錄音（「歡迎光臨！請問幾位？」「兩位，謝謝。」），SillyCat 用 ElevenLabs 的「Callum」（沙啞、搗蛋鬼味道的美國男聲）。字幕：Hey. You.／11/16. I'm moving into your phone.／One short path a day. Then you're done.／Real voices. Real conversations.／That stamp? Addictive.／Forget a word? I'll laugh.／Follow us. We'll tell you when it's out.
- **兩個版本**：`npm run reels` 之後再跑 `python3 scripts/make-reels.py teaser --no-voice` 會多一個只有字幕（沒有傻貓配音）的混音 `teaser-novoice.mp3`，影片相同、只換聲音。

## 授權

小笨貓的配音由 Kokoro-82M（Apache-2.0）合成，不需標示。

Remotion 對個人與 3 人以下公司免費，規模更大需購買 Company License。
