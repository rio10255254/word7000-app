@AGENTS.md

# 語言

- 所有對使用者的回覆一律使用繁體中文（台灣用語）。思考過程不限語言。

# 測試

- 測試永遠只跑這次修改碰到的部分，包括發布前；使用者要求時才跑完整測試。
- iOS：Actions 的 Native iOS 用 `tests` 指定測試類別或方法（例如 `SpeakingCoachTests`、`LayoutTests/testMainScreensFitThisPhone`），或用對應的 `checks`（`compile`、`coach`、`layout`…）；`ios` 只選需要的版本，通常 `27`。只改設定或 widget、沒有對應 UI 測試時，跑 `compile` 就好。
- Node：只跑相關的測試檔，例如 `npx vitest run src/nativeSpeakingRecency.test.ts`。

# 兩條版本線（2026-11-05 起，同日由使用者改定）

這個 repo 有兩條各自發 TestFlight 的線，兩條都是同一個 App（`com.rio.word7000`），共用使用者、進度和後端。

| 線 | 分支 | 版本號 | TestFlight | 送審 |
|---|---|---|---|---|
| 正式線 | `master` | 目前的版本（2.0.2） | 先只發 `Rio Testing`，使用者試過再自己加到其他群組 | 可以 |
| 研發線（WordCat Next） | `claude/wizardly-thompson-s0lgzj` | 跟正式線同一個版本號 | 先只發 `Rio Testing`；不進 `Wordcat Public Testing 1` | **永遠不送審** |

研發線的計畫在研發分支的 `docs/WordCat-Next.md`；它的追蹤 PR 是 rio10255254/word7000-app#58，**永遠不要合併它**。

**先判斷你在哪條線。** 任務提到 WordCat Next、研發版、挖空題、參考 Epop 的改造 → 研發線；其他 → 正式線。不確定就問使用者。

**研發線的工作**

- 從研發分支開始：`git fetch origin claude/wizardly-thompson-s0lgzj && git checkout -B <你的分支> origin/claude/wizardly-thompson-s0lgzj`。
- PR 的 base 設成 `claude/wizardly-thompson-s0lgzj`，不是 `master`。
- 新的學習規則只寫在 Swift（`Word7000Core`）和 Swift 測試，不再同時寫 `src/lib/` 的 TypeScript。

**合併方向只有一個：`master` → 研發分支**

- 正式線的修正（單字內容、後端、bug）要帶到研發線時，把 `master` 合進研發分支。
- 研發線的 `ios/Word7000/Resources/words.json` 多了挖空題用的中文提示詞（`content/example-cues.json`），合併時這個檔一定會衝突：隨便選一邊，再跑 `node scripts/export-native-words.mjs` 重新產生。它列出的「no longer match」提示詞，是例句被改過、要重新標註的字。
- 不要把研發分支合進 `master`，也不要把研發線的改動開 PR 到 `master`。唯一的例外是下面的「換線」，而且要使用者明確要求。

**版本號與建置號碼**

- 兩條線用同一個版本號，跟著 `master`：`master` 改版本時，把 `master` 合進研發分支，研發線不自己改版本。
- 改版本要同時改 `ios/Release/app.json` 的 `version` 和 `ios/Word7000.xcodeproj/project.pbxproj` 的四個 `MARKETING_VERSION`。
- 建置號碼兩條線共用、依序往上（`scripts/next-build-number.mjs` 從 App Store Connect 取下一個號碼），所以同一個版本底下會混著兩條線的建置。例如 2.0.2：(11) 是正式線，(12) 是研發線，正式線下一個是 (13)。

**發 TestFlight：新建置一律先只發 `Rio Testing`（2026-11-06 使用者改定）**

- 兩條線的每個新建置都只先發到內部群組 `Rio Testing`（使用者自己）。使用者自己試過沒問題，才**由使用者手動**在 App Store Connect 加到其他測試群組。
- 不要自動把建置加到其他群組，也不要用 API 或 `testflight-submit` 加，除非使用者明確要求。其他群組有：
  - `WordCat Internal`：內部群組，只收手動加入的建置。2026-11-06 取代了會自動收到所有建置的 `Word7000 Private Beta`。
  - `Wordcat Public Testing 1`：外部群組。
- 操作：GitHub Actions → `iOS release` → Run workflow，「Use workflow from」選要發的那條線的分支，operation 選 `native-testflight`，`testflight_group` 預設就是 `Rio Testing`，不用改。
- 研發分支的發布流程會擋住發給 `Wordcat Public Testing 1`，並在測試說明開頭加上「研發版」。

**送 App Store 審核：只用正式線的建置**

- 研發線的建置永遠不送審。送審前在 App Store Connect 確認選的建置是正式線發的：測試說明開頭寫「研發版」的就是研發線。
- 不確定某個建置號碼屬於哪條線，就問使用者。

**後端與遠端設定兩條線共用**

- `supabase/` 只從 `master` 部署。研發線需要的後端改動要寫成只新增、不改舊的，先合進 `master` 再部署。不要在研發分支上手動跑 `ai-backend.yml`；研發分支也不要改名成 `native/...`（那會自動部署後端）。
- 強制更新（`remote-force-update.yml`）和公告兩條線都收得到。

**進度資料兩條線共用**

- 測試者可能從正式版換到研發版，又被換回來。研發線只能新增進度欄位，不能改舊欄位的意思或格式，也不做只能往前、不能往回的資料搬移。
- 研發線新增的資料要能承受被正式版寫回時弄丟。

**換線（研發版要上 App Store 時）**

- 使用者明確要求後：(1) 把研發分支合進 `master`；(2) 從 `master` 發新的建置、送審；(3) 改寫這一節，標示研發線已併入、只剩一條線。
