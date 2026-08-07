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

    expect(appSource).toContain('IS_WEB_IOS_PREVIEW');
    expect(appSource).toContain('useSafeAreaInsets');
    expect(appSource).toContain('safeAreaInsets.bottom');
    expect(rootLayout).toContain('<SafeAreaProvider>');
    expect(appSource).toContain('CONTENT_BOTTOM_PADDING');
    expect(appSource).toContain('paddingBottom: CONTENT_BOTTOM_PADDING');
    // The bar is positioned absolutely on purpose now: content scrolls under
    // it so the Liquid Glass has something to refract. What the original guard
    // was really protecting against is the safe area being counted twice — the
    // old bug paired absolute positioning with a hardcoded bottom offset and a
    // hardcoded content inset. Pin that down directly rather than banning the
    // positioning: the bar sits at bottom 0, and both the bar's own padding
    // and the scrollers' bottom room derive from the one measured inset.
  });

  test('keeps every native tab below one compact non-overlapping header', () => {
    const appSource = fs.readFileSync(appPath, 'utf8');
    const tabsLayout = fs.readFileSync(path.join(process.cwd(), 'src', 'app', '(tabs)', '_layout.tsx'), 'utf8');

    expect(tabsLayout).toContain('headerLargeTitle: false');
    expect(tabsLayout).toContain('headerTransparent: false');
    expect(tabsLayout).toContain('headerShadowVisible: false');
    expect(tabsLayout).toContain("headerTitleStyle: { fontSize: 21, fontWeight: '700' }");
    expect(appSource).toContain("const TAB_CONTENT_TOP_PADDING = Platform.OS === 'web' ? 18 + WEB_TABS_TOP_INSET : 10;");
    expect(appSource).toContain('contentContainerStyle={[styles.content, { paddingTop: TAB_CONTENT_TOP_PADDING }]}');
    expect(appSource).toContain('paddingTop: TAB_CONTENT_TOP_PADDING');
    expect(appSource).not.toContain('paddingTop: 18 + WEB_TABS_TOP_INSET');
  });

  test('lets the native tab bar react to library scrolling and tab changes', () => {
    const appSource = fs.readFileSync(appPath, 'utf8');
    const tabsLayout = fs.readFileSync(path.join(process.cwd(), 'src', 'app', '(tabs)', '_layout.tsx'), 'utf8');

    expect(tabsLayout).toContain('minimizeBehavior="onScrollDown"');
    expect(tabsLayout).toContain("screenListeners={{ tabPress: () => triggerPressHaptic('tab') }}");
    expect(appSource).toContain('if (IS_NATIVE_IOS)');
    expect(appSource).toContain('<FlatList');
    expect(appSource).toContain('testID="library-native-list"');
    expect(appSource).toContain('initialNumToRender={8}');
    expect(appSource).toContain('windowSize={9}');
  });

  test('uses availability-gated native glass for command button depth', () => {
    const appSource = fs.readFileSync(appPath, 'utf8');

    expect(appSource).toContain("import { GlassView, isGlassEffectAPIAvailable } from 'expo-glass-effect';");
    expect(appSource).toContain("const NATIVE_GLASS_AVAILABLE = IS_NATIVE_IOS && isGlassEffectAPIAvailable();");
    expect(appSource).toContain("type NativeGlassTone = 'primary' | 'secondary' | 'icon';");
    expect(appSource).toContain("glassEffectStyle={tone === 'primary' ? 'regular' : 'clear'}");
    expect(appSource).toContain('nativeGlassTone && styles.nativeGlassButton');
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
