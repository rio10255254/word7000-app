# Word7000 Account Backend

## Current behavior

- First launch creates a temporary guest identity.
- Dictionary, study, and quiz remain available to guests.
- Custom sets and data import/export require Google, Apple, or email sign-in.
- A guest upgrade merges the device snapshot into the permanent account.
- Account deletion removes the Auth identity and all rows linked by cascade.

## Daily activity

Open the Supabase SQL editor and run:

```sql
select *
from word7000_private.daily_metrics
order by activity_date desc
limit 30;
```

The view reports total, guest, and registered daily active users. The database
derives account type from Auth; the app cannot choose or spoof that value.

## Deployment

```powershell
npx supabase db push --linked
npx supabase functions deploy delete-account --project-ref byyaepkhxexppjrdhcaw --use-api
```

Hosted Auth settings are managed separately from schema migrations. Compare
the complete remote diff before using `supabase config push`; never replace the
hosted site URL, redirect allow list, or provider settings with local defaults.

## Online AI (Groq)

The `ai` edge function answers every online AI feature in the iOS app: the
speaking coach, word explanations, quiz explanations, scan tidy-up and word
fill-in. The Groq key is a function secret and never ships in the app.

- Models: `openai/gpt-oss-120b` (strongest) and `openai/gpt-oss-20b` (second).
  Plus subscribers and the 7-day trial: coaching and explanations start on
  120B; scan, quiz and fill-in start on 20B. Free learners use 20B only.
- Tiers are decided on the server. Plus needs the StoreKit transaction the app
  sends, verified against Apple Root CA G3 (`entitlement.ts`); the trial is the
  first 7 days after a learner's first AI request (`word7000_private.ai_members`).
  A rate limit, outage, timeout or off-schema reply moves the request to the
  other model; if both fail the app uses Apple's on-device model.
- Prompts and JSON schemas live in `supabase/functions/ai/tasks.ts`; the app only
  sends data for a named task.
- Requests per UTC day, counted in `word7000_private.ai_usage`: `AI_FREE_LIMIT`
  (default 20) for free learners, `AI_PLUS_LIMIT` (default 100) for Plus and the trial.
- Deploy with the **AI backend** GitHub workflow. It needs the repository
  secrets `GROQ` (the Groq key), `SUPABASE_ACCESS_TOKEN` and `SUPABASE_DB_PASSWORD`.
  Or by hand:

```powershell
npx supabase db push --linked
npx supabase secrets set GROQ_API_KEY=... AI_FREE_LIMIT=20 AI_PLUS_LIMIT=100 --project-ref byyaepkhxexppjrdhcaw
npx supabase functions deploy ai --project-ref byyaepkhxexppjrdhcaw --use-api
```

- Turn online AI off for everyone without an app update: set the function
  secret `AI_DISABLED=true`, or publish `"cloudEnabled": false` in
  `public/ai-features.json`. The app then falls back to on-device AI.
