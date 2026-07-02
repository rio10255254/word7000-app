# Word7000 iOS App Setup

This branch turns the existing Word7000 web app into a real iOS app while keeping `master` as the stable web version.

## Current iOS foundation

- The iOS branch is `ios-app`.
- The app uses the same Expo / React Native codebase as the web version.
- The iOS bundle id is `com.rio.word7000`.
- The native app URL scheme is `word7000`.
- The app is configured for Apple Sign In.
- EAS build profiles are defined in `eas.json`.
- Native storage is now prepared before the main app loads, so progress, filters, theme, study mode, and custom sets can persist on iPhone.
- Supabase Auth uses native session storage outside the web version.
- Google OAuth can use a native app callback URL.
- Apple Sign In is wired for iOS builds.

## Supabase redirect URLs to add

Add these in Supabase Auth settings before testing native social login:

- `word7000://auth/callback`
- your current web production URL
- your local web test URL when needed

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
