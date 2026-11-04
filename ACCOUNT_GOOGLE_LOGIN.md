# Word7000 Google Login Setup

這份文件是 Word7000（單字貓）iOS App 用 Supabase 做帳號登入時，Supabase 和 Google Cloud 後台的設定清單。網頁版已經移除，不需要再設定 Cloudflare Pages。

目前 SwiftUI App 的登入入口是「使用 Apple 登入」。`Word7000Core` 已經有 Google 登入用的 Supabase OAuth 網址函式（`oauthURL`、`linkIdentityURL`），但 App 畫面還沒有使用；要開放 Google 登入時，照下面設定 Supabase 和 Google Cloud 即可。登入後，每個使用者的學習進度和自訂單字集會存到自己的帳號資料。

## 1. 建立 Supabase 專案

1. 到 Supabase 建立一個新專案。
2. 進入專案後，打開 SQL Editor。
3. 貼上並執行 `supabase/schema.sql`。
4. 這會建立 `profiles` 資料表，並限制每個使用者只能讀寫自己的進度和單字集資料。

## 2. 設定 Supabase 網址

在 Supabase 後台進入 Authentication settings。

Site URL 填 Cloudflare Worker 的網址：

```text
https://word7000-app.rio10255254.workers.dev
```

Redirect URLs 加入：

```text
https://word7000-app.rio10255254.workers.dev/**
word7000://auth/callback
```

這個 Worker 現在只放 `public/` 裡的幾個靜態檔（見 `README.md`），由 GitHub 推到 `master` 時自動部署，不再是網頁版 App。其中 `/auth-native.html` 是 iPhone 登入中繼頁（`AccountModel.redirectURL`），收到登入結果後立刻開啟 `word7000://auth/callback` 回到 App。Worker 網址的萬用路徑必須保留；`word7000://auth/callback` 建議保留作為備援。舊的 `*.pages.dev` 和 `localhost` 網址都是網頁版用的，可以從清單移除。

## 3. 建立 Google OAuth

1. 到 Google Cloud Console 建立或選擇一個專案。
2. 設定 OAuth consent screen。
3. 建立 OAuth Client ID，類型選 Web application（Google 會回到 Supabase，不是直接回到 App）。
4. Authorized JavaScript origins 不需要填；網頁版移除後，舊的 `*.pages.dev` 和 `localhost` 來源可以刪掉。
5. Authorized redirect URIs 填 Supabase 給你的 callback URL，格式通常是：

```text
https://YOUR_SUPABASE_PROJECT_REF.supabase.co/auth/v1/callback
```

6. 建立完成後，複製 Google Client ID 和 Client Secret。

## 4. 在 Supabase 打開 Google 登入

1. 回到 Supabase。
2. 進入 Authentication > Providers > Google。
3. 啟用 Google provider。
4. 貼上 Google Client ID 和 Client Secret。
5. 儲存。

## 5. 在 EAS 放 App 的 Supabase 設定

iOS App 在建置時從 Expo EAS 專案的 `production` 環境變數讀取 Supabase 設定，寫進 `ios/Word7000-Info.plist`（`AccountModel.bundledConfig()` 讀取）。在 expo.dev 的專案 > Environment variables > production 加入：

```text
EXPO_PUBLIC_SUPABASE_URL=https://YOUR_SUPABASE_PROJECT_REF.supabase.co
EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY=YOUR_SUPABASE_PUBLISHABLE_KEY
```

這兩個值可以在 Supabase Project Settings > API 找到。
如果你的 Supabase 後台顯示的是舊名稱 `anon public key`，也可以改用 `EXPO_PUBLIC_SUPABASE_ANON_KEY`。

設定完後，用 `ios-release.yml` 的 `native-testflight` 重新建置一次 App。Cloudflare 不需要任何環境變數。

## 6. 測試

1. 在 iPhone 安裝 TestFlight 上的最新版 App。
2. 進入「我的」頁面。
3. 用帳號登入（目前是「使用 Apple 登入」；開放 Google 登入後再測 Google）。
4. 登入完成後收藏幾個單字、做一題測驗。
5. 換另一台 iPhone，用同一個帳號登入。
6. 確認收藏、複習、連續天數、自訂單字集會同步。

## 7. 自訂單字集同步

如果你的 Supabase 專案是在自訂單字集功能完成前建立的，請回到 Supabase SQL Editor，再貼上並執行一次 `supabase/schema.sql`。

這次新增的雲端欄位會保存「我的單字集」、手動新增的單字，以及匯入的單字。沒有執行前，App 還是可以使用，但自訂單字集不會真正跨裝置同步。

## 8. 每日活躍用戶

重新執行 `supabase/schema.sql` 後，Supabase 會建立 `daily_active_users` 表。App 會在使用者登入後每 60 秒更新一次當天活動紀錄。

查今天活躍登入用戶：

```sql
select count(*) as today_active_users
from public.daily_active_users
where activity_date = current_date;
```

查最近 5 分鐘在線登入用戶：

```sql
select count(*) as online_users
from public.daily_active_users
where last_seen_at > now() - interval '5 minutes';
```

查過去 30 天每日活躍用戶：

```sql
select activity_date, count(*) as active_users
from public.daily_active_users
where activity_date >= current_date - interval '30 days'
group by activity_date
order by activity_date desc;
```

## 9. 注意

- 不要把 Google Client Secret 放進 GitHub。
- 不要把 Supabase service role key 放進 App 或 GitHub。
- App 只需要 `EXPO_PUBLIC_SUPABASE_URL` 和 `EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY`。舊專案如果只有 `anon public key`，可用 `EXPO_PUBLIC_SUPABASE_ANON_KEY` 代替。
- 如果 Google 登入完成後沒有回到 App，優先檢查 Supabase 的 Redirect URLs 和 Google 的 Authorized redirect URIs。

## 10. 官方文件

- Supabase Google login: https://supabase.com/docs/guides/auth/social-login/auth-google
- Supabase redirect URLs: https://supabase.com/docs/guides/auth/redirect-urls
- Google OAuth Client ID: https://developers.google.com/identity/gsi/web/guides/get-google-api-clientid
