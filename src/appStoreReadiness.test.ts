import fs from 'node:fs';
import path from 'node:path';
import { describe, expect, test } from 'vitest';
import app from '../app.json';

const appPath = path.join(process.cwd(), 'App.tsx');
const submissionPath = path.join(process.cwd(), 'docs', 'app-store-submission.md');

describe('iOS App Store readiness polish', () => {
  test('asks for confirmation before deleting signed-in account learning data', () => {
    const appSource = fs.readFileSync(appPath, 'utf8');
    const settingsRoute = fs.readFileSync(path.join(process.cwd(), 'src', 'app', 'settings.tsx'), 'utf8');

    expect(appSource).toContain('Alert,');
    expect(appSource).toContain('function confirmDeleteAccountData()');
    expect(appSource).toContain('deleteAccountDataConfirmTitle');
    expect(appSource).toContain('deleteAccountDataConfirmText');
    expect(appSource).toContain('deleteAccountDataConfirmCancel');
    expect(appSource).toContain('deleteAccountDataConfirmAction');
    expect(appSource).toContain('Alert.alert(');
    expect(settingsRoute).toContain('onConfirmDeleteAccountData={bridge.actions.confirmDeleteAccountData}');
    expect(appSource).toContain('onPress={onConfirmDeleteAccountData}');
  });

  test('keeps the Safari add-to-home-screen guide automatic flow web-only', () => {
    const appSource = fs.readFileSync(appPath, 'utf8');

    expect(appSource).toContain("Platform.OS === 'web' && !IS_WEB_IOS_PREVIEW && shouldShowInstallGuide");
    expect(appSource).toContain("const showWebInstallGuidePanel = Platform.OS === 'web' && !IS_WEB_IOS_PREVIEW;");
    expect(appSource).toContain('showWebInstallGuidePanel && (');
    expect(appSource).toContain('openInstallGuide()');
    expect(appSource).toContain('markInstallGuideSeen(getAppStorage(), isInstalledWebApp())');
  });

  test('uses the real iPhone safe area for the bottom tab bar', () => {
    const appSource = fs.readFileSync(appPath, 'utf8');
    const rootLayout = fs.readFileSync(path.join(process.cwd(), 'src', 'app', '_layout.tsx'), 'utf8');
    const tabBarStart = appSource.indexOf('tabBar: {');
    const tabButtonStart = appSource.indexOf('tabButton:', tabBarStart);
    const tabBarSource = appSource.slice(tabBarStart, tabButtonStart);

    expect(appSource).toContain('WEB_TAB_BAR_BOTTOM_OFFSET');
    expect(appSource).toContain('WEB_IOS_PREVIEW_BOTTOM_SAFE_AREA');
    expect(appSource).toContain('IS_WEB_IOS_PREVIEW');
    expect(appSource).toContain('IOS_TAB_BAR_BOTTOM_OFFSET');
    expect(appSource).toContain('useSafeAreaInsets');
    expect(appSource).toContain('safeAreaInsets.bottom');
    expect(rootLayout).toContain('<SafeAreaProvider>');
    expect(appSource).toContain('CONTENT_BOTTOM_PADDING');
    expect(appSource).toContain('paddingBottom: CONTENT_BOTTOM_PADDING');
    expect(appSource).toContain('style={[styles.appScroll, IS_WEB_IOS_PREVIEW && styles.webIosPreviewScroll]}');
    expect(tabBarSource).toContain("alignSelf: 'stretch'");
    expect(tabBarSource).toContain('borderTopWidth:');
    expect(tabBarSource).not.toContain('marginBottom: IOS_TAB_BAR_BOTTOM_OFFSET');
    expect(tabBarSource).toContain('paddingHorizontal: 16');
    expect(tabBarSource).not.toContain("position: 'absolute'");
    expect(tabBarSource).not.toContain('bottom: IOS_TAB_BAR_BOTTOM_OFFSET');
    expect(tabBarSource).not.toContain('borderRadius: 8');
    expect(tabBarSource).not.toContain('marginHorizontal: 16');
  });

  test('keeps the first iOS submission focused on iPhone instead of universal iPad support', () => {
    expect(app.expo.ios?.supportsTablet).toBe(false);
  });

  test('keeps the native launch screen visible until local app data is ready', () => {
    const appSource = fs.readFileSync(appPath, 'utf8');
    const layoutSource = fs.readFileSync(path.join(process.cwd(), 'src', 'app', '_layout.tsx'), 'utf8');
    const nativeSplashSource = fs.readFileSync(path.join(process.cwd(), 'src', 'lib', 'nativeSplash.native.ts'), 'utf8');

    expect(app.expo.plugins).toContainEqual([
      'expo-splash-screen',
      expect.objectContaining({ backgroundColor: '#2d64e7', image: './assets/splash-icon.png' }),
    ]);
    expect(layoutSource).toContain('prepareNativeSplash();');
    expect(nativeSplashSource).toContain('preventAutoHideAsync');
    expect(nativeSplashSource).toContain('fade: true');
    expect(appSource).toContain('hideNativeSplash();');
    expect(appSource).toContain('storageReady && (bundledVocabulary || vocabularyLoadFailed)');
  });

  test('includes a launch-ready App Store submission checklist', () => {
    expect(fs.existsSync(submissionPath)).toBe(true);

    const submission = fs.readFileSync(submissionPath, 'utf8');
    expect(submission).toContain('Word7000');
    expect(submission).toContain('Subtitle');
    expect(submission).toContain('Keywords');
    expect(submission).toContain('Privacy Policy URL');
    expect(submission).toContain('Support URL');
    expect(submission).toContain('Support Email');
    expect(submission).toContain('rio10255254@gmail.com');
    expect(submission).toContain('Review Notes');
    expect(submission).toContain('Demo Account');
    expect(submission).toContain('Screenshot Checklist');
    expect(submission).toContain('Account Deletion');
  });
});
