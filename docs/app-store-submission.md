# Word7000 App Store 送審清單（1.0 正式版）

正式版送審前逐項確認。標「需手動」的項目只能由帳號擁有者在各平台後台完成，程式碼與 CI 無法代勞。

## App 基本資料

- App 名稱：Word7000
- 副標題：Daily vocabulary practice
- 類別：教育（Education）
- Bundle ID：com.rio.word7000
- 最低系統：iOS 17.0（CI 在 iOS 17、18、26、27 上測試）
- 年齡分級：問卷照實回答。沒有公開的使用者內容、沒有不受限的網頁瀏覽、沒有成人內容。App 內有 AI 產生的學習說明（單字解說、口說建議），問卷若問到 AI 生成內容，請勾「有」並說明它只用於學習輔助。

## 描述（草稿）

Word7000 helps learners build a steady daily vocabulary habit with a focused 7000-word library, study cards, quizzes, review lists, custom word sets, and account sync.

Practice English vocabulary with Chinese explanations, or switch into the Learn Chinese course with pinyin and an English interface. Scan printed or handwritten word lists, practise speaking with a coach, and keep progress on every device after signing in.

Word7000 Plus (monthly or yearly auto-renewing subscription) unlocks word-list scanning, cloud sync across devices, full learning history, timed mock exams and deeper online AI answers. Payment is charged to your Apple Account; the subscription renews unless cancelled at least 24 hours before the end of the period, and can be managed in your Apple Account settings.

Terms of Use: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
Privacy Policy: https://word7000-app.rio10255254.workers.dev/privacy.html

> 訂閱制 App 的描述（或 App Store Connect 的 EULA 欄位）必須有使用條款連結，上面最後兩行請保留。

## 關鍵字

vocabulary, english, chinese, flashcards, quiz, word list, language learning, study, review, TOEIC, exam

## 宣傳文字

Build a daily word habit with study cards, quizzes, review lists, and custom vocabulary sets.

## 網址與聯絡方式

- 隱私權政策：https://word7000-app.rio10255254.workers.dev/privacy.html
- 支援網址：https://word7000-app.rio10255254.workers.dev/support.html
- 支援信箱：rio10255254@gmail.com

## 訂閱（App 內購買）

- 訂閱群組：Word7000 Plus
- 產品：`com.rio.word7000.plus.monthly`、`com.rio.word7000.plus.yearly`
- 7 天試用（最多掃描 5 次）由 App 自己計算，不需要購買、不會自動扣款；試用結束後功能回到免費版。Paywall 不使用「免費」字眼描述年方案（顯示「省 2 個月」）。
- Paywall 與設定頁都有「恢復購買」、使用條款、隱私權政策連結；設定頁有「管理訂閱」。

## 給審查人員的說明（Review Notes，英文貼上）

```
Word7000 works without an account: every learner starts as a guest.
Signing in (Sign in with Apple, Google, or email) is required for scanning
word lists and for the online AI features.

Demo account (email sign-in): <fill in before submission>
Password: <fill in before submission>
In the app: Me > Settings > Sign in or create an account > Use email.

Online AI: word explanations, questions about a word, quiz explanations,
scan tidy-up, learning insights and the speaking coach can use Anthropic's
Claude after the learner signs in and agrees in a consent prompt. Only the
text needed for the request is sent; recordings, photos, name and email are
not. Learners can decline or turn it off in Me > Settings > AI and recording,
and then the on-device model is used.

Word7000 Plus: monthly and yearly auto-renewing subscriptions, shown in the
Plus screen. New learners get a 7-day trial of Plus features inside the app
(up to 5 scans) with no purchase and no charge. Restore is on the Plus screen.

Account deletion: Me > Settings > Delete account and data. It permanently
deletes the account and its data on our server and, for Sign in with Apple,
revokes the app's Apple ID token.
```

- 需手動：在 Supabase 後台（Authentication > Users > Add user）建立一個已確認的 Email 帳號給審查用，把帳密填進上面的 Review Notes。不要用個人帳號。

## 帳號刪除

我的 > 設定 > 刪除帳號與資料。確認後刪除伺服器上的帳號、學習進度、字庫、每日紀錄、AI 使用次數、Plus 綁定與鎖定畫面提醒；若用 Apple 登入，同時向 Apple 撤銷授權（需完成下方「Sign in with Apple 金鑰」設定）。確認訊息會提醒刪除帳號不會取消 App Store 訂閱。

