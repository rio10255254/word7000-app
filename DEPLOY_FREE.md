# Word7000 Free Web Deployment

## Current Status

The production web app is built in `dist` after running:

```powershell
npm run build:web
```

The upload-ready zip is:

`word7000-web-dist.zip`

## Recommended: GitHub + Cloudflare Pages

This keeps one public URL and updates the app every time the GitHub repository is pushed.

The current GitHub repository is private. Free GitHub Pages only publishes public repositories on the GitHub Free plan, so use Cloudflare Pages if the repository should stay private and the public app should still be free.

1. Push this project to GitHub.
2. Log in to Cloudflare.
3. Open Workers & Pages.
4. Create a Pages project.
5. Choose Connect to Git.
6. Select the Word7000 GitHub repository.
7. Use these build settings:

```text
Build command: npm run build:web
Build output directory: dist
Root directory: /
```

8. Add these environment variables in Cloudflare Pages:

```text
EXPO_PUBLIC_SUPABASE_URL
EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY
```

After this, pushing to GitHub triggers a new Cloudflare deployment. The automatic update only happens after Cloudflare Pages is connected to this GitHub repository with the Git integration. A GitHub push by itself does not update the public website unless Cloudflare is watching that repository.

For the mobile web app experience, the app checks `/version.json` when opened or resumed. When a newer deployment is available, users see an update prompt and can refresh into the latest version. Users who are actively using an already-open tab may not change screens instantly in the middle of a session, but the next open, resume, or refresh will detect the newer build.

## Supabase Account Memory Setup

1. Create a free Supabase project.
2. Open SQL Editor.
3. Run the SQL in `supabase/schema.sql`.
4. Open Project Settings > API.
5. Copy the Project URL into `EXPO_PUBLIC_SUPABASE_URL`.
6. Copy the Publishable key into `EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY`.
7. Add those values to Cloudflare Pages environment variables.

For local testing, create `.env.local` with the same two values.

If your Supabase project still shows the old `anon public key` label, use `EXPO_PUBLIC_SUPABASE_ANON_KEY` instead.

## Fallback: Cloudflare Pages Direct Upload

1. Create or log in to a free Cloudflare account.
2. Open Cloudflare Dashboard.
3. Go to Workers & Pages.
4. Create a Pages project.
5. Choose Direct Upload.
6. Upload `word7000-web-dist.zip` or the contents of the `dist` folder.
7. Cloudflare will give a free `*.pages.dev` URL.

## Option B: Cloudflare CLI Deploy

The CLI needs a Cloudflare API token in this non-interactive environment.

1. Create a Cloudflare API token with Pages deploy permission.
2. Set it in PowerShell:

```powershell
$env:CLOUDFLARE_API_TOKEN="your-token-here"
```

3. Deploy:

```powershell
cd C:\Users\Rio\word7000-app
npx --yes wrangler pages deploy dist --project-name word7000
```

## Rebuild Before Uploading

```powershell
cd C:\Users\Rio\word7000-app
npm test
npx tsc --noEmit
npm run build:web
```

## Official References

- Cloudflare Pages Git integration: https://developers.cloudflare.com/pages/configuration/git-integration/
- Supabase Auth: https://supabase.com/docs/guides/auth
- Supabase Row Level Security: https://supabase.com/docs/guides/database/postgres/row-level-security
- Supabase JavaScript client: https://supabase.com/docs/reference/javascript/installing
