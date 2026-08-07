import fs from 'node:fs';
import path from 'node:path';
import { describe, expect, test } from 'vitest';
import app from '../app.json';

const manifestPath = path.join(process.cwd(), 'public', 'manifest.json');
const versionPath = path.join(process.cwd(), 'public', 'version.json');
const serviceWorkerPath = path.join(process.cwd(), 'public', 'service-worker.js');
const headersPath = path.join(process.cwd(), 'public', '_headers');
const appPath = path.join(process.cwd(), 'App.tsx');
const easPath = path.join(process.cwd(), 'eas.json');
const schemaPath = path.join(process.cwd(), 'supabase', 'schema.sql');
const appStoragePath = path.join(process.cwd(), 'src', 'lib', 'appStorage.ts');
const nativeAppStoragePath = path.join(process.cwd(), 'src', 'lib', 'nativeAppStorage.native.ts');
const webAppStoragePath = path.join(process.cwd(), 'src', 'lib', 'nativeAppStorage.web.ts');
const supabaseClientPath = path.join(process.cwd(), 'src', 'lib', 'supabaseClient.ts');
const nativeSupabaseRuntimePath = path.join(process.cwd(), 'src', 'lib', 'nativeSupabaseRuntime.native.ts');
const webSupabaseRuntimePath = path.join(process.cwd(), 'src', 'lib', 'nativeSupabaseRuntime.web.ts');
const prepareExportPath = path.join(process.cwd(), 'scripts', 'prepare-web-export.mjs');
const privacyPath = path.join(process.cwd(), 'public', 'privacy.html');
const supportPath = path.join(process.cwd(), 'public', 'support.html');
const rootAppleIconPath = path.join(process.cwd(), 'public', 'apple-touch-icon.png');
const rootApplePrecomposedIconPath = path.join(process.cwd(), 'public', 'apple-touch-icon-precomposed.png');
const accountSetupPath = path.join(process.cwd(), 'ACCOUNT_GOOGLE_LOGIN.md');
const packagePath = path.join(process.cwd(), 'package.json');
const hapticsNativePath = path.join(process.cwd(), 'src', 'lib', 'haptics.native.ts');
const hapticsWebPath = path.join(process.cwd(), 'src', 'lib', 'haptics.web.ts');
const installGuidePath = path.join(process.cwd(), 'src', 'lib', 'installGuide.ts');
const appleAuthPath = path.join(process.cwd(), 'src', 'lib', 'appleAuth.ts');
const supabaseProgressPath = path.join(process.cwd(), 'src', 'lib', 'supabaseProgress.ts');
const metroPath = path.join(process.cwd(), 'metro.config.js');
const vocabularyLoaderPath = path.join(process.cwd(), 'src', 'lib', 'vocabularyLoader.ts');
const nativeVocabularyLoaderPath = path.join(process.cwd(), 'src', 'lib', 'vocabularyLoader.native.ts');
const webVocabularyLoaderPath = path.join(process.cwd(), 'src', 'lib', 'vocabularyLoader.web.ts');