## App 隱私（營養標籤）

照下表填寫，與 App 內的 PrivacyInfo.xcprivacy 一致。所有項目「用於追蹤」都選「否」。

| 類型 | 項目 | 與身分連結 | 用途 |
| --- | --- | --- | --- |
| 聯絡資訊 | 電子郵件地址 | 是 | App 功能 |
| 聯絡資訊 | 姓名（Apple 登入時使用者選擇分享） | 是 | App 功能 |
| 識別碼 | 使用者 ID | 是 | App 功能 |
| 購買項目 | 購買記錄（訂閱交易編號） | 是 | App 功能 |
| 使用資料 | 產品互動（每日學習次數、AI 使用次數） | 是 | App 功能、分析 |
| 使用者內容 | 其他使用者內容（自訂字庫、送給線上 AI 的文字） | 是 | App 功能 |

不收集：位置、聯絡人、健康、財務資訊、瀏覽記錄、診斷資料、照片或錄音（照片與錄音都只在手機上處理）。

## 上架前需手動完成的設定

1. **App Store 伺服器通知**（需手動）：App Store Connect > App > 一般 > App 資訊 > App Store 伺服器通知，正式與沙盒網址都填
   `https://byyaepkhxexppjrdhcaw.supabase.co/functions/v1/app-store-notifications`，版本選 Version 2。設好後按「傳送測試通知」，Supabase 的函式紀錄應出現 `TEST`。退款或撤銷後 Plus 會在伺服器端立即失效。
2. **Sign in with Apple 金鑰**（需手動，審查準則 5.1.1(v)）：developer.apple.com > Certificates, Identifiers & Profiles > Keys 建立啟用 Sign in with Apple 的金鑰，下載 .p8。在 GitHub repo 的 Actions secrets 加入 `APPLE_TEAM_ID`、`APPLE_SIWA_KEY_ID`、`APPLE_SIWA_PRIVATE_KEY`（.p8 全文），再執行一次「AI backend」工作流程。沒設定時刪除帳號仍可運作，只是不會撤銷 Apple 授權，工作流程會顯示警告。
3. **Anthropic 費用上限**（需手動）：console.anthropic.com > Settings > Limits 設每月花費上限與用量通知。伺服器另有全站每日 20,000 次的硬上限（`AI_GLOBAL_DAILY_LIMIT`，可在工作流程手動執行時調整）。
4. **Supabase 驗證設定**（需手動）：
   - URL Configuration：正式環境移除 `http://localhost:8083/*`、`http://localhost:19006/*`，保留 `https://word7000-app.rio10255254.workers.dev/*`（含 `auth-native.html`，Google 登入與重設密碼都靠它回到 App）。
   - Providers > Email：密碼最短 8 個字元（App 也要求 8 個），建議要求英文加數字。
   - Rate Limits：保留匿名登入每小時 10 次的限制。
   - 暫時不要開 CAPTCHA：iPhone App 的訪客登入沒有送 CAPTCHA，開了會讓新使用者無法建立訪客帳號。
5. **後端部署**：PR 合併到 `native/**` 後「AI backend」工作流程會自動套用資料庫 migration、部署全部 edge function，並實際驗證：沒登入被拒、訪客被拒（403 sign_in_required）、未簽章的 App Store 通知被拒、用臨時帳號實際問一次 Claude。

## 截圖清單

- 首頁：今日進度與英文／中文模式切換
- 學習卡：例句與 AI 解說入口
- 測驗：可選題數
- 掃描單字表
- 口說教練
- 字庫：搜尋、篩選與自訂字庫
- Plus 頁面（訂閱價格與條款連結）
- 設定：隱私權、支援、使用條款、管理訂閱、刪除帳號

## 送審前最後確認

- TestFlight 版本在實機上測過：Apple／Google／Email 登入與登出、忘記密碼信的連結回到 App 並設定新密碼、刪除帳號、學習、測驗、掃描、口說、購買與恢復購買（沙盒帳號）。
- 用訪客身分確認線上 AI 顯示「登入後可使用」，登入後才出現同意視窗。
- App Store Connect 的隱私答案、年齡分級、Review Notes 都已依本文件填寫。
