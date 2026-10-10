# Releasing the native app

`.github/workflows/ios-release.yml` with `operation: native-testflight` copies
`ios/` into a clean folder, adds the files here, and runs `eas build` there
with `EAS_NO_VCS=1`. EAS signs with the distribution certificate and profile it
already stores for `com.rio.word7000`, continues the remote build numbers
(the React Native app ended at 25) and uploads to TestFlight with the stored
App Store Connect key.

- `app.json`, `eas.json`, `package.json`: the minimum EAS needs for a project
  that has its own `ios/` folder and no React Native.
- `Podfile`: EAS always runs `pod install`; the app has no pods, so this only
  creates the workspace EAS builds from.

The React Native app is unaffected: the repository root `.easignore` keeps
`/ios/` out of its uploads.
