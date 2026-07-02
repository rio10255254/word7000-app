# Word7000 iOS App Setup

This branch turns the existing Word7000 web app into a real iOS app while keeping `master` as the stable web version.

## Current iOS foundation

- The iOS branch is `ios-app`.
- The app uses the same Expo / React Native codebase as the web version.
- The iOS bundle id is `com.rio.word7000`.
- The native app URL scheme is `word7000`.
- The app is configured for Apple Sign In.
- EAS build profiles are defined in `eas.json`.
- EAS build channels are set to `development`, `preview`, and `production`.
- Native storage is now prepared before the main app loads, so progress, filters, theme, study mode, and custom sets can persist on iPhone.
- Supabase Auth uses native session storage outside the web version.
- Google OAuth can use a native app callback URL.
- Apple Sign In is wired for iOS builds.
- The first App Store submission is iPhone-only to keep screenshots and review scope focused.
- Native EAS Update checks are wired in the app, but the EAS project still needs to be configured after logging in to Expo.
- Public privacy and support pages are included under the web host.
- Signed-in users can delete Word7000 cloud learning data from the app settings.

## Supabase redirect URLs to add

Add these in Supabase Auth settings before testing native social login:

- `word7000://auth/callback`
- your current web production URL
- your local web test URL when needed

## Supabase schema to apply

Run the SQL in `supabase/schema.sql` after pulling this branch. It now includes delete policies so a signed-in user can remove their own Word7000 learning data from the app settings.

## Google OAuth notes

The iOS app still uses Supabase as the auth broker. Google should redirect back through:

- `word7000://auth/callback`

If Google sign-in opens but does not return to the app, check Supabase redirect allow-list first.

## Apple Sign In notes

Apple Sign In is enabled in the Expo iOS config. Before App Store submission, also confirm:

- Apple Developer account is active.
- The App ID has Sign In with Apple capability.
- Supabase Apple provider is configured.
- The App Store privacy and account deletion requirements are ready.

## EAS Update notes

This machine was not logged in to Expo when the iOS branch was prepared, so the EAS project id and update URL could not be created automatically.

After logging in, run:

```bash
npx eas-cli@latest update:configure
```

That command should add the Expo project id and update URL to the app config. The build channels are already prepared in `eas.json`.

To publish a JavaScript/UI/data update after the first native build exists:

```bash
npx eas-cli@latest update --channel preview --message "Preview update" --environment preview
npx eas-cli@latest update --channel production --message "Production update" --environment production
```

## App Store pages

Current hosted page paths:

- Privacy policy: `/privacy.html`
- Support page: `/support.html`

Use the full deployed Cloudflare URL for App Store Connect.

## Build commands

Install EAS CLI if needed:

```bash
npm install -g eas-cli
```

Log in to Expo:

```bash
eas login
```

Create the first internal iOS test build:

```bash
eas build --platform ios --profile preview
```

Create the production App Store build:

```bash
eas build --platform ios --profile production
```

Submit the production build:

```bash
eas submit --platform ios --profile production
```

## Verification commands used on this branch

```bash
npm test
npx tsc --noEmit
npm run build:web
```
