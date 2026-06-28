# Word7000 GitHub Cloud Sync Design

## Goal

Make Word7000 ready for a free public web launch with a fixed update path and per-user learning memory.

## Completion Standard

- The app can run without login and keep local progress in the browser.
- A user can sign up, sign in, sign out, and keep their own learning progress.
- When a signed-in user changes progress, the app saves it to Supabase.
- When the same user signs in again, the app restores their saved progress.
- The app exposes clear setup files for Supabase and Cloudflare Pages.
- The GitHub repository can be pushed and connected to Cloudflare Pages for automatic deployments.
- Tests, type checking, web build, and browser smoke checks pass before handoff.

## Recommended Architecture

Use GitHub for source control, Cloudflare Pages for free static hosting, and Supabase for Auth plus a small per-user progress table.

The 7000-word list stays bundled inside the app. Supabase stores only user identity and one progress record per user. This keeps hosting simple, avoids a word database migration, and makes updates fast because new app versions can ship through GitHub and Cloudflare without rewriting user data.

## User Experience

The app stays usable immediately. If the user does not sign in, progress is saved locally on the device browser. The Profile screen shows a simple account panel with email/password sign up, sign in, save state, and sign out.

After signing in, the app loads the user's saved progress from Supabase. If no cloud progress exists yet, the app uploads the current local progress as the first cloud copy. From that point, learning actions update the screen immediately and save in the background.

## Data Model

Supabase table: `profiles`

- `id`: user id from Supabase Auth
- `progress`: JSON object using the app's existing progress shape
- `updated_at`: last save timestamp

Security rule: each user can read and write only the row whose id matches their own login id.

## App Modules

- Progress helpers keep the existing word-state calculations.
- Local progress storage reads/writes the browser's local storage.
- Cloud progress storage reads/writes Supabase.
- Account UI collects email/password and shows save/sync state.
- Environment config reads public Supabase URL and anon key from Expo public env variables.

## Error Handling

If Supabase is not configured, account controls show setup is needed and the rest of the app continues in local-only mode.

If network saving fails, the screen keeps the local progress and shows a short sync message. The next progress change can retry.

If sign in fails, the account panel shows the error without losing local progress.

## Deployment Flow

Push the repository to GitHub. In Cloudflare Pages, connect the GitHub repository and set:

- Build command: `npm run build:web`
- Output directory: `dist`
- Environment variables:
  - `EXPO_PUBLIC_SUPABASE_URL`
  - `EXPO_PUBLIC_SUPABASE_ANON_KEY`

After this, GitHub pushes trigger Cloudflare rebuilds. The production URL stays fixed while app content updates.

## Testing

Add unit tests for progress serialization, local storage behavior, Supabase-disabled behavior, and account sync decisions. Keep existing word-data and web-launch tests.

Manual browser checks cover:

- opening the app
- studying a word
- favoriting/searching in the library
- seeing the account panel
- confirming local-only fallback when Supabase env is absent

