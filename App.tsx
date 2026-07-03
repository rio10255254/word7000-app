import { StatusBar } from 'expo-status-bar';
import * as AppleAuthentication from 'expo-apple-authentication';
import * as WebBrowser from 'expo-web-browser';
import {
  ArrowUp,
  BookOpen,
  Check,
  ChevronLeft,
  ChevronDown,
  ChevronRight,
  Cloud,
  Compass,
  Database,
  Download,
  GripVertical,
  Home,
  Library,
  Lock,
  LogIn,
  LogOut,
  Languages,
  Mail,
  Moon,
  RotateCcw,
  Search,
  Settings,
  SlidersHorizontal,
  Smartphone,
  SquareArrowUp,
  SquarePlus,
  Star,
  Sun,
  Target,
  Trash2,
  Trophy,
  Upload,
  User,
  X,
} from 'lucide-react-native';
import { createContext, memo, useCallback, useContext, useEffect, useMemo, useRef, useState, type ReactNode } from 'react';
import {
  Alert,
  Animated,
  Easing,
  type LayoutChangeEvent,
  type NativeScrollEvent,
  type NativeSyntheticEvent,
  PanResponder,
  Pressable,
  type PressableProps,
  Platform,
  SafeAreaView,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  type StyleProp,
  View,
  type ViewStyle,
  Linking,
} from 'react-native';
import { sampleWords, type WordEntry } from './src/data/words';
import {
  libraryListScrollTarget,
  scrollThumbOffset,
  shouldSyncLibraryWindowFromScroll,
  virtualListSpacerHeights,
  virtualWindowStartFromScroll,
  virtualWindowStartFromWordIndex,
  wordWindowStartFromFullLibraryScroll,
  wordWindowStartFromSlider,
} from './src/lib/libraryNavigation';
import {
  buildQuizOptions,
  buildQuizSession,
  computeStats,
  filterWords,
  markKnown,
  markReview,
  normalizeProgressForDate,
  selectQuizWords,
  selectStudyWords,
  toggleFavorite,
  type QuizOption,
  type LibraryFilter,
  type LibrarySort,
  type ProgressState,
} from './src/lib/progress';
import { createAppSupabaseClient, type AppSupabaseClient } from './src/lib/supabaseClient';
import { loadProgressFromStorage, progressStorageKey, saveProgressToStorage, type StorageLike } from './src/lib/progressStorage';
import {
  deleteCloudUserData,
  loadCloudProgressRecord,
  recordDailyActiveUser,
  saveCloudCustomSets,
  saveCloudProgress,
  type CloudProgressClient,
} from './src/lib/supabaseProgress';
import type { User as SupabaseUser } from '@supabase/supabase-js';
import { interactionMotion, listEnterOffset, pressMotionFor, type InteractionTone } from './src/lib/interactionMotion';
import {
  INSTALL_GUIDE_STORAGE_KEY,
  markInstallGuideSeen,
  shouldShowInstallGuide,
} from './src/lib/installGuide';
import {
  applyVocabularyImportRows,
  clearDeveloperVocabulary,
  exportWordsToCsv,
  loadDeveloperVocabulary,
  parseVocabularyImport,
  saveDeveloperVocabulary,
  type DeveloperVocabularySnapshot,
} from './src/lib/developerVocabulary';
import {
  chineseMeaningPinyin,
  conciseChineseMeaning,
  supplementalChineseMeaning,
} from './src/lib/chineseDisplay';
import { buildConversationPrompt, type ConversationPromptCard } from './src/lib/conversationPrompts';
import {
  loadFilterPreferences,
  saveFilterPreferences,
} from './src/lib/filterPreferences';
import { authRedirectTo, nativeAuthRedirectTo } from './src/lib/authRedirect';
import {
  addCustomWordToSet,
  addWordToSet,
  createCustomSet,
  customWordsFromImportRows,
  deleteCustomSet,
  loadCustomSetState,
  mergeCustomSetStates,
  mergeCustomWords,
  parseCustomWordsCsv,
  removeWordFromSet,
  renameCustomSet,
  saveCustomSetState,
  customSetStorageKey,
  sortCustomSets,
  wordsForCustomSet,
  type CustomSetSort,
  type CustomSetState,
  type CustomVocabSet,
} from './src/lib/customSets';
import { getAppStorage, hydrateAppStorage, isAppStorageHydrated } from './src/lib/appStorage';
import { parseOAuthCallbackUrl } from './src/lib/oauthCallback';
import { appInfoLinks } from './src/lib/appLinks';

WebBrowser.maybeCompleteAuthSession();

type Tab = 'home' | 'study' | 'quiz' | 'library' | 'profile';
type ProfilePanel = 'overview' | 'settings';
type LibraryPanel = 'list' | 'detail' | 'sets';
type AccountStatus = 'local' | 'loading' | 'signedOut' | 'signedIn' | 'syncing' | 'saved' | 'error';
type ThemeMode = 'light' | 'dark';
type StudyMode = 'english' | 'chinese';
type QuizPracticeMode = 'choice' | 'speaking';
type ManualCustomWordState = {
  example: string;
  exampleZh: string;
  meaningZh: string;
  partOfSpeech: string;
  pronunciation: string;
  word: string;
};

type AccountState = {
  configured: boolean;
  email: string;
  password: string;
  userId: string | null;
  userEmail: string | null;
  busy: boolean;
  status: AccountStatus;
  message: string;
};
type UpdateState = {
  available: boolean;
  buttonText: string;
  countdownSeconds: number;
  countdownText: string;
  detail: string;
  message: string;
  refresh: () => void;
};
type FilterOption = {
  id: string;
  label: string;
};

const today = new Date().toISOString().slice(0, 10);
const UPDATE_STORAGE_KEY = 'word7000-version-v1';
const UPDATE_AUTO_REFRESH_MS = 6500;
const UPDATE_CHECK_INTERVAL_MS = 60_000;
const ACTIVE_USER_HEARTBEAT_MS = 60_000;
const THEME_STORAGE_KEY = 'word7000-theme-v1';
const STUDY_MODE_STORAGE_KEY = 'word7000-study-mode-v1';
const CUSTOM_SET_SORT_STORAGE_KEY = 'word7000-custom-set-sort-v1';
const APP_LINKING_SCHEME = 'word7000';
const WEB_IOS_PREVIEW_QUERY_KEYS = ['ios-preview', 'iosPreview', 'preview-ios'];
function isWebIosPreviewMode() {
  if (Platform.OS !== 'web') {
    return false;
  }

  const location = (globalThis as { location?: Location }).location;
  if (!location?.search) {
    return false;
  }

  const params = new URLSearchParams(location.search);
  return WEB_IOS_PREVIEW_QUERY_KEYS.some((key) => {
    const value = params.get(key);
    return value === '' || value === '1' || value === 'true' || value === 'yes';
  });
}
const IS_WEB_IOS_PREVIEW = isWebIosPreviewMode();
const IOS_BOTTOM_SAFE_AREA_FALLBACK = Platform.OS === 'ios' || IS_WEB_IOS_PREVIEW ? 28 : 0;
const WEB_TAB_BAR_BOTTOM_OFFSET = 8;
const IOS_TAB_BAR_BOTTOM_OFFSET = Platform.OS === 'web'
  ? IS_WEB_IOS_PREVIEW
    ? 16 + IOS_BOTTOM_SAFE_AREA_FALLBACK
    : WEB_TAB_BAR_BOTTOM_OFFSET
  : 16 + IOS_BOTTOM_SAFE_AREA_FALLBACK;
const WEB_IOS_PREVIEW_SCROLL_BOTTOM_INSET = IOS_TAB_BAR_BOTTOM_OFFSET + 72;
const IOS_CONTENT_BOTTOM_PADDING = 102 + IOS_BOTTOM_SAFE_AREA_FALLBACK;
const LIBRARY_SLIDER_THUMB_HEIGHT = 42;
const LIBRARY_ITEM_ESTIMATED_HEIGHT = 170;
const LIBRARY_LIST_DRAG_SCROLL_OFFSET = 168;
const LIBRARY_LIST_DRAG_MIN_SCROLL_Y = 340;
const LIBRARY_SCROLL_FORWARD_ANCHOR = 150;
const LIBRARY_SCROLL_BACKWARD_ANCHOR = 58;
const LIBRARY_WINDOW_SIZE = 260;
const LIBRARY_ANIMATED_ITEM_COUNT = interactionMotion.staggeredListLimit;
const quizQuestionCounts = [10, 20, 50] as const;
type InstallGuideStep = {
  icon: 'add' | 'phone' | 'safari' | 'share';
  text: string;
  title: string;
};
const installGuideStepsByMode: Record<StudyMode, readonly InstallGuideStep[]> = {
  english: [
    {
      icon: 'safari',
      title: '先用 Safari 開啟',
      text: '在 iPhone 上用 Safari 打開 Word7000，這樣才能加入主畫面。',
    },
    {
      icon: 'share',
      title: '點下方分享',
      text: '按 Safari 底部工具列中間的分享按鈕。',
    },
    {
      icon: 'add',
      title: '選「加入主畫面」',
      text: '在選單往下找，點一下「加入主畫面」。',
    },
    {
      icon: 'phone',
      title: '完成後像 App 一樣使用',
      text: '之後從手機桌面打開，就會是全螢幕 App 體驗。',
    },
  ],
  chinese: [
    {
      icon: 'safari',
      title: 'Open in Safari',
      text: 'Open Word7000 in Safari on your iPhone before adding it to your Home Screen.',
    },
    {
      icon: 'share',
      title: 'Tap Share',
      text: "Use the Share button in the center of Safari's bottom toolbar.",
    },
    {
      icon: 'add',
      title: 'Choose Add to Home Screen',
      text: 'Scroll through the menu and tap Add to Home Screen.',
    },
    {
      icon: 'phone',
      title: 'Use it like an app',
      text: 'After this, open it from your Home Screen for the full-screen app experience.',
    },
  ],
};
const initialProgress: ProgressState = {
  dailyTarget: 20,
  streak: 1,
  studiedToday: 0,
  dailyProgressDate: today,
  words: {},
};

const filters: Array<{ id: LibraryFilter; label: string }> = [
  { id: 'all', label: '全部' },
  { id: 'favorites', label: '收藏' },
  { id: 'review', label: '複習' },
  { id: 'mastered', label: '已會' },
  { id: 'new', label: '未背' },
];
const librarySortOptions: Array<{ id: LibrarySort }> = [{ id: 'default' }, { id: 'alphabetical' }];

const tabs: Array<{ id: Tab; label: string; icon: typeof Home }> = [
  { id: 'home', label: '首頁', icon: Home },
  { id: 'study', label: '學習', icon: BookOpen },
  { id: 'quiz', label: '測驗', icon: Target },
  { id: 'library', label: '字庫', icon: Library },
  { id: 'profile', label: '我的', icon: User },
];
const modeCopy = {
  english: {
    brand: 'Word7000',
    subtitle: '每日輕學單字',
    toggleTitle: 'Switch to Chinese words',
    toggleText: 'Practice Chinese words with an English interface',
    overlayTitle: '英文單字模式',
    overlayText: '正在回到中文介面的英文單字 App',
    heroEyebrow: 'ENGLISH MODE',
    heroTitle: '今天 20 個\n剛剛好',
    heroText: '保持一小段節奏，把英文單字變成每天都做得到的事。',
    primaryAction: '開始學英文',
    libraryTitle: '完整字庫',
    searchPlaceholder: '搜尋英文、中文、例句或翻譯',
    studyFilterTitle: '學習篩選',
    quizFilterTitle: '測驗篩選',
    libraryFilterTitle: '分級 / 字首',
    initialTitle: '字首',
    questionBankUnit: '個英文單字',
  },
  chinese: {
    brand: 'Chinese7000',
    subtitle: 'Daily Chinese word practice',
    toggleTitle: '切到英文單字',
    toggleText: '回到中文介面的英文單字 App',
    overlayTitle: 'Chinese Word Mode',
    overlayText: 'Read Chinese first, then recall the English word',
    heroEyebrow: 'CHINESE MODE',
    heroTitle: '20 Chinese words for today',
    heroText: 'Start from the Chinese meaning and example, then recall the matching English word.',
    primaryAction: 'Start Chinese practice',
    libraryTitle: 'Chinese Word Library',
    searchPlaceholder: 'Search Chinese, English words, examples, or translations',
    studyFilterTitle: 'Study Filters',
    quizFilterTitle: 'Quiz Filters',
    libraryFilterTitle: 'Level / First Letter',
    initialTitle: 'First Letter',
    questionBankUnit: 'Chinese words',
  },
} as const;

const modeInterfaceCopy = {
  english: {
    completed: '完成',
    dailyProgress: '今日進度',
    accountSync: '帳號登入與同步',
    streak: '連續天數',
    mastered: '已掌握',
    reviewDue: '待複習',
    reviewList: '複習清單',
    reviewListEmpty: '目前沒有卡住的單字',
    reviewListCount: (count: number) => `${count} 個單字需要再看一次`,
    noStudyWords: '沒有符合的學習單字',
    noChineseWords: '沒有符合的中文單字',
    noQuizWords: '沒有符合的測驗題目',
    noLibraryWords: '沒有符合的單字',
    relaxFilters: '可以放寬狀態、分級或字首篩選。',
    relaxLibraryFilters: (hasQuery: boolean) => (hasQuery ? '可以清除搜尋，或換一個分級、字首。' : '可以換一個分級、字首。'),
    favoriteWord: '收藏這個單字',
    unfavoriteWord: '取消收藏這個單字',
    englishCounterpart: '英文對照',
    chineseMeaning: '中文意思',
    supplementalMeanings: '補充意思',
    reviewAgain: '再複習',
    known: '已會',
    filterStatus: '狀態',
    filterLevel: '分級',
    filterSort: '排序',
    filterCountUnit: '個',
    filterLabels: {
      all: '全部',
      favorites: '收藏',
      review: '複習',
      mastered: '已會',
      new: '未背',
    },
    sortDefault: '原本順序',
    sortAlphabetical: '英文字首 A-Z',
    allLevels: '全部分級',
    allInitials: '全部',
    levelAccessibility: (label: string) => `分級 ${label}`,
    initialAccessibility: (label: string) => (label === 'all' ? '字首 全部' : `字首 ${label}`),
    sortAccessibility: (label: string) => `排序 ${label}`,
    questionCountTitle: '選擇題數',
    questionBankPrefix: '目前題庫',
    questionUnit: '題',
    cappedQuestionPrefix: '出',
    quizPracticeTitle: '練習方式',
    choiceQuizMode: '選擇題',
    speakingQuizMode: '口說練習',
    startQuiz: '開始測驗',
    startSpeaking: '開始口說練習',
    quizFinished: '測驗完成',
    speakingFinished: '口說練習完成',
    quizScore: (correct: number, total: number) => `答對 ${correct} / ${total} 題`,
    speakingScore: (total: number) => `完成 ${total} 張口說卡`,
    restartQuiz: '重新選題',
    restartSpeaking: '重新練習',
    correctResult: '答對了',
    wrongResult: '先放進複習',
    speakingPromptLabel: '口說題目',
    speakingHintLabel: '回答提示',
    iSpoke: '我說完了',
    showSampleAnswer: '看參考回答',
    sampleAnswer: '參考回答',
    sampleTranslation: '中文翻譯',
    englishExample: '英文例句',
    chineseExample: '中文例句',
    chineseTranslation: '中文翻譯',
    answer: '答案',
    nextQuestion: '下一題',
    returnTop: '回到頂端',
    floatingTop: '回頂端',
    clearSearch: '清除搜尋',
    searchMeta: (query: string, count: number) => `搜尋「${query}」：找到 ${count} 個結果`,
    filteredCount: (count: number) => `目前篩選後 ${count} 個單字`,
    resultCount: (count: number, start: number, end: number) => `共 ${count} 個結果，顯示第 ${count === 0 ? 0 : start + 1}-${end} 個`,
    viewDetails: '完整資訊',
    viewWordDetails: (word: string) => `查看 ${word} 完整資訊`,
    favoriteWordName: (word: string) => `收藏 ${word}`,
    unfavoriteWordName: (word: string) => `取消收藏 ${word}`,
    backLibrary: '返回字庫',
    detailTitle: '完整資訊',
    profileIdle: '穩定累積中',
    profileProgress: (percent: number, mastered: number) => `今天完成 ${percent}%，目前掌握 ${mastered} 個單字。`,
    account: '帳號',
    signedIn: '已登入',
    signedOut: '未登入',
    local: '本機',
    accountUnavailableTitle: '帳號同步暫未開放',
    accountUnavailableText: '目前會先把進度保存在這台裝置。雲端同步開放後，就能登入帳號跨裝置保存。',
    passwordPlaceholder: '密碼',
    googleSignIn: '使用 Google 快速登入',
    googleSignInHint: '同步收藏、複習和連續天數',
    appleSignIn: '使用 Apple 登入',
    appleSignInHint: '適合在 iPhone 上快速同步',
    emailFallback: 'Email 備用登入',
    signIn: '登入',
    signUp: '註冊',
    signOut: '登出',
    learningExperience: '學習體驗',
    todayComplete: (percent: number) => `今天完成 ${percent}%`,
    dailyTarget: '每日目標',
    favoriteWords: '收藏單字',
    remainingSamples: '剩餘樣本',
    tutorial: '教學',
    replayTutorial: '重新查看加入主畫面教學',
    settings: '設定',
    settingsSummary: '深色模式與資料匯入工具',
    openSettings: '開啟設定',
    backProfile: '返回我的',
    appSettings: 'App 設定',
    displayTools: '顯示模式與本機工具',
    legalSupport: '隱私與支援',
    legalSupportSummary: '隱私、支援與帳號資料管理',
    privacyPolicy: '隱私權政策',
    privacyPolicyText: '查看 Word7000 如何保存與同步學習資料',
    supportPage: '支援頁面',
    supportPageText: '登入、同步、更新與帳號資料說明',
    deleteAccountData: '刪除帳號學習資料',
    deleteAccountDataText: '刪除雲端進度、單字集與每日活躍紀錄，並登出目前帳號',
    deleteAccountDataConfirmTitle: '刪除帳號學習資料？',
    deleteAccountDataConfirmText: '這會刪除雲端進度、單字集與每日活躍紀錄，並登出目前帳號。',
    deleteAccountDataConfirmCancel: '取消',
    deleteAccountDataConfirmAction: '確認刪除',
    darkMode: '深色模式',
    darkModeOnText: '已切換成夜間閱讀介面',
    darkModeOffText: '切換成夜間閱讀介面',
    toggleDarkMode: '切換深色模式',
    on: '開啟',
    off: '關閉',
    developerPanel: '開發人員資料窗口',
    developerEnabled: '本機預覽啟用中',
    developerBuiltin: '目前使用內建字庫',
    developerIntro: '匯出目前字庫後，可以在外部修改例句與翻譯；匯入後會先套用在這台裝置，方便檢查正式更新前的效果。',
    currentLibrary: '目前字庫',
    rows: '筆',
    dataStatus: '資料狀態',
    localPreview: '本機預覽',
    builtInVersion: '內建版本',
    exportCsv: '匯出 CSV',
    importData: '匯入資料',
    clearPreview: '清除本機預覽',
    customSets: '我的單字集',
    customSetsSummary: (count: number) => `${count} 個自訂資料夾，可用於學習與測驗`,
    manage: '管理',
    openCustomSets: '管理單字集',
    backCustomSets: '返回我的',
    backToSets: '返回單字集',
    setLibrary: '自訂單字集',
    setLibrarySummary: '把常用、考試或主題單字分開整理',
    editSet: '編輯單字集',
    openSetSettings: '開啟單字集設定',
    setDetailActions: '操作',
    editSetName: '資料夾名稱',
    saveSetName: '儲存名稱',
    deleteSet: '刪除資料夾',
    wordsInSet: '資料夾單字',
    emptySetWords: '這個資料夾還沒有單字。',
    removeFromSet: '移除',
    setRenamed: (name: string) => `已更新「${name}」`,
    setDeleted: (name: string) => `已刪除「${name}」`,
    removedFromSet: (word: string, setName: string) => `已從「${setName}」移除 ${word}`,
    customSetSortRecent: '最近更新',
    customSetSortName: '名稱 A-Z',
    customSetSortManual: '建立順序',
    createSet: '新增資料夾',
    newSetPlaceholder: '例如：旅行英文、托福片語',
    addToSet: '加入單字集',
    addToSetName: (word: string) => `把 ${word} 加入單字集`,
    setPickerTitle: (word: string) => `加入「${word}」`,
    setPickerEmpty: '還沒有單字集，先新增一個資料夾。',
    createAndAdd: '新增並加入',
    addExistingWord: '加入',
    addedToSet: (word: string, setName: string) => `已把 ${word} 加入「${setName}」`,
    noCustomSets: '尚未建立單字集',
    customSetCount: (count: number) => `${count} 個單字`,
    chooseCustomSet: '選擇要加入的單字集',
    manualWordTitle: '手動新增單字',
    manualWordIntro: '可以加入字庫沒有的單字，也可以用 CSV 一次匯入。',
    customWordWordPlaceholder: '英文單字',
    customWordMeaningPlaceholder: '中文意思',
    customWordPronunciationPlaceholder: '音標，可空白',
    customWordPartPlaceholder: '詞性，可空白',
    customWordExamplePlaceholder: '英文例句，可空白',
    customWordExampleZhPlaceholder: '中文例句，可空白',
    addManualWord: '新增到單字集',
    importCustomCsv: '匯入自訂 CSV',
    customSetMessageDefault: '單字集會依照目前登入帳號分開記憶在這台裝置。',
    customSetSelectPlaceholder: '先選一個單字集',
    startSetStudy: '用這組學習',
    startSetQuiz: '用這組測驗',
    activeSet: (name: string) => `目前使用「${name}」`,
    clearActiveSet: '清除',
    activeSetCount: (count: number) => `${count} 個單字`,
    setCreated: (name: string) => `已建立「${name}」`,
    customWordAdded: (word: string, setName: string) => `已新增 ${word} 到「${setName}」`,
    customImportApplied: (added: number, skipped: number) => `已匯入 ${added} 個新單字，略過 ${skipped} 筆。`,
  },
  chinese: {
    completed: 'Complete',
    dailyProgress: 'Today',
    accountSync: 'Account and sync',
    streak: 'Streak',
    mastered: 'Mastered',
    reviewDue: 'Review',
    reviewList: 'Review List',
    reviewListEmpty: 'No words need review right now',
    reviewListCount: (count: number) => `${count} words need another look`,
    noStudyWords: 'No matching study words',
    noChineseWords: 'No matching Chinese words',
    noQuizWords: 'No matching quiz questions',
    noLibraryWords: 'No matching words',
    relaxFilters: 'Try loosening the status, level, or first-letter filters.',
    relaxLibraryFilters: (hasQuery: boolean) => (hasQuery ? 'Clear search or try another level or first letter.' : 'Try another level or first letter.'),
    favoriteWord: 'Save this word',
    unfavoriteWord: 'Remove this word from saved',
    englishCounterpart: 'English Match',
    chineseMeaning: 'Chinese Meaning',
    supplementalMeanings: 'Extra Meanings',
    reviewAgain: 'Review Again',
    known: 'I Know It',
    filterStatus: 'Status',
    filterLevel: 'Level',
    filterSort: 'Sort',
    filterCountUnit: 'items',
    filterLabels: {
      all: 'All',
      favorites: 'Saved',
      review: 'Review',
      mastered: 'Known',
      new: 'New',
    },
    sortDefault: 'Original Order',
    sortAlphabetical: 'English A-Z',
    allLevels: 'All Levels',
    allInitials: 'All',
    levelAccessibility: (label: string) => `Level ${label}`,
    initialAccessibility: (label: string) => (label === 'all' ? 'First letter All' : `First letter ${label}`),
    sortAccessibility: (label: string) => `Sort ${label}`,
    questionCountTitle: 'Choose Question Count',
    questionBankPrefix: 'Question bank',
    questionUnit: 'questions',
    cappedQuestionPrefix: 'Uses',
    quizPracticeTitle: 'Practice Type',
    choiceQuizMode: 'Multiple Choice',
    speakingQuizMode: 'Speaking Cards',
    startQuiz: 'Start Quiz',
    startSpeaking: 'Start Speaking',
    quizFinished: 'Quiz Complete',
    speakingFinished: 'Speaking Complete',
    quizScore: (correct: number, total: number) => `${correct} / ${total} correct`,
    speakingScore: (total: number) => `${total} speaking cards completed`,
    restartQuiz: 'Choose Again',
    restartSpeaking: 'Practice Again',
    correctResult: 'Correct',
    wrongResult: 'Added to Review',
    speakingPromptLabel: 'Speaking Prompt',
    speakingHintLabel: 'Answer Hint',
    iSpoke: 'I Finished Speaking',
    showSampleAnswer: 'Show Sample Answer',
    sampleAnswer: 'Sample Answer',
    sampleTranslation: 'English Translation',
    englishExample: 'English Example',
    chineseExample: 'Chinese Example',
    chineseTranslation: 'Chinese Translation',
    answer: 'Answer',
    nextQuestion: 'Next',
    returnTop: 'Back to Top',
    floatingTop: 'Top',
    clearSearch: 'Clear search',
    searchMeta: (query: string, count: number) => `Search "${query}": ${count} results`,
    filteredCount: (count: number) => `${count} ${modeCopy.chinese.questionBankUnit} after filters`,
    resultCount: (count: number, start: number, end: number) => `${count} results, showing ${count === 0 ? 0 : start + 1}-${end}`,
    viewDetails: 'Details',
    viewWordDetails: (word: string) => `View details for ${word}`,
    favoriteWordName: (word: string) => `Save ${word}`,
    unfavoriteWordName: (word: string) => `Remove ${word} from saved`,
    backLibrary: 'Back to Library',
    detailTitle: 'Details',
    profileIdle: 'Building momentum',
    profileProgress: (percent: number, mastered: number) => `${percent}% complete today, ${mastered} words mastered.`,
    account: 'Account',
    signedIn: 'Signed in',
    signedOut: 'Signed out',
    local: 'Local',
    accountUnavailableTitle: 'Account sync is not available yet',
    accountUnavailableText: 'Progress is saved on this device for now. When cloud sync is available, you can sign in to keep it across devices.',
    passwordPlaceholder: 'Password',
    googleSignIn: 'Continue with Google',
    googleSignInHint: 'Sync saved words, review, and streaks',
    appleSignIn: 'Continue with Apple',
    appleSignInHint: 'Fast sign-in on iPhone',
    emailFallback: 'Email fallback',
    signIn: 'Sign In',
    signUp: 'Sign Up',
    signOut: 'Sign Out',
    learningExperience: 'Learning Experience',
    todayComplete: (percent: number) => `${percent}% complete today`,
    dailyTarget: 'Daily Target',
    favoriteWords: 'Saved Words',
    remainingSamples: 'Remaining',
    tutorial: 'Tutorial',
    replayTutorial: 'Review home-screen tutorial',
    settings: 'Settings',
    settingsSummary: 'Dark mode and import tools',
    openSettings: 'Open settings',
    backProfile: 'Back to Me',
    appSettings: 'App Settings',
    displayTools: 'Display mode and local tools',
    legalSupport: 'Privacy and Support',
    legalSupportSummary: 'Privacy, support, and account data controls',
    privacyPolicy: 'Privacy Policy',
    privacyPolicyText: 'See how Word7000 stores and syncs learning data',
    supportPage: 'Support Page',
    supportPageText: 'Help with sign-in, sync, updates, and account data',
    deleteAccountData: 'Delete Account Learning Data',
    deleteAccountDataText: 'Delete cloud progress, custom sets, and daily activity, then sign out',
    deleteAccountDataConfirmTitle: 'Delete account learning data?',
    deleteAccountDataConfirmText: 'This deletes cloud progress, custom sets, and daily activity, then signs out of the current account.',
    deleteAccountDataConfirmCancel: 'Cancel',
    deleteAccountDataConfirmAction: 'Delete Data',
    darkMode: 'Dark Mode',
    darkModeOnText: 'Night reading interface is on',
    darkModeOffText: 'Switch to the night reading interface',
    toggleDarkMode: 'Toggle dark mode',
    on: 'On',
    off: 'Off',
    developerPanel: 'Developer Data Window',
    developerEnabled: 'Local preview enabled',
    developerBuiltin: 'Using built-in library',
    developerIntro: 'Export the current library, edit examples and translations externally, then import it for a local preview before a formal update.',
    currentLibrary: 'Current Library',
    rows: 'rows',
    dataStatus: 'Data Status',
    localPreview: 'Local Preview',
    builtInVersion: 'Built-in',
    exportCsv: 'Export CSV',
    importData: 'Import Data',
    clearPreview: 'Clear Local Preview',
    customSets: 'My Sets',
    customSetsSummary: (count: number) => `${count} custom folders for study and quiz`,
    manage: 'Manage',
    openCustomSets: 'Manage sets',
    backCustomSets: 'Back to Me',
    backToSets: 'Back to Sets',
    setLibrary: 'Custom Sets',
    setLibrarySummary: 'Group words by topic, exam, or personal lists',
    editSet: 'Edit Set',
    openSetSettings: 'Open set settings',
    setDetailActions: 'Actions',
    editSetName: 'Folder name',
    saveSetName: 'Save Name',
    deleteSet: 'Delete Folder',
    wordsInSet: 'Words in Set',
    emptySetWords: 'This folder has no words yet.',
    removeFromSet: 'Remove',
    setRenamed: (name: string) => `Updated "${name}"`,
    setDeleted: (name: string) => `Deleted "${name}"`,
    removedFromSet: (word: string, setName: string) => `Removed ${word} from "${setName}"`,
    customSetSortRecent: 'Recently Updated',
    customSetSortName: 'Name A-Z',
    customSetSortManual: 'Created Order',
    createSet: 'New Folder',
    newSetPlaceholder: 'Travel Chinese, HSK verbs...',
    addToSet: 'Add to set',
    addToSetName: (word: string) => `Add ${word} to a set`,
    setPickerTitle: (word: string) => `Add "${word}"`,
    setPickerEmpty: 'No sets yet. Create a folder first.',
    createAndAdd: 'Create and Add',
    addExistingWord: 'Add',
    addedToSet: (word: string, setName: string) => `Added ${word} to "${setName}"`,
    noCustomSets: 'No custom sets yet',
    customSetCount: (count: number) => `${count} words`,
    chooseCustomSet: 'Choose a set',
    manualWordTitle: 'Add a Word',
    manualWordIntro: 'Add words missing from the library, or import a CSV file.',
    customWordWordPlaceholder: 'Word',
    customWordMeaningPlaceholder: 'Main meaning',
    customWordPronunciationPlaceholder: 'Pronunciation, optional',
    customWordPartPlaceholder: 'Part of speech, optional',
    customWordExamplePlaceholder: 'Example, optional',
    customWordExampleZhPlaceholder: 'Translation, optional',
    addManualWord: 'Add to Set',
    importCustomCsv: 'Import Custom CSV',
    customSetMessageDefault: 'Sets are remembered separately for the current signed-in account on this device.',
    customSetSelectPlaceholder: 'Choose a set first',
    startSetStudy: 'Study This Set',
    startSetQuiz: 'Quiz This Set',
    activeSet: (name: string) => `Using "${name}"`,
    clearActiveSet: 'Clear',
    activeSetCount: (count: number) => `${count} words`,
    setCreated: (name: string) => `Created "${name}"`,
    customWordAdded: (word: string, setName: string) => `Added ${word} to "${setName}"`,
    customImportApplied: (added: number, skipped: number) => `Imported ${added} new words, skipped ${skipped}.`,
  },
} as const;

const systemCopy = {
  english: {
    developerInitial: '可匯出 CSV 修改例句，再匯入成這台裝置的預覽字庫。',
    exportCsvSuccess: (count: number) => `已匯出 ${count} 筆字庫 CSV。`,
    exportCsvUnavailable: '目前這個裝置不支援直接下載 CSV。',
    importReading: '正在讀取匯入檔案...',
    importUnsupported: '目前只有網頁版支援從檔案匯入字庫。',
    importNoFile: '沒有選擇檔案。',
    importReadFailed: '讀取檔案失敗，請確認檔案可以正常開啟。',
    importApplied: (updated: number, added: number, total: number) => `已套用本機預覽：更新 ${updated} 筆，新增 ${added} 筆，目前共 ${total} 筆。`,
    importAppliedWithErrors: (summary: string, count: number) => `${summary} 另有 ${count} 筆未套用。`,
    clearPreview: '已清除本機預覽，現在使用內建 7000 字庫。',
    updateTitle: '需要更新才能繼續使用',
    updateDetail: '為了避免字庫、帳號同步或介面版本不同步，系統會自動更新到最新版。',
    updateCountdown: (seconds: number) => `${seconds} 秒後自動更新`,
    updateNow: '立即更新',
    installGuide: {
      closeAccessibility: '關閉加入主畫面教學',
      dismiss: '我先自己操作',
      done: '完成',
      next: '下一步',
    },
  },
  chinese: {
    developerInitial: 'Export the CSV, edit examples externally, then import it as a local preview on this device.',
    exportCsvSuccess: (count: number) => `Exported ${count} vocabulary rows as CSV.`,
    exportCsvUnavailable: 'This device does not support direct CSV downloads yet.',
    importReading: 'Reading the import file...',
    importUnsupported: 'File import is currently supported only on the web version.',
    importNoFile: 'No file was selected.',
    importReadFailed: 'Could not read the file. Please make sure it opens correctly.',
    importApplied: (updated: number, added: number, total: number) => `Local preview applied: ${updated} updated, ${added} added, ${total} rows total.`,
    importAppliedWithErrors: (summary: string, count: number) => `${summary} ${count} rows were not applied.`,
    clearPreview: 'Local preview cleared. The built-in 7000-word library is active again.',
    updateTitle: 'Update required',
    updateDetail: 'To keep the word library, account sync, and interface version aligned, the app will update automatically.',
    updateCountdown: (seconds: number) => `Auto-updating in ${seconds}s`,
    updateNow: 'Update now',
    installGuide: {
      closeAccessibility: 'Close home-screen tutorial',
      dismiss: "I'll do this myself",
      done: 'Done',
      next: 'Next',
    },
  },
} as const;
type SystemCopy = (typeof systemCopy)[StudyMode];

const levelFilters = buildLevelFilters(sampleWords);
const alphabetFilters: FilterOption[] = [
  { id: 'all', label: '全部' },
  ...'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.split('').map((letter) => ({
    id: letter,
    label: letter,
  })),
];
const emptyManualCustomWord: ManualCustomWordState = {
  example: '',
  exampleZh: '',
  meaningZh: '',
  partOfSpeech: '',
  pronunciation: '',
  word: '',
};
const ThemeContext = createContext<ThemeMode>('light');
const MotionPressable = Animated.createAnimatedComponent(Pressable);

export default function App() {
  const [storageReady, setStorageReady] = useState(() => isAppStorageHydrated());

  useEffect(() => {
    if (storageReady) {
      return;
    }

    let mounted = true;
    hydrateAppStorage()
      .catch(() => undefined)
      .then(() => {
        if (mounted) {
          setStorageReady(true);
        }
      });

    return () => {
      mounted = false;
    };
  }, [storageReady]);

  if (!storageReady) {
    return <AppStorageBootScreen />;
  }

  return <Word7000App />;
}

function Word7000App() {
  const appScrollRef = useRef<ScrollView | null>(null);
  const scrollYRef = useRef(0);
  const libraryListTopYRef = useRef(0);
  const libraryItemExtentRef = useRef(LIBRARY_ITEM_ESTIMATED_HEIGHT);
  const libraryWindowStartRef = useRef(0);
  const libraryScrollSyncLockedRef = useRef(false);
  const librarySliderDraggingRef = useRef(false);
  const launchAnim = useRef(new Animated.Value(0)).current;
  const installGuideAnim = useRef(new Animated.Value(0)).current;
  const screenAnim = useRef(new Animated.Value(1)).current;
  const cardAnim = useRef(new Animated.Value(1)).current;
  const libraryPanelAnim = useRef(new Animated.Value(1)).current;
  const modeTransitionAnim = useRef(new Animated.Value(0)).current;
  const themeTransitionAnim = useRef(new Animated.Value(0)).current;
  const [supabaseClient] = useState<AppSupabaseClient | null>(() => createAppSupabaseClient());
  const [initialFilterPreferences] = useState(() => loadFilterPreferences(getAppStorage()));
  const [activeTab, setActiveTab] = useState<Tab>('home');
  const [progress, setProgress] = useState<ProgressState>(initialProgress);
  const [progressReady, setProgressReady] = useState(false);
  const [wordIndex, setWordIndex] = useState(0);
  const [studyFilter, setStudyFilter] = useState<LibraryFilter>(initialFilterPreferences.study.filter);
  const [studyLevel, setStudyLevel] = useState(initialFilterPreferences.study.level);
  const [studyInitial, setStudyInitial] = useState(initialFilterPreferences.study.initial);
  const [studyFiltersOpen, setStudyFiltersOpen] = useState(false);
  const [quizIndex, setQuizIndex] = useState(0);
  const [quizPracticeMode, setQuizPracticeMode] = useState<QuizPracticeMode>('choice');
  const [quizResult, setQuizResult] = useState<'correct' | 'wrong' | null>(null);
  const [speakingAnswerVisible, setSpeakingAnswerVisible] = useState(false);
  const [answeredQuizWord, setAnsweredQuizWord] = useState<WordEntry | null>(null);
  const [lockedQuizOptions, setLockedQuizOptions] = useState<QuizOption[] | null>(null);
  const [quizQuestionCount, setQuizQuestionCount] = useState<(typeof quizQuestionCounts)[number]>(initialFilterPreferences.quiz.questionCount);
  const [quizSession, setQuizSession] = useState<WordEntry[]>([]);
  const [quizStarted, setQuizStarted] = useState(false);
  const [quizFinished, setQuizFinished] = useState(false);
  const [quizCorrectCount, setQuizCorrectCount] = useState(0);
  const [quizSeed, setQuizSeed] = useState('');
  const [searchQuery, setSearchQuery] = useState('');
  const [searchFocused, setSearchFocused] = useState(false);
  const [activeFilter, setActiveFilter] = useState<LibraryFilter>(initialFilterPreferences.library.filter);
  const [activeLevel, setActiveLevel] = useState(initialFilterPreferences.library.level);
  const [activeInitial, setActiveInitial] = useState(initialFilterPreferences.library.initial);
  const [activeSort, setActiveSort] = useState<LibrarySort>(initialFilterPreferences.library.sort);
  const [libraryFiltersOpen, setLibraryFiltersOpen] = useState(false);
  const [quizFilter, setQuizFilter] = useState<LibraryFilter>(initialFilterPreferences.quiz.filter);
  const [quizLevel, setQuizLevel] = useState(initialFilterPreferences.quiz.level);
  const [quizInitial, setQuizInitial] = useState(initialFilterPreferences.quiz.initial);
  const [quizFiltersOpen, setQuizFiltersOpen] = useState(false);
  const [showLaunch, setShowLaunch] = useState(true);
  const [installGuideChecked, setInstallGuideChecked] = useState(false);
  const [showInstallGuide, setShowInstallGuide] = useState(false);
  const [installGuideStep, setInstallGuideStep] = useState(0);
  const [account, setAccount] = useState<AccountState>(() => createInitialAccountState(Boolean(supabaseClient)));
  const [profilePanel, setProfilePanel] = useState<ProfilePanel>('overview');
  const [libraryPanel, setLibraryPanel] = useState<LibraryPanel>('list');
  const [renderedLibraryPanel, setRenderedLibraryPanel] = useState<LibraryPanel>('list');
  const [themeMode, setThemeMode] = useState<ThemeMode>(() => loadThemeMode(getAppStorage()));
  const [studyMode, setStudyMode] = useState<StudyMode>(() => loadStudyMode(getAppStorage()));
  const [modeSwitchTarget, setModeSwitchTarget] = useState<StudyMode>(() =>
    loadStudyMode(getAppStorage()) === 'english' ? 'chinese' : 'english',
  );
  const [showModeSwitch, setShowModeSwitch] = useState(false);
  const [showThemeTransition, setShowThemeTransition] = useState(false);
  const [themeTransitionTarget, setThemeTransitionTarget] = useState<ThemeMode>(() => loadThemeMode(getAppStorage()));
  const [scrollY, setScrollY] = useState(0);
  const [headerHeight, setHeaderHeight] = useState(88);
  const [sliderTrackHeight, setSliderTrackHeight] = useState(1);
  const [libraryListTopY, setLibraryListTopY] = useState(0);
  const [libraryItemExtent, setLibraryItemExtent] = useState(LIBRARY_ITEM_ESTIMATED_HEIGHT);
  const [librarySliderDragging, setLibrarySliderDragging] = useState(false);
  const [libraryWindowStart, setLibraryWindowStart] = useState(0);
  const [selectedLibraryWord, setSelectedLibraryWord] = useState<WordEntry | null>(null);
  const [customSetState, setCustomSetState] = useState<CustomSetState>(() => loadCustomSetState(getAppStorage()));
  const [customSetSort, setCustomSetSort] = useState<CustomSetSort>(() => loadCustomSetSort(getAppStorage()));
  const [selectedCustomSetId, setSelectedCustomSetId] = useState<string | null>(null);
  const [studySetId, setStudySetId] = useState<string | null>(null);
  const [quizSetId, setQuizSetId] = useState<string | null>(null);
  const [setPickerWord, setSetPickerWord] = useState<WordEntry | null>(null);
  const [newSetName, setNewSetName] = useState('');
  const [manualCustomWord, setManualCustomWord] = useState<ManualCustomWordState>(emptyManualCustomWord);
  const [customSetMessage, setCustomSetMessage] = useState<string>(() => modeInterfaceCopy[studyMode].customSetMessageDefault);
  const [developerVocabulary, setDeveloperVocabulary] = useState<DeveloperVocabularySnapshot | null>(() =>
    loadDeveloperVocabulary(getAppStorage()),
  );
  const [developerVocabularyMessage, setDeveloperVocabularyMessage] = useState<string>(
    () => systemCopy[studyMode].developerInitial,
  );

  const baseVocabularyWords = developerVocabulary?.words ?? sampleWords;
  const vocabularyWords = useMemo(
    () => mergeCustomWords(baseVocabularyWords, customSetState.customWords),
    [baseVocabularyWords, customSetState.customWords],
  );
  const sortedCustomSets = useMemo(() => sortCustomSets(customSetState.sets, customSetSort), [customSetSort, customSetState.sets]);
  const activeStudySet = useMemo(
    () => customSetState.sets.find((set) => set.id === studySetId) ?? null,
    [customSetState.sets, studySetId],
  );
  const activeQuizSet = useMemo(
    () => customSetState.sets.find((set) => set.id === quizSetId) ?? null,
    [customSetState.sets, quizSetId],
  );
  const studySourceWords = useMemo(
    () => (activeStudySet ? wordsForCustomSet(vocabularyWords, activeStudySet) : vocabularyWords),
    [activeStudySet, vocabularyWords],
  );
  const quizSourceWords = useMemo(
    () => (activeQuizSet ? wordsForCustomSet(vocabularyWords, activeQuizSet) : vocabularyWords),
    [activeQuizSet, vocabularyWords],
  );
  const levelFilterOptions = useMemo(() => buildLevelFilters(vocabularyWords), [vocabularyWords]);
  const stats = useMemo(() => computeStats(vocabularyWords, progress), [progress, vocabularyWords]);
  const studyWords = useMemo(
    () =>
      selectStudyWords(studySourceWords, progress, studyFilter, {
        initial: studyInitial,
        level: studyLevel,
      }),
    [progress, studyFilter, studyInitial, studyLevel, studySourceWords],
  );
  const studyWord = studyWords.length > 0 ? studyWords[wordIndex % studyWords.length] : null;
  const quizWords = useMemo(
    () =>
      selectQuizWords(quizSourceWords, progress, quizFilter, {
        initial: quizInitial,
        level: quizLevel,
      }),
    [progress, quizFilter, quizInitial, quizLevel, quizSourceWords],
  );
  const quizWord = quizStarted && quizSession.length > 0 ? quizSession[quizIndex] ?? null : null;
  const quizOptionSource = quizWords.length >= 3 ? quizWords : quizSourceWords.length >= 3 ? quizSourceWords : vocabularyWords;
  const quizOptions = useMemo(
    () => (quizWord ? buildQuizOptions(quizOptionSource, quizWord.id, `${quizSeed}:${quizIndex}`, studyMode === 'chinese' ? 'word' : 'meaning') : []),
    [quizIndex, quizOptionSource, quizSeed, quizWord, studyMode],
  );
  const visibleQuizWord = answeredQuizWord ?? quizWord;
  const visibleQuizOptions = lockedQuizOptions ?? quizOptions;
  const conversationPrompt = useMemo(
    () => (visibleQuizWord ? buildConversationPrompt(visibleQuizWord, studyMode) : null),
    [studyMode, visibleQuizWord],
  );
  const quizSessionTotal = quizStarted || quizFinished ? quizSession.length : Math.min(quizQuestionCount, quizWords.length);
  const libraryWords = useMemo(
    () =>
      filterWords(vocabularyWords, progress, searchQuery, activeFilter, {
        initial: activeInitial,
        level: activeLevel,
        sort: activeSort,
      }),
    [activeFilter, activeInitial, activeLevel, activeSort, progress, searchQuery, vocabularyWords],
  );
  const dailyPercent = Math.min(100, Math.round((stats.studiedToday / progress.dailyTarget) * 100));
  const themeStyles = themeMode === 'dark' ? darkStyles : undefined;
  const darkMode = themeMode === 'dark';
  const libraryDragIconColor = darkMode ? '#bfdbfe' : '#172033';
  const activeModeCopy = modeCopy[studyMode];
  const activeSystemCopy = systemCopy[studyMode];
  const activeInstallGuideSteps = installGuideStepsByMode[studyMode];
  const previewModeLabel = IS_WEB_IOS_PREVIEW ? 'iOS Preview' : null;
  const updateState = useAppUpdateCheck(studyMode);
  const screenMotionStyle = {
    opacity: screenAnim,
    transform: [
      {
        translateY: screenAnim.interpolate({
          inputRange: [0, 1],
          outputRange: [8, 0],
        }),
      },
    ],
  };
  const screenMotionWebTransition: WebTransitionStyle | undefined =
    Platform.OS === 'web'
      ? {
          transformOrigin: 'top center',
          willChange: 'opacity, transform',
        }
      : undefined;
  const cardMotionStyle = {
    opacity: cardAnim,
    transform: [
      {
        translateY: cardAnim.interpolate({
          inputRange: [0, 1],
          outputRange: [12, 0],
        }),
      },
      {
        scale: cardAnim.interpolate({
          inputRange: [0, 1],
          outputRange: [0.985, 1],
        }),
      },
    ],
  };
  const listMotionStyle = useCallback((index: number) => {
    if (activeTab === 'library' && index >= LIBRARY_ANIMATED_ITEM_COUNT) {
      return undefined;
    }

    return {
      opacity: cardAnim,
      transform: [
        {
          translateY: cardAnim.interpolate({
            inputRange: [0, 1],
            outputRange: [listEnterOffset(index), 0],
          }),
        },
        {
          scale: cardAnim.interpolate({
            inputRange: [0, 1],
            outputRange: [0.992, 1],
          }),
        },
      ],
    };
  }, [activeTab, cardAnim]);
  const libraryPanelMotionStyle = {
    opacity: libraryPanelAnim,
    transform: [
      {
        translateX: libraryPanelAnim.interpolate({
          inputRange: [0, 1],
          outputRange: [renderedLibraryPanel === 'detail' ? 18 : -12, 0],
        }),
      },
      {
        scale: libraryPanelAnim.interpolate({
          inputRange: [0, 1],
          outputRange: [0.985, 1],
        }),
      },
    ],
  };
  const libraryListPanelHorizontalMotionStyle = {
    opacity: libraryPanelAnim,
    transform: [
      {
        translateX: libraryPanelAnim.interpolate({
          inputRange: [0, 1],
          outputRange: [-12, 0],
        }),
      },
    ],
  };
  const libraryTransitionPerformanceStyle: WebTransitionStyle | undefined =
    Platform.OS === 'web'
      ? {
          transformOrigin: 'top center',
          willChange: 'opacity, transform',
        }
      : undefined;
  const libraryListPanelMotionStyle = [
    renderedLibraryPanel === 'list' ? libraryListPanelHorizontalMotionStyle : styles.libraryPanelHidden,
    libraryTransitionPerformanceStyle,
  ];
  const libraryDetailStageMotionStyle = [
    renderedLibraryPanel === 'detail' ? libraryPanelMotionStyle : styles.libraryPanelHidden,
    libraryTransitionPerformanceStyle,
  ];
  const librarySetsStageMotionStyle = [
    renderedLibraryPanel === 'sets' ? libraryPanelMotionStyle : styles.libraryPanelHidden,
    libraryTransitionPerformanceStyle,
  ];
  const modeOverlayScale = modeTransitionAnim.interpolate({
    inputRange: [0, 1],
    outputRange: [0.94, 1],
  });
  const modeOverlayTranslateY = modeTransitionAnim.interpolate({
    inputRange: [0, 1],
    outputRange: [18, 0],
  });
  const themeTransitionMotionStyle = {
    backgroundColor: themeTransitionTarget === 'dark' ? '#020617' : '#f8fafc',
    opacity: themeTransitionAnim,
  };
  const launchOpacity = launchAnim.interpolate({
    inputRange: [0, 0.22, 1.62, 2],
    outputRange: [0, 1, 1, 0],
  });
  const launchScale = launchAnim.interpolate({
    inputRange: [0, 1, 2],
    outputRange: [0.94, 1, 1.04],
  });
  const launchProgressWidth = launchAnim.interpolate({
    inputRange: [0, 1, 2],
    outputRange: ['10%', '76%', '100%'],
  });
  const installGuideOpacity = installGuideAnim;
  const installGuideTranslateY = installGuideAnim.interpolate({
    inputRange: [0, 1],
    outputRange: [24, 0],
  });
  const librarySliderVisible = activeTab === 'library' && !selectedLibraryWord && libraryWords.length > LIBRARY_WINDOW_SIZE;
  const librarySliderActive = librarySliderDragging;
  const librarySliderWordIndex = wordWindowStartFromFullLibraryScroll(
    scrollY,
    libraryListTopY,
    libraryItemExtent,
    libraryWords.length,
    LIBRARY_WINDOW_SIZE,
  );
  const libraryThumbOffset = scrollThumbOffset(
    librarySliderWordIndex,
    Math.max(libraryWords.length, LIBRARY_WINDOW_SIZE + 1),
    LIBRARY_WINDOW_SIZE,
    sliderTrackHeight,
    LIBRARY_SLIDER_THUMB_HEIGHT,
  );
  const libraryDragSliderMotionStyle: WebTransitionStyle | undefined =
    Platform.OS === 'web'
      ? {
          transitionDuration: `${librarySliderActive ? 150 : 210}ms`,
          transitionProperty: 'width, right, opacity, background-color, border-color, box-shadow',
          transitionTimingFunction: 'cubic-bezier(0.22, 1, 0.36, 1)',
          willChange: 'width, right, opacity',
        }
      : undefined;
  const libraryDragTrackMotionStyle: WebTransitionStyle | undefined =
    Platform.OS === 'web'
      ? {
          transitionDuration: `${librarySliderActive ? 120 : 190}ms`,
          transitionProperty: 'width, opacity, background-color',
          transitionTimingFunction: 'cubic-bezier(0.22, 1, 0.36, 1)',
          willChange: 'width, opacity',
        }
      : undefined;
  const libraryDragThumbMotionStyle: WebTransitionStyle | undefined =
    Platform.OS === 'web'
      ? {
          transitionDuration: `${librarySliderActive ? 70 : 180}ms`,
          transitionProperty: 'transform, width, opacity, background-color, border-color',
          transitionTimingFunction: 'cubic-bezier(0.22, 1, 0.36, 1)',
          willChange: 'transform, width, opacity',
        }
      : undefined;
  const librarySliderResponder = useMemo(
    () =>
      PanResponder.create({
        onMoveShouldSetPanResponder: () => activeTab === 'library' && libraryPanel === 'list',
        onStartShouldSetPanResponder: () => activeTab === 'library' && libraryPanel === 'list',
        onPanResponderGrant: (event) => {
          librarySliderDraggingRef.current = true;
          setLibrarySliderDragging(true);
          handleLibrarySliderDrag(event.nativeEvent.locationY);
        },
        onPanResponderMove: (event) => handleLibrarySliderDrag(event.nativeEvent.locationY),
        onPanResponderRelease: finishLibrarySliderDrag,
        onPanResponderTerminate: finishLibrarySliderDrag,
      }),
    [activeTab, libraryPanel, libraryWords.length, sliderTrackHeight],
  );

  const onLibraryPanelSwap = useCallback(
    (nextPanel: LibraryPanel) => {
      if (nextPanel === 'list') {
        setSelectedLibraryWord(null);
      }
    },
    [],
  );

  useWebServiceWorker();

  useEffect(() => {
    Animated.sequence([
      Animated.timing(launchAnim, {
        duration: 280,
        easing: Easing.out(Easing.cubic),
        toValue: 1,
        useNativeDriver: false,
      }),
      Animated.delay(520),
      Animated.timing(launchAnim, {
        duration: 300,
        easing: Easing.inOut(Easing.cubic),
        toValue: 2,
        useNativeDriver: false,
      }),
    ]).start(() => setShowLaunch(false));
  }, [launchAnim]);

  useEffect(() => {
    saveThemeMode(getAppStorage(), themeMode);
  }, [themeMode]);

  useEffect(() => {
    saveStudyMode(getAppStorage(), studyMode);
  }, [studyMode]);

  useEffect(() => {
    saveCustomSetState(getAppStorage(), customSetState, account.userId);
  }, [account.userId, customSetState]);

  useEffect(() => {
    saveCustomSetSort(getAppStorage(), customSetSort);
  }, [customSetSort]);

  useEffect(() => {
    setDeveloperVocabularyMessage((current) =>
      current === systemCopy.english.developerInitial || current === systemCopy.chinese.developerInitial
        ? activeSystemCopy.developerInitial
        : current,
    );
  }, [activeSystemCopy.developerInitial]);

  useEffect(() => {
    setCustomSetMessage((current) =>
      current === modeInterfaceCopy.english.customSetMessageDefault || current === modeInterfaceCopy.chinese.customSetMessageDefault
        ? modeInterfaceCopy[studyMode].customSetMessageDefault
        : current,
    );
  }, [studyMode]);

  useEffect(() => {
    saveFilterPreferences(getAppStorage(), {
      library: {
        filter: activeFilter,
        initial: activeInitial,
        level: activeLevel,
        sort: activeSort,
      },
      quiz: {
        filter: quizFilter,
        initial: quizInitial,
        level: quizLevel,
        questionCount: quizQuestionCount,
      },
      study: {
        filter: studyFilter,
        initial: studyInitial,
        level: studyLevel,
      },
    });
  }, [
    activeFilter,
    activeInitial,
    activeLevel,
    activeSort,
    quizFilter,
    quizInitial,
    quizLevel,
    quizQuestionCount,
    studyFilter,
    studyInitial,
    studyLevel,
  ]);

  useEffect(() => {
    if (showLaunch || installGuideChecked) {
      return;
    }

    setInstallGuideChecked(true);
    const shouldAutoShowInstallGuide =
      Platform.OS === 'web' && !IS_WEB_IOS_PREVIEW && shouldShowInstallGuide(getAppStorage(), isInstalledWebApp());
    if (shouldAutoShowInstallGuide) {
      openInstallGuide();
    }
  }, [installGuideChecked, showLaunch]);

  useEffect(() => {
    screenAnim.setValue(0);
    Animated.timing(screenAnim, {
      duration: interactionMotion.screenMs,
      easing: Easing.out(Easing.cubic),
      toValue: 1,
      useNativeDriver: Platform.OS !== 'web',
    }).start();
  }, [activeTab, screenAnim]);

  useEffect(() => {
    cardAnim.setValue(0);
    Animated.timing(cardAnim, {
      duration: interactionMotion.cardMs,
      easing: Easing.out(Easing.cubic),
      toValue: 1,
      useNativeDriver: Platform.OS !== 'web',
    }).start();
  }, [
    activeFilter,
    activeInitial,
    activeLevel,
    activeSort,
    activeTab,
    cardAnim,
    developerVocabulary?.importedAt,
    profilePanel,
    quizFilter,
    quizIndex,
    quizInitial,
    quizLevel,
    quizQuestionCount,
    quizStarted,
    quizFinished,
    studyMode,
    studyFilter,
    studyInitial,
    studyLevel,
    wordIndex,
  ]);

  useEffect(() => {
    let cancelled = false;
    const useNativeDriver = Platform.OS !== 'web';

    if (libraryPanel === renderedLibraryPanel) {
      Animated.timing(libraryPanelAnim, {
        duration: interactionMotion.settingsPanelMs,
        easing: Easing.out(Easing.cubic),
        toValue: 1,
        useNativeDriver,
      }).start();
      return () => {
        cancelled = true;
      };
    }

    Animated.timing(libraryPanelAnim, {
      duration: interactionMotion.settingsPanelExitMs,
      easing: Easing.in(Easing.cubic),
      toValue: 0,
      useNativeDriver,
    }).start(({ finished }) => {
      if (finished && !cancelled) {
        libraryPanelAnim.setValue(0);
        onLibraryPanelSwap(libraryPanel);
        setRenderedLibraryPanel(libraryPanel);
      }
    });

    return () => {
      cancelled = true;
    };
  }, [libraryPanel, libraryPanelAnim, onLibraryPanelSwap, renderedLibraryPanel]);

  useEffect(() => {
    libraryWindowStartRef.current = libraryWindowStart;
  }, [libraryWindowStart]);

  useEffect(() => {
    libraryItemExtentRef.current = libraryItemExtent;
  }, [libraryItemExtent]);

  useEffect(() => {
    appScrollRef.current?.scrollTo({ y: 0, animated: false });
    scrollYRef.current = 0;
    setScrollY(0);
    libraryWindowStartRef.current = 0;
    setLibraryWindowStart(0);
    setSelectedLibraryWord(null);
    setLibraryPanel('list');
    setRenderedLibraryPanel('list');
  }, [activeTab, activeFilter, activeInitial, activeLevel, activeSort, searchQuery]);

  useEffect(() => {
    if (activeTab !== 'profile') {
      setProfilePanel('overview');
    }
  }, [activeTab]);

  useEffect(() => {
    setWordIndex(0);
  }, [studyFilter, studyInitial, studyLevel, studySetId]);

  useEffect(() => {
    setQuizIndex(0);
    setQuizResult(null);
    setSpeakingAnswerVisible(false);
    setAnsweredQuizWord(null);
    setLockedQuizOptions(null);
    setQuizSession([]);
    setQuizStarted(false);
    setQuizFinished(false);
    setQuizCorrectCount(0);
    setQuizSeed('');
  }, [quizFilter, quizInitial, quizLevel, quizSetId]);

  useEffect(() => {
    const setIds = new Set(customSetState.sets.map((set) => set.id));
    if (selectedCustomSetId && !setIds.has(selectedCustomSetId)) {
      setSelectedCustomSetId(customSetState.sets[0]?.id ?? null);
    }
    if (studySetId && !setIds.has(studySetId)) {
      setStudySetId(null);
    }
    if (quizSetId && !setIds.has(quizSetId)) {
      setQuizSetId(null);
    }
  }, [customSetState.sets, quizSetId, selectedCustomSetId, studySetId]);

  useEffect(() => {
    setLibraryWindowStart((current) => {
      const next = Math.min(current, Math.max(0, libraryWords.length - LIBRARY_WINDOW_SIZE));
      libraryWindowStartRef.current = next;
      return next;
    });
  }, [libraryWords.length]);

  useEffect(() => {
    const levelIds = new Set(levelFilterOptions.map((level) => level.id));
    if (!levelIds.has(studyLevel)) {
      setStudyLevel('all');
    }
    if (!levelIds.has(quizLevel)) {
      setQuizLevel('all');
    }
    if (!levelIds.has(activeLevel)) {
      setActiveLevel('all');
    }
  }, [activeLevel, levelFilterOptions, quizLevel, studyLevel]);

  useEffect(() => {
    setWordIndex(0);
    setQuizIndex(0);
    setQuizResult(null);
    setAnsweredQuizWord(null);
    setLockedQuizOptions(null);
    setQuizSession([]);
    setQuizStarted(false);
    setQuizFinished(false);
    setQuizCorrectCount(0);
    setQuizSeed('');
    setLibraryWindowStart(0);
    setSelectedLibraryWord(null);
  }, [developerVocabulary?.importedAt, studyMode]);

  useEffect(() => {
    const localProgress = normalizeProgressForDate(loadProgressFromStorage(getAppStorage(), initialProgress), today);
    setProgress(localProgress);
    setProgressReady(true);

    if (!supabaseClient) {
      setAccount((current) => ({
        ...current,
        busy: false,
        status: 'local',
        message: '本機記憶中',
      }));
      return;
    }

    let cancelled = false;
    setAccount((current) => ({
      ...current,
      busy: true,
      status: 'loading',
      message: '檢查登入狀態',
    }));

    supabaseClient.auth
      .getSession()
      .then(async ({ data, error }) => {
        if (cancelled) {
          return;
        }

        if (error || !data.session?.user) {
          setAccount((current) => ({
            ...current,
            busy: false,
            status: 'signedOut',
            message: '未登入',
          }));
          return;
        }

        await activateSignedInUser(data.session.user);
      })
      .catch((error: unknown) => {
        if (cancelled) {
          return;
        }

        setAccount((current) => ({
          ...current,
          busy: false,
          status: 'error',
          message: error instanceof Error ? error.message : '登入狀態檢查失敗',
        }));
      });

    return () => {
      cancelled = true;
    };
  }, [supabaseClient]);

  useEffect(() => {
    if (!progressReady) {
      return;
    }

    saveProgressToStorage(getAppStorage(), progress, account.userId);
  }, [account.userId, progress, progressReady]);

  useEffect(() => {
    if (!progressReady || !supabaseClient || !account.userId) {
      return;
    }

    let cancelled = false;
    const syncTimer = setTimeout(() => {
      setAccount((current) => ({
        ...current,
        status: 'syncing',
        message: '同步中',
      }));

      Promise.all([
        saveCloudProgress(asCloudProgressClient(supabaseClient), account.userId ?? '', progress),
        saveCloudCustomSets(asCloudProgressClient(supabaseClient), account.userId ?? '', customSetState),
      ]).then(([progressResult, customSetResult]) => {
        if (cancelled) {
          return;
        }

        const saved = progressResult.ok && customSetResult.ok;
        setAccount((current) => ({
          ...current,
          busy: false,
          status: saved ? 'saved' : 'error',
          message: saved ? '已保存到帳號' : progressResult.ok ? customSetResult.message : progressResult.message,
        }));
      });
    }, 450);

    return () => {
      cancelled = true;
      clearTimeout(syncTimer);
    };
  }, [account.userId, customSetState, progress, progressReady, supabaseClient]);

  useEffect(() => {
    if (!supabaseClient || !account.userId) {
      return;
    }

    let cancelled = false;
    const recordActivity = () => {
      if (cancelled || !account.userId) {
        return;
      }

      recordDailyActiveUser(asCloudProgressClient(supabaseClient), account.userId).catch(() => undefined);
    };

    recordActivity();
    const heartbeat = setInterval(recordActivity, ACTIVE_USER_HEARTBEAT_MS);
    const visibilityDocument = (globalThis as { document?: Document }).document;
    const handleVisibility = () => {
      if (visibilityDocument?.visibilityState === 'visible') {
        recordActivity();
      }
    };

    visibilityDocument?.addEventListener?.('visibilitychange', handleVisibility);

    return () => {
      cancelled = true;
      clearInterval(heartbeat);
      visibilityDocument?.removeEventListener?.('visibilitychange', handleVisibility);
    };
  }, [account.userId, supabaseClient]);

  function nextStudyWord() {
    setWordIndex((current) => (studyWords.length > 0 ? (current + 1) % studyWords.length : 0));
  }

  function handleKnown(wordId: string) {
    setProgress((current) => markKnown(current, wordId, today));
    nextStudyWord();
  }

  function handleReview(wordId: string) {
    setProgress((current) => markReview(current, wordId, today));
    nextStudyWord();
  }

  const handleLibraryQueryChange = useCallback((query: string) => {
    setSearchQuery(query);
    setLibraryWindowStart(0);
  }, []);

  const clearLibrarySearch = useCallback(() => {
    setSearchQuery('');
    setLibraryWindowStart(0);
  }, []);

  function handleExportVocabulary() {
    const downloaded = downloadTextFile(`word7000-vocabulary-${today}.csv`, exportWordsToCsv(vocabularyWords), 'text/csv;charset=utf-8');
    setDeveloperVocabularyMessage(downloaded ? activeSystemCopy.exportCsvSuccess(vocabularyWords.length) : activeSystemCopy.exportCsvUnavailable);
  }

  async function handleImportVocabulary() {
    setDeveloperVocabularyMessage(activeSystemCopy.importReading);
    const picked = await pickVocabularyTextFile(activeSystemCopy);
    if (!picked.ok) {
      setDeveloperVocabularyMessage(picked.message);
      return;
    }

    const parsed = parseVocabularyImport(picked.text, picked.fileName);
    if (!parsed.ok) {
      setDeveloperVocabularyMessage(parsed.errors.map((message) => developerVocabularyMessageForMode(message, studyMode)).join(' '));
      return;
    }

    const applied = applyVocabularyImportRows(vocabularyWords, parsed.rows);
    if (applied.updated + applied.added === 0 && applied.errors.length > 0) {
      setDeveloperVocabularyMessage(applied.errors.slice(0, 3).map((message) => developerVocabularyMessageForMode(message, studyMode)).join(' '));
      return;
    }

    const summary = activeSystemCopy.importApplied(applied.updated, applied.added, applied.words.length);
    const snapshot = {
      importedAt: new Date().toISOString(),
      summary,
      words: applied.words,
    };
    setDeveloperVocabulary(snapshot);
    saveDeveloperVocabulary(getAppStorage(), snapshot);
    setDeveloperVocabularyMessage(applied.errors.length > 0 ? activeSystemCopy.importAppliedWithErrors(summary, applied.errors.length) : summary);
  }

  function handleClearDeveloperVocabulary() {
    clearDeveloperVocabulary(getAppStorage());
    setDeveloperVocabulary(null);
    setDeveloperVocabularyMessage(activeSystemCopy.clearPreview);
  }

  const handleOpenSetPicker = useCallback((word: WordEntry) => {
    setSetPickerWord(word);
    setNewSetName('');
  }, []);

  function handleCloseSetPicker() {
    setSetPickerWord(null);
    setNewSetName('');
  }

  function handleCreateCustomSet() {
    const ui = modeInterfaceCopy[studyMode];
    const next = createCustomSet(customSetState, newSetName);
    const createdSet = next.sets[next.sets.length - 1] ?? null;
    setCustomSetState(next);
    if (createdSet) {
      setSelectedCustomSetId(createdSet.id);
      setNewSetName('');
      setCustomSetMessage(ui.setCreated(createdSet.name));
    }
  }

  function handleCreateSetAndAddPickerWord() {
    if (!setPickerWord) {
      return;
    }

    const word = setPickerWord;
    const ui = modeInterfaceCopy[studyMode];
    const withSet = createCustomSet(customSetState, newSetName);
    const createdSet = withSet.sets[withSet.sets.length - 1] ?? null;
    setCustomSetState(createdSet ? addWordToSet(withSet, createdSet.id, word.id) : withSet);
    if (createdSet) {
      setSelectedCustomSetId(createdSet.id);
      setCustomSetMessage(ui.addedToSet(formatWordPrimary(word, studyMode), createdSet.name));
    }
    handleCloseSetPicker();
  }

  function handleAddPickerWordToSet(setId: string) {
    if (!setPickerWord) {
      return;
    }

    const word = setPickerWord;
    const setName = customSetState.sets.find((set) => set.id === setId)?.name ?? '';
    setCustomSetState((current) => addWordToSet(current, setId, word.id));
    setSelectedCustomSetId(setId);
    setCustomSetMessage(modeInterfaceCopy[studyMode].addedToSet(formatWordPrimary(word, studyMode), setName));
    handleCloseSetPicker();
  }

  function handleRenameCustomSet(setId: string, name: string) {
    const cleanName = name.trim();
    if (!cleanName) {
      setCustomSetMessage(modeInterfaceCopy[studyMode].customSetSelectPlaceholder);
      return;
    }

    setCustomSetState((current) => renameCustomSet(current, setId, cleanName));
    setCustomSetMessage(modeInterfaceCopy[studyMode].setRenamed(cleanName));
  }

  function handleDeleteCustomSet(setId: string) {
    const targetSet = customSetState.sets.find((set) => set.id === setId);
    if (!targetSet) {
      return;
    }

    const remainingSets = customSetState.sets.filter((set) => set.id !== setId);
    setCustomSetState((current) => deleteCustomSet(current, setId));
    setSelectedCustomSetId(remainingSets[0]?.id ?? null);
    if (studySetId === setId) {
      setStudySetId(null);
    }
    if (quizSetId === setId) {
      setQuizSetId(null);
    }
    setCustomSetMessage(modeInterfaceCopy[studyMode].setDeleted(targetSet.name));
  }

  function handleRemoveWordFromCustomSet(setId: string, word: WordEntry) {
    const targetSet = customSetState.sets.find((set) => set.id === setId);
    if (!targetSet) {
      return;
    }

    setCustomSetState((current) => removeWordFromSet(current, setId, word.id));
    setCustomSetMessage(modeInterfaceCopy[studyMode].removedFromSet(formatWordPrimary(word, studyMode), targetSet.name));
  }

  function handleManualCustomWordChange(field: keyof ManualCustomWordState, value: string) {
    setManualCustomWord((current) => ({ ...current, [field]: value }));
  }

  function handleAddManualCustomWord() {
    const ui = modeInterfaceCopy[studyMode];
    const targetSetId = selectedCustomSetId ?? sortedCustomSets[0]?.id;
    const targetSet = customSetState.sets.find((set) => set.id === targetSetId);
    const wordText = manualCustomWord.word.trim();
    const meaningText = manualCustomWord.meaningZh.trim();

    if (!targetSet) {
      setCustomSetMessage(ui.customSetSelectPlaceholder);
      return;
    }
    if (!wordText || !meaningText) {
      setCustomSetMessage(`${ui.customWordWordPlaceholder} / ${ui.customWordMeaningPlaceholder}`);
      return;
    }

    const existingWord = vocabularyWords.find((word) => word.word.toLowerCase() === wordText.toLowerCase());
    if (existingWord) {
      setCustomSetState((current) => addWordToSet(current, targetSet.id, existingWord.id));
      setCustomSetMessage(ui.addedToSet(formatWordPrimary(existingWord, studyMode), targetSet.name));
      setManualCustomWord(emptyManualCustomWord);
      return;
    }

    const normalizedId = wordText.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');
    const customWord: WordEntry = {
      example: manualCustomWord.example.trim() || `I want to remember the word ${wordText}.`,
      exampleZh: manualCustomWord.exampleZh.trim() || `我想記住 ${wordText} 這個單字。`,
      group: 'Custom',
      id: `custom-${normalizedId || Date.now()}`,
      meaningZh: meaningText,
      partOfSpeech: manualCustomWord.partOfSpeech.trim() || 'n',
      pronunciation: manualCustomWord.pronunciation.trim() || `/${wordText}/`,
      word: wordText,
    };

    setCustomSetState((current) => addCustomWordToSet(current, targetSet.id, customWord));
    setCustomSetMessage(ui.customWordAdded(customWord.word, targetSet.name));
    setManualCustomWord(emptyManualCustomWord);
  }

  async function handleImportCustomWords() {
    const ui = modeInterfaceCopy[studyMode];
    const targetSetId = selectedCustomSetId ?? sortedCustomSets[0]?.id;
    const targetSet = customSetState.sets.find((set) => set.id === targetSetId);
    if (!targetSet) {
      setCustomSetMessage(ui.customSetSelectPlaceholder);
      return;
    }

    setCustomSetMessage(activeSystemCopy.importReading);
    const picked = await pickVocabularyTextFile(activeSystemCopy);
    if (!picked.ok) {
      setCustomSetMessage(picked.message);
      return;
    }

    const parsed = parseCustomWordsCsv(picked.text);
    if (!parsed.ok) {
      setCustomSetMessage(parsed.errors.map((message) => developerVocabularyMessageForMode(message, studyMode)).join(' '));
      return;
    }

    const applied = customWordsFromImportRows(parsed.rows, vocabularyWords);
    if (applied.words.length === 0) {
      setCustomSetMessage(applied.errors.slice(0, 3).map((message) => developerVocabularyMessageForMode(message, studyMode)).join(' '));
      return;
    }

    setCustomSetState((current) =>
      applied.words.reduce((nextState, word) => addCustomWordToSet(nextState, targetSet.id, word), current),
    );
    setCustomSetMessage(ui.customImportApplied(applied.words.length, Math.max(0, parsed.rows.length - applied.words.length)));
  }

  function handleStartStudySet(setId: string) {
    setStudySetId(setId);
    setWordIndex(0);
    setActiveTab('study');
    setProfilePanel('overview');
  }

  function handleStartQuizSet(setId: string) {
    setQuizSetId(setId);
    restartQuiz();
    setActiveTab('quiz');
    setProfilePanel('overview');
  }

  function handleQuizPracticeModeChange(mode: QuizPracticeMode) {
    setQuizPracticeMode(mode);
    restartQuiz();
  }

  function revealSpeakingAnswer() {
    setSpeakingAnswerVisible(true);
  }

  function handleQuizAnswer(correct: boolean) {
    if (!quizWord) {
      return;
    }
    setAnsweredQuizWord(quizWord);
    setLockedQuizOptions(quizOptions);
    setQuizResult(correct ? 'correct' : 'wrong');
    if (correct) {
      setQuizCorrectCount((current) => current + 1);
    }
    setProgress((current) => (correct ? markKnown(current, quizWord.id, today) : markReview(current, quizWord.id, today)));
  }

  function startQuiz() {
    const seed = `${Date.now()}:${Math.random()}`;
    const session = buildQuizSession(quizWords, quizQuestionCount, seed);
    setQuizSession(session);
    setQuizSeed(seed);
    setQuizIndex(0);
    setQuizCorrectCount(0);
    setQuizResult(null);
    setSpeakingAnswerVisible(false);
    setAnsweredQuizWord(null);
    setLockedQuizOptions(null);
    setQuizFinished(false);
    setQuizStarted(session.length > 0);
  }

  function restartQuiz() {
    setQuizIndex(0);
    setQuizResult(null);
    setSpeakingAnswerVisible(false);
    setAnsweredQuizWord(null);
    setLockedQuizOptions(null);
    setQuizStarted(false);
    setQuizFinished(false);
    setQuizCorrectCount(0);
  }

  function nextQuiz() {
    setQuizResult(null);
    setSpeakingAnswerVisible(false);
    setAnsweredQuizWord(null);
    setLockedQuizOptions(null);
    if (quizIndex >= quizSession.length - 1) {
      setQuizStarted(false);
      setQuizFinished(true);
      return;
    }
    setQuizIndex((current) => current + 1);
  }

  function handleScroll(event: NativeSyntheticEvent<NativeScrollEvent>) {
    if (activeTab === 'library') {
      const nextScrollY = event.nativeEvent.contentOffset.y;
      scrollYRef.current = nextScrollY;
      setScrollY(nextScrollY);
      if (!libraryScrollSyncLockedRef.current && !librarySliderDraggingRef.current) {
        syncLibraryWindowFromScroll(nextScrollY);
      }
    }
  }

  function syncLibraryWindowFromScroll(nextScrollY: number) {
    const currentWindowStart = libraryWindowStartRef.current;

    if (
      activeTab !== 'library' ||
      libraryPanel !== 'list' ||
      selectedLibraryWord ||
      libraryWords.length <= LIBRARY_WINDOW_SIZE ||
      libraryListTopYRef.current <= 0 ||
      !shouldSyncLibraryWindowFromScroll(nextScrollY, libraryListTopYRef.current, currentWindowStart)
    ) {
      return;
    }

    const nextWindowStart = virtualWindowStartFromScroll(
      nextScrollY,
      libraryListTopYRef.current,
      libraryItemExtentRef.current,
      libraryWords.length,
      LIBRARY_WINDOW_SIZE,
      LIBRARY_SCROLL_BACKWARD_ANCHOR,
    );

    if (nextWindowStart === currentWindowStart) {
      return;
    }

    libraryWindowStartRef.current = nextWindowStart;
    setLibraryWindowStart(nextWindowStart);
  }

  function handleLibrarySliderDrag(locationY: number) {
    const target = wordWindowStartFromSlider(
      locationY,
      sliderTrackHeight,
      libraryWords.length,
      LIBRARY_WINDOW_SIZE,
      LIBRARY_SLIDER_THUMB_HEIGHT,
    );
    const bufferedStart = virtualWindowStartFromWordIndex(
      target,
      libraryWords.length,
      LIBRARY_WINDOW_SIZE,
      LIBRARY_SCROLL_BACKWARD_ANCHOR,
    );
    libraryWindowStartRef.current = bufferedStart;
    setLibraryWindowStart(bufferedStart);
    scrollLibraryListIntoView(false, target);
  }

  function finishLibrarySliderDrag() {
    setLibrarySliderDragging(false);
    requestAnimationFrame(() => {
      librarySliderDraggingRef.current = false;
    });
  }

  function scrollLibraryListIntoView(animated: boolean, targetWordStart = libraryWindowStartRef.current) {
    const wordOffset = Math.max(0, targetWordStart) * libraryItemExtentRef.current + LIBRARY_LIST_DRAG_SCROLL_OFFSET;
    const targetY = Math.max(
      LIBRARY_LIST_DRAG_MIN_SCROLL_Y,
      libraryListScrollTarget(libraryListTopYRef.current, wordOffset),
    );
    scrollYRef.current = targetY;
    setScrollY(targetY);
    appScrollRef.current?.scrollTo({ y: targetY, animated });
  }

  const handleLibraryListLayout = useCallback((event: LayoutChangeEvent) => {
    const nextTop = Math.max(0, Math.round(event.nativeEvent.layout.y));
    libraryListTopYRef.current = nextTop;
    setLibraryListTopY(nextTop);
  }, []);

  const handleLibraryFirstItemLayout = useCallback((event: LayoutChangeEvent) => {
    if (libraryWindowStartRef.current > 0) {
      return;
    }

    const nextExtent = Math.max(96, Math.round(event.nativeEvent.layout.height + 10));
    if (Math.abs(nextExtent - libraryItemExtentRef.current) < 3) {
      return;
    }

    libraryItemExtentRef.current = nextExtent;
    setLibraryItemExtent(nextExtent);
  }, []);

  function returnLibraryToTop() {
    libraryWindowStartRef.current = 0;
    setLibraryWindowStart(0);
    scrollYRef.current = 0;
    appScrollRef.current?.scrollTo({ y: 0, animated: true });
    setScrollY(0);
  }

  const openLibraryWordDetail = useCallback((word: WordEntry) => {
    setSelectedLibraryWord(word);
    setLibraryPanel('detail');
  }, []);

  const closeLibraryWordDetail = useCallback(() => {
    setLibraryPanel('list');
  }, []);

  const handleLibraryFiltersToggle = useCallback(() => {
    setLibraryFiltersOpen((current) => !current);
  }, []);

  const handleLibraryFavorite = useCallback((wordId: string) => {
    setProgress((current) => toggleFavorite(current, wordId));
  }, []);

  const handleLibrarySearchBlur = useCallback(() => {
    setSearchFocused(false);
  }, []);

  const handleLibrarySearchFocus = useCallback(() => {
    setSearchFocused(true);
  }, []);

  const openLibraryCustomSets = useCallback(() => {
    setLibraryPanel('sets');
  }, []);

  const onProfilePanelSwap = useCallback(() => {
    appScrollRef.current?.scrollTo({ y: 0, animated: false });
    setScrollY(0);
  }, []);

  function openInstallGuide() {
    setInstallGuideStep(0);
    setShowInstallGuide(true);
    installGuideAnim.setValue(0);
    Animated.timing(installGuideAnim, {
      duration: 260,
      easing: Easing.out(Easing.cubic),
      toValue: 1,
      useNativeDriver: Platform.OS !== 'web',
    }).start();
  }

  function dismissInstallGuide() {
    markInstallGuideSeen(getAppStorage(), isInstalledWebApp());
    Animated.timing(installGuideAnim, {
      duration: 220,
      easing: Easing.inOut(Easing.cubic),
      toValue: 0,
      useNativeDriver: Platform.OS !== 'web',
    }).start(({ finished }) => {
      if (finished) {
        setShowInstallGuide(false);
      }
    });
  }

  function nextInstallGuideStep() {
    if (installGuideStep >= activeInstallGuideSteps.length - 1) {
      dismissInstallGuide();
      return;
    }

    setInstallGuideStep((current) => Math.min(current + 1, activeInstallGuideSteps.length - 1));
  }

  async function activateSignedInUser(user: SupabaseUser) {
    if (!supabaseClient) {
      return;
    }

    const storage = getAppStorage();
    const cloudProgress = await loadCloudProgressRecord(asCloudProgressClient(supabaseClient), user.id);
    const userLocalProgress = normalizeProgressForDate(loadProgressFromStorage(storage, initialProgress, user.id), today);
    const loadedProgress = normalizeProgressForDate(
      cloudProgress.progress ?? (cloudProgress.errorMessage ? userLocalProgress : initialProgress),
      today,
    );
    const loadedCustomSetState = mergeCustomSetStates(cloudProgress.customSets, loadCustomSetState(storage, user.id), loadCustomSetState(storage));

    setProgress(loadedProgress);
    saveProgressToStorage(storage, loadedProgress, user.id);
    setCustomSetState(loadedCustomSetState);
    saveCustomSetState(storage, loadedCustomSetState, user.id);
    setSelectedCustomSetId(null);
    setStudySetId(null);
    setQuizSetId(null);
    setSetPickerWord(null);
    setAccount((current) => ({
      ...current,
      userId: user.id,
      userEmail: user.email ?? current.email,
      busy: false,
      status: 'signedIn',
      message: cloudProgress.found ? '已登入' : '已建立新的帳號記憶',
    }));
  }

  async function handleGoogleSignIn() {
    if (!supabaseClient) {
      setAccount((current) => ({
        ...current,
        status: 'local',
        message: '本機記憶中',
      }));
      return;
    }

    setAccount((current) => ({
      ...current,
      busy: true,
      status: 'loading',
      message: '正在開啟 Google 登入',
    }));

    const redirectTo = getOAuthRedirectUrl();
    const { data, error } = await supabaseClient.auth.signInWithOAuth({
      provider: 'google',
      options: {
        ...(redirectTo ? { redirectTo } : {}),
        skipBrowserRedirect: Platform.OS !== 'web',
        queryParams: {
          prompt: 'select_account',
        },
      },
    });

    if (error) {
      setAccount((current) => ({
        ...current,
        busy: false,
        status: 'error',
        message: error.message,
      }));
      return;
    }

    if (Platform.OS !== 'web') {
      if (!data.url || !redirectTo) {
        setAccount((current) => ({
          ...current,
          busy: false,
          status: 'error',
          message: '無法開啟手機登入流程',
        }));
        return;
      }

      const result = await WebBrowser.openAuthSessionAsync(data.url, redirectTo);
      if (result.type !== 'success') {
        setAccount((current) => ({
          ...current,
          busy: false,
          status: 'signedOut',
          message: '已取消登入',
        }));
        return;
      }

      await completeNativeOAuthSignIn(result.url);
      return;
    }

    setAccount((current) => ({
      ...current,
      busy: true,
      status: 'loading',
      message: '請完成 Google 登入',
    }));
  }

  async function handleAppleSignIn() {
    if (!supabaseClient) {
      setAccount((current) => ({
        ...current,
        status: 'local',
        message: '本機記憶中',
      }));
      return;
    }

    if (IS_WEB_IOS_PREVIEW) {
      setAccount((current) => ({
        ...current,
        busy: false,
        status: 'error',
        message: 'Apple 登入在網頁預覽中只顯示入口',
      }));
      return;
    }

    if (Platform.OS !== 'ios') {
      setAccount((current) => ({
        ...current,
        busy: false,
        status: 'error',
        message: 'Apple 登入只能在 iPhone App 使用',
      }));
      return;
    }

    setAccount((current) => ({
      ...current,
      busy: true,
      status: 'loading',
      message: '正在開啟 Apple 登入',
    }));

    try {
      const available = await AppleAuthentication.isAvailableAsync();
      if (!available) {
        setAccount((current) => ({
          ...current,
          busy: false,
          status: 'error',
          message: '此裝置目前無法使用 Apple 登入',
        }));
        return;
      }

      const credential = await AppleAuthentication.signInAsync({
        requestedScopes: [
          AppleAuthentication.AppleAuthenticationScope.EMAIL,
          AppleAuthentication.AppleAuthenticationScope.FULL_NAME,
        ],
      });

      if (!credential.identityToken) {
        setAccount((current) => ({
          ...current,
          busy: false,
          status: 'error',
          message: 'Apple 登入沒有回傳帳號憑證',
        }));
        return;
      }

      const { data, error } = await supabaseClient.auth.signInWithIdToken({
        provider: 'apple',
        token: credential.identityToken,
      });

      if (error || !data.user) {
        setAccount((current) => ({
          ...current,
          busy: false,
          status: 'error',
          message: error?.message ?? 'Apple 登入失敗',
        }));
        return;
      }

      await activateSignedInUser(data.user);
    } catch (error: unknown) {
      const errorCode = typeof error === 'object' && error && 'code' in error ? String((error as { code?: unknown }).code) : '';
      setAccount((current) => ({
        ...current,
        busy: false,
        status: errorCode === 'ERR_REQUEST_CANCELED' ? 'signedOut' : 'error',
        message: errorCode === 'ERR_REQUEST_CANCELED' ? '已取消登入' : error instanceof Error ? error.message : 'Apple 登入失敗',
      }));
    }
  }

  async function completeNativeOAuthSignIn(callbackUrl: string) {
    if (!supabaseClient) {
      return;
    }

    const callback = parseOAuthCallbackUrl(callbackUrl);

    if (callback.code) {
      const { data, error } = await supabaseClient.auth.exchangeCodeForSession(callback.code);
      if (error || !data.user) {
        setAccount((current) => ({
          ...current,
          busy: false,
          status: 'error',
          message: error?.message ?? '登入導回失敗',
        }));
        return;
      }

      await activateSignedInUser(data.user);
      return;
    }

    if (callback.accessToken && callback.refreshToken) {
      const { data, error } = await supabaseClient.auth.setSession({
        access_token: callback.accessToken,
        refresh_token: callback.refreshToken,
      });
      if (error || !data.user) {
        setAccount((current) => ({
          ...current,
          busy: false,
          status: 'error',
          message: error?.message ?? '登入導回失敗',
        }));
        return;
      }

      await activateSignedInUser(data.user);
      return;
    }

    setAccount((current) => ({
      ...current,
      busy: false,
      status: 'error',
      message: '登入導回沒有取得帳號資料',
    }));
  }

  async function handleSignUp() {
    if (!supabaseClient) {
      setAccount((current) => ({
        ...current,
        status: 'local',
        message: '本機記憶中',
      }));
      return;
    }

    const email = account.email.trim();
    const password = account.password;
    if (!email || password.length < 6) {
      setAccount((current) => ({
        ...current,
        status: 'error',
        message: 'Email 和密碼至少 6 碼',
      }));
      return;
    }

    setAccount((current) => ({
      ...current,
      busy: true,
      status: 'loading',
      message: '建立帳號中',
    }));

    const { data, error } = await supabaseClient.auth.signUp({ email, password });
    if (error) {
      setAccount((current) => ({
        ...current,
        busy: false,
        status: 'error',
        message: error.message,
      }));
      return;
    }

    if (data.user && data.session) {
      await activateSignedInUser(data.user);
      return;
    }

    setAccount((current) => ({
      ...current,
      busy: false,
      status: 'signedOut',
      message: '請確認信箱後登入',
    }));
  }

  async function handleSignIn() {
    if (!supabaseClient) {
      setAccount((current) => ({
        ...current,
        status: 'local',
        message: '本機記憶中',
      }));
      return;
    }

    const email = account.email.trim();
    const password = account.password;
    if (!email || !password) {
      setAccount((current) => ({
        ...current,
        status: 'error',
        message: '請輸入 Email 和密碼',
      }));
      return;
    }

    setAccount((current) => ({
      ...current,
      busy: true,
      status: 'loading',
      message: '登入中',
    }));

    const { data, error } = await supabaseClient.auth.signInWithPassword({ email, password });
    if (error || !data.user) {
      setAccount((current) => ({
        ...current,
        busy: false,
        status: 'error',
        message: error?.message ?? '登入失敗',
      }));
      return;
    }

    await activateSignedInUser(data.user);
  }

  async function handleSignOut() {
    const signedInUserId = account.userId;
    if (signedInUserId) {
      saveProgressToStorage(getAppStorage(), progress, signedInUserId);
      saveCustomSetState(getAppStorage(), customSetState, signedInUserId);
    }

    if (supabaseClient && signedInUserId) {
      await saveCloudProgress(asCloudProgressClient(supabaseClient), signedInUserId, progress);
      await saveCloudCustomSets(asCloudProgressClient(supabaseClient), signedInUserId, customSetState);
    }

    if (supabaseClient) {
      await supabaseClient.auth.signOut();
    }

    const guestProgress = normalizeProgressForDate(loadProgressFromStorage(getAppStorage(), initialProgress), today);
    setProgress(guestProgress);
    setCustomSetState(loadCustomSetState(getAppStorage()));
    setSelectedCustomSetId(null);
    setStudySetId(null);
    setQuizSetId(null);
    setSetPickerWord(null);
    setAccount((current) => ({
      ...current,
      userId: null,
      userEmail: null,
      password: '',
      busy: false,
      status: supabaseClient ? 'signedOut' : 'local',
      message: supabaseClient ? '已登出' : '本機記憶中',
    }));
  }

  function confirmDeleteAccountData() {
    if (!account.userId) {
      void handleDeleteAccountData();
      return;
    }

    const ui = modeInterfaceCopy[studyMode];
    if (Platform.OS === 'web') {
      const confirmed =
        typeof globalThis.confirm === 'function'
          ? globalThis.confirm(`${ui.deleteAccountDataConfirmTitle}\n\n${ui.deleteAccountDataConfirmText}`)
          : true;
      if (confirmed) {
        void handleDeleteAccountData();
      }
      return;
    }

    Alert.alert(ui.deleteAccountDataConfirmTitle, ui.deleteAccountDataConfirmText, [
      {
        text: ui.deleteAccountDataConfirmCancel,
        style: 'cancel',
      },
      {
        text: ui.deleteAccountDataConfirmAction,
        style: 'destructive',
        onPress: () => {
          void handleDeleteAccountData();
        },
      },
    ]);
  }

  async function handleDeleteAccountData() {
    const signedInUserId = account.userId;
    if (!supabaseClient || !signedInUserId) {
      setAccount((current) => ({
        ...current,
        busy: false,
        status: supabaseClient ? 'signedOut' : 'local',
        message: supabaseClient ? '請先登入' : '本機記憶中',
      }));
      return;
    }

    setAccount((current) => ({
      ...current,
      busy: true,
      status: 'loading',
      message: '正在刪除帳號學習資料',
    }));

    const result = await deleteCloudUserData(asCloudProgressClient(supabaseClient), signedInUserId);
    if (!result.ok) {
      setAccount((current) => ({
        ...current,
        busy: false,
        status: 'error',
        message: result.message,
      }));
      return;
    }

    const storage = getAppStorage();
    storage?.removeItem?.(progressStorageKey(signedInUserId));
    storage?.removeItem?.(customSetStorageKey(signedInUserId));
    await supabaseClient.auth.signOut();

    setProgress(normalizeProgressForDate(loadProgressFromStorage(storage, initialProgress), today));
    setCustomSetState(loadCustomSetState(storage));
    setSelectedCustomSetId(null);
    setStudySetId(null);
    setQuizSetId(null);
    setSetPickerWord(null);
    setAccount((current) => ({
      ...current,
      userId: null,
      userEmail: null,
      password: '',
      busy: false,
      status: 'signedOut',
      message: '帳號學習資料已刪除',
    }));
  }

  function handleOpenAppInfoLink(url: string) {
    Linking.openURL(url).catch(() => {
      setAccount((current) => ({
        ...current,
        status: 'error',
        message: '無法開啟連結',
      }));
    });
  }

  function toggleStudyMode() {
    const nextMode: StudyMode = studyMode === 'english' ? 'chinese' : 'english';
    setModeSwitchTarget(nextMode);
    setShowModeSwitch(true);
    modeTransitionAnim.setValue(0);

    Animated.timing(modeTransitionAnim, {
      duration: 210,
      easing: Easing.out(Easing.cubic),
      toValue: 1,
      useNativeDriver: Platform.OS !== 'web',
    }).start(() => {
      setStudyMode(nextMode);
      Animated.sequence([
        Animated.delay(220),
        Animated.timing(modeTransitionAnim, {
          duration: 260,
          easing: Easing.inOut(Easing.cubic),
          toValue: 0,
          useNativeDriver: Platform.OS !== 'web',
        }),
      ]).start(({ finished }) => {
        if (finished) {
          setShowModeSwitch(false);
        }
      });
    });
  }

  function triggerThemeModeChange(nextMode: ThemeMode) {
    if (nextMode === themeMode || showThemeTransition) {
      return;
    }

    setThemeTransitionTarget(nextMode);
    setShowThemeTransition(true);
    themeTransitionAnim.setValue(0);
    Animated.timing(themeTransitionAnim, {
      duration: 180,
      easing: Easing.out(Easing.cubic),
      toValue: 1,
      useNativeDriver: Platform.OS !== 'web',
    }).start(({ finished }) => {
      if (!finished) {
        return;
      }

      setThemeMode(nextMode);
      Animated.timing(themeTransitionAnim, {
        duration: 260,
        easing: Easing.inOut(Easing.cubic),
        toValue: 0,
        useNativeDriver: Platform.OS !== 'web',
      }).start(({ finished: fadeFinished }) => {
        if (fadeFinished) {
          setShowThemeTransition(false);
        }
      });
    });
  }

  return (
    <ThemeContext.Provider value={themeMode}>
    <SafeAreaView style={[styles.safeArea, themeStyles?.safeArea, IS_WEB_IOS_PREVIEW && styles.webIosPreviewSafeArea]}>
      <StatusBar style={darkMode ? 'light' : 'dark'} />
      <View style={[styles.appShell, IS_WEB_IOS_PREVIEW && styles.webIosPreviewAppShell, themeStyles?.appShell]}>
        <View
          onLayout={(event) => setHeaderHeight(Math.ceil(event.nativeEvent.layout.height))}
          style={styles.header}
        >
          <View>
            <Text style={[styles.brand, themeStyles?.brand]}>{activeModeCopy.brand}</Text>
            <Text style={[styles.headerSubtext, themeStyles?.headerSubtext]}>{activeModeCopy.subtitle}</Text>
          </View>
          <View style={styles.headerActions}>
            {previewModeLabel && (
              <View style={[styles.previewModePill, themeStyles?.previewModePill]}>
                <Smartphone size={14} color={darkMode ? '#bfdbfe' : '#2563eb'} strokeWidth={2.4} />
                <Text style={[styles.previewModeText, themeStyles?.previewModeText]}>{previewModeLabel}</Text>
              </View>
            )}
            <View style={[styles.levelPill, themeStyles?.levelPill]}>
              <Trophy size={15} color="#2f855a" strokeWidth={2.4} />
              <Text style={[styles.levelText, themeStyles?.levelText]}>Day {progress.streak}</Text>
            </View>
          </View>
        </View>
        <ScrollView
          contentContainerStyle={styles.content}
          onScroll={handleScroll}
          ref={appScrollRef}
          scrollEventThrottle={16}
          showsVerticalScrollIndicator={false}
          style={IS_WEB_IOS_PREVIEW && styles.webIosPreviewScroll}
        >
          <Animated.View style={[styles.screenMotion, screenMotionWebTransition, screenMotionStyle]}>
          {activeTab === 'home' && (
            <HomeView
              dailyPercent={dailyPercent}
              progress={progress}
              stats={stats}
              studyMode={studyMode}
              onOpenAccount={() => setActiveTab('profile')}
              onStartStudy={() => setActiveTab('study')}
              onOpenReview={() => {
                setActiveFilter('review');
                setActiveTab('library');
              }}
              onToggleStudyMode={toggleStudyMode}
            />
          )}
          {activeTab === 'study' && (
            <StudyView
              activeFilter={studyFilter}
              activeInitial={studyInitial}
              activeLevel={studyLevel}
              filtersOpen={studyFiltersOpen}
              levelOptions={levelFilterOptions}
              motionStyle={cardMotionStyle}
              studyMode={studyMode}
              activeSetCount={activeStudySet ? studySourceWords.length : 0}
              activeSetName={activeStudySet?.name ?? null}
              wordCount={studyWords.length}
              word={studyWord}
              progress={progress}
              onClearActiveSet={() => setStudySetId(null)}
              onFilterChange={setStudyFilter}
              onFiltersToggle={() => setStudyFiltersOpen((current) => !current)}
              onInitialChange={setStudyInitial}
              onKnown={() => studyWord && handleKnown(studyWord.id)}
              onLevelChange={setStudyLevel}
              onReview={() => studyWord && handleReview(studyWord.id)}
              onAddToSet={handleOpenSetPicker}
              onFavorite={() => studyWord && setProgress((current) => toggleFavorite(current, studyWord.id))}
            />
          )}
          {activeTab === 'quiz' && (
            <QuizView
              activeFilter={quizFilter}
              activeInitial={quizInitial}
              activeLevel={quizLevel}
              filtersOpen={quizFiltersOpen}
              levelOptions={levelFilterOptions}
              motionStyle={cardMotionStyle}
              conversationPrompt={conversationPrompt}
              options={visibleQuizOptions}
              practiceMode={quizPracticeMode}
              questionCount={quizQuestionCount}
              questionCounts={quizQuestionCounts}
              questionIndex={quizIndex}
              quizFinished={quizFinished}
              quizStarted={quizStarted}
              result={quizResult}
              sessionTotal={quizSessionTotal}
              speakingAnswerVisible={speakingAnswerVisible}
              studyMode={studyMode}
              activeSetCount={activeQuizSet ? quizSourceWords.length : 0}
              activeSetName={activeQuizSet?.name ?? null}
              correctCount={quizCorrectCount}
              word={visibleQuizWord}
              wordCount={quizWords.length}
              onAnswer={handleQuizAnswer}
              onClearActiveSet={() => setQuizSetId(null)}
              onFilterChange={setQuizFilter}
              onFiltersToggle={() => setQuizFiltersOpen((current) => !current)}
              onInitialChange={setQuizInitial}
              onLevelChange={setQuizLevel}
              onPracticeModeChange={handleQuizPracticeModeChange}
              onNext={nextQuiz}
              onQuestionCountChange={setQuizQuestionCount}
              onRevealSpeakingAnswer={revealSpeakingAnswer}
              onRestart={restartQuiz}
              onStart={startQuiz}
            />
          )}
          {activeTab === 'library' && (
            <Animated.View
              pointerEvents={libraryPanel === 'list' && renderedLibraryPanel === 'list' ? 'auto' : 'none'}
              style={libraryListPanelMotionStyle}
              testID="library-panel-transition"
            >
              <LibraryView
                activeFilter={activeFilter}
                activeInitial={activeInitial}
                activeLevel={activeLevel}
                activeSort={activeSort}
                customSets={sortedCustomSets}
                filtersOpen={libraryFiltersOpen}
                itemExtent={libraryItemExtent}
                levelOptions={levelFilterOptions}
                listMotionStyle={listMotionStyle}
                progress={progress}
                query={searchQuery}
                searchFocused={searchFocused}
                studyMode={studyMode}
                visibleStart={libraryWindowStart}
                visibleWindowSize={LIBRARY_WINDOW_SIZE}
                words={libraryWords}
                onAddToSet={handleOpenSetPicker}
                onFilterChange={setActiveFilter}
                onFiltersToggle={handleLibraryFiltersToggle}
                onFavorite={handleLibraryFavorite}
                onInitialChange={setActiveInitial}
                onFirstItemLayout={handleLibraryFirstItemLayout}
                onListLayout={handleLibraryListLayout}
                onLevelChange={setActiveLevel}
                onOpenWord={openLibraryWordDetail}
                onOpenCustomSets={openLibraryCustomSets}
                onQueryChange={handleLibraryQueryChange}
                onQueryClear={clearLibrarySearch}
                onSearchBlur={handleLibrarySearchBlur}
                onSearchFocus={handleLibrarySearchFocus}
                onSortChange={setActiveSort}
              />
            </Animated.View>
          )}
          {activeTab === 'profile' && (
            <ProfileView
              account={account}
              dailyPercent={dailyPercent}
              developerMessage={developerVocabularyMessage}
              developerVocabulary={developerVocabulary}
              panel={profilePanel}
              progress={progress}
              stats={stats}
              studyMode={studyMode}
              themeMode={themeMode}
              vocabularyCount={vocabularyWords.length}
              onClearDeveloperVocabulary={handleClearDeveloperVocabulary}
              onCloseSettings={() => setProfilePanel('overview')}
              onConfirmDeleteAccountData={confirmDeleteAccountData}
              onEmailChange={(email) => setAccount((current) => ({ ...current, email }))}
              onExportVocabulary={handleExportVocabulary}
              onImportVocabulary={handleImportVocabulary}
              onAppleSignIn={handleAppleSignIn}
              onGoogleSignIn={handleGoogleSignIn}
              onOpenSettings={() => setProfilePanel('settings')}
              onOpenAppInfoLink={handleOpenAppInfoLink}
              onPanelSwap={onProfilePanelSwap}
              onPasswordChange={(password) => setAccount((current) => ({ ...current, password }))}
              onShowInstallGuide={openInstallGuide}
              onSignIn={handleSignIn}
              onSignOut={handleSignOut}
              onSignUp={handleSignUp}
              onThemeModeChange={triggerThemeModeChange}
            />
          )}
          </Animated.View>
        </ScrollView>

        {activeTab === 'library' && libraryPanel === 'list' && renderedLibraryPanel === 'list' && !selectedLibraryWord && (
          <View pointerEvents="box-none" style={styles.libraryFixedControls}>
            {scrollY > 180 && (
              <AnimatedPressable
                accessibilityRole="button"
                onPress={returnLibraryToTop}
                pressTone="secondary"
                style={[styles.libraryFloatingTopButton, themeStyles?.libraryFloatingTopButton]}
                testID="library-floating-top"
              >
                <ArrowUp size={15} color={libraryDragIconColor} strokeWidth={2.5} />
                <Text style={[styles.libraryFloatingTopText, themeStyles?.libraryFloatingTopText]}>{modeInterfaceCopy[studyMode].floatingTop}</Text>
              </AnimatedPressable>
            )}
            {librarySliderVisible && (
              <View
                {...librarySliderResponder.panHandlers}
                onLayout={(event) => setSliderTrackHeight(event.nativeEvent.layout.height)}
                style={[
                  styles.libraryDragSlider,
                  themeStyles?.libraryDragSlider,
                  librarySliderActive ? styles.libraryDragSliderActive : styles.libraryDragSliderCollapsed,
                  librarySliderActive ? themeStyles?.libraryDragSliderActive : themeStyles?.libraryDragSliderCollapsed,
                  libraryDragSliderMotionStyle,
                ]}
                testID="library-drag-slider"
              >
                <View
                  style={[
                    styles.libraryDragTrack,
                    themeStyles?.libraryDragTrack,
                    librarySliderActive ? styles.libraryDragTrackActive : styles.libraryDragTrackCollapsed,
                    librarySliderActive ? themeStyles?.libraryDragTrackActive : themeStyles?.libraryDragTrackCollapsed,
                    libraryDragTrackMotionStyle,
                  ]}
                />
                <View
                  style={[
                    styles.libraryDragThumb,
                    themeStyles?.libraryDragThumb,
                    librarySliderActive ? styles.libraryDragThumbActive : styles.libraryDragThumbCollapsed,
                    librarySliderActive ? themeStyles?.libraryDragThumbActive : themeStyles?.libraryDragThumbCollapsed,
                    libraryDragThumbMotionStyle,
                    { transform: [{ translateY: libraryThumbOffset }] },
                  ]}
                  testID="library-drag-thumb"
                >
                  {librarySliderActive && (
                    <GripVertical size={17} color={libraryDragIconColor} strokeWidth={2.4} />
                  )}
                </View>
              </View>
            )}
          </View>
        )}

        {activeTab === 'library' && selectedLibraryWord && (
          <Animated.View
            pointerEvents={renderedLibraryPanel === 'detail' ? 'auto' : 'none'}
            style={[
              styles.libraryDetailStage,
              themeStyles?.libraryDetailStage,
              { top: headerHeight },
              libraryDetailStageMotionStyle,
            ]}
            testID="library-detail-stage"
          >
            <ScrollView contentContainerStyle={styles.libraryDetailStageContent} showsVerticalScrollIndicator={false}>
              <LibraryWordDetailView
                progress={progress}
                studyMode={studyMode}
                word={selectedLibraryWord}
                onAddToSet={handleOpenSetPicker}
                onBack={closeLibraryWordDetail}
                onFavorite={() => setProgress((current) => toggleFavorite(current, selectedLibraryWord.id))}
              />
            </ScrollView>
          </Animated.View>
        )}

        {activeTab === 'library' && (
          <Animated.View
            pointerEvents={renderedLibraryPanel === 'sets' ? 'auto' : 'none'}
            style={[
              styles.libraryDetailStage,
              themeStyles?.libraryDetailStage,
              { top: headerHeight },
              librarySetsStageMotionStyle,
            ]}
            testID="library-custom-sets-stage"
          >
            <ScrollView contentContainerStyle={styles.libraryDetailStageContent} showsVerticalScrollIndicator={false}>
              <ProfileCustomSetsView
                backLabel={modeInterfaceCopy[studyMode].backLibrary}
                customSetMessage={customSetMessage}
                customSetSort={customSetSort}
                customSets={sortedCustomSets}
                customSetState={customSetState}
                manualCustomWord={manualCustomWord}
                newSetName={newSetName}
                selectedCustomSetId={selectedCustomSetId}
                studyMode={studyMode}
                vocabularyWords={vocabularyWords}
                onAddManualCustomWord={handleAddManualCustomWord}
                onBack={() => {
                  setLibraryPanel('list');
                }}
                onCreateCustomSet={handleCreateCustomSet}
                onCustomSetSelect={setSelectedCustomSetId}
                onCustomSetSortChange={setCustomSetSort}
                onDeleteCustomSet={handleDeleteCustomSet}
                onImportCustomWords={handleImportCustomWords}
                onManualCustomWordChange={handleManualCustomWordChange}
                onNewSetNameChange={setNewSetName}
                onRemoveWordFromSet={handleRemoveWordFromCustomSet}
                onRenameCustomSet={handleRenameCustomSet}
                onStartQuizSet={handleStartQuizSet}
                onStartStudySet={handleStartStudySet}
              />
            </ScrollView>
          </Animated.View>
        )}

        {setPickerWord && (
          <CustomSetPickerOverlay
            customSets={sortedCustomSets}
            newSetName={newSetName}
            studyMode={studyMode}
            word={setPickerWord}
            onAddToSet={handleAddPickerWordToSet}
            onClose={handleCloseSetPicker}
            onCreateAndAdd={handleCreateSetAndAddPickerWord}
            onNewSetNameChange={setNewSetName}
          />
        )}

        <View style={[styles.tabBar, themeStyles?.tabBar]}>
          {tabs.map((tab) => {
            const Icon = tab.icon;
            const selected = activeTab === tab.id;
            const tabIconColor = selected ? (darkMode ? '#f8fafc' : '#172033') : darkMode ? '#94a3b8' : '#717987';
            return (
              <AnimatedPressable
                accessibilityRole="button"
                key={tab.id}
                onPress={() => setActiveTab(tab.id)}
                pressTone="tab"
                style={[styles.tabButton, selected && styles.tabButtonActive, selected && themeStyles?.tabButtonActive]}
              >
                <Icon size={18} color={tabIconColor} strokeWidth={2.2} />
                <Text style={[styles.tabLabel, themeStyles?.tabLabel, selected && styles.tabLabelActive, selected && themeStyles?.tabLabelActive]}>
                  {tabLabelForMode(tab.id, studyMode)}
                </Text>
              </AnimatedPressable>
            );
          })}
        </View>

        {showModeSwitch && (
          <ModeSwitchOverlay
            mode={modeSwitchTarget}
            opacity={modeTransitionAnim}
            scale={modeOverlayScale}
            translateY={modeOverlayTranslateY}
          />
        )}

        {showLaunch && (
          <Animated.View
            pointerEvents="none"
            style={[styles.launchOverlay, { opacity: launchOpacity, transform: [{ scale: launchScale }] }]}
            testID="launch-overlay"
          >
            <View style={styles.launchIcon}>
              <View style={styles.launchDot} />
              <Text style={styles.launchIconText}>W7</Text>
            </View>
            <Text style={styles.launchTitle}>{activeModeCopy.brand}</Text>
            <Text style={styles.launchText}>{activeModeCopy.subtitle}</Text>
            <View style={styles.launchBar}>
              <Animated.View style={[styles.launchBarFill, { width: launchProgressWidth }]} />
            </View>
          </Animated.View>
        )}
        {showInstallGuide && (
          <InstallGuideOverlay
            copy={activeSystemCopy.installGuide}
            opacity={installGuideOpacity}
            step={installGuideStep}
            steps={activeInstallGuideSteps}
            translateY={installGuideTranslateY}
            onDismiss={dismissInstallGuide}
            onNext={nextInstallGuideStep}
          />
        )}
        {showThemeTransition && (
          <Animated.View
            pointerEvents="none"
            style={[styles.themeTransitionOverlay, themeTransitionMotionStyle]}
            testID="theme-transition-overlay"
          />
        )}
        {updateState.available && (
          <UpdateRequiredOverlay
            buttonText={updateState.buttonText}
            countdownText={updateState.countdownText}
            detail={updateState.detail}
            message={updateState.message}
            onRefresh={updateState.refresh}
          />
        )}
      </View>
    </SafeAreaView>
    </ThemeContext.Provider>
  );
}

function useWebServiceWorker() {
  useEffect(() => {
    const webNavigator = globalThis.navigator as
      | undefined
      | {
          serviceWorker?: {
            register: (scriptUrl: string) => Promise<unknown>;
          };
        };
    const serviceWorker = webNavigator?.serviceWorker;

    if (Platform.OS !== 'web' || !serviceWorker) {
      return;
    }

    serviceWorker.register('/service-worker.js').catch(() => undefined);
  }, []);
}

function AppStorageBootScreen() {
  return (
    <SafeAreaView style={styles.safeArea}>
      <View style={styles.appStorageBootScreen}>
        <View style={styles.launchIcon}>
          <View style={styles.launchDot} />
          <Text style={styles.launchIconText}>W7</Text>
        </View>
        <Text style={styles.appStorageBootTitle}>Word7000</Text>
        <Text style={styles.appStorageBootText}>Preparing your learning memory...</Text>
      </View>
    </SafeAreaView>
  );
}

function useAppUpdateCheck(studyMode: StudyMode): UpdateState {
  const [available, setAvailable] = useState(false);
  const [countdownSeconds, setCountdownSeconds] = useState(Math.ceil(UPDATE_AUTO_REFRESH_MS / 1000));
  const [latestVersion, setLatestVersion] = useState<string | null>(null);
  const copy = systemCopy[studyMode];

  const refresh = useCallback(() => {
    if (Platform.OS !== 'web') {
      import('expo-updates')
        .then((updates) => updates.reloadAsync())
        .catch(() => undefined);
      return;
    }

    const storage = getAppStorage();
    if (latestVersion) {
      storage?.setItem(UPDATE_STORAGE_KEY, latestVersion);
    }
    (globalThis as { location?: { reload: () => void } }).location?.reload();
  }, [latestVersion]);

  useEffect(() => {
    if (Platform.OS !== 'web') {
      return;
    }

    let cancelled = false;

    async function checkVersion() {
      try {
        const response = await fetch(`/version.json?t=${Date.now()}`, {
          cache: 'no-store',
        });
        const data: unknown = await response.json();
        const version = typeof (data as { version?: unknown }).version === 'string' ? (data as { version: string }).version : '';
        const storage = getAppStorage();
        const storedVersion = storage?.getItem(UPDATE_STORAGE_KEY);

        if (!version || cancelled) {
          return;
        }

        if (!storedVersion) {
          storage?.setItem(UPDATE_STORAGE_KEY, version);
          return;
        }

        if (storedVersion !== version) {
          setLatestVersion(version);
          setCountdownSeconds(Math.ceil(UPDATE_AUTO_REFRESH_MS / 1000));
          setAvailable(true);
        }
      } catch {
        // Version checks should never block studying.
      }
    }

    checkVersion();
    const interval = setInterval(checkVersion, UPDATE_CHECK_INTERVAL_MS);

    const visibilityDocument = (globalThis as { document?: Document }).document;
    const handleVisibility = () => {
      if (visibilityDocument?.visibilityState === 'visible') {
        checkVersion();
      }
    };
    visibilityDocument?.addEventListener?.('visibilitychange', handleVisibility);

    return () => {
      cancelled = true;
      clearInterval(interval);
      visibilityDocument?.removeEventListener?.('visibilitychange', handleVisibility);
    };
  }, []);

  useEffect(() => {
    if (Platform.OS === 'web') {
      return;
    }

    let cancelled = false;

    async function checkNativeUpdate() {
      try {
        const updates = await import('expo-updates');
        if (!updates.isEnabled) {
          return;
        }

        const update = await updates.checkForUpdateAsync();
        if (!update.isAvailable || cancelled) {
          return;
        }

        await updates.fetchUpdateAsync();
        if (cancelled) {
          return;
        }

        setCountdownSeconds(Math.ceil(UPDATE_AUTO_REFRESH_MS / 1000));
        setAvailable(true);
      } catch {
        // Native update checks should never block studying.
      }
    }

    checkNativeUpdate();

    return () => {
      cancelled = true;
    };
  }, []);

  useEffect(() => {
    if (!available) {
      return;
    }

    const countdown = setInterval(() => {
      setCountdownSeconds((current) => Math.max(1, current - 1));
    }, 1000);
    const autoRefresh = setTimeout(refresh, UPDATE_AUTO_REFRESH_MS);

    return () => {
      clearInterval(countdown);
      clearTimeout(autoRefresh);
    };
  }, [available, refresh]);

  return {
    available,
    buttonText: copy.updateNow,
    countdownSeconds,
    countdownText: copy.updateCountdown(countdownSeconds),
    detail: copy.updateDetail,
    message: copy.updateTitle,
    refresh,
  };
}

function loadThemeMode(storage?: StorageLike): ThemeMode {
  try {
    return storage?.getItem(THEME_STORAGE_KEY) === 'dark' ? 'dark' : 'light';
  } catch {
    return 'light';
  }
}

function saveThemeMode(storage: StorageLike | undefined, themeMode: ThemeMode) {
  try {
    storage?.setItem(THEME_STORAGE_KEY, themeMode);
  } catch {
    // Theme choice is a convenience; keep the app usable if storage is blocked.
  }
}

function loadStudyMode(storage?: StorageLike): StudyMode {
  try {
    return storage?.getItem(STUDY_MODE_STORAGE_KEY) === 'chinese' ? 'chinese' : 'english';
  } catch {
    return 'english';
  }
}

function saveStudyMode(storage: StorageLike | undefined, studyMode: StudyMode) {
  try {
    storage?.setItem(STUDY_MODE_STORAGE_KEY, studyMode);
  } catch {
    // Study mode should still be usable for the current session if storage is blocked.
  }
}

function loadCustomSetSort(storage?: StorageLike): CustomSetSort {
  try {
    const stored = storage?.getItem(CUSTOM_SET_SORT_STORAGE_KEY);
    return stored === 'manual' || stored === 'name' || stored === 'recent' ? stored : 'recent';
  } catch {
    return 'recent';
  }
}

function saveCustomSetSort(storage: StorageLike | undefined, sort: CustomSetSort) {
  try {
    storage?.setItem(CUSTOM_SET_SORT_STORAGE_KEY, sort);
  } catch {
    // Custom set sorting is a convenience; keep studying available if storage is blocked.
  }
}

function useThemeStyles() {
  return useContext(ThemeContext) === 'dark' ? darkStyles : undefined;
}

function formatWordPrimary(word: WordEntry, studyMode: StudyMode): string {
  return studyMode === 'chinese' ? conciseChineseMeaning(word.meaningZh) : word.word;
}

function formatWordSecondary(word: WordEntry, studyMode: StudyMode): string {
  return studyMode === 'chinese' ? `${word.word} ${word.pronunciation}` : word.pronunciation;
}

function formatWordPinyin(word: WordEntry, studyMode: StudyMode): string {
  return studyMode === 'chinese' ? chineseMeaningPinyin(conciseChineseMeaning(word.meaningZh)) : '';
}

function formatMeaningDetail(word: WordEntry, studyMode: StudyMode): string {
  return studyMode === 'chinese' ? word.word : word.meaningZh;
}

function formatMeaningSupplement(word: WordEntry, studyMode: StudyMode): string {
  return studyMode === 'chinese' ? supplementalChineseMeaning(word.meaningZh) : '';
}

function formatExamplePrimary(word: WordEntry, studyMode: StudyMode): string {
  return studyMode === 'chinese' ? word.exampleZh : word.example;
}

function formatExampleSecondary(word: WordEntry, studyMode: StudyMode): string {
  return studyMode === 'chinese' ? word.example : word.exampleZh;
}

function formatQuizAnswer(word: WordEntry, studyMode: StudyMode): string {
  return studyMode === 'chinese' ? word.word : word.meaningZh;
}

function tabLabelForMode(tab: Tab, studyMode: StudyMode): string {
  if (studyMode !== 'chinese') {
    return tabs.find((item) => item.id === tab)?.label ?? '';
  }

  const englishTabLabels: Record<Tab, string> = {
    home: 'Home',
    study: 'Chinese',
    quiz: 'Quiz',
    library: 'Library',
    profile: 'Me',
  };
  return englishTabLabels[tab];
}

function getBrowserLocation(): Location | undefined {
  if (Platform.OS !== 'web') {
    return undefined;
  }

  return (globalThis as { location?: Location }).location;
}

function getOAuthRedirectUrl(): string | undefined {
  return Platform.OS === 'web' ? authRedirectTo(getBrowserLocation()) : nativeAuthRedirectTo(APP_LINKING_SCHEME);
}

function downloadTextFile(fileName: string, text: string, type: string): boolean {
  const browser = globalThis as {
    Blob?: typeof Blob;
    URL?: typeof URL;
    document?: Document;
  };

  if (Platform.OS !== 'web' || !browser.document || !browser.Blob || !browser.URL) {
    return false;
  }

  const url = browser.URL.createObjectURL(new browser.Blob([text], { type }));
  const link = browser.document.createElement('a');
  link.href = url;
  link.download = fileName;
  browser.document.body.appendChild(link);
  link.click();
  link.remove();
  browser.URL.revokeObjectURL(url);
  return true;
}

function pickVocabularyTextFile(copy: Pick<SystemCopy, 'importNoFile' | 'importReadFailed' | 'importUnsupported'>): Promise<
  { fileName: string; ok: true; text: string } | { message: string; ok: false }
> {
  const documentRef = (globalThis as { document?: Document }).document;
  if (Platform.OS !== 'web' || !documentRef) {
    return Promise.resolve({ message: copy.importUnsupported, ok: false });
  }

  return new Promise((resolve) => {
    const input = documentRef.createElement('input');
    input.accept = '.csv,.json,text/csv,application/json';
    input.type = 'file';
    input.style.display = 'none';
    input.onchange = async () => {
      const file = input.files?.[0];
      input.remove();
      if (!file) {
        resolve({ message: copy.importNoFile, ok: false });
        return;
      }

      try {
        resolve({ fileName: file.name, ok: true, text: await file.text() });
      } catch {
        resolve({ message: copy.importReadFailed, ok: false });
      }
    };
    documentRef.body.appendChild(input);
    input.click();
  });
}

function isInstalledWebApp(): boolean {
  if (Platform.OS !== 'web') {
    return true;
  }

  const browserWindow = globalThis as {
    matchMedia?: (query: string) => { matches: boolean };
    navigator?: { standalone?: boolean };
  };

  return Boolean(browserWindow.navigator?.standalone || browserWindow.matchMedia?.('(display-mode: standalone)').matches);
}

function asCloudProgressClient(client: AppSupabaseClient): CloudProgressClient {
  return client as unknown as CloudProgressClient;
}

function createInitialAccountState(configured: boolean): AccountState {
  return {
    configured,
    email: '',
    password: '',
    userId: null,
    userEmail: null,
    busy: false,
    status: configured ? 'signedOut' : 'local',
    message: configured ? '未登入' : '本機記憶中',
  };
}

type AnimatedPressableProps = Omit<PressableProps, 'children' | 'style'> & {
  children: ReactNode;
  pressTone?: InteractionTone;
  pressedStyle?: StyleProp<ViewStyle>;
  style?: StyleProp<ViewStyle>;
};
type WebTransitionStyle = ViewStyle & {
  transitionDuration?: string;
  transitionProperty?: string;
  transitionTimingFunction?: string;
  transformOrigin?: string;
  willChange?: string;
};

function AnimatedPressable({
  children,
  disabled,
  onPressIn,
  onPressOut,
  pressTone = 'secondary',
  pressedStyle,
  style,
  ...props
}: AnimatedPressableProps) {
  const [pressed, setPressed] = useState(false);
  const pressAnim = useRef(new Animated.Value(0)).current;
  const pressMotion = pressMotionFor(pressTone);
  const pressStyle = {
    opacity: pressAnim.interpolate({
      inputRange: [0, 1],
      outputRange: [1, pressMotion.pressedOpacity],
    }),
    transform: [
      {
        scale: pressAnim.interpolate({
          inputRange: [0, 1],
          outputRange: [1, pressMotion.pressedScale],
        }),
      },
      {
        translateY: pressAnim.interpolate({
          inputRange: [0, 1],
          outputRange: [0, pressMotion.pressedTranslateY],
        }),
      },
    ],
  };

  function animatePress(toValue: number, duration: number) {
    Animated.timing(pressAnim, {
      duration,
      easing: Easing.out(Easing.cubic),
      toValue,
      useNativeDriver: Platform.OS !== 'web',
    }).start();
  }

  function handlePressIn(event: Parameters<NonNullable<PressableProps['onPressIn']>>[0]) {
    if (!disabled) {
      setPressed(true);
      animatePress(1, interactionMotion.pressInMs);
    }
    onPressIn?.(event);
  }

  function handlePressOut(event: Parameters<NonNullable<PressableProps['onPressOut']>>[0]) {
    if (!disabled) {
      setPressed(false);
      animatePress(0, interactionMotion.releaseMs);
    }
    onPressOut?.(event);
  }

  return (
    <MotionPressable
      {...props}
      disabled={disabled}
      onPressIn={handlePressIn}
      onPressOut={handlePressOut}
      style={[style, pressed && !disabled && pressedStyle, !disabled && pressStyle]}
    >
      {children}
    </MotionPressable>
  );
}

function AnimatedFilterPanel({ children, open, testID }: { children: ReactNode; open: boolean; testID: string }) {
  const themeStyles = useThemeStyles();
  const [filterPanelMeasuredHeight, setFilterPanelMeasuredHeight] = useState(0);
  const panelAnim = useRef(new Animated.Value(open ? 1 : 0)).current;

  useEffect(() => {
    if (Platform.OS === 'web') {
      return;
    }

    Animated.timing(panelAnim, {
      duration: open ? interactionMotion.panelMs : interactionMotion.panelCloseMs,
      easing: open ? Easing.out(Easing.cubic) : Easing.out(Easing.cubic),
      toValue: open ? 1 : 0,
      useNativeDriver: false,
    }).start();
  }, [open, panelAnim]);

  function handlePanelContentLayout(event: LayoutChangeEvent) {
    const nextHeight = Math.ceil(event.nativeEvent.layout.height);
    if (nextHeight > 0 && Math.abs(nextHeight - filterPanelMeasuredHeight) > 1) {
      setFilterPanelMeasuredHeight(nextHeight);
    }
  }

  const measuredHeight = Math.max(filterPanelMeasuredHeight, interactionMotion.panelCollapsedHeight);
  const filterPanelWebTransition: WebTransitionStyle | undefined =
    Platform.OS === 'web'
      ? {
          transitionDuration: `${open ? interactionMotion.panelMs : interactionMotion.panelCloseMs}ms`,
          transitionProperty: 'height, opacity, border-top-width, transform',
          transitionTimingFunction: open ? 'cubic-bezier(0.22, 1, 0.36, 1)' : 'cubic-bezier(0.4, 0, 0.2, 1)',
        }
      : undefined;
  const panelMotionStyle =
    Platform.OS === 'web'
      ? {
          borderTopWidth: open && measuredHeight > 0 ? 1 : 0,
          height: open ? measuredHeight : interactionMotion.panelCollapsedHeight,
          opacity: open ? 1 : 0,
        }
      : {
          borderTopWidth: panelAnim.interpolate({
            inputRange: [0, 1],
            outputRange: [0, 1],
          }),
          height: panelAnim.interpolate({
            inputRange: [0, 1],
            outputRange: [interactionMotion.panelCollapsedHeight, measuredHeight],
          }),
          opacity: panelAnim.interpolate({
            inputRange: [0, 0.24, 1],
            outputRange: [0, 0.72, 1],
          }),
        };
  const contentMotionStyle =
    Platform.OS === 'web'
      ? {
          opacity: open ? 1 : 0,
          transform: [{ translateY: open ? 0 : -6 }, { scale: open ? 1 : 0.985 }],
        }
      : {
          opacity: panelAnim.interpolate({
            inputRange: [0, 0.18, 1],
            outputRange: [0, 0.65, 1],
          }),
          transform: [
            {
              translateY: panelAnim.interpolate({
                inputRange: [0, 1],
                outputRange: [-6, 0],
              }),
            },
            {
              scale: panelAnim.interpolate({
                inputRange: [0, 1],
                outputRange: [0.985, 1],
              }),
            },
          ],
        };

  return (
    <Animated.View
      pointerEvents={open ? 'auto' : 'none'}
      style={[styles.filterPanel, themeStyles?.filterPanel, filterPanelWebTransition, panelMotionStyle]}
      testID={testID}
    >
      <Animated.View onLayout={handlePanelContentLayout} style={[styles.filterPanelContent, filterPanelWebTransition, contentMotionStyle]}>
        {children}
      </Animated.View>
    </Animated.View>
  );
}

function UpdateRequiredOverlay({
  buttonText,
  countdownText,
  detail,
  message,
  onRefresh,
}: {
  buttonText: string;
  countdownText: string;
  detail: string;
  message: string;
  onRefresh: () => void;
}) {
  const themeStyles = useThemeStyles();
  const darkMode = useContext(ThemeContext) === 'dark';
  const iconColor = darkMode ? '#bfdbfe' : '#2563eb';

  return (
    <View style={[styles.updateRequiredOverlay, themeStyles?.updateRequiredOverlay]} testID="force-update-overlay">
      <View style={[styles.updateRequiredCard, themeStyles?.updateRequiredCard]}>
        <View style={[styles.updateRequiredIcon, themeStyles?.updateRequiredIcon]}>
          <Cloud size={30} color={iconColor} strokeWidth={2.4} />
        </View>
        <Text style={[styles.updateRequiredTitle, themeStyles?.updateRequiredTitle]}>{message}</Text>
        <Text style={[styles.updateRequiredText, themeStyles?.updateRequiredText]}>{detail}</Text>
        <Text style={[styles.updateRequiredCountdown, themeStyles?.updateRequiredCountdown]}>{countdownText}</Text>
        <AnimatedPressable accessibilityRole="button" onPress={onRefresh} pressTone="primary" style={styles.updateRequiredButton}>
          <RotateCcw size={17} color="#fff" strokeWidth={2.4} />
          <Text style={styles.updateRequiredButtonText}>{buttonText}</Text>
        </AnimatedPressable>
      </View>
    </View>
  );
}

function ModeSwitchOverlay({
  mode,
  opacity,
  scale,
  translateY,
}: {
  mode: StudyMode;
  opacity: Animated.Value;
  scale: Animated.AnimatedInterpolation<number>;
  translateY: Animated.AnimatedInterpolation<number>;
}) {
  const copy = modeCopy[mode];
  const chineseMode = mode === 'chinese';

  return (
    <Animated.View
      pointerEvents="none"
      style={[
        styles.modeSwitchBackdrop,
        chineseMode && styles.modeSwitchOverlayChinese,
        {
          opacity,
        },
      ]}
      testID="mode-switch-overlay"
    >
      <Animated.View
        style={[
          styles.modeSwitchPanel,
          chineseMode && styles.modeSwitchPanelChinese,
          {
            transform: [{ scale }, { translateY }],
          },
        ]}
      >
        <View style={[styles.modeSwitchOverlayIcon, chineseMode && styles.modeSwitchOverlayIconChinese]}>
          <Languages size={34} color={chineseMode ? '#0f766e' : '#2563eb'} strokeWidth={2.5} />
        </View>
        <Text style={styles.modeSwitchOverlayTitle}>{copy.overlayTitle}</Text>
        <Text style={styles.modeSwitchOverlayText}>{copy.overlayText}</Text>
      </Animated.View>
    </Animated.View>
  );
}

function InstallGuideOverlay({
  copy,
  opacity,
  step,
  steps,
  translateY,
  onDismiss,
  onNext,
}: {
  copy: SystemCopy['installGuide'];
  opacity: Animated.Value;
  step: number;
  steps: readonly InstallGuideStep[];
  translateY: Animated.AnimatedInterpolation<number>;
  onDismiss: () => void;
  onNext: () => void;
}) {
  const current = steps[step] ?? steps[0];
  const isLastStep = step >= steps.length - 1;
  const themeStyles = useThemeStyles();
  const darkMode = useContext(ThemeContext) === 'dark';
  const installGuideIconColor = darkMode ? '#60a5fa' : '#2563eb';
  const installGuideCloseIconColor = darkMode ? '#e2e8f0' : '#172033';
  const installGuideStepProgress = useRef(new Animated.Value(1)).current;

  useEffect(() => {
    installGuideStepProgress.setValue(0);
    Animated.timing(installGuideStepProgress, {
      duration: interactionMotion.guideStepMs,
      easing: Easing.out(Easing.cubic),
      toValue: 1,
      useNativeDriver: Platform.OS !== 'web',
    }).start();
  }, [installGuideStepProgress, step]);

  const stepMotionStyle = {
    opacity: installGuideStepProgress,
    transform: [
      {
        translateY: installGuideStepProgress.interpolate({
          inputRange: [0, 1],
          outputRange: [10, 0],
        }),
      },
      {
        scale: installGuideStepProgress.interpolate({
          inputRange: [0, 1],
          outputRange: [0.96, 1],
        }),
      },
    ],
  };

  return (
    <Animated.View
      style={[styles.installGuideOverlay, themeStyles?.installGuideOverlay, { opacity, transform: [{ translateY }] }]}
      testID="install-guide-overlay"
    >
      <View style={styles.installGuideTopBar}>
        <View style={[styles.installGuideLogo, themeStyles?.installGuideLogo]}>
          <View style={styles.installGuideLogoDot} />
          <Text style={styles.installGuideLogoText}>W7</Text>
        </View>
        <AnimatedPressable
          accessibilityLabel={copy.closeAccessibility}
          accessibilityRole="button"
          onPress={onDismiss}
          pressTone="icon"
          style={[styles.installGuideClose, themeStyles?.installGuideClose]}
        >
          <X size={18} color={installGuideCloseIconColor} strokeWidth={2.4} />
        </AnimatedPressable>
      </View>

      <View style={styles.installGuideMain}>
        <View style={[styles.installGuideCard, themeStyles?.installGuideCard]}>
          <View style={[styles.installGuideStepPill, themeStyles?.installGuideStepPill]}>
            <Text style={[styles.installGuideStepText, themeStyles?.installGuideStepText]}>
              {step + 1} / {steps.length}
            </Text>
          </View>
          <Animated.View style={[styles.installGuideIconWrap, themeStyles?.installGuideIconWrap, stepMotionStyle]}>
            <Animated.View
              pointerEvents="none"
              style={[
                styles.installGuideIconGlow,
                themeStyles?.installGuideIconGlow,
                {
                  opacity: installGuideStepProgress,
                  transform: [
                    {
                      scale: installGuideStepProgress.interpolate({
                        inputRange: [0, 1],
                        outputRange: [0.82, 1.08],
                      }),
                    },
                  ],
                },
              ]}
            />
            <View style={styles.installGuideIconGraphic}>
              <InstallGuideStepIcon icon={current.icon} color={installGuideIconColor} />
            </View>
          </Animated.View>
          <Animated.View style={[styles.installGuideCopyBlock, stepMotionStyle]}>
            <Text style={[styles.installGuideTitle, themeStyles?.installGuideTitle]}>{current.title}</Text>
            <Text style={[styles.installGuideText, themeStyles?.installGuideText]}>{current.text}</Text>
          </Animated.View>

          <View style={[styles.installGuidePreview, themeStyles?.installGuidePreview]}>
            <View style={[styles.installGuideBrowserBar, themeStyles?.installGuideBrowserBar]} />
            <View style={styles.installGuidePreviewRow}>
              {steps.map((item, index) => (
                <Animated.View
                  key={item.title}
                  style={[
                    styles.installGuideMiniStep,
                    themeStyles?.installGuideMiniStep,
                    index <= step && styles.installGuideMiniStepActive,
                    index === step && styles.installGuideStepProgress,
                  ]}
                >
                  <Text style={[styles.installGuideMiniText, themeStyles?.installGuideMiniText, index <= step && styles.installGuideMiniTextActive]}>
                    {index + 1}
                  </Text>
                </Animated.View>
              ))}
            </View>
          </View>
        </View>

        <View style={styles.installGuideDots}>
          {steps.map((item, index) => (
            <View key={item.title} style={[styles.installGuideDot, themeStyles?.installGuideDot, index === step && styles.installGuideDotActive]} />
          ))}
        </View>
      </View>

      <View style={styles.installGuideActions}>
        <AnimatedPressable accessibilityRole="button" onPress={onDismiss} pressTone="secondary" style={[styles.installGuideSecondary, themeStyles?.installGuideSecondary]}>
          <Text style={[styles.installGuideSecondaryText, themeStyles?.installGuideSecondaryText]}>{copy.dismiss}</Text>
        </AnimatedPressable>
        <AnimatedPressable accessibilityRole="button" onPress={onNext} pressTone="primary" style={[styles.installGuidePrimary, themeStyles?.installGuidePrimary]}>
          <Text style={styles.installGuidePrimaryText}>{isLastStep ? copy.done : copy.next}</Text>
          <ChevronRight size={18} color="#fff" strokeWidth={2.5} />
        </AnimatedPressable>
      </View>
    </Animated.View>
  );
}

function InstallGuideStepIcon({ color, icon }: { color: string; icon: InstallGuideStep['icon'] }) {
  if (icon === 'safari') {
    return <Compass size={56} color={color} strokeWidth={2.1} />;
  }
  if (icon === 'share') {
    return <SquareArrowUp size={56} color={color} strokeWidth={2.1} />;
  }
  if (icon === 'add') {
    return <SquarePlus size={56} color={color} strokeWidth={2.1} />;
  }
  return <Smartphone size={56} color={color} strokeWidth={2.1} />;
}

function HomeView({
  dailyPercent,
  progress,
  stats,
  studyMode,
  onOpenAccount,
  onOpenReview,
  onStartStudy,
  onToggleStudyMode,
}: {
  dailyPercent: number;
  progress: ProgressState;
  stats: ReturnType<typeof computeStats>;
  studyMode: StudyMode;
  onOpenAccount: () => void;
  onOpenReview: () => void;
  onStartStudy: () => void;
  onToggleStudyMode: () => void;
}) {
  const themeStyles = useThemeStyles();
  const bodyIconColor = useContext(ThemeContext) === 'dark' ? '#e2e8f0' : '#172033';
  const copy = modeCopy[studyMode];
  const ui = modeInterfaceCopy[studyMode];

  return (
    <View style={styles.homeStack}>
      <View style={[styles.hero, themeStyles?.hero]}>
        <View style={styles.heroCopy}>
          <Text style={styles.eyebrow}>{copy.heroEyebrow}</Text>
          <Text style={[styles.heroTitle, themeStyles?.heroTitle]}>{copy.heroTitle}</Text>
          <Text style={[styles.heroText, themeStyles?.heroText]}>{copy.heroText}</Text>
        </View>
        <View style={[styles.ring, themeStyles?.ring]}>
          <Text style={[styles.ringValue, themeStyles?.ringValue]}>{dailyPercent}%</Text>
          <Text style={[styles.ringLabel, themeStyles?.ringLabel]}>{ui.completed}</Text>
        </View>
      </View>

      <AnimatedPressable
        accessibilityLabel={copy.toggleTitle}
        accessibilityRole="button"
        onPress={onToggleStudyMode}
        pressTone="list"
        style={[styles.modeSwitchButton, studyMode === 'chinese' && styles.modeSwitchButtonChinese, themeStyles?.modeSwitchButton]}
        testID="study-mode-toggle"
      >
        <View style={[styles.modeSwitchIcon, studyMode === 'chinese' && styles.modeSwitchIconChinese]}>
          <Languages size={20} color={studyMode === 'chinese' ? '#0f766e' : '#2563eb'} strokeWidth={2.4} />
        </View>
        <View style={styles.flexOne}>
          <Text style={[styles.modeSwitchTitle, themeStyles?.modeSwitchTitle]}>{copy.toggleTitle}</Text>
          <Text style={[styles.modeSwitchText, themeStyles?.modeSwitchText]}>{copy.toggleText}</Text>
        </View>
        <ChevronRight size={18} color={studyMode === 'chinese' ? '#0f766e' : '#2563eb'} strokeWidth={2.4} />
      </AnimatedPressable>

      <View style={[styles.progressCard, themeStyles?.progressCard]}>
        <View style={styles.rowBetween}>
          <Text style={[styles.sectionTitle, themeStyles?.sectionTitle]}>{ui.dailyProgress}</Text>
          <Text style={[styles.cardMeta, themeStyles?.cardMeta]}>
            {stats.studiedToday} / {progress.dailyTarget}
          </Text>
        </View>
        <View style={[styles.progressTrack, themeStyles?.progressTrack]}>
          <View style={[styles.progressFill, { width: `${dailyPercent}%` }]} />
        </View>
        <AnimatedPressable accessibilityRole="button" onPress={onStartStudy} pressTone="primary" style={styles.primaryButton}>
          <BookOpen size={18} color="#fff" strokeWidth={2.3} />
          <Text style={styles.primaryButtonText}>{copy.primaryAction}</Text>
          <ChevronRight size={18} color="#fff" strokeWidth={2.3} />
        </AnimatedPressable>
        <AnimatedPressable accessibilityRole="button" onPress={onOpenAccount} pressTone="secondary" style={[styles.accountShortcut, themeStyles?.accountShortcut]}>
          <User size={17} color={bodyIconColor} strokeWidth={2.3} />
          <Text style={[styles.accountShortcutText, themeStyles?.accountShortcutText]}>{ui.accountSync}</Text>
        </AnimatedPressable>
      </View>

      <View style={styles.statsGrid}>
        <StatCard label={ui.streak} value={progress.streak.toString()} tone="green" />
        <StatCard label={ui.mastered} value={stats.mastered.toString()} tone="blue" />
        <StatCard label={ui.reviewDue} value={stats.review.toString()} tone="orange" />
      </View>

      <AnimatedPressable accessibilityRole="button" onPress={onOpenReview} pressTone="list" style={[styles.reviewStrip, themeStyles?.reviewStrip]}>
        <RotateCcw size={20} color="#d97706" strokeWidth={2.4} />
        <View style={styles.flexOne}>
          <Text style={[styles.reviewTitle, themeStyles?.reviewTitle]}>{ui.reviewList}</Text>
          <Text style={[styles.reviewText, themeStyles?.reviewText]}>{stats.review > 0 ? ui.reviewListCount(stats.review) : ui.reviewListEmpty}</Text>
        </View>
        <ChevronRight size={18} color="#6b7280" strokeWidth={2.2} />
      </AnimatedPressable>
    </View>
  );
}

function StudyView({
  activeSetCount,
  activeSetName,
  activeFilter,
  activeInitial,
  activeLevel,
  filtersOpen,
  levelOptions,
  motionStyle,
  studyMode,
  wordCount,
  word,
  progress,
  onClearActiveSet,
  onAddToSet,
  onFilterChange,
  onFiltersToggle,
  onFavorite,
  onInitialChange,
  onKnown,
  onLevelChange,
  onReview,
}: {
  activeSetCount: number;
  activeSetName: string | null;
  activeFilter: LibraryFilter;
  activeInitial: string;
  activeLevel: string;
  filtersOpen: boolean;
  levelOptions: FilterOption[];
  motionStyle: StyleProp<ViewStyle>;
  studyMode: StudyMode;
  word: WordEntry | null;
  wordCount: number;
  progress: ProgressState;
  onClearActiveSet: () => void;
  onAddToSet: (word: WordEntry) => void;
  onFilterChange: (filter: LibraryFilter) => void;
  onFiltersToggle: () => void;
  onFavorite: () => void;
  onInitialChange: (initial: string) => void;
  onKnown: () => void;
  onLevelChange: (level: string) => void;
  onReview: () => void;
}) {
  const wordProgress = word ? progress.words[word.id] : undefined;
  const favorited = Boolean(wordProgress?.favorite);
  const themeStyles = useThemeStyles();
  const copy = modeCopy[studyMode];
  const ui = modeInterfaceCopy[studyMode];

  return (
    <View style={styles.screenStack}>
      <FilterControlPanel
        activeFilter={activeFilter}
        activeInitial={activeInitial}
        activeLevel={activeLevel}
        count={wordCount}
        levelOptions={levelOptions}
        open={filtersOpen}
        showStatus
        studyMode={studyMode}
        testID="study-filter-toggle"
        title={copy.studyFilterTitle}
        initialTitle={copy.initialTitle}
        onFilterChange={onFilterChange}
        onInitialChange={onInitialChange}
        onLevelChange={onLevelChange}
        onToggle={onFiltersToggle}
      />

      {activeSetName && (
        <ActiveSetBanner
          count={activeSetCount}
          name={activeSetName}
          studyMode={studyMode}
          onClear={onClearActiveSet}
        />
      )}

      {!word && (
        <View style={[styles.emptyState, themeStyles?.emptyState]}>
          <Text style={[styles.emptyTitle, themeStyles?.emptyTitle]}>
            {studyMode === 'chinese' ? ui.noChineseWords : ui.noStudyWords}
          </Text>
          <Text style={[styles.emptyText, themeStyles?.emptyText]}>{ui.relaxFilters}</Text>
        </View>
      )}

      {word && (
        <>
      <Animated.View style={[styles.wordCard, themeStyles?.wordCard, motionStyle]}>
        <View style={styles.rowBetween}>
          <View style={styles.groupPill}>
            <Text style={styles.groupText}>{word.group}</Text>
          </View>
          <View style={styles.studyCardActions}>
            <AnimatedPressable
              accessibilityLabel={ui.addToSetName(formatWordPrimary(word, studyMode))}
              accessibilityRole="button"
              onPress={() => onAddToSet(word)}
              pressTone="icon"
              style={[styles.iconButton, styles.addToSetIconButton]}
              testID="study-add-to-set"
            >
              <SquarePlus size={19} color="#2563eb" strokeWidth={2.4} />
            </AnimatedPressable>
            <AnimatedPressable
              accessibilityLabel={favorited ? ui.unfavoriteWord : ui.favoriteWord}
              accessibilityRole="button"
              onPress={onFavorite}
              pressTone="icon"
              style={styles.iconButton}
            >
              <Star size={20} color={favorited ? '#f59e0b' : '#717987'} fill={favorited ? '#f59e0b' : 'transparent'} />
            </AnimatedPressable>
          </View>
        </View>
        <Text style={[styles.bigWord, studyMode === 'chinese' && styles.bigChineseWord, themeStyles?.bigWord]}>
          {formatWordPrimary(word, studyMode)}
        </Text>
        {studyMode === 'chinese' && (
          <Text style={[styles.pinyinText, themeStyles?.pinyinText]}>{formatWordPinyin(word, studyMode)}</Text>
        )}
        <Text style={[styles.pronunciation, themeStyles?.pronunciation]}>{formatWordSecondary(word, studyMode)}</Text>
        <View style={[styles.meaningBlock, themeStyles?.meaningBlock]}>
          <Text style={styles.partOfSpeech}>{studyMode === 'chinese' ? ui.englishCounterpart : word.partOfSpeech}</Text>
          <Text style={[styles.meaning, themeStyles?.meaning]}>{formatMeaningDetail(word, studyMode)}</Text>
        </View>
        {formatMeaningSupplement(word, studyMode) && (
          <View style={[styles.supplementalMeaning, themeStyles?.supplementalMeaning]}>
            <Text style={[styles.supplementalLabel, themeStyles?.supplementalLabel]}>{ui.supplementalMeanings}</Text>
            <Text style={[styles.supplementalText, themeStyles?.supplementalText]}>{formatMeaningSupplement(word, studyMode)}</Text>
          </View>
        )}
        <View style={[styles.exampleBox, themeStyles?.exampleBox]}>
          <Text style={[styles.example, themeStyles?.example]}>{formatExamplePrimary(word, studyMode)}</Text>
          <Text style={[styles.exampleZh, themeStyles?.exampleZh]}>{formatExampleSecondary(word, studyMode)}</Text>
        </View>
      </Animated.View>

      <View style={styles.actionGrid}>
        <AnimatedPressable accessibilityRole="button" onPress={onReview} pressTone="secondary" style={styles.secondaryButton}>
          <RotateCcw size={18} color="#9a3412" strokeWidth={2.3} />
          <Text style={styles.secondaryButtonText}>{ui.reviewAgain}</Text>
        </AnimatedPressable>
        <AnimatedPressable accessibilityRole="button" onPress={onKnown} pressTone="primary" style={styles.confirmButton}>
          <Check size={18} color="#fff" strokeWidth={2.4} />
          <Text style={styles.confirmButtonText}>{ui.known}</Text>
        </AnimatedPressable>
      </View>
        </>
      )}
    </View>
  );
}

function FilterControlPanel({
  activeFilter,
  activeInitial,
  activeLevel,
  activeSort,
  count,
  initialTitle = '字首',
  levelOptions,
  open,
  showStatus,
  studyMode,
  testID,
  title,
  onFilterChange,
  onInitialChange,
  onLevelChange,
  onSortChange,
  onToggle,
}: {
  activeFilter: LibraryFilter;
  activeInitial: string;
  activeLevel: string;
  activeSort?: LibrarySort;
  count: number;
  initialTitle?: string;
  levelOptions: FilterOption[];
  open: boolean;
  showStatus: boolean;
  studyMode: StudyMode;
  testID: string;
  title: string;
  onFilterChange: (filter: LibraryFilter) => void;
  onInitialChange: (initial: string) => void;
  onLevelChange: (level: string) => void;
  onSortChange?: (sort: LibrarySort) => void;
  onToggle: () => void;
}) {
  const summary = filterSummary(activeFilter, activeLevel, activeInitial, showStatus, studyMode, levelOptions, activeSort);
  const themeStyles = useThemeStyles();
  const bodyIconColor = useContext(ThemeContext) === 'dark' ? '#e2e8f0' : '#172033';
  const ui = modeInterfaceCopy[studyMode];

  return (
    <View style={[styles.foldedFilterCard, themeStyles?.foldedFilterCard]}>
      <AnimatedPressable
        accessibilityRole="button"
        onPress={onToggle}
        pressTone="secondary"
        style={[styles.filterSummaryButton, open && styles.filterSummaryButtonOpen, open && themeStyles?.filterSummaryButtonOpen]}
        testID={testID}
      >
        <View style={styles.flexOne}>
          <Text style={[styles.filterSummaryTitle, themeStyles?.filterSummaryTitle]}>{title}</Text>
          <Text style={[styles.filterSummaryText, themeStyles?.filterSummaryText]}>
            {summary} · {count} {ui.filterCountUnit}
          </Text>
        </View>
        <View style={styles.filterSummaryIcon}>
          <SlidersHorizontal size={16} color={bodyIconColor} strokeWidth={2.4} />
          <ChevronDown size={15} color={bodyIconColor} strokeWidth={2.4} style={open ? styles.filterChevronOpen : undefined} />
        </View>
      </AnimatedPressable>

      <AnimatedFilterPanel open={open} testID={`${testID}-panel`}>
          {showStatus && (
            <View style={styles.filterSection}>
              <Text style={[styles.filterSectionTitle, themeStyles?.filterSectionTitle]}>{ui.filterStatus}</Text>
              <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.filterRow}>
                {filters.map((filter) => {
                  const selected = activeFilter === filter.id;
                  return (
                    <AnimatedPressable
                      accessibilityRole="button"
                      key={filter.id}
                      onPress={() => onFilterChange(filter.id)}
                      pressTone="chip"
                      style={[styles.filterChip, themeStyles?.filterChip, selected && styles.filterChipActive]}
                    >
                      <Text style={[styles.filterText, selected && styles.filterTextActive]}>{filterLabel(filter.id, studyMode)}</Text>
                    </AnimatedPressable>
                  );
                })}
              </ScrollView>
            </View>
          )}

          <View style={styles.filterSection}>
            <Text style={[styles.filterSectionTitle, themeStyles?.filterSectionTitle]}>{ui.filterLevel}</Text>
            <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.filterRow}>
              {levelOptions.map((level) => {
                const selected = activeLevel === level.id;
                return (
                  <AnimatedPressable
                    accessibilityLabel={ui.levelAccessibility(levelLabel(level.id, studyMode, levelOptions))}
                    accessibilityRole="button"
                    key={level.id}
                    onPress={() => onLevelChange(level.id)}
                    pressTone="chip"
                    style={[styles.filterChip, themeStyles?.filterChip, selected && styles.levelChipActive]}
                  >
                    <Text style={[styles.filterText, selected && styles.filterTextActive]}>{levelLabel(level.id, studyMode, levelOptions)}</Text>
                  </AnimatedPressable>
                );
              })}
            </ScrollView>
          </View>

          <View style={styles.filterSection}>
            <Text style={[styles.filterSectionTitle, themeStyles?.filterSectionTitle]}>{initialTitle}</Text>
            <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.letterRow}>
              {alphabetFilters.map((initial) => {
                const selected = activeInitial === initial.id;
                return (
                  <AnimatedPressable
                    accessibilityLabel={ui.initialAccessibility(initial.id)}
                    accessibilityRole="button"
                    key={initial.id}
                    onPress={() => onInitialChange(initial.id)}
                    pressTone="chip"
                    style={[styles.letterChip, themeStyles?.letterChip, selected && styles.letterChipActive]}
                  >
                    <Text style={[styles.letterText, selected && styles.letterTextActive]}>{initialLabel(initial.id, studyMode)}</Text>
                  </AnimatedPressable>
                );
              })}
            </ScrollView>
          </View>

          {activeSort && onSortChange && (
            <View style={styles.filterSection}>
              <Text style={[styles.filterSectionTitle, themeStyles?.filterSectionTitle]}>{ui.filterSort}</Text>
              <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.filterRow}>
                {librarySortOptions.map((sort) => {
                  const selected = activeSort === sort.id;
                  const label = sortLabel(sort.id, studyMode);
                  return (
                    <AnimatedPressable
                      accessibilityLabel={ui.sortAccessibility(label)}
                      accessibilityRole="button"
                      key={sort.id}
                      onPress={() => onSortChange(sort.id)}
                      pressTone="chip"
                      style={[styles.filterChip, themeStyles?.filterChip, selected && styles.filterChipActive]}
                    >
                      <Text style={[styles.filterText, selected && styles.filterTextActive]}>{label}</Text>
                    </AnimatedPressable>
                  );
                })}
              </ScrollView>
            </View>
          )}
      </AnimatedFilterPanel>
    </View>
  );
}

function QuizView({
  activeSetCount,
  activeSetName,
  activeFilter,
  activeInitial,
  activeLevel,
  correctCount,
  filtersOpen,
  levelOptions,
  motionStyle,
  conversationPrompt,
  options,
  practiceMode,
  questionCount,
  questionCounts,
  questionIndex,
  quizFinished,
  quizStarted,
  result,
  sessionTotal,
  speakingAnswerVisible,
  studyMode,
  wordCount,
  word,
  onAnswer,
  onClearActiveSet,
  onFilterChange,
  onFiltersToggle,
  onInitialChange,
  onLevelChange,
  onPracticeModeChange,
  onNext,
  onQuestionCountChange,
  onRevealSpeakingAnswer,
  onRestart,
  onStart,
}: {
  activeSetCount: number;
  activeSetName: string | null;
  activeFilter: LibraryFilter;
  activeInitial: string;
  activeLevel: string;
  correctCount: number;
  filtersOpen: boolean;
  levelOptions: FilterOption[];
  motionStyle: StyleProp<ViewStyle>;
  conversationPrompt: ConversationPromptCard | null;
  options: ReturnType<typeof buildQuizOptions>;
  practiceMode: QuizPracticeMode;
  questionCount: (typeof quizQuestionCounts)[number];
  questionCounts: readonly (typeof quizQuestionCounts)[number][];
  questionIndex: number;
  quizFinished: boolean;
  quizStarted: boolean;
  result: 'correct' | 'wrong' | null;
  sessionTotal: number;
  speakingAnswerVisible: boolean;
  studyMode: StudyMode;
  word: WordEntry | null;
  wordCount: number;
  onAnswer: (correct: boolean) => void;
  onClearActiveSet: () => void;
  onFilterChange: (filter: LibraryFilter) => void;
  onFiltersToggle: () => void;
  onInitialChange: (initial: string) => void;
  onLevelChange: (level: string) => void;
  onPracticeModeChange: (mode: QuizPracticeMode) => void;
  onNext: () => void;
  onQuestionCountChange: (count: (typeof quizQuestionCounts)[number]) => void;
  onRevealSpeakingAnswer: () => void;
  onRestart: () => void;
  onStart: () => void;
}) {
  const themeStyles = useThemeStyles();
  const bodyIconColor = useContext(ThemeContext) === 'dark' ? '#e2e8f0' : '#172033';
  const copy = modeCopy[studyMode];
  const ui = modeInterfaceCopy[studyMode];
  const speakingMode = practiceMode === 'speaking';

  return (
    <View style={styles.screenStack}>
      <FilterControlPanel
        activeFilter={activeFilter}
        activeInitial={activeInitial}
        activeLevel={activeLevel}
        count={wordCount}
        levelOptions={levelOptions}
        open={filtersOpen}
        showStatus
        studyMode={studyMode}
        testID="quiz-filter-toggle"
        title={copy.quizFilterTitle}
        initialTitle={copy.initialTitle}
        onFilterChange={onFilterChange}
        onInitialChange={onInitialChange}
        onLevelChange={onLevelChange}
        onToggle={onFiltersToggle}
      />

      {activeSetName && (
        <ActiveSetBanner
          count={activeSetCount}
          name={activeSetName}
          studyMode={studyMode}
          onClear={onClearActiveSet}
        />
      )}

      <Animated.View style={[styles.quizModeCard, themeStyles?.quizModeCard, motionStyle]}>
        <View style={styles.rowBetween}>
          <Text style={[styles.sectionTitle, themeStyles?.sectionTitle]}>{ui.quizPracticeTitle}</Text>
          <Languages size={20} color="#2563eb" strokeWidth={2.3} />
        </View>
        <View style={[styles.quizModeSwitch, themeStyles?.quizModeSwitch]}>
          {(['choice', 'speaking'] as const).map((mode) => {
            const selected = practiceMode === mode;
            return (
              <AnimatedPressable
                accessibilityRole="button"
                key={mode}
                onPress={() => onPracticeModeChange(mode)}
                pressTone="chip"
                style={[
                  styles.quizModeButton,
                  themeStyles?.quizModeButton,
                  selected && styles.quizModeButtonActive,
                ]}
              >
                <Text
                  style={[
                    styles.quizModeButtonText,
                    themeStyles?.quizModeButtonText,
                    selected && styles.quizModeButtonTextActive,
                  ]}
                >
                  {mode === 'choice' ? ui.choiceQuizMode : ui.speakingQuizMode}
                </Text>
              </AnimatedPressable>
            );
          })}
        </View>
      </Animated.View>

      {!quizStarted && !quizFinished && (
        <Animated.View style={[styles.quizSetupCard, themeStyles?.quizSetupCard, motionStyle]}>
          <View style={styles.rowBetween}>
            <View>
              <Text style={[styles.sectionTitle, themeStyles?.sectionTitle]}>{ui.questionCountTitle}</Text>
              <Text style={[styles.cardMeta, themeStyles?.cardMeta]}>{ui.questionBankPrefix} {wordCount} {copy.questionBankUnit}</Text>
            </View>
            {speakingMode ? (
              <Languages size={22} color="#2563eb" strokeWidth={2.3} />
            ) : (
              <Target size={22} color="#2563eb" strokeWidth={2.3} />
            )}
          </View>
          <View style={styles.quizCountRow}>
            {questionCounts.map((count) => {
              const selected = questionCount === count;
              const cappedCount = Math.min(count, wordCount);
              return (
                <AnimatedPressable
                  accessibilityRole="button"
                  key={count}
                  onPress={() => onQuestionCountChange(count)}
                  pressTone="chip"
                  style={[styles.quizCountChip, themeStyles?.quizCountChip, selected && styles.quizCountChipActive]}
                >
                  <Text style={[styles.quizCountText, themeStyles?.quizCountText, selected && styles.quizCountTextActive]}>
                    {count} {ui.questionUnit}
                  </Text>
                  {cappedCount < count && (
                    <Text style={[styles.quizCountMeta, themeStyles?.quizCountMeta, selected && styles.quizCountTextActive]}>
                      {ui.cappedQuestionPrefix} {cappedCount}
                    </Text>
                  )}
                </AnimatedPressable>
              );
            })}
          </View>
          <AnimatedPressable
            accessibilityRole="button"
            disabled={wordCount === 0}
            onPress={onStart}
            pressTone="primary"
            style={[styles.primaryButton, wordCount === 0 && styles.disabledButton]}
          >
            {speakingMode ? (
              <Languages size={18} color="#fff" strokeWidth={2.3} />
            ) : (
              <Target size={18} color="#fff" strokeWidth={2.3} />
            )}
            <Text style={styles.primaryButtonText}>{speakingMode ? ui.startSpeaking : ui.startQuiz}</Text>
          </AnimatedPressable>
        </Animated.View>
      )}

      {quizFinished && (
        <Animated.View style={[styles.quizSetupCard, themeStyles?.quizSetupCard, motionStyle]}>
          <Text style={styles.eyebrow}>{speakingMode ? 'SPEAKING' : 'RESULT'}</Text>
          <Text style={[styles.resultTitle, themeStyles?.resultTitle]}>
            {speakingMode ? ui.speakingFinished : ui.quizFinished}
          </Text>
          <Text style={[styles.quizScoreText, themeStyles?.quizScoreText]}>
            {speakingMode ? ui.speakingScore(sessionTotal) : ui.quizScore(correctCount, sessionTotal)}
          </Text>
          <AnimatedPressable accessibilityRole="button" onPress={onRestart} pressTone="primary" style={styles.primaryButton}>
            <RotateCcw size={18} color="#fff" strokeWidth={2.3} />
            <Text style={styles.primaryButtonText}>{speakingMode ? ui.restartSpeaking : ui.restartQuiz}</Text>
          </AnimatedPressable>
        </Animated.View>
      )}

      {quizStarted && !word && (
        <View style={[styles.emptyState, themeStyles?.emptyState]}>
          <Text style={[styles.emptyTitle, themeStyles?.emptyTitle]}>
            {ui.noQuizWords}
          </Text>
          <Text style={[styles.emptyText, themeStyles?.emptyText]}>{ui.relaxFilters}</Text>
        </View>
      )}

      {quizStarted && word && !speakingMode && (
        <>
          <Animated.View style={[styles.quizCard, themeStyles?.quizCard, motionStyle]}>
            <View style={styles.quizQuestionHeader}>
              <Text style={styles.eyebrow}>
                QUIZ {questionIndex + 1} / {sessionTotal}
              </Text>
              {result && (
                <AnimatedPressable
                  accessibilityLabel={ui.nextQuestion}
                  accessibilityRole="button"
                  onPress={onNext}
                  pressTone="secondary"
                  style={[styles.quizNextTopButton, themeStyles?.quizNextTopButton]}
                >
                  <Text style={[styles.quizNextTopText, themeStyles?.quizNextTopText]}>{ui.nextQuestion}</Text>
                  <ChevronRight size={16} color={bodyIconColor} strokeWidth={2.3} />
                </AnimatedPressable>
              )}
            </View>
            <Text style={[styles.bigWord, studyMode === 'chinese' && styles.bigChineseWord, themeStyles?.bigWord]}>
              {formatWordPrimary(word, studyMode)}
            </Text>
            {studyMode === 'chinese' && (
              <Text style={[styles.pinyinText, themeStyles?.pinyinText]}>{formatWordPinyin(word, studyMode)}</Text>
            )}
            <View style={styles.quizOptions}>
              {options.map((option) => (
                <AnimatedPressable
                  accessibilityRole="button"
                  disabled={result !== null}
                  key={option.meaning}
                  onPress={() => onAnswer(option.correct)}
                  pressTone="list"
                  pressedStyle={[styles.quizOptionPressed, themeStyles?.quizOptionPressed]}
                  style={[
                    styles.quizOption,
                    themeStyles?.quizOption,
                    result !== null && option.correct && styles.quizOptionCorrect,
                    result === 'wrong' && !option.correct && styles.quizOptionMuted,
                  ]}
                >
                  <Text
                    style={[
                      styles.quizOptionText,
                      themeStyles?.quizOptionText,
                      result !== null && option.correct && styles.quizOptionTextCorrect,
                    ]}
                  >
                    {option.meaning}
                  </Text>
                </AnimatedPressable>
              ))}
            </View>
          </Animated.View>

          {result && (
            <Animated.View style={[styles.resultCard, result === 'correct' ? styles.resultCorrect : styles.resultWrong, themeStyles?.resultCard, motionStyle]}>
              <Text style={[styles.resultTitle, themeStyles?.resultTitle]}>{result === 'correct' ? ui.correctResult : ui.wrongResult}</Text>
              <View style={[styles.quizExampleCard, themeStyles?.quizExampleCard]}>
                <Text style={[styles.quizExampleLabel, themeStyles?.quizExampleLabel]}>
                  {studyMode === 'chinese' ? ui.chineseExample : ui.englishExample}
                </Text>
                <Text style={[styles.resultText, themeStyles?.resultText]}>{formatExamplePrimary(word, studyMode)}</Text>
                <Text style={[styles.quizExampleLabel, themeStyles?.quizExampleLabel]}>
                  {studyMode === 'chinese' ? ui.englishExample : ui.chineseTranslation}
                </Text>
                <Text style={[styles.resultText, themeStyles?.resultText]}>{formatExampleSecondary(word, studyMode)}</Text>
                <Text style={[styles.quizExampleLabel, themeStyles?.quizExampleLabel]}>{ui.answer}</Text>
                <Text style={[styles.resultText, themeStyles?.resultText]}>{formatQuizAnswer(word, studyMode)}</Text>
                {formatMeaningSupplement(word, studyMode) && (
                  <>
                    <Text style={[styles.quizExampleLabel, themeStyles?.quizExampleLabel]}>{ui.supplementalMeanings}</Text>
                    <Text style={[styles.resultText, themeStyles?.resultText]}>{formatMeaningSupplement(word, studyMode)}</Text>
                  </>
                )}
              </View>
            </Animated.View>
          )}
        </>
      )}

      {quizStarted && word && speakingMode && conversationPrompt && (
        <>
          <Animated.View style={[styles.quizCard, themeStyles?.quizCard, motionStyle]}>
            <View style={styles.quizQuestionHeader}>
              <Text style={styles.eyebrow}>
                SPEAKING {questionIndex + 1} / {sessionTotal}
              </Text>
              {speakingAnswerVisible && (
                <AnimatedPressable
                  accessibilityLabel={ui.nextQuestion}
                  accessibilityRole="button"
                  onPress={onNext}
                  pressTone="secondary"
                  style={[styles.quizNextTopButton, themeStyles?.quizNextTopButton]}
                >
                  <Text style={[styles.quizNextTopText, themeStyles?.quizNextTopText]}>{ui.nextQuestion}</Text>
                  <ChevronRight size={16} color={bodyIconColor} strokeWidth={2.3} />
                </AnimatedPressable>
              )}
            </View>
            <View style={styles.speakingKeywordHeader}>
              <View style={[styles.speakingIconWrap, themeStyles?.speakingIconWrap]}>
                <Languages size={24} color="#2563eb" strokeWidth={2.4} />
              </View>
              <View style={styles.flexOne}>
                <Text style={[styles.bigWord, studyMode === 'chinese' && styles.bigChineseWord, themeStyles?.bigWord]}>
                  {conversationPrompt.keyword}
                </Text>
                {conversationPrompt.keywordPronunciation ? (
                  <Text style={[styles.pinyinText, themeStyles?.pinyinText]}>{conversationPrompt.keywordPronunciation}</Text>
                ) : null}
              </View>
            </View>
            <View style={[styles.quizExampleCard, themeStyles?.quizExampleCard]}>
              <Text style={[styles.quizExampleLabel, themeStyles?.quizExampleLabel]}>{ui.speakingPromptLabel}</Text>
              <Text style={[styles.speakingPromptQuestion, themeStyles?.speakingPromptQuestion]} testID="speaking-prompt-question">
                {conversationPrompt.question}
              </Text>
              <Text style={[styles.quizExampleLabel, themeStyles?.quizExampleLabel]}>{ui.speakingHintLabel}</Text>
              <Text style={[styles.resultText, themeStyles?.resultText]}>{conversationPrompt.questionSupport}</Text>
            </View>
            <View style={styles.speakingActionRow}>
              <AnimatedPressable
                accessibilityRole="button"
                onPress={onRevealSpeakingAnswer}
                pressTone="primary"
                style={styles.speakingDoneButton}
              >
                <Check size={18} color="#fff" strokeWidth={2.4} />
                <Text style={styles.speakingDoneButtonText}>{ui.iSpoke}</Text>
              </AnimatedPressable>
              <AnimatedPressable
                accessibilityRole="button"
                onPress={onRevealSpeakingAnswer}
                pressTone="secondary"
                style={[styles.speakingSecondaryButton, themeStyles?.speakingSecondaryButton]}
              >
                <BookOpen size={18} color={bodyIconColor} strokeWidth={2.3} />
                <Text style={[styles.speakingSecondaryText, themeStyles?.speakingSecondaryText]}>{ui.showSampleAnswer}</Text>
              </AnimatedPressable>
            </View>
          </Animated.View>

          {speakingAnswerVisible && (
            <Animated.View style={[styles.resultCard, styles.resultCorrect, themeStyles?.resultCard, motionStyle]}>
              <Text style={[styles.resultTitle, themeStyles?.resultTitle]}>{ui.sampleAnswer}</Text>
              <View style={[styles.quizExampleCard, themeStyles?.quizExampleCard]}>
                <Text style={[styles.quizExampleLabel, themeStyles?.quizExampleLabel]}>{ui.sampleAnswer}</Text>
                <Text style={[styles.resultText, themeStyles?.resultText]}>{conversationPrompt.referenceAnswer}</Text>
                <Text style={[styles.quizExampleLabel, themeStyles?.quizExampleLabel]}>{ui.sampleTranslation}</Text>
                <Text style={[styles.resultText, themeStyles?.resultText]}>{conversationPrompt.referenceTranslation}</Text>
              </View>
            </Animated.View>
          )}
        </>
      )}
    </View>
  );
}

const LibraryView = memo(function LibraryView({
  activeFilter,
  activeInitial,
  activeLevel,
  activeSort,
  customSets,
  filtersOpen,
  itemExtent,
  levelOptions,
  listMotionStyle,
  progress,
  query,
  searchFocused,
  studyMode,
  visibleStart,
  visibleWindowSize,
  words,
  onAddToSet,
  onFavorite,
  onFilterChange,
  onFiltersToggle,
  onFirstItemLayout,
  onInitialChange,
  onListLayout,
  onLevelChange,
  onOpenCustomSets,
  onOpenWord,
  onQueryChange,
  onQueryClear,
  onSearchBlur,
  onSearchFocus,
  onSortChange,
}: {
  activeFilter: LibraryFilter;
  activeInitial: string;
  activeLevel: string;
  activeSort: LibrarySort;
  customSets: CustomVocabSet[];
  filtersOpen: boolean;
  itemExtent: number;
  levelOptions: FilterOption[];
  listMotionStyle: (index: number) => StyleProp<ViewStyle>;
  progress: ProgressState;
  query: string;
  searchFocused: boolean;
  studyMode: StudyMode;
  visibleStart: number;
  visibleWindowSize: number;
  words: WordEntry[];
  onAddToSet: (word: WordEntry) => void;
  onFavorite: (wordId: string) => void;
  onFilterChange: (filter: LibraryFilter) => void;
  onFiltersToggle: () => void;
  onFirstItemLayout: (event: LayoutChangeEvent) => void;
  onInitialChange: (initial: string) => void;
  onListLayout: (event: LayoutChangeEvent) => void;
  onLevelChange: (level: string) => void;
  onOpenCustomSets: () => void;
  onOpenWord: (word: WordEntry) => void;
  onQueryChange: (query: string) => void;
  onQueryClear: () => void;
  onSearchBlur: () => void;
  onSearchFocus: () => void;
  onSortChange: (sort: LibrarySort) => void;
}) {
  const safeStart = Math.max(0, Math.min(visibleStart, Math.max(0, words.length - visibleWindowSize)));
  const visibleEnd = Math.min(words.length, safeStart + visibleWindowSize);
  const visibleWords = words.slice(safeStart, visibleEnd);
  const spacerHeights = virtualListSpacerHeights(safeStart, visibleWords.length, words.length, itemExtent);
  const hasQuery = query.trim().length > 0;
  const searchAnim = useRef(new Animated.Value(searchFocused || hasQuery ? 1 : 0)).current;
  const themeStyles = useThemeStyles();
  const darkMode = useContext(ThemeContext) === 'dark';
  const bodyIconColor = darkMode ? '#e2e8f0' : '#172033';
  const copy = modeCopy[studyMode];
  const ui = modeInterfaceCopy[studyMode];

  useEffect(() => {
    Animated.timing(searchAnim, {
      duration: interactionMotion.hoverMs,
      easing: Easing.out(Easing.cubic),
      toValue: searchFocused || hasQuery ? 1 : 0,
      useNativeDriver: Platform.OS !== 'web',
    }).start();
  }, [hasQuery, searchAnim, searchFocused]);

  const searchMotionStyle = {
    transform: [
      {
        scale: searchAnim.interpolate({
          inputRange: [0, 1],
          outputRange: [1, 1.008],
        }),
      },
    ],
  };
  const searchMetaMotionStyle = {
    opacity: searchAnim,
    transform: [
      {
        translateY: searchAnim.interpolate({
          inputRange: [0, 1],
          outputRange: [-5, 0],
        }),
      },
    ],
  };
  const searchBoxWebTransition: WebTransitionStyle | undefined =
    Platform.OS === 'web'
      ? {
          transitionDuration: '180ms',
          transitionProperty: 'background-color, border-color, box-shadow, transform',
          transitionTimingFunction: 'cubic-bezier(0.22, 1, 0.36, 1)',
          willChange: 'background-color, border-color, box-shadow, transform',
        }
      : undefined;

  return (
    <View style={styles.screenStack}>
      <View style={[styles.libraryHeaderCard, themeStyles?.libraryHeaderCard]}>
        <View style={styles.libraryHeaderRow}>
          <View style={styles.libraryHeaderTitleLine}>
            <Text style={[styles.libraryHeaderTitle, themeStyles?.libraryHeaderTitle]}>{copy.libraryTitle}</Text>
            <View style={[styles.libraryHeaderMetaPill, themeStyles?.libraryHeaderMetaPill]} testID="library-filtered-count-pill">
              <Text style={[styles.libraryHeaderMetaPillText, themeStyles?.libraryHeaderMetaPillText]}>{ui.filteredCount(words.length)}</Text>
            </View>
          </View>
        </View>

        <View style={styles.libraryTopControlsInset}>
          <Animated.View style={searchMotionStyle}>
            <View style={[styles.searchBox, themeStyles?.searchBox, searchBoxWebTransition, searchFocused && styles.searchBoxFocused, hasQuery && styles.searchBoxActive]}>
              <Search size={18} color={searchFocused ? '#2563eb' : '#717987'} strokeWidth={2.2} />
              <TextInput
                onChangeText={onQueryChange}
                onBlur={onSearchBlur}
                onFocus={onSearchFocus}
                placeholder={copy.searchPlaceholder}
                placeholderTextColor="#9ca3af"
                style={[styles.searchInput, themeStyles?.searchInput]}
                value={query}
              />
              {hasQuery && (
                <AnimatedPressable
                  accessibilityLabel={ui.clearSearch}
                  accessibilityRole="button"
                  onPress={onQueryClear}
                  pressTone="icon"
                  style={[styles.searchClearButton, themeStyles?.searchClearButton]}
                  testID="library-search-clear"
                >
                  <X size={16} color="#64748b" strokeWidth={2.5} />
                </AnimatedPressable>
              )}
            </View>
          </Animated.View>

          {hasQuery && (
            <Animated.View style={[styles.searchMetaBox, themeStyles?.searchMetaBox, searchMetaMotionStyle]}>
              <Text style={[styles.searchMetaText, themeStyles?.searchMetaText]}>{ui.searchMeta(query.trim(), words.length)}</Text>
            </Animated.View>
          )}

          <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.filterRow}>
            {filters.map((filter) => {
              const selected = activeFilter === filter.id;
              return (
                <AnimatedPressable
                  accessibilityRole="button"
                  key={filter.id}
                  onPress={() => onFilterChange(filter.id)}
                  pressTone="chip"
                  style={[styles.filterChip, themeStyles?.filterChip, selected && styles.filterChipActive]}
                >
                  <Text style={[styles.filterText, selected && styles.filterTextActive]}>{filterLabel(filter.id, studyMode)}</Text>
                </AnimatedPressable>
              );
            })}
          </ScrollView>

          <FilterControlPanel
            activeFilter={activeFilter}
            activeInitial={activeInitial}
            activeLevel={activeLevel}
            activeSort={activeSort}
            count={words.length}
            levelOptions={levelOptions}
            open={filtersOpen}
            showStatus={false}
            studyMode={studyMode}
            testID="library-filter-toggle"
            title={copy.libraryFilterTitle}
            initialTitle={copy.initialTitle}
            onFilterChange={onFilterChange}
            onInitialChange={onInitialChange}
            onLevelChange={onLevelChange}
            onSortChange={onSortChange}
            onToggle={onFiltersToggle}
          />
        </View>

      </View>

      <View style={[styles.libraryCustomSetsCard, themeStyles?.libraryCustomSetsCard]} testID="library-custom-sets-card">
        <View style={styles.libraryCustomSetsHeader}>
          <View style={styles.libraryCustomSetsTitleRow}>
            <View style={[styles.settingsEntryIcon, themeStyles?.settingsEntryIcon]}>
              <Library size={18} color={bodyIconColor} strokeWidth={2.3} />
            </View>
            <View style={styles.flexOne}>
              <Text style={[styles.libraryCustomSetsTitle, themeStyles?.libraryCustomSetsTitle]}>{ui.customSets}</Text>
              <Text style={[styles.libraryHeaderMeta, themeStyles?.libraryHeaderMeta]}>{ui.customSetsSummary(customSets.length)}</Text>
            </View>
          </View>
          <AnimatedPressable accessibilityRole="button" onPress={onOpenCustomSets} pressTone="secondary" style={[styles.libraryManageSetsButton, themeStyles?.libraryTopButton]}>
            <Text style={[styles.libraryManageSetsButtonLabel, themeStyles?.libraryTopButtonText]}>{ui.manage}</Text>
            <ChevronRight size={15} color={bodyIconColor} strokeWidth={2.4} />
          </AnimatedPressable>
        </View>
        {customSets.length > 0 ? (
          <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.filterRow}>
            {customSets.slice(0, 4).map((set) => (
              <AnimatedPressable
                accessibilityRole="button"
                key={set.id}
                onPress={onOpenCustomSets}
                pressTone="chip"
                style={[styles.libraryCustomSetChip, themeStyles?.filterChip]}
              >
                <View style={[styles.customSetColorDot, { backgroundColor: set.color }]} />
                <Text style={[styles.filterText, themeStyles?.filterText]}>{set.name}</Text>
                <Text style={[styles.libraryCustomSetCount, themeStyles?.libraryHeaderMeta]}>{set.wordIds.length}</Text>
              </AnimatedPressable>
            ))}
          </ScrollView>
        ) : (
          <Text style={[styles.customSetPickerEmpty, themeStyles?.customSetPickerEmpty]}>{ui.noCustomSets}</Text>
        )}
      </View>

      <View onLayout={onListLayout} style={styles.libraryPanel}>
        <View style={styles.wordList}>
        <Text style={[styles.resultCount, themeStyles?.resultCount]}>
          {ui.resultCount(words.length, safeStart, visibleEnd)}
        </Text>
        {spacerHeights.top > 0 && (
          <View pointerEvents="none" style={[styles.virtualLibrarySpacer, { height: spacerHeights.top }]} />
        )}
        {visibleWords.map((word, index) => {
          const wordProgress = progress.words[word.id];
          return (
            <Animated.View
              key={word.id}
              onLayout={index === 0 ? onFirstItemLayout : undefined}
              style={[styles.libraryItem, themeStyles?.libraryItem, listMotionStyle(index)]}
            >
              <AnimatedPressable
                accessibilityLabel={ui.viewWordDetails(formatWordPrimary(word, studyMode))}
                accessibilityRole="button"
                onPress={() => onOpenWord(word)}
                pressTone="libraryItem"
                pressedStyle={[
                  styles.libraryItemPressed,
                  styles.libraryItemPressedLift,
                  themeStyles?.libraryItemPressed,
                  themeStyles?.libraryItemPressedLift,
                ]}
                style={styles.libraryItemMain}
              >
                <View style={styles.wordLine}>
                  <Text style={[styles.libraryWord, studyMode === 'chinese' && styles.libraryChineseWord, themeStyles?.libraryWord]}>
                    {formatWordPrimary(word, studyMode)}
                  </Text>
                  <Text style={styles.libraryGroup}>{word.group}</Text>
                  <Text style={styles.libraryPos}>{word.partOfSpeech}</Text>
                </View>
                {studyMode === 'chinese' && (
                  <Text style={[styles.libraryPinyin, themeStyles?.libraryPinyin]}>{formatWordPinyin(word, studyMode)}</Text>
                )}
                <Text style={[styles.libraryMeaning, themeStyles?.libraryMeaning]}>{formatMeaningDetail(word, studyMode)}</Text>
                {formatMeaningSupplement(word, studyMode) && (
                  <Text style={[styles.librarySupplemental, themeStyles?.librarySupplemental]}>
                    {ui.supplementalMeanings}: {formatMeaningSupplement(word, studyMode)}
                  </Text>
                )}
                <Text style={[styles.libraryExample, themeStyles?.libraryExample]}>{formatExamplePrimary(word, studyMode)}</Text>
                <Text style={styles.libraryDetailHint}>{ui.viewDetails}</Text>
              </AnimatedPressable>
              <View style={styles.librarySide}>
                <AnimatedPressable
                  accessibilityLabel={ui.addToSetName(formatWordPrimary(word, studyMode))}
                  accessibilityRole="button"
                  onPress={() => onAddToSet(word)}
                  pressTone="icon"
                  style={[styles.iconButton, styles.addToSetIconButton]}
                >
                  <SquarePlus size={18} color="#2563eb" strokeWidth={2.4} />
                </AnimatedPressable>
                <AnimatedPressable
                  accessibilityLabel={
                    wordProgress?.favorite
                      ? ui.unfavoriteWordName(formatWordPrimary(word, studyMode))
                      : ui.favoriteWordName(formatWordPrimary(word, studyMode))
                  }
                  accessibilityRole="button"
                  onPress={() => onFavorite(word.id)}
                  pressTone="icon"
                  style={styles.iconButton}
                >
                  <Star
                    size={18}
                    color={wordProgress?.favorite ? '#f59e0b' : '#717987'}
                    fill={wordProgress?.favorite ? '#f59e0b' : 'transparent'}
                  />
                </AnimatedPressable>
                <Text style={[styles.statusText, themeStyles?.statusText]}>{statusLabel(wordProgress?.status, studyMode)}</Text>
              </View>
            </Animated.View>
          );
        })}
        {spacerHeights.bottom > 0 && (
          <View pointerEvents="none" style={[styles.virtualLibrarySpacer, { height: spacerHeights.bottom }]} />
        )}
        {words.length === 0 && (
          <View style={[styles.emptyState, themeStyles?.emptyState]}>
            <Text style={[styles.emptyTitle, themeStyles?.emptyTitle]}>
              {studyMode === 'chinese' ? ui.noChineseWords : ui.noLibraryWords}
            </Text>
            <Text style={[styles.emptyText, themeStyles?.emptyText]}>{ui.relaxLibraryFilters(hasQuery)}</Text>
          </View>
        )}
        </View>
      </View>
    </View>
  );
});

function LibraryWordDetailView({
  progress,
  studyMode,
  word,
  onAddToSet,
  onBack,
  onFavorite,
}: {
  progress: ProgressState;
  studyMode: StudyMode;
  word: WordEntry;
  onAddToSet: (word: WordEntry) => void;
  onBack: () => void;
  onFavorite: () => void;
}) {
  const wordProgress = progress.words[word.id];
  const favorite = Boolean(wordProgress?.favorite);
  const themeStyles = useThemeStyles();
  const bodyIconColor = useContext(ThemeContext) === 'dark' ? '#e2e8f0' : '#172033';
  const ui = modeInterfaceCopy[studyMode];

  return (
    <View style={styles.screenStack}>
      <AnimatedPressable accessibilityRole="button" onPress={onBack} pressTone="secondary" style={[styles.libraryDetailBack, themeStyles?.libraryDetailBack]}>
        <ChevronLeft size={18} color={bodyIconColor} strokeWidth={2.5} />
        <Text style={[styles.libraryDetailBackText, themeStyles?.libraryDetailBackText]}>{ui.backLibrary}</Text>
      </AnimatedPressable>

      <View style={[styles.libraryDetailPage, themeStyles?.libraryDetailPage]} testID="library-word-detail">
        <View style={styles.libraryDetailHeader}>
          <View style={styles.flexOne}>
            <Text style={styles.eyebrow}>{ui.detailTitle}</Text>
            <Text style={[styles.libraryDetailWord, studyMode === 'chinese' && styles.libraryDetailChineseWord, themeStyles?.libraryDetailWord]}>
              {formatWordPrimary(word, studyMode)}
            </Text>
            {studyMode === 'chinese' && (
              <Text style={[styles.libraryDetailPinyin, themeStyles?.libraryDetailPinyin]}>{formatWordPinyin(word, studyMode)}</Text>
            )}
            <Text style={[styles.libraryDetailPronunciation, themeStyles?.libraryDetailPronunciation]}>
              {formatWordSecondary(word, studyMode)}
            </Text>
          </View>
          <View style={styles.libraryDetailActionStack}>
            <AnimatedPressable
              accessibilityLabel={ui.addToSetName(formatWordPrimary(word, studyMode))}
              accessibilityRole="button"
              onPress={() => onAddToSet(word)}
              pressTone="icon"
              style={styles.libraryDetailFavorite}
            >
              <SquarePlus size={21} color="#2563eb" strokeWidth={2.4} />
            </AnimatedPressable>
            <AnimatedPressable
              accessibilityLabel={
                favorite
                  ? ui.unfavoriteWordName(formatWordPrimary(word, studyMode))
                  : ui.favoriteWordName(formatWordPrimary(word, studyMode))
              }
              accessibilityRole="button"
              onPress={onFavorite}
              pressTone="icon"
              style={styles.libraryDetailFavorite}
            >
              <Star size={21} color={favorite ? '#f59e0b' : '#717987'} fill={favorite ? '#f59e0b' : 'transparent'} />
            </AnimatedPressable>
          </View>
        </View>

        <View style={styles.libraryDetailMetaRow}>
          <Text style={styles.libraryDetailBadge}>{word.group}</Text>
          <Text style={styles.libraryDetailBadge}>{word.partOfSpeech}</Text>
          <Text style={styles.libraryDetailBadge}>{statusLabel(wordProgress?.status, studyMode)}</Text>
        </View>

        <View style={[styles.libraryDetailSection, themeStyles?.libraryDetailSection]}>
          <Text style={[styles.libraryDetailLabel, themeStyles?.libraryDetailLabel]}>
            {studyMode === 'chinese' ? ui.englishCounterpart : ui.chineseMeaning}
          </Text>
          <Text style={[styles.libraryDetailMeaning, themeStyles?.libraryDetailMeaning]}>
            {formatMeaningDetail(word, studyMode)}
          </Text>
        </View>

        {formatMeaningSupplement(word, studyMode) && (
          <View style={[styles.libraryDetailSection, themeStyles?.libraryDetailSection]}>
            <Text style={[styles.libraryDetailLabel, themeStyles?.libraryDetailLabel]}>{ui.supplementalMeanings}</Text>
            <Text style={[styles.libraryDetailMeaning, themeStyles?.libraryDetailMeaning]}>
              {formatMeaningSupplement(word, studyMode)}
            </Text>
          </View>
        )}

        <View style={[styles.libraryDetailExampleCard, themeStyles?.libraryDetailExampleCard]}>
          <Text style={[styles.libraryDetailLabel, themeStyles?.libraryDetailLabel]}>
            {studyMode === 'chinese' ? ui.chineseExample : ui.englishExample}
          </Text>
          <Text style={[styles.libraryDetailExample, themeStyles?.libraryDetailExample]}>{formatExamplePrimary(word, studyMode)}</Text>
          <View style={[styles.libraryDetailDivider, themeStyles?.libraryDetailDivider]} />
          <Text style={[styles.libraryDetailLabel, themeStyles?.libraryDetailLabel]}>
            {studyMode === 'chinese' ? ui.englishExample : ui.chineseTranslation}
          </Text>
          <Text style={[styles.libraryDetailExampleZh, themeStyles?.libraryDetailExampleZh]}>
            {formatExampleSecondary(word, studyMode)}
          </Text>
        </View>
      </View>
    </View>
  );
}

function ProfileView({
  account,
  dailyPercent,
  developerMessage,
  developerVocabulary,
  panel,
  onEmailChange,
  onClearDeveloperVocabulary,
  onCloseSettings,
  onConfirmDeleteAccountData,
  onExportVocabulary,
  onImportVocabulary,
  onAppleSignIn,
  onGoogleSignIn,
  onOpenSettings,
  onOpenAppInfoLink,
  onPanelSwap,
  onPasswordChange,
  onShowInstallGuide,
  onSignIn,
  onSignOut,
  onSignUp,
  progress,
  stats,
  studyMode,
  themeMode,
  vocabularyCount,
  onThemeModeChange,
}: {
  account: AccountState;
  dailyPercent: number;
  developerMessage: string;
  developerVocabulary: DeveloperVocabularySnapshot | null;
  panel: ProfilePanel;
  progress: ProgressState;
  stats: ReturnType<typeof computeStats>;
  studyMode: StudyMode;
  themeMode: ThemeMode;
  vocabularyCount: number;
  onClearDeveloperVocabulary: () => void;
  onCloseSettings: () => void;
  onConfirmDeleteAccountData: () => void;
  onEmailChange: (email: string) => void;
  onExportVocabulary: () => void;
  onAppleSignIn: () => void;
  onGoogleSignIn: () => void;
  onImportVocabulary: () => void;
  onOpenSettings: () => void;
  onOpenAppInfoLink: (url: string) => void;
  onPanelSwap: () => void;
  onPasswordChange: (password: string) => void;
  onShowInstallGuide: () => void;
  onSignIn: () => void;
  onSignOut: () => void;
  onSignUp: () => void;
  onThemeModeChange: (themeMode: ThemeMode) => void;
}) {
  const themeStyles = useThemeStyles();
  const signedIn = Boolean(account.userId);
  const syncError = account.status === 'error';
  const bodyIconColor = themeMode === 'dark' ? '#e2e8f0' : '#172033';
  const ui = modeInterfaceCopy[studyMode];
  const showWebInstallGuidePanel = Platform.OS === 'web' && !IS_WEB_IOS_PREVIEW;
  const showAppleSignIn = Platform.OS === 'ios' || IS_WEB_IOS_PREVIEW;
  const [renderedProfilePanel, setRenderedProfilePanel] = useState<ProfilePanel>(panel);
  const profilePanelAnim = useRef(new Animated.Value(1)).current;

  useEffect(() => {
    let cancelled = false;
    const useNativeDriver = Platform.OS !== 'web';

    if (panel === renderedProfilePanel) {
      Animated.timing(profilePanelAnim, {
        duration: interactionMotion.settingsPanelMs,
        easing: Easing.out(Easing.cubic),
        toValue: 1,
        useNativeDriver,
      }).start();
      return () => {
        cancelled = true;
      };
    }

    Animated.timing(profilePanelAnim, {
      duration: interactionMotion.settingsPanelExitMs,
      easing: Easing.in(Easing.cubic),
      toValue: 0,
      useNativeDriver,
    }).start(({ finished }) => {
      if (finished && !cancelled) {
        profilePanelAnim.setValue(0);
        onPanelSwap();
        setRenderedProfilePanel(panel);
      }
    });

    return () => {
      cancelled = true;
    };
  }, [onPanelSwap, panel, profilePanelAnim, renderedProfilePanel]);

  const settingsPanelMotionStyle = {
    opacity: profilePanelAnim,
    transform: [
      {
        translateX: profilePanelAnim.interpolate({
          inputRange: [0, 1],
          outputRange: [renderedProfilePanel !== 'overview' ? 18 : -12, 0],
        }),
      },
      {
        scale: profilePanelAnim.interpolate({
          inputRange: [0, 1],
          outputRange: [0.985, 1],
        }),
      },
    ],
  };

  if (renderedProfilePanel === 'settings') {
    return (
      <Animated.View style={settingsPanelMotionStyle}>
        <ProfileSettingsView
          developerMessage={developerMessage}
          developerVocabulary={developerVocabulary}
          studyMode={studyMode}
          themeMode={themeMode}
          vocabularyCount={vocabularyCount}
          onBack={onCloseSettings}
          onClearDeveloperVocabulary={onClearDeveloperVocabulary}
          onConfirmDeleteAccountData={onConfirmDeleteAccountData}
          onExportVocabulary={onExportVocabulary}
          onImportVocabulary={onImportVocabulary}
          onOpenAppInfoLink={onOpenAppInfoLink}
          onThemeModeChange={onThemeModeChange}
          accountBusy={account.busy}
          signedIn={signedIn}
        />
      </Animated.View>
    );
  }

  return (
    <Animated.View style={settingsPanelMotionStyle}>
    <View style={styles.screenStack}>
      <View style={[styles.profileCard, themeStyles?.profileCard]}>
        <View style={[styles.avatar, themeStyles?.avatar]}>
          <User size={32} color={bodyIconColor} strokeWidth={2.2} />
        </View>
        <Text style={[styles.profileTitle, themeStyles?.profileTitle]}>{signedIn ? account.userEmail : ui.profileIdle}</Text>
        <Text style={[styles.profileText, themeStyles?.profileText]}>{ui.profileProgress(dailyPercent, stats.mastered)}</Text>
        <View style={[styles.syncPill, syncError && styles.syncPillError]}>
          <Cloud size={15} color={syncError ? '#b91c1c' : '#166534'} strokeWidth={2.3} />
          <Text style={[styles.syncText, syncError && styles.syncTextError]}>{accountMessageForMode(account.message, studyMode)}</Text>
        </View>
      </View>

      <View style={[styles.accountCard, themeStyles?.accountCard]}>
        <View style={styles.rowBetween}>
          <Text style={[styles.sectionTitle, themeStyles?.sectionTitle]}>{ui.account}</Text>
          <Text style={[styles.cardMeta, themeStyles?.cardMeta]}>{account.configured ? (signedIn ? ui.signedIn : ui.signedOut) : ui.local}</Text>
        </View>

        {!signedIn && (
          <View style={styles.inputStack}>
            {!account.configured && (
              <View style={[styles.localOnlyBox, themeStyles?.localOnlyBox]}>
                <Text style={[styles.localOnlyTitle, themeStyles?.localOnlyTitle]}>{ui.accountUnavailableTitle}</Text>
                <Text style={[styles.localOnlyText, themeStyles?.localOnlyText]}>{ui.accountUnavailableText}</Text>
              </View>
            )}
            <AnimatedPressable
              accessibilityLabel={ui.googleSignIn}
              accessibilityRole="button"
              disabled={!account.configured || account.busy}
              onPress={onGoogleSignIn}
              pressTone="primary"
              style={[styles.googleButton, themeStyles?.googleButton, (!account.configured || account.busy) && styles.disabledButton]}
            >
              <View style={[styles.googleIconMark, themeStyles?.googleIconMark]}>
                <LogIn size={18} color={bodyIconColor} strokeWidth={2.4} />
              </View>
              <View style={styles.flexOne}>
                <Text style={[styles.googleButtonTitle, themeStyles?.googleButtonTitle]}>{ui.googleSignIn}</Text>
                <Text style={[styles.googleButtonText, themeStyles?.googleButtonText]}>{ui.googleSignInHint}</Text>
              </View>
              <ChevronRight size={18} color={bodyIconColor} strokeWidth={2.4} />
            </AnimatedPressable>
            {showAppleSignIn && (
              <AnimatedPressable
                accessibilityLabel={ui.appleSignIn}
                accessibilityRole="button"
                disabled={!account.configured || account.busy}
                onPress={onAppleSignIn}
                pressTone="primary"
                style={[styles.appleButton, (!account.configured || account.busy) && styles.disabledButton]}
              >
                <View style={styles.appleIconMark}>
                  <Smartphone size={18} color="#fff" strokeWidth={2.4} />
                </View>
                <View style={styles.flexOne}>
                  <Text style={styles.appleButtonTitle}>{ui.appleSignIn}</Text>
                  <Text style={styles.appleButtonText}>{ui.appleSignInHint}</Text>
                </View>
                <ChevronRight size={18} color="#fff" strokeWidth={2.4} />
              </AnimatedPressable>
            )}
            <Text style={[styles.emailFallbackLabel, themeStyles?.emailFallbackLabel]}>{ui.emailFallback}</Text>
            <View style={[styles.inputBox, themeStyles?.inputBox]}>
              <Mail size={17} color="#717987" strokeWidth={2.2} />
              <TextInput
                autoCapitalize="none"
                editable={account.configured && !account.busy}
                keyboardType="email-address"
                onChangeText={onEmailChange}
                placeholder="Email"
                placeholderTextColor="#9ca3af"
                style={[styles.accountInput, themeStyles?.accountInput]}
                value={account.email}
              />
            </View>
            <View style={[styles.inputBox, themeStyles?.inputBox]}>
              <Lock size={17} color="#717987" strokeWidth={2.2} />
              <TextInput
                editable={account.configured && !account.busy}
                onChangeText={onPasswordChange}
                placeholder={ui.passwordPlaceholder}
                placeholderTextColor="#9ca3af"
                secureTextEntry
                style={[styles.accountInput, themeStyles?.accountInput]}
                value={account.password}
              />
            </View>
            <View style={styles.buttonRow}>
              <AnimatedPressable
                accessibilityRole="button"
                disabled={!account.configured || account.busy}
                onPress={onSignIn}
                pressTone="primary"
                style={[styles.accountButton, (!account.configured || account.busy) && styles.disabledButton]}
              >
                <LogIn size={17} color="#fff" strokeWidth={2.4} />
                <Text style={styles.accountButtonText}>{ui.signIn}</Text>
              </AnimatedPressable>
              <AnimatedPressable
                accessibilityRole="button"
                disabled={!account.configured || account.busy}
                onPress={onSignUp}
                pressTone="secondary"
                style={[styles.outlineButton, themeStyles?.outlineButton, (!account.configured || account.busy) && styles.disabledButton]}
              >
                <Text style={[styles.outlineButtonText, themeStyles?.outlineButtonText]}>{ui.signUp}</Text>
              </AnimatedPressable>
            </View>
          </View>
        )}

        {account.configured && signedIn && (
          <AnimatedPressable
            accessibilityRole="button"
            disabled={account.busy}
            onPress={onSignOut}
            pressTone="secondary"
            style={[styles.signOutButton, account.busy && styles.disabledButton]}
          >
            <LogOut size={17} color="#9a3412" strokeWidth={2.4} />
            <Text style={styles.signOutButtonText}>{ui.signOut}</Text>
          </AnimatedPressable>
        )}
      </View>

      <ProfileLearningExperiencePanel dailyPercent={dailyPercent} progress={progress} stats={stats} studyMode={studyMode} />

      {showWebInstallGuidePanel && (
        <ProfileTutorialPanel studyMode={studyMode} onShowInstallGuide={onShowInstallGuide} />
      )}

      <AnimatedPressable
        accessibilityLabel={ui.openSettings}
        accessibilityRole="button"
        onPress={onOpenSettings}
        pressTone="list"
        style={[styles.settingsEntryButton, themeStyles?.settingsEntryButton]}
      >
        <View style={[styles.settingsEntryIcon, themeStyles?.settingsEntryIcon]}>
          <Settings size={20} color={bodyIconColor} strokeWidth={2.3} />
        </View>
        <View style={styles.flexOne}>
          <Text style={[styles.settingsEntryTitle, themeStyles?.settingsEntryTitle]}>{ui.settings}</Text>
          <Text style={[styles.settingsEntryText, themeStyles?.settingsEntryText]}>{ui.settingsSummary}</Text>
        </View>
        <ChevronRight size={18} color="#64748b" strokeWidth={2.3} />
      </AnimatedPressable>
    </View>
    </Animated.View>
  );
}

function ProfileLearningExperiencePanel({
  dailyPercent,
  progress,
  studyMode,
  stats,
}: {
  dailyPercent: number;
  progress: ProgressState;
  studyMode: StudyMode;
  stats: ReturnType<typeof computeStats>;
}) {
  const themeStyles = useThemeStyles();
  const ui = modeInterfaceCopy[studyMode];

  return (
    <View style={[styles.profileInfoCard, themeStyles?.profileInfoCard]} testID="profile-learning-panel">
      <View style={styles.rowBetween}>
        <View>
          <Text style={[styles.sectionTitle, themeStyles?.sectionTitle]}>{ui.learningExperience}</Text>
          <Text style={[styles.cardMeta, themeStyles?.cardMeta]}>{ui.todayComplete(dailyPercent)}</Text>
        </View>
        <BookOpen size={21} color="#2563eb" strokeWidth={2.3} />
      </View>
      <View style={styles.learningMetricGrid}>
        <View style={[styles.learningMetric, themeStyles?.learningMetric]}>
          <Text style={[styles.learningMetricLabel, themeStyles?.learningMetricLabel]}>{ui.dailyTarget}</Text>
          <Text style={[styles.learningMetricValue, themeStyles?.learningMetricValue]}>{progress.dailyTarget} words</Text>
        </View>
        <View style={[styles.learningMetric, themeStyles?.learningMetric]}>
          <Text style={[styles.learningMetricLabel, themeStyles?.learningMetricLabel]}>{ui.favoriteWords}</Text>
          <Text style={[styles.learningMetricValue, themeStyles?.learningMetricValue]}>{stats.favorites}</Text>
        </View>
        <View style={[styles.learningMetric, themeStyles?.learningMetric]}>
          <Text style={[styles.learningMetricLabel, themeStyles?.learningMetricLabel]}>{ui.remainingSamples}</Text>
          <Text style={[styles.learningMetricValue, themeStyles?.learningMetricValue]}>{stats.remaining}</Text>
        </View>
      </View>
    </View>
  );
}

function ProfileTutorialPanel({ onShowInstallGuide, studyMode }: { onShowInstallGuide: () => void; studyMode: StudyMode }) {
  const themeStyles = useThemeStyles();
  const bodyIconColor = useContext(ThemeContext) === 'dark' ? '#e2e8f0' : '#172033';
  const ui = modeInterfaceCopy[studyMode];

  return (
    <AnimatedPressable
      accessibilityLabel={ui.replayTutorial}
      accessibilityRole="button"
      onPress={onShowInstallGuide}
      pressTone="list"
      style={[styles.settingsEntryButton, themeStyles?.settingsEntryButton]}
      testID="profile-tutorial-panel"
    >
      <View style={[styles.settingsEntryIcon, themeStyles?.settingsEntryIcon]}>
        <Smartphone size={20} color={bodyIconColor} strokeWidth={2.3} />
      </View>
      <View style={styles.flexOne}>
        <Text style={[styles.settingsEntryTitle, themeStyles?.settingsEntryTitle]}>{ui.tutorial}</Text>
        <Text style={[styles.settingsEntryText, themeStyles?.settingsEntryText]}>{ui.replayTutorial}</Text>
      </View>
      <ChevronRight size={18} color="#64748b" strokeWidth={2.3} />
    </AnimatedPressable>
  );
}

function ActiveSetBanner({
  count,
  name,
  onClear,
  studyMode,
}: {
  count: number;
  name: string;
  onClear: () => void;
  studyMode: StudyMode;
}) {
  const themeStyles = useThemeStyles();
  const ui = modeInterfaceCopy[studyMode];

  return (
    <View style={[styles.activeSetBanner, themeStyles?.activeSetBanner]}>
      <View style={styles.flexOne}>
        <Text style={[styles.activeSetTitle, themeStyles?.activeSetTitle]}>{ui.activeSet(name)}</Text>
        <Text style={[styles.activeSetText, themeStyles?.activeSetText]}>{ui.activeSetCount(count)}</Text>
      </View>
      <AnimatedPressable
        accessibilityRole="button"
        onPress={onClear}
        pressTone="chip"
        style={[styles.activeSetClearButton, themeStyles?.activeSetClearButton]}
      >
        <Text style={[styles.activeSetClearText, themeStyles?.activeSetClearText]}>{ui.clearActiveSet}</Text>
      </AnimatedPressable>
    </View>
  );
}

function CustomSetPickerOverlay({
  customSets,
  newSetName,
  onAddToSet,
  onClose,
  onCreateAndAdd,
  onNewSetNameChange,
  studyMode,
  word,
}: {
  customSets: CustomVocabSet[];
  newSetName: string;
  onAddToSet: (setId: string) => void;
  onClose: () => void;
  onCreateAndAdd: () => void;
  onNewSetNameChange: (name: string) => void;
  studyMode: StudyMode;
  word: WordEntry;
}) {
  const themeStyles = useThemeStyles();
  const darkMode = useContext(ThemeContext) === 'dark';
  const bodyIconColor = darkMode ? '#e2e8f0' : '#172033';
  const ui = modeInterfaceCopy[studyMode];
  const overlayAnim = useRef(new Animated.Value(0)).current;

  useEffect(() => {
    Animated.timing(overlayAnim, {
      duration: interactionMotion.settingsPanelMs,
      easing: Easing.out(Easing.cubic),
      toValue: 1,
      useNativeDriver: Platform.OS !== 'web',
    }).start();
  }, [overlayAnim]);

  const overlayMotion = {
    opacity: overlayAnim,
  };
  const cardMotion = {
    transform: [
      {
        translateY: overlayAnim.interpolate({
          inputRange: [0, 1],
          outputRange: [18, 0],
        }),
      },
      {
        scale: overlayAnim.interpolate({
          inputRange: [0, 1],
          outputRange: [0.98, 1],
        }),
      },
    ],
  };

  return (
    <Animated.View style={[styles.customSetOverlay, overlayMotion]} testID="custom-set-picker">
      <Animated.View style={[styles.customSetPickerCard, themeStyles?.customSetPickerCard, cardMotion]}>
        <View style={styles.rowBetween}>
          <View style={styles.flexOne}>
            <Text style={[styles.customSetPickerTitle, themeStyles?.customSetPickerTitle]}>
              {ui.setPickerTitle(formatWordPrimary(word, studyMode))}
            </Text>
            <Text style={[styles.customSetPickerText, themeStyles?.customSetPickerText]}>{ui.chooseCustomSet}</Text>
          </View>
          <AnimatedPressable accessibilityRole="button" onPress={onClose} pressTone="icon" style={styles.iconButton}>
            <X size={18} color={bodyIconColor} strokeWidth={2.5} />
          </AnimatedPressable>
        </View>

        <View style={styles.customSetCreateRow}>
          <View style={[styles.inputBox, themeStyles?.inputBox, styles.customSetNameInputBox]}>
            <TextInput
              onChangeText={onNewSetNameChange}
              placeholder={ui.newSetPlaceholder}
              placeholderTextColor="#9ca3af"
              style={[styles.accountInput, themeStyles?.accountInput]}
              value={newSetName}
            />
          </View>
          <AnimatedPressable
            accessibilityRole="button"
            onPress={onCreateAndAdd}
            pressTone="primary"
            style={styles.customSetCreateButton}
          >
            <SquarePlus size={16} color="#fff" strokeWidth={2.4} />
          </AnimatedPressable>
        </View>

        <View style={styles.customSetPickerList}>
          {customSets.length === 0 && (
            <Text style={[styles.customSetPickerEmpty, themeStyles?.customSetPickerEmpty]}>{ui.setPickerEmpty}</Text>
          )}
          {customSets.map((set) => (
            <AnimatedPressable
              accessibilityRole="button"
              key={set.id}
              onPress={() => onAddToSet(set.id)}
              pressTone="list"
              style={[styles.customSetPickerRow, themeStyles?.customSetPickerRow]}
            >
              <View style={[styles.customSetColorDot, { backgroundColor: set.color }]} />
              <View style={styles.flexOne}>
                <Text style={[styles.customSetRowTitle, themeStyles?.customSetRowTitle]}>{set.name}</Text>
                <Text style={[styles.customSetRowText, themeStyles?.customSetRowText]}>{ui.customSetCount(set.wordIds.length)}</Text>
              </View>
              <Text style={styles.customSetAddText}>{ui.addExistingWord}</Text>
            </AnimatedPressable>
          ))}
        </View>
      </Animated.View>
    </Animated.View>
  );
}

function ProfileCustomSetsView({
  backLabel,
  customSetMessage,
  customSetSort,
  customSets,
  customSetState,
  manualCustomWord,
  newSetName,
  onAddManualCustomWord,
  onBack,
  onCreateCustomSet,
  onCustomSetSelect,
  onCustomSetSortChange,
  onDeleteCustomSet,
  onImportCustomWords,
  onManualCustomWordChange,
  onNewSetNameChange,
  onRemoveWordFromSet,
  onRenameCustomSet,
  onStartQuizSet,
  onStartStudySet,
  selectedCustomSetId,
  studyMode,
  vocabularyWords,
}: {
  backLabel?: string;
  customSetMessage: string;
  customSetSort: CustomSetSort;
  customSets: CustomVocabSet[];
  customSetState: CustomSetState;
  manualCustomWord: ManualCustomWordState;
  newSetName: string;
  onAddManualCustomWord: () => void;
  onBack: () => void;
  onCreateCustomSet: () => void;
  onCustomSetSelect: (setId: string | null) => void;
  onCustomSetSortChange: (sort: CustomSetSort) => void;
  onDeleteCustomSet: (setId: string) => void;
  onImportCustomWords: () => void;
  onManualCustomWordChange: (field: keyof ManualCustomWordState, value: string) => void;
  onNewSetNameChange: (name: string) => void;
  onRemoveWordFromSet: (setId: string, word: WordEntry) => void;
  onRenameCustomSet: (setId: string, name: string) => void;
  onStartQuizSet: (setId: string) => void;
  onStartStudySet: (setId: string) => void;
  selectedCustomSetId: string | null;
  studyMode: StudyMode;
  vocabularyWords: WordEntry[];
}) {
  type CustomSetPanel = 'list' | 'detail';

  const themeStyles = useThemeStyles();
  const darkMode = useContext(ThemeContext) === 'dark';
  const bodyIconColor = darkMode ? '#e2e8f0' : '#172033';
  const ui = modeInterfaceCopy[studyMode];
  const [customSetPanel, setCustomSetPanel] = useState<CustomSetPanel>('list');
  const [renderedCustomSetPanel, setRenderedCustomSetPanel] = useState<CustomSetPanel>('list');
  const selectedSet = customSets.find((set) => set.id === selectedCustomSetId) ?? customSets[0] ?? null;
  const selectedSetWords = wordsForCustomSet(vocabularyWords, selectedSet);
  const [editingSetId, setEditingSetId] = useState<string | null>(selectedSet?.id ?? null);
  const [editingSetName, setEditingSetName] = useState(selectedSet?.name ?? '');
  const customSetPanelAnim = useRef(new Animated.Value(1)).current;
  const isDetailPanel = renderedCustomSetPanel === 'detail' && selectedSet;
  const customSetPanelEnteringX =
    renderedCustomSetPanel === 'list' ? -interactionMotion.panelSlideX : interactionMotion.panelSlideX;
  const customSetPanelMotionStyle = {
    opacity: customSetPanelAnim.interpolate({
      inputRange: [0, 0.2, 1],
      outputRange: [0, 0.74, 1],
    }),
    transform: [
      {
        translateX: customSetPanelAnim.interpolate({
          inputRange: [0, 1],
          outputRange: [customSetPanelEnteringX, 0],
        }),
      },
      {
        scale: customSetPanelAnim.interpolate({
          inputRange: [0, 1],
          outputRange: [interactionMotion.panelPushScale, 1],
        }),
      },
    ],
  };
  const sortOptions: Array<{ id: CustomSetSort; label: string }> = [
    { id: 'recent', label: ui.customSetSortRecent },
    { id: 'name', label: ui.customSetSortName },
    { id: 'manual', label: ui.customSetSortManual },
  ];

  useEffect(() => {
    if (!selectedSet) {
      setEditingSetId(null);
      setEditingSetName('');
      return;
    }

    setEditingSetId(selectedSet.id);
    setEditingSetName(selectedSet.name);
  }, [selectedSet?.id, selectedSet?.name]);

  useEffect(() => {
    if (customSetPanel === 'detail' && !selectedSet) {
      setCustomSetPanel('list');
    }
  }, [customSetPanel, selectedSet]);

  useEffect(() => {
    let cancelled = false;
    const useNativeDriver = Platform.OS !== 'web';

    if (customSetPanel === renderedCustomSetPanel) {
      Animated.timing(customSetPanelAnim, {
        duration: interactionMotion.settingsPanelMs,
        easing: Easing.out(Easing.cubic),
        toValue: 1,
        useNativeDriver,
      }).start();
      return () => {
        cancelled = true;
      };
    }

    Animated.timing(customSetPanelAnim, {
      duration: interactionMotion.settingsPanelExitMs,
      easing: Easing.in(Easing.cubic),
      toValue: 0,
      useNativeDriver,
    }).start(({ finished }) => {
      if (finished && !cancelled) {
        customSetPanelAnim.setValue(0);
        setRenderedCustomSetPanel(customSetPanel);
      }
    });

    return () => {
      cancelled = true;
    };
  }, [customSetPanel, customSetPanelAnim, renderedCustomSetPanel]);

  function openSetDetail(setId: string) {
    onCustomSetSelect(setId);
    setCustomSetPanel('detail');
  }

  function closeSetDetail() {
    setCustomSetPanel('list');
  }

  return (
    <View style={styles.screenStack} testID="profile-custom-sets-panel">
      <AnimatedPressable
        accessibilityRole="button"
        onPress={isDetailPanel ? closeSetDetail : onBack}
        pressTone="secondary"
        style={[styles.libraryDetailBack, themeStyles?.libraryDetailBack]}
      >
        <ChevronLeft size={18} color={bodyIconColor} strokeWidth={2.5} />
        <Text style={[styles.libraryDetailBackText, themeStyles?.libraryDetailBackText]}>
          {isDetailPanel ? ui.backToSets : backLabel ?? ui.backCustomSets}
        </Text>
      </AnimatedPressable>

      <Animated.View style={customSetPanelMotionStyle} testID="custom-set-panel-transition">
      {renderedCustomSetPanel === 'list' && (
        <View style={styles.screenStack} testID="custom-set-list-panel">
          <View style={[styles.customSetsHeroCard, themeStyles?.customSetsHeroCard]}>
            <View style={styles.rowBetween}>
              <View style={styles.flexOne}>
                <Text style={[styles.sectionTitle, themeStyles?.sectionTitle]}>{ui.setLibrary}</Text>
                <Text style={[styles.cardMeta, themeStyles?.cardMeta]}>{ui.setLibrarySummary}</Text>
              </View>
              <Library size={21} color="#2563eb" strokeWidth={2.3} />
            </View>
            <View style={styles.customSetCreateRow}>
              <View style={[styles.inputBox, themeStyles?.inputBox, styles.customSetNameInputBox]}>
                <TextInput
                  onChangeText={onNewSetNameChange}
                  placeholder={ui.newSetPlaceholder}
                  placeholderTextColor="#9ca3af"
                  style={[styles.accountInput, themeStyles?.accountInput]}
                  value={newSetName}
                />
              </View>
              <AnimatedPressable accessibilityRole="button" onPress={onCreateCustomSet} pressTone="primary" style={styles.customSetWideCreateButton}>
                <SquarePlus size={16} color="#fff" strokeWidth={2.4} />
                <Text style={styles.customSetWideCreateText}>{ui.createSet}</Text>
              </AnimatedPressable>
            </View>
            <Text style={[styles.developerMessage, themeStyles?.developerMessage]}>{customSetMessage}</Text>
          </View>

          <View style={styles.customSetSortRow}>
            {sortOptions.map((option) => {
              const selected = customSetSort === option.id;
              return (
                <AnimatedPressable
                  accessibilityRole="button"
                  key={option.id}
                  onPress={() => onCustomSetSortChange(option.id)}
                  pressTone="chip"
                  style={[styles.filterChip, themeStyles?.filterChip, selected && styles.filterChipActive]}
                >
                  <Text style={[styles.filterText, selected && styles.filterTextActive]}>{option.label}</Text>
                </AnimatedPressable>
              );
            })}
          </View>

          <View style={styles.customSetList}>
            {customSets.length === 0 && (
              <View style={[styles.emptyState, themeStyles?.emptyState]}>
                <Text style={[styles.emptyTitle, themeStyles?.emptyTitle]}>{ui.noCustomSets}</Text>
                <Text style={[styles.emptyText, themeStyles?.emptyText]}>{ui.customSetMessageDefault}</Text>
              </View>
            )}
            {customSets.map((set) => {
              const selected = selectedSet?.id === set.id;
              return (
                <View
                  key={set.id}
                  style={[styles.customSetCard, themeStyles?.customSetCard, selected && styles.customSetCardActive]}
                >
                  <View style={styles.customSetSelectHeader}>
                    <AnimatedPressable
                      accessibilityRole="button"
                      onPress={() => onCustomSetSelect(set.id)}
                      pressTone="list"
                      style={styles.customSetListMainButton}
                    >
                      <View style={styles.customSetTitleRow}>
                        <View style={[styles.customSetColorDot, { backgroundColor: set.color }]} />
                        <View>
                          <Text style={[styles.customSetRowTitle, themeStyles?.customSetRowTitle]}>{set.name}</Text>
                          <Text style={[styles.customSetRowText, themeStyles?.customSetRowText]}>{ui.customSetCount(set.wordIds.length)}</Text>
                        </View>
                      </View>
                      <Check size={17} color={selected ? '#2563eb' : 'transparent'} strokeWidth={2.5} />
                    </AnimatedPressable>
                    <AnimatedPressable
                      accessibilityLabel={`${ui.openSetSettings} ${set.name}`}
                      accessibilityRole="button"
                      onPress={() => openSetDetail(set.id)}
                      pressTone="secondary"
                      style={[styles.customSetSettingsButton, themeStyles?.customSetActionButton]}
                      testID="custom-set-settings-button"
                    >
                      <Settings size={17} color={bodyIconColor} strokeWidth={2.3} />
                    </AnimatedPressable>
                  </View>
                  <View style={styles.customSetActionRow}>
                    <AnimatedPressable accessibilityRole="button" onPress={() => onStartStudySet(set.id)} pressTone="secondary" style={[styles.customSetActionButton, themeStyles?.customSetActionButton]}>
                      <BookOpen size={16} color={bodyIconColor} strokeWidth={2.3} />
                      <Text style={[styles.customSetActionText, themeStyles?.customSetActionText]}>{ui.startSetStudy}</Text>
                    </AnimatedPressable>
                    <AnimatedPressable accessibilityRole="button" onPress={() => onStartQuizSet(set.id)} pressTone="primary" style={styles.customSetPrimaryActionButton}>
                      <Target size={16} color="#fff" strokeWidth={2.3} />
                      <Text style={styles.customSetPrimaryActionText}>{ui.startSetQuiz}</Text>
                    </AnimatedPressable>
                  </View>
                </View>
              );
            })}
          </View>
        </View>
      )}

      {renderedCustomSetPanel === 'detail' && selectedSet && (
        <View style={styles.screenStack} testID="custom-set-detail-panel">
          <View style={[styles.customSetsHeroCard, themeStyles?.customSetsHeroCard]}>
            <View style={styles.rowBetween}>
              <View style={styles.flexOne}>
                <Text style={[styles.sectionTitle, themeStyles?.sectionTitle]}>{selectedSet.name}</Text>
                <Text style={[styles.cardMeta, themeStyles?.cardMeta]}>{ui.customSetCount(selectedSet.wordIds.length)}</Text>
              </View>
              <Settings size={21} color="#2563eb" strokeWidth={2.3} />
            </View>
            <View style={styles.customSetDetailActions} testID="custom-set-detail-actions">
              <AnimatedPressable accessibilityRole="button" onPress={() => onStartStudySet(selectedSet.id)} pressTone="secondary" style={[styles.customSetActionButton, themeStyles?.customSetActionButton]}>
                <BookOpen size={16} color={bodyIconColor} strokeWidth={2.3} />
                <Text style={[styles.customSetActionText, themeStyles?.customSetActionText]}>{ui.startSetStudy}</Text>
              </AnimatedPressable>
              <AnimatedPressable accessibilityRole="button" onPress={() => onStartQuizSet(selectedSet.id)} pressTone="primary" style={styles.customSetPrimaryActionButton}>
                <Target size={16} color="#fff" strokeWidth={2.3} />
                <Text style={styles.customSetPrimaryActionText}>{ui.startSetQuiz}</Text>
              </AnimatedPressable>
              <AnimatedPressable
                accessibilityRole="button"
                onPress={() => {
                  closeSetDetail();
                  onDeleteCustomSet(selectedSet.id);
                }}
                pressTone="secondary"
                style={[styles.customSetDeleteButton, themeStyles?.customSetActionButton]}
                testID="custom-set-delete-button"
              >
                <Trash2 size={15} color="#b91c1c" strokeWidth={2.3} />
                <Text style={styles.customSetDeleteText}>{ui.deleteSet}</Text>
              </AnimatedPressable>
            </View>
          </View>

          <View style={[styles.customSetsHeroCard, themeStyles?.customSetsHeroCard]}>
            <Text style={[styles.sectionTitle, themeStyles?.sectionTitle]}>{ui.editSetName}</Text>
            <View style={styles.customSetEditRow}>
              <View style={[styles.inputBox, themeStyles?.inputBox, styles.customSetRenameInputBox]}>
                <TextInput
                  onChangeText={setEditingSetName}
                  placeholder={ui.editSetName}
                  placeholderTextColor="#9ca3af"
                  style={[styles.accountInput, themeStyles?.accountInput]}
                  testID="custom-set-rename-input"
                  value={editingSetId === selectedSet.id ? editingSetName : selectedSet.name}
                />
              </View>
              <AnimatedPressable
                accessibilityRole="button"
                disabled={!editingSetName.trim()}
                onPress={() => onRenameCustomSet(selectedSet.id, editingSetName)}
                pressTone="secondary"
                style={[styles.customSetActionButton, themeStyles?.customSetActionButton, !editingSetName.trim() && styles.disabledButton]}
              >
                <Text style={[styles.customSetActionText, themeStyles?.customSetActionText]}>{ui.saveSetName}</Text>
              </AnimatedPressable>
            </View>
            <Text style={[styles.developerMessage, themeStyles?.developerMessage]}>{customSetMessage}</Text>
          </View>

          <View style={[styles.customSetsHeroCard, themeStyles?.customSetsHeroCard]}>
            <Text style={[styles.sectionTitle, themeStyles?.sectionTitle]}>{ui.wordsInSet}</Text>
            <Text style={[styles.cardMeta, themeStyles?.cardMeta]}>{ui.customSetCount(selectedSet.wordIds.length)}</Text>
            <View style={styles.customSetWordList}>
              {selectedSetWords.length === 0 && (
                <Text style={[styles.customSetPickerEmpty, themeStyles?.customSetPickerEmpty]}>{ui.emptySetWords}</Text>
              )}
              {selectedSetWords.map((word) => (
                <View key={word.id} style={[styles.customSetWordRow, themeStyles?.customSetPickerRow]}>
                  <View style={styles.flexOne}>
                    <Text style={[styles.customSetRowTitle, themeStyles?.customSetRowTitle]}>{formatWordPrimary(word, studyMode)}</Text>
                    <Text style={[styles.customSetRowText, themeStyles?.customSetRowText]}>{formatMeaningDetail(word, studyMode)}</Text>
                  </View>
                  <AnimatedPressable
                    accessibilityRole="button"
                    onPress={() => onRemoveWordFromSet(selectedSet.id, word)}
                    pressTone="secondary"
                    style={styles.customSetRemoveWordButton}
                    testID="custom-set-remove-word"
                  >
                    <X size={15} color="#b91c1c" strokeWidth={2.5} />
                    <Text style={styles.customSetRemoveWordText}>{ui.removeFromSet}</Text>
                  </AnimatedPressable>
                </View>
              ))}
            </View>
          </View>

          <View style={[styles.customSetsHeroCard, themeStyles?.customSetsHeroCard]}>
            <Text style={[styles.sectionTitle, themeStyles?.sectionTitle]}>{ui.manualWordTitle}</Text>
            <Text style={[styles.cardMeta, themeStyles?.cardMeta]}>{ui.manualWordIntro}</Text>
            <View style={styles.customWordFormGrid}>
              <View style={[styles.inputBox, themeStyles?.inputBox]}>
                <TextInput
                  autoCapitalize="none"
                  onChangeText={(value) => onManualCustomWordChange('word', value)}
                  placeholder={ui.customWordWordPlaceholder}
                  placeholderTextColor="#9ca3af"
                  style={[styles.accountInput, themeStyles?.accountInput]}
                  value={manualCustomWord.word}
                />
              </View>
              <View style={[styles.inputBox, themeStyles?.inputBox]}>
                <TextInput
                  onChangeText={(value) => onManualCustomWordChange('meaningZh', value)}
                  placeholder={ui.customWordMeaningPlaceholder}
                  placeholderTextColor="#9ca3af"
                  style={[styles.accountInput, themeStyles?.accountInput]}
                  value={manualCustomWord.meaningZh}
                />
              </View>
              <View style={[styles.inputBox, themeStyles?.inputBox]}>
                <TextInput
                  onChangeText={(value) => onManualCustomWordChange('pronunciation', value)}
                  placeholder={ui.customWordPronunciationPlaceholder}
                  placeholderTextColor="#9ca3af"
                  style={[styles.accountInput, themeStyles?.accountInput]}
                  value={manualCustomWord.pronunciation}
                />
              </View>
              <View style={[styles.inputBox, themeStyles?.inputBox]}>
                <TextInput
                  onChangeText={(value) => onManualCustomWordChange('partOfSpeech', value)}
                  placeholder={ui.customWordPartPlaceholder}
                  placeholderTextColor="#9ca3af"
                  style={[styles.accountInput, themeStyles?.accountInput]}
                  value={manualCustomWord.partOfSpeech}
                />
              </View>
              <View style={[styles.inputBox, themeStyles?.inputBox, styles.customWordLongInput]}>
                <TextInput
                  onChangeText={(value) => onManualCustomWordChange('example', value)}
                  placeholder={ui.customWordExamplePlaceholder}
                  placeholderTextColor="#9ca3af"
                  style={[styles.accountInput, themeStyles?.accountInput]}
                  value={manualCustomWord.example}
                />
              </View>
              <View style={[styles.inputBox, themeStyles?.inputBox, styles.customWordLongInput]}>
                <TextInput
                  onChangeText={(value) => onManualCustomWordChange('exampleZh', value)}
                  placeholder={ui.customWordExampleZhPlaceholder}
                  placeholderTextColor="#9ca3af"
                  style={[styles.accountInput, themeStyles?.accountInput]}
                  value={manualCustomWord.exampleZh}
                />
              </View>
            </View>
            <View style={styles.buttonRow}>
              <AnimatedPressable
                accessibilityRole="button"
                onPress={onAddManualCustomWord}
                pressTone="primary"
                style={styles.developerPrimaryButton}
              >
                <SquarePlus size={16} color="#fff" strokeWidth={2.3} />
                <Text style={styles.developerPrimaryText}>{ui.addManualWord}</Text>
              </AnimatedPressable>
              <AnimatedPressable
                accessibilityRole="button"
                onPress={onImportCustomWords}
                pressTone="secondary"
                style={[styles.developerActionButton, themeStyles?.developerActionButton]}
              >
                <Upload size={16} color={bodyIconColor} strokeWidth={2.3} />
                <Text style={[styles.developerActionText, themeStyles?.developerActionText]}>{ui.importCustomCsv}</Text>
              </AnimatedPressable>
            </View>
            <Text style={[styles.customSetTinyMeta, themeStyles?.customSetTinyMeta]}>
              {customSetState.customWords.length} Custom
            </Text>
          </View>
        </View>
      )}
      </Animated.View>
    </View>
  );
}

function ProfileSettingsView({
  accountBusy,
  developerMessage,
  developerVocabulary,
  onBack,
  onClearDeveloperVocabulary,
  onConfirmDeleteAccountData,
  onExportVocabulary,
  onImportVocabulary,
  onOpenAppInfoLink,
  onThemeModeChange,
  signedIn,
  studyMode,
  themeMode,
  vocabularyCount,
}: {
  accountBusy: boolean;
  developerMessage: string;
  developerVocabulary: DeveloperVocabularySnapshot | null;
  signedIn: boolean;
  studyMode: StudyMode;
  themeMode: ThemeMode;
  vocabularyCount: number;
  onBack: () => void;
  onClearDeveloperVocabulary: () => void;
  onConfirmDeleteAccountData: () => void;
  onExportVocabulary: () => void;
  onImportVocabulary: () => void;
  onOpenAppInfoLink: (url: string) => void;
  onThemeModeChange: (themeMode: ThemeMode) => void;
}) {
  const themeStyles = useThemeStyles();
  const darkMode = themeMode === 'dark';
  const bodyIconColor = darkMode ? '#e2e8f0' : '#172033';
  const nextThemeMode = darkMode ? 'light' : 'dark';
  const toggleThemeMode = () => onThemeModeChange(nextThemeMode);
  const dangerIconColor = darkMode ? '#fca5a5' : '#b91c1c';
  const ui = modeInterfaceCopy[studyMode];

  return (
    <View style={styles.screenStack} testID="profile-settings-panel">
      <AnimatedPressable accessibilityRole="button" onPress={onBack} pressTone="secondary" style={[styles.libraryDetailBack, themeStyles?.libraryDetailBack]}>
        <ChevronLeft size={18} color={bodyIconColor} strokeWidth={2.5} />
        <Text style={[styles.libraryDetailBackText, themeStyles?.libraryDetailBackText]}>{ui.backProfile}</Text>
      </AnimatedPressable>

      <View style={[styles.settingsCard, themeStyles?.settingsCard]}>
        <View style={styles.rowBetween}>
          <View>
            <Text style={[styles.sectionTitle, themeStyles?.sectionTitle]}>{ui.appSettings}</Text>
            <Text style={[styles.cardMeta, themeStyles?.cardMeta]}>{ui.displayTools}</Text>
          </View>
          <Settings size={21} color="#2563eb" strokeWidth={2.3} />
        </View>

        <AnimatedPressable
          accessibilityLabel={ui.toggleDarkMode}
          accessibilityRole="switch"
          accessibilityState={{ checked: darkMode }}
          onPress={toggleThemeMode}
          pressTone="list"
          style={[styles.settingOptionRow, themeStyles?.settingOptionRow]}
        >
          <View style={[styles.settingOptionIcon, themeStyles?.settingsEntryIcon]}>
            {darkMode ? <Sun size={19} color="#fbbf24" strokeWidth={2.3} /> : <Moon size={19} color="#2563eb" strokeWidth={2.3} />}
          </View>
          <View style={styles.flexOne}>
            <Text style={[styles.settingsEntryTitle, themeStyles?.settingsEntryTitle]}>{ui.darkMode}</Text>
            <Text style={[styles.settingsEntryText, themeStyles?.settingsEntryText]}>
              {darkMode ? ui.darkModeOnText : ui.darkModeOffText}
            </Text>
          </View>
          <View
            pointerEvents="none"
            style={[styles.themeSwitchButton, darkMode && styles.themeSwitchButtonActive]}
          >
            <View style={[styles.themeSwitchDot, darkMode && styles.themeSwitchDotActive]} />
            <Text style={[styles.themeSwitchText, darkMode && styles.themeSwitchTextActive]}>{darkMode ? ui.on : ui.off}</Text>
          </View>
        </AnimatedPressable>
      </View>

      <View style={[styles.settingsCard, themeStyles?.settingsCard]}>
        <View style={styles.rowBetween}>
          <View>
            <Text style={[styles.sectionTitle, themeStyles?.sectionTitle]}>{ui.legalSupport}</Text>
            <Text style={[styles.cardMeta, themeStyles?.cardMeta]}>{ui.legalSupportSummary}</Text>
          </View>
          <Cloud size={21} color="#2563eb" strokeWidth={2.3} />
        </View>

        <AnimatedPressable
          accessibilityRole="link"
          onPress={() => onOpenAppInfoLink(appInfoLinks.privacy)}
          pressTone="list"
          style={[styles.settingsEntryButton, themeStyles?.settingsEntryButton]}
        >
          <View style={[styles.settingsEntryIcon, themeStyles?.settingsEntryIcon]}>
            <Lock size={19} color={bodyIconColor} strokeWidth={2.3} />
          </View>
          <View style={styles.flexOne}>
            <Text style={[styles.settingsEntryTitle, themeStyles?.settingsEntryTitle]}>{ui.privacyPolicy}</Text>
            <Text style={[styles.settingsEntryText, themeStyles?.settingsEntryText]}>{ui.privacyPolicyText}</Text>
          </View>
          <ChevronRight size={18} color="#64748b" strokeWidth={2.3} />
        </AnimatedPressable>

        <AnimatedPressable
          accessibilityRole="link"
          onPress={() => onOpenAppInfoLink(appInfoLinks.support)}
          pressTone="list"
          style={[styles.settingsEntryButton, themeStyles?.settingsEntryButton]}
        >
          <View style={[styles.settingsEntryIcon, themeStyles?.settingsEntryIcon]}>
            <Compass size={19} color={bodyIconColor} strokeWidth={2.3} />
          </View>
          <View style={styles.flexOne}>
            <Text style={[styles.settingsEntryTitle, themeStyles?.settingsEntryTitle]}>{ui.supportPage}</Text>
            <Text style={[styles.settingsEntryText, themeStyles?.settingsEntryText]}>{ui.supportPageText}</Text>
          </View>
          <ChevronRight size={18} color="#64748b" strokeWidth={2.3} />
        </AnimatedPressable>

        <AnimatedPressable
          accessibilityRole="button"
          disabled={!signedIn || accountBusy}
          onPress={onConfirmDeleteAccountData}
          pressTone="secondary"
          style={[styles.deleteAccountDataButton, themeStyles?.deleteAccountDataButton, (!signedIn || accountBusy) && styles.disabledButton]}
          testID="delete-account-data-button"
        >
          <Trash2 size={17} color={dangerIconColor} strokeWidth={2.4} />
          <View style={styles.flexOne}>
            <Text style={[styles.deleteAccountDataTitle, themeStyles?.deleteAccountDataTitle]}>{ui.deleteAccountData}</Text>
            <Text style={[styles.deleteAccountDataText, themeStyles?.deleteAccountDataText]}>{ui.deleteAccountDataText}</Text>
          </View>
        </AnimatedPressable>
      </View>

      <DeveloperVocabularyPanel
        developerMessage={developerMessage}
        developerVocabulary={developerVocabulary}
        studyMode={studyMode}
        vocabularyCount={vocabularyCount}
        onClearDeveloperVocabulary={onClearDeveloperVocabulary}
        onExportVocabulary={onExportVocabulary}
        onImportVocabulary={onImportVocabulary}
      />
    </View>
  );
}

function DeveloperVocabularyPanel({
  developerMessage,
  developerVocabulary,
  onClearDeveloperVocabulary,
  onExportVocabulary,
  onImportVocabulary,
  studyMode,
  vocabularyCount,
}: {
  developerMessage: string;
  developerVocabulary: DeveloperVocabularySnapshot | null;
  studyMode: StudyMode;
  vocabularyCount: number;
  onClearDeveloperVocabulary: () => void;
  onExportVocabulary: () => void;
  onImportVocabulary: () => void;
}) {
  const themeStyles = useThemeStyles();
  const bodyIconColor = useContext(ThemeContext) === 'dark' ? '#e2e8f0' : '#172033';
  const ui = modeInterfaceCopy[studyMode];

  return (
    <View style={[styles.developerCard, themeStyles?.developerCard]} testID="developer-vocabulary-panel">
      <View style={styles.rowBetween}>
        <View style={styles.flexOne}>
          <Text style={[styles.sectionTitle, themeStyles?.sectionTitle]}>{ui.developerPanel}</Text>
          <Text style={[styles.cardMeta, themeStyles?.cardMeta]}>{developerVocabulary ? ui.developerEnabled : ui.developerBuiltin}</Text>
        </View>
        <Database size={22} color="#2563eb" strokeWidth={2.3} />
      </View>

      <Text style={[styles.developerText, themeStyles?.developerText]}>{ui.developerIntro}</Text>

      <View style={[styles.developerStats, themeStyles?.developerStats]}>
        <View>
          <Text style={[styles.developerLabel, themeStyles?.developerLabel]}>{ui.currentLibrary}</Text>
          <Text style={[styles.developerValue, themeStyles?.developerValue]}>{vocabularyCount} {ui.rows}</Text>
        </View>
        <View>
          <Text style={[styles.developerLabel, themeStyles?.developerLabel]}>{ui.dataStatus}</Text>
          <Text style={[styles.developerValue, themeStyles?.developerValue]}>{developerVocabulary ? ui.localPreview : ui.builtInVersion}</Text>
        </View>
      </View>

      {developerVocabulary && <Text style={styles.developerSummary}>{developerVocabulary.summary}</Text>}
      <Text style={[styles.developerMessage, themeStyles?.developerMessage]}>{developerMessage}</Text>

      <View style={styles.buttonRow}>
        <AnimatedPressable accessibilityRole="button" onPress={onExportVocabulary} pressTone="secondary" style={[styles.developerActionButton, themeStyles?.developerActionButton]}>
          <Download size={16} color={bodyIconColor} strokeWidth={2.3} />
          <Text style={[styles.developerActionText, themeStyles?.developerActionText]}>{ui.exportCsv}</Text>
        </AnimatedPressable>
        <AnimatedPressable accessibilityRole="button" onPress={onImportVocabulary} pressTone="primary" style={styles.developerPrimaryButton}>
          <Upload size={16} color="#fff" strokeWidth={2.3} />
          <Text style={styles.developerPrimaryText}>{ui.importData}</Text>
        </AnimatedPressable>
      </View>

      <AnimatedPressable
        accessibilityRole="button"
        disabled={!developerVocabulary}
        onPress={onClearDeveloperVocabulary}
        pressTone="secondary"
        style={[styles.developerClearButton, !developerVocabulary && styles.disabledButton]}
      >
        <Trash2 size={16} color="#9a3412" strokeWidth={2.3} />
        <Text style={styles.developerClearText}>{ui.clearPreview}</Text>
      </AnimatedPressable>
    </View>
  );
}

function StatCard({ label, tone, value }: { label: string; tone: 'blue' | 'green' | 'orange'; value: string }) {
  const themeStyles = useThemeStyles();

  return (
    <View style={[styles.statCard, styles[`${tone}Tint`], themeStyles?.statCard]}>
      <Text style={[styles.statValue, themeStyles?.statValue]}>{value}</Text>
      <Text style={[styles.statLabel, themeStyles?.statLabel]}>{label}</Text>
    </View>
  );
}

function statusLabel(status?: string, studyMode: StudyMode = 'english') {
  const ui = modeInterfaceCopy[studyMode];
  if (status === 'mastered') {
    return ui.filterLabels.mastered;
  }
  if (status === 'review') {
    return ui.filterLabels.review;
  }
  return ui.filterLabels.new;
}

function buildLevelFilters(words: WordEntry[]): FilterOption[] {
  return [
    { id: 'all', label: '全部分級' },
    ...Array.from(new Set(words.map((word) => word.group))).map((group) => ({
      id: group,
      label: group.replace('Core ', 'L'),
    })),
  ];
}

function filterSummary(
  filter: LibraryFilter,
  level: string,
  initial: string,
  showStatus: boolean,
  studyMode: StudyMode,
  levelOptions = levelFilters,
  sort?: LibrarySort,
): string {
  const parts = [levelLabel(level, studyMode, levelOptions), initialLabel(initial, studyMode)];
  if (sort) {
    parts.push(sortLabel(sort, studyMode));
  }
  if (showStatus) {
    parts.unshift(filterLabel(filter, studyMode));
  }
  return parts.join(' / ');
}

function filterLabel(filter: LibraryFilter, studyMode: StudyMode = 'english'): string {
  return modeInterfaceCopy[studyMode].filterLabels[filter] ?? modeInterfaceCopy[studyMode].filterLabels.all;
}

function levelLabel(level: string, studyMode: StudyMode = 'english', levelOptions = levelFilters): string {
  if (level === 'all') {
    return modeInterfaceCopy[studyMode].allLevels;
  }
  return levelOptions.find((item) => item.id === level)?.label ?? modeInterfaceCopy[studyMode].allLevels;
}

function initialLabel(initial: string, studyMode: StudyMode = 'english'): string {
  if (initial === 'all') {
    return modeInterfaceCopy[studyMode].allInitials;
  }
  return alphabetFilters.find((item) => item.id === initial)?.label ?? modeInterfaceCopy[studyMode].allInitials;
}

function sortLabel(sort: LibrarySort, studyMode: StudyMode = 'english'): string {
  const ui = modeInterfaceCopy[studyMode];
  return sort === 'alphabetical' ? ui.sortAlphabetical : ui.sortDefault;
}

function developerVocabularyMessageForMode(message: string, studyMode: StudyMode): string {
  if (studyMode !== 'chinese') {
    return message;
  }

  const staticMessages: Record<string, string> = {
    '匯入檔案是空的。': 'The import file is empty.',
    'JSON 需要是陣列，或包含 words 陣列。': 'JSON must be an array or include a words array.',
    'JSON 格式無法讀取。': 'Could not read the JSON format.',
    'CSV 至少需要標題列和一筆資料。': 'CSV needs a header row and at least one data row.',
    'CSV 需要 word 或 id 欄位，才能對應要修改的單字。': 'CSV needs a word or id column so rows can be matched.',
  };
  if (staticMessages[message]) {
    return staticMessages[message];
  }

  const displayRowName = (rowName: string) => rowName.replace(/^第 (\d+) 筆$/, 'row $1');
  const missingFields = message.match(/^(.+) 不是既有單字，也缺少新增單字需要的完整欄位。$/);
  if (missingFields) {
    return `${displayRowName(missingFields[1])} is not an existing word and is missing required fields for a new word.`;
  }

  const duplicateRow = message.match(/^(.+) 的 id 或單字重複。$/);
  if (duplicateRow) {
    return `${displayRowName(duplicateRow[1])} has a duplicate id or word.`;
  }

  return message;
}

function accountMessageForMode(message: string, studyMode: StudyMode): string {
  if (studyMode !== 'chinese') {
    return message;
  }

  const messages: Record<string, string> = {
    本機記憶中: 'Saved locally',
    檢查登入狀態: 'Checking sign-in',
    未登入: 'Signed out',
    同步中: 'Syncing',
    已保存到帳號: 'Saved to account',
    已登入: 'Signed in',
    已建立新的帳號記憶: 'Created fresh account memory',
    '正在開啟 Google 登入': 'Opening Google sign-in',
    '請完成 Google 登入': 'Complete Google sign-in',
    '無法開啟手機登入流程': 'Could not open mobile sign-in',
    已取消登入: 'Sign-in canceled',
    '正在開啟 Apple 登入': 'Opening Apple sign-in',
    'Apple 登入在網頁預覽中只顯示入口': 'Apple sign-in is shown here for iPhone preview',
    'Apple 登入只能在 iPhone App 使用': 'Apple sign-in is only available in the iPhone app',
    '此裝置目前無法使用 Apple 登入': 'Apple sign-in is not available on this device',
    'Apple 登入沒有回傳帳號憑證': 'Apple sign-in did not return account credentials',
    'Apple 登入失敗': 'Apple sign-in failed',
    登入導回失敗: 'Sign-in redirect failed',
    登入導回沒有取得帳號資料: 'The sign-in redirect did not return account data',
    請先登入: 'Please sign in first',
    正在刪除帳號學習資料: 'Deleting account learning data',
    帳號學習資料已刪除: 'Account learning data deleted',
    無法開啟連結: 'Could not open link',
    建立帳號中: 'Creating account',
    請確認信箱後登入: 'Check your email, then sign in',
    'Email 和密碼至少 6 碼': 'Email and password need at least 6 characters',
    '請輸入 Email 和密碼': 'Enter email and password',
    登入中: 'Signing in',
    登入失敗: 'Sign-in failed',
    已登出: 'Signed out',
  };
  return messages[message] ?? message;
}

const styles = StyleSheet.create({
  safeArea: {
    flex: 1,
    backgroundColor: '#eef2f7',
  },
  webIosPreviewSafeArea: {
    alignItems: 'center',
    backgroundColor: '#0f172a',
    justifyContent: 'center',
    paddingHorizontal: 16,
    paddingVertical: 18,
  },
  appStorageBootScreen: {
    alignItems: 'center',
    backgroundColor: '#f8fafc',
    flex: 1,
    gap: 12,
    justifyContent: 'center',
    padding: 28,
  },
  appStorageBootTitle: {
    color: '#172033',
    fontSize: 27,
    fontWeight: '900',
    marginTop: 6,
  },
  appStorageBootText: {
    color: '#64748b',
    fontSize: 14,
    fontWeight: '700',
    textAlign: 'center',
  },
  appShell: {
    alignSelf: 'center',
    backgroundColor: '#f8fafc',
    flex: 1,
    maxWidth: 760,
    width: '100%',
  },
  webIosPreviewAppShell: {
    borderColor: '#1f2937',
    borderRadius: 30,
    borderWidth: 1,
    maxHeight: 852,
    maxWidth: 393,
    overflow: 'hidden',
    shadowColor: '#000',
    shadowOffset: { height: 20, width: 0 },
    shadowOpacity: 0.26,
    shadowRadius: 34,
  },
  webIosPreviewScroll: {
    marginBottom: WEB_IOS_PREVIEW_SCROLL_BOTTOM_INSET,
  },
  header: {
    alignItems: 'center',
    flexDirection: 'row',
    justifyContent: 'space-between',
    paddingHorizontal: 22,
    paddingTop: 18,
    paddingBottom: 12,
  },
  headerActions: {
    alignItems: 'flex-end',
    gap: 6,
  },
  brand: {
    color: '#172033',
    fontSize: 26,
    fontWeight: '800',
  },
  headerSubtext: {
    color: '#717987',
    fontSize: 13,
    marginTop: 3,
  },
  levelPill: {
    alignItems: 'center',
    backgroundColor: '#ecfdf3',
    borderColor: '#bbf7d0',
    borderRadius: 8,
    borderWidth: 1,
    flexDirection: 'row',
    gap: 6,
    paddingHorizontal: 10,
    paddingVertical: 8,
  },
  levelText: {
    color: '#166534',
    fontSize: 13,
    fontWeight: '700',
  },
  previewModePill: {
    alignItems: 'center',
    backgroundColor: '#eff6ff',
    borderColor: '#bfdbfe',
    borderRadius: 8,
    borderWidth: 1,
    flexDirection: 'row',
    gap: 5,
    paddingHorizontal: 8,
    paddingVertical: 6,
  },
  previewModeText: {
    color: '#1d4ed8',
    fontSize: 11,
    fontWeight: '900',
  },
  updateBanner: {
    alignItems: 'center',
    backgroundColor: '#eff6ff',
    borderBottomColor: '#bfdbfe',
    borderBottomWidth: 1,
    flexDirection: 'row',
    gap: 10,
    justifyContent: 'space-between',
    paddingHorizontal: 18,
    paddingVertical: 10,
  },
  updateText: {
    color: '#1d4ed8',
    flex: 1,
    fontSize: 13,
    fontWeight: '800',
  },
  updateButton: {
    backgroundColor: '#172033',
    borderRadius: 8,
    paddingHorizontal: 12,
    paddingVertical: 8,
  },
  updateButtonText: {
    color: '#fff',
    fontSize: 13,
    fontWeight: '900',
  },
  updateRequiredOverlay: {
    alignItems: 'center',
    backgroundColor: 'rgba(15, 23, 42, 0.78)',
    bottom: 0,
    justifyContent: 'center',
    left: 0,
    padding: 22,
    position: 'absolute',
    right: 0,
    top: 0,
    zIndex: 95,
  },
  updateRequiredCard: {
    alignItems: 'center',
    backgroundColor: '#fff',
    borderColor: '#bfdbfe',
    borderRadius: 8,
    borderWidth: 1,
    maxWidth: 420,
    paddingHorizontal: 22,
    paddingVertical: 24,
    shadowColor: '#172033',
    shadowOffset: { height: 18, width: 0 },
    shadowOpacity: 0.2,
    shadowRadius: 30,
    width: '100%',
  },
  updateRequiredIcon: {
    alignItems: 'center',
    backgroundColor: '#eff6ff',
    borderColor: '#bfdbfe',
    borderRadius: 8,
    borderWidth: 1,
    height: 58,
    justifyContent: 'center',
    width: 58,
  },
  updateRequiredTitle: {
    color: '#172033',
    fontSize: 21,
    fontWeight: '900',
    marginTop: 16,
    textAlign: 'center',
  },
  updateRequiredText: {
    color: '#64748b',
    fontSize: 14,
    fontWeight: '700',
    lineHeight: 21,
    marginTop: 10,
    textAlign: 'center',
  },
  updateRequiredCountdown: {
    color: '#1d4ed8',
    fontSize: 15,
    fontWeight: '900',
    marginTop: 16,
  },
  updateRequiredButton: {
    alignItems: 'center',
    backgroundColor: '#2563eb',
    borderRadius: 8,
    flexDirection: 'row',
    gap: 8,
    justifyContent: 'center',
    marginTop: 16,
    minHeight: 48,
    paddingHorizontal: 18,
    width: '100%',
  },
  updateRequiredButtonText: {
    color: '#fff',
    fontSize: 15,
    fontWeight: '900',
  },
  content: {
    padding: 18,
    paddingBottom: IOS_CONTENT_BOTTOM_PADDING,
  },
  screenMotion: {
    gap: 14,
  },
  libraryPanelHidden: {
    opacity: 0,
    transform: [{ translateX: -12 }, { scale: 0.985 }],
  },
  launchOverlay: {
    alignItems: 'center',
    backgroundColor: '#f8fafc',
    bottom: 0,
    justifyContent: 'center',
    left: 0,
    paddingHorizontal: 24,
    position: 'absolute',
    right: 0,
    top: 0,
    zIndex: 60,
  },
  themeTransitionOverlay: {
    bottom: 0,
    left: 0,
    position: 'absolute',
    right: 0,
    top: 0,
    zIndex: 70,
  },
  launchIcon: {
    alignItems: 'center',
    backgroundColor: '#2563eb',
    borderColor: '#bfdbfe',
    borderRadius: 8,
    borderWidth: 1,
    height: 82,
    justifyContent: 'center',
    overflow: 'hidden',
    shadowColor: '#172033',
    shadowOffset: { height: 14, width: 0 },
    shadowOpacity: 0.2,
    shadowRadius: 24,
    width: 82,
  },
  launchDot: {
    backgroundColor: '#f97316',
    borderRadius: 99,
    height: 18,
    position: 'absolute',
    right: 10,
    top: 10,
    width: 18,
  },
  launchIconText: {
    color: '#fff',
    fontSize: 30,
    fontWeight: '900',
  },
  launchTitle: {
    color: '#172033',
    fontSize: 24,
    fontWeight: '900',
    marginTop: 14,
  },
  launchText: {
    color: '#64748b',
    fontSize: 14,
    fontWeight: '700',
    marginTop: 4,
  },
  launchBar: {
    backgroundColor: '#dbeafe',
    borderRadius: 99,
    height: 5,
    marginTop: 18,
    overflow: 'hidden',
    width: 112,
  },
  launchBarFill: {
    backgroundColor: '#2563eb',
    borderRadius: 99,
    height: 5,
    width: '68%',
  },
  installGuideOverlay: {
    backgroundColor: '#f8fafc',
    bottom: 0,
    gap: 18,
    justifyContent: 'space-between',
    left: 0,
    paddingHorizontal: 22,
    paddingVertical: 24,
    position: 'absolute',
    right: 0,
    top: 0,
    zIndex: 80,
  },
  installGuideMain: {
    flex: 1,
    gap: 18,
    justifyContent: 'flex-start',
    paddingTop: 80,
  },
  installGuideTopBar: {
    alignItems: 'center',
    flexDirection: 'row',
    justifyContent: 'space-between',
  },
  installGuideLogo: {
    alignItems: 'center',
    backgroundColor: '#2563eb',
    borderColor: '#bfdbfe',
    borderRadius: 8,
    borderWidth: 1,
    height: 48,
    justifyContent: 'center',
    overflow: 'hidden',
    width: 48,
  },
  installGuideLogoDot: {
    backgroundColor: '#f97316',
    borderRadius: 99,
    height: 11,
    position: 'absolute',
    right: 6,
    top: 6,
    width: 11,
  },
  installGuideLogoText: {
    color: '#fff',
    fontSize: 18,
    fontWeight: '900',
  },
  installGuideClose: {
    alignItems: 'center',
    backgroundColor: '#fff',
    borderColor: '#e5e7eb',
    borderRadius: 8,
    borderWidth: 1,
    height: 42,
    justifyContent: 'center',
    width: 42,
  },
  installGuideCard: {
    alignItems: 'center',
    backgroundColor: '#fff',
    borderColor: '#dbeafe',
    borderRadius: 8,
    borderWidth: 1,
    gap: 12,
    padding: 20,
    shadowColor: '#172033',
    shadowOffset: { height: 12, width: 0 },
    shadowOpacity: 0.08,
    shadowRadius: 22,
  },
  installGuideStepPill: {
    backgroundColor: '#eff6ff',
    borderColor: '#bfdbfe',
    borderRadius: 8,
    borderWidth: 1,
    paddingHorizontal: 10,
    paddingVertical: 6,
  },
  installGuideStepText: {
    color: '#1d4ed8',
    fontSize: 12,
    fontWeight: '900',
  },
  installGuideIconWrap: {
    alignItems: 'center',
    backgroundColor: '#eff6ff',
    borderColor: '#bfdbfe',
    borderRadius: 8,
    borderWidth: 1,
    height: 108,
    justifyContent: 'center',
    marginTop: 4,
    overflow: 'hidden',
    width: 108,
  },
  installGuideIconGlow: {
    backgroundColor: '#dbeafe',
    borderRadius: 99,
    height: 84,
    position: 'absolute',
    width: 84,
    zIndex: 0,
  },
  installGuideIconGraphic: {
    alignItems: 'center',
    justifyContent: 'center',
    zIndex: 1,
  },
  installGuideCopyBlock: {
    alignItems: 'center',
    gap: 8,
  },
  installGuideTitle: {
    color: '#172033',
    fontSize: 25,
    fontWeight: '900',
    lineHeight: 31,
    marginTop: 4,
    textAlign: 'center',
  },
  installGuideText: {
    color: '#5f6675',
    fontSize: 15,
    lineHeight: 23,
    textAlign: 'center',
  },
  installGuidePreview: {
    alignSelf: 'stretch',
    backgroundColor: '#f8fafc',
    borderColor: '#e5e7eb',
    borderRadius: 8,
    borderWidth: 1,
    marginTop: 4,
    padding: 12,
  },
  installGuideBrowserBar: {
    alignSelf: 'center',
    backgroundColor: '#cbd5e1',
    borderRadius: 99,
    height: 5,
    marginBottom: 12,
    width: 86,
  },
  installGuidePreviewRow: {
    flexDirection: 'row',
    gap: 8,
    justifyContent: 'center',
  },
  installGuideMiniStep: {
    alignItems: 'center',
    backgroundColor: '#fff',
    borderColor: '#e5e7eb',
    borderRadius: 8,
    borderWidth: 1,
    height: 34,
    justifyContent: 'center',
    width: 34,
  },
  installGuideMiniStepActive: {
    backgroundColor: '#2563eb',
    borderColor: '#2563eb',
  },
  installGuideStepProgress: {
    shadowColor: '#2563eb',
    shadowOffset: { height: 3, width: 0 },
    shadowOpacity: 0.16,
    shadowRadius: 7,
    transform: [{ scale: 1.08 }],
  },
  installGuideMiniText: {
    color: '#64748b',
    fontSize: 13,
    fontWeight: '900',
  },
  installGuideMiniTextActive: {
    color: '#fff',
  },
  installGuideDots: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: 7,
    justifyContent: 'center',
  },
  installGuideDot: {
    backgroundColor: '#cbd5e1',
    borderRadius: 99,
    height: 7,
    width: 7,
  },
  installGuideDotActive: {
    backgroundColor: '#2563eb',
    width: 22,
  },
  installGuideActions: {
    flexDirection: 'row',
    gap: 10,
  },
  installGuideSecondary: {
    alignItems: 'center',
    backgroundColor: '#fff',
    borderColor: '#cbd5e1',
    borderRadius: 8,
    borderWidth: 1,
    flex: 1,
    justifyContent: 'center',
    minHeight: 50,
    paddingHorizontal: 12,
  },
  installGuideSecondaryText: {
    color: '#172033',
    fontSize: 14,
    fontWeight: '900',
    textAlign: 'center',
  },
  installGuidePrimary: {
    alignItems: 'center',
    backgroundColor: '#172033',
    borderRadius: 8,
    flex: 1,
    flexDirection: 'row',
    gap: 6,
    justifyContent: 'center',
    minHeight: 50,
    paddingHorizontal: 12,
  },
  installGuidePrimaryText: {
    color: '#fff',
    fontSize: 15,
    fontWeight: '900',
  },
  modeSwitchBackdrop: {
    alignItems: 'center',
    backgroundColor: '#dbeafe',
    bottom: 0,
    justifyContent: 'center',
    left: 0,
    padding: 24,
    position: 'absolute',
    right: 0,
    top: 0,
    zIndex: 90,
  },
  modeSwitchPanel: {
    alignItems: 'center',
    backgroundColor: '#eff6ff',
    borderColor: '#bfdbfe',
    borderRadius: 8,
    borderWidth: 1,
    elevation: 8,
    gap: 8,
    maxWidth: 420,
    padding: 24,
    shadowColor: '#172033',
    shadowOffset: { height: 10, width: 0 },
    shadowOpacity: 0.16,
    shadowRadius: 22,
    width: '100%',
  },
  modeSwitchPanelChinese: {
    backgroundColor: '#ecfdf5',
    borderColor: '#99f6e4',
  },
  modeSwitchOverlayChinese: {
    backgroundColor: '#ecfdf5',
  },
  modeSwitchOverlayIcon: {
    alignItems: 'center',
    backgroundColor: '#fff',
    borderColor: '#bfdbfe',
    borderRadius: 8,
    borderWidth: 1,
    height: 70,
    justifyContent: 'center',
    width: 70,
  },
  modeSwitchOverlayIconChinese: {
    borderColor: '#99f6e4',
  },
  modeSwitchOverlayTitle: {
    color: '#172033',
    fontSize: 24,
    fontWeight: '900',
  },
  modeSwitchOverlayText: {
    color: '#475569',
    fontSize: 14,
    fontWeight: '800',
    textAlign: 'center',
  },
  screenStack: {
    gap: 14,
  },
  homeStack: {
    gap: 12,
  },
  hero: {
    backgroundColor: '#fff7ed',
    borderColor: '#fed7aa',
    borderRadius: 8,
    borderWidth: 1,
    flexDirection: 'row',
    gap: 14,
    justifyContent: 'space-between',
    padding: 18,
  },
  heroCopy: {
    flex: 1,
  },
  eyebrow: {
    color: '#d97706',
    fontSize: 12,
    fontWeight: '800',
    marginBottom: 8,
  },
  heroTitle: {
    color: '#172033',
    fontSize: 32,
    fontWeight: '900',
    lineHeight: 36,
  },
  heroText: {
    color: '#5f6675',
    fontSize: 14,
    lineHeight: 21,
    marginTop: 10,
  },
  ring: {
    alignItems: 'center',
    alignSelf: 'center',
    backgroundColor: '#ffffff',
    borderColor: '#fdba74',
    borderRadius: 8,
    borderWidth: 1,
    height: 92,
    justifyContent: 'center',
    width: 92,
  },
  ringValue: {
    color: '#172033',
    fontSize: 24,
    fontWeight: '900',
  },
  ringLabel: {
    color: '#717987',
    fontSize: 12,
    marginTop: 2,
  },
  modeSwitchButton: {
    alignItems: 'center',
    backgroundColor: '#eff6ff',
    borderColor: '#bfdbfe',
    borderRadius: 8,
    borderWidth: 1,
    flexDirection: 'row',
    gap: 12,
    minHeight: 72,
    padding: 14,
  },
  modeSwitchButtonChinese: {
    backgroundColor: '#ecfdf5',
    borderColor: '#99f6e4',
  },
  modeSwitchIcon: {
    alignItems: 'center',
    backgroundColor: '#fff',
    borderColor: '#bfdbfe',
    borderRadius: 8,
    borderWidth: 1,
    height: 44,
    justifyContent: 'center',
    width: 44,
  },
  modeSwitchIconChinese: {
    borderColor: '#99f6e4',
  },
  modeSwitchTitle: {
    color: '#172033',
    fontSize: 16,
    fontWeight: '900',
  },
  modeSwitchText: {
    color: '#5f6675',
    fontSize: 12,
    fontWeight: '700',
    lineHeight: 17,
    marginTop: 3,
  },
  progressCard: {
    backgroundColor: '#fff',
    borderColor: '#e5e7eb',
    borderRadius: 8,
    borderWidth: 1,
    gap: 12,
    padding: 15,
  },
  rowBetween: {
    alignItems: 'center',
    flexDirection: 'row',
    justifyContent: 'space-between',
  },
  sectionTitle: {
    color: '#172033',
    fontSize: 15,
    fontWeight: '700',
  },
  cardMeta: {
    color: '#717987',
    fontSize: 13,
    fontWeight: '700',
  },
  progressTrack: {
    backgroundColor: '#e5e7eb',
    borderRadius: 8,
    height: 9,
    overflow: 'hidden',
  },
  progressFill: {
    backgroundColor: '#f97316',
    borderRadius: 8,
    height: '100%',
  },
  primaryButton: {
    alignItems: 'center',
    backgroundColor: '#172033',
    borderRadius: 8,
    flexDirection: 'row',
    gap: 8,
    justifyContent: 'center',
    minHeight: 48,
    paddingHorizontal: 16,
  },
  primaryButtonText: {
    color: '#fff',
    fontSize: 15,
    fontWeight: '800',
  },
  accountShortcut: {
    alignItems: 'center',
    backgroundColor: '#f8fafc',
    borderColor: '#e5e7eb',
    borderRadius: 8,
    borderWidth: 1,
    flexDirection: 'row',
    gap: 7,
    justifyContent: 'center',
    minHeight: 42,
    paddingHorizontal: 12,
  },
  accountShortcutText: {
    color: '#172033',
    fontSize: 14,
    fontWeight: '800',
  },
  statsGrid: {
    flexDirection: 'row',
    gap: 10,
  },
  statCard: {
    borderRadius: 8,
    flex: 1,
    padding: 13,
  },
  blueTint: {
    backgroundColor: '#eff6ff',
    borderColor: '#bfdbfe',
    borderWidth: 1,
  },
  greenTint: {
    backgroundColor: '#ecfdf3',
    borderColor: '#bbf7d0',
    borderWidth: 1,
  },
  orangeTint: {
    backgroundColor: '#fff7ed',
    borderColor: '#fed7aa',
    borderWidth: 1,
  },
  statValue: {
    color: '#172033',
    fontSize: 24,
    fontWeight: '900',
  },
  statLabel: {
    color: '#717987',
    fontSize: 12,
    marginTop: 4,
  },
  reviewStrip: {
    alignItems: 'center',
    backgroundColor: '#fff',
    borderColor: '#e5e7eb',
    borderRadius: 8,
    borderWidth: 1,
    flexDirection: 'row',
    gap: 12,
    padding: 14,
  },
  reviewTitle: {
    color: '#172033',
    fontSize: 15,
    fontWeight: '800',
  },
  reviewText: {
    color: '#717987',
    fontSize: 13,
    marginTop: 3,
  },
  flexOne: {
    flex: 1,
  },
  wordCard: {
    backgroundColor: '#fff',
    borderColor: '#e5e7eb',
    borderRadius: 8,
    borderWidth: 1,
    gap: 14,
    padding: 18,
  },
  groupPill: {
    alignSelf: 'flex-start',
    backgroundColor: '#eff6ff',
    borderColor: '#bfdbfe',
    borderRadius: 8,
    borderWidth: 1,
    paddingHorizontal: 10,
    paddingVertical: 6,
  },
  groupText: {
    color: '#1d4ed8',
    fontSize: 12,
    fontWeight: '700',
  },
  iconButton: {
    alignItems: 'center',
    backgroundColor: '#f8fafc',
    borderColor: '#e5e7eb',
    borderRadius: 8,
    borderWidth: 1,
    height: 38,
    justifyContent: 'center',
    width: 38,
  },
  studyCardActions: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: 8,
  },
  bigWord: {
    color: '#172033',
    fontSize: 42,
    fontWeight: '900',
  },
  bigChineseWord: {
    fontSize: 30,
    lineHeight: 38,
  },
  pronunciation: {
    color: '#717987',
    fontSize: 16,
  },
  pinyinText: {
    color: '#2563eb',
    fontSize: 15,
    fontWeight: '800',
    lineHeight: 21,
  },
  meaningBlock: {
    borderTopColor: '#edf0f5',
    borderTopWidth: 1,
    gap: 6,
    paddingTop: 14,
  },
  partOfSpeech: {
    color: '#2563eb',
    fontSize: 13,
    fontWeight: '800',
  },
  meaning: {
    color: '#172033',
    fontSize: 22,
    fontWeight: '800',
  },
  supplementalMeaning: {
    backgroundColor: '#f8fafc',
    borderColor: '#dbeafe',
    borderRadius: 8,
    borderWidth: 1,
    gap: 5,
    paddingHorizontal: 12,
    paddingVertical: 10,
  },
  supplementalLabel: {
    color: '#2563eb',
    fontSize: 12,
    fontWeight: '900',
  },
  supplementalText: {
    color: '#475569',
    fontSize: 14,
    fontWeight: '700',
    lineHeight: 20,
  },
  exampleBox: {
    backgroundColor: '#f8fafc',
    borderColor: '#e5e7eb',
    borderRadius: 8,
    borderWidth: 1,
    gap: 6,
    padding: 14,
  },
  example: {
    color: '#172033',
    fontSize: 15,
    lineHeight: 22,
  },
  exampleZh: {
    color: '#717987',
    fontSize: 14,
    lineHeight: 21,
  },
  actionGrid: {
    flexDirection: 'row',
    gap: 10,
  },
  secondaryButton: {
    alignItems: 'center',
    backgroundColor: '#fff7ed',
    borderColor: '#fed7aa',
    borderRadius: 8,
    borderWidth: 1,
    flex: 1,
    flexDirection: 'row',
    gap: 8,
    justifyContent: 'center',
    minHeight: 50,
  },
  secondaryButtonText: {
    color: '#9a3412',
    fontSize: 15,
    fontWeight: '800',
  },
  confirmButton: {
    alignItems: 'center',
    backgroundColor: '#2f855a',
    borderRadius: 8,
    flex: 1,
    flexDirection: 'row',
    gap: 8,
    justifyContent: 'center',
    minHeight: 50,
  },
  confirmButtonText: {
    color: '#fff',
    fontSize: 15,
    fontWeight: '900',
  },
  quizCard: {
    backgroundColor: '#fff',
    borderColor: '#e5e7eb',
    borderRadius: 8,
    borderWidth: 1,
    gap: 12,
    padding: 18,
  },
  quizQuestionHeader: {
    alignItems: 'center',
    flexDirection: 'row',
    justifyContent: 'space-between',
    minHeight: 38,
  },
  quizNextTopButton: {
    alignItems: 'center',
    backgroundColor: '#fff',
    borderColor: '#dbeafe',
    borderRadius: 8,
    borderWidth: 1,
    flexDirection: 'row',
    gap: 4,
    minHeight: 34,
    paddingHorizontal: 10,
  },
  quizNextTopText: {
    color: '#172033',
    fontSize: 12,
    fontWeight: '900',
  },
  quizSetupCard: {
    backgroundColor: '#fff',
    borderColor: '#e5e7eb',
    borderRadius: 8,
    borderWidth: 1,
    gap: 14,
    padding: 18,
  },
  quizModeCard: {
    backgroundColor: '#fff',
    borderColor: '#e5e7eb',
    borderRadius: 8,
    borderWidth: 1,
    gap: 12,
    padding: 14,
  },
  quizModeSwitch: {
    backgroundColor: '#eef2ff',
    borderRadius: 8,
    flexDirection: 'row',
    gap: 6,
    padding: 4,
  },
  quizModeButton: {
    alignItems: 'center',
    borderRadius: 7,
    flex: 1,
    justifyContent: 'center',
    minHeight: 42,
    paddingHorizontal: 10,
  },
  quizModeButtonActive: {
    backgroundColor: '#2563eb',
    shadowColor: '#2563eb',
    shadowOffset: { height: 5, width: 0 },
    shadowOpacity: 0.18,
    shadowRadius: 10,
  },
  quizModeButtonText: {
    color: '#475569',
    fontSize: 14,
    fontWeight: '900',
  },
  quizModeButtonTextActive: {
    color: '#fff',
  },
  quizCountRow: {
    flexDirection: 'row',
    gap: 8,
  },
  quizCountChip: {
    alignItems: 'center',
    backgroundColor: '#f8fafc',
    borderColor: '#e5e7eb',
    borderRadius: 8,
    borderWidth: 1,
    flex: 1,
    justifyContent: 'center',
    minHeight: 54,
    paddingHorizontal: 10,
    paddingVertical: 8,
  },
  quizCountChipActive: {
    backgroundColor: '#2563eb',
    borderColor: '#2563eb',
  },
  quizCountText: {
    color: '#172033',
    fontSize: 15,
    fontWeight: '900',
  },
  quizCountTextActive: {
    color: '#fff',
  },
  quizCountMeta: {
    color: '#717987',
    fontSize: 11,
    fontWeight: '800',
    marginTop: 3,
  },
  quizOptions: {
    gap: 10,
    marginTop: 8,
  },
  quizOption: {
    backgroundColor: '#f8fafc',
    borderColor: '#e5e7eb',
    borderRadius: 8,
    borderWidth: 1,
    padding: 15,
  },
  quizOptionPressed: {
    backgroundColor: '#eff6ff',
    borderColor: '#bfdbfe',
  },
  quizOptionCorrect: {
    backgroundColor: '#ecfdf3',
    borderColor: '#86efac',
  },
  quizOptionMuted: {
    opacity: 0.55,
  },
  quizOptionText: {
    color: '#172033',
    fontSize: 16,
    fontWeight: '700',
  },
  quizOptionTextCorrect: {
    color: '#166534',
  },
  resultCard: {
    borderRadius: 8,
    borderWidth: 1,
    gap: 8,
    padding: 16,
  },
  resultCorrect: {
    backgroundColor: '#ecfdf3',
    borderColor: '#86efac',
  },
  resultWrong: {
    backgroundColor: '#fff7ed',
    borderColor: '#fed7aa',
  },
  resultTitle: {
    color: '#172033',
    fontSize: 18,
    fontWeight: '900',
  },
  resultText: {
    color: '#5f6675',
    fontSize: 14,
    lineHeight: 21,
  },
  speakingPromptQuestion: {
    color: '#172033',
    fontSize: 22,
    fontWeight: '900',
    lineHeight: 30,
  },
  quizExampleCard: {
    backgroundColor: 'rgba(255, 255, 255, 0.7)',
    borderColor: 'rgba(203, 213, 225, 0.72)',
    borderRadius: 8,
    borderWidth: 1,
    gap: 6,
    padding: 12,
  },
  quizExampleLabel: {
    color: '#64748b',
    fontSize: 11,
    fontWeight: '900',
    marginTop: 2,
  },
  speakingKeywordHeader: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: 12,
  },
  speakingIconWrap: {
    alignItems: 'center',
    backgroundColor: '#eff6ff',
    borderColor: '#bfdbfe',
    borderRadius: 8,
    borderWidth: 1,
    height: 48,
    justifyContent: 'center',
    width: 48,
  },
  speakingActionRow: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 10,
  },
  speakingDoneButton: {
    alignItems: 'center',
    backgroundColor: '#2563eb',
    borderRadius: 8,
    flex: 1,
    flexDirection: 'row',
    gap: 8,
    justifyContent: 'center',
    minHeight: 48,
    minWidth: 132,
    paddingHorizontal: 14,
  },
  speakingDoneButtonText: {
    color: '#fff',
    fontSize: 14,
    fontWeight: '900',
  },
  speakingSecondaryButton: {
    alignItems: 'center',
    backgroundColor: '#fff',
    borderColor: '#e5e7eb',
    borderRadius: 8,
    borderWidth: 1,
    flex: 1,
    flexDirection: 'row',
    gap: 8,
    justifyContent: 'center',
    minHeight: 48,
    minWidth: 132,
    paddingHorizontal: 14,
  },
  speakingSecondaryText: {
    color: '#172033',
    fontSize: 14,
    fontWeight: '900',
  },
  quizScoreText: {
    color: '#172033',
    fontSize: 24,
    fontWeight: '900',
  },
  nextButton: {
    alignItems: 'center',
    alignSelf: 'flex-start',
    backgroundColor: '#fff',
    borderColor: '#e5e7eb',
    borderRadius: 8,
    borderWidth: 1,
    flexDirection: 'row',
    gap: 6,
    marginTop: 6,
    paddingHorizontal: 12,
    paddingVertical: 9,
  },
  nextButtonText: {
    color: '#172033',
    fontSize: 14,
    fontWeight: '800',
  },
  libraryTopControlsInset: {
    gap: 10,
    paddingRight: 36,
  },
  searchBox: {
    alignItems: 'center',
    backgroundColor: '#fff',
    borderColor: '#e5e7eb',
    borderRadius: 8,
    borderWidth: 1,
    flexDirection: 'row',
    gap: 8,
    paddingHorizontal: 13,
    paddingVertical: 10,
  },
  searchBoxActive: {
    borderColor: '#bfdbfe',
    shadowColor: '#2563eb',
    shadowOffset: { height: 4, width: 0 },
    shadowOpacity: 0.08,
    shadowRadius: 10,
  },
  searchBoxFocused: {
    borderColor: '#2563eb',
  },
  searchInput: {
    color: '#172033',
    flex: 1,
    fontSize: 15,
  },
  searchClearButton: {
    alignItems: 'center',
    backgroundColor: '#f1f5f9',
    borderRadius: 8,
    height: 30,
    justifyContent: 'center',
    width: 30,
  },
  searchMetaBox: {
    backgroundColor: '#eff6ff',
    borderColor: '#bfdbfe',
    borderRadius: 8,
    borderWidth: 1,
    paddingHorizontal: 12,
    paddingVertical: 9,
  },
  searchMetaText: {
    color: '#1d4ed8',
    fontSize: 12,
    fontWeight: '800',
  },
  foldedFilterCard: {
    backgroundColor: '#fff',
    borderColor: '#e5e7eb',
    borderRadius: 8,
    borderWidth: 1,
    overflow: 'hidden',
  },
  filterSummaryButton: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: 12,
    minHeight: 54,
    paddingHorizontal: 14,
    paddingVertical: 10,
  },
  filterSummaryButtonOpen: {
    backgroundColor: '#f8fafc',
  },
  filterSummaryTitle: {
    color: '#172033',
    fontSize: 14,
    fontWeight: '900',
  },
  filterSummaryText: {
    color: '#717987',
    fontSize: 12,
    fontWeight: '700',
    marginTop: 2,
  },
  filterSummaryIcon: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: 4,
  },
  filterChevronOpen: {
    transform: [{ rotate: '180deg' }],
  },
  filterPanel: {
    borderTopColor: '#edf0f5',
    overflow: 'hidden',
  },
  filterPanelContent: {
    gap: 12,
    paddingHorizontal: 12,
    paddingVertical: 12,
  },
  filterSection: {
    gap: 8,
  },
  filterSectionTitle: {
    color: '#64748b',
    fontSize: 12,
    fontWeight: '900',
  },
  filterRow: {
    gap: 8,
    paddingRight: 10,
  },
  filterChip: {
    backgroundColor: '#fff',
    borderColor: '#e5e7eb',
    borderRadius: 8,
    borderWidth: 1,
    paddingHorizontal: 12,
    paddingVertical: 8,
  },
  filterChipActive: {
    backgroundColor: '#172033',
    borderColor: '#172033',
  },
  levelChipActive: {
    backgroundColor: '#2563eb',
    borderColor: '#2563eb',
  },
  filterText: {
    color: '#717987',
    fontSize: 13,
    fontWeight: '700',
  },
  filterTextActive: {
    color: '#fff',
  },
  letterRow: {
    gap: 6,
    paddingRight: 10,
  },
  letterChip: {
    alignItems: 'center',
    backgroundColor: '#fff',
    borderColor: '#e5e7eb',
    borderRadius: 8,
    borderWidth: 1,
    height: 34,
    justifyContent: 'center',
    minWidth: 34,
    paddingHorizontal: 9,
  },
  letterChipActive: {
    backgroundColor: '#172033',
    borderColor: '#172033',
  },
  letterText: {
    color: '#717987',
    fontSize: 12,
    fontWeight: '900',
  },
  letterTextActive: {
    color: '#fff',
  },
  libraryHeaderCard: {
    alignItems: 'stretch',
    backgroundColor: '#fff',
    borderColor: '#e5e7eb',
    borderRadius: 8,
    borderWidth: 1,
    gap: 12,
    padding: 14,
  },
  libraryHeaderRow: {
    alignItems: 'center',
    flexDirection: 'row',
    justifyContent: 'space-between',
  },
  libraryHeaderTitleLine: {
    alignItems: 'center',
    flexDirection: 'row',
    flex: 1,
    gap: 9,
    justifyContent: 'space-between',
  },
  libraryHeaderTitle: {
    color: '#172033',
    fontSize: 17,
    fontWeight: '900',
    flexShrink: 0,
  },
  libraryHeaderMeta: {
    color: '#717987',
    fontSize: 13,
    fontWeight: '700',
    marginTop: 3,
  },
  libraryHeaderMetaPill: {
    alignItems: 'center',
    backgroundColor: '#eff6ff',
    borderColor: '#bfdbfe',
    borderRadius: 8,
    borderWidth: 1,
    flexShrink: 1,
    justifyContent: 'center',
    minHeight: 28,
    paddingHorizontal: 9,
  },
  libraryHeaderMetaPillText: {
    color: '#1d4ed8',
    fontSize: 12,
    fontWeight: '900',
  },
  libraryTopButton: {
    alignItems: 'center',
    backgroundColor: '#f8fafc',
    borderColor: '#cbd5e1',
    borderRadius: 8,
    borderWidth: 1,
    flexDirection: 'row',
    gap: 6,
    minHeight: 40,
    paddingHorizontal: 11,
  },
  libraryTopButtonText: {
    color: '#172033',
    fontSize: 13,
    fontWeight: '900',
  },
  libraryCustomSetsCard: {
    backgroundColor: '#f8fafc',
    borderColor: '#e5e7eb',
    borderRadius: 8,
    borderWidth: 1,
    gap: 10,
    padding: 11,
    paddingRight: 32,
  },
  libraryCustomSetsHeader: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: 10,
    justifyContent: 'space-between',
  },
  libraryCustomSetsTitleRow: {
    alignItems: 'center',
    flexDirection: 'row',
    flex: 1,
    gap: 9,
    minWidth: 0,
  },
  libraryCustomSetsTitle: {
    color: '#172033',
    fontSize: 14,
    fontWeight: '900',
  },
  libraryManageSetsButton: {
    alignItems: 'center',
    backgroundColor: '#fff',
    borderColor: '#cbd5e1',
    borderRadius: 8,
    borderWidth: 1,
    flexDirection: 'row',
    flexShrink: 0,
    gap: 4,
    justifyContent: 'center',
    minHeight: 34,
    paddingHorizontal: 9,
  },
  libraryManageSetsButtonLabel: {
    color: '#172033',
    fontSize: 12,
    fontWeight: '900',
  },
  libraryCustomSetChip: {
    alignItems: 'center',
    backgroundColor: '#fff',
    borderColor: '#dbeafe',
    borderRadius: 8,
    borderWidth: 1,
    flexDirection: 'row',
    gap: 7,
    minHeight: 34,
    paddingHorizontal: 10,
  },
  libraryCustomSetCount: {
    fontSize: 11,
    fontWeight: '900',
  },
  libraryPanel: {
    position: 'relative',
  },
  wordList: {
    gap: 10,
    paddingRight: 44,
  },
  virtualLibrarySpacer: {
    width: '100%',
  },
  libraryItem: {
    backgroundColor: '#fff',
    borderColor: '#e5e7eb',
    borderRadius: 8,
    borderWidth: 1,
    flexDirection: 'row',
    gap: 12,
    padding: 14,
  },
  libraryItemMain: {
    borderRadius: 8,
    flex: 1,
    minWidth: 0,
    paddingHorizontal: 2,
    paddingVertical: 2,
  },
  libraryItemPressed: {
    backgroundColor: 'rgba(37, 99, 235, 0.06)',
  },
  libraryItemPressedLift: {
    borderColor: '#bfdbfe',
    shadowColor: '#2563eb',
    shadowOffset: { width: 0, height: 7 },
    shadowOpacity: 0.12,
    shadowRadius: 16,
  },
  wordLine: {
    alignItems: 'center',
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 8,
  },
  libraryWord: {
    color: '#172033',
    fontSize: 20,
    fontWeight: '900',
  },
  libraryChineseWord: {
    fontSize: 17,
    lineHeight: 23,
  },
  libraryGroup: {
    backgroundColor: '#eff6ff',
    borderColor: '#bfdbfe',
    borderRadius: 6,
    borderWidth: 1,
    color: '#1d4ed8',
    fontSize: 11,
    fontWeight: '900',
    overflow: 'hidden',
    paddingHorizontal: 6,
    paddingVertical: 3,
  },
  libraryPos: {
    color: '#2563eb',
    fontSize: 12,
    fontWeight: '800',
  },
  libraryPinyin: {
    color: '#2563eb',
    fontSize: 12,
    fontWeight: '800',
    lineHeight: 18,
    marginTop: 5,
  },
  libraryMeaning: {
    color: '#172033',
    fontSize: 14,
    fontWeight: '700',
    marginTop: 5,
  },
  librarySupplemental: {
    color: '#64748b',
    fontSize: 12,
    fontWeight: '700',
    lineHeight: 18,
    marginTop: 4,
  },
  libraryExample: {
    color: '#717987',
    fontSize: 13,
    lineHeight: 19,
    marginTop: 5,
  },
  libraryDetailHint: {
    color: '#2563eb',
    fontSize: 12,
    fontWeight: '900',
    marginTop: 8,
  },
  libraryDetailBack: {
    alignItems: 'center',
    alignSelf: 'flex-start',
    backgroundColor: '#fff',
    borderColor: '#cbd5e1',
    borderRadius: 8,
    borderWidth: 1,
    flexDirection: 'row',
    gap: 6,
    minHeight: 42,
    paddingHorizontal: 12,
  },
  libraryDetailBackText: {
    color: '#172033',
    fontSize: 14,
    fontWeight: '900',
  },
  libraryDetailPage: {
    backgroundColor: '#fff',
    borderColor: '#dbeafe',
    borderRadius: 8,
    borderWidth: 1,
    gap: 16,
    padding: 18,
  },
  libraryDetailHeader: {
    alignItems: 'flex-start',
    flexDirection: 'row',
    gap: 12,
  },
  libraryDetailWord: {
    color: '#172033',
    fontSize: 42,
    fontWeight: '900',
    lineHeight: 48,
  },
  libraryDetailChineseWord: {
    fontSize: 30,
    lineHeight: 38,
  },
  libraryDetailPronunciation: {
    color: '#717987',
    fontSize: 16,
    marginTop: 4,
  },
  libraryDetailPinyin: {
    color: '#2563eb',
    fontSize: 15,
    fontWeight: '800',
    lineHeight: 21,
    marginTop: 4,
  },
  libraryDetailOverlay: {
    bottom: 0,
    left: 0,
    position: 'absolute',
    right: 0,
    top: 0,
    zIndex: 50,
  },
  libraryDetailBackdrop: {
    backgroundColor: '#f8fafc',
    bottom: 0,
    left: 0,
    position: 'absolute',
    right: 0,
    top: 0,
  },
  libraryDetailPanel: {
    bottom: 0,
    left: 0,
    paddingHorizontal: 18,
    paddingTop: 18,
    position: 'absolute',
    right: 0,
    top: 0,
  },
  libraryDetailOverlayContent: {
    paddingBottom: 110,
  },
  libraryDetailStage: {
    backgroundColor: '#f8fafc',
    bottom: 86,
    left: 0,
    paddingHorizontal: 18,
    paddingTop: 18,
    position: 'absolute',
    right: 0,
    zIndex: 30,
  },
  libraryDetailStageContent: {
    paddingBottom: 24,
  },
  libraryDetailFavorite: {
    alignItems: 'center',
    backgroundColor: '#f8fafc',
    borderColor: '#e5e7eb',
    borderRadius: 8,
    borderWidth: 1,
    height: 44,
    justifyContent: 'center',
    width: 44,
  },
  libraryDetailMetaRow: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 8,
  },
  libraryDetailBadge: {
    backgroundColor: '#eff6ff',
    borderColor: '#bfdbfe',
    borderRadius: 7,
    borderWidth: 1,
    color: '#1d4ed8',
    fontSize: 12,
    fontWeight: '900',
    overflow: 'hidden',
    paddingHorizontal: 9,
    paddingVertical: 5,
  },
  libraryDetailSection: {
    borderTopColor: '#edf0f5',
    borderTopWidth: 1,
    gap: 7,
    paddingTop: 15,
  },
  libraryDetailLabel: {
    color: '#64748b',
    fontSize: 12,
    fontWeight: '900',
  },
  libraryDetailMeaning: {
    color: '#172033',
    fontSize: 24,
    fontWeight: '900',
    lineHeight: 31,
  },
  libraryDetailExampleCard: {
    backgroundColor: '#f8fafc',
    borderColor: '#e5e7eb',
    borderRadius: 8,
    borderWidth: 1,
    gap: 8,
    padding: 15,
  },
  libraryDetailExample: {
    color: '#172033',
    fontSize: 16,
    lineHeight: 24,
  },
  libraryDetailDivider: {
    backgroundColor: '#e5e7eb',
    height: 1,
    marginVertical: 2,
  },
  libraryDetailExampleZh: {
    color: '#5f6675',
    fontSize: 15,
    lineHeight: 23,
  },
  resultCount: {
    color: '#717987',
    fontSize: 13,
    fontWeight: '700',
    paddingHorizontal: 2,
  },
  librarySide: {
    alignItems: 'center',
    gap: 8,
  },
  statusText: {
    color: '#717987',
    fontSize: 12,
    fontWeight: '700',
  },
  loadMoreButton: {
    alignItems: 'center',
    backgroundColor: '#172033',
    borderRadius: 8,
    justifyContent: 'center',
    minHeight: 46,
    paddingHorizontal: 14,
  },
  loadMoreText: {
    color: '#fff',
    fontSize: 14,
    fontWeight: '900',
  },
  emptyState: {
    backgroundColor: '#fff',
    borderColor: '#e5e7eb',
    borderRadius: 8,
    borderWidth: 1,
    padding: 16,
  },
  emptyTitle: {
    color: '#172033',
    fontSize: 15,
    fontWeight: '900',
  },
  emptyText: {
    color: '#717987',
    fontSize: 13,
    marginTop: 5,
  },
  alphabetRail: {
    backgroundColor: '#ffffff',
    borderColor: '#e5e7eb',
    borderRadius: 8,
    borderWidth: 1,
    gap: 1,
    paddingHorizontal: 2,
    paddingVertical: 4,
    position: 'absolute',
    right: 2,
    top: 28,
  },
  railLetterButton: {
    alignItems: 'center',
    borderRadius: 6,
    height: 18,
    justifyContent: 'center',
    width: 20,
  },
  railLetterButtonActive: {
    backgroundColor: '#172033',
  },
  railLetterText: {
    color: '#717987',
    fontSize: 9,
    fontWeight: '900',
    lineHeight: 11,
  },
  railLetterTextActive: {
    color: '#fff',
  },
  libraryFixedControls: {
    height: 600,
    position: 'absolute',
    right: 10,
    top: 94,
    width: 86,
    zIndex: 20,
  },
  libraryFloatingTopButton: {
    alignItems: 'center',
    alignSelf: 'flex-end',
    backgroundColor: '#ffffff',
    borderColor: '#cbd5e1',
    borderRadius: 8,
    borderWidth: 1,
    elevation: 4,
    flexDirection: 'row',
    gap: 5,
    marginBottom: 10,
    minHeight: 38,
    paddingHorizontal: 9,
    position: 'absolute',
    right: 0,
    shadowColor: '#172033',
    shadowOffset: { height: 2, width: 0 },
    shadowOpacity: 0.12,
    shadowRadius: 6,
    top: 0,
  },
  libraryFloatingTopText: {
    color: '#172033',
    fontSize: 12,
    fontWeight: '900',
  },
  libraryDragSlider: {
    alignItems: 'center',
    alignSelf: 'flex-end',
    borderRadius: 8,
    borderWidth: 1,
    height: 500,
    paddingHorizontal: 4,
    paddingVertical: 5,
    position: 'absolute',
    shadowColor: '#172033',
    shadowOffset: { height: 2, width: 0 },
    top: 100,
  },
  libraryDragSliderActive: {
    backgroundColor: '#ffffff',
    borderColor: '#cbd5e1',
    elevation: 5,
    opacity: 1,
    right: 0,
    shadowOpacity: 0.14,
    shadowRadius: 7,
    width: 34,
  },
  libraryDragSliderCollapsed: {
    backgroundColor: 'rgba(37, 99, 235, 0.16)',
    borderColor: 'rgba(37, 99, 235, 0.14)',
    elevation: 1,
    opacity: 0.76,
    right: -2,
    shadowOpacity: 0.04,
    shadowRadius: 3,
    width: 14,
  },
  libraryDragTrack: {
    backgroundColor: '#e5e7eb',
    borderRadius: 8,
    bottom: 8,
    position: 'absolute',
    top: 8,
  },
  libraryDragTrackActive: {
    opacity: 1,
    width: 4,
  },
  libraryDragTrackCollapsed: {
    backgroundColor: '#2563eb',
    opacity: 0.58,
    width: 2,
  },
  libraryDragThumb: {
    alignItems: 'center',
    backgroundColor: '#eff6ff',
    borderColor: '#93c5fd',
    borderRadius: 8,
    borderWidth: 1,
    height: LIBRARY_SLIDER_THUMB_HEIGHT,
    justifyContent: 'center',
    position: 'absolute',
    top: 5,
  },
  libraryDragThumbActive: {
    opacity: 1,
    width: 24,
  },
  libraryDragThumbCollapsed: {
    backgroundColor: '#2563eb',
    borderColor: '#bfdbfe',
    borderRadius: 99,
    opacity: 0.82,
    width: 8,
  },
  profileCard: {
    alignItems: 'center',
    backgroundColor: '#fff',
    borderColor: '#e5e7eb',
    borderRadius: 8,
    borderWidth: 1,
    padding: 22,
  },
  avatar: {
    alignItems: 'center',
    backgroundColor: '#eff6ff',
    borderColor: '#bfdbfe',
    borderRadius: 8,
    borderWidth: 1,
    height: 72,
    justifyContent: 'center',
    marginBottom: 14,
    width: 72,
  },
  profileTitle: {
    color: '#172033',
    fontSize: 22,
    fontWeight: '900',
  },
  profileText: {
    color: '#717987',
    fontSize: 14,
    lineHeight: 21,
    marginTop: 8,
    textAlign: 'center',
  },
  syncPill: {
    alignItems: 'center',
    backgroundColor: '#ecfdf3',
    borderColor: '#bbf7d0',
    borderRadius: 8,
    borderWidth: 1,
    flexDirection: 'row',
    gap: 6,
    marginTop: 14,
    paddingHorizontal: 10,
    paddingVertical: 7,
  },
  syncPillError: {
    backgroundColor: '#fef2f2',
    borderColor: '#fecaca',
  },
  syncText: {
    color: '#166534',
    fontSize: 12,
    fontWeight: '800',
  },
  syncTextError: {
    color: '#b91c1c',
  },
  accountCard: {
    backgroundColor: '#fff',
    borderColor: '#e5e7eb',
    borderRadius: 8,
    borderWidth: 1,
    gap: 14,
    padding: 16,
  },
  googleButton: {
    alignItems: 'center',
    backgroundColor: '#ffffff',
    borderColor: '#cbd5e1',
    borderRadius: 8,
    borderWidth: 1,
    flexDirection: 'row',
    gap: 11,
    minHeight: 62,
    paddingHorizontal: 12,
    paddingVertical: 10,
  },
  googleIconMark: {
    alignItems: 'center',
    backgroundColor: '#f8fafc',
    borderColor: '#e5e7eb',
    borderRadius: 8,
    borderWidth: 1,
    height: 38,
    justifyContent: 'center',
    width: 38,
  },
  googleButtonTitle: {
    color: '#172033',
    fontSize: 15,
    fontWeight: '900',
  },
  googleButtonText: {
    color: '#717987',
    fontSize: 12,
    fontWeight: '700',
    lineHeight: 17,
    marginTop: 2,
  },
  appleButton: {
    alignItems: 'center',
    backgroundColor: '#0f172a',
    borderColor: '#0f172a',
    borderRadius: 8,
    borderWidth: 1,
    flexDirection: 'row',
    gap: 11,
    minHeight: 62,
    paddingHorizontal: 12,
    paddingVertical: 10,
  },
  appleIconMark: {
    alignItems: 'center',
    backgroundColor: '#172033',
    borderColor: '#334155',
    borderRadius: 8,
    borderWidth: 1,
    height: 38,
    justifyContent: 'center',
    width: 38,
  },
  appleButtonTitle: {
    color: '#ffffff',
    fontSize: 15,
    fontWeight: '900',
  },
  appleButtonText: {
    color: '#cbd5e1',
    fontSize: 12,
    fontWeight: '700',
    lineHeight: 17,
    marginTop: 2,
  },
  emailFallbackLabel: {
    color: '#64748b',
    fontSize: 12,
    fontWeight: '900',
    marginTop: 2,
  },
  inputStack: {
    gap: 10,
  },
  inputBox: {
    alignItems: 'center',
    backgroundColor: '#f8fafc',
    borderColor: '#e5e7eb',
    borderRadius: 8,
    borderWidth: 1,
    flexDirection: 'row',
    gap: 8,
    minHeight: 46,
    paddingHorizontal: 12,
  },
  accountInput: {
    color: '#172033',
    flex: 1,
    fontSize: 15,
    minWidth: 0,
  },
  buttonRow: {
    flexDirection: 'row',
    gap: 10,
  },
  accountButton: {
    alignItems: 'center',
    backgroundColor: '#172033',
    borderRadius: 8,
    flex: 1,
    flexDirection: 'row',
    gap: 7,
    justifyContent: 'center',
    minHeight: 46,
    paddingHorizontal: 12,
  },
  accountButtonText: {
    color: '#fff',
    fontSize: 14,
    fontWeight: '900',
  },
  outlineButton: {
    alignItems: 'center',
    backgroundColor: '#fff',
    borderColor: '#cbd5e1',
    borderRadius: 8,
    borderWidth: 1,
    flex: 1,
    justifyContent: 'center',
    minHeight: 46,
    paddingHorizontal: 12,
  },
  outlineButtonText: {
    color: '#172033',
    fontSize: 14,
    fontWeight: '900',
  },
  signOutButton: {
    alignItems: 'center',
    alignSelf: 'stretch',
    backgroundColor: '#fff7ed',
    borderColor: '#fed7aa',
    borderRadius: 8,
    borderWidth: 1,
    flexDirection: 'row',
    gap: 7,
    justifyContent: 'center',
    minHeight: 46,
    paddingHorizontal: 12,
  },
  signOutButtonText: {
    color: '#9a3412',
    fontSize: 14,
    fontWeight: '900',
  },
  localOnlyBox: {
    backgroundColor: '#f8fafc',
    borderColor: '#e5e7eb',
    borderRadius: 8,
    borderWidth: 1,
    padding: 13,
  },
  localOnlyTitle: {
    color: '#172033',
    fontSize: 14,
    fontWeight: '900',
  },
  localOnlyText: {
    color: '#717987',
    fontSize: 13,
    marginTop: 4,
  },
  disabledButton: {
    opacity: 0.58,
  },
  activeSetBanner: {
    alignItems: 'center',
    backgroundColor: '#eff6ff',
    borderColor: '#bfdbfe',
    borderRadius: 8,
    borderWidth: 1,
    flexDirection: 'row',
    gap: 12,
    paddingHorizontal: 14,
    paddingVertical: 12,
  },
  activeSetTitle: {
    color: '#1d4ed8',
    fontSize: 14,
    fontWeight: '900',
  },
  activeSetText: {
    color: '#64748b',
    fontSize: 12,
    fontWeight: '800',
    marginTop: 2,
  },
  activeSetClearButton: {
    backgroundColor: '#fff',
    borderColor: '#bfdbfe',
    borderRadius: 8,
    borderWidth: 1,
    paddingHorizontal: 11,
    paddingVertical: 8,
  },
  activeSetClearText: {
    color: '#1d4ed8',
    fontSize: 12,
    fontWeight: '900',
  },
  addToSetIconButton: {
    backgroundColor: '#eff6ff',
    borderColor: '#bfdbfe',
    borderRadius: 8,
    borderWidth: 1,
  },
  libraryDetailActionStack: {
    gap: 8,
  },
  customSetOverlay: {
    alignItems: 'center',
    backgroundColor: 'rgba(15, 23, 42, 0.54)',
    bottom: 0,
    justifyContent: 'center',
    left: 0,
    padding: 18,
    position: 'absolute',
    right: 0,
    top: 0,
    zIndex: 90,
  },
  customSetPickerCard: {
    backgroundColor: '#fff',
    borderColor: '#dbeafe',
    borderRadius: 8,
    borderWidth: 1,
    gap: 14,
    maxWidth: 430,
    padding: 16,
    shadowColor: '#172033',
    shadowOffset: { height: 18, width: 0 },
    shadowOpacity: 0.2,
    shadowRadius: 30,
    width: '100%',
  },
  customSetPickerTitle: {
    color: '#172033',
    fontSize: 18,
    fontWeight: '900',
  },
  customSetPickerText: {
    color: '#64748b',
    fontSize: 13,
    fontWeight: '800',
    marginTop: 3,
  },
  customSetCreateRow: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: 9,
  },
  customSetNameInputBox: {
    flex: 1,
  },
  customSetCreateButton: {
    alignItems: 'center',
    backgroundColor: '#2563eb',
    borderRadius: 8,
    height: 44,
    justifyContent: 'center',
    width: 44,
  },
  customSetWideCreateButton: {
    alignItems: 'center',
    backgroundColor: '#2563eb',
    borderRadius: 8,
    flexDirection: 'row',
    gap: 6,
    minHeight: 44,
    paddingHorizontal: 12,
  },
  customSetWideCreateText: {
    color: '#fff',
    fontSize: 13,
    fontWeight: '900',
  },
  customSetPickerList: {
    gap: 8,
  },
  customSetPickerRow: {
    alignItems: 'center',
    backgroundColor: '#f8fafc',
    borderColor: '#e5e7eb',
    borderRadius: 8,
    borderWidth: 1,
    flexDirection: 'row',
    gap: 10,
    padding: 12,
  },
  customSetPickerEmpty: {
    color: '#64748b',
    fontSize: 13,
    fontWeight: '800',
    lineHeight: 19,
  },
  customSetColorDot: {
    borderRadius: 99,
    height: 12,
    width: 12,
  },
  customSetRowTitle: {
    color: '#172033',
    fontSize: 14,
    fontWeight: '900',
  },
  customSetRowText: {
    color: '#64748b',
    fontSize: 12,
    fontWeight: '800',
    marginTop: 2,
  },
  customSetAddText: {
    color: '#2563eb',
    fontSize: 13,
    fontWeight: '900',
  },
  customSetsHeroCard: {
    backgroundColor: '#fff',
    borderColor: '#dbeafe',
    borderRadius: 8,
    borderWidth: 1,
    gap: 13,
    padding: 14,
  },
  customSetSortRow: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 8,
  },
  customSetList: {
    gap: 10,
  },
  customSetCard: {
    backgroundColor: '#fff',
    borderColor: '#e5e7eb',
    borderRadius: 8,
    borderWidth: 1,
    gap: 12,
    padding: 13,
  },
  customSetCardActive: {
    borderColor: '#2563eb',
    shadowColor: '#2563eb',
    shadowOffset: { height: 8, width: 0 },
    shadowOpacity: 0.09,
    shadowRadius: 16,
  },
  customSetSelectHeader: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: 10,
    justifyContent: 'space-between',
  },
  customSetListMainButton: {
    alignItems: 'center',
    flex: 1,
    flexDirection: 'row',
    justifyContent: 'space-between',
    minHeight: 42,
  },
  customSetSettingsButton: {
    alignItems: 'center',
    borderRadius: 8,
    height: 42,
    justifyContent: 'center',
    width: 42,
  },
  customSetTitleRow: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: 9,
  },
  customSetEditBlock: {
    gap: 7,
  },
  customSetEditLabel: {
    color: '#64748b',
    fontSize: 11,
    fontWeight: '900',
  },
  customSetEditRow: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: 9,
  },
  customSetRenameInputBox: {
    flex: 1,
  },
  customSetActionRow: {
    flexDirection: 'row',
    gap: 9,
  },
  customSetDetailActions: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 9,
  },
  customSetActionButton: {
    alignItems: 'center',
    backgroundColor: '#f8fafc',
    borderColor: '#cbd5e1',
    borderRadius: 8,
    borderWidth: 1,
    flex: 1,
    flexDirection: 'row',
    gap: 6,
    justifyContent: 'center',
    minHeight: 42,
  },
  customSetActionText: {
    color: '#172033',
    fontSize: 13,
    fontWeight: '900',
  },
  customSetPrimaryActionButton: {
    alignItems: 'center',
    backgroundColor: '#172033',
    borderRadius: 8,
    flex: 1,
    flexDirection: 'row',
    gap: 6,
    justifyContent: 'center',
    minHeight: 42,
  },
  customSetPrimaryActionText: {
    color: '#fff',
    fontSize: 13,
    fontWeight: '900',
  },
  customSetDeleteButton: {
    alignItems: 'center',
    backgroundColor: '#fef2f2',
    borderColor: '#fecaca',
    borderRadius: 8,
    borderWidth: 1,
    flexDirection: 'row',
    gap: 6,
    justifyContent: 'center',
    minHeight: 40,
  },
  customSetDeleteText: {
    color: '#b91c1c',
    fontSize: 12,
    fontWeight: '900',
  },
  customSetWordList: {
    gap: 8,
  },
  customSetWordRow: {
    alignItems: 'center',
    backgroundColor: '#f8fafc',
    borderColor: '#e5e7eb',
    borderRadius: 8,
    borderWidth: 1,
    flexDirection: 'row',
    gap: 10,
    padding: 10,
  },
  customSetRemoveWordButton: {
    alignItems: 'center',
    backgroundColor: '#fff',
    borderColor: '#fecaca',
    borderRadius: 8,
    borderWidth: 1,
    flexDirection: 'row',
    gap: 4,
    minHeight: 34,
    paddingHorizontal: 9,
  },
  customSetRemoveWordText: {
    color: '#b91c1c',
    fontSize: 12,
    fontWeight: '900',
  },
  customWordFormGrid: {
    gap: 9,
  },
  customWordLongInput: {
    minHeight: 48,
  },
  customSetTinyMeta: {
    color: '#94a3b8',
    fontSize: 11,
    fontWeight: '900',
    textAlign: 'right',
  },
  settingsCard: {
    backgroundColor: '#fff',
    borderColor: '#e5e7eb',
    borderRadius: 8,
    borderWidth: 1,
    gap: 16,
    padding: 16,
  },
  profileInfoCard: {
    backgroundColor: '#fff',
    borderColor: '#e5e7eb',
    borderRadius: 8,
    borderWidth: 1,
    gap: 14,
    padding: 16,
  },
  learningMetricGrid: {
    flexDirection: 'row',
    gap: 8,
  },
  learningMetric: {
    backgroundColor: '#f8fafc',
    borderColor: '#e5e7eb',
    borderRadius: 8,
    borderWidth: 1,
    flex: 1,
    minHeight: 66,
    padding: 10,
  },
  learningMetricLabel: {
    color: '#64748b',
    fontSize: 11,
    fontWeight: '900',
  },
  learningMetricValue: {
    color: '#172033',
    fontSize: 16,
    fontWeight: '900',
    marginTop: 6,
  },
  settingOptionRow: {
    alignItems: 'center',
    backgroundColor: '#f8fafc',
    borderColor: '#e5e7eb',
    borderRadius: 8,
    borderWidth: 1,
    flexDirection: 'row',
    gap: 12,
    minHeight: 70,
    padding: 12,
  },
  settingOptionIcon: {
    alignItems: 'center',
    backgroundColor: '#eff6ff',
    borderColor: '#bfdbfe',
    borderRadius: 8,
    borderWidth: 1,
    height: 42,
    justifyContent: 'center',
    width: 42,
  },
  themeSwitchButton: {
    alignItems: 'center',
    backgroundColor: '#fff',
    borderColor: '#cbd5e1',
    borderRadius: 8,
    borderWidth: 1,
    flexDirection: 'row',
    gap: 6,
    minHeight: 38,
    paddingHorizontal: 10,
  },
  themeSwitchButtonActive: {
    backgroundColor: '#172033',
    borderColor: '#172033',
  },
  themeSwitchDot: {
    backgroundColor: '#cbd5e1',
    borderRadius: 99,
    height: 9,
    width: 9,
  },
  themeSwitchDotActive: {
    backgroundColor: '#60a5fa',
  },
  themeSwitchText: {
    color: '#64748b',
    fontSize: 12,
    fontWeight: '900',
  },
  themeSwitchTextActive: {
    color: '#fff',
  },
  settingsEntryButton: {
    alignItems: 'center',
    backgroundColor: '#fff',
    borderColor: '#dbeafe',
    borderRadius: 8,
    borderWidth: 1,
    flexDirection: 'row',
    gap: 12,
    minHeight: 68,
    padding: 14,
  },
  settingsEntryIcon: {
    alignItems: 'center',
    backgroundColor: '#eff6ff',
    borderColor: '#bfdbfe',
    borderRadius: 8,
    borderWidth: 1,
    height: 42,
    justifyContent: 'center',
    width: 42,
  },
  settingsEntryTitle: {
    color: '#172033',
    fontSize: 16,
    fontWeight: '900',
  },
  settingsEntryText: {
    color: '#717987',
    fontSize: 12,
    fontWeight: '700',
    lineHeight: 17,
    marginTop: 3,
  },
  developerCard: {
    backgroundColor: '#fff',
    borderColor: '#dbeafe',
    borderRadius: 8,
    borderWidth: 1,
    gap: 13,
    padding: 16,
  },
  developerText: {
    color: '#5f6675',
    fontSize: 13,
    lineHeight: 20,
  },
  developerStats: {
    backgroundColor: '#f8fafc',
    borderColor: '#e5e7eb',
    borderRadius: 8,
    borderWidth: 1,
    flexDirection: 'row',
    gap: 12,
    justifyContent: 'space-between',
    padding: 12,
  },
  developerLabel: {
    color: '#64748b',
    fontSize: 11,
    fontWeight: '900',
  },
  developerValue: {
    color: '#172033',
    fontSize: 15,
    fontWeight: '900',
    marginTop: 3,
  },
  developerSummary: {
    color: '#166534',
    fontSize: 12,
    fontWeight: '800',
    lineHeight: 18,
  },
  developerMessage: {
    color: '#717987',
    fontSize: 12,
    fontWeight: '700',
    lineHeight: 18,
  },
  developerActionButton: {
    alignItems: 'center',
    backgroundColor: '#f8fafc',
    borderColor: '#cbd5e1',
    borderRadius: 8,
    borderWidth: 1,
    flex: 1,
    flexDirection: 'row',
    gap: 7,
    justifyContent: 'center',
    minHeight: 46,
    paddingHorizontal: 10,
  },
  developerActionText: {
    color: '#172033',
    fontSize: 13,
    fontWeight: '900',
  },
  developerPrimaryButton: {
    alignItems: 'center',
    backgroundColor: '#2563eb',
    borderRadius: 8,
    flex: 1,
    flexDirection: 'row',
    gap: 7,
    justifyContent: 'center',
    minHeight: 46,
    paddingHorizontal: 10,
  },
  developerPrimaryText: {
    color: '#fff',
    fontSize: 13,
    fontWeight: '900',
  },
  developerClearButton: {
    alignItems: 'center',
    alignSelf: 'stretch',
    backgroundColor: '#fff7ed',
    borderColor: '#fed7aa',
    borderRadius: 8,
    borderWidth: 1,
    flexDirection: 'row',
    gap: 7,
    justifyContent: 'center',
    minHeight: 42,
    paddingHorizontal: 12,
  },
  developerClearText: {
    color: '#9a3412',
    fontSize: 13,
    fontWeight: '900',
  },
  installGuideReplayButton: {
    alignItems: 'center',
    backgroundColor: '#eff6ff',
    borderColor: '#bfdbfe',
    borderRadius: 8,
    borderWidth: 1,
    flexDirection: 'row',
    gap: 8,
    minHeight: 46,
    paddingHorizontal: 12,
  },
  installGuideReplayText: {
    color: '#172033',
    flex: 1,
    fontSize: 14,
    fontWeight: '900',
  },
  settingValue: {
    color: '#172033',
    fontSize: 15,
    fontWeight: '800',
  },
  deleteAccountDataButton: {
    alignItems: 'center',
    backgroundColor: '#fff7ed',
    borderColor: '#fed7aa',
    borderRadius: 8,
    borderWidth: 1,
    flexDirection: 'row',
    gap: 10,
    minHeight: 58,
    paddingHorizontal: 12,
    paddingVertical: 10,
  },
  deleteAccountDataTitle: {
    color: '#9a3412',
    fontSize: 14,
    fontWeight: '900',
  },
  deleteAccountDataText: {
    color: '#b45309',
    fontSize: 12,
    fontWeight: '700',
    lineHeight: 17,
    marginTop: 2,
  },
  tabBar: {
    alignSelf: 'center',
    backgroundColor: '#fff',
    borderColor: '#e5e7eb',
    borderRadius: 8,
    borderWidth: 1,
    bottom: IOS_TAB_BAR_BOTTOM_OFFSET,
    flexDirection: 'row',
    gap: 4,
    left: 16,
    maxWidth: 720,
    padding: 6,
    position: 'absolute',
    right: 16,
  },
  tabButton: {
    alignItems: 'center',
    borderRadius: 8,
    flex: 1,
    gap: 4,
    minHeight: 52,
    justifyContent: 'center',
  },
  tabButtonActive: {
    backgroundColor: '#eef2f7',
  },
  tabLabel: {
    color: '#717987',
    fontSize: 11,
    fontWeight: '700',
  },
  tabLabelActive: {
    color: '#172033',
  },
});

const darkStyles = StyleSheet.create({
  safeArea: {
    backgroundColor: '#020617',
  },
  appShell: {
    backgroundColor: '#0f172a',
  },
  previewModePill: {
    backgroundColor: '#0b1f3a',
    borderColor: '#1d4ed8',
  },
  previewModeText: {
    color: '#bfdbfe',
  },
  brand: {
    color: '#f8fafc',
  },
  headerSubtext: {
    color: '#94a3b8',
  },
  levelPill: {
    backgroundColor: '#102a1f',
    borderColor: '#166534',
  },
  levelText: {
    color: '#86efac',
  },
  updateBanner: {
    backgroundColor: '#0b1f3a',
    borderBottomColor: '#1d4ed8',
  },
  updateText: {
    color: '#bfdbfe',
  },
  updateRequiredOverlay: {
    backgroundColor: 'rgba(2, 6, 23, 0.84)',
  },
  updateRequiredCard: {
    backgroundColor: '#111827',
    borderColor: '#334155',
  },
  updateRequiredIcon: {
    backgroundColor: '#0b1f3a',
    borderColor: '#1d4ed8',
  },
  updateRequiredTitle: {
    color: '#f8fafc',
  },
  updateRequiredText: {
    color: '#cbd5e1',
  },
  updateRequiredCountdown: {
    color: '#bfdbfe',
  },
  tabBar: {
    backgroundColor: '#111827',
    borderColor: '#334155',
  },
  tabButtonActive: {
    backgroundColor: '#2563eb',
  },
  tabLabel: {
    color: '#94a3b8',
  },
  tabLabelActive: {
    color: '#f8fafc',
  },
  hero: {
    backgroundColor: '#182033',
    borderColor: '#334155',
  },
  heroTitle: {
    color: '#f8fafc',
  },
  heroText: {
    color: '#cbd5e1',
  },
  ring: {
    backgroundColor: '#0f172a',
    borderColor: '#475569',
  },
  ringValue: {
    color: '#f8fafc',
  },
  ringLabel: {
    color: '#94a3b8',
  },
  modeSwitchButton: {
    backgroundColor: '#0b1f3a',
    borderColor: '#1d4ed8',
  },
  modeSwitchTitle: {
    color: '#f8fafc',
  },
  modeSwitchText: {
    color: '#cbd5e1',
  },
  installGuideOverlay: {
    backgroundColor: '#020617',
  },
  installGuideLogo: {
    backgroundColor: '#1d4ed8',
    borderColor: '#60a5fa',
  },
  installGuideClose: {
    backgroundColor: '#111827',
    borderColor: '#334155',
  },
  installGuideCard: {
    backgroundColor: '#111827',
    borderColor: '#334155',
    shadowColor: '#000',
    shadowOpacity: 0.2,
  },
  installGuideStepPill: {
    backgroundColor: '#0b1f3a',
    borderColor: '#1d4ed8',
  },
  installGuideStepText: {
    color: '#bfdbfe',
  },
  installGuideIconWrap: {
    backgroundColor: '#0b1f3a',
    borderColor: '#1d4ed8',
  },
  installGuideIconGlow: {
    backgroundColor: '#1d4ed8',
  },
  installGuideTitle: {
    color: '#f8fafc',
  },
  installGuideText: {
    color: '#cbd5e1',
  },
  installGuidePreview: {
    backgroundColor: '#0f172a',
    borderColor: '#334155',
  },
  installGuideBrowserBar: {
    backgroundColor: '#475569',
  },
  installGuideMiniStep: {
    backgroundColor: '#111827',
    borderColor: '#334155',
  },
  installGuideMiniText: {
    color: '#94a3b8',
  },
  installGuideDot: {
    backgroundColor: '#475569',
  },
  installGuideSecondary: {
    backgroundColor: '#111827',
    borderColor: '#334155',
  },
  installGuideSecondaryText: {
    color: '#e2e8f0',
  },
  installGuidePrimary: {
    backgroundColor: '#2563eb',
  },
  progressCard: {
    backgroundColor: '#111827',
    borderColor: '#334155',
  },
  sectionTitle: {
    color: '#f8fafc',
  },
  cardMeta: {
    color: '#94a3b8',
  },
  progressTrack: {
    backgroundColor: '#334155',
  },
  accountShortcut: {
    backgroundColor: '#182033',
    borderColor: '#334155',
  },
  accountShortcutText: {
    color: '#e2e8f0',
  },
  statCard: {
    backgroundColor: '#111827',
    borderColor: '#334155',
  },
  statValue: {
    color: '#f8fafc',
  },
  statLabel: {
    color: '#94a3b8',
  },
  reviewStrip: {
    backgroundColor: '#111827',
    borderColor: '#334155',
  },
  reviewTitle: {
    color: '#f8fafc',
  },
  reviewText: {
    color: '#94a3b8',
  },
  emptyState: {
    backgroundColor: '#111827',
    borderColor: '#334155',
  },
  emptyTitle: {
    color: '#f8fafc',
  },
  emptyText: {
    color: '#94a3b8',
  },
  wordCard: {
    backgroundColor: '#111827',
    borderColor: '#334155',
  },
  bigWord: {
    color: '#f8fafc',
  },
  pronunciation: {
    color: '#94a3b8',
  },
  pinyinText: {
    color: '#93c5fd',
  },
  meaningBlock: {
    borderTopColor: '#334155',
  },
  meaning: {
    color: '#e2e8f0',
  },
  supplementalMeaning: {
    backgroundColor: '#182033',
    borderColor: '#334155',
  },
  supplementalLabel: {
    color: '#93c5fd',
  },
  supplementalText: {
    color: '#cbd5e1',
  },
  exampleBox: {
    backgroundColor: '#182033',
    borderColor: '#334155',
  },
  example: {
    color: '#f8fafc',
  },
  exampleZh: {
    color: '#cbd5e1',
  },
  foldedFilterCard: {
    backgroundColor: '#111827',
    borderColor: '#334155',
  },
  filterSummaryButtonOpen: {
    backgroundColor: '#182033',
  },
  filterPanel: {
    borderTopColor: '#334155',
  },
  filterSummaryTitle: {
    color: '#f8fafc',
  },
  filterSummaryText: {
    color: '#94a3b8',
  },
  filterSectionTitle: {
    color: '#cbd5e1',
  },
  filterChip: {
    backgroundColor: '#182033',
    borderColor: '#334155',
  },
  filterText: {
    color: '#cbd5e1',
  },
  letterChip: {
    backgroundColor: '#182033',
    borderColor: '#334155',
  },
  quizSetupCard: {
    backgroundColor: '#111827',
    borderColor: '#334155',
  },
  quizModeCard: {
    backgroundColor: '#111827',
    borderColor: '#334155',
  },
  quizModeSwitch: {
    backgroundColor: '#0f172a',
  },
  quizModeButton: {
    backgroundColor: 'transparent',
  },
  quizModeButtonText: {
    color: '#cbd5e1',
  },
  quizCountChip: {
    backgroundColor: '#182033',
    borderColor: '#334155',
  },
  quizCountText: {
    color: '#e2e8f0',
  },
  quizCountMeta: {
    color: '#94a3b8',
  },
  quizCard: {
    backgroundColor: '#111827',
    borderColor: '#334155',
  },
  quizNextTopButton: {
    backgroundColor: '#182033',
    borderColor: '#334155',
  },
  quizNextTopText: {
    color: '#e2e8f0',
  },
  quizOption: {
    backgroundColor: '#182033',
    borderColor: '#334155',
  },
  quizOptionPressed: {
    backgroundColor: '#0b1f3a',
    borderColor: '#1d4ed8',
  },
  quizOptionText: {
    color: '#e2e8f0',
  },
  resultCard: {
    backgroundColor: '#111827',
    borderColor: '#334155',
  },
  resultTitle: {
    color: '#f8fafc',
  },
  quizScoreText: {
    color: '#f8fafc',
  },
  quizExampleCard: {
    backgroundColor: '#182033',
    borderColor: '#334155',
  },
  quizExampleLabel: {
    color: '#94a3b8',
  },
  speakingIconWrap: {
    backgroundColor: '#0b1f3a',
    borderColor: '#1d4ed8',
  },
  speakingSecondaryButton: {
    backgroundColor: '#182033',
    borderColor: '#334155',
  },
  speakingSecondaryText: {
    color: '#e2e8f0',
  },
  resultText: {
    color: '#cbd5e1',
  },
  speakingPromptQuestion: {
    color: '#f8fafc',
  },
  nextButton: {
    backgroundColor: '#182033',
    borderColor: '#334155',
  },
  nextButtonText: {
    color: '#e2e8f0',
  },
  libraryFloatingTopButton: {
    backgroundColor: '#111827',
    borderColor: '#334155',
    shadowColor: '#000',
  },
  libraryFloatingTopText: {
    color: '#e2e8f0',
  },
  libraryDragSlider: {
    backgroundColor: '#111827',
    borderColor: '#334155',
    shadowColor: '#000',
  },
  libraryDragSliderActive: {
    backgroundColor: '#111827',
    borderColor: '#334155',
    shadowColor: '#000',
  },
  libraryDragSliderCollapsed: {
    backgroundColor: 'rgba(96, 165, 250, 0.2)',
    borderColor: 'rgba(96, 165, 250, 0.2)',
    shadowColor: '#000',
  },
  libraryDragTrack: {
    backgroundColor: '#334155',
  },
  libraryDragTrackActive: {
    backgroundColor: '#334155',
  },
  libraryDragTrackCollapsed: {
    backgroundColor: '#60a5fa',
  },
  libraryDragThumb: {
    backgroundColor: '#0b1f3a',
    borderColor: '#3b82f6',
  },
  libraryDragThumbActive: {
    backgroundColor: '#0b1f3a',
    borderColor: '#3b82f6',
  },
  libraryDragThumbCollapsed: {
    backgroundColor: '#60a5fa',
    borderColor: '#93c5fd',
  },
  libraryHeaderCard: {
    backgroundColor: '#111827',
    borderColor: '#334155',
  },
  libraryCustomSetsCard: {
    backgroundColor: '#182033',
    borderColor: '#334155',
  },
  libraryHeaderMetaPill: {
    backgroundColor: '#0b1f3a',
    borderColor: '#1d4ed8',
  },
  libraryHeaderMetaPillText: {
    color: '#bfdbfe',
  },
  libraryHeaderTitle: {
    color: '#f8fafc',
  },
  libraryHeaderMeta: {
    color: '#94a3b8',
  },
  libraryCustomSetsTitle: {
    color: '#f8fafc',
  },
  libraryTopButton: {
    backgroundColor: '#182033',
    borderColor: '#334155',
  },
  libraryTopButtonText: {
    color: '#e2e8f0',
  },
  searchBox: {
    backgroundColor: '#111827',
    borderColor: '#334155',
  },
  searchInput: {
    color: '#f8fafc',
  },
  searchClearButton: {
    backgroundColor: '#1f2937',
  },
  searchMetaBox: {
    backgroundColor: '#0b1f3a',
    borderColor: '#1d4ed8',
  },
  searchMetaText: {
    color: '#bfdbfe',
  },
  resultCount: {
    color: '#94a3b8',
  },
  libraryItem: {
    backgroundColor: '#111827',
    borderColor: '#334155',
  },
  libraryItemPressed: {
    backgroundColor: 'rgba(37, 99, 235, 0.18)',
  },
  libraryItemPressedLift: {
    borderColor: '#3b82f6',
    shadowColor: '#60a5fa',
    shadowOpacity: 0.16,
  },
  libraryWord: {
    color: '#f8fafc',
  },
  libraryPinyin: {
    color: '#93c5fd',
  },
  libraryMeaning: {
    color: '#e2e8f0',
  },
  librarySupplemental: {
    color: '#cbd5e1',
  },
  libraryExample: {
    color: '#94a3b8',
  },
  statusText: {
    color: '#94a3b8',
  },
  libraryDetailBack: {
    backgroundColor: '#111827',
    borderColor: '#334155',
  },
  libraryDetailBackText: {
    color: '#e2e8f0',
  },
  libraryDetailPage: {
    backgroundColor: '#111827',
    borderColor: '#334155',
  },
  libraryDetailWord: {
    color: '#f8fafc',
  },
  libraryDetailPronunciation: {
    color: '#94a3b8',
  },
  libraryDetailPinyin: {
    color: '#93c5fd',
  },
  libraryDetailBackdrop: {
    backgroundColor: '#0f172a',
  },
  libraryDetailPanel: {
    backgroundColor: 'transparent',
  },
  libraryDetailStage: {
    backgroundColor: '#0f172a',
  },
  libraryDetailSection: {
    borderTopColor: '#334155',
  },
  libraryDetailLabel: {
    color: '#94a3b8',
  },
  libraryDetailMeaning: {
    color: '#f8fafc',
  },
  libraryDetailExampleCard: {
    backgroundColor: '#182033',
    borderColor: '#334155',
  },
  libraryDetailExample: {
    color: '#f8fafc',
  },
  libraryDetailDivider: {
    backgroundColor: '#334155',
  },
  libraryDetailExampleZh: {
    color: '#cbd5e1',
  },
  profileCard: {
    backgroundColor: '#111827',
    borderColor: '#334155',
  },
  avatar: {
    backgroundColor: '#182033',
    borderColor: '#334155',
  },
  profileTitle: {
    color: '#f8fafc',
  },
  profileText: {
    color: '#cbd5e1',
  },
  accountCard: {
    backgroundColor: '#111827',
    borderColor: '#334155',
  },
  googleButton: {
    backgroundColor: '#182033',
    borderColor: '#334155',
  },
  googleIconMark: {
    backgroundColor: '#111827',
    borderColor: '#334155',
  },
  googleButtonTitle: {
    color: '#f8fafc',
  },
  googleButtonText: {
    color: '#94a3b8',
  },
  emailFallbackLabel: {
    color: '#94a3b8',
  },
  localOnlyBox: {
    backgroundColor: '#182033',
    borderColor: '#334155',
  },
  localOnlyTitle: {
    color: '#f8fafc',
  },
  localOnlyText: {
    color: '#94a3b8',
  },
  inputBox: {
    backgroundColor: '#182033',
    borderColor: '#334155',
  },
  accountInput: {
    color: '#f8fafc',
  },
  outlineButton: {
    backgroundColor: '#182033',
    borderColor: '#334155',
  },
  outlineButtonText: {
    color: '#e2e8f0',
  },
  activeSetBanner: {
    backgroundColor: '#0b1f3a',
    borderColor: '#1d4ed8',
  },
  activeSetTitle: {
    color: '#bfdbfe',
  },
  activeSetText: {
    color: '#94a3b8',
  },
  activeSetClearButton: {
    backgroundColor: '#182033',
    borderColor: '#334155',
  },
  activeSetClearText: {
    color: '#bfdbfe',
  },
  customSetPickerCard: {
    backgroundColor: '#111827',
    borderColor: '#334155',
    shadowColor: '#000',
  },
  customSetPickerTitle: {
    color: '#f8fafc',
  },
  customSetPickerText: {
    color: '#94a3b8',
  },
  customSetPickerRow: {
    backgroundColor: '#182033',
    borderColor: '#334155',
  },
  customSetPickerEmpty: {
    color: '#94a3b8',
  },
  customSetRowTitle: {
    color: '#f8fafc',
  },
  customSetRowText: {
    color: '#94a3b8',
  },
  customSetsHeroCard: {
    backgroundColor: '#111827',
    borderColor: '#334155',
  },
  customSetCard: {
    backgroundColor: '#111827',
    borderColor: '#334155',
  },
  customSetActionButton: {
    backgroundColor: '#182033',
    borderColor: '#334155',
  },
  customSetActionText: {
    color: '#e2e8f0',
  },
  customSetTinyMeta: {
    color: '#64748b',
  },
  settingsCard: {
    backgroundColor: '#111827',
    borderColor: '#334155',
  },
  profileInfoCard: {
    backgroundColor: '#111827',
    borderColor: '#334155',
  },
  learningMetric: {
    backgroundColor: '#182033',
    borderColor: '#334155',
  },
  learningMetricLabel: {
    color: '#94a3b8',
  },
  learningMetricValue: {
    color: '#f8fafc',
  },
  settingOptionRow: {
    backgroundColor: '#182033',
    borderColor: '#334155',
  },
  settingsEntryButton: {
    backgroundColor: '#111827',
    borderColor: '#334155',
  },
  settingsEntryIcon: {
    backgroundColor: '#182033',
    borderColor: '#334155',
  },
  settingsEntryTitle: {
    color: '#f8fafc',
  },
  settingsEntryText: {
    color: '#94a3b8',
  },
  deleteAccountDataButton: {
    backgroundColor: '#2a1714',
    borderColor: '#7f1d1d',
  },
  deleteAccountDataTitle: {
    color: '#fca5a5',
  },
  deleteAccountDataText: {
    color: '#fecaca',
  },
  developerCard: {
    backgroundColor: '#111827',
    borderColor: '#334155',
  },
  developerText: {
    color: '#cbd5e1',
  },
  developerStats: {
    backgroundColor: '#182033',
    borderColor: '#334155',
  },
  developerLabel: {
    color: '#94a3b8',
  },
  developerValue: {
    color: '#f8fafc',
  },
  developerMessage: {
    color: '#94a3b8',
  },
  developerActionButton: {
    backgroundColor: '#182033',
    borderColor: '#334155',
  },
  developerActionText: {
    color: '#e2e8f0',
  },
});


