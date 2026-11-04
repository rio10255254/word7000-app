# Word7000

Word7000 is a 7000-word English vocabulary app for iPhone. The app is the
native SwiftUI project in `ios/`; the earlier Expo / React Native app and its
web version have been removed.

## What lives where

- `ios/`: the SwiftUI app, its widget, the `Word7000Core` package and the UI
  tests. Release steps are in `ios/Release/README.md`.
- `src/data/words.ts`, `content/`: the reviewed word list and speaking
  content the native app is built from (`scripts/export-native-words.mjs`,
  `scripts/build-native-speaking-library.mjs`, `scripts/build-coach-evaluation.mjs`).
- `src/lib/`: the TypeScript learning rules (progress, study sessions, scan
  parsing, Chinese display, ...) that the Swift port follows. Their tests
  produce the golden results in `ios/Packages/Word7000Core` (see
  `src/nativeParity.test.ts` and `src/nativeParityChinese.test.ts`).
- `supabase/`: the account, AI and Live Activity backend.
- `public/`: the few static files the iOS app links to or fetches, served by
  the `word7000-app` Cloudflare Worker (`wrangler.jsonc`):
  - `/auth-native.html`: return page for Google / email sign-in; it opens
    `word7000://auth/callback`.
  - `/privacy.html`, `/support.html`: privacy policy and support pages (Me,
    paywall and the App Store listing).
  - `/ai-features.json`: remote switch for the AI features.
  - `/ios-update.json`: update prompt read by old React Native builds.

  Do not delete the Worker: the shipping app depends on these URLs under
  `https://word7000-app.rio10255254.workers.dev/`, and keep the Worker's Git
  connection: each push to `master` redeploys `public/`. `npm run build:web`
  only checks these files (there is nothing to build), then
  `npx wrangler deploy` uploads them.

## Checks

```bash
npm ci
npm run verify
```

`verify` runs the TypeScript tests (including the native parity and data
checks), the word-content audits and the type check. The native app is built
and tested by `.github/workflows/ios-native.yml`.

## Account setup

The app signs in through Supabase. In Supabase Auth settings keep these
redirect URLs allow-listed:

- `https://word7000-app.rio10255254.workers.dev/**` (for `/auth-native.html`)
- `word7000://auth/callback`

Google sign-in setup is in `ACCOUNT_GOOGLE_LOGIN.md`; the backend is described
in `supabase/ACCOUNT_BACKEND.md`.
