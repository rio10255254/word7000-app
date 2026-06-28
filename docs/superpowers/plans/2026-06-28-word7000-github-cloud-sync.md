# Word7000 GitHub Cloud Sync Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add free web deployment readiness, GitHub publishing, and optional per-user cloud progress memory.

**Architecture:** Keep the word list inside the app, add a small account/sync layer, and store progress locally first with optional Supabase sync after login. Cloudflare Pages will build from GitHub and serve the static web app.

**Tech Stack:** Expo web, React Native Web, Vitest, Supabase Auth and database, GitHub, Cloudflare Pages.

---

### Task 1: Document Setup Surface

**Files:**
- Create: `supabase/schema.sql`
- Modify: `DEPLOY_FREE.md`
- Create: `.env.example`

- [ ] Add the Supabase SQL table and user-only security rules.
- [ ] Add the required public env variable names.
- [ ] Expand the deployment guide with GitHub + Cloudflare automatic deployment steps.

### Task 2: Add Storage and Sync Tests

**Files:**
- Create: `src/lib/progressStorage.test.ts`
- Create: `src/lib/supabaseProgress.test.ts`
- Modify: `src/lib/progress.test.ts`

- [ ] Test saving and loading progress from local storage.
- [ ] Test invalid stored progress falls back safely.
- [ ] Test Supabase disabled mode.
- [ ] Test cloud progress upsert/load behavior with a fake client.

### Task 3: Implement Storage and Supabase Modules

**Files:**
- Create: `src/lib/progressStorage.ts`
- Create: `src/lib/supabaseProgress.ts`
- Create: `src/lib/supabaseClient.ts`
- Modify: `package.json`

- [ ] Add `@supabase/supabase-js`.
- [ ] Add local progress read/write helpers.
- [ ] Add Supabase config detection and progress load/save helpers.
- [ ] Keep all helpers independent from React components so they stay testable.

### Task 4: Wire App State to Storage

**Files:**
- Modify: `App.tsx`

- [ ] Load local progress on startup.
- [ ] Save progress locally after learning actions.
- [ ] Add account state and signed-in progress loading.
- [ ] Sync progress after signed-in changes.
- [ ] Keep local-only mode working when Supabase is not configured.

### Task 5: Add Account UI

**Files:**
- Modify: `App.tsx`

- [ ] Replace the simple Profile placeholder with an account panel.
- [ ] Add email and password fields.
- [ ] Add sign up, sign in, sign out, and sync status.
- [ ] Keep the existing progress stats visible.

### Task 6: Verify and Publish Prep

**Files:**
- Modify as needed only if verification reveals issues.

- [ ] Run `npm test`.
- [ ] Run `npx tsc --noEmit`.
- [ ] Run `npm run build:web`.
- [ ] Serve `dist` locally and test core browser flow.
- [ ] Create or connect GitHub remote.
- [ ] Push the repository when the scope is clean and intended.

