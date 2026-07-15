# Word7000 Google Login Setup

這份文件是把 Word7000 的「使用 Google 快速登入」真正啟用到線上版的後台設定清單。

App 端已經會用 Supabase 開啟 Google 登入，並把每個使用者的學習進度和自訂單字集存到自己的帳號資料。你需要在自己的 Supabase、Google Cloud、Cloudflare Pages 後台完成下面設定。

## 1. 建立 Supabase 專案

1. 到 Supabase 建立一個新專案。
2. 進入專案後，打開 SQL Editor。
3. 貼上並執行 `supabase/schema.sql`。
4. 這會建立 `profiles` 資料表，並限制每個使用者只能讀寫自己的進度和單字集資料。

## 2. 設定 Supabase 網址

在 Supabase 後台進入 Authentication settings。

Site URL 填你的正式網址，例如：

```text
https://your-word7000-domain.pages.dev
```

Redirect URLs 至少加入：

```text
https://your-word7000-domain.pages.dev/*
https://your-custom-domain.com/*
word7000://auth/callback
http://localhost:8083/*
http://localhost:19006/*
```

如果你只用 Cloudflare Pages 網址，第二行自訂網域可以先不填。
正式網站會提供 `/auth-native.html` 作為 iPhone 登入中繼頁，收到登入結果後立刻開啟 `word7000://auth/callback` 回到 App。正式網址的萬用路徑必須保留；自訂 callback 則建議保留作為備援。

## 3. 建立 Google OAuth

1. 到 Google Cloud Console 建立或選擇一個專案。
2. 設定 OAuth consent screen。
3. 建立 OAuth Client ID，類型選 Web application。
4. Authorized JavaScript origins 加入：

```text
https://your-word7000-domain.pages.dev
https://your-custom-domain.com
http://localhost:8083
http://localhost:19006
```

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

## 5. 在 Cloudflare Pages 放環境設定

在 Cloudflare Pages 專案設定中加入 Production 和 Preview 環境變數：

```text
EXPO_PUBLIC_SUPABASE_URL=https://YOUR_SUPABASE_PROJECT_REF.supabase.co
EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY=YOUR_SUPABASE_PUBLISHABLE_KEY
```

這兩個值可以在 Supabase Project Settings > API 找到。
如果你的 Supabase 後台顯示的是舊名稱 `anon public key`，也可以改用 `EXPO_PUBLIC_SUPABASE_ANON_KEY`。

設定完後重新部署 Cloudflare Pages。

## 6. 測試

1. 用手機 Safari 開啟正式網址。
2. 進入「我的」頁面。
3. 點「使用 Google 快速登入」。
4. 登入完成後收藏幾個單字、做一題測驗。
5. 換另一台手機或另一個瀏覽器，用同一個 Google 帳號登入。
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
- Supabase JavaScript OAuth: https://supabase.com/docs/reference/javascript/auth-signinwithoauth
- Google OAuth Client ID: https://developers.google.com/identity/gsi/web/guides/get-google-api-clientid
