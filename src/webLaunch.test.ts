import fs from 'node:fs';
import path from 'node:path';
import { describe, expect, test } from 'vitest';
import app from '../app.json';

const manifestPath = path.join(process.cwd(), 'public', 'manifest.json');
const versionPath = path.join(process.cwd(), 'public', 'version.json');
const serviceWorkerPath = path.join(process.cwd(), 'public', 'service-worker.js');
const headersPath = path.join(process.cwd(), 'public', '_headers');
const appPath = path.join(process.cwd(), 'App.tsx');
const prepareExportPath = path.join(process.cwd(), 'scripts', 'prepare-web-export.mjs');
const rootAppleIconPath = path.join(process.cwd(), 'public', 'apple-touch-icon.png');
const rootApplePrecomposedIconPath = path.join(process.cwd(), 'public', 'apple-touch-icon-precomposed.png');

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

  test('provides a version endpoint for mobile web app update checks', () => {
    const version = JSON.parse(fs.readFileSync(versionPath, 'utf8'));

    expect(typeof version.version).toBe('string');
    expect(version.version.length).toBeGreaterThan(0);
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
  });

  test('includes quiz session setup with selectable question counts', () => {
    const appSource = fs.readFileSync(appPath, 'utf8');

    expect(appSource).toContain('選擇題數');
    expect(appSource).toContain('開始測驗');
    expect(appSource).toContain('const quizQuestionCounts = [10, 20, 50] as const;');
    expect(appSource).toContain('{count} {ui.questionUnit}');
    expect(appSource).toContain('測驗完成');
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
    expect(appSource).toContain('libraryDetailAnim');
    expect(appSource).toContain('detailMotionStyle');
    expect(appSource).toContain('libraryDetailAnim.setValue(0)');
  });

  test('includes a developer vocabulary panel for import and export workflow', () => {
    const appSource = fs.readFileSync(appPath, 'utf8');

    expect(appSource).toContain('開發人員資料窗口');
    expect(appSource).toContain('developer-vocabulary-panel');
    expect(appSource).toContain('exportWordsToCsv');
    expect(appSource).toContain('parseVocabularyImport');
    expect(appSource).toContain('applyVocabularyImportRows');
    expect(appSource).toContain('清除本機預覽');
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
    expect(appSource).toContain('切到中文單字');
    expect(appSource).toContain('Switch back to English words');
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
    expect(appSource).toContain("toggleTitle: 'Switch back to English words'");
    expect(appSource).toContain("libraryTitle: 'Chinese Word Library'");
    expect(appSource).toContain("searchPlaceholder: 'Search Chinese, English words, examples, or translations'");
    expect(appSource).toContain("studyFilterTitle: 'Study Filters'");
    expect(appSource).toContain("quizFilterTitle: 'Quiz Filters'");
    expect(appSource).toContain("questionBankUnit: 'Chinese words'");
    expect(appSource).toContain('modeInterfaceCopy');
    expect(appSource).toContain('styles.modeSwitchBackdrop');
    expect(appSource).toContain('styles.modeSwitchPanel');
    expect(appSource).toContain('bottom: 0');
    expect(appSource).toContain('top: 0');
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

    expect(appSource).toContain('libraryDetailPanelMotionStyle');
    expect(appSource).toContain('detailMotionStyle={libraryDetailPanelMotionStyle}');
    expect(appSource).toContain('duration: interactionMotion.settingsPanelMs');
    expect(appSource).toContain('function closeLibraryWordDetail()');
    expect(appSource).toContain('duration: interactionMotion.settingsPanelExitMs');
    expect(appSource).toContain('easing: Easing.out(Easing.cubic),\n      toValue: 0');
    expect(appSource).toContain('toValue: 0');
    expect(appSource).toContain('onCloseWord={closeLibraryWordDetail}');
    expect(appSource).toContain('Animated.View style={[styles.screenStack, motionStyle]}');
  });

  test('keeps the current scroll position during profile settings transitions', () => {
    const appSource = fs.readFileSync(appPath, 'utf8');

    expect(appSource).toContain('onProfilePanelSwap');
    expect(appSource).toContain('onPanelSwap={onProfilePanelSwap}');
    expect(appSource).toContain('setSelectedLibraryWord(null);');
    expect(appSource).toContain('}, [activeTab, activeFilter, activeInitial, activeLevel, searchQuery]);');
    expect(appSource).not.toContain('}, [activeTab, activeFilter, activeInitial, activeLevel, profilePanel, searchQuery]);');
  });

  test('returns from word detail to the previous library position without replaying the list', () => {
    const appSource = fs.readFileSync(appPath, 'utf8');

    expect(appSource).toContain('libraryReturnScrollYRef');
    expect(appSource).toContain('restoreLibraryScrollPosition');
    expect(appSource).toContain('libraryReturnScrollYRef.current = scrollY;');
    expect(appSource).toContain('appScrollRef.current?.scrollTo({ y: libraryReturnScrollYRef.current, animated: false });');
    expect(appSource).toContain('LIBRARY_ANIMATED_ITEM_COUNT');
    expect(appSource).toContain("activeTab === 'library' && index >= LIBRARY_ANIMATED_ITEM_COUNT");
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
});
