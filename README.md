# Word7000

Word7000 is a lightweight 7000-word English vocabulary web app for daily study, review, quiz practice, and personal progress memory.

## Run Locally

```powershell
npm install
npm run web
```

## Check Before Deploy

```powershell
npm test
npx tsc --noEmit
npm run build:web
```

## Account Memory

The app works without login and saves progress on the current device.

To enable account memory, create a Supabase project, run `supabase/schema.sql`, then set:

```text
EXPO_PUBLIC_SUPABASE_URL
EXPO_PUBLIC_SUPABASE_ANON_KEY
```

For Google sign-in setup, follow `ACCOUNT_GOOGLE_LOGIN.md`.

## Free Deployment

Use Cloudflare Pages with GitHub:

```text
Build command: npm run build:web
Output directory: dist
```

See `DEPLOY_FREE.md` for the full launch checklist.
