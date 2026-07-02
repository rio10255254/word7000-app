import fs from 'node:fs';
import path from 'node:path';
import { describe, expect, test } from 'vitest';
import app from '../app.json';

const manifestPath = path.join(process.cwd(), 'public', 'manifest.json');
const versionPath = path.join(process.cwd(), 'public', 'version.json');
const serviceWorkerPath = path.join(process.cwd(), 'public', 'service-worker.js');
const headersPath = path.join(process.cwd(), 'public', '_headers');
const appPath = path.join(process.cwd(), 'App.tsx');
const schemaPath = path.join(process.cwd(), 'supabase', 'schema.sql');
const prepareExportPath = path.join(process.cwd(), 'scripts', 'prepare-web-export.mjs');
const privacyPath = path.join(process.cwd(), 'public', 'privacy.html');
const supportPath = path.join(process.cwd(), 'public', 'support.html');
const rootAppleIconPath = path.join(process.cwd(), 'public', 'apple-touch-icon.png');
const rootApplePrecomposedIconPath = path.join(process.cwd(), 'public', 'apple-touch-icon-precomposed.png');
const accountSetupPath = path.join(process.cwd(), 'ACCOUNT_GOOGLE_LOGIN.md');

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

  test('includes a first-launch Safari add-to-home-screen guide', () => {
    const appSource = fs.readFileSync(appPath, 'utf8');

    expect(appSource).toContain('INSTALL_GUIDE_STORAGE_KEY');
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
    expect(quizSource).toContain('ui.iSpoke');
    expect(quizSource).toContain('ui.showSampleAnswer');
    expect(quizSource).toContain('ui.sampleAnswer');
    expect(quizSource).toContain('ui.sampleTranslation');
    expect(quizSource).not.toContain('styles.pronunciation');
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

    expect(appSource).toContain('selectedLibraryWord');
    expect(appSource).toContain('library-word-detail');
    expect(appSource).toContain('返回字庫');
    expect(appSource).toContain('完整資訊');
    expect(appSource).toContain('onOpenWord');
    expect(appSource).toContain("type LibraryPanel = 'list' | 'detail' | 'sets'");
    expect(appSource).toContain('renderedLibraryPanel');
    expect(appSource).toContain('libraryPanelMotionStyle');
    expect(appSource).toContain("setLibraryPanel('detail')");
    expect(appSource).toContain("setLibraryPanel('list')");
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

    expect(appSource).toContain("type ProfilePanel = 'overview' | 'settings'");
    expect(appSource).toContain('ProfileLearningExperiencePanel');
    expect(appSource).toContain('ProfileTutorialPanel');
    expect(appSource).toContain('profile-settings-panel');
    expect(appSource).toContain('開啟設定');
    expect(appSource).toContain('返回我的');
    expect(appSource).toContain('App 設定');
    expect(appSource).toContain('深色模式');
    expect(appSource).toContain('word7000-theme-v1');
    expect(appSource).toContain('onThemeModeChange');
    expect(appSource).toContain('DeveloperVocabularyPanel');
  });

  test('includes App Store support links and account data deletion controls', () => {
    const appSource = fs.readFileSync(appPath, 'utf8');
    const schema = fs.readFileSync(schemaPath, 'utf8');

    expect(fs.existsSync(privacyPath)).toBe(true);
    expect(fs.existsSync(supportPath)).toBe(true);
    expect(appSource).toContain('appInfoLinks.privacy');
    expect(appSource).toContain('appInfoLinks.support');
    expect(appSource).toContain('onConfirmDeleteAccountData={confirmDeleteAccountData}');
    expect(appSource).toContain('testID="delete-account-data-button"');
    expect(appSource).toContain('deleteCloudUserData(asCloudProgressClient(supabaseClient), signedInUserId)');
    expect(schema).toContain('Users can delete their own profile');
    expect(schema).toContain('Users can delete their own daily activity');
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

    expect(appSource).toContain("from './src/lib/authRedirect'");
    expect(appSource).toContain('loadCloudProgressRecord');
    expect(appSource).toContain('saveCloudCustomSets');
    expect(appSource).toContain('mergeCustomSetStates');
    expect(appSource).toContain("cloudProgress.progress ?? (cloudProgress.errorMessage ? userLocalProgress : initialProgress)");
    expect(appSource).toContain('mergeCustomSetStates(cloudProgress.customSets, loadCustomSetState(storage, user.id), loadCustomSetState(storage))');
    expect(appSource).toContain('saveProgressToStorage(getAppStorage(), progress, account.userId)');
    expect(appSource).toContain('saveCustomSetState(getAppStorage(), customSetState, account.userId)');
    expect(appSource).toContain('saveProgressToStorage(storage, loadedProgress, user.id)');
    expect(appSource).toContain('await saveCloudProgress(asCloudProgressClient(supabaseClient), signedInUserId, progress)');
    expect(appSource).toContain('await saveCloudCustomSets(asCloudProgressClient(supabaseClient), signedInUserId, customSetState)');
    expect(appSource).toContain('loadProgressFromStorage(getAppStorage(), initialProgress)');
    expect(appSource).toContain('handleGoogleSignIn');
    expect(appSource).toContain("provider: 'google'");
    expect(appSource).toContain('signInWithOAuth');
    expect(appSource).toContain('getOAuthRedirectUrl()');
    expect(appSource).toContain("prompt: 'select_account'");
    expect(appSource).toContain('skipBrowserRedirect: Platform.OS !==');
    expect(appSource).toContain('使用 Google 快速登入');
    expect(appSource).toContain('Continue with Google');
    expect(appSource).toContain('handleAppleSignIn');
    expect(appSource).toContain("provider: 'apple'");
    expect(appSource).toContain('Email 備用登入');
    expect(appSource).toContain('Email fallback');
    expect(appSource).toContain('onGoogleSignIn={handleGoogleSignIn}');
  });

  test('records signed-in daily active users for Supabase analytics', () => {
    const appSource = fs.readFileSync(appPath, 'utf8');
    const schema = fs.readFileSync(schemaPath, 'utf8');

    expect(appSource).toContain('ACTIVE_USER_HEARTBEAT_MS = 60_000');
    expect(appSource).toContain('recordDailyActiveUser(asCloudProgressClient(supabaseClient), account.userId)');
    expect(appSource).toContain('setInterval(recordActivity, ACTIVE_USER_HEARTBEAT_MS)');
    expect(schema).toContain('custom_sets jsonb');
    expect(schema).toContain('create table if not exists public.daily_active_users');
    expect(schema).toContain('primary key (user_id, activity_date)');
    expect(schema).toContain('daily_active_users_activity_date_idx');
    expect(schema).toContain('daily_active_users_last_seen_at_idx');
    expect(schema).toContain('Users can insert their own daily activity');
    expect(schema).toContain('Users can update their own daily activity');
  });

  test('documents the Google account setup needed after deployment', () => {
    const setupGuide = fs.readFileSync(accountSetupPath, 'utf8');

    expect(setupGuide).toContain('Supabase');
    expect(setupGuide).toContain('Google');
    expect(setupGuide).toContain('supabase/schema.sql');
    expect(setupGuide).toContain('Redirect URLs');
    expect(setupGuide).toContain('EXPO_PUBLIC_SUPABASE_URL');
    expect(setupGuide).toContain('EXPO_PUBLIC_SUPABASE_ANON_KEY');
    expect(setupGuide).toContain('Cloudflare Pages');
  });

  test('injects public Supabase settings into the exported web runtime', () => {
    const prepareScript = fs.readFileSync(path.join(process.cwd(), 'scripts', 'prepare-web-export.mjs'), 'utf8');

    expect(prepareScript).toContain('globalThis.__WORD7000_CONFIG__');
    expect(prepareScript).toContain('EXPO_PUBLIC_SUPABASE_URL');
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
    expect(appSource).toContain('onLayout={handlePanelContentLayout}');
    expect(appSource).toContain('pointerEvents={open ?');
    expect(appSource).toContain('styles.filterPanelContent');
    expect(appSource).toContain('filterPanelWebTransition');
    expect(appSource).toContain("transitionProperty: 'height, opacity, border-top-width, transform'");
    expect(appSource).toContain('styles.filterSummaryButtonOpen');
    expect(appSource).toContain('styles.libraryItemPressed');
    expect(appSource).not.toContain('maxHeight: panelAnim.interpolate');
  });

  test('adds an English alphabetical sort option inside the library filter panel', () => {
    const appSource = fs.readFileSync(appPath, 'utf8');

    expect(appSource).toContain('type LibrarySort,');
    expect(appSource).toContain('activeSort={activeSort}');
    expect(appSource).toContain("sort: activeSort");
    expect(appSource).toContain('onSortChange={setActiveSort}');
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

  test('animates profile settings and fully darkens the install guide', () => {
    const appSource = fs.readFileSync(appPath, 'utf8');

    expect(appSource).toContain('profilePanelAnim');
    expect(appSource).toContain('renderedProfilePanel');
    expect(appSource).toContain('settingsPanelMotionStyle');
    expect(appSource).toContain('interactionMotion.settingsPanelMs');
    expect(appSource).toContain('interactionMotion.settingsPanelExitMs');
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
    const openDetailBlock = appSource.slice(
      appSource.indexOf('function openLibraryWordDetail'),
      appSource.indexOf('function closeLibraryWordDetail')
    );

    expect(appSource).toContain("type LibraryPanel = 'list' | 'detail' | 'sets'");
    expect(appSource).toContain("const [libraryPanel, setLibraryPanel] = useState<LibraryPanel>('list');");
    expect(appSource).toContain("const [renderedLibraryPanel, setRenderedLibraryPanel] = useState<LibraryPanel>('list');");
    expect(appSource).toContain('const libraryPanelAnim = useRef(new Animated.Value(1)).current;');
    expect(appSource).toContain('duration: interactionMotion.settingsPanelMs');
    expect(appSource).toContain('duration: interactionMotion.settingsPanelExitMs');
    expect(appSource).toContain('easing: Easing.out(Easing.cubic)');
    expect(appSource).toContain('easing: Easing.in(Easing.cubic)');
    expect(appSource).toContain("outputRange: [renderedLibraryPanel === 'detail' ? 18 : -12, 0]");
    expect(appSource).toContain('outputRange: [0.985, 1]');
    expect(appSource).toContain('setRenderedLibraryPanel(libraryPanel);');
    expect(appSource).toContain('libraryPanelMotionStyle');
    expect(appSource).toContain('libraryListPanelHorizontalMotionStyle');
    expect(appSource).toContain('libraryListPanelMotionStyle');
    expect(appSource).toContain('libraryDetailStageMotionStyle');
    expect(appSource).toContain("transformOrigin: 'top center'");
    expect(appSource).toContain('testID="library-panel-transition"');
    expect(appSource).toContain('testID="library-detail-stage"');
    expect(appSource).toContain('styles.libraryDetailStage');
    expect(appSource).toContain('style={[styles.screenMotion, screenMotionStyle]}');
    expect(appSource).not.toContain('libraryDepthMotionStyle');
    expect(appSource).not.toContain('libraryDetailBackdropMotionStyle');
    expect(appSource).not.toContain('libraryDetailPanelMotionStyle');
    expect(appSource).not.toContain('style={[styles.screenMotion, screenMotionStyle, libraryDepthMotionStyle]}');
    expect(appSource).not.toContain('styles.libraryDetailOverlay');
    expect(appSource).not.toContain('styles.libraryDetailBackdrop');
    expect(appSource).not.toContain('styles.libraryDetailPanel');
    expect(openDetailBlock).toContain('setSelectedLibraryWord(word);');
    expect(openDetailBlock).toContain("setLibraryPanel('detail');");
    expect(openDetailBlock).not.toContain('Animated.timing');
    expect(appSource).toContain('function closeLibraryWordDetail()');
    expect(appSource).toContain("setLibraryPanel('list');");
    expect(appSource).not.toContain("studyMode === 'chinese' && libraryDetailOpen");
    expect(appSource).toContain('toValue: 0');
    expect(appSource).toContain('onBack={closeLibraryWordDetail}');
    expect(appSource).toContain('pressTone="libraryItem"');
    expect(appSource).toContain('styles.libraryItemPressedLift');
  });

  test('keeps the current scroll position during profile settings transitions', () => {
    const appSource = fs.readFileSync(appPath, 'utf8');

    expect(appSource).toContain('onProfilePanelSwap');
    expect(appSource).toContain('onPanelSwap={onProfilePanelSwap}');
    expect(appSource).toContain('setSelectedLibraryWord(null);');
    expect(appSource).toContain('}, [activeTab, activeFilter, activeInitial, activeLevel, activeSort, searchQuery]);');
    expect(appSource).not.toContain('}, [activeTab, activeFilter, activeInitial, activeLevel, activeSort, profilePanel, searchQuery]);');
  });

  test('returns from word detail to the previous library position without replaying the list', () => {
    const appSource = fs.readFileSync(appPath, 'utf8');

    expect(appSource).toContain('libraryListPanelMotionStyle');
    expect(appSource).toContain('libraryDetailStageMotionStyle');
    expect(appSource).toContain('styles.libraryPanelHidden');
    expect(appSource).toContain('pointerEvents={renderedLibraryPanel ===');
    expect(appSource).toContain('contentContainerStyle={styles.libraryDetailStageContent}');
    expect(appSource).toContain('setSelectedLibraryWord(null);');
    expect(appSource).toContain('LIBRARY_ANIMATED_ITEM_COUNT');
    expect(appSource).toContain("activeTab === 'library' && index >= LIBRARY_ANIMATED_ITEM_COUNT");
    expect(appSource).not.toContain('if (selectedWord) {');
    expect(appSource).not.toContain('readCurrentAppScrollY');
    expect(appSource).not.toContain('restoreLibraryScrollPositionAfterRender');
    expect(appSource).not.toContain('setSelectedLibraryWord(word);\n    appScrollRef.current?.scrollTo({ y: 0, animated: true });');
    expect(appSource).not.toContain('selectedLibraryWord?.id,');
  });

  test('uses a full-page fade when toggling dark mode colors', () => {
    const appSource = fs.readFileSync(appPath, 'utf8');

    expect(appSource).toContain('themeTransitionAnim');
    expect(appSource).toContain('showThemeTransition');
    expect(appSource).toContain('themeTransitionTarget');
    expect(appSource).toContain('function triggerThemeModeChange(nextMode: ThemeMode)');
    expect(appSource).toContain('onThemeModeChange={triggerThemeModeChange}');
    expect(appSource).toContain('styles.themeTransitionOverlay');
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

    expect(appSource).toContain('wordWindowStartFromFullLibraryScroll');
    expect(appSource).toContain('virtualListSpacerHeights');
    expect(appSource).toContain('virtualWindowStartFromScroll');
    expect(appSource).toContain('virtualWindowStartFromWordIndex');
    expect(appSource).toContain('libraryListScrollTarget');
    expect(appSource).toContain('styles.virtualLibrarySpacer');
    expect(appSource).toContain('onListLayout={handleLibraryListLayout}');
    expect(appSource).toContain('onFirstItemLayout={handleLibraryFirstItemLayout}');
    expect(appSource).toContain('LIBRARY_LIST_DRAG_MIN_SCROLL_Y');
    expect(appSource).toContain('transitionTimingFunction:');
    expect(appSource).not.toContain('appScrollRef.current?.scrollTo({ y: 0, animated: false });\n    setScrollY(0);\n  }\n\n  function returnLibraryToTop');
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
    const appStudyCallStart = appSource.indexOf('<StudyView');
    const appStudyCallEnd = appSource.indexOf('/>', appStudyCallStart);
    const studySource = appSource.slice(studyStart, studyEnd);
    const studyCallSource = appSource.slice(appStudyCallStart, appStudyCallEnd);

    expect(studyCallSource).toContain('onAddToSet={handleOpenSetPicker}');
    expect(studySource).toContain('onAddToSet,');
    expect(studySource).toContain('testID="study-add-to-set"');
    expect(studySource).toContain('ui.addToSetName(formatWordPrimary(word, studyMode))');
  });
});
