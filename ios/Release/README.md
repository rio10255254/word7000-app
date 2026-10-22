# Releasing the native app

`.github/workflows/ios-release.yml` with `operation: native-testflight` copies
`ios/` into a clean folder, adds the files here, and runs `eas build` there
with `EAS_NO_VCS=1`. EAS signs with the distribution certificate and profile it
already stores for `com.rio.word7000`, continues the remote build numbers
(the React Native app ended at 25) and uploads to TestFlight with the stored
App Store Connect key.

The workflow stages the next remote build number into the Xcode settings of
both shipping targets. The targets generate their Info.plist, so updating
only the plist through EAS leaves `CURRENT_PROJECT_VERSION` unchanged.
Before submitting, the workflow downloads the actual IPA and verifies the
app/widget versions, account configuration, signing groups, and all 7000
words against the source. A mismatched archive is never submitted.

- `app.json`, `eas.json`, `package.json`: the minimum EAS needs for a project
  that has its own `ios/` folder and no React Native.
- `Podfile`: EAS always runs `pod install`; the app has no pods, so this only
  creates the workspace EAS builds from.

The app and widget targets both declare the existing App Group
`group.com.rio.word7000` in their signing entitlements. Keep it when reusing
`com.rio.word7000.ExpoWidgetsTarget`: omitting it makes EAS try to disable the
group on Apple's registered identifier and blocks the release.

The Native iOS workflow checks iOS 18, 26, and 27 separately. Its screenshots
are saved in version-specific folders on the `native-screenshots` branch.

The React Native app is unaffected: the repository root `.easignore` keeps
`/ios/` out of its uploads.

## 2.0.1 experience candidate

Keep the pending 2.0.0 (36) App Store submission unchanged. This branch is a
separate TestFlight candidate, not an instruction to replace the review build.

The custom reminder-time picker is capability-gated. Deploy
`send-streak-live-activities` with its time-neutral title, then apply
`supabase/migrations/20261019150000_personal_reminder_time.sql`. Until that
migration is installed, the app omits the new field and preserves noon delivery.
The migration has been exercised locally with PostgreSQL-compatible PGlite,
including completed goals, disabled devices, account changes, repeated claims,
and invalid times. This does not claim the production backend was changed.

Native checks must cover: repeated card grading and swipes, session resume,
first five-word practice, exact search with a visible keyboard, 20-question
quiz navigation, and all five photo formats saved into a playable bank.
Inspect light/dark and both-language screenshots on iOS 18, 26, and 27 before
dispatching `native-testflight`.

## Speaking coach TestFlight preview

Rio authorized a TestFlight preview on 2026-10-22. Release from
`native/apple-speaking-coach`; do not merge it into `master` or replace the
formal App Store submission. The release must wait for a successful full
Native iOS push run of the same source, and the signed archive must exclude
both coach and recording test fixtures.

This preview adds optional local recording, playback, editable on-device
transcription, and Apple Intelligence speaking suggestions when available.
Recording and manual answers remain available without Apple Intelligence.
No cloud AI, new subscription promise, or answer-content analytics is enabled.
It also includes reviewed notes for 24 words, a seven-day summary, and practice
shortcuts. It does not claim expanded notes for all 7000 words.

The iOS 18, 26, and 27 targeted UI checks passed. Hosted test machines cannot
run the real Apple Intelligence model. TestFlight is therefore needed to
evaluate real speech transcription, suggestion quality, response time, audio
routing, and Siri on supported physical devices. The 200 evaluation inputs
validate request structure, not model accuracy or 200 independent learners.