describe('free web launch configuration', () => {
  test('keeps web-facing app identity ready for static hosting', () => {
    expect(app.expo.name).toBe('Word7000');
    expect(app.expo.description).toContain('7000-word');
    expect(app.expo.web?.favicon).toBe('./assets/favicon.png');
  });

  test('provides a web app manifest for add-to-home-screen usage', () => {
    const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));

    expect(manifest.name).toBe('Word7000');
    expect(manifest.short_name).toBe('Word7000');
    expect(manifest.id).toBe('/word7000-pwa-v2');
    expect(manifest.display).toBe('standalone');
    expect(manifest.start_url).toBe('/?pwa=word7000-v2');
    expect(manifest.icons.length).toBeGreaterThanOrEqual(2);
    for (const icon of manifest.icons) {
      expect(fs.existsSync(path.join(process.cwd(), 'public', icon.src.replace(/^\//, '')))).toBe(true);
    }
  });

  test('provides offline cache support for the web app shell', () => {
    const serviceWorker = fs.readFileSync(serviceWorkerPath, 'utf8');
    const headers = fs.readFileSync(headersPath, 'utf8');
    const appSource = fs.readFileSync(appPath, 'utf8');
    const prepareExport = fs.readFileSync(prepareExportPath, 'utf8');

    expect(serviceWorker).toContain('word7000-static');
    expect(serviceWorker).toContain("self.addEventListener('fetch'");
    expect(serviceWorker).toContain('self.skipWaiting');
    expect(serviceWorker).toContain('self.clients.claim');
    expect(serviceWorker).toContain("request.mode === 'navigate'");
    expect(serviceWorker).toContain('PUBLIC_HTML_PATHS');
    expect(serviceWorker).toContain("'/privacy.html'");
    expect(serviceWorker).toContain("'/support.html'");
    expect(serviceWorker).toContain("cache.put(event.request, copy)");
    expect(headers).toContain('/service-worker.js');
    expect(headers).toContain('/version.json');
    expect(headers).toContain('Cache-Control: no-cache');
    expect(appSource).toContain('/service-worker.js');
    expect(appSource).toContain('/version.json');
    expect(prepareExport).toContain('rel="manifest"');
    expect(prepareExport).toContain('version.json');
  });

  test('keeps add-to-home-screen icon metadata fresh after icon changes', () => {
    const serviceWorker = fs.readFileSync(serviceWorkerPath, 'utf8');
    const prepareExport = fs.readFileSync(prepareExportPath, 'utf8');

    expect(serviceWorker).not.toContain("const APP_SHELL = ['/', '/manifest.json'");
    expect(serviceWorker).toContain('NETWORK_FIRST_PATHS');
    expect(serviceWorker).toContain("const NETWORK_FIRST_PATHS = ['/manifest.json'");
    expect(prepareExport).toContain('cacheBustInstallIcons');
    expect(prepareExport).toContain('manifest.json?v=');
    expect(prepareExport).toContain('apple-touch-icon');
    expect(prepareExport).toContain('apple-touch-icon-precomposed');
    expect(prepareExport).toContain('replaceInstallTag');
    expect(fs.existsSync(rootAppleIconPath)).toBe(true);
    expect(fs.existsSync(rootApplePrecomposedIconPath)).toBe(true);
  });

  test('exports iPhone standalone web app viewport and status bar metadata', () => {
    const prepareExport = fs.readFileSync(prepareExportPath, 'utf8');

    expect(prepareExport).toContain('viewport-fit=cover');
    expect(prepareExport).toContain('apple-mobile-web-app-status-bar-style');
    expect(prepareExport).toContain('black-translucent');
  });

  test('keeps native-only storage imports out of the web bundle path', () => {
    const appStorageSource = fs.readFileSync(appStoragePath, 'utf8');
    const supabaseClientSource = fs.readFileSync(supabaseClientPath, 'utf8');
    const nativeAppStorageSource = fs.readFileSync(nativeAppStoragePath, 'utf8');
    const webAppStorageSource = fs.readFileSync(webAppStoragePath, 'utf8');
    const nativeSupabaseRuntimeSource = fs.readFileSync(nativeSupabaseRuntimePath, 'utf8');
    const webSupabaseRuntimeSource = fs.readFileSync(webSupabaseRuntimePath, 'utf8');

    expect(appStorageSource).not.toContain("from '@react-native-async-storage/async-storage'");
    expect(supabaseClientSource).not.toContain("from '@react-native-async-storage/async-storage'");
    expect(supabaseClientSource).not.toContain("react-native-url-polyfill/auto");
    expect(nativeAppStorageSource).toContain("from '@react-native-async-storage/async-storage'");
    expect(webAppStorageSource).not.toContain("from '@react-native-async-storage/async-storage'");
    expect(nativeSupabaseRuntimeSource).toContain("from '@react-native-async-storage/async-storage'");
    expect(nativeSupabaseRuntimeSource).toContain("react-native-url-polyfill/auto");
    expect(webSupabaseRuntimeSource).not.toContain("from '@react-native-async-storage/async-storage'");
    expect(webSupabaseRuntimeSource).not.toContain("react-native-url-polyfill/auto");
  });

  test('lets the web build preview the current iPhone app experience', () => {
    const appSource = fs.readFileSync(appPath, 'utf8');

    expect(appSource).toContain('WEB_IOS_PREVIEW_QUERY_KEYS');
    expect(appSource).toContain("['ios-preview', 'iosPreview', 'preview-ios']");
    expect(appSource).toContain('function isWebIosPreviewMode()');
    expect(appSource).toContain('const IS_WEB_IOS_PREVIEW = isWebIosPreviewMode();');
    expect(appSource).toContain("Platform.OS === 'web' && !IS_WEB_IOS_PREVIEW && shouldShowInstallGuide");
    expect(appSource).toContain("const showWebInstallGuidePanel = Platform.OS === 'web' && !IS_WEB_IOS_PREVIEW;");
    expect(appSource).toContain("const showAppleSignIn = Platform.OS === 'ios' || IS_WEB_IOS_PREVIEW;");
    expect(appSource).toContain('styles.webIosPreviewSafeArea');
    expect(appSource).toContain('styles.webIosPreviewAppShell');
    expect(appSource).toContain('WEB_IOS_PREVIEW_SCROLL_BOTTOM_INSET');
    expect(appSource).toContain('Apple 登入在網頁預覽中只顯示入口');
    expect(appSource).toContain('Apple sign-in is shown here for iPhone preview');
  });

  test('keeps iPhone bottom navigation anchored without double-counting safe area', () => {
    const appSource = fs.readFileSync(appPath, 'utf8');
    const rootLayout = fs.readFileSync(path.join(process.cwd(), 'src', 'app', '_layout.tsx'), 'utf8');

    expect(rootLayout).toContain('<SafeAreaProvider>');
    expect(appSource).toContain("import { SafeAreaView, useSafeAreaInsets } from 'react-native-safe-area-context';");
    expect(appSource).toContain('appScroll:');
    expect(appSource).toContain('flex: 1');
    expect(appSource).toContain("overflow: 'hidden'");
    expect(appSource).toContain('paddingBottom: CONTENT_BOTTOM_PADDING');
    // The bar is positioned absolutely on purpose now: content scrolls under
    // it so the Liquid Glass has something to refract. What the original guard
    // was really protecting against is the safe area being counted twice — the
    // old bug paired absolute positioning with a hardcoded bottom offset and a
    // hardcoded content inset. Pin that down directly rather than banning the
    // positioning: the bar sits at bottom 0, and both the bar's own padding
    // and the scrollers' bottom room derive from the one measured inset.
  });

  test('provides a version endpoint for mobile web app update checks', () => {
    const version = JSON.parse(fs.readFileSync(versionPath, 'utf8'));
    const appSource = fs.readFileSync(appPath, 'utf8');

    expect(typeof version.version).toBe('string');
    expect(version.version.length).toBeGreaterThan(0);
    expect(appSource).toContain('UPDATE_CHECK_INTERVAL_MS = 60_000');
    expect(appSource).toContain('UPDATE_AUTO_REFRESH_MS = 6500');
    expect(appSource).toContain('force-update-overlay');
    expect(appSource).toContain('需要更新才能繼續使用');
    expect(appSource).toContain('秒後自動更新');
    expect(appSource).toContain('立即更新');
    expect(appSource).toContain('Update required');
    expect(appSource).toContain('Auto-updating in');
    expect(appSource).toContain('Update now');
    expect(appSource).toContain('useAppUpdateCheck(studyMode)');
    expect(appSource).toContain('countdownText: copy.updateCountdown(countdownSeconds)');
    expect(appSource).toContain('countdownText={updateState.countdownText}');
    expect(appSource).toContain('setTimeout(refresh, UPDATE_AUTO_REFRESH_MS)');
  });

  test('configures native builds for fast TestFlight updates', () => {
    const eas = JSON.parse(fs.readFileSync(easPath, 'utf8'));

    expect(app.expo.updates?.url).toBe('https://u.expo.dev/d973eb82-7066-453c-a361-afe987ba0ca1');
    expect(app.expo.runtimeVersion).toEqual({ policy: 'appVersion' });
    expect(app.expo.extra?.eas?.projectId).toBe('d973eb82-7066-453c-a361-afe987ba0ca1');
    expect(eas.submit.production.ios.ascAppId).toBe('6786934889');
  });

  test('includes a first-launch Safari add-to-home-screen guide', () => {
    const appSource = fs.readFileSync(appPath, 'utf8');
    const installGuideSource = fs.readFileSync(installGuidePath, 'utf8');

    expect(installGuideSource).toContain('INSTALL_GUIDE_STORAGE_KEY');
    expect(appSource).toContain('Safari');
    expect(appSource).toContain('SquareArrowUp');
    expect(appSource).toContain('installGuideIconGraphic');
    expect(appSource).not.toContain('Safari 分享');
    expect(appSource).not.toContain('safariShareIconText');
    expect(appSource).toContain('分享');
    expect(appSource).toContain('加入主畫面');
    expect(appSource).toContain('install-guide-overlay');
    expect(appSource).toContain('installGuideStepProgress');
    expect(appSource).toContain('重新查看加入主畫面教學');
    expect(appSource).toContain('Open in Safari');
    expect(appSource).toContain('Tap Share');
    expect(appSource).toContain('Choose Add to Home Screen');
    expect(appSource).toContain("I'll do this myself");
    expect(appSource).toContain('Close home-screen tutorial');
    expect(appSource).toContain('const activeInstallGuideSteps = installGuideStepsByMode[studyMode];');
    expect(appSource).toContain('steps={activeInstallGuideSteps}');
    expect(appSource).toContain('copy={activeSystemCopy.installGuide}');
  });

  test('includes quiz session setup with selectable question counts', () => {
    const appSource = fs.readFileSync(appPath, 'utf8');

    expect(appSource).toContain('選擇題數');
    expect(appSource).toContain('開始測驗');
    expect(appSource).toContain('const quizQuestionCounts = [10, 20, 50] as const;');
    expect(appSource).toContain('{count} {ui.questionUnit}');
    expect(appSource).toContain('測驗完成');
  });

  test('integrates conversation prompt practice inside the quiz page', () => {
    const appSource = fs.readFileSync(appPath, 'utf8');
    const quizStart = appSource.indexOf('function QuizView({');
    const libraryStart = appSource.indexOf('function LibraryView({');
    const quizSource = appSource.slice(quizStart, libraryStart);

    expect(appSource).toContain("type QuizPracticeMode = 'choice' | 'speaking'");
    expect(appSource).toContain('buildConversationPrompt');
    expect(quizSource).toContain('ui.choiceQuizMode');
    expect(quizSource).toContain('ui.speakingQuizMode');
    expect(quizSource).toContain('conversationPrompt');
    expect(quizSource).toContain('ui.speakingPromptLabel');
    expect(quizSource).toContain('styles.speakingPromptQuestion');
    expect(quizSource).toContain('testID="speaking-prompt-question"');
    expect(quizSource).toContain('conversationPrompt.question');
    expect(quizSource).toContain('ui.iSpoke');
    expect(quizSource).toContain('ui.showSampleAnswer');
    expect(quizSource).toContain('ui.sampleAnswer');
    expect(quizSource).toContain('ui.sampleTranslation');
    expect(quizSource).not.toContain('styles.pronunciation');
    expect(appSource).toContain('speakingPromptQuestion:');
    expect(appSource).toContain('fontSize: 22');
  });

  test('keeps pronunciation off the quiz question card', () => {
    const appSource = fs.readFileSync(appPath, 'utf8');
    const quizStart = appSource.indexOf('function QuizView({');
    const libraryStart = appSource.indexOf('function LibraryView({');
    const quizSource = appSource.slice(quizStart, libraryStart);

    expect(quizStart).toBeGreaterThan(-1);
    expect(libraryStart).toBeGreaterThan(quizStart);
    expect(quizSource).not.toContain('formatWordSecondary(word, studyMode)');
    expect(quizSource).not.toContain('styles.pronunciation');
  });

  test('keeps the quiz next button at the top-right of the question card after answering', () => {
    const appSource = fs.readFileSync(appPath, 'utf8');
    const quizStart = appSource.indexOf('function QuizView({');
    const libraryStart = appSource.indexOf('function LibraryView({');
    const quizSource = appSource.slice(quizStart, libraryStart);
    const resultCardStart = quizSource.indexOf('styles.resultCard');
    const resultCardSource = quizSource.slice(resultCardStart);

    expect(quizSource).toContain('styles.quizQuestionHeader');
    expect(quizSource).toContain('styles.quizNextTopButton');
    expect(quizSource).toContain('{result && (');
    expect(quizSource).toContain('accessibilityLabel={ui.nextQuestion}');
    expect(resultCardSource).not.toContain('styles.nextButton');
  });

  test('shows full quiz feedback with English and Chinese examples after answering', () => {
    const appSource = fs.readFileSync(appPath, 'utf8');

    expect(appSource).toContain('quizExampleCard');
    expect(appSource).toContain('英文例句');
    expect(appSource).toContain('中文例句');
    expect(appSource).toContain('中文翻譯');
    expect(appSource).toContain('formatExamplePrimary(word, studyMode)');
    expect(appSource).toContain('formatExampleSecondary(word, studyMode)');
  });

  test('lets library words open a full detail view', () => {
    const appSource = fs.readFileSync(appPath, 'utf8');
    const detailRoute = fs.readFileSync(path.join(process.cwd(), 'src', 'app', 'library', '[wordId].tsx'), 'utf8');
    const rootLayout = fs.readFileSync(path.join(process.cwd(), 'src', 'app', '_layout.tsx'), 'utf8');

    expect(appSource).not.toContain('selectedLibraryWord');
    expect(appSource).toContain('library-word-detail');
    expect(appSource).toContain('返回字庫');
    expect(appSource).toContain('完整資訊');
    expect(appSource).toContain('onOpenWord');
    expect(appSource).toContain("router.push({ pathname: '/library/[wordId]'");
    expect(detailRoute).toContain('<LibraryWordDetailView');
    expect(detailRoute).toContain('router.back()');
    expect(detailRoute).toContain('bridge.actions.restoreLibraryScroll()');
    expect(rootLayout).toContain('<Stack.Screen name="library/[wordId]" />');
  });

  test('keeps custom set navigation and search polish on the shared slide motion system', () => {
    const appSource = fs.readFileSync(appPath, 'utf8');
    const motionSource = fs.readFileSync(path.join(process.cwd(), 'src', 'lib', 'interactionMotion.ts'), 'utf8');

    expect(motionSource).toContain('panelSlideX');
    expect(motionSource).toContain('panelPushScale');
    expect(motionSource).toContain('staggeredListLimit');
    expect(appSource).toContain('searchBoxWebTransition');
    expect(appSource).toContain('customSetPanelMotionStyle');
    expect(appSource).toContain('testID="custom-set-panel-transition"');
  });

  test('includes a developer vocabulary panel for import and export workflow', () => {
    const appSource = fs.readFileSync(appPath, 'utf8');

    expect(appSource).toContain('開發人員資料窗口');
    expect(appSource).toContain('Developer Data Window');
    expect(appSource).toContain('developer-vocabulary-panel');
    expect(appSource).toContain('exportWordsToCsv');
    expect(appSource).toContain('parseVocabularyImport');
    expect(appSource).toContain('applyVocabularyImportRows');
    expect(appSource).toContain('清除本機預覽');
    expect(appSource).toContain('activeSystemCopy.exportCsvSuccess');
    expect(appSource).toContain('activeSystemCopy.importReading');
    expect(appSource).toContain('developerVocabularyMessageForMode');
    expect(appSource).toContain('The import file is empty.');
  });

  test('opens app settings from the profile page before showing developer tools', () => {
    const appSource = fs.readFileSync(appPath, 'utf8');
    const settingsRoute = fs.readFileSync(path.join(process.cwd(), 'src', 'app', 'settings.tsx'), 'utf8');

    expect(appSource).toContain('ProfileLearningExperiencePanel');
    expect(appSource).toContain('ProfileTutorialPanel');
    expect(appSource).toContain('profile-settings-panel');
    expect(appSource).toContain("profileOpenSettings = useStableEvent(() => router.push('/settings'))");
    expect(settingsRoute).toContain('<ProfileSettingsView');
    expect(settingsRoute).toContain('router.back()');
    expect(appSource).not.toContain('renderedProfilePanel');
    expect(appSource).toContain('開啟設定');
    expect(appSource).toContain('返回我的');
    expect(appSource).toContain('App 設定');
    expect(appSource).toContain('深色模式');
    expect(appSource).toContain('word7000-theme-v1');
    expect(appSource).toContain('const nextThemeMode = darkMode ? \'light\' : \'dark\';');
    expect(appSource).toContain('const toggleThemeMode = () => onThemeModeChange(nextThemeMode);');
    expect(appSource).toContain('onPress={toggleThemeMode}');
    expect(appSource).toContain("const dangerIconColor = darkMode ? '#FF6961' : '#D70015';");
    expect(appSource).toContain('themeStyles?.deleteAccountDataButton');
    expect(appSource).toContain('themeStyles?.deleteAccountDataTitle');
    expect(appSource).toContain('themeStyles?.deleteAccountDataText');
    expect(appSource).toContain('deleteAccountDataButton:');
    expect(appSource).toContain("backgroundColor: '#3A1714'");
    expect(appSource).toContain('onThemeModeChange');
    expect(appSource).toContain('DeveloperVocabularyPanel');
  });

  test('includes App Store support links and account data deletion controls', () => {
    const appSource = fs.readFileSync(appPath, 'utf8');
    const schema = fs.readFileSync(schemaPath, 'utf8');
    const privacyHtml = fs.readFileSync(privacyPath, 'utf8');
    const supportHtml = fs.readFileSync(supportPath, 'utf8');

    expect(fs.existsSync(privacyPath)).toBe(true);
    expect(fs.existsSync(supportPath)).toBe(true);
    expect(privacyHtml).toContain('rio10255254@gmail.com');
    expect(supportHtml).toContain('mailto:rio10255254@gmail.com');
    expect(supportHtml).toContain('rio10255254@gmail.com');
    expect(appSource).toContain('appInfoLinks.privacy');
    expect(appSource).toContain('appInfoLinks.support');
    const settingsRoute = fs.readFileSync(path.join(process.cwd(), 'src', 'app', 'settings.tsx'), 'utf8');
    expect(settingsRoute).toContain('onConfirmDeleteAccountData={bridge.actions.confirmDeleteAccountData}');
    expect(appSource).toContain('testID="delete-account-data-button"');
    expect(appSource).toContain('deleteCloudUserData(asCloudProgressClient(supabaseClient), signedInUserId)');
    expect(schema).toContain('Users can delete their own profile');
    expect(schema).toContain('Users can delete their own daily activity');
  });

  test('keeps public privacy and support pages user-facing', () => {
    const publicPages = [
      fs.readFileSync(privacyPath, 'utf8'),
      fs.readFileSync(supportPath, 'utf8'),
    ].join('\n');

    expect(publicPages).not.toContain('Supabase');
    expect(publicPages).not.toContain('word7000://auth/callback');
    expect(publicPages).not.toContain('GitHub project');
    expect(publicPages).not.toContain('support channel listed');
  });

  test('checks native EAS updates outside the web service worker flow', () => {
    const appSource = fs.readFileSync(appPath, 'utf8');
    const eas = JSON.parse(fs.readFileSync(path.join(process.cwd(), 'eas.json'), 'utf8'));

    expect(appSource).toContain("import('expo-updates')");
    expect(appSource).toContain('checkForUpdateAsync');
    expect(appSource).toContain('fetchUpdateAsync');
    expect(appSource).toContain('reloadAsync');
    expect(eas.build.preview.channel).toBe('preview');
    expect(eas.build.production.channel).toBe('production');
  });

  test('uses Google sign-in as the primary account entry for cloud sync', () => {
    const appSource = fs.readFileSync(appPath, 'utf8');
    const authCallbackRoute = fs.readFileSync(path.join(process.cwd(), 'src', 'app', 'auth', 'callback.tsx'), 'utf8');
    const nativeAuthBridge = fs.readFileSync(path.join(process.cwd(), 'public', 'auth-native.html'), 'utf8');

    expect(appSource).toContain("from './src/lib/authRedirect'");
    expect(appSource).toContain('loadCloudProgressRecord');
    expect(appSource).toContain('saveCloudUserMemory');
    expect(appSource).toContain('UserMemorySyncQueue');
    expect(appSource).toContain('mergeProgressStates');
    expect(appSource).toContain('mergeCustomSetStates');
    expect(appSource).toContain('mergeProgressStates(cloudProgress.progress, userLocalProgress, pendingMemory?.progress)');
    expect(appSource).toContain('pendingMemory?.customSets');
    expect(appSource).toContain('saveProgressToStorage(getAppStorage(), progress, account.userId)');
    expect(appSource).toContain('saveCustomSetState(getAppStorage(), customSetState, account.userId)');
    expect(appSource).toContain('saveProgressToStorage(storage, loadedProgress, user.id)');
    expect(appSource).toContain('syncQueue.enqueue(');
    expect(appSource).toContain('{ customSets: true, progress: true }');
    expect(appSource).toContain('await syncQueue.flush()');
    expect(appSource).toContain('if (saveResult.ok)');
    expect(appSource).toContain('loadProgressFromStorage(getAppStorage(), initialProgress)');
    expect(appSource).toContain('handleGoogleSignIn');
    expect(appSource).toContain("provider: 'google'");
    expect(appSource).toContain('signInWithOAuth');
    expect(appSource).toContain('getOAuthRedirectUrl()');
    expect(appSource).toContain("buildHostedAppUrl('/auth-native.html')");
    expect(appSource).toContain('nativeAuthRedirectTo(APP_LINKING_SCHEME)');
    expect(appSource).toContain('WebBrowser.openAuthSessionAsync(data.url, nativeReturnTo)');
    expect(appSource).toContain("prompt: 'select_account'");
    expect(appSource).toContain('skipBrowserRedirect: Platform.OS !==');
    expect(appSource).toContain('使用 Google 快速登入');
    expect(appSource).toContain('Continue with Google');
    expect(appSource).toContain('handleAppleSignIn');
    expect(appSource).toContain("provider: 'apple'");
    expect(appSource).toContain('createAppleNoncePair()');
    expect(appSource).toContain('nonce: appleNonce.sha256');
    expect(appSource).toContain('nonce: appleNonce.raw');
    expect(appSource).toContain('access_token: credential.authorizationCode');
    expect(appSource).toContain('appleCredentialMetadata');
    expect(appSource).toContain('supabaseClient.auth.updateUser');
    expect(appSource).toContain('Email 備用登入');
    expect(appSource).toContain('Email fallback');
    expect(appSource).toContain('profileGoogleSignIn = useStableEvent(handleGoogleSignIn)');
    expect(appSource).toContain('onGoogleSignIn: profileGoogleSignIn,');
    expect(authCallbackRoute).toContain('<Redirect href="/" />');
    expect(nativeAuthBridge).toContain("'word7000://auth/callback'");
    expect(nativeAuthBridge).toContain('window.location.replace(callbackUrl)');
  });

  test('keeps account sync unavailable messages user-facing', () => {
    const appSource = fs.readFileSync(appPath, 'utf8');

    expect(appSource).toContain('目前會先把進度保存在這台裝置');
    expect(appSource).toContain('Progress is saved on this device for now');
    expect(appSource).not.toContain('Cloudflare 設好 Supabase');
    expect(appSource).not.toContain('Add Supabase settings in Cloudflare');
    expect(appSource).not.toContain('iPhone App 上架必備');
    expect(appSource).not.toContain('App Store 上架與使用者協助入口');
    expect(appSource).not.toContain('Required App Store and user help links');
  });

  test('records signed-in daily active users for Supabase analytics', () => {
    const appSource = fs.readFileSync(appPath, 'utf8');
    const schema = fs.readFileSync(schemaPath, 'utf8');
    const supabaseProgressSource = fs.readFileSync(supabaseProgressPath, 'utf8');

    expect(appSource).toContain('ACTIVE_USER_HEARTBEAT_MS = 60_000');
    expect(appSource).toContain('recordDailyActiveUser(asCloudProgressClient(supabaseClient), account.userId)');
    expect(appSource).toContain('setInterval(recordActivity, ACTIVE_USER_HEARTBEAT_MS)');
    expect(schema).toContain('custom_sets jsonb');
    expect(schema).toContain('create table if not exists public.daily_active_users');
    expect(schema).toContain('primary key (user_id, activity_date)');
    expect(schema).toContain('daily_active_users_activity_date_idx');
    expect(schema).toContain('daily_active_users_last_seen_at_idx');
    expect(schema).toContain('add column if not exists progress jsonb');
    expect(schema).toContain('add column if not exists updated_at timestamptz');
    expect(schema).toContain('profiles_updated_at_idx');
    expect(supabaseProgressSource).toContain('saveCloudUserMemory');
    expect(supabaseProgressSource).toContain('progress, custom_sets');
    expect(schema).toContain('Users can insert their own daily activity');
    expect(schema).toContain('Users can update their own daily activity');
  });

  test('adds native haptic feedback to shared app presses only on device builds', () => {
    const appSource = fs.readFileSync(appPath, 'utf8');
    const packageJson = JSON.parse(fs.readFileSync(packagePath, 'utf8'));
    const nativeHapticsSource = fs.readFileSync(hapticsNativePath, 'utf8');
    const webHapticsSource = fs.readFileSync(hapticsWebPath, 'utf8');

    expect(packageJson.dependencies['expo-haptics']).toBeTruthy();
    expect(appSource).toContain("from './src/lib/haptics'");
    expect(appSource).toContain('triggerPressHaptic(pressTone)');
    expect(nativeHapticsSource).toContain("from 'expo-haptics'");
    expect(nativeHapticsSource).toContain('selectionAsync');
    expect(nativeHapticsSource).toContain('impactAsync');
    expect(nativeHapticsSource).toContain("Older test builds may not include the native haptics module yet.");
    expect(webHapticsSource).not.toContain('expo-haptics');
  });

  test('keeps Apple sign-in metadata reusable and first-login name aware', () => {
    const appleAuthSource = fs.readFileSync(appleAuthPath, 'utf8');

    expect(appleAuthSource).toContain('createAppleNoncePair');
    expect(appleAuthSource).toContain('sha256Hex');
    expect(appleAuthSource).toContain('appleCredentialMetadata');
    expect(appleAuthSource).toContain('full_name');
    expect(appleAuthSource).toContain('given_name');
    expect(appleAuthSource).toContain('family_name');
    expect(appleAuthSource).toContain('apple_user');
  });

  test('documents the Google account setup needed after deployment', () => {
    const setupGuide = fs.readFileSync(accountSetupPath, 'utf8');

    expect(setupGuide).toContain('Supabase');
    expect(setupGuide).toContain('Google');
    expect(setupGuide).toContain('supabase/schema.sql');
    expect(setupGuide).toContain('Redirect URLs');
    expect(setupGuide).toContain('word7000://auth/callback');
    expect(setupGuide).toContain('EXPO_PUBLIC_SUPABASE_URL');
    expect(setupGuide).toContain('EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY');
    expect(setupGuide).toContain('EXPO_PUBLIC_SUPABASE_ANON_KEY');
    expect(setupGuide).toContain('Cloudflare Pages');
  });

  test('injects public Supabase settings into the exported web runtime', () => {
    const prepareScript = fs.readFileSync(path.join(process.cwd(), 'scripts', 'prepare-web-export.mjs'), 'utf8');

    expect(prepareScript).toContain('globalThis.__WORD7000_CONFIG__');
    expect(prepareScript).toContain('EXPO_PUBLIC_SUPABASE_URL');
    expect(prepareScript).toContain('EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY');
    expect(prepareScript).toContain('EXPO_PUBLIC_SUPABASE_ANON_KEY');
  });

  test('animates the launch progress bar instead of showing a static fill', () => {
    const appSource = fs.readFileSync(appPath, 'utf8');

    expect(appSource).toContain('launchProgressWidth');
    expect(appSource).toContain('Animated.View style={[styles.launchBarFill');
    expect(appSource).not.toContain('<View style={styles.launchBarFill} />');
  });

  test('includes a whole-app study mode switch with a visible transition', () => {
    const appSource = fs.readFileSync(appPath, 'utf8');

    expect(appSource).toContain("type StudyMode = 'english' | 'chinese'");
    expect(appSource).toContain('word7000-study-mode-v1');
    expect(appSource).toContain('Switch to Chinese words');
    expect(appSource).toContain('切到英文單字');
    expect(appSource).not.toContain('切到中文單字');
    expect(appSource).not.toContain('Switch back to English words');
    expect(appSource).toContain('ModeSwitchOverlay');
    expect(appSource).toContain('modeTransitionAnim');
    expect(appSource).toContain('accessibilityLabel={copy.toggleTitle}');
    expect(appSource).toContain('{copy.toggleTitle}');
    expect(appSource).not.toContain('targetCopy.toggleTitle');
    expect(appSource).toContain('formatWordPrimary');
    expect(appSource).toContain('formatQuizAnswer');
    expect(appSource).toContain("buildQuizOptions(quizOptionSource, quizWord.id, `${quizSeed}:${quizIndex}`, studyMode === 'chinese' ? 'word' : 'meaning')");
  });

  test('polishes mobile first-screen spacing without changing the app structure', () => {
    const appSource = fs.readFileSync(appPath, 'utf8');

    expect(appSource).toContain("heroTitle: '今天 20 個\\n剛剛好'");
    expect(appSource).toContain('styles.homeStack');
    expect(appSource).toContain('homeStack:');
    expect(appSource).toContain('gap: 12');
    expect(appSource).toContain('styles.installGuideMain');
    expect(appSource).toContain('installGuideMain:');
    expect(appSource).toContain("justifyContent: 'flex-start'");
    expect(appSource).toContain('paddingTop: 80');
    expect(appSource).toContain('libraryTopControlsInset:');
    expect(appSource).toContain('paddingRight: 36');
  });

  test('uses an English interface and full-page transition in Chinese word mode', () => {
    const appSource = fs.readFileSync(appPath, 'utf8');

    expect(appSource).toContain("brand: 'Chinese7000'");
    expect(appSource).toContain("toggleTitle: '切到英文單字'");
    expect(appSource).toContain("toggleText: '回到中文介面的英文單字 App'");
    expect(appSource).toContain("libraryTitle: 'Chinese Word Library'");
    expect(appSource).toContain("searchPlaceholder: 'Search Chinese, English words, examples, or translations'");
    expect(appSource).toContain("studyFilterTitle: 'Study Filters'");
    expect(appSource).toContain("quizFilterTitle: 'Quiz Filters'");
    expect(appSource).toContain("questionBankUnit: 'Chinese words'");
    expect(appSource).toContain('<Text style={styles.launchTitle}>{activeModeCopy.brand}</Text>');
    expect(appSource).toContain('<Text style={styles.launchText}>{activeModeCopy.subtitle}</Text>');
    expect(appSource).toContain('const activeSystemCopy = systemCopy[studyMode];');
    expect(appSource).toContain('modeInterfaceCopy');
    expect(appSource).toContain('styles.modeSwitchBackdrop');
    expect(appSource).toContain('styles.modeSwitchPanel');
    expect(appSource).toContain('bottom: 0');
    expect(appSource).toContain('top: 0');
  });

  test('uses concise Chinese meanings, supplemental details, and pinyin in Chinese word mode', () => {
    const appSource = fs.readFileSync(appPath, 'utf8');

    expect(appSource).toContain("from './src/lib/chineseDisplay'");
    expect(appSource).toContain('conciseChineseMeaning(word.meaningZh)');
    expect(appSource).toContain('supplementalChineseMeaning(word.meaningZh)');
    expect(appSource).toContain('chineseMeaningPinyin');
    expect(appSource).toContain('formatWordPinyin(word, studyMode)');
    expect(appSource).toContain('ui.supplementalMeanings');
    expect(appSource).toContain('styles.supplementalMeaning');
  });

  test('polishes interaction motion and avoids stuttery filter collapse', () => {
    const appSource = fs.readFileSync(appPath, 'utf8');

    expect(appSource).toContain('pressedOpacity');
    expect(appSource).toContain('filterPanelMeasuredHeight');
    expect(appSource).toContain('const [hasOpened, setHasOpened] = useState(open);');
    expect(appSource).toContain('{(open || hasOpened) && children}');
    expect(appSource).toContain('onLayout={handlePanelContentLayout}');
    expect(appSource).toContain('pointerEvents={open ?');
    expect(appSource).toContain('styles.filterPanelContent');
    expect(appSource).toContain('filterPanelWebTransition');
    expect(appSource).toContain("transitionProperty: 'height, opacity, border-top-width, transform'");
    expect(appSource).toContain('styles.filterSummaryButtonOpen');
    expect(appSource).toContain('styles.libraryItemPressed');
    expect(appSource).not.toContain('maxHeight: panelAnim.interpolate');
  });

  test('does not mount hidden library management screens during first library paint', () => {
    const appSource = fs.readFileSync(appPath, 'utf8');
    const setsRoute = fs.readFileSync(path.join(process.cwd(), 'src', 'app', 'sets.tsx'), 'utf8');

    expect(appSource).toContain("router.push('/sets')");
    expect(setsRoute).toContain('<ProfileCustomSetsView');
    expect(appSource).not.toContain('library-custom-sets-stage');
    expect(appSource).not.toContain('renderedLibraryPanel');
  });

  test('adds an English alphabetical sort option inside the library filter panel', () => {
    const appSource = fs.readFileSync(appPath, 'utf8');

    expect(appSource).toContain('type LibrarySort,');
    expect(appSource).toContain('activeSort={activeSort}');
    expect(appSource).toContain("sort: activeSort");
    expect(appSource).toContain('onSortChange: setActiveSort,');
    expect(appSource).toContain('ui.filterSort');
    expect(appSource).toContain('ui.sortAlphabetical');
    expect(appSource).toContain('sortLabel(sort, studyMode)');
  });

  test('remembers filter preferences and defaults library sorting to alphabetical', () => {
    const appSource = fs.readFileSync(appPath, 'utf8');
    const preferencesSource = fs.readFileSync(path.join(process.cwd(), 'src/lib/filterPreferences.ts'), 'utf8');

    expect(appSource).toContain("from './src/lib/filterPreferences'");
    expect(appSource).toContain('loadFilterPreferences(getAppStorage())');
    expect(appSource).toContain('saveFilterPreferences(getAppStorage()');
    expect(appSource).toContain("sort: activeSort");
    expect(appSource).toContain('study: {');
    expect(appSource).toContain('quiz: {');
    expect(appSource).toContain('library: {');
    expect(preferencesSource).toContain('FILTER_PREFERENCES_STORAGE_KEY');
    expect(preferencesSource).toContain("sort: 'alphabetical'");
  });

  test('uses native settings navigation and fully darkens the install guide', () => {
    const appSource = fs.readFileSync(appPath, 'utf8');
    const rootLayout = fs.readFileSync(path.join(process.cwd(), 'src', 'app', '_layout.tsx'), 'utf8');

    expect(rootLayout).toContain("<Stack.Screen name=\"settings\" />");
    expect(rootLayout).toContain('animation: pushAnimation');
    expect(appSource).not.toContain('profilePanelAnim');
    expect(appSource).not.toContain('renderedProfilePanel');
    expect(appSource).toContain('themeStyles?.installGuideOverlay');
    expect(appSource).toContain('themeStyles?.installGuideCard');
    expect(appSource).toContain('themeStyles?.installGuideClose');
    expect(appSource).toContain('themeStyles?.installGuidePreview');
    expect(appSource).toContain('themeStyles?.installGuideMiniStep');
    expect(appSource).toContain('themeStyles?.installGuideSecondaryText');
    expect(appSource).toContain('installGuideIconColor');
    expect(appSource).toContain('color={installGuideIconColor}');
  });

  test('animates word detail navigation in both directions', () => {
    const appSource = fs.readFileSync(appPath, 'utf8');
    const detailRoute = fs.readFileSync(path.join(process.cwd(), 'src', 'app', 'library', '[wordId].tsx'), 'utf8');
    const rootLayout = fs.readFileSync(path.join(process.cwd(), 'src', 'app', '_layout.tsx'), 'utf8');

    expect(rootLayout).toContain("const pushAnimation = Platform.OS === 'ios' ? 'simple_push' : 'slide_from_right';");
    expect(rootLayout).toContain('animation: pushAnimation');
    expect(rootLayout).toContain('animationDuration: 360');
    expect(rootLayout).toContain('fullScreenGestureEnabled: true');
    expect(rootLayout).toContain('gestureEnabled: true');
    expect(appSource).toContain("router.push({ pathname: '/library/[wordId]'");
    expect(detailRoute).toContain('router.back()');
    expect(detailRoute).toContain('router.replace(\'/\')');
    expect(appSource).not.toContain('libraryPanelAnim');
    expect(appSource).not.toContain('renderedLibraryPanel');
    expect(appSource).not.toContain('selectedLibraryWord');
  });

  test('keeps the library detail transition smooth without changing its form', () => {
    const appSource = fs.readFileSync(appPath, 'utf8');
    const routeBridge = fs.readFileSync(path.join(process.cwd(), 'src', 'lib', 'appRouteBridge.ts'), 'utf8');
    const libraryViewStart = appSource.indexOf('const LibraryView = memo(function LibraryView');
    const detailViewStart = appSource.indexOf('function LibraryWordDetailView');
    const libraryViewSource = appSource.slice(libraryViewStart, detailViewStart);

    expect(appSource).toContain('memo,');
    expect(libraryViewStart).toBeGreaterThan(-1);
    expect(libraryViewSource).toContain('listMotionStyle(index)');
    expect(appSource).toContain('const listMotionStyle = useCallback(');
    expect(appSource).toContain('const handleLibraryFiltersToggle = useCallback(');
    expect(appSource).toContain('const handleLibraryFavorite = useCallback(');
    expect(appSource).toContain('const handleLibrarySearchBlur = useCallback(');
    expect(appSource).toContain('const handleLibrarySearchFocus = useCallback(');
    expect(appSource).toContain('const openLibraryCustomSets = useCallback(');
    expect(appSource).toContain('onFiltersToggle: handleLibraryFiltersToggle,');
    expect(appSource).toContain('onFavorite: handleLibraryFavorite,');
    expect(appSource).toContain('onSearchBlur: librarySearchBlur,');
    expect(appSource).toContain('onSearchFocus: librarySearchFocus,');
    expect(appSource).toContain('onOpenCustomSets: openLibraryCustomSets,');
    expect(routeBridge).toContain('useSyncExternalStore');
    expect(appSource).not.toContain('libraryListPanelMotionStyle');
    expect(appSource).not.toContain('libraryListPanelReturnMotionStyle');
  });

  test('keeps the current scroll position during profile settings transitions', () => {
    const appSource = fs.readFileSync(appPath, 'utf8');
    const settingsRoute = fs.readFileSync(path.join(process.cwd(), 'src', 'app', 'settings.tsx'), 'utf8');

    expect(appSource).toContain("profileOpenSettings = useStableEvent(() => router.push('/settings'))");
    expect(appSource).toContain('onOpenSettings: profileOpenSettings,');
    expect(settingsRoute).toContain('router.back()');
    expect(appSource).not.toContain('setSelectedLibraryWord');
  });

  test('returns from word detail to the previous library position without replaying the list', () => {
    const appSource = fs.readFileSync(appPath, 'utf8');
    const detailRoute = fs.readFileSync(path.join(process.cwd(), 'src', 'app', 'library', '[wordId].tsx'), 'utf8');

    expect(appSource).toContain("router.push({ pathname: '/library/[wordId]'");
    expect(detailRoute).toContain('router.back()');
    expect(appSource).toContain('libraryRouteScrollRestoreRef.current = libraryScrollYRef.current');
    expect(appSource).toContain('restoreLibraryRouteScroll(restoreOffset)');
    expect(appSource).toContain('setTimeout(() => restoreLibraryRouteScroll(restoreOffset), 420)');
    expect(appSource).toContain('LIBRARY_ANIMATED_ITEM_COUNT');
    expect(appSource).toContain('index >= LIBRARY_ANIMATED_ITEM_COUNT');
    expect(appSource).not.toContain('setSelectedLibraryWord');
    expect(appSource).not.toContain('setLibraryPanel');
  });

  test('uses a full-page fade when toggling dark mode colors', () => {
    const appSource = fs.readFileSync(appPath, 'utf8');

    expect(appSource).toContain('themeTransitionAnim');
    expect(appSource).toContain('showThemeTransition');
    expect(appSource).toContain('themeTransitionTarget');
    expect(appSource).toContain('function triggerThemeModeChange(nextMode: ThemeMode)');
    const settingsRoute = fs.readFileSync(path.join(process.cwd(), 'src', 'app', 'settings.tsx'), 'utf8');
    expect(settingsRoute).toContain('onThemeModeChange={changeThemeMode}');
    expect(settingsRoute).toContain('settings-theme-transition-overlay');
    expect(settingsRoute).toContain('Animated.sequence([');
    expect(appSource).toContain('styles.themeTransitionOverlay');
  });

  test('keeps settings scrolling finite and uses only a dark-mode status light', () => {
    const appSource = fs.readFileSync(appPath, 'utf8');
    const settingsRoute = fs.readFileSync(path.join(process.cwd(), 'src', 'app', 'settings.tsx'), 'utf8');

    expect(settingsRoute).toContain('alwaysBounceVertical={false}');
    expect(settingsRoute).toContain('bounces={false}');
    expect(settingsRoute).toContain('overScrollMode="never"');
    expect(appSource).toContain('styles.themeStatusLight');
    expect(appSource).toContain('styles.themeStatusLightCore');
    expect(appSource).not.toContain('styles.themeSwitchButton');
    expect(appSource).not.toContain('styles.themeSwitchText');
  });

  test('keeps the fixed library drag slider themed in dark mode', () => {
    const appSource = fs.readFileSync(appPath, 'utf8');

    expect(appSource).toContain('themeStyles?.libraryFloatingTopButton');
    expect(appSource).toContain('themeStyles?.libraryFloatingTopText');
    expect(appSource).toContain('themeStyles?.libraryDragSlider');
    expect(appSource).toContain('themeStyles?.libraryDragTrack');
    expect(appSource).toContain('themeStyles?.libraryDragThumb');
    expect(appSource).toContain('libraryDragIconColor');
    expect(appSource).toContain('libraryDragSlider:');
    expect(appSource).toContain('libraryDragTrack:');
    expect(appSource).toContain('libraryDragThumb:');
  });

  test('keeps library dragging synchronized with the page scroll and list body', () => {
    const appSource = fs.readFileSync(appPath, 'utf8');

    expect(appSource).toContain("import { FlashList, type FlashListRef } from '@shopify/flash-list';");
    expect(appSource).toContain('scrollTargetFromSlider');
    expect(appSource).toContain('libraryContentHeightRef.current');
    expect(appSource).toContain('libraryViewportHeightRef.current');
    expect(appSource).toContain('onContentSizeChange: libraryContentSizeChange,');
    expect(appSource).toContain('onViewportLayout: libraryViewportLayout,');
    expect(appSource).toContain('libraryListRef.current?.scrollToOffset({ offset, animated })');
    expect(appSource).toContain("webScrollNode.scrollTo({ top: offset, behavior: animated ? 'smooth' : 'auto' })");
    expect(appSource).toContain('scrollLibraryToRawOffset(targetY)');
    expect(appSource).toContain('scrollLibraryToRawOffset(offset)');
    expect(appSource).toContain('Gesture.Pan()');
    expect(appSource).toContain('<GestureDetector gesture={librarySliderGesture}>');
    expect(appSource).toContain('runOnJS(moveLibrarySliderDrag)');
    expect(appSource).toContain('transitionTimingFunction:');
    expect(appSource).not.toContain('virtualListSpacerHeights');
    expect(appSource).not.toContain('setLibraryWindowStart');
  });

  test('keeps the library drag slider tucked away until touch dragging', () => {
    const appSource = fs.readFileSync(appPath, 'utf8');

    expect(appSource).toContain('librarySliderActive');
    expect(appSource).toContain('libraryDragSliderMotionStyle');
    expect(appSource).toContain('styles.libraryDragSliderCollapsed');
    expect(appSource).toContain('styles.libraryDragSliderActive');
    expect(appSource).toContain('styles.libraryDragTrackCollapsed');
    expect(appSource).toContain('styles.libraryDragTrackActive');
    expect(appSource).toContain('styles.libraryDragThumbCollapsed');
    expect(appSource).toContain('styles.libraryDragThumbActive');
    expect(appSource).toContain('{librarySliderActive && (');
  });

  test('keeps the library drag slider adaptive and clear of the tab bar', () => {
    const appSource = fs.readFileSync(appPath, 'utf8');
    const controlsStart = appSource.indexOf('libraryFixedControls:');
    const controlsEnd = appSource.indexOf('libraryFloatingTopButton:', controlsStart);
    const sliderStart = appSource.indexOf('libraryDragSlider:', controlsEnd);
    const sliderEnd = appSource.indexOf('libraryDragSliderActive:', sliderStart);
    const controlsSource = appSource.slice(controlsStart, controlsEnd);
    const sliderSource = appSource.slice(sliderStart, sliderEnd);

    expect(appSource).toContain('const LIBRARY_FIXED_CONTROLS_TOP = 8;');
    expect(appSource).toContain('const LIBRARY_FIXED_CONTROLS_BOTTOM = 8;');
    expect(appSource).toContain('<View pointerEvents="box-none" style={styles.libraryFixedControls}>');
    expect(controlsSource).toContain('bottom: LIBRARY_FIXED_CONTROLS_BOTTOM');
    expect(controlsSource).toContain('top: LIBRARY_FIXED_CONTROLS_TOP');
    expect(controlsSource).not.toContain('height: 600');
    expect(sliderSource).toContain('bottom: 0');
    expect(sliderSource).toContain('top: 92');
    expect(sliderSource).not.toContain('height: 500');
  });

  test('keeps the first library render lightweight on phones', () => {
    const appSource = fs.readFileSync(appPath, 'utf8');

    expect(appSource).toContain('<FlashList');
    expect(appSource).toContain('drawDistance={720}');
    expect(appSource).not.toContain('<FlatList');
    expect(appSource).toContain('const LibraryWordRow = memo(function LibraryWordRow');
    expect(appSource).toContain('keyExtractor={libraryWordKeyExtractor}');
    expect(appSource).toContain('const LIBRARY_ANIMATED_ITEM_COUNT = Math.min(5, interactionMotion.staggeredListLimit);');
    expect(appSource).not.toContain('visibleWords.map(');
    expect(appSource).not.toContain('const LIBRARY_WINDOW_SIZE');
  });

  test('loads the full vocabulary after the app shell can render', () => {
    const appSource = fs.readFileSync(appPath, 'utf8');
    const loaderSource = fs.readFileSync(vocabularyLoaderPath, 'utf8');
    const nativeLoaderSource = fs.readFileSync(nativeVocabularyLoaderPath, 'utf8');
    const webLoaderSource = fs.readFileSync(webVocabularyLoaderPath, 'utf8');

    expect(appSource).not.toContain("import { sampleWords, type WordEntry } from './src/data/words';");
    expect(appSource).toContain('loadBundledVocabulary()');
    expect(loaderSource).toContain("require('../data/words')");
    expect(nativeLoaderSource).toContain("require('../data/words')");
    expect(webLoaderSource).toContain("import('../data/words')");
  });

  test('defers nonessential modules in native production bundles', () => {
    const metroSource = fs.readFileSync(metroPath, 'utf8');

    expect(metroSource).toContain('inlineRequires: true');
  });

  test('keeps high-frequency library scrolling out of root render state', () => {
    const appSource = fs.readFileSync(appPath, 'utf8');
    const handlerStart = appSource.indexOf('function handleLibraryScroll(');
    const handlerEnd = appSource.indexOf('function updateLibraryThumbFromScroll(', handlerStart);
    const handlerSource = appSource.slice(handlerStart, handlerEnd);
    const thumbStart = handlerEnd;
    const thumbEnd = appSource.indexOf('function handleLibrarySliderDrag(', thumbStart);
    const thumbSource = appSource.slice(thumbStart, thumbEnd);

    expect(handlerSource).toContain('updateLibraryThumbFromScroll(nextScrollY)');
    expect(handlerSource).not.toContain('setScrollY(');
    expect(handlerSource).not.toContain('setLibraryWindowStart(');
    expect(thumbSource).toContain('libraryThumbOffsetAnim.setValue(offset)');
    expect(appSource).toContain('<Animated.View');
    expect(appSource).toContain('transform: [{ translateY: libraryThumbOffsetAnim }]');
  });

  test('keeps library search and filters inset from the edge slider', () => {
    const appSource = fs.readFileSync(appPath, 'utf8');

    expect(appSource).toContain('styles.libraryTopControlsInset');
    expect(appSource).toContain('<View style={styles.libraryTopControlsInset}>');
    expect(appSource).toContain('libraryTopControlsInset:');
    expect(appSource).toContain('paddingRight: 32');
  });

  test('places custom sets in the library page and removes the redundant library header top button', () => {
    const appSource = fs.readFileSync(appPath, 'utf8');
    const libraryStart = appSource.indexOf('function LibraryView({');
    const libraryEnd = appSource.indexOf('function LibraryWordDetailView({');
    const profileOverviewStart = appSource.indexOf('<View style={[styles.profileCard');
    const profileSettingsStart = appSource.indexOf('accessibilityLabel={ui.openSettings}', profileOverviewStart);
    const librarySource = appSource.slice(libraryStart, libraryEnd);
    const profileOverviewSource = appSource.slice(profileOverviewStart, profileSettingsStart);

    expect(librarySource).toContain('customSets,');
    expect(librarySource).toContain('onOpenCustomSets,');
    expect(librarySource).toContain('testID="library-custom-sets-card"');
    expect(librarySource).toContain('styles.libraryCustomSetsCard');
    expect(librarySource).not.toContain('testID="library-top-return"');
    expect(profileOverviewSource).not.toContain('accessibilityLabel={ui.openCustomSets}');
  });

  test('keeps custom sets as a separate library card with compact header count', () => {
    const appSource = fs.readFileSync(appPath, 'utf8');
    const libraryStart = appSource.indexOf('function LibraryView({');
    const libraryEnd = appSource.indexOf('function LibraryWordDetailView({');
    const librarySource = appSource.slice(libraryStart, libraryEnd);

    expect(librarySource).toContain('testID="library-filtered-count-pill"');
    expect(librarySource).toContain('testID="library-custom-sets-card"');
    expect(librarySource).toContain('styles.libraryCustomSetsCard');
    expect(librarySource).toContain('styles.libraryManageSetsButtonLabel');
    expect(librarySource).toContain('{ui.manage}');
    expect(librarySource).not.toContain('{ui.openCustomSets}');
    expect(librarySource).not.toContain('styles.libraryCustomSetsStrip');
  });

  test('supports editing existing custom sets from the management page', () => {
    const appSource = fs.readFileSync(appPath, 'utf8');
    const profileSetsStart = appSource.indexOf('function ProfileCustomSetsView({');
    const profileSetsEnd = appSource.indexOf('function ProfileSettingsView({');
    const profileSetsSource = appSource.slice(profileSetsStart, profileSetsEnd);

    expect(appSource).toContain('renameCustomSet');
    expect(appSource).toContain('deleteCustomSet');
    expect(appSource).toContain('removeWordFromSet');
    expect(profileSetsSource).toContain('testID="custom-set-rename-input"');
    expect(profileSetsSource).toContain('testID="custom-set-delete-button"');
    expect(profileSetsSource).toContain('testID="custom-set-remove-word"');
    expect(profileSetsSource).toContain('onRenameCustomSet');
    expect(profileSetsSource).toContain('onDeleteCustomSet');
    expect(profileSetsSource).toContain('onRemoveWordFromSet');
  });

  test('keeps advanced custom set editing inside a dedicated set settings page', () => {
    const appSource = fs.readFileSync(appPath, 'utf8');
    const profileSetsStart = appSource.indexOf('function ProfileCustomSetsView({');
    const profileSetsEnd = appSource.indexOf('function ProfileSettingsView({');
    const profileSetsSource = appSource.slice(profileSetsStart, profileSetsEnd);

    const listStart = profileSetsSource.indexOf('testID="custom-set-list-panel"');
    const detailStart = profileSetsSource.indexOf('testID="custom-set-detail-panel"');
    const listSource = profileSetsSource.slice(listStart, detailStart);
    const detailSource = profileSetsSource.slice(detailStart);

    expect(profileSetsSource).toContain("type CustomSetPanel = 'list' | 'detail'");
    expect(profileSetsSource).toContain('setCustomSetPanel');
    expect(profileSetsSource).toContain('testID="custom-set-settings-button"');
    expect(profileSetsSource).toContain('testID="custom-set-detail-actions"');
    expect(listSource).not.toContain('testID="custom-set-rename-input"');
    expect(listSource).not.toContain('testID="custom-set-delete-button"');
    expect(listSource).not.toContain('testID="custom-set-remove-word"');
    expect(detailSource).toContain('testID="custom-set-rename-input"');
    expect(detailSource).toContain('testID="custom-set-delete-button"');
    expect(detailSource).toContain('testID="custom-set-remove-word"');
  });

  test('adds a custom-set button to the study word card', () => {
    const appSource = fs.readFileSync(appPath, 'utf8');
    const studyStart = appSource.indexOf('function StudyView({');
    const studyEnd = appSource.indexOf('function FilterControlPanel({');
    const appStudyCallStart = appSource.indexOf('studyProps: {');
    const appStudyCallEnd = appSource.indexOf('\n    },', appStudyCallStart);
    const studySource = appSource.slice(studyStart, studyEnd);
    const studyCallSource = appSource.slice(appStudyCallStart, appStudyCallEnd);

    expect(studyCallSource).toContain('onAddToSet: handleOpenSetPicker,');
    expect(studySource).toContain('onAddToSet,');
    expect(studySource).toContain('testID="study-add-to-set"');
    expect(studySource).toContain('ui.addToSetName(formatWordPrimary(word, studyMode))');
  });

  test('keeps the library keyboard open while search results update', () => {
    const appSource = fs.readFileSync(appPath, 'utf8');
    const scrollResetStart = appSource.indexOf("if (activeTab === 'library') {");
    const scrollResetEnd = appSource.indexOf('useEffect(() => {', scrollResetStart + 1);
    const scrollResetSource = appSource.slice(scrollResetStart, scrollResetEnd);

    expect(scrollResetSource).not.toContain('searchQuery');
    expect(appSource).toContain('keyboardDismissMode="on-drag"');
    expect(appSource).toContain('ref={searchInputRef}');
    expect(appSource).toContain('onChangeText={onQueryChange}');
    expect(appSource).not.toContain('key={query}');
  });

  test('provides a grouped native-style home dashboard with an independent dictionary', () => {
    const appSource = fs.readFileSync(appPath, 'utf8');
    const homeStart = appSource.indexOf('const HomeView = memo(function HomeView');
    const homeEnd = appSource.indexOf('function StudySwipeRevealGradient', homeStart);
    const homeSource = appSource.slice(homeStart, homeEnd);

    expect(homeSource).toContain('testID="home-dictionary-search"');
    expect(homeSource).toContain('testID="home-dictionary-modal"');
    expect(homeSource).toContain('testID="home-metrics-group"');
    expect(homeSource).toContain('testID="home-action-group"');
    expect(homeSource).toContain('styles.homeActionDivider');
    expect(homeSource).toContain('<Modal');
    expect(homeSource).toContain('filterWords(vocabularyWords, progress, normalizedDictionaryQuery');
    expect(homeSource).toContain('onOpenDictionaryWord');
    expect(homeSource).toContain('useNativeDriver: Platform.OS !== \'web\'');
    expect(homeSource).toContain('allowSwipeDismissal={IS_NATIVE_IOS}');
    expect(homeSource).toContain("presentationStyle={IS_NATIVE_IOS ? 'pageSheet' : 'overFullScreen'}");
    expect(homeSource).toContain("clearButtonMode={IS_NATIVE_IOS ? 'while-editing' : 'never'}");
    expect(homeSource).not.toContain('copy.heroText');
    expect(homeSource).toContain('styles.homeDictionaryLauncherIcon');
    expect(homeSource.indexOf('testID="home-dictionary-search"')).toBeGreaterThan(
      homeSource.indexOf('onPress={onOpenReview}'),
    );
    expect(appSource).not.toContain('const homeDictionarySearch = useStableEvent');
    expect(appSource).not.toContain('setLibrarySearchFocusRequest');
    expect(homeSource).not.toContain('onOpenAccount');
  });

  test('turns the study card into a randomized native swipe deck with navigation buttons', () => {
    const appSource = fs.readFileSync(appPath, 'utf8');
    const progressSource = fs.readFileSync(path.join(process.cwd(), 'src', 'lib', 'progress.ts'), 'utf8');
    const studyStart = appSource.indexOf('const StudyView = memo(function StudyView');
    const studyEnd = appSource.indexOf('function FilterControlPanel({');
    const studySource = appSource.slice(studyStart, studyEnd);
    // The study screen is its own route now, so its props are assembled as an
    // object in the provider rather than spread across JSX attributes.
    const appStudyCallStart = appSource.indexOf('studyProps: {');
    const appStudyCallEnd = appSource.indexOf('\n    },', appStudyCallStart);
    const studyCallSource = appSource.slice(appStudyCallStart, appStudyCallEnd);

    expect(appSource).toContain('buildStudySession');
    expect(appSource).toContain('const [studySeed, setStudySeed]');
    expect(progressSource).toContain('export function buildStudySession');
    expect(appSource).toContain('const StudyView = memo(function StudyView');
    expect(appSource).toContain('const cardMotionStyle = useMemo(');
    expect(studyCallSource).toContain('onPrevious: studyPreviousWord,');
    expect(studyCallSource).toContain('onNext: studyNextWord,');
    expect(studyCallSource).toContain('onSwipeKnown: studySwipeKnown,');
    expect(studyCallSource).toContain('onSwipeReview: studySwipeReview,');
    expect(studySource).toContain('Gesture.Pan()');
    expect(studySource).toContain('.activeOffsetX([-10, 10])');
    expect(studySource).toContain('.failOffsetY([-12, 12])');
    expect(studySource).toContain('<GestureDetector gesture={studySwipeGesture}>');
    expect(studySource).toContain('const swipeX = useSharedValue(0)');
    expect(studySource).toContain('const slidingCardStyle = useAnimatedStyle');
    expect(studySource).toContain('swipeX.value = nextX');
    expect(studySource).toContain('swipeX.value = withSpring(');
    expect(studySource).toContain('runOnJS(fireSwipeHaptic)()');
    expect(studySource).toContain("triggerPressHaptic('chip')");
    expect(studySource).toContain("triggerPressHaptic('primary')");
    expect(studySource).toContain('STUDY_SWIPE_MIN_EXIT_VELOCITY');
    expect(studySource).toContain('velocity: releaseVelocity');
    expect(studySource).toContain('rotateZ');
    expect(studySource).toContain('const swipeExitX = Math.max(320, Math.min(440, viewportWidth - 16))');
    expect(studySource).toContain('swipeX.value = withDecay(');
    expect(studySource).toContain('clamp: directionCode > 0 ? [0, swipeExitX] : [-swipeExitX, 0]');
    expect(studySource).toContain('deckUnderlayStyle');
    expect(studySource).toContain('swipeCommitPulse');
    expect(studySource).toContain('const swipeHintX = useSharedValue(0)');
    expect(studySource).toContain('withSequence(');
    expect(studySource).toContain('scheduleStudySwipeHint(STUDY_SWIPE_HINT_IDLE_DELAY_MS)');
    expect(studySource).toContain('cancelAnimation(swipeHintX)');
    expect(studySource).toContain('if (swipePhase.value === 3)');
    expect(studySource).toContain('swipePhase.value = 3');
    expect(studySource).toContain('if (swipePhase.value !== 1)');
    expect(studySource).toContain('velocity: event.velocityX');
    expect(appSource).not.toContain('PanResponder');
    expect(appSource).not.toContain('studySwipeScrollLocked');
    expect(studySource).toContain('styles.studySwipeRevealFill');
    expect(studySource).toContain('<StudySwipeRevealGradient tone="review" />');
    expect(studySource).toContain('<StudySwipeRevealGradient tone="known" />');
    expect(studySource).toContain('const reviewRevealGlowStyle');
    expect(studySource).toContain('const knownRevealGlowStyle');
    expect(appSource).toContain('function StudySwipeRevealGradient');
    expect(appSource).toContain('SvgRadialGradient');
    expect(appSource).toContain('SvgLinearGradient');
    expect(appSource).toContain('SvgMask');
    expect(studySource).toContain('cardEntryProgress');
    expect(studySource).toContain('const cardEntryProgress = useSharedValue(1)');
    expect(studySource).toContain('const cardVisibility = useSharedValue(1)');
    expect(studySource).toContain('cardVisibility.value = 0');
    expect(studySource).not.toContain('cardSwapOpacity');
    expect(studySource).toContain('onSwipeReview');
    expect(studySource).toContain('onSwipeKnown');
    expect(studySource).toContain('testID="study-navigation-controls"');
    expect(appSource).toContain('adjustsFontSizeToFit={Platform.OS === \'ios\'}');
    expect(appSource).toContain('minimumFontScale={0.72}');
    expect(appSource).toContain('styles.studyWordIdentity');
    expect(studySource).toContain('ui.previousWord');
    expect(studySource).toContain('ui.nextWord');
  });
});
