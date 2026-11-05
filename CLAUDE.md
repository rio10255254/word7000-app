@AGENTS.md

# 語言

- 所有對使用者的回覆一律使用繁體中文（台灣用語）。思考過程不限語言。

# 測試

- 測試永遠只跑這次修改碰到的部分，包括發布前；使用者要求時才跑完整測試。
- iOS：Actions 的 Native iOS 用 `tests` 指定測試類別或方法（例如 `SpeakingCoachTests`、`LayoutTests/testMainScreensFitThisPhone`），或用對應的 `checks`（`compile`、`coach`、`layout`…）；`ios` 只選需要的版本，通常 `27`。只改設定或 widget、沒有對應 UI 測試時，跑 `compile` 就好。
- Node：只跑相關的測試檔，例如 `npx vitest run src/nativeSpeakingRecency.test.ts`。

# 兩條版本線（2026-11-05 起）

這個 repo 有兩條各自發 TestFlight 的線，兩條都是同一個 App（`com.rio.word7000`），共用使用者、進度和後端。

| 線 | 分支 | 版本號 | TestFlight 群組 |
|---|---|---|---|
| 正式線 | `master` | 2.x（目前 2.0.x） | `Wordcat Public Testing 1` |
| 研發線（WordCat Next） | `claude/wizardly-thompson-s0lgzj` | 3.x | `WordCat Lab` |

研發線的計畫在研發分支的 `docs/WordCat-Next.md`；它的追蹤 PR 是 rio10255254/word7000-app#58，**永遠不要合併它**。

**先判斷你在哪條線。** 任務提到 3.0、WordCat Next、研發版、Lab、挖空題、參考 Epop 的改造 → 研發線；其他 → 正式線。不確定就問使用者。

**研發線的工作**

- 從研發分支開始：`git fetch origin claude/wizardly-thompson-s0lgzj && git checkout -B <你的分支> origin/claude/wizardly-thompson-s0lgzj`。
- PR 的 base 設成 `claude/wizardly-thompson-s0lgzj`，不是 `master`。
- 新的學習規則只寫在 Swift（`Word7000Core`）和 Swift 測試，不再同時寫 `src/lib/` 的 TypeScript。

**合併方向只有一個：`master` → 研發分支**

- 正式線的修正（單字內容、後端、bug）要帶到研發線時，把 `master` 合進研發分支。版本號衝突時保留研發線的 3.x。
- 研發線的 `ios/Word7000/Resources/words.json` 多了挖空題用的中文提示詞（`content/example-cues.json`），合併時這個檔一定會衝突：隨便選一邊，再跑 `node scripts/export-native-words.mjs` 重新產生。它列出的「no longer match」提示詞，是例句被改過、要重新標註的字。
- 不要把研發分支合進 `master`，也不要把研發線的改動開 PR 到 `master`。唯一的例外是下面的「換線」，而且要使用者明確要求。

**版本號**

- `master` 永遠留在 3.0 以下；研發線用 3.x。
- 改版本要同時改 `ios/Release/app.json` 的 `version` 和 `ios/Word7000.xcodeproj/project.pbxproj` 的四個 `MARKETING_VERSION`。
- 建置號碼是每個版本各自從 1 開始（`scripts/next-build-number.mjs`），兩條線不會互搶。

**發 TestFlight**

- **研發線目前不發 TestFlight。** 要等正式線的 2.0.2 (8) 送審、上架告一段落，而且使用者明確說可以，才發第一個 3.x。
- GitHub Actions → `iOS release` → Run workflow，「Use workflow from」選要發的那條線的分支，operation 選 `native-testflight`。
- 正式線發給 `Wordcat Public Testing 1`；研發線發給 `WordCat Lab`（研發分支的發布流程預設就是它，群組不存在時會自動建立，並擋住 3.x 發給公開群組）。
- 送 App Store 審核只用正式線的 2.x 建置，直到換線。

**後端與遠端設定兩條線共用**

- `supabase/` 只從 `master` 部署。研發線需要的後端改動要寫成只新增、不改舊的，先合進 `master` 再部署。不要在研發分支上手動跑 `ai-backend.yml`；研發分支也不要改名成 `native/...`（那會自動部署後端）。
- 強制更新（`remote-force-update.yml`）和公告兩條線都收得到。3.0 上架前，強制更新的最低版本一定要低於 3.0，填 3.x 會把 App Store 上所有 2.x 使用者擋在外面，卻沒有新版可以更新。

**進度資料兩條線共用**

- 測試者可能從正式版換到研發版，又被換回來。研發線只能新增進度欄位，不能改舊欄位的意思或格式，也不做只能往前、不能往回的資料搬移。
- 研發線新增的資料要能承受被正式版寫回時弄丟。

**換線（研發版要上 App Store 時）**

- Apple 只要核准過某個版本，之後上傳的版本號（包括 TestFlight）都必須比它高。所以 3.0 一旦被 App Store 核准，2.x 就再也傳不上去，正式線就此結束。
- 步驟：使用者明確要求後，(1) 把研發分支合進 `master`，`master` 變成 3.x；(2) 從 `master` 送審 3.0；(3) 改寫這一節，標示研發線已併入、只剩一條線。
