import fs from 'node:fs';
import path from 'node:path';
import { describe, expect, test } from 'vitest';
import app from '../app.json';

const appPath = path.join(process.cwd(), 'App.tsx');
const submissionPath = path.join(process.cwd(), 'docs', 'app-store-submission.md');

describe('iOS App Store readiness polish', () => {
  test('asks for confirmation before deleting signed-in account learning data', () => {
    const appSource = fs.readFileSync(appPath, 'utf8');

    expect(appSource).toContain('Alert,');
    expect(appSource).toContain('function confirmDeleteAccountData()');
    expect(appSource).toContain('deleteAccountDataConfirmTitle');
    expect(appSource).toContain('deleteAccountDataConfirmText');
    expect(appSource).toContain('deleteAccountDataConfirmCancel');
    expect(appSource).toContain('deleteAccountDataConfirmAction');
    expect(appSource).toContain('Alert.alert(');
    expect(appSource).toContain('onConfirmDeleteAccountData={confirmDeleteAccountData}');
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

  test('reserves extra bottom room for iPhone home indicator and fixed tab bar', () => {
    const appSource = fs.readFileSync(appPath, 'utf8');
    const tabBarStart = appSource.indexOf('tabBar: {');
    const tabButtonStart = appSource.indexOf('tabButton:', tabBarStart);
    const tabBarSource = appSource.slice(tabBarStart, tabButtonStart);

    expect(appSource).toContain('WEB_TAB_BAR_BOTTOM_OFFSET');
    expect(appSource).toContain('NATIVE_TAB_BAR_BOTTOM_OFFSET');
    expect(appSource).toContain('WEB_IOS_PREVIEW_BOTTOM_SAFE_AREA');
    expect(appSource).toContain('IS_WEB_IOS_PREVIEW');
    expect(appSource).toContain('IOS_TAB_BAR_BOTTOM_OFFSET');
    expect(appSource).toContain('TAB_BAR_RESERVED_HEIGHT');
    expect(appSource).toContain('CONTENT_BOTTOM_PADDING');
    expect(appSource).toContain('paddingBottom: CONTENT_BOTTOM_PADDING');
    expect(appSource).toContain('style={[styles.appScroll, IS_WEB_IOS_PREVIEW && styles.webIosPreviewScroll]}');
    expect(tabBarSource).toContain("alignSelf: 'stretch'");
    expect(tabBarSource).toContain('borderTopWidth: 1');
    expect(tabBarSource).toContain('marginBottom: IOS_TAB_BAR_BOTTOM_OFFSET');
    expect(tabBarSource).toContain('paddingHorizontal: 16');
    expect(tabBarSource).not.toContain("position: 'absolute'");
    expect(tabBarSource).not.toContain('bottom: IOS_TAB_BAR_BOTTOM_OFFSET');
    expect(tabBarSource).not.toContain('borderRadius: 8');
    expect(tabBarSource).not.toContain('marginHorizontal: 16');
  });

  test('keeps the first iOS submission focused on iPhone instead of universal iPad support', () => {
    expect(app.expo.ios?.supportsTablet).toBe(false);
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
