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
