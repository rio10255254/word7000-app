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

    expect(appSource).toContain("Platform.OS === 'web' &&\n      !IS_WEB_IOS_PREVIEW &&\n      shouldShowInstallGuide(");
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
    expect(appSource).toContain('paddingBottom: CONTENT_BOTTOM_PADDING + bottomClearance');
    expect(appSource).toContain('Math.max(PROFILE_TAB_BAR_MIN_CLEARANCE, safeAreaInsets.bottom + 34)');
    expect(appSource).toContain('<TabScrollHost bottomClearance={bottomClearance} containOverscroll>');
    expect(appSource).toContain('paddingTop: TAB_CONTENT_TOP_PADDING');
    expect(appSource).not.toContain('paddingTop: 18 + WEB_TABS_TOP_INSET');
  });

  test('lets the native tab bar react to library scrolling and tab changes', () => {
    const appSource = fs.readFileSync(appPath, 'utf8');
    const tabsLayout = fs.readFileSync(path.join(process.cwd(), 'src', 'app', '(tabs)', '_layout.tsx'), 'utf8');

    expect(tabsLayout).toContain("performance.supportsLiquidGlass ? 'onScrollDown' : undefined");
    expect(tabsLayout).toContain("if (!performance.lowPowerMode)");
    expect(appSource).toContain('<View collapsable={false} style={[styles.libraryScreenHost');
    expect(appSource).toContain('<View collapsable={false} style={styles.libraryListStage');
    expect(appSource).toContain('<FlashList');
    expect(appSource).toContain("testID={IS_NATIVE_IOS ? 'library-native-list' : 'library-flash-list'}");
    expect(appSource).not.toContain('<FlatList');
  });

  test('prepares tab data without flashing empty states during native tab selection', () => {
    const appSource = fs.readFileSync(appPath, 'utf8');

    expect(appSource).toContain('() => selectStudyWords(studySourceWords, progress, studyFilter');
    expect(appSource).toContain('() => selectQuizWords(quizSourceWords, progress, quizFilter');
    expect(appSource).toContain('() => filterWords(bankWords, progress, deferredSearchQuery');
    expect(appSource).not.toContain("() => activeTab === 'study'");
    expect(appSource).not.toContain("() => activeTab === 'library'");
    expect(appSource).toContain('useFocusedSnapshot(progress, activeTab === \'study\')');
    expect(appSource).toContain('useFocusedSnapshot(progress, activeTab === \'library\')');
  });

  test('uses availability-gated native glass for command button depth', () => {
    const appSource = fs.readFileSync(appPath, 'utf8');

    expect(appSource).toContain("import { GlassView, isGlassEffectAPIAvailable } from 'expo-glass-effect';");
    expect(appSource).toContain("const NATIVE_GLASS_AVAILABLE = IS_NATIVE_IOS && isGlassEffectAPIAvailable();");
    expect(appSource).toContain("type NativeGlassTone = 'primary' | 'secondary' | 'icon';");
    expect(appSource).toContain("style: 'regular'");
    expect(appSource).toContain('animationDuration: interactionMotion.glassMorphMs / 1000');
    expect(appSource).toContain('nativeGlassTone && styles.nativeGlassButton');
    expect(appSource).toContain('glassTone="secondary"');
    expect(appSource).toContain('nativeGlassToneForPressTone(pressTone)');
    expect(appSource).toContain("return tone === 'icon' ? 'icon' : null;");
    expect(appSource).toContain('styles.nativeGlassFeedback');
    expect(appSource).toContain("'rgba(235, 245, 255, 0.62)'");
    expect(appSource).toContain('opacity: nativeGlassTone');
    expect(appSource).toContain('runtimePerformance.supportsLiquidGlass');
  });

  test('provides stable fallbacks for iOS 16 through iOS 18 and low power mode', () => {
    const rootLayout = fs.readFileSync(path.join(process.cwd(), 'src', 'app', '_layout.tsx'), 'utf8');
    const tabsLayout = fs.readFileSync(path.join(process.cwd(), 'src', 'app', '(tabs)', '_layout.tsx'), 'utf8');
    const runtimePerformance = fs.readFileSync(
      path.join(process.cwd(), 'src', 'lib', 'runtimePerformance.tsx'),
      'utf8',
    );

    expect(rootLayout).toContain("modernIosNavigation ? 'simple_push' : 'default'");
    expect(rootLayout).toContain('<AppErrorBoundary>');
    expect(rootLayout).toContain('<RuntimePerformanceProvider>');
    expect(tabsLayout).toContain("performance.supportsLiquidGlass ? 'onScrollDown' : undefined");
    expect(runtimePerformance).toContain('Battery.addLowPowerModeListener');
    expect(runtimePerformance).toContain("AccessibilityInfo.addEventListener('reduceMotionChanged'");
    expect(runtimePerformance).toContain("'reduceTransparencyChanged'");
  });

  test('gives native navigation and primary actions stronger haptic feedback', () => {
    const hapticsSource = fs.readFileSync(path.join(process.cwd(), 'src', 'lib', 'haptics.native.ts'), 'utf8');

    expect(hapticsSource).toContain('primary: Haptics.ImpactFeedbackStyle.Heavy');
    expect(hapticsSource).toContain('secondary: Haptics.ImpactFeedbackStyle.Medium');
    expect(hapticsSource).toContain('tab: Haptics.ImpactFeedbackStyle.Medium');
    expect(hapticsSource).toContain("tone === 'icon'");
  });

  test('keeps compact command labels readable and the destructive set action full width', () => {
    const appSource = fs.readFileSync(appPath, 'utf8');

    expect(appSource).toContain("deleteSet: '刪除單字集'");
    expect(appSource).toContain("deleteSet: 'Delete Set'");
    expect(appSource).toContain("flexBasis: '100%'");
    expect(appSource).toContain('minimumFontScale={0.82} numberOfLines={1} style={[styles.customSetActionText');
    expect(appSource).toContain('minimumFontScale={0.84} numberOfLines={1} style={styles.customSetDeleteText}');
  });

  test('uses one semantic iOS color system across navigation and content', () => {
    const appSource = fs.readFileSync(appPath, 'utf8');
    const rootLayout = fs.readFileSync(path.join(process.cwd(), 'src', 'app', '_layout.tsx'), 'utf8');
    const visualSystem = fs.readFileSync(path.join(process.cwd(), 'src', 'design', 'iosVisualSystem.ts'), 'utf8');

    expect(visualSystem).toContain("background: '#F2F2F7'");
    expect(visualSystem).toContain("surface: '#FFFFFF'");
    expect(visualSystem).toContain("label: '#1C1C1E'");
    expect(visualSystem).toContain("accent: '#007AFF'");
    expect(visualSystem).toContain("background: '#000000'");
    expect(visualSystem).toContain("surface: '#1C1C1E'");
    expect(visualSystem).toContain("accent: '#0A84FF'");
    expect(rootLayout).toContain('lightNavigationTheme');
    expect(rootLayout).toContain('darkNavigationTheme');
    expect(rootLayout).toContain('iosVisual.light.background');
    expect(rootLayout).toContain('iosVisual.dark.background');
    expect(appSource).not.toContain('#172033');
    expect(appSource).not.toContain('#2563eb');
    expect(appSource).not.toContain('#111827');
    expect(appSource).not.toContain('#334155');
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
      expect.objectContaining({ backgroundColor: '#2563EB', image: './assets/splash-icon.png' }),
    ]);
    expect(layoutSource).toContain('prepareNativeSplash();');
    expect(nativeSplashSource).toContain('preventAutoHideAsync');
    expect(nativeSplashSource).toContain('fade: true');
    expect(appSource).toContain('hideNativeSplash();');
    expect(appSource).toContain('(storageReady || storageLoadFailed) && (bundledVocabulary || vocabularyLoadFailed)');
    expect(appSource).toContain('setStorageLoadFailed(true)');
    // The splash hands straight over to the app; no second timed overlay.
    expect(appSource).not.toContain('styles.launchOverlay');
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
