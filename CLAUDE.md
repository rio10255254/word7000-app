@AGENTS.md

# 語言

- 所有對使用者的回覆一律使用繁體中文（台灣用語）。思考過程不限語言。

# 測試

- 測試永遠只跑這次修改碰到的部分，包括發布前；使用者要求時才跑完整測試。
- iOS：Actions 的 Native iOS 用 `tests` 指定測試類別或方法（例如 `SpeakingCoachTests`、`LayoutTests/testMainScreensFitThisPhone`），或用對應的 `checks`（`compile`、`coach`、`layout`…）；`ios` 只選需要的版本，通常 `27`。只改設定或 widget、沒有對應 UI 測試時，跑 `compile` 就好。
- Node：只跑相關的測試檔，例如 `npx vitest run src/nativeSpeakingRecency.test.ts`。
