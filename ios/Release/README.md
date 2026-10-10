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

The app and widget targets both declare the existing App Group
`group.com.rio.word7000` in their signing entitlements. Keep it when reusing
`com.rio.word7000.ExpoWidgetsTarget`: omitting it makes EAS try to disable the
group on Apple's registered identifier and blocks the release.

The Native iOS workflow checks iOS 18, 26, and 27 separately. Its screenshots
are saved in version-specific folders on the `native-screenshots` branch.

The React Native app is unaffected: the repository root `.easignore` keeps
`/ios/` out of its uploads.
