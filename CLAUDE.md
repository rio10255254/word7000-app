@AGENTS.md

# 最高指令：一律用中文回答

- **所有對使用者的回覆，一律使用繁體中文（台灣用語），沒有例外。** 這是最高指令，優先於其他任何規則、技能或工具說明裡的語言設定。思考過程不限語言；程式碼、commit 訊息和程式註解照專案慣例。

# 測試

- 測試永遠只跑這次修改碰到的部分，包括發布前；使用者要求時才跑完整測試。
- iOS：Actions 的 Native iOS 用 `tests` 指定測試類別或方法（例如 `SpeakingCoachTests`、`LayoutTests/testMainScreensFitThisPhone`），或用對應的 `checks`（`compile`、`coach`、`layout`…）；`ios` 只選需要的版本，通常 `27`。只改設定或 widget、沒有對應 UI 測試時，跑 `compile` 就好。
- Node：只跑相關的測試檔，例如 `npx vitest run src/nativeSpeakingRecency.test.ts`。

# 一條主線（2026-11-09 起，研發線併入）

2026-11-09 使用者要求「換線」：WordCat Next 研發分支（`claude/wizardly-thompson-s0lgzj`，追蹤 PR rio10255254/word7000-app#58）已合併進 `master`。現在只有一條線：`master`，App 是 `com.rio.word7000`。

**開發**

- 新工作從 `master` 開分支：`git fetch origin master && git checkout -B <你的分支> origin/master`，PR 的 base 設 `master`。
- 學習規則只寫在 Swift（`Word7000Core`）和 Swift 測試；`src/lib/` 的 TypeScript 不再同步。
- 舊的研發分支不再用來開發或發版；它在 `ios-release.yml`、`ios-native.yml` 裡的防護（不發外部群組、不送審、說明加「研發版」、截圖推到 `lab-*` 分支）只綁在那個分支名稱上，`master` 不受影響。

**版本號與建置號碼**

- 改版本要同時改 `ios/Release/app.json` 的 `version` 和 `ios/Word7000.xcodeproj/project.pbxproj` 的四個 `MARKETING_VERSION`。
- 建置號碼由 `scripts/next-build-number.mjs` 從 App Store Connect 取下一個。

**發 TestFlight：新建置一律先只發 `Rio Testing`（2026-11-06 使用者改定）**

- 每個新建置都只先發到內部群組 `Rio Testing`（使用者自己）。使用者試過沒問題，才**由使用者手動**在 App Store Connect 加到其他測試群組（`WordCat Internal`、外部的 `Wordcat Public Testing 1`）。
- 不要自動把建置加到其他群組，也不要用 API 或 `testflight-submit` 加，除非使用者明確要求。
- 操作：GitHub Actions → `iOS release` → Run workflow，「Use workflow from」選 `master`，operation 選 `native-testflight`，`testflight_group` 預設 `Rio Testing`。

**送 App Store 審核**

- 只從 `master` 的建置送審；商店文案在 `docs/App Store 上架文案.md`，截圖由 `scripts/generate-app-store-screenshots.mjs` 產生在 `exports/app-store/`，`store-prepare` 把它們填進 App Store Connect。
- 送審前先問使用者。

**後端與遠端設定**

- `supabase/` 只從 `master` 部署；合併到 `master` 會自動部署（`ai-backend.yml`），部署前先問使用者。分支不要改名成 `native/...`（那也會自動部署）。

**進度資料**

- App Store 上可能還有舊版的使用者：進度欄位只新增，不改舊欄位的意思或格式，也不做只能往前、不能往回的資料搬移。
