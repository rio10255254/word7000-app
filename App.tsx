import { StatusBar } from 'expo-status-bar';
import * as AppleAuthentication from 'expo-apple-authentication';
import * as WebBrowser from 'expo-web-browser';
import Constants from 'expo-constants';
import { GlassView, isGlassEffectAPIAvailable } from 'expo-glass-effect';
import { useFocusEffect, usePathname, useRouter } from 'expo-router';
import { FlashList, type FlashListRef } from '@shopify/flash-list';
import { Gesture, GestureDetector } from 'react-native-gesture-handler';
import Reanimated, {
  cancelAnimation,
  Easing as ReanimatedEasing,
  Extrapolation,
  interpolate,
  ReduceMotion,
  runOnJS,
  useAnimatedStyle,
  useSharedValue,
  withDecay,
  withSequence,
  withSpring,
  withTiming,
} from 'react-native-reanimated';
import {
  ArrowUp,
  BookOpen,
  ScanText,
  Eye,
  EyeOff,
  PartyPopper,
  Undo2,
  Check,
  ChartColumn,
  ChevronLeft,
  ChevronDown,
  ChevronRight,
  Cloud,
  Compass,
  Database,
  Download,
  Flame,
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
  ShieldCheck,
  SlidersHorizontal,
  Smartphone,
  SquareArrowUp,
  SquarePlus,
  Star,
  Sun,
  Target,
  Trash2,
  Upload,
  User,
  X,
} from 'lucide-react-native';
import { createContext, memo, useCallback, useContext, useDeferredValue, useEffect, useLayoutEffect, useMemo, useRef, useState, type ComponentProps, type Context, type ReactNode, type RefObject } from 'react';
import {
  ActivityIndicator,
  Alert,
  Animated,
  AppState,
  Easing,
  Keyboard,
  KeyboardAvoidingView,
  type LayoutChangeEvent,
  Modal,
  type NativeScrollEvent,
  type NativeSyntheticEvent,
  Pressable,
  type PressableProps,
  Platform,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  type StyleProp,
  useColorScheme,
  useWindowDimensions,
  View,
  type ViewStyle,
  Linking,
} from 'react-native';
import { SafeAreaView, useSafeAreaInsets } from 'react-native-safe-area-context';
import type { WordEntry } from './src/data/words';
import { iosVisual } from './src/design/iosVisualSystem';
import { scrollTargetFromSlider, scrollThumbOffset } from './src/lib/libraryNavigation';
import {
  buildQuizOptions,
  buildQuizSession,
  buildStudyQueue,
  computeStats,
  filterWords,
  markKnown,
  markQuizCorrect,
  markReview,
  mergeProgressStates,
  normalizeProgressForDate,
  selectQuizWords,
  selectStudyWords,
  toggleFavorite,
  type QuizOption,
  type LibraryFilter,
  type LibrarySort,
  type ProgressState,
} from './src/lib/progress';
import {
  STUDY_SWIPE_FLING_DISTANCE,
  STUDY_SWIPE_FLING_VELOCITY,
  STUDY_SWIPE_RELEASE_DISTANCE,
  STUDY_SWIPE_THRESHOLD,
  type StudySwipeDirection,
} from './src/lib/studySwipe';
import { createAppSupabaseClient, type AppSupabaseClient } from './src/lib/supabaseClient';
import { deleteAuthenticatedAccount } from './src/lib/accountDeletion';
import {
  accountDisplayName,
  accountNameFromUser,
  accountUpgradeReasonForFilter,
  clearPendingAccountUpgrade,
  hasUsedPermanentAccount,
  isAnonymousUser,
  isIdentityAlreadyLinkedError,
  loadPendingAccountUpgrade,
  markPermanentAccountUsed,
  markProgressProtectionPromptSeen,
  savePendingAccountUpgrade,
  shouldPromptToProtectProgress,
  type AccountUpgradeReason,
} from './src/lib/accountIdentity';
import { loadProgressFromStorage, progressStorageKey, saveProgressToStorage, type StorageLike } from './src/lib/progressStorage';
import {
  loadCloudProgressRecord,
  recordDailyActiveUser,
  saveCloudCustomSets,
  saveCloudProgress,
  saveCloudUserMemory,
  type CloudProgressClient,
} from './src/lib/supabaseProgress';
import type { User as SupabaseUser } from '@supabase/supabase-js';
import { interactionMotion, listEnterOffset, pressMotionFor, type InteractionTone } from './src/lib/interactionMotion';
import { appleCredentialMetadata, createAppleNoncePair } from './src/lib/appleAuth';
import { triggerPressHaptic } from './src/lib/haptics';
import { iosUpdateDecision, parseIosUpdatePolicy, type IosUpdateDecision } from './src/lib/nativeUpdatePolicy';
import { loadBundledVocabulary } from './src/lib/vocabularyLoader';
import {
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
import Svg, {
  Circle as SvgCircle,
  Defs as SvgDefs,
  G as SvgG,
  LinearGradient as SvgLinearGradient,
  Mask as SvgMask,
  RadialGradient as SvgRadialGradient,
  Rect as SvgRect,
  Stop as SvgStop,
} from 'react-native-svg';
import { getAppStorage, hydrateAppStorage, isAppStorageHydrated } from './src/lib/appStorage';
import { parseOAuthCallbackUrl } from './src/lib/oauthCallback';
import { appInfoLinks, buildHostedAppUrl } from './src/lib/appLinks';
import {
  clearUserMemoryOutbox,
  loadUserMemoryOutbox,
  UserMemorySyncQueue,
} from './src/lib/userMemorySync';
import { setAppRouteBridgeSnapshot } from './src/lib/appRouteBridge';
import { hideNativeSplash } from './src/lib/nativeSplash';
import {
  buildStreakLiveActivityProps,
  buildStreakReminderPlan,
  loadStreakReminderEnabled,
  localDateKey,
  nextStreakReminderRefreshAt,
  saveStreakReminderEnabled,
} from './src/lib/streakReminder';
import {
  subscribeToStreakPushToStartToken,
  syncStreakLiveActivity,
  type StreakLiveActivitySyncResult,
} from './src/lib/streakLiveActivityController';
import {
  disableStreakReminderRegistration,
  getOrCreateStreakDeviceId,
  saveStreakReminderRegistration,
  StreakReminderRegistrationQueue,
} from './src/lib/streakReminderRegistration';
import { DeferredStorageWriter } from './src/lib/deferredStorageWriter';
import {
  buildScannedWords,
  CORE_BANK_ID,
  isScannedWordId,
  loadActiveBankId,
  defaultScanBankName,
  saveActiveBankId,
  type ReviewedScanWord,
} from './src/lib/wordBanks';
import {
  createStudySession,
  currentStudyCardId,
  gradeStudyCard,
  isStudySessionComplete,
  studySessionProgress,
  upcomingStudyCardId,
  type StudyGrade,
  type StudySession,
} from './src/lib/studySession';
import { useRuntimePerformance } from './src/lib/runtimePerformance';
import { withTimeout } from './src/lib/asyncTimeout';
import {
  buildPersonalLearningAnalytics,
  recordLearningDuration,
  recordLearningEvent,
  type LearningEventType,
  type PersonalLearningAnalytics,
} from './src/lib/learningAnalytics';
import { BrandMark } from './src/components/BrandMark';
import { AppIcon } from './src/components/AppIcon';

WebBrowser.maybeCompleteAuthSession();

type Tab = 'home' | 'study' | 'quiz' | 'library' | 'profile';
type AccountStatus = 'local' | 'loading' | 'guest' | 'signedOut' | 'signedIn' | 'syncing' | 'saved' | 'error';
type ThemeMode = 'light' | 'dark';
type ThemePreference = ThemeMode | 'system';
type StudyMode = 'english' | 'chinese';
type QuizPracticeMode = 'choice' | 'speaking';
type ManualCustomWordState = {
  example: string;
  exampleZh: string;
  meaningZh: string;
  supplementalMeaningZh: string;
  partOfSpeech: string;
  pronunciation: string;
  word: string;
};

type AccountState = {
  configured: boolean;
  email: string;
  password: string;
  isAnonymous: boolean;
  userId: string | null;
  userEmail: string | null;
  userName: string | null;
  busy: boolean;
  status: AccountStatus;
  message: string;
};
type ManualUpdateStatus = 'idle' | 'checking' | 'available' | 'current' | 'error';
type UpdateState = {
  available: boolean;
  buttonText: string;
  checkNow: () => void;
  countdownSeconds: number;
  countdownText: string;
  detail: string;
  manualStatus: ManualUpdateStatus;
  message: string;
  refresh: () => void;
};
type FilterOption = {
  id: string;
  label: string;
};

const today = localDateKey();
const UPDATE_STORAGE_KEY = 'word7000-version-v1';
const UPDATE_AUTO_REFRESH_MS = 6500;
const UPDATE_CHECK_INTERVAL_MS = 60_000;
const IOS_UPDATE_POLICY_URL = 'https://word7000-app.rio10255254.workers.dev/ios-update.json';
const ACTIVE_USER_HEARTBEAT_MS = 5 * 60_000;
const ACTIVE_USER_HEARTBEAT_MIN_GAP_MS = 60_000;
const NATIVE_UPDATE_CHECK_COOLDOWN_MS = 15 * 60_000;
const THEME_STORAGE_KEY = 'word7000-theme-v1';
const STUDY_MODE_STORAGE_KEY = 'word7000-study-mode-v1';
const STUDY_AUTO_REVEAL_STORAGE_KEY = 'word7000-study-auto-reveal-v1';
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
const IS_NATIVE_IOS = Platform.OS === 'ios';
const NATIVE_GLASS_AVAILABLE = IS_NATIVE_IOS && isGlassEffectAPIAvailable();
const WEB_IOS_PREVIEW_SCROLL_BOTTOM_INSET = 0;
// SF Rounded for headings and numbers: friendlier for a study app, and the
// system design React Native maps "ui-rounded" to on iOS.
const ROUNDED_FONT = Platform.select({ ios: 'ui-rounded', web: 'ui-rounded, system-ui, sans-serif', default: undefined });
const CONTENT_BOTTOM_PADDING = 30;
const PROFILE_TAB_BAR_MIN_CLEARANCE = 28;
// On iOS the native tab bar sits at the bottom and the system hands us the
// inset. The web fallback for native tabs is a fixed pill at top: 24px with a
// height of 40, which floats over the content, so web alone owes it headroom.
const WEB_TABS_TOP_INSET = Platform.OS === 'web' ? 76 : 0;
const TAB_CONTENT_TOP_PADDING = Platform.OS === 'web' ? 18 + WEB_TABS_TOP_INSET : 10;
const LIBRARY_SLIDER_THUMB_HEIGHT = 36;
const LIBRARY_ANIMATED_ITEM_COUNT = Math.min(5, interactionMotion.staggeredListLimit);
const LIBRARY_FIXED_CONTROLS_TOP = 8;
const LIBRARY_FIXED_CONTROLS_BOTTOM = 8;
const STUDY_SWIPE_REVEAL_WIDTH = 460;
const STUDY_SWIPE_GLOW_WAKE_X = 14;
const STUDY_SWIPE_PREVIEW_FADE_X = 28;
const STUDY_SWIPE_READY_FADE_X = STUDY_SWIPE_THRESHOLD - 8;
const STUDY_SWIPE_COMMIT_FADE_X = STUDY_SWIPE_THRESHOLD + 18;
const STUDY_SWIPE_MAX_TILT_DEG = 7;
// Tilt has to reach full angle within the distance a swipe actually travels
// before release, not across the whole exit path — otherwise the card is
// barely a degree off while the finger is still on it.
const STUDY_SWIPE_TILT_REFERENCE = STUDY_SWIPE_THRESHOLD * 2.2;
// A card dragged slowly past the threshold is released at almost zero velocity;
// give it a floor so it still leaves decisively instead of drifting out.
const STUDY_SWIPE_MIN_EXIT_VELOCITY = 950;
const STUDY_CARD_ENTRY_MS = 240;
const STUDY_SWIPE_HINT_INITIAL_DELAY_MS = 1450;
const STUDY_SWIPE_HINT_IDLE_DELAY_MS = 10_000;
const STUDY_SWIPE_HINT_REPEAT_MS = 15_000;
const SHOULD_CLEAR_STUDY_SELECTION = Platform.OS === 'web';
const quizQuestionCounts = [10, 20, 50] as const;
const dailyTargetOptions = [10, 20, 30, 50] as const;
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
  streak: 0,
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
    heroTitle: (target: number) => `今天 ${target} 個\n剛剛好`,
    heroDoneTitle: '今天的目標\n完成了',
    primaryAction: '開始今日學習',
    continueAction: '繼續學習',
    extraAction: '再學一組',
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
    heroTitle: (target: number) => `${target} Chinese words\nfor today`,
    heroDoneTitle: "Today's goal\nis done",
    primaryAction: "Start today's practice",
    continueAction: 'Keep going',
    extraAction: 'Practice one more set',
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
    dictionaryLookup: '快速查字',
    todayPlan: (due: number, fresh: number) => `${due} 個待複習 · ${fresh} 個新字`,
    reviewDueToday: '今日待複習',
    quickQuiz: '小測驗',
    quickQuizText: '10 題選擇題，檢查最近學的字',
    streakDays: (days: number) => `${days} 天`,
    dictionarySearch: '查詢字庫',
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
    previousWord: '上一個',
    nextWord: '下一個',
    swipeReviewHint: '左滑不會',
    swipeKnownHint: '右滑已會',
    tapToReveal: '想一下，再點卡片看答案',
    coreBankName: '7000 單字',
    builtInBank: '內建',
    scanBankTag: '掃描',
    bankLabel: '字庫',
    bankWordCount: (count: number) => `${count} 個`,
    bankPickerTitle: '選擇字庫',
    bankPickerHint: '學習、測驗和字庫都會改用這個字庫',
    scanNewSheet: '掃描單字表',
    scanShort: '掃描',
    closeSheet: '關閉',
    showAnswer: '顯示答案',
    autoReveal: '直接顯示中文',
    autoRevealHint: '開啟後卡片直接顯示中文，不用先點一下',
    dontKnow: '不熟',
    knowIt: '認識',
    undo: '復原上一張',
    sessionLabel: (done: number, total: number) => `第 ${Math.min(done + 1, total)} / ${total} 張`,
    todayGoalLine: (studied: number, target: number) => `今日 ${studied} / ${target}`,
    sessionCompleteTitle: '這一組完成了',
    sessionCompleteText: (known: number, review: number) => `認識 ${known} 個 · 還不熟 ${review} 個`,
    sessionGoalDone: '今天的目標已達成，繼續加油！',
    sessionGoalLeft: (left: number) => `距離今天的目標還差 ${left} 個字`,
    nextSession: '再來一組',
    reviewMissed: (count: number) => `再練不熟的 ${count} 個`,
    goQuiz: '用測驗檢查記憶',
    keyboardHint: '鍵盤：空白鍵看答案，← 不熟，→ 認識',
    filterButtonLabel: '篩選',
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
    seeResults: '看結果',
    endQuiz: '結束',
    quizPrompt: '選出正確的中文意思',
    quizMissedTitle: (count: number) => `答錯的 ${count} 個字`,
    practiceMissed: (count: number) => `用學習卡複習這 ${count} 個字`,
    returnTop: '回到頂端',
    floatingTop: '回頂端',
    clearSearch: '清除搜尋',
    searchMeta: (query: string, count: number) => `搜尋「${query}」：找到 ${count} 個結果`,
    filteredCount: (count: number) => `篩選後 ${count} 個`,
    resultCount: (count: number, start: number, end: number) => `共 ${count} 個結果，顯示第 ${count === 0 ? 0 : start + 1}-${end} 個`,
    viewDetails: '完整資訊',
    viewWordDetails: (word: string) => `查看 ${word} 完整資訊`,
    favoriteWordName: (word: string) => `收藏 ${word}`,
    unfavoriteWordName: (word: string) => `取消收藏 ${word}`,
    backLibrary: '返回字庫',
    backHome: '返回首頁',
    detailTitle: '完整資訊',
    profileIdle: '穩定累積中',
    profileProgress: (percent: number, mastered: number) => `今天完成 ${percent}%，目前掌握 ${mastered} 個單字。`,
    account: '帳號',
    appleAccountName: 'Apple 使用者',
    learningAnalytics: '學習分析',
    analyticsPreview: (activeDays: number, accuracy: number | null) =>
      `近 7 天活躍 ${activeDays} 天 · 測驗正確率 ${accuracy === null ? '尚無資料' : `${accuracy}%`}`,
    guest: '訪客',
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
    favoritesRequireSignIn: '需登入',
    remainingSamples: '尚未學過',
    tutorial: '教學',
    replayTutorial: '重新查看加入主畫面教學',
    settings: '設定',
    settingsSummary: '深色模式、連勝提醒與資料工具',
    openSettings: '開啟設定',
    backProfile: '返回我的',
    appSettings: 'App 設定',
    displayTools: '顯示模式、連勝提醒與本機工具',
    legalSupport: '隱私與支援',
    legalSupportSummary: '隱私、支援與帳號資料管理',
    privacyPolicy: '隱私權政策',
    privacyPolicyText: '查看 Word7000 如何保存與同步學習資料',
    supportPage: '支援頁面',
    supportPageText: '登入、同步、更新與帳號資料說明',
    deleteAccountData: '刪除帳號與資料',
    deleteAccountDataText: '永久刪除這個 Word7000 身分、學習進度、活躍紀錄與提醒資料',
    deleteAccountDataConfirmTitle: '刪除帳號與所有資料？',
    deleteAccountDataConfirmText: '這會永久刪除目前的 Word7000 身分、學習進度、單字集、每日活躍紀錄與鎖定畫面提醒，且無法復原。',
    deleteAccountDataConfirmCancel: '取消',
    deleteAccountDataConfirmAction: '確認刪除',
    darkMode: '深色模式',
    appearance: '外觀',
    appearanceText: '跟隨系統，或固定使用淺色、深色',
    themeSystem: '跟隨系統',
    themeLight: '淺色',
    themeDark: '深色',
    dailyTargetTitle: '每日目標',
    dailyTargetText: '每天想學幾個單字，也決定每組學習卡的張數',
    dailyTargetOption: (count: number) => `每日 ${count} 個單字`,
    wordsUnit: (count: number) => `${count} 個`,
    darkModeOnText: '已切換成夜間閱讀介面',
    darkModeOffText: '切換成夜間閱讀介面',
    toggleDarkMode: '切換深色模式',
    streakReminder: '鎖定畫面學習提醒',
    streakReminderOnText: '每天中午提醒，連勝最後一小時倒數',
    streakReminderOffText: '不顯示鎖定畫面與靈動島提醒',
    toggleStreakReminder: '切換鎖定畫面學習提醒',
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
    editSetName: '單字集名稱',
    saveSetName: '儲存名稱',
    deleteSet: '刪除單字集',
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
    customWordSupplementalMeaningPlaceholder: '補充意思，可空白',
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
    scanSaved: (count: number, name: string) => `已把 ${count} 個掃描單字存進「${name}」`,
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
    dictionaryLookup: 'Quick Dictionary',
    todayPlan: (due: number, fresh: number) => `${due} to review · ${fresh} new`,
    reviewDueToday: 'Due Today',
    quickQuiz: 'Quick Quiz',
    quickQuizText: 'A short multiple-choice check on recent words',
    streakDays: (days: number) => `${days} ${days === 1 ? 'day' : 'days'}`,
    dictionarySearch: 'Search the library',
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
    previousWord: 'Previous',
    nextWord: 'Next',
    swipeReviewHint: 'Swipe left: still learning',
    swipeKnownHint: 'Swipe right: I know it',
    tapToReveal: 'Think first, then tap to check',
    coreBankName: '7000 Words',
    builtInBank: 'Built-in',
    scanBankTag: 'Scanned',
    bankLabel: 'Bank',
    bankWordCount: (count: number) => `${count} words`,
    bankPickerTitle: 'Choose a Word Bank',
    bankPickerHint: 'Study, quiz, and library all switch to this bank',
    scanNewSheet: 'Scan a Word Sheet',
    scanShort: 'Scan',
    closeSheet: 'Close',
    showAnswer: 'Show Answer',
    autoReveal: 'Show English',
    autoRevealHint: 'When on, cards show the English right away instead of waiting for a tap',
    dontKnow: 'Not Yet',
    knowIt: 'I Know It',
    undo: 'Undo last card',
    sessionLabel: (done: number, total: number) => `Card ${Math.min(done + 1, total)} of ${total}`,
    todayGoalLine: (studied: number, target: number) => `Today ${studied} / ${target}`,
    sessionCompleteTitle: 'Set complete',
    sessionCompleteText: (known: number, review: number) => `${known} known · ${review} still learning`,
    sessionGoalDone: "Today's goal is done. Nice work!",
    sessionGoalLeft: (left: number) => `${left} more words to reach today's goal`,
    nextSession: 'Next Set',
    reviewMissed: (count: number) => `Practice ${count} missed words`,
    goQuiz: 'Check with a quiz',
    keyboardHint: 'Keyboard: Space to reveal, ← still learning, → know it',
    filterButtonLabel: 'Filters',
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
    seeResults: 'See Results',
    endQuiz: 'End',
    quizPrompt: 'Pick the matching English word',
    quizMissedTitle: (count: number) => `${count} missed words`,
    practiceMissed: (count: number) => `Practice these ${count} words`,
    returnTop: 'Back to Top',
    floatingTop: 'Top',
    clearSearch: 'Clear search',
    searchMeta: (query: string, count: number) => `Search "${query}": ${count} results`,
    filteredCount: (count: number) => `${count} words`,
    resultCount: (count: number, start: number, end: number) => `${count} results, showing ${count === 0 ? 0 : start + 1}-${end}`,
    viewDetails: 'Details',
    viewWordDetails: (word: string) => `View details for ${word}`,
    favoriteWordName: (word: string) => `Save ${word}`,
    unfavoriteWordName: (word: string) => `Remove ${word} from saved`,
    backLibrary: 'Back to Library',
    backHome: 'Back to Home',
    detailTitle: 'Details',
    profileIdle: 'Building momentum',
    profileProgress: (percent: number, mastered: number) => `${percent}% complete today, ${mastered} words mastered.`,
    account: 'Account',
    appleAccountName: 'Apple user',
    learningAnalytics: 'Learning Analytics',
    analyticsPreview: (activeDays: number, accuracy: number | null) =>
      `${activeDays} active days this week · Quiz accuracy ${accuracy === null ? 'No data yet' : `${accuracy}%`}`,
    guest: 'Guest',
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
    favoritesRequireSignIn: 'Sign in',
    remainingSamples: 'Not Started',
    tutorial: 'Tutorial',
    replayTutorial: 'Review home-screen tutorial',
    settings: 'Settings',
    settingsSummary: 'Dark mode, streak alerts, and data tools',
    openSettings: 'Open settings',
    backProfile: 'Back to Me',
    appSettings: 'App Settings',
    displayTools: 'Display, streak alerts, and local tools',
    legalSupport: 'Privacy and Support',
    legalSupportSummary: 'Privacy, support, and account data controls',
    privacyPolicy: 'Privacy Policy',
    privacyPolicyText: 'See how Word7000 stores and syncs learning data',
    supportPage: 'Support Page',
    supportPageText: 'Help with sign-in, sync, updates, and account data',
    deleteAccountData: 'Delete Account and Data',
    deleteAccountDataText: 'Permanently delete this Word7000 identity, progress, activity, and reminder data',
    deleteAccountDataConfirmTitle: 'Delete account and all data?',
    deleteAccountDataConfirmText: 'This permanently deletes the current Word7000 identity, learning progress, custom sets, daily activity, and Lock Screen reminders. This cannot be undone.',
    deleteAccountDataConfirmCancel: 'Cancel',
    deleteAccountDataConfirmAction: 'Delete Data',
    darkMode: 'Dark Mode',
    appearance: 'Appearance',
    appearanceText: 'Follow the system, or always use light or dark',
    themeSystem: 'System',
    themeLight: 'Light',
    themeDark: 'Dark',
    dailyTargetTitle: 'Daily Goal',
    dailyTargetText: 'How many words a day, and how many cards per study set',
    dailyTargetOption: (count: number) => `${count} words a day`,
    wordsUnit: (count: number) => `${count} words`,
    darkModeOnText: 'Night reading interface is on',
    darkModeOffText: 'Switch to the night reading interface',
    toggleDarkMode: 'Toggle dark mode',
    streakReminder: 'Lock Screen Study Reminder',
    streakReminderOnText: 'Remind me at noon and during the final streak hour',
    streakReminderOffText: 'Hide Lock Screen and Dynamic Island reminders',
    toggleStreakReminder: 'Toggle Lock Screen study reminders',
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
    editSetName: 'Set name',
    saveSetName: 'Save Name',
    deleteSet: 'Delete Set',
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
    customWordSupplementalMeaningPlaceholder: 'Extra meanings, optional',
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
    scanSaved: (count: number, name: string) => `Saved ${count} scanned words to "${name}"`,
  },
} as const;

const accountUpgradeCopy = {
  english: {
    badge: {
      customSets: '單字集會同步到你的帳號',
      dataTools: '資料工具只會連結你的帳號',
      favorites: '收藏會同步到你的帳號',
      protectProgress: '目前進度已保留',
    },
    body: {
      customSets: '登入後即可建立與管理單字集，並在換機後完整取回。',
      dataTools: '登入後才會開放匯入、匯出與帳號資料工具。',
      favorites: '收藏會安全同步到你的帳號，換機或重新安裝後仍能找回。',
      protectProgress: '登入後可跨裝置保留連續天數、收藏、複習狀態與學習紀錄。',
    },
    later: '稍後再說',
    privacy: '不登入也能繼續查字、學習與測驗。',
    title: {
      customSets: '登入以使用單字集',
      dataTools: '登入以使用資料工具',
      favorites: '登入後才能收藏',
      protectProgress: '保護你的學習進度',
    },
  },
  chinese: {
    badge: {
      customSets: 'Sets sync with your account',
      dataTools: 'Data tools stay linked to your account',
      favorites: 'Saved words sync with your account',
      protectProgress: 'Your current progress is safe',
    },
    body: {
      customSets: 'Sign in to create and manage custom sets and restore them on another device.',
      dataTools: 'Sign in to use imports, exports, and account data tools.',
      favorites: 'Saved words stay with your account, even after changing devices or reinstalling the app.',
      protectProgress: 'Sign in to keep your streak, saved words, review status, and learning history across devices.',
    },
    later: 'Not Now',
    privacy: 'You can keep using dictionary, study, and quiz without signing in.',
    title: {
      customSets: 'Sign In for Custom Sets',
      dataTools: 'Sign In for Data Tools',
      favorites: 'Sign In to Save Words',
      protectProgress: 'Protect Your Progress',
    },
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
    updateCheckTitle: '檢查 App 更新',
    updateCheckDetail: '自動更新已開啟，也可以隨時手動檢查。',
    updateChecking: '正在檢查',
    updateAvailable: '新版已就緒',
    updateAvailableDetail: '新版已下載完成，點一下立即套用。',
    updateCurrent: '已是最新版本',
    updateCurrentDetail: '目前版本已同步，自動更新仍會持續運作。',
    updateRetry: '重新檢查',
    updateCheckFailed: '暫時無法連線，請稍後再試。',
    testFlightUpdateButton: '開啟 TestFlight',
    testFlightUpdateDetail: '這個版本已停止使用，請到 TestFlight 安裝最新版後再繼續。',
    testFlightUpdateHint: '安裝完成後重新開啟 Word7000',
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
    updateCheckTitle: 'Check for App Updates',
    updateCheckDetail: 'Automatic updates are on, and you can check at any time.',
    updateChecking: 'Checking',
    updateAvailable: 'Update ready',
    updateAvailableDetail: 'The latest update is downloaded and ready to apply.',
    updateCurrent: 'Up to date',
    updateCurrentDetail: 'This version is current and automatic updates remain active.',
    updateRetry: 'Check again',
    updateCheckFailed: 'Unable to connect right now. Please try again shortly.',
    testFlightUpdateButton: 'Open TestFlight',
    testFlightUpdateDetail: 'This build is no longer supported. Install the latest version from TestFlight to continue.',
    testFlightUpdateHint: 'Reopen Word7000 after installing the update',
    installGuide: {
      closeAccessibility: 'Close home-screen tutorial',
      dismiss: "I'll do this myself",
      done: 'Done',
      next: 'Next',
    },
  },
} as const;
type SystemCopy = (typeof systemCopy)[StudyMode];

const levelFilters: FilterOption[] = [
  { id: 'all', label: '全部' },
  ...Array.from({ length: 14 }, (_, index) => ({
    id: `Core ${index + 1}`,
    label: `Core ${index + 1}`,
  })),
];
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
  supplementalMeaningZh: '',
  partOfSpeech: '',
  pronunciation: '',
  word: '',
};
const ThemeContext = createContext<ThemeMode>('light');
// Each tab is its own route under (tabs), so the props a screen needs can no
// longer be handed down as JSX attributes. They travel as one object per
// screen instead, which keeps the route files to a single line of rendering
// and keeps the assembly of those props where the state actually lives.
type AppScreenProps = {
  homeProps: ComponentProps<typeof HomeView>;
  studyProps: ComponentProps<typeof StudyView>;
  quizProps: ComponentProps<typeof QuizView>;
  libraryProps: Omit<ComponentProps<typeof LibraryView>, 'bottomInset'>;
  profileProps: ComponentProps<typeof ProfileView>;
  libraryChrome: { floatingControls: ReactNode };
};
const StudyModeContext = createContext<StudyMode>('english');
const HomeScreenPropsContext = createContext<AppScreenProps['homeProps'] | null>(null);
const StudyScreenPropsContext = createContext<AppScreenProps['studyProps'] | null>(null);
const QuizScreenPropsContext = createContext<AppScreenProps['quizProps'] | null>(null);
const ProfileScreenPropsContext = createContext<AppScreenProps['profileProps'] | null>(null);
const LibraryScreenPropsContext = createContext<{
  libraryChrome: AppScreenProps['libraryChrome'];
  libraryProps: AppScreenProps['libraryProps'];
} | null>(null);

export function useAppStudyMode(): StudyMode {
  return useContext(StudyModeContext);
}

function useRequiredScreenProps<T>(context: Context<T | null>): T {
  const value = useContext(context);
  if (!value) {
    throw new Error('Screen props must be used inside the tabs layout');
  }
  return value;
}
const VocabularyContext = createContext<WordEntry[]>([]);
const MotionPressable = Reanimated.createAnimatedComponent(Pressable);
type LibraryListHandle = FlashListRef<WordEntry>;

export function AppBootstrap({ children }: { children: ReactNode }) {
  const [storageReady, setStorageReady] = useState(() => isAppStorageHydrated());
  const [storageLoadFailed, setStorageLoadFailed] = useState(false);
  const [bundledVocabulary, setBundledVocabulary] = useState<WordEntry[] | null>(null);
  const [vocabularyLoadFailed, setVocabularyLoadFailed] = useState(false);

  useEffect(() => {
    if (storageReady) {
      return;
    }

    let mounted = true;
    const timeout = setTimeout(() => {
      if (mounted) {
        setStorageLoadFailed(true);
      }
    }, 10_000);
    hydrateAppStorage()
      .then(() => {
        if (mounted) {
          clearTimeout(timeout);
          setStorageLoadFailed(false);
          setStorageReady(true);
        }
      })
      .catch(() => {
        if (mounted) {
          clearTimeout(timeout);
          setStorageLoadFailed(true);
        }
      });

    return () => {
      mounted = false;
      clearTimeout(timeout);
    };
  }, [storageReady]);

  useEffect(() => {
    let mounted = true;
    loadBundledVocabulary()
      .then((words) => {
        if (mounted) {
          setBundledVocabulary(words);
        }
      })
      .catch(() => {
        if (mounted) {
          setVocabularyLoadFailed(true);
        }
      });

    return () => {
      mounted = false;
    };
  }, []);

  useEffect(() => {
    if ((storageReady || storageLoadFailed) && (bundledVocabulary || vocabularyLoadFailed)) {
      hideNativeSplash();
    }
  }, [bundledVocabulary, storageLoadFailed, storageReady, vocabularyLoadFailed]);

  if (!storageReady || !bundledVocabulary) {
    return <AppStorageBootScreen failed={storageLoadFailed || vocabularyLoadFailed} />;
  }

  return <VocabularyContext.Provider value={bundledVocabulary}>{children}</VocabularyContext.Provider>;
}

// One component per tab route. The native header owns the top safe area and
// NativeTabs owns the bottom inset; this is only the visual gap after them.
function TabScrollHost({
  bottomClearance = 0,
  children,
  containOverscroll = false,
}: {
  bottomClearance?: number;
  children: ReactNode;
  containOverscroll?: boolean;
}) {
  const themeStyles = useThemeStyles();

  return (
    <ScrollView
      alwaysBounceVertical={!containOverscroll}
      automaticallyAdjustContentInsets
      automaticallyAdjustKeyboardInsets={Platform.OS === 'ios' && !containOverscroll}
      automaticallyAdjustsScrollIndicatorInsets
      bounces={!containOverscroll}
      contentContainerStyle={[
        styles.content,
        { paddingBottom: CONTENT_BOTTOM_PADDING + bottomClearance, paddingTop: TAB_CONTENT_TOP_PADDING },
      ]}
      contentInsetAdjustmentBehavior="automatic"
      keyboardDismissMode={Platform.OS === 'ios' ? 'interactive' : 'on-drag'}
      keyboardShouldPersistTaps="handled"
      overScrollMode={containOverscroll ? 'never' : 'auto'}
      scrollEnabled
      style={[styles.appScroll, IS_WEB_IOS_PREVIEW && styles.webIosPreviewScroll, themeStyles?.appShell]}
    >
      <View style={styles.screenMotion}>{children}</View>
    </ScrollView>
  );
}

export function HomeTabScreen() {
  const homeProps = useRequiredScreenProps(HomeScreenPropsContext);
  return (
    <TabScrollHost>
      <HomeView {...homeProps} />
    </TabScrollHost>
  );
}

export function StudyTabScreen() {
  const studyProps = useRequiredScreenProps(StudyScreenPropsContext);
  return (
    <TabScrollHost>
      <StudyView {...studyProps} />
    </TabScrollHost>
  );
}

export function QuizTabScreen() {
  const quizProps = useRequiredScreenProps(QuizScreenPropsContext);
  return (
    <TabScrollHost>
      <QuizView {...quizProps} />
    </TabScrollHost>
  );
}

export function ProfileTabScreen() {
  const profileProps = useRequiredScreenProps(ProfileScreenPropsContext);
  const safeAreaInsets = useSafeAreaInsets();
  const bottomClearance = Math.max(PROFILE_TAB_BAR_MIN_CLEARANCE, safeAreaInsets.bottom + 34);
  return (
    <TabScrollHost bottomClearance={bottomClearance} containOverscroll>
      <ProfileView {...profileProps} />
    </TabScrollHost>
  );
}

export function LibraryTabScreen() {
  const { libraryChrome, libraryProps } = useRequiredScreenProps(LibraryScreenPropsContext);
  const themeStyles = useThemeStyles();

  return (
    <View collapsable={false} style={[styles.libraryScreenHost, themeStyles?.appShell]}>
      <View collapsable={false} style={styles.libraryListStage} testID="library-panel-transition">
        <LibraryView {...libraryProps} bottomInset={0} />
      </View>
      {libraryChrome.floatingControls}
    </View>
  );
}

export function Word7000RouteScreen({
  children,
  studyMode: _studyMode,
  themeMode,
  vocabularyWords,
}: {
  children: ReactNode;
  studyMode: StudyMode;
  themeMode: ThemeMode;
  vocabularyWords: WordEntry[];
}) {
  const routeThemeStyles = themeMode === 'dark' ? darkStyles : undefined;
  return (
    <VocabularyContext.Provider value={vocabularyWords}>
      <ThemeContext.Provider value={themeMode}>
        <SafeAreaView edges={['top', 'bottom', 'left', 'right']} style={[styles.safeArea, routeThemeStyles?.safeArea]}>
          <StatusBar style={themeMode === 'dark' ? 'light' : 'dark'} />
          <View style={[styles.appShell, routeThemeStyles?.appShell]}>{children}</View>
        </SafeAreaView>
      </ThemeContext.Provider>
    </VocabularyContext.Provider>
  );
}

function useActiveTabFromRoute(): Tab {
  const pathname = usePathname();
  return useMemo(() => {
    if (pathname.startsWith('/settings') || pathname.startsWith('/stats')) {
      return 'profile';
    }
    if (pathname.startsWith('/sets')) {
      return 'library';
    }
    if (pathname.startsWith('/study')) {
      return 'study';
    }
    if (pathname.startsWith('/quiz')) {
      return 'quiz';
    }
    if (pathname.startsWith('/library')) {
      return 'library';
    }
    if (pathname.startsWith('/profile')) {
      return 'profile';
    }
    return 'home';
  }, [pathname]);
}

function useStableEvent<T extends (...args: any[]) => any>(handler: T): T {
  const handlerRef = useRef(handler);
  handlerRef.current = handler;
  return useCallback(((...args: Parameters<T>) => handlerRef.current(...args)) as T, []);
}

function useDebouncedValue<T>(value: T, delayMs: number): T {
  const [debounced, setDebounced] = useState(value);
  useEffect(() => {
    const timer = setTimeout(() => setDebounced(value), delayMs);
    return () => clearTimeout(timer);
  }, [delayMs, value]);
  return debounced;
}

function useFocusedSnapshot<T>(value: T, focused: boolean): T {
  const snapshotRef = useRef(value);
  useLayoutEffect(() => {
    if (focused) {
      snapshotRef.current = value;
    }
  }, [focused, value]);
  return focused ? value : snapshotRef.current;
}

export function AppDataProvider({ children }: { children: ReactNode }) {
  const bundledVocabulary = useContext(VocabularyContext);
  const router = useRouter();
  const runtimePerformance = useRuntimePerformance();
  const appScrollRef = useRef<ScrollView | null>(null);
  const libraryListRef = useRef<LibraryListHandle | null>(null);
  const libraryScrollYRef = useRef(0);
  const libraryContentHeightRef = useRef(1);
  const libraryViewportHeightRef = useRef(1);
  const librarySliderDraggingRef = useRef(false);
  const libraryScrolledPastTopRef = useRef(false);
  const libraryRouteScrollRestoreRef = useRef<number | null>(null);
  const memorySyncQueueRef = useRef<UserMemorySyncQueue | null>(null);
  const progressStorageWriterRef = useRef<DeferredStorageWriter<ProgressState> | null>(null);
  const streakRegistrationQueueRef = useRef<StreakReminderRegistrationQueue | null>(null);
  const pendingAdvancedActionRef = useRef<(() => void) | null>(null);
  const progressProtectionTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const installGuideAnim = useRef(new Animated.Value(0)).current;
  const cardAnim = useRef(new Animated.Value(1)).current;
  const libraryThumbOffsetAnim = useRef(new Animated.Value(0)).current;
  const librarySliderInteractionAnim = useRef(new Animated.Value(0)).current;
  const modeTransitionAnim = useRef(new Animated.Value(0)).current;
  const accountUpgradeAnim = useRef(new Animated.Value(0)).current;
  const librarySliderLastY = useSharedValue(-1000);
  const learningSessionRef = useRef<{
    date: string;
    mode: StudyMode;
    sourceId: string;
    startedAt: number;
  } | null>(null);
  const accountUpgradeFrameRef = useRef<ReturnType<typeof requestAnimationFrame> | null>(null);
  const accountUpgradeHapticTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const answeredQuizKeyRef = useRef<string | null>(null);
  const speakingRecordedKeyRef = useRef<string | null>(null);
  const [supabaseClient] = useState<AppSupabaseClient | null>(() => createAppSupabaseClient());
  const [initialFilterPreferences] = useState(() => loadFilterPreferences(getAppStorage()));
  const [streakDeviceId] = useState(() => getOrCreateStreakDeviceId(getAppStorage()));
  // Derived from the route rather than held in state. The memos below use it
  // to skip work for screens you are not looking at, and with native tabs the
  // router is the only thing that knows which screen that is. Keeping the same
  // name means every existing guard keeps working unchanged.
  const activeTab = useActiveTabFromRoute();
  const setActiveTab = useCallback(
    (tab: Tab) => {
      router.navigate(tab === 'home' ? '/' : `/${tab}`);
    },
    [router],
  );
  const [currentDate, setCurrentDate] = useState(today);
  const [streakReminderNow, setStreakReminderNow] = useState(() => Date.now());
  const [progress, setProgress] = useState<ProgressState>(initialProgress);
  const [progressReady, setProgressReady] = useState(false);
  const [studySession, setStudySession] = useState<StudySession | null>(null);
  const [studySessionSerial, setStudySessionSerial] = useState(0);
  const [studyUndo, setStudyUndo] = useState<{
    after: ProgressState;
    before: ProgressState;
    session: StudySession;
  } | null>(null);
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
  const [quizMissedIds, setQuizMissedIds] = useState<string[]>([]);
  const [quizChosenText, setQuizChosenText] = useState<string | null>(null);
  const [quizSeed, setQuizSeed] = useState('');
  const [searchQuery, setSearchQuery] = useState('');
  const debouncedSearchQuery = useDebouncedValue(
    searchQuery,
    runtimePerformance.conserveResources || runtimePerformance.isLegacyIos ? 160 : 80,
  );
  const deferredSearchQuery = useDeferredValue(debouncedSearchQuery);
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
  const [installGuideChecked, setInstallGuideChecked] = useState(false);
  const [showInstallGuide, setShowInstallGuide] = useState(false);
  const [installGuideStep, setInstallGuideStep] = useState(0);
  const [account, setAccount] = useState<AccountState>(() => createInitialAccountState(Boolean(supabaseClient)));
  const [accountUpgradeReason, setAccountUpgradeReason] = useState<AccountUpgradeReason | null>(null);
  const systemColorScheme = useColorScheme();
  const [themePreference, setThemePreference] = useState<ThemePreference>(() => loadThemePreference(getAppStorage()));
  const themeMode: ThemeMode = themePreference === 'system'
    ? systemColorScheme === 'dark' ? 'dark' : 'light'
    : themePreference;
  const [studyMode, setStudyMode] = useState<StudyMode>(() => loadStudyMode(getAppStorage()));
  const [streakReminderEnabled, setStreakReminderEnabled] = useState(() =>
    loadStreakReminderEnabled(getAppStorage()),
  );
  const [streakPushToStartToken, setStreakPushToStartToken] = useState<string | null>(null);
  const [streakActivitySync, setStreakActivitySync] = useState<StreakLiveActivitySyncResult>({
    active: false,
    activityPushToken: null,
    startedForExpiresAt: null,
  });
  const [modeSwitchTarget, setModeSwitchTarget] = useState<StudyMode>(() =>
    loadStudyMode(getAppStorage()) === 'english' ? 'chinese' : 'english',
  );
  const [showModeSwitch, setShowModeSwitch] = useState(false);
  const [sliderTrackHeight, setSliderTrackHeight] = useState(1);
  const [librarySliderDragging, setLibrarySliderDragging] = useState(false);
  const [libraryScrolledPastTop, setLibraryScrolledPastTop] = useState(false);
  const [customSetState, setCustomSetState] = useState<CustomSetState>(() => loadCustomSetState(getAppStorage()));
  const [customSetSort, setCustomSetSort] = useState<CustomSetSort>(() => loadCustomSetSort(getAppStorage()));
  const [selectedCustomSetId, setSelectedCustomSetId] = useState<string | null>(null);
  const [activeBankId, setActiveBankId] = useState<string>(() => loadActiveBankId(getAppStorage()));
  const [bankPickerOpen, setBankPickerOpen] = useState(false);
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

  const baseVocabularyWords = developerVocabulary?.words ?? bundledVocabulary;
  // The core bank: the built-in list plus words added by hand. Scanned words
  // keep the meaning printed on their sheet, so they stay in their own banks.
  const vocabularyWords = useMemo(
    () => mergeCustomWords(
      baseVocabularyWords,
      customSetState.customWords.filter((word) => !isScannedWordId(word.id)),
    ),
    [baseVocabularyWords, customSetState.customWords],
  );
  // Every word any bank can refer to, for lookups by id.
  const allWords = useMemo(() => {
    const scanned = customSetState.customWords.filter((word) => isScannedWordId(word.id));
    return scanned.length > 0 ? [...scanned, ...vocabularyWords] : vocabularyWords;
  }, [customSetState.customWords, vocabularyWords]);
  const sortedCustomSets = useMemo(() => sortCustomSets(customSetState.sets, customSetSort), [customSetSort, customSetState.sets]);
  const activeBank = useMemo(
    () => customSetState.sets.find((set) => set.id === activeBankId) ?? null,
    [activeBankId, customSetState.sets],
  );
  // One bank drives study, quiz, the library and the home summary, so what
  // the learner picked is what every tab is about.
  const bankWords = useMemo(
    () => (activeBank ? wordsForCustomSet(allWords, activeBank) : vocabularyWords),
    [activeBank, allWords, vocabularyWords],
  );
  const studySourceWords = bankWords;
  const quizSourceWords = bankWords;
  const bankName = activeBank?.name ?? modeInterfaceCopy[studyMode].coreBankName;
  const bankIsScan = Boolean(activeBank?.wordIds.some(isScannedWordId));
  const levelFilterOptions = useMemo(() => buildLevelFilters(bankWords), [bankWords]);
  const summaryProgress = useFocusedSnapshot(
    progress,
    activeTab === 'home' || activeTab === 'profile',
  );
  const stats = useMemo(
    () => computeStats(bankWords, summaryProgress, currentDate),
    [bankWords, currentDate, summaryProgress],
  );
  const personalAnalytics = useMemo(
    () => buildPersonalLearningAnalytics(summaryProgress, stats, bankWords.length, currentDate),
    [bankWords.length, currentDate, stats, summaryProgress],
  );
  const studyProgressDependency = activeTab === 'study' && studyFilter !== 'all' ? progress : null;
  const studyWords = useMemo(
    () => selectStudyWords(studySourceWords, progress, studyFilter, {
      initial: studyInitial,
      level: studyLevel,
    }),
    [activeTab, studyFilter, studyInitial, studyLevel, studyProgressDependency, studySourceWords],
  );
  const vocabularyById = useMemo(
    () => new Map(allWords.map((word) => [word.id, word])),
    [allWords],
  );
  // Everything a session is built from. When any of it changes the session in
  // progress no longer matches what the learner asked for, so it is rebuilt;
  // progress changes are deliberately not part of it, otherwise grading a card
  // would reshuffle the deck under the learner's finger.
  const studySourceKey = [
    studyMode,
    studyFilter,
    studyLevel,
    studyInitial,
    activeBankId,
    developerVocabulary?.importedAt ?? '',
    bankWords.length,
  ].join('|');
  const studyWord = vocabularyById.get(currentStudyCardId(studySession) ?? '') ?? null;
  const studyDeckNextWord = vocabularyById.get(upcomingStudyCardId(studySession) ?? '') ?? null;
  const studySessionDone = isStudySessionComplete(studySession);
  const studyCanUndo = Boolean(studyUndo && studyUndo.after === progress);
  const quizProgressDependency = activeTab === 'quiz' && quizFilter !== 'all' ? progress : null;
  const quizWords = useMemo(
    () => selectQuizWords(quizSourceWords, progress, quizFilter, {
      initial: quizInitial,
      level: quizLevel,
    }),
    [activeTab, quizFilter, quizInitial, quizLevel, quizProgressDependency, quizSourceWords],
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
  const libraryProgressDependency = activeTab === 'library' && activeFilter !== 'all' ? progress : null;
  const libraryWords = useMemo(
    () => filterWords(bankWords, progress, deferredSearchQuery, activeFilter, {
      initial: activeInitial,
      level: activeLevel,
      sort: activeSort,
    }),
    [activeFilter, activeInitial, activeLevel, activeSort, activeTab, bankWords, deferredSearchQuery, libraryProgressDependency],
  );
  const dailyPercent = Math.min(100, Math.round((stats.studiedToday / summaryProgress.dailyTarget) * 100));
  const progressPresentation = useMemo(
    () => ({ dailyPercent, progress: summaryProgress, stats }),
    [dailyPercent, stats, summaryProgress],
  );
  const homePresentation = useFocusedSnapshot(progressPresentation, activeTab === 'home');
  const studyProgress = useFocusedSnapshot(progress, activeTab === 'study');
  const libraryProgress = useFocusedSnapshot(progress, activeTab === 'library');
  const profilePresentation = useFocusedSnapshot(progressPresentation, activeTab === 'profile');
  const isPermanentAccount = Boolean(account.userId && !account.isAnonymous);
  const themeStyles = themeMode === 'dark' ? darkStyles : undefined;
  const darkMode = themeMode === 'dark';
  const libraryDragIconColor = darkMode ? '#0A84FF' : '#1C1C1E';
  const activeSystemCopy = systemCopy[studyMode];
  const activeInstallGuideSteps = installGuideStepsByMode[studyMode];
  const streakReminderPlan = useMemo(
    () => buildStreakReminderPlan(progress, new Date(streakReminderNow), streakReminderEnabled),
    [progress.lastStudyDate, progress.streak, streakReminderEnabled, streakReminderNow],
  );
  const streakLiveActivityProps = useMemo(
    () => buildStreakLiveActivityProps(streakReminderPlan, studyMode),
    [streakReminderPlan.expiresAt?.getTime(), streakReminderPlan.startsAt?.getTime(), streakReminderPlan.streak, studyMode],
  );
  const updateState = useAppUpdateCheck(studyMode);
  const cardMotionStyle = useMemo(
    () => ({
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
    }),
    [cardAnim],
  );
  const listMotionStyle = useCallback((index: number) => {
    const animationLimit = runtimePerformance.isLegacyIos ? 6 : LIBRARY_ANIMATED_ITEM_COUNT;
    if (runtimePerformance.conserveResources || index >= animationLimit) {
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
  }, [cardAnim, runtimePerformance.conserveResources, runtimePerformance.isLegacyIos]);
  const modeOverlayScale = modeTransitionAnim.interpolate({
    inputRange: [0, 1],
    outputRange: [0.94, 1],
  });
  const modeOverlayTranslateY = modeTransitionAnim.interpolate({
    inputRange: [0, 1],
    outputRange: [18, 0],
  });
  const installGuideOpacity = installGuideAnim;
  const installGuideTranslateY = installGuideAnim.interpolate({
    inputRange: [0, 1],
    outputRange: [24, 0],
  });
  const librarySliderVisible = activeTab === 'library' && libraryWords.length > 24;
  const librarySliderActive = librarySliderDragging;
  useEffect(() => {
    const interactionAnimation = Animated.spring(librarySliderInteractionAnim, {
      bounciness: 0,
      speed: librarySliderActive ? 28 : 22,
      toValue: librarySliderActive ? 1 : 0,
      useNativeDriver: Platform.OS !== 'web',
    });
    interactionAnimation.start();
    return () => interactionAnimation.stop();
  }, [librarySliderActive, librarySliderInteractionAnim]);
  const libraryDragTrackMotionStyle = {
    opacity: librarySliderInteractionAnim.interpolate({
      inputRange: [0, 1],
      outputRange: [0, 0.28],
    }),
    transform: [
      {
        scaleX: librarySliderInteractionAnim.interpolate({
          inputRange: [0, 1],
          outputRange: [0.5, 1],
        }),
      },
    ],
  };
  const libraryDragThumbMotionStyle = {
    opacity: librarySliderInteractionAnim.interpolate({
      inputRange: [0, 1],
      outputRange: [0.5, 0.92],
    }),
    transform: [
      { translateY: libraryThumbOffsetAnim },
      {
        scaleX: librarySliderInteractionAnim.interpolate({
          inputRange: [0, 1],
          outputRange: [0.72, 1.65],
        }),
      },
    ],
  };
  const beginLibrarySliderDrag = useStableEvent((locationY: number) => {
    librarySliderDraggingRef.current = true;
    setLibrarySliderDragging(true);
    triggerPressHaptic('secondary');
    handleLibrarySliderDrag(locationY);
  });
  const moveLibrarySliderDrag = useStableEvent((locationY: number) => {
    handleLibrarySliderDrag(locationY);
  });
  const endLibrarySliderDrag = useStableEvent(() => {
    finishLibrarySliderDrag();
  });
  const librarySliderGesture = useMemo(
    () =>
      Gesture.Pan()
        .enabled(activeTab === 'library')
        .minDistance(0)
        .onBegin((event) => {
          librarySliderLastY.value = event.y;
          runOnJS(beginLibrarySliderDrag)(event.y);
        })
        .onUpdate((event) => {
          const minimumTravel = runtimePerformance.conserveResources || runtimePerformance.isLegacyIos ? 6 : 3;
          if (Math.abs(event.y - librarySliderLastY.value) >= minimumTravel) {
            librarySliderLastY.value = event.y;
            runOnJS(moveLibrarySliderDrag)(event.y);
          }
        })
        .onFinalize(() => runOnJS(endLibrarySliderDrag)()),
    [
      activeTab,
      beginLibrarySliderDrag,
      endLibrarySliderDrag,
      librarySliderLastY,
      moveLibrarySliderDrag,
      runtimePerformance.conserveResources,
      runtimePerformance.isLegacyIos,
    ],
  );

  const scrollLibraryToRawOffset = useStableEvent((offset: number, animated = false) => {
    if (Platform.OS === 'web') {
      const webScrollNode = libraryListRef.current?.getScrollableNode() as
        | { scrollTo?: (options: { behavior?: 'auto' | 'smooth'; top: number }) => void; scrollTop?: number }
        | null
        | undefined;
      if (typeof webScrollNode?.scrollTo === 'function') {
        webScrollNode.scrollTo({ top: offset, behavior: animated ? 'smooth' : 'auto' });
        return;
      }
      if (webScrollNode && typeof webScrollNode.scrollTop === 'number') {
        webScrollNode.scrollTop = offset;
        return;
      }
    }

    libraryListRef.current?.scrollToOffset({ offset, animated });
  });

  const restoreLibraryRouteScroll = useStableEvent((offset: number) => {
    scrollLibraryToRawOffset(offset);
    libraryScrollYRef.current = offset;
    updateLibraryThumbFromScroll(offset);
  });

  useFocusEffect(
    useCallback(() => {
      if (Platform.OS !== 'web') {
        return undefined;
      }
      const restoreOffset = libraryRouteScrollRestoreRef.current;
      if (restoreOffset === null || activeTab !== 'library') {
        return undefined;
      }

      libraryRouteScrollRestoreRef.current = null;
      let secondFrame: number | null = null;
      const firstFrame = requestAnimationFrame(() => {
        restoreLibraryRouteScroll(restoreOffset);
        secondFrame = requestAnimationFrame(() => restoreLibraryRouteScroll(restoreOffset));
      });

      return () => {
        cancelAnimationFrame(firstFrame);
        if (secondFrame !== null) {
          cancelAnimationFrame(secondFrame);
        }
      };
    }, [activeTab, restoreLibraryRouteScroll]),
  );

  useWebServiceWorker();

  useEffect(() => {
    let timer: ReturnType<typeof setTimeout> | null = null;
    const refreshClock = () => {
      const now = new Date();
      setStreakReminderNow(now.getTime());
      const nextDate = localDateKey(now);
      setCurrentDate((current) => current === nextDate ? current : nextDate);
      const currentPlan = buildStreakReminderPlan(progress, now, streakReminderEnabled);
      const nextRefresh = nextStreakReminderRefreshAt(currentPlan, now);
      if (timer) {
        clearTimeout(timer);
      }
      timer = setTimeout(refreshClock, Math.max(1000, nextRefresh.getTime() - now.getTime() + 250));
    };
    refreshClock();
    const appStateSubscription = AppState.addEventListener('change', (state) => {
      if (state === 'active') {
        refreshClock();
      }
    });

    return () => {
      if (timer) {
        clearTimeout(timer);
      }
      appStateSubscription.remove();
    };
  }, [progress.lastStudyDate, progress.streak, streakReminderEnabled]);

  useEffect(() => {
    if (progressReady) {
      setProgress((current) => normalizeProgressForDate(current, currentDate));
    }
  }, [currentDate, progressReady]);

  useEffect(() => {
    const learningTabActive = activeTab === 'study' || activeTab === 'quiz';
    const startSession = () => {
      if (!learningTabActive || AppState.currentState !== 'active' || learningSessionRef.current) {
        return;
      }
      learningSessionRef.current = {
        date: currentDate,
        mode: studyMode,
        sourceId: streakDeviceId,
        startedAt: Date.now(),
      };
    };
    const flushSession = () => {
      const session = learningSessionRef.current;
      learningSessionRef.current = null;
      if (!session) {
        return;
      }
      const seconds = Math.round((Date.now() - session.startedAt) / 1000);
      setProgress((current) => recordLearningDuration(current, { ...session, seconds }));
    };

    startSession();
    const appStateSubscription = AppState.addEventListener('change', (state) => {
      if (state === 'active') {
        startSession();
      } else {
        flushSession();
      }
    });
    return () => {
      appStateSubscription.remove();
      flushSession();
    };
  }, [activeTab, currentDate, streakDeviceId, studyMode]);

  useEffect(() => {
    const subscription = subscribeToStreakPushToStartToken(setStreakPushToStartToken);
    return () => subscription?.remove();
  }, []);

  useEffect(() => {
    streakRegistrationQueueRef.current?.dispose();
    streakRegistrationQueueRef.current = null;
    if (!supabaseClient || !account.userId) {
      return;
    }

    const queue = new StreakReminderRegistrationQueue({
      save: (registration) => saveStreakReminderRegistration(supabaseClient, account.userId!, registration),
    });
    streakRegistrationQueueRef.current = queue;
    const appStateSubscription = AppState.addEventListener('change', (state) => {
      if (state !== 'active') {
        void queue.flush();
      }
    });

    return () => {
      appStateSubscription.remove();
      if (streakRegistrationQueueRef.current === queue) {
        streakRegistrationQueueRef.current = null;
      }
      queue.dispose();
    };
  }, [account.userId, supabaseClient]);

  useEffect(() => {
    let cancelled = false;
    syncStreakLiveActivity(streakLiveActivityProps, streakReminderPlan.activeNow)
      .then((result) => {
        if (!cancelled) {
          setStreakActivitySync(result);
        }
      })
      .catch(() => undefined);

    return () => {
      cancelled = true;
    };
  }, [streakLiveActivityProps, streakReminderPlan.activeNow]);

  useEffect(() => {
    if (!supabaseClient || !account.userId || !streakPushToStartToken) {
      return;
    }

    const expiresAt = streakReminderPlan.expiresAt?.toISOString() ?? null;
    const activityMatchesExpiration = expiresAt === streakActivitySync.startedForExpiresAt;
    const timeZone = Intl.DateTimeFormat().resolvedOptions().timeZone || 'UTC';
    streakRegistrationQueueRef.current?.enqueue({
      activityPushToken: activityMatchesExpiration ? streakActivitySync.activityPushToken : null,
      dailyTarget: progress.dailyTarget,
      deviceId: streakDeviceId,
      enabled: streakReminderEnabled,
      expiresAt,
      locale: studyMode === 'chinese' ? 'en' : 'zh-TW',
      progressDate: currentDate,
      pushToStartToken: streakPushToStartToken,
      startedForExpiresAt: activityMatchesExpiration ? streakActivitySync.startedForExpiresAt : null,
      streak: streakReminderPlan.streak,
      studiedToday: progress.studiedToday,
      timeZone,
    });
  }, [
    account.userId,
    currentDate,
    progress.dailyTarget,
    progress.studiedToday,
    streakActivitySync.activityPushToken,
    streakActivitySync.startedForExpiresAt,
    streakDeviceId,
    streakPushToStartToken,
    streakReminderEnabled,
    streakReminderPlan.expiresAt?.getTime(),
    streakReminderPlan.streak,
    studyMode,
    supabaseClient,
  ]);

  useEffect(
    () => () => {
      if (progressProtectionTimerRef.current) {
        clearTimeout(progressProtectionTimerRef.current);
      }
      if (accountUpgradeHapticTimerRef.current) {
        clearTimeout(accountUpgradeHapticTimerRef.current);
      }
    },
    [],
  );

  useEffect(() => {
    memorySyncQueueRef.current?.dispose();
    memorySyncQueueRef.current = null;
    if (!supabaseClient || !account.userId) {
      return;
    }

    const userId = account.userId;
    const cloudClient = asCloudProgressClient(supabaseClient);
    const queue = new UserMemorySyncQueue({
      saveAll: ({ customSets, progress: queuedProgress }) =>
        saveCloudUserMemory(cloudClient, userId, queuedProgress, customSets),
      saveCustomSets: (queuedCustomSets) => saveCloudCustomSets(cloudClient, userId, queuedCustomSets),
      saveProgress: (queuedProgress) => saveCloudProgress(cloudClient, userId, queuedProgress),
      storage: getAppStorage(),
      userId,
    });
    memorySyncQueueRef.current = queue;
    queue.restore();

    const appStateSubscription = AppState.addEventListener('change', () => {
      void queue.flush();
    });
    const browserWindow = Platform.OS === 'web'
      ? (globalThis as typeof globalThis & {
          addEventListener?: (type: string, listener: () => void) => void;
          removeEventListener?: (type: string, listener: () => void) => void;
        })
      : null;
    const flushWhenOnline = () => void queue.flush();
    browserWindow?.addEventListener?.('online', flushWhenOnline);

    return () => {
      appStateSubscription.remove();
      browserWindow?.removeEventListener?.('online', flushWhenOnline);
      if (memorySyncQueueRef.current === queue) {
        memorySyncQueueRef.current = null;
      }
      queue.dispose();
    };
  }, [account.userId, supabaseClient]);

  useEffect(() => {
    progressStorageWriterRef.current?.dispose();
    const userId = account.userId;
    const writer = new DeferredStorageWriter<ProgressState>(
      (queuedProgress) => saveProgressToStorage(getAppStorage(), queuedProgress, userId),
      runtimePerformance.conserveResources ? 650 : 300,
    );
    progressStorageWriterRef.current = writer;
    const appStateSubscription = AppState.addEventListener('change', (state) => {
      if (state !== 'active') {
        writer.flush();
      }
    });

    return () => {
      appStateSubscription.remove();
      if (progressStorageWriterRef.current === writer) {
        progressStorageWriterRef.current = null;
      }
      writer.dispose();
    };
  }, [account.userId, runtimePerformance.conserveResources]);

  useEffect(() => {
    saveThemePreference(getAppStorage(), themePreference);
  }, [themePreference]);

  useEffect(() => {
    saveStreakReminderEnabled(getAppStorage(), streakReminderEnabled);
  }, [streakReminderEnabled]);

  useEffect(() => {
    saveStudyMode(getAppStorage(), studyMode);
  }, [studyMode]);

  useEffect(() => {
    saveCustomSetState(getAppStorage(), customSetState, account.userId);
    if (progressReady && account.userId) {
      memorySyncQueueRef.current?.enqueue({ customSets: customSetState, progress }, { customSets: true });
    }
  }, [account.userId, customSetState, progressReady]);

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
    const visitorIdentityReady = account.isAnonymous || (!account.configured && account.status === 'local');
    if (!visitorIdentityReady || account.status === 'loading') {
      return;
    }

    if (activeFilter === 'favorites') {
      setActiveFilter('all');
    }
    if (studyFilter === 'favorites') {
      setStudyFilter('all');
    }
    if (quizFilter === 'favorites') {
      setQuizFilter('all');
    }
  }, [account.configured, account.isAnonymous, account.status, activeFilter, quizFilter, studyFilter]);

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
    if (installGuideChecked) {
      return;
    }

    setInstallGuideChecked(true);
    const shouldAutoShowInstallGuide =
      Platform.OS === 'web' &&
      !IS_WEB_IOS_PREVIEW &&
      shouldShowInstallGuide(getAppStorage(), isInstalledWebApp(), browserUserAgent(), browserMaxTouchPoints());
    if (shouldAutoShowInstallGuide) {
      openInstallGuide();
    }
  }, [installGuideChecked]);

  useEffect(() => {
    if (runtimePerformance.conserveResources) {
      cardAnim.setValue(1);
      return;
    }
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
    cardAnim,
    developerVocabulary?.importedAt,
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
    runtimePerformance.conserveResources,
  ]);

  useEffect(() => {
    updateLibraryThumbFromScroll(libraryScrollYRef.current);
  }, [libraryThumbOffsetAnim, libraryWords.length, sliderTrackHeight]);

  useEffect(() => {
    if (activeTab === 'library') {
      requestAnimationFrame(() => scrollLibraryToRawOffset(0));
    } else {
      appScrollRef.current?.scrollTo({ y: 0, animated: false });
    }
    libraryScrollYRef.current = 0;
    libraryThumbOffsetAnim.setValue(0);
    libraryScrolledPastTopRef.current = false;
    setLibraryScrolledPastTop(false);
  }, [activeTab, activeFilter, activeInitial, activeLevel, activeSort, scrollLibraryToRawOffset]);

  useEffect(() => {
    if (!progressReady || (studySession && studySession.sourceKey === studySourceKey)) {
      return;
    }
    startStudySession();
  }, [progressReady, studySession, studySourceKey]);

  useEffect(() => {
    setQuizIndex(0);
    setQuizResult(null);
    setQuizChosenText(null);
    setSpeakingAnswerVisible(false);
    setAnsweredQuizWord(null);
    setLockedQuizOptions(null);
    setQuizSession([]);
    setQuizStarted(false);
    setQuizFinished(false);
    setQuizCorrectCount(0);
    setQuizMissedIds([]);
    setQuizSeed('');
  }, [activeBankId, quizFilter, quizInitial, quizLevel]);

  useEffect(() => {
    const setIds = new Set(customSetState.sets.map((set) => set.id));
    if (selectedCustomSetId && !setIds.has(selectedCustomSetId)) {
      setSelectedCustomSetId(customSetState.sets[0]?.id ?? null);
    }
    // A bank that was deleted, or that belongs to an account that just signed
    // out, falls back to the built-in list.
    if (activeBankId !== CORE_BANK_ID && progressReady && !setIds.has(activeBankId)) {
      setActiveBankId(CORE_BANK_ID);
    }
  }, [activeBankId, customSetState.sets, progressReady, selectedCustomSetId]);

  useEffect(() => {
    saveActiveBankId(getAppStorage(), activeBankId);
  }, [activeBankId]);

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
    setQuizIndex(0);
    setQuizResult(null);
    setQuizChosenText(null);
    setAnsweredQuizWord(null);
    setLockedQuizOptions(null);
    setQuizSession([]);
    setQuizStarted(false);
    setQuizFinished(false);
    setQuizCorrectCount(0);
    setQuizMissedIds([]);
    setQuizSeed('');
  }, [developerVocabulary?.importedAt, studyMode]);

  useEffect(() => {
    const localProgress = normalizeProgressForDate(loadProgressFromStorage(getAppStorage(), initialProgress), currentDate);
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

    withTimeout(supabaseClient.auth.getSession(), 10_000, 'account session')
      .then(async ({ data, error }) => {
        if (cancelled) {
          return;
        }

        if (!error && data.session?.user) {
          const refreshed = await withTimeout(
            supabaseClient.auth.getUser(),
            10_000,
            'account refresh',
          ).catch(() => ({ data: { user: null }, error: null }));
          if (!cancelled) {
            await activateAuthenticatedUser(refreshed.data.user ?? data.session.user);
          }
          return;
        }

        const anonymous = await withTimeout(
          supabaseClient.auth.signInAnonymously(),
          10_000,
          'guest session',
        );
        if (cancelled) {
          return;
        }
        if (anonymous.error || !anonymous.data.user) {
          setAccount((current) => ({
            ...current,
            busy: false,
            isAnonymous: true,
            status: 'local',
            message: '訪客進度保存在這台裝置',
          }));
          return;
        }

        await activateAuthenticatedUser(anonymous.data.user);
      })
      .catch((error: unknown) => {
        if (cancelled) {
          return;
        }

        setAccount((current) => ({
          ...current,
          busy: false,
          isAnonymous: true,
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

    progressStorageWriterRef.current?.enqueue(progress);
    if (account.userId) {
      memorySyncQueueRef.current?.enqueue({ customSets: customSetState, progress }, { progress: true });
    }
  }, [account.userId, progress, progressReady]);

  useEffect(() => {
    if (!supabaseClient || !account.userId) {
      return;
    }

    let cancelled = false;
    let lastRecordedAt = 0;
    const recordActivity = () => {
      const now = Date.now();
      if (
        cancelled ||
        !account.userId ||
        AppState.currentState !== 'active' ||
        now - lastRecordedAt < ACTIVE_USER_HEARTBEAT_MIN_GAP_MS
      ) {
        return;
      }
      lastRecordedAt = now;

      recordDailyActiveUser(
        asCloudProgressClient(supabaseClient),
        account.userId,
        new Date(),
      ).catch(() => undefined);
    };

    recordActivity();
    const heartbeat = setInterval(recordActivity, ACTIVE_USER_HEARTBEAT_MS);
    const appStateSubscription = AppState.addEventListener('change', (state) => {
      if (state === 'active') {
        recordActivity();
      }
    });
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
      appStateSubscription.remove();
      visibilityDocument?.removeEventListener?.('visibilitychange', handleVisibility);
    };
  }, [account.isAnonymous, account.userId, supabaseClient]);

  function startStudySession(cardIds?: string[]) {
    const pool = selectStudyWords(studySourceWords, progress, studyFilter, {
      initial: studyInitial,
      level: studyLevel,
    });
    const ids = cardIds ?? buildStudyQueue(pool, progress, currentDate, {
      limit: Math.max(5, progress.dailyTarget),
    }).map((word) => word.id);
    setStudySession(createStudySession(ids, studySourceKey));
    setStudySessionSerial((current) => current + 1);
    setStudyUndo(null);
  }

  function gradeCurrentStudyCard(grade: StudyGrade) {
    const session = studySession;
    const wordId = currentStudyCardId(session);
    if (!session || !wordId) {
      return;
    }
    const before = progress;
    const after = recordTrackedLearningEvent(
      before,
      grade === 'known' ? markKnown(before, wordId, currentDate) : markReview(before, wordId, currentDate),
      grade === 'known' ? 'studyKnown' : 'studyReview',
    );
    setStudySession(gradeStudyCard(session, wordId, grade));
    setStudyUndo({ after, before, session });
    setProgress(after);
    maybePromptToProtectProgress();
  }

  function undoStudyGrade() {
    if (!studyUndo || studyUndo.after !== progress) {
      return;
    }
    setProgress(studyUndo.before);
    setStudySession(studyUndo.session);
    setStudyUndo(null);
  }

  function requestAccountUpgrade(reason: AccountUpgradeReason, afterUpgrade?: () => void) {
    if (isPermanentAccount) {
      afterUpgrade?.();
      return;
    }
    if (!account.configured) {
      setAccount((current) => ({ ...current, status: 'local', message: '帳號服務目前無法使用' }));
      return;
    }

    pendingAdvancedActionRef.current = afterUpgrade ?? null;
    if (accountUpgradeFrameRef.current !== null) {
      cancelAnimationFrame(accountUpgradeFrameRef.current);
      accountUpgradeFrameRef.current = null;
    }
    accountUpgradeAnim.stopAnimation();
    accountUpgradeAnim.setValue(0);
    setAccountUpgradeReason(reason);
  }

  function handleAccountUpgradeShown() {
    accountUpgradeFrameRef.current = requestAnimationFrame(() => {
      accountUpgradeFrameRef.current = null;
      Animated.spring(accountUpgradeAnim, {
        damping: interactionMotion.accountPromptDamping,
        mass: interactionMotion.accountPromptMass,
        overshootClamping: true,
        stiffness: interactionMotion.accountPromptStiffness,
        toValue: 1,
        useNativeDriver: Platform.OS !== 'web',
      }).start();
      accountUpgradeHapticTimerRef.current = setTimeout(() => {
        accountUpgradeHapticTimerRef.current = null;
        triggerPressHaptic('secondary');
      }, 45);
    });
  }

  function dismissAccountUpgrade() {
    if (account.busy) {
      return;
    }
    if (accountUpgradeFrameRef.current !== null) {
      cancelAnimationFrame(accountUpgradeFrameRef.current);
      accountUpgradeFrameRef.current = null;
    }
    if (accountUpgradeHapticTimerRef.current) {
      clearTimeout(accountUpgradeHapticTimerRef.current);
      accountUpgradeHapticTimerRef.current = null;
    }
    pendingAdvancedActionRef.current = null;
    Animated.timing(accountUpgradeAnim, {
      duration: interactionMotion.settingsPanelExitMs,
      easing: Easing.inOut(Easing.cubic),
      toValue: 0,
      useNativeDriver: Platform.OS !== 'web',
    }).start(({ finished }) => {
      if (finished) {
        setAccountUpgradeReason(null);
      }
    });
  }

  function maybePromptToProtectProgress() {
    const storage = getAppStorage();
    if (!account.isAnonymous || !account.userId || !shouldPromptToProtectProgress(storage)) {
      return;
    }

    markProgressProtectionPromptSeen(storage);
      if (progressProtectionTimerRef.current) {
        clearTimeout(progressProtectionTimerRef.current);
      }
      if (accountUpgradeFrameRef.current !== null) {
        cancelAnimationFrame(accountUpgradeFrameRef.current);
      }
    progressProtectionTimerRef.current = setTimeout(() => {
      progressProtectionTimerRef.current = null;
      requestAccountUpgrade('protectProgress');
    }, 650);
  }

  function recordTrackedLearningEvent(
    before: ProgressState,
    after: ProgressState,
    type: LearningEventType,
  ): ProgressState {
    return recordLearningEvent(before, after, {
      date: currentDate,
      mode: studyMode,
      sourceId: streakDeviceId,
      type,
    });
  }

  const handleLibraryQueryChange = useCallback((query: string) => {
    setSearchQuery(query);
  }, []);

  const clearLibrarySearch = useCallback(() => {
    setSearchQuery('');
  }, []);

  function handleExportVocabulary() {
    const downloaded = downloadTextFile(`word7000-vocabulary-${currentDate}.csv`, exportWordsToCsv(vocabularyWords), 'text/csv;charset=utf-8');
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
    requestAccountUpgrade('customSets', () => {
      setSetPickerWord(word);
      setNewSetName('');
    });
  }, [isPermanentAccount, account.configured, account.isAnonymous, account.userId]);

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
    if (activeBankId === setId) {
      setActiveBankId(CORE_BANK_ID);
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

    // A word typed into a scanned bank belongs to that bank, with the meaning
    // the learner typed, just like the words scanned into it. Otherwise it
    // would also appear in the core 7000-word bank.
    if (targetSet.wordIds.some(isScannedWordId)) {
      const [scannedWord] = buildScannedWords(
        [{ meaningZh: meaningText, partOfSpeech: manualCustomWord.partOfSpeech, word: wordText }],
        vocabularyWords,
      );
      if (scannedWord) {
        setCustomSetState((current) => addCustomWordToSet(current, targetSet.id, scannedWord));
        setCustomSetMessage(ui.customWordAdded(scannedWord.word, targetSet.name));
        setManualCustomWord(emptyManualCustomWord);
      }
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
      supplementalMeaningZh: manualCustomWord.supplementalMeaningZh.trim(),
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

  function handleSaveScannedWords(
    rows: ReviewedScanWord[],
    target: { kind: 'existing'; setId: string } | { kind: 'new'; name: string },
  ): string | null {
    let state = customSetState;
    let setId: string;
    if (target.kind === 'new') {
      state = createCustomSet(state, target.name.trim() || defaultScanBankName(new Date(), studyMode));
      setId = state.sets[state.sets.length - 1]?.id ?? '';
    } else {
      setId = target.setId;
    }
    const targetSet = state.sets.find((set) => set.id === setId);
    if (!targetSet) {
      return null;
    }
    // Scanning the same sheet twice should not fill the bank with copies.
    const alreadyInBank = new Set(
      wordsForCustomSet(allWords, targetSet).map((word) => word.word.toLowerCase()),
    );
    const words = buildScannedWords(
      rows.filter((row) => !alreadyInBank.has(row.word.trim().toLowerCase())),
      vocabularyWords,
    );
    // addCustomWordToSet puts each new word first, so add them in reverse to
    // keep the order they were printed in.
    const nextState = [...words].reverse().reduce((current, word) => addCustomWordToSet(current, setId, word), state);
    setCustomSetState(nextState);
    setSelectedCustomSetId(setId);
    setActiveBankId(setId);
    setCustomSetMessage(modeInterfaceCopy[studyMode].scanSaved(words.length, targetSet.name));
    return setId;
  }

  function handleStartStudySet(setId: string) {
    setActiveBankId(setId);
    setActiveTab('study');
  }

  function handleStartQuizSet(setId: string) {
    setActiveBankId(setId);
    restartQuiz();
    setActiveTab('quiz');
  }

  function handleQuizPracticeModeChange(mode: QuizPracticeMode) {
    setQuizPracticeMode(mode);
    restartQuiz();
  }

  function revealSpeakingAnswer(completed: boolean) {
    const eventKey = quizWord ? `${quizSeed}:${quizIndex}:${quizWord.id}` : null;
    if (!speakingAnswerVisible && quizWord && eventKey && speakingRecordedKeyRef.current !== eventKey) {
      speakingRecordedKeyRef.current = eventKey;
      setProgress((current) => recordTrackedLearningEvent(
        current,
        current,
        completed ? 'speakingCompleted' : 'speakingSkipped',
      ));
    }
    setSpeakingAnswerVisible(true);
  }

  function handleQuizAnswer(option: QuizOption) {
    const correct = option.correct;
    if (!quizWord) {
      return;
    }
    const eventKey = `${quizSeed}:${quizIndex}:${quizWord.id}`;
    if (answeredQuizKeyRef.current === eventKey) {
      return;
    }
    answeredQuizKeyRef.current = eventKey;
    setAnsweredQuizWord(quizWord);
    setLockedQuizOptions(quizOptions);
    setQuizResult(correct ? 'correct' : 'wrong');
    setQuizChosenText(option.meaning);
    if (correct) {
      setQuizCorrectCount((current) => current + 1);
    } else {
      const missedId = quizWord.id;
      setQuizMissedIds((current) => (current.includes(missedId) ? current : [...current, missedId]));
    }
    setProgress((current) => recordTrackedLearningEvent(
      current,
      correct ? markQuizCorrect(current, quizWord.id, currentDate) : markReview(current, quizWord.id, currentDate),
      correct ? 'quizCorrect' : 'quizWrong',
    ));
    maybePromptToProtectProgress();
  }

  function startQuiz() {
    const seed = `${Date.now()}:${Math.random()}`;
    const session = buildQuizSession(quizWords, quizQuestionCount, seed);
    setQuizSession(session);
    setQuizSeed(seed);
    setQuizIndex(0);
    setQuizCorrectCount(0);
    setQuizMissedIds([]);
    setQuizResult(null);
    setQuizChosenText(null);
    setSpeakingAnswerVisible(false);
    setAnsweredQuizWord(null);
    setLockedQuizOptions(null);
    setQuizFinished(false);
    setQuizStarted(session.length > 0);
  }

  function restartQuiz() {
    setQuizIndex(0);
    setQuizResult(null);
    setQuizChosenText(null);
    setSpeakingAnswerVisible(false);
    setAnsweredQuizWord(null);
    setLockedQuizOptions(null);
    setQuizStarted(false);
    setQuizFinished(false);
    setQuizCorrectCount(0);
    setQuizMissedIds([]);
  }

  function nextQuiz() {
    setQuizResult(null);
    setQuizChosenText(null);
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

  function handleLibraryScroll(event: NativeSyntheticEvent<NativeScrollEvent>) {
    const nextScrollY = event.nativeEvent.contentOffset.y;
    libraryScrollYRef.current = nextScrollY;
    updateLibraryThumbFromScroll(nextScrollY);
    const scrolledPastTop = nextScrollY > 180;
    if (scrolledPastTop !== libraryScrolledPastTopRef.current) {
      libraryScrolledPastTopRef.current = scrolledPastTop;
      setLibraryScrolledPastTop(scrolledPastTop);
    }
  }

  function updateLibraryThumbFromScroll(nextScrollY: number) {
    const offset = scrollThumbOffset(
      nextScrollY,
      libraryContentHeightRef.current,
      libraryViewportHeightRef.current,
      Math.max(0, sliderTrackHeight - 10),
      LIBRARY_SLIDER_THUMB_HEIGHT,
    );
    libraryThumbOffsetAnim.setValue(offset);
  }

  function handleLibrarySliderDrag(locationY: number) {
    const trackTravel = Math.max(1, sliderTrackHeight - LIBRARY_SLIDER_THUMB_HEIGHT - 10);
    const targetY = scrollTargetFromSlider(
      locationY - LIBRARY_SLIDER_THUMB_HEIGHT / 2 - 5,
      trackTravel,
      libraryContentHeightRef.current,
      libraryViewportHeightRef.current,
    );
    libraryScrollYRef.current = targetY;
    updateLibraryThumbFromScroll(targetY);
    const scrolledPastTop = targetY > 180;
    if (scrolledPastTop !== libraryScrolledPastTopRef.current) {
      libraryScrolledPastTopRef.current = scrolledPastTop;
      setLibraryScrolledPastTop(scrolledPastTop);
    }
    scrollLibraryToRawOffset(targetY);
  }

  function finishLibrarySliderDrag() {
    setLibrarySliderDragging(false);
    requestAnimationFrame(() => {
      librarySliderDraggingRef.current = false;
    });
  }

  const handleLibraryContentSizeChange = useCallback((_width: number, height: number) => {
    libraryContentHeightRef.current = Math.max(1, height);
    updateLibraryThumbFromScroll(libraryScrollYRef.current);
  }, [sliderTrackHeight]);

  const handleLibraryViewportLayout = useCallback((event: LayoutChangeEvent) => {
    libraryViewportHeightRef.current = Math.max(1, event.nativeEvent.layout.height);
    updateLibraryThumbFromScroll(libraryScrollYRef.current);
  }, [sliderTrackHeight]);

  function returnLibraryToTop() {
    libraryScrollYRef.current = 0;
    libraryThumbOffsetAnim.setValue(0);
    libraryScrolledPastTopRef.current = false;
    setLibraryScrolledPastTop(false);
    scrollLibraryToRawOffset(0, true);
  }

  const openLibraryWordDetail = useCallback((word: WordEntry) => {
    libraryRouteScrollRestoreRef.current = libraryScrollYRef.current;
    router.push({ pathname: '/library/[wordId]', params: { wordId: word.id } });
  }, [router]);

  const handleLibraryFiltersToggle = useCallback(() => {
    setLibraryFiltersOpen((current) => !current);
  }, []);

  const handleLibraryFavorite = useCallback((wordId: string) => {
    requestAccountUpgrade('favorites', () => {
      setProgress((current) => toggleFavorite(current, wordId));
    });
  }, [account.configured, account.isAnonymous, account.userId, isPermanentAccount]);

  const handleLibrarySearchBlur = useCallback(() => {
    setSearchFocused(false);
  }, []);

  const handleLibrarySearchFocus = useCallback(() => {
    setSearchFocused(true);
  }, []);

  const openLibraryCustomSets = useCallback(() => {
    requestAccountUpgrade('customSets', () => {
      libraryRouteScrollRestoreRef.current = libraryScrollYRef.current;
      router.push('/sets');
    });
  }, [account.configured, account.isAnonymous, account.userId, isPermanentAccount, router]);

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

  async function activateAuthenticatedUser(user: SupabaseUser, fallbackEmail?: string | null) {
    if (!supabaseClient) {
      return;
    }

    const storage = getAppStorage();
    const anonymous = isAnonymousUser(user);
    if (!anonymous) {
      markPermanentAccountUsed(storage);
    }
    const cloudProgress = await withTimeout(
      loadCloudProgressRecord(asCloudProgressClient(supabaseClient), user.id),
      12_000,
      'cloud memory load',
    ).catch(() => ({
      customSets: null,
      errorMessage: 'Cloud load timed out',
      found: false,
      progress: null,
    }));
    const userLocalProgress = normalizeProgressForDate(loadProgressFromStorage(storage, initialProgress, user.id), currentDate);
    const pendingMemory = loadUserMemoryOutbox(storage, user.id);
    const pendingUpgrade = anonymous ? null : loadPendingAccountUpgrade(storage);
    const legacyGuestProgress = anonymous ? loadProgressFromStorage(storage, initialProgress) : null;
    const loadedProgress = normalizeProgressForDate(
      mergeProgressStates(
        cloudProgress.progress,
        userLocalProgress,
        pendingMemory?.progress,
        legacyGuestProgress,
        pendingUpgrade?.progress,
      ),
      currentDate,
    );
    const loadedCustomSetState = mergeCustomSetStates(
      cloudProgress.customSets,
      loadCustomSetState(storage, user.id),
      anonymous ? loadCustomSetState(storage) : null,
      pendingMemory?.customSets,
      pendingUpgrade?.customSets,
    );

    setProgress(loadedProgress);
    saveProgressToStorage(storage, loadedProgress, user.id);
    setCustomSetState(loadedCustomSetState);
    saveCustomSetState(storage, loadedCustomSetState, user.id);
    setSelectedCustomSetId(null);
    setStudySession(null);
    setSetPickerWord(null);
    setAccount((current) => ({
      ...current,
      isAnonymous: anonymous,
      userId: user.id,
      userEmail: anonymous ? null : user.email ?? fallbackEmail ?? current.email,
      userName: anonymous ? null : accountNameFromUser(user),
      busy: false,
      status: anonymous ? 'guest' : 'syncing',
      message: anonymous ? '訪客進度已自動保存' : '已登入，正在背景同步',
    }));

    void withTimeout(
      saveCloudUserMemory(asCloudProgressClient(supabaseClient), user.id, loadedProgress, loadedCustomSetState),
      15_000,
      'cloud memory save',
    )
      .then((saveResult) => {
        if (saveResult.ok) {
          clearUserMemoryOutbox(storage, user.id);
          if (anonymous) {
            storage?.removeItem?.(progressStorageKey());
            storage?.removeItem?.(customSetStorageKey());
          } else {
            clearPendingAccountUpgrade(storage);
            if (pendingUpgrade?.sourceUserId && pendingUpgrade.sourceUserId !== user.id) {
              storage?.removeItem?.(progressStorageKey(pendingUpgrade.sourceUserId));
              storage?.removeItem?.(customSetStorageKey(pendingUpgrade.sourceUserId));
              clearUserMemoryOutbox(storage, pendingUpgrade.sourceUserId);
            }
          }
        }
        setAccount((current) => current.userId === user.id
          ? {
              ...current,
              status: saveResult.ok ? (anonymous ? 'guest' : 'signedIn') : 'error',
              message: saveResult.ok
                ? anonymous
                  ? '訪客進度已自動保存'
                  : cloudProgress.found ? '已登入並同步' : '已建立新的帳號記憶'
                : '進度已保存在本機，稍後會自動重試同步',
            }
          : current);
      })
      .catch(() => {
        setAccount((current) => current.userId === user.id
          ? {
              ...current,
              status: 'error',
              message: '進度已保存在本機，稍後會自動重試同步',
            }
          : current);
      });

    if (!anonymous) {
      const pendingAction = pendingAdvancedActionRef.current;
      pendingAdvancedActionRef.current = null;
      const finishUpgrade = () => {
        setAccountUpgradeReason(null);
        accountUpgradeAnim.setValue(0);
        if (pendingAction) {
          requestAnimationFrame(pendingAction);
        }
      };

      if (accountUpgradeReason) {
        Animated.timing(accountUpgradeAnim, {
          duration: 220,
          easing: Easing.inOut(Easing.cubic),
          toValue: 0,
          useNativeDriver: Platform.OS !== 'web',
        }).start(({ finished }) => {
          if (finished) {
            finishUpgrade();
          }
        });
      } else {
        finishUpgrade();
      }
    }
  }

  function stageAccountUpgrade() {
    savePendingAccountUpgrade(getAppStorage(), {
      customSets: customSetState,
      progress,
      sourceUserId: account.userId,
    });
  }

  async function handleGoogleSignIn() {
    stageAccountUpgrade();
    const storage = getAppStorage();
    const shouldLinkGuestIdentity =
      Platform.OS !== 'web' &&
      account.isAnonymous &&
      Boolean(account.userId) &&
      !hasUsedPermanentAccount(storage);
    await startGoogleSignIn(shouldLinkGuestIdentity);
  }

  async function startGoogleSignIn(linkGuestIdentity: boolean) {
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
    const nativeReturnTo = Platform.OS === 'web' ? undefined : nativeAuthRedirectTo(APP_LINKING_SCHEME);
    const credentials = {
      provider: 'google' as const,
      options: {
        ...(redirectTo ? { redirectTo } : {}),
        skipBrowserRedirect: Platform.OS !== 'web',
        queryParams: {
          prompt: 'select_account',
        },
      },
    };
    const { data, error } = linkGuestIdentity
      ? await supabaseClient.auth.linkIdentity(credentials)
      : await supabaseClient.auth.signInWithOAuth(credentials);

    if (error) {
      if (linkGuestIdentity && isIdentityAlreadyLinkedError(error)) {
        await startGoogleSignIn(false);
        return;
      }
      setAccount((current) => ({
        ...current,
        busy: false,
        status: 'error',
        message: error.message,
      }));
      return;
    }

    if (Platform.OS !== 'web') {
      if (!data.url || !nativeReturnTo) {
        setAccount((current) => ({
          ...current,
          busy: false,
          status: 'error',
          message: '無法開啟手機登入流程',
        }));
        return;
      }

      const result = await WebBrowser.openAuthSessionAsync(data.url, nativeReturnTo);
      if (result.type !== 'success') {
        setAccount((current) => ({
          ...current,
          busy: false,
          status: current.isAnonymous ? 'guest' : 'signedOut',
          message: '已取消登入',
        }));
        return;
      }

      if (linkGuestIdentity) {
        const callback = parseOAuthCallbackUrl(result.url);
        if (callback.error) {
          if (callback.errorCode === 'identity_already_exists' || /already.*(?:linked|registered)/i.test(callback.error)) {
            await startGoogleSignIn(false);
            return;
          }
          setAccount((current) => ({
            ...current,
            busy: false,
            status: 'error',
            message: callback.error ?? 'Google 帳號連結失敗',
          }));
          return;
        }

        const refreshedSession = await supabaseClient.auth.refreshSession();
        const linkedUser = refreshedSession.data.user
          ? refreshedSession
          : await supabaseClient.auth.getUser();
        if (linkedUser.error || !linkedUser.data.user || isAnonymousUser(linkedUser.data.user)) {
          setAccount((current) => ({
            ...current,
            busy: false,
            status: 'error',
            message: linkedUser.error?.message ?? 'Google 帳號連結未完成',
          }));
          return;
        }
        await activateAuthenticatedUser(linkedUser.data.user);
      } else {
        await completeNativeOAuthSignIn(result.url);
      }
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

    stageAccountUpgrade();
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

      const appleNonce = await createAppleNoncePair();
      const credential = await AppleAuthentication.signInAsync({
        nonce: appleNonce.sha256,
        state: appleNonce.raw,
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

      if (!credential.authorizationCode) {
        setAccount((current) => ({
          ...current,
          busy: false,
          status: 'error',
          message: 'Apple 登入沒有回傳授權碼',
        }));
        return;
      }

      const credentialState = await AppleAuthentication.getCredentialStateAsync(credential.user).catch(() => null);
      if (
        credentialState !== null &&
        credentialState !== AppleAuthentication.AppleAuthenticationCredentialState.AUTHORIZED
      ) {
        setAccount((current) => ({
          ...current,
          busy: false,
          status: 'error',
          message: 'Apple 帳號授權狀態無效，請重新登入',
        }));
        return;
      }

      const credentials = {
        access_token: credential.authorizationCode,
        nonce: appleNonce.raw,
        provider: 'apple' as const,
        token: credential.identityToken,
      };
      let authenticatedUser: SupabaseUser | null = null;
      let authenticationError = '';
      if (account.isAnonymous && account.userId) {
        const linkResult = await supabaseClient.auth.linkIdentity(credentials);
        if (linkResult.error && isIdentityAlreadyLinkedError(linkResult.error)) {
          const signInResult = await supabaseClient.auth.signInWithIdToken(credentials);
          authenticatedUser = signInResult.data.user;
          authenticationError = signInResult.error?.message ?? '';
        } else if (linkResult.error) {
          authenticationError = linkResult.error.message;
        } else {
          const userResult = await supabaseClient.auth.getUser();
          authenticatedUser = userResult.data.user;
          authenticationError = userResult.error?.message ?? '';
        }
      } else {
        const signInResult = await supabaseClient.auth.signInWithIdToken(credentials);
        authenticatedUser = signInResult.data.user;
        authenticationError = signInResult.error?.message ?? '';
      }

      if (!authenticatedUser) {
        setAccount((current) => ({
          ...current,
          busy: false,
          status: 'error',
          message: authenticationError || 'Apple 登入失敗',
        }));
        return;
      }

      const metadata = appleCredentialMetadata(credential.fullName, credential.email, credential.user);
      if (Object.keys(metadata).length > 0) {
        const metadataResult = await supabaseClient.auth.updateUser({ data: metadata }).catch(() => null);
        authenticatedUser = metadataResult?.data.user ?? authenticatedUser;
      }

      await activateAuthenticatedUser(authenticatedUser, credential.email);
    } catch (error: unknown) {
      const errorCode = typeof error === 'object' && error && 'code' in error ? String((error as { code?: unknown }).code) : '';
      setAccount((current) => ({
        ...current,
        busy: false,
        status: errorCode === 'ERR_REQUEST_CANCELED' ? (current.isAnonymous ? 'guest' : 'signedOut') : 'error',
        message: errorCode === 'ERR_REQUEST_CANCELED' ? '已取消登入' : error instanceof Error ? error.message : 'Apple 登入失敗',
      }));
    }
  }

  async function completeNativeOAuthSignIn(callbackUrl: string) {
    if (!supabaseClient) {
      return;
    }

    const callback = parseOAuthCallbackUrl(callbackUrl);

    if (callback.error) {
      setAccount((current) => ({
        ...current,
        busy: false,
        status: current.isAnonymous ? 'guest' : 'error',
        message: callback.error ?? '登入導回失敗',
      }));
      return;
    }

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

      await activateAuthenticatedUser(data.user);
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

      await activateAuthenticatedUser(data.user);
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

    stageAccountUpgrade();
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
      await activateAuthenticatedUser(data.user);
      return;
    }

    setAccount((current) => ({
      ...current,
      busy: false,
      status: current.isAnonymous ? 'guest' : 'signedOut',
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

    stageAccountUpgrade();
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

    await activateAuthenticatedUser(data.user);
  }

  async function handleSignOut() {
    const signedInUserId = account.userId;
    if (signedInUserId) {
      saveProgressToStorage(getAppStorage(), progress, signedInUserId);
      saveCustomSetState(getAppStorage(), customSetState, signedInUserId);
    }

    if (supabaseClient && signedInUserId) {
      const syncQueue = memorySyncQueueRef.current;
      if (syncQueue) {
        syncQueue.enqueue(
          { customSets: customSetState, progress },
          { customSets: true, progress: true },
        );
        await syncQueue.flush();
      } else {
        const saveResult = await saveCloudUserMemory(
          asCloudProgressClient(supabaseClient),
          signedInUserId,
          progress,
          customSetState,
        );
        if (saveResult.ok) {
          clearUserMemoryOutbox(getAppStorage(), signedInUserId);
        }
      }
    }

    if (supabaseClient) {
      if (signedInUserId) {
        await disableStreakReminderRegistration(supabaseClient, signedInUserId, streakDeviceId);
      }
      await supabaseClient.auth.signOut();
    }

    const guestProgress = normalizeProgressForDate(loadProgressFromStorage(getAppStorage(), initialProgress), currentDate);
    setProgress(guestProgress);
    setCustomSetState(loadCustomSetState(getAppStorage()));
    setSelectedCustomSetId(null);
    setStudySession(null);
    setSetPickerWord(null);
    setAccount((current) => ({
      ...current,
      isAnonymous: true,
      userId: null,
      userEmail: null,
      userName: null,
      password: '',
      busy: false,
      status: supabaseClient ? 'loading' : 'local',
      message: supabaseClient ? '正在切換為訪客模式' : '本機記憶中',
    }));

    if (supabaseClient) {
      const anonymous = await supabaseClient.auth.signInAnonymously();
      if (anonymous.error || !anonymous.data.user) {
        setAccount((current) => ({
          ...current,
          busy: false,
          isAnonymous: true,
          status: 'local',
          message: '已登出，訪客進度保存在這台裝置',
        }));
        return;
      }
      await activateAuthenticatedUser(anonymous.data.user);
    }
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
        status: supabaseClient ? 'guest' : 'local',
        message: supabaseClient ? '請先登入' : '本機記憶中',
      }));
      return;
    }

    setAccount((current) => ({
      ...current,
      busy: true,
      status: 'loading',
      message: '正在刪除帳號與資料',
    }));

    const result = await deleteAuthenticatedAccount(supabaseClient);
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
    clearUserMemoryOutbox(storage, signedInUserId);
    await supabaseClient.auth.signOut({ scope: 'local' }).catch(() => undefined);

    setProgress(normalizeProgressForDate(loadProgressFromStorage(storage, initialProgress), currentDate));
    setCustomSetState(loadCustomSetState(storage));
    setSelectedCustomSetId(null);
    setStudySession(null);
    setSetPickerWord(null);
    setAccount((current) => ({
      ...current,
      isAnonymous: true,
      userId: null,
      userEmail: null,
      userName: null,
      password: '',
      busy: false,
      status: 'loading',
      message: '帳號已刪除，正在建立訪客進度',
    }));

    const anonymous = await supabaseClient.auth.signInAnonymously();
    if (anonymous.error || !anonymous.data.user) {
      setAccount((current) => ({
        ...current,
        busy: false,
        isAnonymous: true,
        status: 'local',
        message: '帳號已刪除，訪客進度保存在這台裝置',
      }));
      return;
    }
    await activateAuthenticatedUser(anonymous.data.user);
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
    if (runtimePerformance.conserveResources) {
      setStudyMode(nextMode);
      return;
    }
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

  const homeStartStudy = useStableEvent(() => {
    // A finished set would greet the learner with its summary; from the home
    // screen they asked to study, so deal a fresh set instead.
    if (studySessionDone) {
      startStudySession();
    }
    setActiveTab('study');
  });
  const homeOpenReview = useStableEvent(() => {
    setActiveFilter('review');
    setActiveTab('library');
  });
  const homeOpenDictionaryWord = useStableEvent((word: WordEntry) => {
    router.push({ pathname: '/library/[wordId]', params: { source: 'home', wordId: word.id } });
  });
  const homeToggleStudyMode = useStableEvent(toggleStudyMode);
  const openBankPicker = useStableEvent(() => setBankPickerOpen(true));
  const closeBankPicker = useStableEvent(() => setBankPickerOpen(false));
  const selectBank = useStableEvent((bankId: string) => {
    setBankPickerOpen(false);
    if (bankId === CORE_BANK_ID) {
      setActiveBankId(CORE_BANK_ID);
      return;
    }
    requestAccountUpgrade('customSets', () => setActiveBankId(bankId));
  });
  const openScanner = useStableEvent(() => {
    setBankPickerOpen(false);
    requestAccountUpgrade('customSets', () => router.push('/scan'));
  });
  const manageBanks = useStableEvent(() => {
    setBankPickerOpen(false);
    openLibraryCustomSets();
  });
  const studyToggleFilters = useStableEvent(() => setStudyFiltersOpen((current) => !current));
  const studySwipeKnown = useStableEvent(() => gradeCurrentStudyCard('known'));
  const studySwipeReview = useStableEvent(() => gradeCurrentStudyCard('review'));
  const studyUndoGrade = useStableEvent(undoStudyGrade);
  const studyNextSession = useStableEvent(() => startStudySession());
  const studyReviewMissed = useStableEvent(() => {
    if (studySession && studySession.reviewIds.length > 0) {
      startStudySession(studySession.reviewIds);
    }
  });
  const studyOpenQuiz = useStableEvent(() => setActiveTab('quiz'));
  const studyFavoriteWord = useStableEvent(() => {
    if (studyWord) {
      const wordId = studyWord.id;
      requestAccountUpgrade('favorites', () => {
        setProgress((current) => toggleFavorite(current, wordId));
      });
    }
  });
  const studyFilterChange = useStableEvent((filter: LibraryFilter) => {
    const reason = accountUpgradeReasonForFilter(filter);
    if (reason) {
      requestAccountUpgrade(reason, () => setStudyFilter(filter));
      return;
    }
    setStudyFilter(filter);
  });
  const quizToggleFilters = useStableEvent(() => setQuizFiltersOpen((current) => !current));
  const quizAnswer = useStableEvent(handleQuizAnswer);
  const quizPracticeModeChange = useStableEvent(handleQuizPracticeModeChange);
  const quizNextQuestion = useStableEvent(nextQuiz);
  const quizRevealAnswer = useStableEvent(revealSpeakingAnswer);
  const quizRestart = useStableEvent(restartQuiz);
  const quizPracticeMissed = useStableEvent(() => {
    if (quizMissedIds.length === 0) {
      return;
    }
    startStudySession(quizMissedIds);
    setActiveTab('study');
  });
  const quizStart = useStableEvent(startQuiz);
  const quizFilterChange = useStableEvent((filter: LibraryFilter) => {
    const reason = accountUpgradeReasonForFilter(filter);
    if (reason) {
      requestAccountUpgrade(reason, () => setQuizFilter(filter));
      return;
    }
    setQuizFilter(filter);
  });
  const libraryContentSizeChange = useStableEvent(handleLibraryContentSizeChange);
  const libraryScroll = useStableEvent(handleLibraryScroll);
  const libraryViewportLayout = useStableEvent(handleLibraryViewportLayout);
  const libraryQueryChange = useStableEvent(handleLibraryQueryChange);
  const libraryQueryClear = useStableEvent(clearLibrarySearch);
  const librarySearchBlur = useStableEvent(handleLibrarySearchBlur);
  const librarySearchFocus = useStableEvent(handleLibrarySearchFocus);
  const libraryFilterChange = useStableEvent((filter: LibraryFilter) => {
    const reason = accountUpgradeReasonForFilter(filter);
    if (reason) {
      requestAccountUpgrade(reason, () => setActiveFilter(filter));
      return;
    }
    setActiveFilter(filter);
  });
  const profileEmailChange = useStableEvent((email: string) => setAccount((current) => ({ ...current, email })));
  const profilePasswordChange = useStableEvent((password: string) => setAccount((current) => ({ ...current, password })));
  const profileOpenSettings = useStableEvent(() => router.push('/settings'));
  const profileOpenStats = useStableEvent(() => router.push('/stats'));
  const profileAppleSignIn = useStableEvent(handleAppleSignIn);
  const profileGoogleSignIn = useStableEvent(handleGoogleSignIn);
  const profileShowInstallGuide = useStableEvent(openInstallGuide);
  const profileSignIn = useStableEvent(handleSignIn);
  const profileSignOut = useStableEvent(handleSignOut);
  const profileSignUp = useStableEvent(handleSignUp);
  const profileOpenFavorites = useStableEvent(() => {
    requestAccountUpgrade('favorites', () => {
      setActiveFilter('favorites');
      setActiveTab('library');
    });
  });

  const routeAddWordToSet = useStableEvent((word: WordEntry, setId: string) => {
    const setName = customSetState.sets.find((set) => set.id === setId)?.name ?? '';
    setCustomSetState((current) => addWordToSet(current, setId, word.id));
    setSelectedCustomSetId(setId);
    setCustomSetMessage(modeInterfaceCopy[studyMode].addedToSet(formatWordPrimary(word, studyMode), setName));
  });
  const routeCreateSetAndAddWord = useStableEvent((word: WordEntry, name: string) => {
    const withSet = createCustomSet(customSetState, name);
    const createdSet = withSet.sets[withSet.sets.length - 1] ?? null;
    setCustomSetState(createdSet ? addWordToSet(withSet, createdSet.id, word.id) : withSet);
    if (createdSet) {
      setSelectedCustomSetId(createdSet.id);
      setCustomSetMessage(modeInterfaceCopy[studyMode].addedToSet(formatWordPrimary(word, studyMode), createdSet.name));
    }
  });
  const routeFavoriteWord = useStableEvent((wordId: string) => {
    requestAccountUpgrade('favorites', () => {
      setProgress((current) => toggleFavorite(current, wordId));
    });
  });
  const routeAddManualCustomWord = useStableEvent(handleAddManualCustomWord);
  const routeClearDeveloperVocabulary = useStableEvent(handleClearDeveloperVocabulary);
  const routeConfirmDeleteAccountData = useStableEvent(confirmDeleteAccountData);
  const routeCreateCustomSet = useStableEvent(handleCreateCustomSet);
  const routeDeleteCustomSet = useStableEvent(handleDeleteCustomSet);
  const routeExportVocabulary = useStableEvent(() => requestAccountUpgrade('dataTools', handleExportVocabulary));
  const routeImportCustomWords = useStableEvent(() => requestAccountUpgrade('customSets', handleImportCustomWords));
  const routeImportVocabulary = useStableEvent(() => requestAccountUpgrade('dataTools', () => void handleImportVocabulary()));
  const routeManualCustomWordChange = useStableEvent(handleManualCustomWordChange);
  const routeOpenAppInfoLink = useStableEvent(handleOpenAppInfoLink);
  const routeRemoveWordFromSet = useStableEvent(handleRemoveWordFromCustomSet);
  const routeRenameCustomSet = useStableEvent(handleRenameCustomSet);
  const routeRequestAccountUpgrade = useStableEvent(requestAccountUpgrade);
  const routeRestoreLibraryScroll = useStableEvent(() => {
    if (Platform.OS !== 'web') {
      return;
    }
    const restoreOffset = libraryRouteScrollRestoreRef.current;
    if (restoreOffset === null) {
      return;
    }

    libraryRouteScrollRestoreRef.current = null;
    restoreLibraryRouteScroll(restoreOffset);
    requestAnimationFrame(() => {
      restoreLibraryRouteScroll(restoreOffset);
      requestAnimationFrame(() => restoreLibraryRouteScroll(restoreOffset));
    });
    setTimeout(() => restoreLibraryRouteScroll(restoreOffset), 420);
  });
  const routeSetStreakReminderEnabled = useStableEvent(setStreakReminderEnabled);
  const routeSetThemePreference = useStableEvent((preference: ThemePreference) => setThemePreference(preference));
  const routeSetDailyTarget = useStableEvent((target: number) => {
    const nextTarget = Math.max(5, Math.min(100, Math.round(target)));
    setProgress((current) => (current.dailyTarget === nextTarget ? current : { ...current, dailyTarget: nextTarget }));
  });
  const routeStartQuizSet = useStableEvent(handleStartQuizSet);
  const routeSaveScannedWords = useStableEvent(handleSaveScannedWords);
  const routeStartStudySet = useStableEvent(handleStartStudySet);
  const routeActions = useMemo(
    () => ({
      addManualCustomWord: routeAddManualCustomWord,
      addWordToSet: routeAddWordToSet,
      clearDeveloperVocabulary: routeClearDeveloperVocabulary,
      confirmDeleteAccountData: routeConfirmDeleteAccountData,
      createCustomSet: routeCreateCustomSet,
      createSetAndAddWord: routeCreateSetAndAddWord,
      deleteCustomSet: routeDeleteCustomSet,
      exportVocabulary: routeExportVocabulary,
      favoriteWord: routeFavoriteWord,
      importCustomWords: routeImportCustomWords,
      importVocabulary: routeImportVocabulary,
      manualCustomWordChange: routeManualCustomWordChange,
      newSetNameChange: setNewSetName,
      openAppInfoLink: routeOpenAppInfoLink,
      removeWordFromSet: routeRemoveWordFromSet,
      renameCustomSet: routeRenameCustomSet,
      requestAccountUpgrade: routeRequestAccountUpgrade,
      restoreLibraryScroll: routeRestoreLibraryScroll,
      saveScannedWords: routeSaveScannedWords,
      selectCustomSet: setSelectedCustomSetId,
      setCustomSetSort,
      setStreakReminderEnabled: routeSetStreakReminderEnabled,
      setDailyTarget: routeSetDailyTarget,
      setThemePreference: routeSetThemePreference,
      startQuizSet: routeStartQuizSet,
      startStudySet: routeStartStudySet,
    }),
    [
      routeAddManualCustomWord,
      routeAddWordToSet,
      routeClearDeveloperVocabulary,
      routeConfirmDeleteAccountData,
      routeCreateCustomSet,
      routeCreateSetAndAddWord,
      routeDeleteCustomSet,
      routeExportVocabulary,
      routeFavoriteWord,
      routeImportCustomWords,
      routeImportVocabulary,
      routeManualCustomWordChange,
      routeOpenAppInfoLink,
      routeRemoveWordFromSet,
      routeRenameCustomSet,
      routeRequestAccountUpgrade,
      routeRestoreLibraryScroll,
      routeSaveScannedWords,
      routeSetStreakReminderEnabled,
      routeSetDailyTarget,
      routeSetThemePreference,
      routeStartQuizSet,
      routeStartStudySet,
    ],
  );

  useEffect(() => {
    setAppRouteBridgeSnapshot({
      accountBusy: account.busy,
      accountReady: Boolean(account.userId),
      actions: routeActions,
      customSetMessage,
      customSetSort,
      customSetState,
      customSets: sortedCustomSets,
      developerMessage: developerVocabularyMessage,
      developerVocabulary,
      manualCustomWord,
      newSetName,
      progress,
      selectedCustomSetId,
      signedIn: isPermanentAccount,
      streakReminderEnabled,
      studyMode,
      themeMode,
      themePreference,
      vocabularyWords: allWords,
    });
  }, [
    account.busy,
    account.isAnonymous,
    account.userId,
    customSetMessage,
    customSetSort,
    customSetState,
    developerVocabulary,
    developerVocabularyMessage,
    manualCustomWord,
    newSetName,
    progress,
    routeActions,
    selectedCustomSetId,
    sortedCustomSets,
    streakReminderEnabled,
    studyMode,
    themeMode,
    themePreference,
    allWords,
  ]);

  useEffect(() => () => setAppRouteBridgeSnapshot(null), []);

  // Assembled here rather than passed as a dozen animated values: these
  // controls read from state that belongs to this provider, so the library
  // route just drops the finished node into place.
  const libraryFloatingControls = (
    <View pointerEvents="box-none" style={styles.libraryFixedControls}>
      {libraryScrolledPastTop && (
        <AnimatedPressable
          accessibilityRole="button"
          glassTone="secondary"
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
        <GestureDetector gesture={librarySliderGesture}>
          <View
            onLayout={(event) => setSliderTrackHeight(event.nativeEvent.layout.height)}
            style={[
              styles.libraryDragSlider,
              themeStyles?.libraryDragSlider,
            ]}
            testID="library-drag-slider"
          >
            <Animated.View
              style={[
                styles.libraryDragTrack,
                themeStyles?.libraryDragTrack,
                libraryDragTrackMotionStyle,
              ]}
            />
            <Animated.View
              style={[
                styles.libraryDragThumb,
                themeStyles?.libraryDragThumb,
                libraryDragThumbMotionStyle,
              ]}
              testID="library-drag-thumb"
            />
          </View>
        </GestureDetector>
      )}
    </View>
  );

  const currentScreenProps: AppScreenProps = {
    homeProps: {
      bankCount: bankWords.length,
      bankIsScan,
      bankName,
      onOpenBankPicker: openBankPicker,
      dailyPercent: homePresentation.dailyPercent,
      progress: homePresentation.progress,
      stats: homePresentation.stats,
      studyMode,
      updateStatus: updateState.manualStatus,
      vocabularyWords: allWords,
      onCheckForUpdate: updateState.checkNow,
      onOpenDictionaryWord: homeOpenDictionaryWord,
      onOpenQuiz: studyOpenQuiz,
      onOpenStats: profileOpenStats,
      onStartStudy: homeStartStudy,
      onOpenReview: homeOpenReview,
      onToggleStudyMode: homeToggleStudyMode,
    },
    studyProps: {
      activeFilter: studyFilter,
      activeInitial: studyInitial,
      activeLevel: studyLevel,
      canUndo: studyCanUndo,
      cardSequence: studySessionSerial * 10_000 + (studySession?.index ?? 0),
      filtersOpen: studyFiltersOpen,
      levelOptions: levelFilterOptions,
      motionStyle: cardMotionStyle,
      nextWord: studyDeckNextWord,
      sessionComplete: studySessionDone,
      sessionKnownCount: studySession?.knownIds.length ?? 0,
      sessionProgress: studySessionProgress(studySession),
      sessionReviewCount: studySession?.reviewIds.length ?? 0,
      studiedToday: studyProgress.studiedToday,
      dailyTarget: studyProgress.dailyTarget,
      streak: studyProgress.streak,
      studyMode,
      bankCount: bankWords.length,
      bankIsScan,
      bankName,
      customSetsLocked: !isPermanentAccount,
      favoriteLocked: !isPermanentAccount,
      wordCount: studyWords.length,
      word: studyWord,
      progress: studyProgress,
      onOpenBankPicker: openBankPicker,
      onFilterChange: studyFilterChange,
      onFiltersToggle: studyToggleFilters,
      onInitialChange: setStudyInitial,
      onLevelChange: setStudyLevel,
      onNextSession: studyNextSession,
      onOpenQuiz: studyOpenQuiz,
      onReviewMissed: studyReviewMissed,
      onSwipeKnown: studySwipeKnown,
      onSwipeReview: studySwipeReview,
      onUndo: studyUndoGrade,
      onAddToSet: handleOpenSetPicker,
      onFavorite: studyFavoriteWord,
    },
    quizProps: {
      activeFilter: quizFilter,
      activeInitial: quizInitial,
      activeLevel: quizLevel,
      filtersOpen: quizFiltersOpen,
      levelOptions: levelFilterOptions,
      motionStyle: cardMotionStyle,
      conversationPrompt,
      options: visibleQuizOptions,
      practiceMode: quizPracticeMode,
      questionCount: quizQuestionCount,
      questionCounts: quizQuestionCounts,
      questionIndex: quizIndex,
      quizFinished,
      quizStarted,
      result: quizResult,
      sessionTotal: quizSessionTotal,
      speakingAnswerVisible,
      studyMode,
      favoriteLocked: !isPermanentAccount,
      bankCount: bankWords.length,
      bankIsScan,
      bankName,
      chosenText: quizChosenText,
      correctCount: quizCorrectCount,
      missedWords: quizMissedIds
        .map((wordId) => vocabularyById.get(wordId))
        .filter((entry): entry is WordEntry => Boolean(entry)),
      onPracticeMissed: quizPracticeMissed,
      word: visibleQuizWord,
      wordCount: quizWords.length,
      onAnswer: quizAnswer,
      onOpenBankPicker: openBankPicker,
      onFilterChange: quizFilterChange,
      onFiltersToggle: quizToggleFilters,
      onInitialChange: setQuizInitial,
      onLevelChange: setQuizLevel,
      onPracticeModeChange: quizPracticeModeChange,
      onNext: quizNextQuestion,
      onQuestionCountChange: setQuizQuestionCount,
      onRevealSpeakingAnswer: quizRevealAnswer,
      onRestart: quizRestart,
      onStart: quizStart,
    },
    libraryProps: {
      activeFilter,
      bankCount: bankWords.length,
      bankIsScan,
      bankName,
      onOpenBankPicker: openBankPicker,
      onOpenScanner: openScanner,
      activeInitial,
      activeLevel,
      activeSort,
      customSets: sortedCustomSets,
      filtersOpen: libraryFiltersOpen,
      levelOptions: levelFilterOptions,
      listMotionStyle,
      listRef: libraryListRef,
      progress: libraryProgress,
      query: searchQuery,
      searchFocused,
      studyMode,
      customSetsLocked: !isPermanentAccount,
      favoriteLocked: !isPermanentAccount,
      words: libraryWords,
      onAddToSet: handleOpenSetPicker,
      onContentSizeChange: libraryContentSizeChange,
      onFilterChange: libraryFilterChange,
      onFiltersToggle: handleLibraryFiltersToggle,
      onFavorite: handleLibraryFavorite,
      onInitialChange: setActiveInitial,
      onLevelChange: setActiveLevel,
      onOpenWord: openLibraryWordDetail,
      onOpenCustomSets: openLibraryCustomSets,
      onQueryChange: libraryQueryChange,
      onQueryClear: libraryQueryClear,
      onScroll: libraryScroll,
      onSearchBlur: librarySearchBlur,
      onSearchFocus: librarySearchFocus,
      onSortChange: setActiveSort,
      onViewportLayout: libraryViewportLayout,
    },
    profileProps: {
      account,
      analytics: personalAnalytics,
      dailyPercent: profilePresentation.dailyPercent,
      progress: profilePresentation.progress,
      stats: profilePresentation.stats,
      studyMode,
      themeMode,
      onEmailChange: profileEmailChange,
      onAppleSignIn: profileAppleSignIn,
      onGoogleSignIn: profileGoogleSignIn,
      onOpenSettings: profileOpenSettings,
      onOpenStats: profileOpenStats,
      onOpenFavorites: profileOpenFavorites,
      onPasswordChange: profilePasswordChange,
      onShowInstallGuide: profileShowInstallGuide,
      onSignIn: profileSignIn,
      onSignOut: profileSignOut,
      onSignUp: profileSignUp,
    },
    libraryChrome: { floatingControls: libraryFloatingControls },
  };
  const homeScreenProps = useFocusedSnapshot(currentScreenProps.homeProps, activeTab === 'home');
  const studyScreenProps = useFocusedSnapshot(currentScreenProps.studyProps, activeTab === 'study');
  const quizScreenProps = useFocusedSnapshot(currentScreenProps.quizProps, activeTab === 'quiz');
  const profileScreenProps = useFocusedSnapshot(currentScreenProps.profileProps, activeTab === 'profile');
  const libraryScreenProps = useFocusedSnapshot(
    {
      libraryChrome: currentScreenProps.libraryChrome,
      libraryProps: currentScreenProps.libraryProps,
    },
    activeTab === 'library',
  );

  return (
    <StudyModeContext.Provider value={studyMode}>
    <HomeScreenPropsContext.Provider value={homeScreenProps}>
    <StudyScreenPropsContext.Provider value={studyScreenProps}>
    <QuizScreenPropsContext.Provider value={quizScreenProps}>
    <ProfileScreenPropsContext.Provider value={profileScreenProps}>
    <LibraryScreenPropsContext.Provider value={libraryScreenProps}>
    <ThemeContext.Provider value={themeMode}>
      {/* A plain View, not SafeAreaView: on iOS the native header and native
          tab bar own the safe area now, and wrapping them would have the app
          subtract insets the system has already accounted for. This layer only
          survives for the web iPhone preview frame. */}
      <View style={[styles.safeArea, themeStyles?.safeArea, IS_WEB_IOS_PREVIEW && styles.webIosPreviewSafeArea]}>
      <StatusBar style={darkMode ? 'light' : 'dark'} />
      <View style={[styles.appShell, IS_WEB_IOS_PREVIEW && styles.webIosPreviewAppShell, themeStyles?.appShell]}>
        {children}

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

        <WordBankPickerSheet
          activeBankId={activeBank ? activeBankId : CORE_BANK_ID}
          canScan={isPermanentAccount}
          coreCount={vocabularyWords.length}
          sets={sortedCustomSets}
          studyMode={studyMode}
          visible={bankPickerOpen}
          onClose={closeBankPicker}
          onManage={manageBanks}
          onScan={openScanner}
          onSelect={selectBank}
        />

        <AccountUpgradeOverlay
          accountBusy={account.busy}
          animation={accountUpgradeAnim}
          reason={accountUpgradeReason ?? 'protectProgress'}
          studyMode={studyMode}
          themeMode={themeMode}
          visible={Boolean(accountUpgradeReason)}
          onAppleSignIn={handleAppleSignIn}
          onDismiss={dismissAccountUpgrade}
          onGoogleSignIn={handleGoogleSignIn}
          onShown={handleAccountUpgradeShown}
        />


        {showModeSwitch && (
          <ModeSwitchOverlay
            mode={modeSwitchTarget}
            opacity={modeTransitionAnim}
            scale={modeOverlayScale}
            translateY={modeOverlayTranslateY}
          />
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
      </View>
    </ThemeContext.Provider>
    </LibraryScreenPropsContext.Provider>
    </ProfileScreenPropsContext.Provider>
    </QuizScreenPropsContext.Provider>
    </StudyScreenPropsContext.Provider>
    </HomeScreenPropsContext.Provider>
    </StudyModeContext.Provider>
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

    if (Platform.OS !== 'web' || IS_WEB_IOS_PREVIEW || __DEV__ || !serviceWorker) {
      return;
    }

    serviceWorker.register('/service-worker.js').catch(() => undefined);
  }, []);
}

function AppStorageBootScreen({ failed = false }: { failed?: boolean }) {
  const reopen = () => {
    import('expo-updates')
      .then((updates) => {
        if (updates.isEnabled) {
          return updates.reloadAsync();
        }
        return undefined;
      })
      .catch(() => undefined);
  };

  return (
    <SafeAreaView style={styles.safeArea}>
      <View style={styles.appStorageBootScreen}>
        <BrandMark size={82} style={styles.launchIcon} />
        <Text style={styles.appStorageBootTitle}>Word7000</Text>
        <Text style={styles.appStorageBootText}>
          {failed
            ? '無法完成啟動，但你的學習紀錄仍安全保存在裝置中。'
            : '正在準備你的學習紀錄...'}
        </Text>
        {failed && (
          <Pressable accessibilityRole="button" onPress={reopen} style={styles.appStorageBootButton}>
            <Text style={styles.appStorageBootButtonText}>重新開啟 Word7000</Text>
          </Pressable>
        )}
      </View>
    </SafeAreaView>
  );
}

function useAppUpdateCheck(studyMode: StudyMode): UpdateState {
  const [available, setAvailable] = useState(false);
  const [countdownSeconds, setCountdownSeconds] = useState(Math.ceil(UPDATE_AUTO_REFRESH_MS / 1000));
  const [latestVersion, setLatestVersion] = useState<string | null>(null);
  const [manualStatus, setManualStatus] = useState<ManualUpdateStatus>('idle');
  const [nativeStoreUpdate, setNativeStoreUpdate] = useState<IosUpdateDecision | null>(null);
  const nativeCheckPromiseRef = useRef<Promise<boolean> | null>(null);
  const copy = systemCopy[studyMode];

  const refresh = useCallback(() => {
    if (Platform.OS !== 'web') {
      if (nativeStoreUpdate?.required) {
        Linking.openURL(nativeStoreUpdate.testFlightUrl).catch(() => undefined);
        return;
      }
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
  }, [latestVersion, nativeStoreUpdate]);

  const checkNativeStoreUpdate = useCallback(async (): Promise<IosUpdateDecision | null> => {
    if (Platform.OS !== 'ios' || __DEV__ || IS_WEB_IOS_PREVIEW) {
      return null;
    }

    try {
      const currentBuild = Constants.platform?.ios?.buildNumber;
      if (!currentBuild) {
        return null;
      }
      const response = await withTimeout(
        fetch(`${IOS_UPDATE_POLICY_URL}?t=${Date.now()}`, {
          headers: {
            Accept: 'application/json',
            'Cache-Control': 'no-cache',
          },
        }),
        8000,
        'version policy',
      );
      if (!response.ok) {
        return null;
      }
      const policy = parseIosUpdatePolicy(await response.json());
      if (!policy) {
        return null;
      }

      const decision = iosUpdateDecision(currentBuild, policy);
      setNativeStoreUpdate(decision.available ? decision : null);
      if (decision.required) {
        setAvailable(true);
      }
      return decision;
    } catch {
      return null;
    }
  }, []);

  const downloadNativeUpdate = useCallback(async (): Promise<boolean> => {
    if (nativeCheckPromiseRef.current) {
      return nativeCheckPromiseRef.current;
    }

    const checkPromise = withTimeout((async () => {
      const updates = await import('expo-updates');
      if (!updates.isEnabled) {
        throw new Error('updates-disabled');
      }

      const update = await updates.checkForUpdateAsync();
      if (!update.isAvailable) {
        return false;
      }

      await updates.fetchUpdateAsync();
      return true;
    })(), 25_000, 'app update');
    nativeCheckPromiseRef.current = checkPromise;

    try {
      return await checkPromise;
    } finally {
      if (nativeCheckPromiseRef.current === checkPromise) {
        nativeCheckPromiseRef.current = null;
      }
    }
  }, []);

  useEffect(() => {
    if (Platform.OS !== 'web' || IS_WEB_IOS_PREVIEW || __DEV__) {
      return;
    }

    let cancelled = false;

    async function checkVersion() {
      setManualStatus('checking');
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
          setManualStatus('current');
          return;
        }

        if (storedVersion !== version) {
          setLatestVersion(version);
          setCountdownSeconds(Math.ceil(UPDATE_AUTO_REFRESH_MS / 1000));
          setManualStatus('available');
          setAvailable(true);
          return;
        }
        setManualStatus('current');
      } catch {
        if (!cancelled) {
          setManualStatus('error');
        }
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
    let lastCheckedAt = 0;

    async function checkNativeUpdate(force = false) {
      const now = Date.now();
      if (!force && now - lastCheckedAt < NATIVE_UPDATE_CHECK_COOLDOWN_MS) {
        return;
      }
      lastCheckedAt = now;
      setManualStatus('checking');
      try {
        const storeDecision = await checkNativeStoreUpdate();
        if (cancelled) {
          return;
        }
        if (storeDecision?.required) {
          setManualStatus('available');
          return;
        }

        const updateDownloaded = await downloadNativeUpdate();
        if (cancelled) {
          return;
        }
        if (!updateDownloaded) {
          setManualStatus(storeDecision?.available ? 'available' : 'current');
          return;
        }

        setCountdownSeconds(Math.ceil(UPDATE_AUTO_REFRESH_MS / 1000));
        setManualStatus('available');
        setAvailable(true);
      } catch {
        if (!cancelled) {
          setManualStatus('error');
        }
      }
    }

    void checkNativeUpdate(true);
    const appStateSubscription = AppState.addEventListener('change', (state) => {
      if (state === 'active') {
        void checkNativeUpdate(false);
      }
    });

    return () => {
      cancelled = true;
      appStateSubscription.remove();
    };
  }, [checkNativeStoreUpdate, downloadNativeUpdate]);

  const checkNow = useCallback(() => {
    if (manualStatus === 'checking') {
      return;
    }

    setManualStatus('checking');
    void (async () => {
      try {
        if (__DEV__ || IS_WEB_IOS_PREVIEW) {
          setManualStatus('current');
          return;
        }

        if (Platform.OS === 'web') {
          const response = await fetch(`/version.json?t=${Date.now()}`, { cache: 'no-store' });
          if (!response.ok) {
            throw new Error('version-check-failed');
          }
          const data: unknown = await response.json();
          const version = typeof (data as { version?: unknown }).version === 'string'
            ? (data as { version: string }).version
            : '';
          if (!version) {
            throw new Error('version-missing');
          }

          const storage = getAppStorage();
          const storedVersion = storage?.getItem(UPDATE_STORAGE_KEY);
          if (storedVersion && storedVersion !== version) {
            storage?.setItem(UPDATE_STORAGE_KEY, version);
            setLatestVersion(version);
            (globalThis as { location?: { reload: () => void } }).location?.reload();
            return;
          }
          if (!storedVersion) {
            storage?.setItem(UPDATE_STORAGE_KEY, version);
          }
          setManualStatus('current');
          return;
        }

        if (nativeStoreUpdate?.available) {
          await Linking.openURL(nativeStoreUpdate.testFlightUrl);
          setManualStatus('available');
          return;
        }

        const storeDecision = await checkNativeStoreUpdate();
        if (storeDecision?.available) {
          setManualStatus('available');
          await Linking.openURL(storeDecision.testFlightUrl);
          return;
        }

        if (available || manualStatus === 'available') {
          refresh();
          return;
        }

        const updateDownloaded = await downloadNativeUpdate();
        if (!updateDownloaded) {
          setManualStatus('current');
          return;
        }

        setAvailable(true);
        const updates = await import('expo-updates');
        await updates.reloadAsync();
      } catch {
        setManualStatus('error');
      }
    })();
  }, [available, checkNativeStoreUpdate, downloadNativeUpdate, manualStatus, nativeStoreUpdate, refresh]);

  useEffect(() => {
    if (!available || nativeStoreUpdate?.required) {
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
  }, [available, nativeStoreUpdate, refresh]);

  return {
    available,
    buttonText: nativeStoreUpdate?.required ? copy.testFlightUpdateButton : copy.updateNow,
    checkNow,
    countdownSeconds,
    countdownText: nativeStoreUpdate?.required ? copy.testFlightUpdateHint : copy.updateCountdown(countdownSeconds),
    detail: nativeStoreUpdate?.required ? copy.testFlightUpdateDetail : copy.updateDetail,
    manualStatus,
    message: copy.updateTitle,
    refresh,
  };
}

function loadThemePreference(storage?: StorageLike): ThemePreference {
  try {
    const stored = storage?.getItem(THEME_STORAGE_KEY);
    // Nothing stored means a first launch: follow the system appearance.
    return stored === 'dark' || stored === 'light' ? stored : 'system';
  } catch {
    return 'system';
  }
}

function saveThemePreference(storage: StorageLike | undefined, preference: ThemePreference) {
  try {
    storage?.setItem(THEME_STORAGE_KEY, preference);
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

function loadStudyAutoReveal(storage?: StorageLike): boolean {
  try {
    return storage?.getItem(STUDY_AUTO_REVEAL_STORAGE_KEY) === '1';
  } catch {
    return false;
  }
}

function saveStudyAutoReveal(storage: StorageLike | undefined, autoReveal: boolean) {
  try {
    storage?.setItem(STUDY_AUTO_REVEAL_STORAGE_KEY, autoReveal ? '1' : '0');
  } catch {
    // The toggle still works for this session if storage is blocked.
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

function primaryChineseMeaning(word: WordEntry): string {
  return conciseChineseMeaning(word.meaningZh);
}

function wordSupplementalChineseMeaning(word: WordEntry): string {
  return word.supplementalMeaningZh?.trim() || supplementalChineseMeaning(word.meaningZh);
}

function formatWordPrimary(word: WordEntry, studyMode: StudyMode): string {
  return studyMode === 'chinese' ? primaryChineseMeaning(word) : word.word;
}

function formatWordSecondary(word: WordEntry, studyMode: StudyMode): string {
  return studyMode === 'chinese' ? `${word.word} ${word.pronunciation}` : word.pronunciation;
}

function formatWordPinyin(word: WordEntry, studyMode: StudyMode): string {
  return studyMode === 'chinese' ? chineseMeaningPinyin(primaryChineseMeaning(word)) : '';
}

function formatMeaningDetail(word: WordEntry, studyMode: StudyMode): string {
  return studyMode === 'chinese' ? word.word : primaryChineseMeaning(word);
}

function formatMeaningSupplement(word: WordEntry): string {
  return wordSupplementalChineseMeaning(word);
}

function formatStudyMeaningSupplement(word: WordEntry, studyMode: StudyMode): string {
  const supplemental = formatMeaningSupplement(word);
  if (!supplemental) {
    return '';
  }

  const meanings = supplemental.split('；').map((meaning) => meaning.trim()).filter(Boolean);
  if (studyMode === 'chinese') {
    return meanings
      .map((meaning) => `${meaning} ${chineseMeaningPinyin(meaning)}`.trim())
      .join(' · ');
  }

  return meanings.join(' · ');
}

function formatExamplePrimary(word: WordEntry, studyMode: StudyMode): string {
  return studyMode === 'chinese' ? word.exampleZh : word.example;
}

function formatExampleSecondary(word: WordEntry, studyMode: StudyMode): string {
  return studyMode === 'chinese' ? word.example : word.exampleZh;
}

function formatQuizAnswer(word: WordEntry, studyMode: StudyMode): string {
  return studyMode === 'chinese' ? word.word : primaryChineseMeaning(word);
}

export function tabLabelForMode(tab: Tab, studyMode: StudyMode): string {
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
  return Platform.OS === 'web' ? authRedirectTo(getBrowserLocation()) : buildHostedAppUrl('/auth-native.html');
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

function browserUserAgent(): string {
  return (globalThis as { navigator?: { userAgent?: string } }).navigator?.userAgent ?? '';
}

function browserMaxTouchPoints(): number {
  return (globalThis as { navigator?: { maxTouchPoints?: number } }).navigator?.maxTouchPoints ?? 0;
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
    isAnonymous: configured,
    password: '',
    userId: null,
    userEmail: null,
    userName: null,
    busy: false,
    status: configured ? 'loading' : 'local',
    message: configured ? '正在準備訪客進度' : '本機記憶中',
  };
}

type AnimatedPressableProps = Omit<PressableProps, 'children' | 'style'> & {
  children: ReactNode;
  glassTone?: NativeGlassTone;
  hapticEnabled?: boolean;
  pressTone?: InteractionTone;
  pressedStyle?: StyleProp<ViewStyle>;
  style?: StyleProp<ViewStyle>;
};
type NativeGlassTone = 'primary' | 'secondary' | 'icon';
type WebTransitionStyle = ViewStyle & {
  WebkitTouchCallout?: string;
  WebkitUserSelect?: string;
  touchAction?: string;
  transitionDuration?: string;
  transitionProperty?: string;
  transitionTimingFunction?: string;
  transformOrigin?: string;
  userSelect?: string;
  willChange?: string;
};

function nativeGlassToneForPressTone(tone: InteractionTone): NativeGlassTone | null {
  return tone === 'icon' ? 'icon' : null;
}

function NativeButtonGlass({ tone }: { tone: NativeGlassTone }) {
  const themeMode = useContext(ThemeContext);
  const darkMode = themeMode === 'dark';
  const tintColor = tone === 'primary'
    ? (darkMode ? iosVisual.dark.accent : iosVisual.light.accent)
    : tone === 'icon'
      ? darkMode
        ? 'rgba(18, 29, 43, 0.58)'
        : 'rgba(235, 245, 255, 0.62)'
    : darkMode
      ? 'rgba(44, 44, 46, 0.72)'
      : 'rgba(255, 255, 255, 0.68)';

  return (
    <GlassView
      colorScheme={darkMode ? 'dark' : 'light'}
      glassEffectStyle={{
        animate: true,
        animationDuration: interactionMotion.glassMorphMs / 1000,
        style: 'regular',
      }}
      isInteractive
      style={StyleSheet.absoluteFill}
      tintColor={tintColor}
    />
  );
}

function AnimatedPressable({
  children,
  disabled,
  glassTone,
  hapticEnabled = true,
  onPressIn,
  onPressOut,
  pressTone = 'secondary',
  pressedStyle,
  style,
  ...props
}: AnimatedPressableProps) {
  const [pressed, setPressed] = useState(false);
  const themeMode = useContext(ThemeContext);
  const runtimePerformance = useRuntimePerformance();
  const pressProgress = useSharedValue(0);
  const pressMotion = pressMotionFor(pressTone);
  const nativeGlassTone = !disabled && NATIVE_GLASS_AVAILABLE && runtimePerformance.supportsLiquidGlass
    ? glassTone ?? nativeGlassToneForPressTone(pressTone)
    : null;
  const pressStyle = useAnimatedStyle(() => ({
    opacity: nativeGlassTone
      ? 1
      : interpolate(
          pressProgress.value,
          [0, 1],
          [1, pressMotion.pressedOpacity],
          Extrapolation.CLAMP,
        ),
    transform: [
      {
        scale: interpolate(
          pressProgress.value,
          [0, 1],
          [1, pressMotion.pressedScale],
          Extrapolation.CLAMP,
        ),
      },
      {
        translateY: interpolate(
          pressProgress.value,
          [0, 1],
          [0, pressMotion.pressedTranslateY],
          Extrapolation.CLAMP,
        ),
      },
    ],
  }));
  const glassFeedbackStyle = useAnimatedStyle(() => ({
    opacity: interpolate(
      pressProgress.value,
      [0, 1],
      [0, interactionMotion.glassFeedbackMaxOpacity],
      Extrapolation.CLAMP,
    ),
    transform: [
      {
        scale: interpolate(pressProgress.value, [0, 1], [1.08, 1], Extrapolation.CLAMP),
      },
    ],
  }));

  useEffect(() => {
    if (disabled) {
      cancelAnimation(pressProgress);
      pressProgress.value = 0;
      setPressed(false);
    }
  }, [disabled, pressProgress]);

  function handlePressIn(event: Parameters<NonNullable<PressableProps['onPressIn']>>[0]) {
    if (!disabled) {
      cancelAnimation(pressProgress);
      pressProgress.value = withTiming(1, {
        duration: interactionMotion.pressInMs,
        easing: ReanimatedEasing.out(ReanimatedEasing.cubic),
        reduceMotion: ReduceMotion.System,
      });
      if (hapticEnabled && !runtimePerformance.lowPowerMode) {
        triggerPressHaptic(pressTone);
      }
      if (pressedStyle) {
        setPressed(true);
      }
    }
    onPressIn?.(event);
  }

  function handlePressOut(event: Parameters<NonNullable<PressableProps['onPressOut']>>[0]) {
    if (!disabled) {
      cancelAnimation(pressProgress);
      pressProgress.value = withSpring(0, {
        dampingRatio: interactionMotion.pressReleaseDampingRatio,
        duration: interactionMotion.releaseMs,
        reduceMotion: ReduceMotion.System,
      });
      if (pressedStyle) {
        setPressed(false);
      }
    }
    onPressOut?.(event);
  }

  return (
    <MotionPressable
      {...props}
      disabled={disabled}
      onPressIn={handlePressIn}
      onPressOut={handlePressOut}
      style={[
        style,
        nativeGlassTone && styles.nativeGlassButton,
        pressed && !disabled && pressedStyle,
        !disabled && pressStyle,
      ]}
    >
      {nativeGlassTone ? <NativeButtonGlass tone={nativeGlassTone} /> : null}
      {nativeGlassTone ? (
        <>
          <Reanimated.View
            pointerEvents="none"
            style={[
              styles.nativeGlassFeedback,
              themeMode === 'dark' ? styles.nativeGlassFeedbackDark : styles.nativeGlassFeedbackLight,
              glassFeedbackStyle,
            ]}
          />
        </>
      ) : null}
      {children}
    </MotionPressable>
  );
}

function AnimatedFilterPanel({ children, open, testID }: { children: ReactNode; open: boolean; testID: string }) {
  const themeStyles = useThemeStyles();
  const runtimePerformance = useRuntimePerformance();
  const [filterPanelMeasuredHeight, setFilterPanelMeasuredHeight] = useState(0);
  const panelProgress = useSharedValue(open ? 1 : 0);

  useEffect(() => {
    if (Platform.OS === 'web') {
      return;
    }

    cancelAnimation(panelProgress);
    panelProgress.value = withTiming(open ? 1 : 0, {
      duration: runtimePerformance.conserveResources
        ? 120
        : open ? interactionMotion.panelMs : interactionMotion.panelCloseMs,
      easing: open
        ? ReanimatedEasing.out(ReanimatedEasing.cubic)
        : ReanimatedEasing.inOut(ReanimatedEasing.cubic),
      reduceMotion: ReduceMotion.System,
    });
  }, [open, panelProgress, runtimePerformance.conserveResources]);

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
  const nativePanelMotionStyle = useAnimatedStyle(() => ({
    borderTopWidth: interpolate(panelProgress.value, [0, 1], [0, 1], Extrapolation.CLAMP),
    height: interpolate(
      panelProgress.value,
      [0, 1],
      [interactionMotion.panelCollapsedHeight, measuredHeight],
      Extrapolation.CLAMP,
    ),
    opacity: interpolate(panelProgress.value, [0, 0.24, 1], [0, 0.72, 1], Extrapolation.CLAMP),
  }), [measuredHeight]);
  const nativeContentMotionStyle = useAnimatedStyle(() => ({
    opacity: interpolate(panelProgress.value, [0, 0.18, 1], [0, 0.65, 1], Extrapolation.CLAMP),
    transform: [
      {
        translateY: interpolate(panelProgress.value, [0, 1], [-6, 0], Extrapolation.CLAMP),
      },
      {
        scale: interpolate(panelProgress.value, [0, 1], [0.985, 1], Extrapolation.CLAMP),
      },
    ],
  }));
  const panelMotionStyle = Platform.OS === 'web'
    ? {
        borderTopWidth: open && measuredHeight > 0 ? 1 : 0,
        height: open ? measuredHeight : interactionMotion.panelCollapsedHeight,
        opacity: open ? 1 : 0,
      }
    : nativePanelMotionStyle;
  const contentMotionStyle = Platform.OS === 'web'
    ? {
        opacity: open ? 1 : 0,
        transform: [{ translateY: open ? 0 : -6 }, { scale: open ? 1 : 0.985 }],
      }
    : nativeContentMotionStyle;

  return (
    <Reanimated.View
      pointerEvents={open ? 'auto' : 'none'}
      style={[styles.filterPanel, themeStyles?.filterPanel, filterPanelWebTransition, panelMotionStyle]}
      testID={testID}
    >
      <Reanimated.View onLayout={handlePanelContentLayout} style={[styles.filterPanelContent, filterPanelWebTransition, contentMotionStyle]}>
        {children}
      </Reanimated.View>
    </Reanimated.View>
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
  const iconColor = darkMode ? '#0A84FF' : '#007AFF';

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
          <RotateCcw size={17} color="#FFFFFF" strokeWidth={2.4} />
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
          <Languages size={34} color={chineseMode ? '#5856D6' : '#007AFF'} strokeWidth={2.5} />
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
  const installGuideIconColor = darkMode ? '#0A84FF' : '#007AFF';
  const installGuideCloseIconColor = darkMode ? '#F2F2F7' : '#1C1C1E';
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
        <BrandMark size={48} style={[styles.installGuideLogo, themeStyles?.installGuideLogo]} />
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
          <ChevronRight size={18} color="#FFFFFF" strokeWidth={2.5} />
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

const HomeView = memo(function HomeView({
  dailyPercent,
  progress,
  stats,
  studyMode,
  updateStatus,
  vocabularyWords,
  onCheckForUpdate,
  bankCount,
  bankIsScan,
  bankName,
  onOpenBankPicker,
  onOpenDictionaryWord,
  onOpenQuiz,
  onOpenStats,
  onOpenReview,
  onStartStudy,
  onToggleStudyMode,
}: {
  bankCount: number;
  bankIsScan: boolean;
  bankName: string;
  onOpenBankPicker: () => void;
  dailyPercent: number;
  progress: ProgressState;
  stats: ReturnType<typeof computeStats>;
  studyMode: StudyMode;
  updateStatus: ManualUpdateStatus;
  vocabularyWords: WordEntry[];
  onCheckForUpdate: () => void;
  onOpenDictionaryWord: (word: WordEntry) => void;
  onOpenQuiz: () => void;
  onOpenStats: () => void;
  onOpenReview: () => void;
  onStartStudy: () => void;
  onToggleStudyMode: () => void;
}) {
  const themeStyles = useThemeStyles();
  const safeAreaInsets = useSafeAreaInsets();
  const themeMode = useContext(ThemeContext);
  const runtimePerformance = useRuntimePerformance();
  const darkMode = themeMode === 'dark';
  const bodyIconColor = darkMode ? '#F2F2F7' : '#1C1C1E';
  const copy = modeCopy[studyMode];
  const updateCopy = systemCopy[studyMode];
  const ui = modeInterfaceCopy[studyMode];
  const updateChecking = updateStatus === 'checking';
  const updateActionText = updateStatus === 'available'
    ? updateCopy.updateAvailable
    : updateStatus === 'current'
    ? updateCopy.updateCurrent
    : updateStatus === 'error'
      ? updateCopy.updateRetry
      : updateStatus === 'checking'
        ? updateCopy.updateChecking
        : updateCopy.updateNow;
  const updateDetail = updateStatus === 'available'
    ? updateCopy.updateAvailableDetail
    : updateStatus === 'current'
    ? updateCopy.updateCurrentDetail
    : updateStatus === 'error'
      ? updateCopy.updateCheckFailed
      : updateCopy.updateCheckDetail;
  const palette = darkMode ? iosVisual.dark : iosVisual.light;
  const goalDone = stats.studiedToday >= progress.dailyTarget;
  const newLeft = Math.max(0, progress.dailyTarget - stats.studiedToday);
  const primaryActionText = goalDone
    ? copy.extraAction
    : stats.studiedToday > 0
      ? copy.continueAction
      : copy.primaryAction;
  const [dictionaryQuery, setDictionaryQuery] = useState('');
  const [dictionaryOpen, setDictionaryOpen] = useState(false);
  const debouncedDictionaryQuery = useDebouncedValue(
    dictionaryQuery,
    runtimePerformance.conserveResources || runtimePerformance.isLegacyIos ? 160 : 80,
  );
  const deferredDictionaryQuery = useDeferredValue(debouncedDictionaryQuery);
  const dictionaryModalProgress = useRef(new Animated.Value(0)).current;
  const dictionaryInputRef = useRef<TextInput | null>(null);
  const dictionaryClosingRef = useRef(false);
  const dictionaryPendingActionRef = useRef<(() => void) | null>(null);
  const dictionaryFocusTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const normalizedDictionaryQuery = deferredDictionaryQuery.trim();
  const dictionaryResults = useMemo(
    () =>
      normalizedDictionaryQuery
        ? filterWords(vocabularyWords, progress, normalizedDictionaryQuery, 'all').slice(0, 36)
        : [],
    [normalizedDictionaryQuery, vocabularyWords],
  );

  useEffect(() => {
    if (!dictionaryOpen || IS_NATIVE_IOS) {
      return;
    }

    dictionaryClosingRef.current = false;
    dictionaryModalProgress.setValue(0);
    const frame = requestAnimationFrame(() => {
      Animated.spring(dictionaryModalProgress, {
        damping: 22,
        mass: 0.82,
        stiffness: 210,
        toValue: 1,
        useNativeDriver: Platform.OS !== 'web',
      }).start();
    });
    return () => {
      cancelAnimationFrame(frame);
    };
  }, [dictionaryModalProgress, dictionaryOpen]);

  const focusDictionaryInput = useCallback(() => {
    if (dictionaryFocusTimerRef.current) {
      clearTimeout(dictionaryFocusTimerRef.current);
    }
    dictionaryFocusTimerRef.current = setTimeout(
      () => dictionaryInputRef.current?.focus(),
      IS_NATIVE_IOS ? 110 : 60,
    );
  }, []);

  useEffect(
    () => () => {
      if (dictionaryFocusTimerRef.current) {
        clearTimeout(dictionaryFocusTimerRef.current);
      }
    },
    [],
  );

  const openDictionary = useCallback(() => {
    if (!dictionaryOpen) {
      setDictionaryOpen(true);
    }
  }, [dictionaryOpen]);

  const closeDictionary = useCallback(
    (afterClose?: () => void) => {
      if (dictionaryClosingRef.current) {
        return;
      }

      dictionaryClosingRef.current = true;
      if (dictionaryFocusTimerRef.current) {
        clearTimeout(dictionaryFocusTimerRef.current);
        dictionaryFocusTimerRef.current = null;
      }
      Keyboard.dismiss();
      if (IS_NATIVE_IOS) {
        dictionaryPendingActionRef.current = afterClose ?? null;
        setDictionaryOpen(false);
        return;
      }

      dictionaryModalProgress.stopAnimation();
      Animated.timing(dictionaryModalProgress, {
        duration: 210,
        easing: Easing.in(Easing.cubic),
        toValue: 0,
        useNativeDriver: Platform.OS !== 'web',
      }).start(() => {
        setDictionaryOpen(false);
        dictionaryClosingRef.current = false;
        afterClose?.();
      });
    },
    [dictionaryModalProgress],
  );

  const finishDictionaryDismiss = useCallback(() => {
    dictionaryClosingRef.current = false;
    const pendingAction = dictionaryPendingActionRef.current;
    dictionaryPendingActionRef.current = null;
    pendingAction?.();
  }, []);

  const openDictionaryWord = useCallback(
    (word: WordEntry) => {
      closeDictionary(() => onOpenDictionaryWord(word));
    },
    [closeDictionary, onOpenDictionaryWord],
  );

  const dictionaryBackdropStyle = {
    opacity: dictionaryModalProgress.interpolate({
      inputRange: [0, 1],
      outputRange: [0, 1],
    }),
  };
  const dictionarySheetStyle = {
    opacity: dictionaryModalProgress.interpolate({
      inputRange: [0, 0.28, 1],
      outputRange: [0, 1, 1],
    }),
    transform: [
      {
        translateY: dictionaryModalProgress.interpolate({
          inputRange: [0, 1],
          outputRange: [54, 0],
        }),
      },
      {
        scale: dictionaryModalProgress.interpolate({
          inputRange: [0, 1],
          outputRange: [0.985, 1],
        }),
      },
    ],
  };

  return (
    <>
      <View style={styles.homeStack}>
        <WordBankBar count={bankCount} isScan={bankIsScan} name={bankName} studyMode={studyMode} testID="home-bank-bar" onPress={onOpenBankPicker} />
        <View style={[styles.hero, themeStyles?.hero]} testID="home-today-plan">
          <View style={styles.homeHeroRow}>
            <ProgressRing
              color={goalDone ? palette.green : palette.accent}
              percent={dailyPercent}
              size={112}
              strokeWidth={11}
              trackColor={darkMode ? 'rgba(120, 120, 128, 0.32)' : 'rgba(120, 120, 128, 0.16)'}
            >
              <Text style={[styles.homeRingValue, themeStyles?.heroTitle]}>{stats.studiedToday}</Text>
              <Text style={[styles.homeRingTarget, themeStyles?.cardMeta]}>/ {progress.dailyTarget}</Text>
            </ProgressRing>
            <View style={styles.homeHeroCopy}>
              <Text style={[styles.heroTitle, styles.homeHeroTitle, themeStyles?.heroTitle]}>
                {goalDone ? copy.heroDoneTitle : copy.heroTitle(progress.dailyTarget)}
              </Text>
              <Text style={[styles.homePlanText, themeStyles?.cardMeta]}>{ui.todayPlan(stats.due, newLeft)}</Text>
              {progress.streak > 0 && (
                <View style={[styles.homeStreakPill, themeStyles?.homeStreakPill]}>
                  <AppIcon color={palette.orange} name="flame" size={13} />
                  <Text style={styles.homeStreakText}>{ui.streakDays(progress.streak)}</Text>
                </View>
              )}
            </View>
          </View>
          <AnimatedPressable accessibilityRole="button" onPress={onStartStudy} pressTone="primary" style={[styles.primaryButton, styles.homePrimaryButton]} testID="home-start-study">
            <AppIcon color="#FFFFFF" name="book" size={18} />
            <Text style={[styles.primaryButtonText, styles.homePrimaryButtonText]}>{primaryActionText}</Text>
          </AnimatedPressable>
        </View>

        <AnimatedPressable
          accessibilityLabel={ui.learningAnalytics}
          accessibilityRole="button"
          onPress={onOpenStats}
          pressTone="list"
          style={[styles.statsGrid, themeStyles?.homeGroupedSurface]}
          testID="home-learning-analytics"
        >
          <StatCard color={palette.orange} label={ui.streak} value={progress.streak.toString()} />
          <StatCard color={palette.green} divider label={ui.mastered} value={stats.mastered.toString()} />
          <StatCard color={stats.due > 0 ? palette.accent : undefined} divider label={ui.reviewDueToday} value={stats.due.toString()} />
        </AnimatedPressable>

        <AnimatedPressable
          accessibilityLabel={ui.dictionaryLookup}
          accessibilityRole="button"
          onPress={openDictionary}
          pressTone="list"
          style={[styles.homeDictionaryStandalone, themeStyles?.homeDictionarySearch]}
          testID="home-dictionary-search"
        >
          <View style={[styles.homeDictionaryLauncherIcon, themeStyles?.homeDictionaryLauncherIcon]}>
            <AppIcon color={palette.accent} name="search" size={18} />
          </View>
          <Text numberOfLines={1} style={[styles.homeDictionaryLauncherText, themeStyles?.homeDictionaryInput]}>
            {copy.searchPlaceholder}
          </Text>
        </AnimatedPressable>

        <View style={[styles.homeActionGroup, themeStyles?.homeGroupedSurface]} testID="home-action-group">
          <AnimatedPressable accessibilityRole="button" onPress={onOpenReview} pressTone="list" style={styles.reviewStrip}>
            <View style={[styles.reviewIcon, themeStyles?.reviewIcon]}>
              <AppIcon color={palette.orange} name="review" size={18} />
            </View>
            <Text style={[styles.reviewTitle, styles.flexOne, themeStyles?.reviewTitle]}>{ui.reviewList}</Text>
            {stats.review > 0 && <Text style={[styles.homeRowValue, themeStyles?.cardMeta]}>{stats.review}</Text>}
            <AppIcon color="#C7C7CC" name="chevronRight" size={14} />
          </AnimatedPressable>

          <View style={[styles.homeActionDivider, themeStyles?.homeDivider]} />

          <AnimatedPressable accessibilityRole="button" onPress={onOpenQuiz} pressTone="list" style={styles.reviewStrip} testID="home-quick-quiz">
            <View style={[styles.reviewIcon, styles.homeQuizIcon, themeStyles?.homeQuizIcon]}>
              <AppIcon color={palette.accent} name="target" size={18} />
            </View>
            <Text style={[styles.reviewTitle, styles.flexOne, themeStyles?.reviewTitle]}>{ui.quickQuiz}</Text>
            <AppIcon color="#C7C7CC" name="chevronRight" size={14} />
          </AnimatedPressable>

          <View style={[styles.homeActionDivider, themeStyles?.homeDivider]} />

          <AnimatedPressable
            accessibilityLabel={copy.toggleTitle}
            accessibilityRole="button"
            onPress={onToggleStudyMode}
            pressTone="list"
            style={styles.modeSwitchButton}
            testID="study-mode-toggle"
          >
            <View style={[styles.modeSwitchIcon, studyMode === 'chinese' && styles.modeSwitchIconChinese, themeStyles?.modeSwitchIcon]}>
              <AppIcon color={studyMode === 'chinese' ? palette.indigo : palette.accent} name="language" size={18} />
            </View>
            <Text accessibilityHint={copy.toggleText} style={[styles.modeSwitchTitle, styles.flexOne, themeStyles?.modeSwitchTitle]}>{copy.toggleTitle}</Text>
            <AppIcon color="#C7C7CC" name="chevronRight" size={14} />
          </AnimatedPressable>
        </View>

        <AnimatedPressable
          accessibilityLabel={updateCopy.updateCheckTitle}
          accessibilityRole="button"
          disabled={updateChecking}
          glassTone="secondary"
          onPress={onCheckForUpdate}
          pressTone="secondary"
          style={[styles.homeUpdateButton, themeStyles?.homeUpdateButton]}
          testID="home-manual-update"
        >
          <View style={[styles.homeUpdateIcon, themeStyles?.homeUpdateIcon]}>
            <Cloud size={20} color={darkMode ? '#0A84FF' : '#007AFF'} strokeWidth={2.4} />
          </View>
          <View style={styles.flexOne}>
            <Text style={[styles.homeUpdateTitle, themeStyles?.homeUpdateTitle]}>{updateCopy.updateCheckTitle}</Text>
            <Text numberOfLines={2} style={[styles.homeUpdateText, themeStyles?.homeUpdateText]}>{updateDetail}</Text>
          </View>
          <View
            style={[
              styles.homeUpdateAction,
              updateStatus === 'available' && styles.homeUpdateActionAvailable,
              updateStatus === 'current' && styles.homeUpdateActionCurrent,
              updateStatus === 'error' && styles.homeUpdateActionError,
            ]}
          >
            {updateChecking ? (
              <ActivityIndicator color="#FFFFFF" size="small" />
            ) : updateStatus === 'current' ? (
              <Check size={14} color="#FFFFFF" strokeWidth={2.7} />
            ) : updateStatus === 'available' ? (
              <Download size={14} color="#FFFFFF" strokeWidth={2.5} />
            ) : (
              <RotateCcw size={14} color="#FFFFFF" strokeWidth={2.5} />
            )}
            <Text adjustsFontSizeToFit minimumFontScale={0.78} numberOfLines={1} style={styles.homeUpdateActionText}>
              {updateActionText}
            </Text>
          </View>
        </AnimatedPressable>
      </View>

      <Modal
        allowSwipeDismissal={IS_NATIVE_IOS}
        animationType={IS_NATIVE_IOS ? 'slide' : 'none'}
        onDismiss={finishDictionaryDismiss}
        onRequestClose={() => closeDictionary()}
        onShow={focusDictionaryInput}
        presentationStyle={IS_NATIVE_IOS ? 'pageSheet' : 'overFullScreen'}
        statusBarTranslucent={!IS_NATIVE_IOS}
        transparent={!IS_NATIVE_IOS}
        visible={dictionaryOpen}
      >
        <View
          accessibilityViewIsModal
          style={[
            styles.homeDictionaryModalRoot,
            IS_NATIVE_IOS && styles.homeDictionaryModalRootNative,
            IS_NATIVE_IOS && themeStyles?.homeDictionaryModalRootNative,
          ]}
          testID="home-dictionary-modal"
        >
          {!IS_NATIVE_IOS ? (
            <Pressable accessible={false} onPress={() => closeDictionary()} style={StyleSheet.absoluteFill}>
              <Animated.View pointerEvents="none" style={[styles.homeDictionaryBackdrop, dictionaryBackdropStyle]} />
            </Pressable>
          ) : null}
          <KeyboardAvoidingView
            behavior={IS_NATIVE_IOS ? 'padding' : undefined}
            pointerEvents="box-none"
            style={styles.homeDictionaryKeyboardLayer}
          >
            <Animated.View
              style={[
                styles.homeDictionaryModalSheet,
                IS_NATIVE_IOS && styles.homeDictionaryModalSheetNative,
                themeStyles?.homeDictionaryModalSheet,
                { paddingBottom: Math.max(14, safeAreaInsets.bottom + 8) },
                !IS_NATIVE_IOS && dictionarySheetStyle,
              ]}
            >
              {!IS_NATIVE_IOS ? <View style={styles.homeDictionaryModalHandle} /> : null}
              <View
                style={[
                  styles.homeDictionaryModalHeader,
                  IS_NATIVE_IOS && styles.homeDictionaryModalHeaderNative,
                ]}
              >
                <View style={styles.flexOne}>
                  <Text style={[styles.homeDictionaryModalTitle, themeStyles?.sectionTitle]}>{ui.dictionaryLookup}</Text>
                  {normalizedDictionaryQuery ? (
                    <Text style={[styles.homeDictionaryModalMeta, themeStyles?.cardMeta]}>
                      {ui.searchMeta(normalizedDictionaryQuery, dictionaryResults.length)}
                    </Text>
                  ) : null}
                </View>
                <AnimatedPressable
                  accessibilityLabel={studyMode === 'chinese' ? 'Close dictionary' : '關閉查字'}
                  accessibilityRole="button"
                  glassTone="icon"
                  onPress={() => closeDictionary()}
                  pressTone="icon"
                  style={[styles.iconButton, themeStyles?.iconButton]}
                >
                  <X size={20} color={bodyIconColor} strokeWidth={2.4} />
                </AnimatedPressable>
              </View>

              <View
                style={[
                  styles.homeDictionaryModalSearch,
                  IS_NATIVE_IOS && styles.homeDictionaryModalSearchNative,
                  themeStyles?.homeDictionarySearch,
                ]}
              >
                <Search size={20} color="#6C6C70" strokeWidth={2.2} />
                <TextInput
                  accessibilityLabel={ui.dictionaryLookup}
                  autoCapitalize="none"
                  autoCorrect={false}
                  clearButtonMode={IS_NATIVE_IOS ? 'while-editing' : 'never'}
                  keyboardAppearance={darkMode ? 'dark' : 'light'}
                  onChangeText={setDictionaryQuery}
                  placeholder={copy.searchPlaceholder}
                  placeholderTextColor="#8E8E93"
                  ref={dictionaryInputRef}
                  returnKeyType="search"
                  selectionColor="#007AFF"
                  style={[styles.homeDictionaryModalInput, themeStyles?.homeDictionaryInput]}
                  value={dictionaryQuery}
                />
                {dictionaryQuery && !IS_NATIVE_IOS ? (
                  <AnimatedPressable
                    accessibilityLabel={ui.clearSearch}
                    accessibilityRole="button"
                    onPress={() => {
                      setDictionaryQuery('');
                      dictionaryInputRef.current?.focus();
                    }}
                    pressTone="icon"
                    style={styles.homeDictionaryClearButton}
                  >
                    <X size={17} color="#6C6C70" strokeWidth={2.5} />
                  </AnimatedPressable>
                ) : null}
              </View>

              <ScrollView
                contentContainerStyle={styles.homeDictionaryResultsContent}
                keyboardDismissMode={Platform.OS === 'ios' ? 'interactive' : 'on-drag'}
                keyboardShouldPersistTaps="handled"
                showsVerticalScrollIndicator={false}
                style={styles.homeDictionaryResults}
              >
                {!normalizedDictionaryQuery ? (
                  <View style={styles.homeDictionaryEmptyState}>
                    <Search size={28} color="#8E8E93" strokeWidth={2} />
                    <Text style={[styles.homeDictionaryEmptyText, themeStyles?.cardMeta]}>{copy.searchPlaceholder}</Text>
                  </View>
                ) : dictionaryResults.length === 0 ? (
                  <View style={styles.homeDictionaryEmptyState}>
                    <Search size={28} color="#8E8E93" strokeWidth={2} />
                    <Text style={[styles.homeDictionaryEmptyText, themeStyles?.cardMeta]}>{ui.noLibraryWords}</Text>
                  </View>
                ) : (
                  dictionaryResults.map((word) => (
                    <HomeDictionaryResultRow
                      key={word.id}
                      studyMode={studyMode}
                      word={word}
                      onPress={openDictionaryWord}
                    />
                  ))
                )}
              </ScrollView>
            </Animated.View>
          </KeyboardAvoidingView>
        </View>
      </Modal>
    </>
  );
});

const HomeDictionaryResultRow = memo(function HomeDictionaryResultRow({
  studyMode,
  word,
  onPress,
}: {
  studyMode: StudyMode;
  word: WordEntry;
  onPress: (word: WordEntry) => void;
}) {
  const themeStyles = useThemeStyles();
  const ui = modeInterfaceCopy[studyMode];
  const primaryWord = formatWordPrimary(word, studyMode);

  return (
    <AnimatedPressable
      accessibilityLabel={ui.viewWordDetails(primaryWord)}
      accessibilityRole="button"
      onPress={() => onPress(word)}
      pressTone="list"
      style={[styles.homeDictionaryResultRow, themeStyles?.homeDictionaryResultRow]}
      testID={`home-dictionary-result-${word.id}`}
    >
      <View style={styles.flexOne}>
        <View style={styles.homeDictionaryResultTitleRow}>
          <Text numberOfLines={1} style={[styles.homeDictionaryResultTitle, themeStyles?.libraryWord]}>
            {primaryWord}
          </Text>
          <Text style={styles.libraryGroup}>{word.group}</Text>
        </View>
        {studyMode === 'chinese' ? (
          <Text numberOfLines={1} style={[styles.homeDictionaryResultPinyin, themeStyles?.libraryPinyin]}>
            {formatWordPinyin(word, studyMode)}
          </Text>
        ) : null}
        <Text numberOfLines={2} style={[styles.homeDictionaryResultMeaning, themeStyles?.libraryMeaning]}>
          {formatMeaningDetail(word, studyMode)}
        </Text>
        {Boolean(formatExamplePrimary(word, studyMode)) && (
          <Text numberOfLines={1} style={[styles.homeDictionaryResultExample, themeStyles?.libraryExample]}>
            {formatExamplePrimary(word, studyMode)}
          </Text>
        )}
      </View>
      <ChevronRight size={18} color="#6C6C70" strokeWidth={2.3} />
    </AnimatedPressable>
  );
});

function StudySwipeRevealGradient({ tone }: { tone: StudySwipeDirection }) {
  const review = tone === 'review';
  const featherId = `study-swipe-${tone}-feather`;
  const maskId = `study-swipe-${tone}-mask`;
  const radialId = `study-swipe-${tone}-radial`;
  const washId = `study-swipe-${tone}-wash`;
  const mainColor = review ? '#FF3B30' : '#34C759';
  const softColor = review ? '#FF6961' : '#6CD97E';
  const deepColor = review ? '#D70015' : '#248A3D';
  const hotEdge = review ? '0%' : '100%';
  const fadeEdge = review ? '100%' : '0%';

  return (
    <Svg height="100%" preserveAspectRatio="none" style={styles.studySwipeRevealGradient} width="100%">
      <SvgDefs>
        <SvgLinearGradient id={featherId} x1="0%" x2="0%" y1="0%" y2="100%">
          <SvgStop offset="0%" stopColor="#FFFFFF" stopOpacity="0" />
          <SvgStop offset="11%" stopColor="#FFFFFF" stopOpacity="0.82" />
          <SvgStop offset="22%" stopColor="#FFFFFF" stopOpacity="1" />
          <SvgStop offset="78%" stopColor="#FFFFFF" stopOpacity="1" />
          <SvgStop offset="89%" stopColor="#FFFFFF" stopOpacity="0.82" />
          <SvgStop offset="100%" stopColor="#FFFFFF" stopOpacity="0" />
        </SvgLinearGradient>
        <SvgMask height="100%" id={maskId} width="100%" x="0" y="0">
          <SvgRect fill={`url(#${featherId})`} height="100%" width="100%" x="0" y="0" />
        </SvgMask>
        <SvgLinearGradient id={washId} x1={hotEdge} x2={fadeEdge} y1="0%" y2="0%">
          <SvgStop offset="0%" stopColor={deepColor} stopOpacity="0.24" />
          <SvgStop offset="18%" stopColor={mainColor} stopOpacity="0.18" />
          <SvgStop offset="46%" stopColor={mainColor} stopOpacity="0.11" />
          <SvgStop offset="72%" stopColor={softColor} stopOpacity="0.06" />
          <SvgStop offset="100%" stopColor={softColor} stopOpacity="0.03" />
        </SvgLinearGradient>
        <SvgRadialGradient cx={hotEdge} cy="50%" fx={hotEdge} fy="50%" id={radialId} r="128%">
          <SvgStop offset="0%" stopColor={deepColor} stopOpacity="0.32" />
          <SvgStop offset="26%" stopColor={mainColor} stopOpacity="0.21" />
          <SvgStop offset="54%" stopColor={mainColor} stopOpacity="0.11" />
          <SvgStop offset="78%" stopColor={softColor} stopOpacity="0.05" />
          <SvgStop offset="100%" stopColor={softColor} stopOpacity="0.015" />
        </SvgRadialGradient>
      </SvgDefs>
      <SvgG mask={`url(#${maskId})`}>
        <SvgRect fill={`url(#${washId})`} height="100%" width="100%" x="0" y="0" />
        <SvgRect fill={`url(#${radialId})`} height="100%" width="100%" x="0" y="0" />
      </SvgG>
    </Svg>
  );
}

// Shared by the live card and the deck underlay. They have to render the exact
// same body, otherwise the underlay grows extra content the instant it becomes
// the live card and the swap reads as a flash. The underlay always shows the
// unrevealed face, because that is what the incoming card looks like.
function StudyCardBody({
  onReveal,
  revealed,
  studyMode,
  word,
}: {
  onReveal?: () => void;
  revealed: boolean;
  studyMode: StudyMode;
  word: WordEntry;
}) {
  const themeStyles = useThemeStyles();
  const darkMode = useContext(ThemeContext) === 'dark';
  const ui = modeInterfaceCopy[studyMode];
  const supplementalMeaning = formatStudyMeaningSupplement(word, studyMode);
  // In Chinese mode the secondary line is the English word itself, which is
  // the answer; it only belongs on the revealed face.
  const showSecondary = studyMode !== 'chinese' || revealed;

  return (
    <Pressable
      accessibilityHint={revealed ? undefined : ui.tapToReveal}
      accessibilityRole={revealed ? undefined : 'button'}
      disabled={revealed || !onReveal}
      onPress={onReveal}
      style={styles.studyCardFace}
      testID={revealed ? 'study-card-answer' : 'study-card-front'}
    >
      <View style={styles.studyWordIdentity}>
        <Text
          adjustsFontSizeToFit={Platform.OS === 'ios'}
          minimumFontScale={0.72}
          numberOfLines={2}
          style={[styles.bigWord, studyMode === 'chinese' && styles.bigChineseWord, themeStyles?.bigWord]}
        >
          {formatWordPrimary(word, studyMode)}
        </Text>
        {studyMode === 'chinese' && (
          <Text numberOfLines={2} style={[styles.pinyinText, themeStyles?.pinyinText]}>
            {formatWordPinyin(word, studyMode)}
          </Text>
        )}
        {showSecondary && Boolean(formatWordSecondary(word, studyMode).trim()) && (
          <Text numberOfLines={2} style={[styles.pronunciation, themeStyles?.pronunciation]}>
            {formatWordSecondary(word, studyMode)}
          </Text>
        )}
      </View>
      {revealed ? (
        <>
          {/* Line limits exist to keep every entry inside the card's fixed
              height; without them a long definition would be clipped. */}
          <View style={[styles.meaningBlock, themeStyles?.meaningBlock]}>
            <Text style={styles.partOfSpeech}>{studyMode === 'chinese' ? ui.englishCounterpart : word.partOfSpeech}</Text>
            <Text numberOfLines={3} style={[styles.meaning, themeStyles?.meaning]}>
              {formatMeaningDetail(word, studyMode)}
            </Text>
            {Boolean(supplementalMeaning) && (
              <View style={[styles.studySupplement, themeStyles?.studySupplement]}>
                <Text style={[styles.studySupplementLabel, themeStyles?.studySupplementLabel]}>
                  {ui.supplementalMeanings}
                </Text>
                <Text numberOfLines={2} style={[styles.studySupplementText, themeStyles?.studySupplementText]}>
                  {supplementalMeaning}
                </Text>
              </View>
            )}
          </View>
          {/* Words saved from a scanned sheet may have no example sentence. */}
          {Boolean(formatExamplePrimary(word, studyMode)) && (
            <View style={[styles.exampleBox, styles.studyCardExampleBox, themeStyles?.exampleBox]}>
              <Text numberOfLines={2} style={[styles.example, themeStyles?.example]}>
                {formatExamplePrimary(word, studyMode)}
              </Text>
              <Text numberOfLines={2} style={[styles.exampleZh, themeStyles?.exampleZh]}>
                {formatExampleSecondary(word, studyMode)}
              </Text>
            </View>
          )}
        </>
      ) : (
        <View style={[styles.studyRevealPrompt, themeStyles?.studyRevealPrompt]}>
          <Eye size={24} color={darkMode ? '#0A84FF' : '#007AFF'} strokeWidth={2.2} />
          <Text style={[styles.studyRevealPromptText, themeStyles?.studyRevealPromptText]}>{ui.tapToReveal}</Text>
        </View>
      )}
    </Pressable>
  );
}

function splitSwipeHintLines(hint: string): string[] {
  const colonIndex = hint.indexOf(':');
  if (colonIndex > -1) {
    const lead = hint.slice(0, colonIndex).trim();
    const action = hint.slice(colonIndex + 1).trim();
    return action ? [lead, action] : [lead];
  }

  if (!hint.includes(' ') && hint.length >= 4) {
    return [hint.slice(0, 2), hint.slice(2)];
  }

  return [hint];
}

function clearStudySwipeTextSelection() {
  if (Platform.OS !== 'web') {
    return;
  }

  const selection = (globalThis as { getSelection?: () => { removeAllRanges: () => void } | null }).getSelection?.();
  selection?.removeAllRanges();
}

function FeatureLockBadge() {
  const darkMode = useContext(ThemeContext) === 'dark';

  return (
    <View style={[styles.featureLockBadge, darkMode && styles.featureLockBadgeDark]}>
      <Lock size={8} color={darkMode ? '#F2F2F7' : '#1C1C1E'} strokeWidth={2.6} />
    </View>
  );
}

function FavoriteGlyph({ favorited, locked, size = 20 }: { favorited: boolean; locked: boolean; size?: number }) {
  const darkMode = useContext(ThemeContext) === 'dark';
  const starColor = favorited ? '#FF9500' : darkMode ? '#AEAEB2' : '#6C6C70';

  return (
    <View pointerEvents="none" style={[styles.lockedFeatureGlyph, { height: size + 5, width: size + 5 }]}>
      <Star size={size} color={starColor} fill={favorited ? '#FF9500' : 'transparent'} />
      {locked && <FeatureLockBadge />}
    </View>
  );
}

function AddToSetGlyph({ locked, size = 20 }: { locked: boolean; size?: number }) {
  return (
    <View pointerEvents="none" style={[styles.lockedFeatureGlyph, { height: size + 5, width: size + 5 }]}>
      <SquarePlus size={size} color="#007AFF" strokeWidth={2.4} />
      {locked && <FeatureLockBadge />}
    </View>
  );
}

const StudyView = memo(function StudyView({
  bankCount,
  bankIsScan,
  bankName,
  activeFilter,
  activeInitial,
  activeLevel,
  canUndo,
  cardSequence,
  customSetsLocked,
  dailyTarget,
  filtersOpen,
  favoriteLocked,
  levelOptions,
  motionStyle,
  nextWord,
  sessionComplete,
  sessionKnownCount,
  sessionProgress,
  sessionReviewCount,
  streak,
  studiedToday,
  studyMode,
  wordCount,
  word,
  progress,
  onOpenBankPicker,
  onAddToSet,
  onFilterChange,
  onFiltersToggle,
  onFavorite,
  onInitialChange,
  onLevelChange,
  onNextSession,
  onOpenQuiz,
  onReviewMissed,
  onSwipeKnown,
  onSwipeReview,
  onUndo,
}: {
  bankCount: number;
  bankIsScan: boolean;
  bankName: string;
  activeFilter: LibraryFilter;
  activeInitial: string;
  activeLevel: string;
  canUndo: boolean;
  cardSequence: number;
  customSetsLocked: boolean;
  dailyTarget: number;
  filtersOpen: boolean;
  favoriteLocked: boolean;
  levelOptions: FilterOption[];
  motionStyle: StyleProp<ViewStyle>;
  nextWord: WordEntry | null;
  sessionComplete: boolean;
  sessionKnownCount: number;
  sessionProgress: { done: number; total: number };
  sessionReviewCount: number;
  streak: number;
  studiedToday: number;
  studyMode: StudyMode;
  word: WordEntry | null;
  wordCount: number;
  progress: ProgressState;
  onOpenBankPicker: () => void;
  onAddToSet: (word: WordEntry) => void;
  onFilterChange: (filter: LibraryFilter) => void;
  onFiltersToggle: () => void;
  onFavorite: () => void;
  onInitialChange: (initial: string) => void;
  onLevelChange: (level: string) => void;
  onNextSession: () => void;
  onOpenQuiz: () => void;
  onReviewMissed: () => void;
  onSwipeKnown: () => void;
  onSwipeReview: () => void;
  onUndo: () => void;
}) {
  const wordProgress = word ? progress.words[word.id] : undefined;
  const favorited = Boolean(wordProgress?.favorite);
  const themeStyles = useThemeStyles();
  const darkMode = useContext(ThemeContext) === 'dark';
  const runtimePerformance = useRuntimePerformance();
  const copy = modeCopy[studyMode];
  const ui = modeInterfaceCopy[studyMode];
  const { height: viewportHeight, width: viewportWidth } = useWindowDimensions();
  // One height for both cards, and it has to be fixed. What floats up can only
  // be "the same card that takes over" if the two are the same shape, and any
  // height driven by content breaks that the moment a longer word arrives. The
  // line limits below keep content under this height, so the leftover space at
  // the bottom stays small rather than the hollow gap a taller ceiling left.
  const compactPhone = viewportHeight < 740 || viewportWidth < 360;
  const studyCardHeight = compactPhone
    ? Math.round(Math.max(404, Math.min(432, viewportHeight * 0.6)))
    : Math.round(Math.max(430, Math.min(470, viewportHeight * 0.54)));
  const swipeExitX = Math.max(320, Math.min(440, viewportWidth - 16));
  const reviewHintLines = splitSwipeHintLines(ui.swipeReviewHint);
  const knownHintLines = splitSwipeHintLines(ui.swipeKnownHint);
  const swipeX = useSharedValue(0);
  const swipeHintX = useSharedValue(0);
  const swipeStartX = useSharedValue(0);
  const swipePhase = useSharedValue(0);
  const hapticDirectionCode = useSharedValue(0);
  const swipeCommitPulse = useSharedValue(0);
  const cardEntryProgress = useSharedValue(1);
  const cardVisibility = useSharedValue(1);
  // Marks a handoff that came from a throw. The card taking over has already
  // been floated into place by the underlay animation, so replaying the entry
  // would drop it 4px and scale it back up — a small jolt exactly at the swap.
  // A handoff from the next/prev buttons has no such lead-in and still wants it.
  const swipeHandoff = useSharedValue(0);
  // The underlay's content comes from React state while its brightness comes
  // from swipeX on the UI thread. On device those two land on different
  // frames: React swaps in the card *after* next while swipeX is still parked
  // at the exit position, so for a frame the underlay is fully lit, in the
  // live card's place, showing a word that is not the one taking over. That
  // wrong word appearing is the flash. Holding the content back until the
  // layout effect — the same moment swipeX is reset — keeps both in step.
  const [deckWord, setDeckWord] = useState(nextWord);
  // The underlay has to draw the same action row as the live card. Without it
  // the top row is a bare pill, which is shorter than a row containing icon
  // buttons — so the card grew by that difference at the moment it took over.
  const deckFavorited = Boolean(deckWord ? progress.words[deckWord.id]?.favorite : false);
  const [revealedByTap, setRevealed] = useState(false);
  // Some learners would rather read every card with its meaning already open
  // (a quick skim) than recall first. The toggle only skips the tap; grading
  // still works the same, and switching it off brings the recall face back.
  const [autoReveal, setAutoReveal] = useState(() => loadStudyAutoReveal(getAppStorage()));
  const revealed = revealedByTap || autoReveal;
  const toggleAutoReveal = useCallback(() => {
    setAutoReveal((current) => {
      saveStudyAutoReveal(getAppStorage(), !current);
      return !current;
    });
  }, []);
  const studyHintTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const studyInitialHintScheduledRef = useRef(false);
  // Everything that belongs to the live card — travel, tilt, entry, visibility
  // — has to live on the card itself. These used to be split across the card
  // and its parent stage, which meant hiding the thrown card also blanked the
  // underlay and the glow sitting in that same stage. That was the whole-card
  // flash: the page underneath was never on screen to cover the handoff.
  const slidingCardStyle = useAnimatedStyle(() => {
    const offsetX = swipeX.value + swipeHintX.value;
    const distanceScale = interpolate(
      Math.abs(swipeX.value),
      [0, STUDY_SWIPE_THRESHOLD, swipeExitX],
      [1, 0.988, 0.958],
      Extrapolation.CLAMP,
    );
    // The card pivots below its own base, so pushing one edge tips it like a
    // real card instead of sliding it along a rail.
    const tilt = interpolate(
      offsetX,
      [-STUDY_SWIPE_TILT_REFERENCE, 0, STUDY_SWIPE_TILT_REFERENCE],
      [-STUDY_SWIPE_MAX_TILT_DEG, 0, STUDY_SWIPE_MAX_TILT_DEG],
      Extrapolation.CLAMP,
    );
    const entryScale = interpolate(cardEntryProgress.value, [0, 1], [0.997, 1], Extrapolation.CLAMP);

    return {
      opacity:
        cardVisibility.value *
        interpolate(swipeX.value, [-swipeExitX, 0, swipeExitX], [0.92, 1, 0.92], Extrapolation.CLAMP),
      transform: [
        { translateX: offsetX },
        { translateY: interpolate(cardEntryProgress.value, [0, 1], [4, 0], Extrapolation.CLAMP) },
        { rotateZ: `${tilt}deg` },
        { scale: distanceScale * entryScale + swipeCommitPulse.value * 0.01 },
      ],
    };
  });
  // The next card sits under the current one and rises as the top card is
  // dragged away, so a swipe reads as dealing off a deck instead of one card
  // vanishing and an unrelated one fading in.
  // Deliberately understated. When the underlay rose close to full size it
  // read as "this is the next card", and the swap then looked like a glitch —
  // with any filter but "all", marking a word rebuilds and reshuffles the
  // session, so the card that actually arrives often is not this one. Staying
  // low keeps it an honest hint of depth rather than a broken promise.
  // Two stages, like turning a page. While the finger is still on the card the
  // page underneath only firms up a little. Once the card is thrown it settles
  // all the way into the live card's position, so by the time the top card is
  // gone the next one is already exactly where the incoming card will be —
  // that overlap is what covers the frames lost to runOnJS and the re-render,
  // which is where the flash was coming from.
  const deckUnderlayStyle = useAnimatedStyle(() => {
    const distance = Math.abs(swipeX.value);
    const settle = [0, STUDY_SWIPE_THRESHOLD, swipeExitX * 0.58];

    return {
      opacity: interpolate(distance, settle, [0.32, 0.58, 1], Extrapolation.CLAMP),
      transform: [
        { translateY: interpolate(distance, settle, [14, 9, 0], Extrapolation.CLAMP) },
        { scale: interpolate(distance, settle, [0.955, 0.974, 1], Extrapolation.CLAMP) },
      ],
    };
  });
  const studySwipeTouchGuardStyle: WebTransitionStyle | undefined =
    Platform.OS === 'web'
      ? {
          touchAction: 'none',
          userSelect: 'none',
          WebkitTouchCallout: 'none',
          WebkitUserSelect: 'none',
        }
      : undefined;
  const reviewFeedbackStyle = useAnimatedStyle(() => ({
    opacity: interpolate(
      swipeX.value,
      [
        -swipeExitX * 0.94,
        -STUDY_SWIPE_COMMIT_FADE_X,
        -STUDY_SWIPE_THRESHOLD,
        -STUDY_SWIPE_READY_FADE_X,
        -STUDY_SWIPE_PREVIEW_FADE_X,
        -STUDY_SWIPE_GLOW_WAKE_X,
        0,
      ],
      [0, 1, 0.94, 0.62, 0.28, 0.1, 0],
      Extrapolation.CLAMP,
    ),
  }));
  const knownFeedbackStyle = useAnimatedStyle(() => ({
    opacity: interpolate(
      swipeX.value,
      [
        0,
        STUDY_SWIPE_GLOW_WAKE_X,
        STUDY_SWIPE_PREVIEW_FADE_X,
        STUDY_SWIPE_READY_FADE_X,
        STUDY_SWIPE_THRESHOLD,
        STUDY_SWIPE_COMMIT_FADE_X,
        swipeExitX * 0.94,
      ],
      [0, 0.1, 0.28, 0.62, 0.94, 1, 0],
      Extrapolation.CLAMP,
    ),
  }));
  // The glow has to ride the exact same transform as the card, including the
  // hint nudge and the tilt. Tracking swipeX alone left it flat and lagging
  // behind the card edge it is supposed to be attached to.
  const reviewRevealGlowStyle = useAnimatedStyle(() => {
    const offsetX = swipeX.value + swipeHintX.value;
    return {
      transform: [
        {
          translateX: interpolate(
            offsetX,
            [-swipeExitX, 0],
            [STUDY_SWIPE_REVEAL_WIDTH - swipeExitX, STUDY_SWIPE_REVEAL_WIDTH],
            Extrapolation.CLAMP,
          ),
        },
        {
          rotateZ: `${interpolate(
            offsetX,
            [-STUDY_SWIPE_TILT_REFERENCE, 0, STUDY_SWIPE_TILT_REFERENCE],
            [-STUDY_SWIPE_MAX_TILT_DEG, 0, STUDY_SWIPE_MAX_TILT_DEG],
            Extrapolation.CLAMP,
          )}deg`,
        },
      ],
    };
  });
  const knownRevealGlowStyle = useAnimatedStyle(() => {
    const offsetX = swipeX.value + swipeHintX.value;
    return {
      transform: [
        {
          translateX: interpolate(
            offsetX,
            [0, swipeExitX],
            [-STUDY_SWIPE_REVEAL_WIDTH, swipeExitX - STUDY_SWIPE_REVEAL_WIDTH],
            Extrapolation.CLAMP,
          ),
        },
        {
          rotateZ: `${interpolate(
            offsetX,
            [-STUDY_SWIPE_TILT_REFERENCE, 0, STUDY_SWIPE_TILT_REFERENCE],
            [-STUDY_SWIPE_MAX_TILT_DEG, 0, STUDY_SWIPE_MAX_TILT_DEG],
            Extrapolation.CLAMP,
          )}deg`,
        },
      ],
    };
  });
  // Fades back out as the card is thrown: past this point the decision is made
  // and the cue would only sit on top of the page settling into place.
  const reviewCueStyle = useAnimatedStyle(() => ({
    opacity: interpolate(
      swipeX.value,
      [-swipeExitX * 0.52, -STUDY_SWIPE_THRESHOLD, -STUDY_SWIPE_READY_FADE_X, 0],
      [0, 1, 0, 0],
      Extrapolation.CLAMP,
    ),
    transform: [
      {
        scale: interpolate(
          swipeX.value,
          [-STUDY_SWIPE_COMMIT_FADE_X, -STUDY_SWIPE_THRESHOLD, -STUDY_SWIPE_READY_FADE_X],
          [1.08, 1, 0.9],
          Extrapolation.CLAMP,
        ),
      },
    ],
  }));
  const knownCueStyle = useAnimatedStyle(() => ({
    opacity: interpolate(
      swipeX.value,
      [0, STUDY_SWIPE_READY_FADE_X, STUDY_SWIPE_THRESHOLD, swipeExitX * 0.52],
      [0, 0, 1, 0],
      Extrapolation.CLAMP,
    ),
    transform: [
      {
        scale: interpolate(
          swipeX.value,
          [STUDY_SWIPE_READY_FADE_X, STUDY_SWIPE_THRESHOLD, STUDY_SWIPE_COMMIT_FADE_X],
          [0.9, 1, 1.08],
          Extrapolation.CLAMP,
        ),
      },
    ],
  }));

  const runStudyCardEntry = useCallback(() => {
    cancelAnimation(cardEntryProgress);
    if (runtimePerformance.conserveResources) {
      cardEntryProgress.value = 1;
      return;
    }
    cardEntryProgress.value = 0;
    cardEntryProgress.value = withTiming(1, {
      duration: STUDY_CARD_ENTRY_MS,
      easing: ReanimatedEasing.bezier(0.2, 0.76, 0.24, 1),
    });
  }, [cardEntryProgress, runtimePerformance.conserveResources]);

  const fireSwipeHaptic = useCallback(() => {
    if (!runtimePerformance.lowPowerMode) {
      triggerPressHaptic('chip');
    }
  }, [runtimePerformance.lowPowerMode]);

  const fireSwipeCommitHaptic = useCallback(() => {
    if (!runtimePerformance.lowPowerMode) {
      triggerPressHaptic('primary');
    }
  }, [runtimePerformance.lowPowerMode]);

  const clearStudyHintTimer = useCallback(() => {
    if (studyHintTimerRef.current) {
      clearTimeout(studyHintTimerRef.current);
      studyHintTimerRef.current = null;
    }
  }, []);

  const runStudySwipeHint = useCallback(() => {
    if (runtimePerformance.conserveResources) {
      swipeHintX.value = 0;
      return;
    }
    cancelAnimation(swipeHintX);
    swipeHintX.value = 0;
    swipeHintX.value = withSequence(
      withTiming(-9, { duration: 135, easing: ReanimatedEasing.out(ReanimatedEasing.cubic) }),
      withTiming(11, { duration: 210, easing: ReanimatedEasing.inOut(ReanimatedEasing.cubic) }),
      withTiming(-6, { duration: 170, easing: ReanimatedEasing.inOut(ReanimatedEasing.cubic) }),
      withSpring(0, { damping: 15, mass: 0.55, stiffness: 220 }),
    );
  }, [runtimePerformance.conserveResources, swipeHintX]);

  const scheduleStudySwipeHint = useCallback(
    (delayMs: number) => {
      clearStudyHintTimer();
      const pulse = () => {
        runStudySwipeHint();
        studyHintTimerRef.current = setTimeout(pulse, STUDY_SWIPE_HINT_REPEAT_MS);
      };
      studyHintTimerRef.current = setTimeout(pulse, delayMs);
    },
    [clearStudyHintTimer, runStudySwipeHint],
  );

  const markStudyCardInteraction = useCallback(() => {
    scheduleStudySwipeHint(STUDY_SWIPE_HINT_IDLE_DELAY_MS);
  }, [scheduleStudySwipeHint]);

  const finishNativeSwipe = useCallback(
    (directionCode: number) => {
      if (directionCode > 0) {
        onSwipeKnown();
      } else {
        onSwipeReview();
      }
    },
    [onSwipeKnown, onSwipeReview],
  );

  useLayoutEffect(() => {
    cancelAnimation(cardEntryProgress);
    cancelAnimation(swipeX);
    cancelAnimation(swipeHintX);
    cancelAnimation(swipeCommitPulse);
    swipeX.value = 0;
    swipeHintX.value = 0;
    swipeStartX.value = 0;
    swipePhase.value = 0;
    hapticDirectionCode.value = 0;
    swipeCommitPulse.value = 0;
    cardVisibility.value = 1;
    setDeckWord(nextWord);
    setRevealed(false);
    if (swipeHandoff.value === 1) {
      swipeHandoff.value = 0;
      cardEntryProgress.value = 1;
    } else {
      runStudyCardEntry();
    }
  }, [cardEntryProgress, cardSequence, cardVisibility, hapticDirectionCode, nextWord, runStudyCardEntry, swipeCommitPulse, swipeHandoff, swipeHintX, swipePhase, swipeStartX, swipeX, word?.id]);

  useEffect(() => {
    if (!word) {
      clearStudyHintTimer();
      return;
    }

    const delay = studyInitialHintScheduledRef.current
      ? STUDY_SWIPE_HINT_IDLE_DELAY_MS
      : STUDY_SWIPE_HINT_INITIAL_DELAY_MS;
    studyInitialHintScheduledRef.current = true;
    scheduleStudySwipeHint(delay);
    return clearStudyHintTimer;
  }, [cardSequence, clearStudyHintTimer, scheduleStudySwipeHint, word?.id]);

  const revealCard = useCallback(() => {
    setRevealed(true);
    markStudyCardInteraction();
  }, [markStudyCardInteraction]);

  // Desktop browsers get the same three decisions on the keyboard, graded
  // through the same handlers a swipe uses. Tab screens stay mounted, so the
  // listener only lives while this screen is focused; otherwise arrow keys on
  // the library would quietly grade study cards.
  useFocusEffect(
    useCallback(() => {
      const browserWindow = Platform.OS === 'web'
        ? (globalThis as typeof globalThis & {
            addEventListener?: (type: string, listener: (event: KeyboardEvent) => void) => void;
            removeEventListener?: (type: string, listener: (event: KeyboardEvent) => void) => void;
          })
        : null;
      if (!browserWindow?.addEventListener || !word) {
        return undefined;
      }
      const handleKey = (event: KeyboardEvent) => {
        const target = event.target as { isContentEditable?: boolean; tagName?: string } | null;
        if (
          target?.tagName === 'INPUT' ||
          target?.tagName === 'TEXTAREA' ||
          target?.isContentEditable ||
          event.metaKey ||
          event.ctrlKey ||
          event.altKey
        ) {
          return;
        }
        if (event.key === ' ' || event.key === 'Enter') {
          event.preventDefault();
          setRevealed(true);
        } else if (event.key === 'ArrowLeft') {
          event.preventDefault();
          onSwipeReview();
        } else if (event.key === 'ArrowRight') {
          event.preventDefault();
          onSwipeKnown();
        }
      };
      browserWindow.addEventListener('keydown', handleKey);
      return () => browserWindow.removeEventListener?.('keydown', handleKey);
    }, [onSwipeKnown, onSwipeReview, word]),
  );

  const studySwipeGesture = useMemo(
    () =>
      Gesture.Pan()
        .enabled(Boolean(word))
        .activeOffsetX([-10, 10])
        .failOffsetY([-12, 12])
        .minDistance(4)
        .shouldCancelWhenOutside(false)
        .onBegin(() => {
          if (swipePhase.value === 3) {
            return;
          }
          cancelAnimation(swipeX);
          cancelAnimation(swipeHintX);
          cancelAnimation(swipeCommitPulse);
          swipeHintX.value = 0;
          swipeStartX.value = swipeX.value;
          swipePhase.value = 0;
          hapticDirectionCode.value = 0;
          swipeCommitPulse.value = 0;
          runOnJS(markStudyCardInteraction)();
        })
        .onStart(() => {
          if (swipePhase.value === 3) {
            return;
          }
          swipePhase.value = 1;
          if (SHOULD_CLEAR_STUDY_SELECTION) {
            runOnJS(clearStudySwipeTextSelection)();
          }
        })
        .onUpdate((event) => {
          if (swipePhase.value !== 1) {
            return;
          }
          const nextX = swipeStartX.value + event.translationX;
          swipeX.value = nextX;

          const flingVelocity = STUDY_SWIPE_FLING_VELOCITY * 1000;
          const readyCode =
            nextX >= STUDY_SWIPE_THRESHOLD ||
            (nextX >= STUDY_SWIPE_FLING_DISTANCE && event.velocityX >= flingVelocity)
              ? 1
              : nextX <= -STUDY_SWIPE_THRESHOLD ||
                  (nextX <= -STUDY_SWIPE_FLING_DISTANCE && event.velocityX <= -flingVelocity)
                ? -1
                : 0;
          if (readyCode !== 0 && hapticDirectionCode.value !== readyCode) {
            hapticDirectionCode.value = readyCode;
            swipeCommitPulse.value = 0;
            swipeCommitPulse.value = withSequence(
              withTiming(1, { duration: 64, easing: ReanimatedEasing.out(ReanimatedEasing.cubic) }),
              withSpring(0, { damping: 15, mass: 0.45, stiffness: 250 }),
            );
            runOnJS(fireSwipeHaptic)();
          } else if (readyCode === 0 && hapticDirectionCode.value !== 0) {
            hapticDirectionCode.value = 0;
          }
        })
        .onEnd((event) => {
          if (swipePhase.value !== 1) {
            return;
          }
          const nextX = swipeX.value;
          const flingVelocity = STUDY_SWIPE_FLING_VELOCITY * 1000;
          const directionCode =
            nextX >= STUDY_SWIPE_RELEASE_DISTANCE ||
            (nextX >= STUDY_SWIPE_FLING_DISTANCE && event.velocityX >= flingVelocity)
              ? 1
              : nextX <= -STUDY_SWIPE_RELEASE_DISTANCE ||
                  (nextX <= -STUDY_SWIPE_FLING_DISTANCE && event.velocityX <= -flingVelocity)
                ? -1
                : 0;
          swipePhase.value = 2;

          if (directionCode !== 0) {
            swipePhase.value = 3;
            if (hapticDirectionCode.value !== directionCode) {
              hapticDirectionCode.value = directionCode;
            }
            runOnJS(fireSwipeCommitHaptic)();
            swipeCommitPulse.value = withSequence(
              withTiming(1, { duration: 72, easing: ReanimatedEasing.out(ReanimatedEasing.cubic) }),
              withSpring(0, { damping: 18, mass: 0.5, stiffness: 230 }),
            );
            // Carry the finger's velocity straight into the exit so the card
            // keeps moving at the speed it was released at. A timing curve
            // always restarts from zero, which is what made a fast flick stall
            // for a moment before the card left the screen.
            const releaseVelocity = Math.abs(event.velocityX) < STUDY_SWIPE_MIN_EXIT_VELOCITY
              ? directionCode * STUDY_SWIPE_MIN_EXIT_VELOCITY
              : event.velocityX;
            // Decay, not spring: a spring settles *at* its target, so the card
            // was braking over the last stretch — right as it should have been
            // leaving the screen. Decay holds the release speed and the clamp
            // ends the animation the moment the card is fully out of frame.
            swipeX.value = withDecay(
              {
                clamp: directionCode > 0 ? [0, swipeExitX] : [-swipeExitX, 0],
                deceleration: 0.998,
                velocity: releaseVelocity,
              },
              (finished) => {
                if (!finished) {
                  return;
                }
                // Hide the thrown card, but leave swipeX where it is. The
                // underlay reads from it, so zeroing it here would drop the
                // settled page back to its resting state during the very
                // frames it is meant to be covering. The layout effect that
                // runs with the new word resets everything at the same moment
                // the incoming card is painted over it.
                cardVisibility.value = 0;
                swipeHandoff.value = 1;
                runOnJS(finishNativeSwipe)(directionCode);
              },
            );
            return;
          }

          swipeCommitPulse.value = withTiming(0, { duration: 120 });
          swipeX.value = withSpring(
            0,
            { damping: 24, mass: 0.82, stiffness: 210, velocity: event.velocityX },
            (finished) => {
              if (finished) {
                swipePhase.value = 0;
                swipeStartX.value = 0;
                hapticDirectionCode.value = 0;
              }
            },
          );
        })
        .onFinalize(() => {
          if (swipePhase.value !== 1) {
            return;
          }
          swipePhase.value = 2;
          swipeCommitPulse.value = withTiming(0, { duration: 120 });
          swipeX.value = withSpring(
            0,
            { damping: 25, mass: 0.84, stiffness: 215 },
            (finished) => {
              if (finished) {
                swipePhase.value = 0;
                swipeStartX.value = 0;
                hapticDirectionCode.value = 0;
              }
            },
          );
        }),
    [
      cardEntryProgress,
      cardVisibility,
      finishNativeSwipe,
      fireSwipeCommitHaptic,
      fireSwipeHaptic,
      hapticDirectionCode,
      markStudyCardInteraction,
      swipeHintX,
      swipeCommitPulse,
      swipeHandoff,
      swipePhase,
      swipeStartX,
      swipeExitX,
      swipeX,
      word,
    ],
  );

  const sessionEmpty = sessionProgress.total === 0;
  const progressRatio = sessionProgress.total > 0 ? sessionProgress.done / sessionProgress.total : 0;
  const goalLeft = Math.max(0, dailyTarget - studiedToday);
  const bodyIconColor = darkMode ? '#F2F2F7' : '#1C1C1E';

  return (
    <View style={styles.screenStack}>
      <WordBankBar
        count={bankCount}
        filter={{
          active: activeFilter !== 'all' || activeLevel !== 'all' || activeInitial !== 'all',
          open: filtersOpen,
          testID: 'study-filter-toggle',
          onPress: onFiltersToggle,
        }}
        isScan={bankIsScan}
        name={bankName}
        studyMode={studyMode}
        testID="study-bank-bar"
        onPress={onOpenBankPicker}
      />
      <FilterControlPanel
        hideSummary
        activeFilter={activeFilter}
        activeInitial={activeInitial}
        activeLevel={activeLevel}
        count={wordCount}
        levelOptions={levelOptions}
        open={filtersOpen}
        favoritesLocked={favoriteLocked}
        showStatus
        studyMode={studyMode}
        testID="study-filter"
        title={copy.studyFilterTitle}
        initialTitle={copy.initialTitle}
        onFilterChange={onFilterChange}
        onInitialChange={onInitialChange}
        onLevelChange={onLevelChange}
        onToggle={onFiltersToggle}
      />


      {sessionEmpty && (
        <View style={[styles.emptyState, themeStyles?.emptyState]}>
          <Text style={[styles.emptyTitle, themeStyles?.emptyTitle]}>
            {studyMode === 'chinese' ? ui.noChineseWords : ui.noStudyWords}
          </Text>
          <Text style={[styles.emptyText, themeStyles?.emptyText]}>{ui.relaxFilters}</Text>
        </View>
      )}

      {!sessionEmpty && sessionComplete && (
        <Animated.View style={[styles.sessionSummaryCard, themeStyles?.quizSetupCard, motionStyle]} testID="study-session-summary">
          <View style={[styles.sessionSummaryIcon, themeStyles?.sessionSummaryIcon]}>
            <PartyPopper size={30} color="#FF9500" strokeWidth={2.2} />
          </View>
          <Text style={[styles.resultTitle, styles.quizResultTitle, themeStyles?.resultTitle]}>{ui.sessionCompleteTitle}</Text>
          <Text style={[styles.sessionSummaryText, themeStyles?.cardMeta]}>
            {ui.sessionCompleteText(sessionKnownCount, sessionReviewCount)}
          </Text>
          <View style={styles.sessionSummaryStats}>
            <StatCard label={ui.dailyProgress} value={`${studiedToday}/${dailyTarget}`} />
            <StatCard divider label={ui.streak} value={streak.toString()} />
          </View>
          <Text style={[styles.sessionSummaryGoal, themeStyles?.cardMeta]}>
            {goalLeft === 0 ? ui.sessionGoalDone : ui.sessionGoalLeft(goalLeft)}
          </Text>
          <AnimatedPressable accessibilityRole="button" onPress={onNextSession} pressTone="primary" style={styles.primaryButton} testID="study-next-session">
            <BookOpen size={18} color="#FFFFFF" strokeWidth={2.3} />
            <Text style={styles.primaryButtonText}>{ui.nextSession}</Text>
          </AnimatedPressable>
          {sessionReviewCount > 0 && (
            <AnimatedPressable accessibilityRole="button" onPress={onReviewMissed} pressTone="secondary" style={[styles.secondaryButton, styles.sessionSummaryWideButton, themeStyles?.secondaryButton]}>
              <RotateCcw size={17} color={bodyIconColor} strokeWidth={2.3} />
              <Text style={[styles.secondaryButtonText, themeStyles?.secondaryButtonText]}>{ui.reviewMissed(sessionReviewCount)}</Text>
            </AnimatedPressable>
          )}
          <AnimatedPressable accessibilityRole="button" onPress={onOpenQuiz} pressTone="secondary" style={[styles.secondaryButton, styles.sessionSummaryWideButton, themeStyles?.secondaryButton]}>
            <Target size={17} color={bodyIconColor} strokeWidth={2.3} />
            <Text style={[styles.secondaryButtonText, themeStyles?.secondaryButtonText]}>{ui.goQuiz}</Text>
          </AnimatedPressable>
        </Animated.View>
      )}

      {word && !sessionComplete && (
        <>
      <View style={styles.studySessionHeader} testID="study-session-header">
        <View style={styles.rowBetween}>
          <View style={styles.studySessionMeta}>
            <Text style={[styles.studySessionLabel, themeStyles?.studySessionLabel]}>
              {ui.sessionLabel(sessionProgress.done, sessionProgress.total)}
            </Text>
            <Text style={[styles.studySessionGoal, themeStyles?.cardMeta]}>{ui.todayGoalLine(studiedToday, dailyTarget)}</Text>
          </View>
          <AnimatedPressable
            accessibilityHint={ui.autoRevealHint}
            accessibilityLabel={ui.autoReveal}
            accessibilityRole="switch"
            accessibilityState={{ checked: autoReveal }}
            hitSlop={6}
            onPress={toggleAutoReveal}
            pressTone="secondary"
            style={[
              styles.studyAutoRevealToggle,
              themeStyles?.studyAutoRevealToggle,
              autoReveal && styles.studyAutoRevealToggleOn,
              autoReveal && themeStyles?.studyAutoRevealToggleOn,
            ]}
            testID="study-auto-reveal-toggle"
          >
            {autoReveal ? (
              <Eye size={15} color={darkMode ? '#0A84FF' : '#007AFF'} strokeWidth={2.4} />
            ) : (
              <EyeOff size={15} color={darkMode ? '#8E8E93' : '#6C6C70'} strokeWidth={2.4} />
            )}
            <Text
              numberOfLines={1}
              style={[
                styles.studyAutoRevealText,
                themeStyles?.studyAutoRevealText,
                autoReveal && styles.studyAutoRevealTextOn,
                autoReveal && themeStyles?.studyAutoRevealTextOn,
              ]}
            >
              {ui.autoReveal}
            </Text>
            <View
              style={[
                styles.studyAutoRevealTrack,
                themeStyles?.studyAutoRevealTrack,
                autoReveal && styles.studyAutoRevealTrackOn,
              ]}
            >
              <View style={[styles.studyAutoRevealKnob, autoReveal && styles.studyAutoRevealKnobOn]} />
            </View>
          </AnimatedPressable>
        </View>
        <View style={[styles.progressTrack, styles.studySessionTrack, themeStyles?.progressTrack]}>
          <View style={[styles.progressFill, { width: `${Math.round(progressRatio * 100)}%` }]} />
        </View>
      </View>
       <Animated.View style={[styles.studySwipeDeck, motionStyle]} testID="study-swipe-deck">
        <Reanimated.View style={styles.studySwipeSwapStage}>
        {deckWord && (
          <Reanimated.View
            pointerEvents="none"
            style={[
              styles.wordCard,
              styles.studySwipeDeckUnderlay,
              { height: studyCardHeight },
              themeStyles?.wordCard,
              deckUnderlayStyle,
            ]}
            testID="study-swipe-deck-underlay"
          >
            <View style={styles.rowBetween}>
              <View style={[styles.groupPill, themeStyles?.groupPill]}>
                <Text style={[styles.groupText, themeStyles?.groupText]}>{deckWord.group}</Text>
              </View>
              <View style={styles.studyCardActions}>
                <View style={[styles.iconButton, styles.addToSetIconButton, themeStyles?.iconButton]}>
                  <AddToSetGlyph locked={customSetsLocked} size={19} />
                </View>
                <View style={[styles.iconButton, themeStyles?.iconButton]}>
                  <FavoriteGlyph favorited={deckFavorited} locked={favoriteLocked} />
                </View>
              </View>
            </View>
            <StudyCardBody revealed={autoReveal} studyMode={studyMode} word={deckWord} />
          </Reanimated.View>
        )}
         <Reanimated.View
           pointerEvents="none"
           style={[styles.studySwipeRevealFill, styles.studySwipeRevealReview, reviewFeedbackStyle]}
        >
          <Reanimated.View
            style={[
              styles.studySwipeRevealGradientWrap,
              styles.studySwipeRevealReviewGradientWrap,
              reviewRevealGlowStyle,
            ]}
          >
            <StudySwipeRevealGradient tone="review" />
          </Reanimated.View>
          <Reanimated.View style={[styles.studySwipeRevealCue, styles.studySwipeRevealCueReview, reviewCueStyle]}>
            <X size={42} color="#D70015" strokeWidth={2.8} />
            {reviewHintLines.map((line, index) => (
              <Text
                key={`${line}-${index}`}
                numberOfLines={1}
                style={[
                  styles.studySwipeFeedbackLine,
                  styles.studySwipeFeedbackReviewText,
                  index === 0 ? styles.studySwipeFeedbackLead : styles.studySwipeFeedbackAction,
                ]}
              >
                {line}
              </Text>
            ))}
          </Reanimated.View>
        </Reanimated.View>
        <Reanimated.View
          pointerEvents="none"
          style={[styles.studySwipeRevealFill, styles.studySwipeRevealKnown, knownFeedbackStyle]}
        >
          <Reanimated.View
            style={[
              styles.studySwipeRevealGradientWrap,
              styles.studySwipeRevealKnownGradientWrap,
              knownRevealGlowStyle,
            ]}
          >
            <StudySwipeRevealGradient tone="known" />
          </Reanimated.View>
          <Reanimated.View style={[styles.studySwipeRevealCue, styles.studySwipeRevealCueKnown, knownCueStyle]}>
            <Check size={42} color="#248A3D" strokeWidth={2.8} />
            {knownHintLines.map((line, index) => (
              <Text
                key={`${line}-${index}`}
                numberOfLines={1}
                style={[
                  styles.studySwipeFeedbackLine,
                  styles.studySwipeFeedbackKnownText,
                  index === 0 ? styles.studySwipeFeedbackLead : styles.studySwipeFeedbackAction,
                ]}
              >
                {line}
              </Text>
            ))}
          </Reanimated.View>
        </Reanimated.View>
        <GestureDetector gesture={studySwipeGesture}>
         <Reanimated.View
          accessibilityHint={`${ui.swipeReviewHint}; ${ui.swipeKnownHint}`}
          style={[
            styles.wordCard,
            styles.studySwipeSlidingCard,
            { height: studyCardHeight },
            themeStyles?.wordCard,
            slidingCardStyle,
            studySwipeTouchGuardStyle,
          ]}
          testID="study-swipe-card"
        >
          <View style={styles.rowBetween}>
            <View style={[styles.groupPill, themeStyles?.groupPill]}>
              <Text style={[styles.groupText, themeStyles?.groupText]}>{word.group}</Text>
            </View>
            <View style={styles.studyCardActions}>
              <AnimatedPressable
                accessibilityLabel={ui.addToSetName(formatWordPrimary(word, studyMode))}
                accessibilityHint={customSetsLocked ? ui.favoritesRequireSignIn : undefined}
                accessibilityRole="button"
                hapticEnabled={!customSetsLocked}
                onPress={() => onAddToSet(word)}
                pressTone="icon"
                style={[styles.iconButton, styles.addToSetIconButton, themeStyles?.iconButton]}
                testID="study-add-to-set"
              >
                <AddToSetGlyph locked={customSetsLocked} size={19} />
              </AnimatedPressable>
              <AnimatedPressable
                accessibilityLabel={favorited ? ui.unfavoriteWord : ui.favoriteWord}
                accessibilityRole="button"
                hapticEnabled={!favoriteLocked}
                onPress={onFavorite}
                pressTone="icon"
                style={[styles.iconButton, themeStyles?.iconButton]}
                hitSlop={8}
              >
                <FavoriteGlyph favorited={favorited} locked={favoriteLocked} />
              </AnimatedPressable>
            </View>
          </View>
          <StudyCardBody onReveal={revealCard} revealed={revealed} studyMode={studyMode} word={word} />
         </Reanimated.View>
        </GestureDetector>
        </Reanimated.View>
       </Animated.View>

      {/* Two explicit grade buttons, not "previous / next": every card has to
          end with a decision, or the schedule never learns anything. They also
          give VoiceOver users the same choice the swipe gives everyone else. */}
      <View style={styles.studyGradeRow} testID="study-navigation-controls">
        <AnimatedPressable
          accessibilityLabel={ui.undo}
          accessibilityRole="button"
          disabled={!canUndo}
          onPress={onUndo}
          pressTone="icon"
          style={[styles.studyUndoButton, themeStyles?.secondaryButton, !canUndo && styles.disabledButton]}
          testID="study-undo"
        >
          <Undo2 size={19} color={bodyIconColor} strokeWidth={2.3} />
        </AnimatedPressable>
        {revealed ? (
          <>
            <AnimatedPressable
              accessibilityRole="button"
              onPress={onSwipeReview}
              pressTone="secondary"
              style={[styles.studyGradeButton, styles.studyGradeReview, themeStyles?.studyGradeReview]}
              testID="study-grade-review"
            >
              <X size={18} color={darkMode ? '#FF6961' : '#D70015'} strokeWidth={2.6} />
              <Text style={[styles.studyGradeText, styles.studyGradeReviewText, themeStyles?.studyGradeReviewText]}>{ui.dontKnow}</Text>
            </AnimatedPressable>
            <AnimatedPressable
              accessibilityRole="button"
              onPress={onSwipeKnown}
              pressTone="primary"
              style={[styles.studyGradeButton, styles.studyGradeKnown]}
              testID="study-grade-known"
            >
              <Check size={18} color="#FFFFFF" strokeWidth={2.6} />
              <Text style={[styles.studyGradeText, styles.studyGradeKnownText]}>{ui.knowIt}</Text>
            </AnimatedPressable>
          </>
        ) : (
          <AnimatedPressable
            accessibilityRole="button"
            onPress={revealCard}
            pressTone="primary"
            style={[styles.studyGradeButton, styles.studyRevealButton]}
            testID="study-show-answer"
          >
            <Eye size={18} color="#FFFFFF" strokeWidth={2.4} />
            <Text style={[styles.studyGradeText, styles.studyGradeKnownText]}>{ui.showAnswer}</Text>
          </AnimatedPressable>
        )}
      </View>
        </>
      )}
    </View>
  );
});

function FilterControlPanel({
  activeFilter,
  activeInitial,
  activeLevel,
  activeSort,
  count,
  favoritesLocked,
  hideSummary,
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
  favoritesLocked: boolean;
  /** The toggle lives elsewhere (the bank toolbar); show only the options. */
  hideSummary?: boolean;
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
  const bodyIconColor = useContext(ThemeContext) === 'dark' ? '#F2F2F7' : '#1C1C1E';
  const ui = modeInterfaceCopy[studyMode];

  if (hideSummary && !open) {
    return null;
  }

  return (
    <View style={[styles.foldedFilterCard, themeStyles?.foldedFilterCard]}>
      {hideSummary ? (
        <Text style={[styles.filterInlineSummary, themeStyles?.filterSummaryText]}>
          {summary} · {count} {ui.filterCountUnit}
        </Text>
      ) : (
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
      )}

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
                      hapticEnabled={filter.id !== 'favorites' || !favoritesLocked}
                      key={filter.id}
                      onPress={() => onFilterChange(filter.id)}
                      pressTone="chip"
                      style={[styles.filterChip, themeStyles?.filterChip, selected && styles.filterChipActive]}
                    >
                      <View style={styles.filterChipLabelRow}>
                        <Text adjustsFontSizeToFit minimumFontScale={0.86} numberOfLines={1} style={[styles.filterText, selected && styles.filterTextActive]}>{filterLabel(filter.id, studyMode)}</Text>
                        {filter.id === 'favorites' && favoritesLocked && (
                          <Lock size={11} color={selected ? '#FFFFFF' : '#6C6C70'} strokeWidth={2.5} />
                        )}
                      </View>
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
                    <Text adjustsFontSizeToFit minimumFontScale={0.86} numberOfLines={1} style={[styles.filterText, selected && styles.filterTextActive]}>{levelLabel(level.id, studyMode, levelOptions)}</Text>
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
                    <Text adjustsFontSizeToFit minimumFontScale={0.86} numberOfLines={1} style={[styles.letterText, selected && styles.letterTextActive]}>{initialLabel(initial.id, studyMode)}</Text>
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
                      <Text adjustsFontSizeToFit minimumFontScale={0.86} numberOfLines={1} style={[styles.filterText, selected && styles.filterTextActive]}>{label}</Text>
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

const QuizView = memo(function QuizView({
  bankCount,
  bankIsScan,
  bankName,
  activeFilter,
  activeInitial,
  activeLevel,
  chosenText,
  correctCount,
  filtersOpen,
  favoriteLocked,
  levelOptions,
  missedWords,
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
  onOpenBankPicker,
  onFilterChange,
  onFiltersToggle,
  onInitialChange,
  onLevelChange,
  onPracticeModeChange,
  onNext,
  onPracticeMissed,
  onQuestionCountChange,
  onRevealSpeakingAnswer,
  onRestart,
  onStart,
}: {
  bankCount: number;
  bankIsScan: boolean;
  bankName: string;
  activeFilter: LibraryFilter;
  activeInitial: string;
  activeLevel: string;
  chosenText: string | null;
  correctCount: number;
  favoriteLocked: boolean;
  filtersOpen: boolean;
  levelOptions: FilterOption[];
  missedWords: WordEntry[];
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
  onAnswer: (option: QuizOption) => void;
  onOpenBankPicker: () => void;
  onFilterChange: (filter: LibraryFilter) => void;
  onFiltersToggle: () => void;
  onInitialChange: (initial: string) => void;
  onLevelChange: (level: string) => void;
  onPracticeModeChange: (mode: QuizPracticeMode) => void;
  onNext: () => void;
  onPracticeMissed: () => void;
  onQuestionCountChange: (count: (typeof quizQuestionCounts)[number]) => void;
  onRevealSpeakingAnswer: (completed: boolean) => void;
  onRestart: () => void;
  onStart: () => void;
}) {
  const themeStyles = useThemeStyles();
  const bodyIconColor = useContext(ThemeContext) === 'dark' ? '#F2F2F7' : '#1C1C1E';
  const copy = modeCopy[studyMode];
  const ui = modeInterfaceCopy[studyMode];
  const speakingMode = practiceMode === 'speaking';

  const inSession = quizStarted && Boolean(word);
  const answered = speakingMode ? speakingAnswerVisible : result !== null;
  const progressRatio = sessionTotal > 0 ? (questionIndex + (answered ? 1 : 0)) / sessionTotal : 0;
  const accuracy = sessionTotal > 0 ? Math.round((correctCount / sessionTotal) * 100) : 0;
  const optionLetters = ['A', 'B', 'C', 'D'];
  const isLastQuestion = questionIndex >= sessionTotal - 1;

  // The way forward sits right under the answers, where the eye and thumb
  // already are; the explanation follows below for anyone who wants it.
  const nextButton = inSession && answered ? (
    <AnimatedPressable
      accessibilityRole="button"
      onPress={onNext}
      pressTone="primary"
      style={[styles.primaryButton, styles.quizNextButton]}
      testID="quiz-next"
    >
      <Text style={styles.primaryButtonText}>{isLastQuestion ? ui.seeResults : ui.nextQuestion}</Text>
      <ChevronRight size={18} color="#FFFFFF" strokeWidth={2.4} />
    </AnimatedPressable>
  ) : null;

  return (
    <View style={styles.screenStack}>
      {/* Setup only belongs before a quiz. Changing a filter mid-quiz throws
          the session away, so while one runs these controls are hidden and a
          single "end quiz" control takes their place. */}
      {!quizStarted && (
        <>
          <WordBankBar
            count={bankCount}
            filter={{
              active: activeFilter !== 'all' || activeLevel !== 'all' || activeInitial !== 'all',
              open: filtersOpen,
              testID: 'quiz-filter-toggle',
              onPress: onFiltersToggle,
            }}
            isScan={bankIsScan}
            name={bankName}
            studyMode={studyMode}
            testID="quiz-bank-bar"
            onPress={onOpenBankPicker}
          />
          <FilterControlPanel
            hideSummary
            activeFilter={activeFilter}
            activeInitial={activeInitial}
            activeLevel={activeLevel}
            count={wordCount}
            favoritesLocked={favoriteLocked}
            levelOptions={levelOptions}
            open={filtersOpen}
            showStatus
            studyMode={studyMode}
            testID="quiz-filter"
            title={copy.quizFilterTitle}
            initialTitle={copy.initialTitle}
            onFilterChange={onFilterChange}
            onInitialChange={onInitialChange}
            onLevelChange={onLevelChange}
            onToggle={onFiltersToggle}
          />

        </>
      )}

      {!quizStarted && !quizFinished && (
        <Animated.View style={[styles.quizSetupCard, themeStyles?.quizSetupCard, motionStyle]}>
          <Text style={[styles.sectionTitle, themeStyles?.sectionTitle]}>{ui.quizPracticeTitle}</Text>
          <View style={[styles.quizModeSwitch, themeStyles?.quizModeSwitch]}>
            {(['choice', 'speaking'] as const).map((mode) => {
              const selected = practiceMode === mode;
              return (
                <AnimatedPressable
                  accessibilityRole="button"
                  accessibilityState={{ selected }}
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

          <View style={[styles.quizSectionDivider, themeStyles?.quizSectionDivider]} />
          <View>
            <Text style={[styles.sectionTitle, themeStyles?.sectionTitle]}>{ui.questionCountTitle}</Text>
            <Text style={[styles.cardMeta, themeStyles?.cardMeta]}>{ui.questionBankPrefix} {wordCount} {copy.questionBankUnit}</Text>
          </View>
          <View style={styles.quizCountRow}>
            {questionCounts.map((count) => {
              const selected = questionCount === count;
              const cappedCount = Math.min(count, wordCount);
              return (
                <AnimatedPressable
                  accessibilityRole="button"
                  accessibilityState={{ selected }}
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
            testID="quiz-start"
          >
            {speakingMode ? (
              <Languages size={18} color="#FFFFFF" strokeWidth={2.3} />
            ) : (
              <Target size={18} color="#FFFFFF" strokeWidth={2.3} />
            )}
            <Text style={styles.primaryButtonText}>{speakingMode ? ui.startSpeaking : ui.startQuiz}</Text>
          </AnimatedPressable>
        </Animated.View>
      )}

      {quizFinished && (
        <Animated.View style={[styles.sessionSummaryCard, themeStyles?.quizSetupCard, motionStyle]} testID="quiz-results">
          <Text style={[styles.eyebrow, styles.quizResultEyebrow]}>{speakingMode ? 'SPEAKING' : 'RESULT'}</Text>
          {!speakingMode && (
            <View style={[styles.quizScoreRing, accuracy >= 80 ? styles.quizScoreRingGood : accuracy >= 50 ? styles.quizScoreRingOkay : styles.quizScoreRingLow]}>
              <Text style={[styles.quizScoreRingValue, themeStyles?.resultTitle]}>{accuracy}%</Text>
            </View>
          )}
          <Text style={[styles.resultTitle, styles.quizResultTitle, themeStyles?.resultTitle]}>
            {speakingMode ? ui.speakingFinished : ui.quizFinished}
          </Text>
          <Text style={[styles.quizScoreText, styles.quizResultTitle, themeStyles?.quizScoreText]}>
            {speakingMode ? ui.speakingScore(sessionTotal) : ui.quizScore(correctCount, sessionTotal)}
          </Text>
          {!speakingMode && missedWords.length > 0 && (
            <View style={[styles.quizMissedList, themeStyles?.quizExampleCard]} testID="quiz-missed-words">
              <Text style={[styles.quizExampleLabel, themeStyles?.quizExampleLabel]}>{ui.quizMissedTitle(missedWords.length)}</Text>
              {missedWords.slice(0, 8).map((missed) => (
                <View key={missed.id} style={styles.quizMissedRow}>
                  <Text numberOfLines={1} style={[styles.quizMissedWord, themeStyles?.resultTitle]}>{formatWordPrimary(missed, studyMode)}</Text>
                  <Text numberOfLines={1} style={[styles.quizMissedMeaning, themeStyles?.cardMeta]}>{formatQuizAnswer(missed, studyMode)}</Text>
                </View>
              ))}
              {missedWords.length > 8 && (
                <Text style={[styles.cardMeta, themeStyles?.cardMeta]}>+{missedWords.length - 8}</Text>
              )}
            </View>
          )}
          {!speakingMode && missedWords.length > 0 && (
            <AnimatedPressable accessibilityRole="button" onPress={onPracticeMissed} pressTone="primary" style={styles.primaryButton} testID="quiz-practice-missed">
              <BookOpen size={18} color="#FFFFFF" strokeWidth={2.3} />
              <Text style={styles.primaryButtonText}>{ui.practiceMissed(missedWords.length)}</Text>
            </AnimatedPressable>
          )}
          <AnimatedPressable
            accessibilityRole="button"
            onPress={onRestart}
            pressTone={missedWords.length > 0 && !speakingMode ? 'secondary' : 'primary'}
            style={missedWords.length > 0 && !speakingMode
              ? [styles.secondaryButton, styles.sessionSummaryWideButton, themeStyles?.secondaryButton]
              : styles.primaryButton}
          >
            <RotateCcw size={18} color={missedWords.length > 0 && !speakingMode ? bodyIconColor : '#FFFFFF'} strokeWidth={2.3} />
            <Text style={missedWords.length > 0 && !speakingMode ? [styles.secondaryButtonText, themeStyles?.secondaryButtonText] : styles.primaryButtonText}>
              {speakingMode ? ui.restartSpeaking : ui.restartQuiz}
            </Text>
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

      {inSession && (
        <View style={styles.studySessionHeader} testID="quiz-session-header">
          <View style={styles.rowBetween}>
            <Text style={[styles.studySessionLabel, themeStyles?.studySessionLabel]}>
              {speakingMode ? 'SPEAKING' : 'QUIZ'} {questionIndex + 1} / {sessionTotal}
            </Text>
            <AnimatedPressable
              accessibilityRole="button"
              onPress={onRestart}
              pressTone="chip"
              style={[styles.quizQuitButton, themeStyles?.quizQuitButton]}
              testID="quiz-quit"
            >
              <X size={14} color={bodyIconColor} strokeWidth={2.5} />
              <Text style={[styles.quizQuitText, themeStyles?.quizQuitText]}>{ui.endQuiz}</Text>
            </AnimatedPressable>
          </View>
          <View style={[styles.progressTrack, styles.studySessionTrack, themeStyles?.progressTrack]}>
            <View style={[styles.progressFill, { width: `${Math.round(progressRatio * 100)}%` }]} />
          </View>
        </View>
      )}

      {quizStarted && word && !speakingMode && (
        <>
          <Animated.View style={[styles.quizCard, themeStyles?.quizCard, motionStyle]}>
            <Text style={[styles.quizPromptLabel, themeStyles?.cardMeta]}>{ui.quizPrompt}</Text>
            <Text style={[styles.bigWord, studyMode === 'chinese' && styles.bigChineseWord, themeStyles?.bigWord]}>
              {formatWordPrimary(word, studyMode)}
            </Text>
            {studyMode === 'chinese' && (
              <Text style={[styles.pinyinText, themeStyles?.pinyinText]}>{formatWordPinyin(word, studyMode)}</Text>
            )}
            <View style={styles.quizOptions}>
              {options.map((option, index) => {
                const chosen = result !== null && option.meaning === chosenText;
                const showCorrect = result !== null && option.correct;
                const showWrong = chosen && !option.correct;
                return (
                  <AnimatedPressable
                    accessibilityLabel={`${optionLetters[index] ?? ''} ${option.meaning}`}
                    accessibilityRole="button"
                    accessibilityState={{ disabled: result !== null, selected: chosen }}
                    disabled={result !== null}
                    key={`${index}-${option.meaning}`}
                    onPress={() => onAnswer(option)}
                    pressTone="list"
                    pressedStyle={[styles.quizOptionPressed, themeStyles?.quizOptionPressed]}
                    style={[
                      styles.quizOption,
                      themeStyles?.quizOption,
                      showCorrect && [styles.quizOptionCorrect, themeStyles?.quizOptionCorrect],
                      showWrong && [styles.quizOptionWrong, themeStyles?.quizOptionWrong],
                      result !== null && !showCorrect && !showWrong && styles.quizOptionMuted,
                    ]}
                    testID={`quiz-option-${index}`}
                  >
                    <View
                      style={[
                        styles.quizOptionLetter,
                        themeStyles?.quizOptionLetter,
                        showCorrect && styles.quizOptionLetterCorrect,
                        showWrong && styles.quizOptionLetterWrong,
                      ]}
                    >
                      {showCorrect ? (
                        <Check size={14} color="#FFFFFF" strokeWidth={3} />
                      ) : showWrong ? (
                        <X size={14} color="#FFFFFF" strokeWidth={3} />
                      ) : (
                        <Text style={[styles.quizOptionLetterText, themeStyles?.quizOptionLetterText]}>{optionLetters[index]}</Text>
                      )}
                    </View>
                    <Text
                      style={[
                        styles.quizOptionText,
                        themeStyles?.quizOptionText,
                        showCorrect && [styles.quizOptionTextCorrect, themeStyles?.quizOptionTextCorrect],
                        showWrong && [styles.quizOptionTextWrong, themeStyles?.quizOptionTextWrong],
                      ]}
                    >
                      {option.meaning}
                    </Text>
                  </AnimatedPressable>
                );
              })}
            </View>
          </Animated.View>

          {nextButton}

          {result && (
            <Animated.View
              style={[
                styles.resultCard,
                themeStyles?.resultCard,
                result === 'correct' ? [styles.resultCorrect, themeStyles?.resultCorrect] : [styles.resultWrong, themeStyles?.resultWrong],
                motionStyle,
              ]}
            >
              <Text style={[styles.resultTitle, themeStyles?.resultTitle]}>{result === 'correct' ? ui.correctResult : ui.wrongResult}</Text>
              <View style={[styles.quizExampleCard, themeStyles?.quizExampleCard]}>
                <Text style={[styles.quizExampleLabel, themeStyles?.quizExampleLabel]}>{ui.answer}</Text>
                <Text style={[styles.resultText, themeStyles?.resultText]}>{formatQuizAnswer(word, studyMode)}</Text>
                {formatMeaningSupplement(word) && (
                  <>
                    <Text style={[styles.quizExampleLabel, themeStyles?.quizExampleLabel]}>{ui.supplementalMeanings}</Text>
                    <Text style={[styles.resultText, themeStyles?.resultText]}>{formatMeaningSupplement(word)}</Text>
                  </>
                )}
                {Boolean(formatExamplePrimary(word, studyMode)) && (
                  <>
                    <Text style={[styles.quizExampleLabel, themeStyles?.quizExampleLabel]}>
                      {studyMode === 'chinese' ? ui.chineseExample : ui.englishExample}
                    </Text>
                    <Text style={[styles.resultText, themeStyles?.resultText]}>{formatExamplePrimary(word, studyMode)}</Text>
                    <Text style={[styles.quizExampleLabel, themeStyles?.quizExampleLabel]}>
                      {studyMode === 'chinese' ? ui.englishExample : ui.chineseTranslation}
                    </Text>
                    <Text style={[styles.resultText, themeStyles?.resultText]}>{formatExampleSecondary(word, studyMode)}</Text>
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
            <View style={styles.speakingKeywordHeader}>
              <View style={[styles.speakingIconWrap, themeStyles?.speakingIconWrap]}>
                <Languages size={24} color="#007AFF" strokeWidth={2.4} />
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
            {!speakingAnswerVisible && (
              <View style={styles.speakingActionRow}>
                <AnimatedPressable
                  accessibilityRole="button"
                  onPress={() => onRevealSpeakingAnswer(true)}
                  pressTone="primary"
                  style={styles.speakingDoneButton}
                >
                  <Check size={18} color="#FFFFFF" strokeWidth={2.4} />
                  <Text style={styles.speakingDoneButtonText}>{ui.iSpoke}</Text>
                </AnimatedPressable>
                <AnimatedPressable
                  accessibilityRole="button"
                  onPress={() => onRevealSpeakingAnswer(false)}
                  pressTone="secondary"
                  style={[styles.speakingSecondaryButton, themeStyles?.speakingSecondaryButton]}
                >
                  <BookOpen size={18} color={bodyIconColor} strokeWidth={2.3} />
                  <Text style={[styles.speakingSecondaryText, themeStyles?.speakingSecondaryText]}>{ui.showSampleAnswer}</Text>
                </AnimatedPressable>
              </View>
            )}
          </Animated.View>

          {nextButton}

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
});

const LibraryView = memo(function LibraryView({
  activeFilter,
  bankCount,
  bankIsScan,
  bankName,
  onOpenBankPicker,
  onOpenScanner,
  activeInitial,
  activeLevel,
  activeSort,
  bottomInset,
  customSets,
  customSetsLocked,
  favoriteLocked,
  filtersOpen,
  levelOptions,
  listMotionStyle,
  listRef,
  progress,
  query,
  searchFocused,
  studyMode,
  words,
  onAddToSet,
  onContentSizeChange,
  onFavorite,
  onFilterChange,
  onFiltersToggle,
  onInitialChange,
  onLevelChange,
  onOpenCustomSets,
  onOpenWord,
  onQueryChange,
  onQueryClear,
  onScroll,
  onSearchBlur,
  onSearchFocus,
  onSortChange,
  onViewportLayout,
}: {
  activeFilter: LibraryFilter;
  activeInitial: string;
  activeLevel: string;
  activeSort: LibrarySort;
  bankCount: number;
  bankIsScan: boolean;
  bankName: string;
  onOpenBankPicker: () => void;
  onOpenScanner: () => void;
  bottomInset: number;
  customSets: CustomVocabSet[];
  customSetsLocked: boolean;
  favoriteLocked: boolean;
  filtersOpen: boolean;
  levelOptions: FilterOption[];
  listMotionStyle: (index: number) => StyleProp<ViewStyle>;
  listRef: RefObject<LibraryListHandle | null>;
  progress: ProgressState;
  query: string;
  searchFocused: boolean;
  studyMode: StudyMode;
  words: WordEntry[];
  onAddToSet: (word: WordEntry) => void;
  onContentSizeChange: (width: number, height: number) => void;
  onFavorite: (wordId: string) => void;
  onFilterChange: (filter: LibraryFilter) => void;
  onFiltersToggle: () => void;
  onInitialChange: (initial: string) => void;
  onLevelChange: (level: string) => void;
  onOpenCustomSets: () => void;
  onOpenWord: (word: WordEntry) => void;
  onQueryChange: (query: string) => void;
  onQueryClear: () => void;
  onScroll: (event: NativeSyntheticEvent<NativeScrollEvent>) => void;
  onSearchBlur: () => void;
  onSearchFocus: () => void;
  onSortChange: (sort: LibrarySort) => void;
  onViewportLayout: (event: LayoutChangeEvent) => void;
}) {
  const hasQuery = query.trim().length > 0;
  const libraryListContentStyle = useMemo(
    () => StyleSheet.flatten([
      styles.libraryListContent,
      { paddingBottom: CONTENT_BOTTOM_PADDING + bottomInset, paddingTop: TAB_CONTENT_TOP_PADDING },
    ]),
    [bottomInset],
  );
  const searchAnim = useRef(new Animated.Value(searchFocused || hasQuery ? 1 : 0)).current;
  const searchInputRef = useRef<TextInput | null>(null);
  const themeStyles = useThemeStyles();
  const runtimePerformance = useRuntimePerformance();
  const darkMode = useContext(ThemeContext) === 'dark';
  const bodyIconColor = darkMode ? '#F2F2F7' : '#1C1C1E';
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

  const listHeader = (
    <View style={styles.screenStack}>
      <WordBankBar count={bankCount} isScan={bankIsScan} name={bankName} studyMode={studyMode} testID="library-bank-bar" onPress={onOpenBankPicker} />
      <View style={[styles.libraryHeaderCard, themeStyles?.libraryHeaderCard]}>
        <View style={styles.libraryHeaderRow}>
          <View style={styles.libraryHeaderTitleLine}>
            <Text adjustsFontSizeToFit minimumFontScale={0.82} numberOfLines={1} style={[styles.libraryHeaderTitle, themeStyles?.libraryHeaderTitle]}>{copy.libraryTitle}</Text>
            <View style={[styles.libraryHeaderMetaPill, themeStyles?.libraryHeaderMetaPill]} testID="library-filtered-count-pill">
              <Text adjustsFontSizeToFit minimumFontScale={0.74} numberOfLines={1} style={[styles.libraryHeaderMetaPillText, themeStyles?.libraryHeaderMetaPillText]}>{ui.filteredCount(words.length)}</Text>
            </View>
          </View>
        </View>

        <View style={styles.libraryTopControlsInset}>
          <Animated.View style={searchMotionStyle}>
            <View style={[styles.searchBox, themeStyles?.searchBox, searchBoxWebTransition, searchFocused && styles.searchBoxFocused, hasQuery && styles.searchBoxActive]}>
              <Search size={18} color={searchFocused ? '#007AFF' : '#6C6C70'} strokeWidth={2.2} />
              <TextInput
                ref={searchInputRef}
                onChangeText={onQueryChange}
                onBlur={onSearchBlur}
                onFocus={onSearchFocus}
                placeholder={copy.searchPlaceholder}
                placeholderTextColor="#8E8E93"
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
                  <X size={16} color="#6C6C70" strokeWidth={2.5} />
                </AnimatedPressable>
              )}
            </View>
          </Animated.View>

          {hasQuery && (
            <Animated.View style={[styles.searchMetaBox, themeStyles?.searchMetaBox, searchMetaMotionStyle]}>
              <Text style={[styles.searchMetaText, themeStyles?.searchMetaText]}>{ui.searchMeta(query.trim(), words.length)}</Text>
            </Animated.View>
          )}

          <View style={styles.libraryStatusFilterRow}>
            {filters.map((filter) => {
              const selected = activeFilter === filter.id;
              return (
                <AnimatedPressable
                  accessibilityRole="button"
                  hapticEnabled={filter.id !== 'favorites' || !favoriteLocked}
                  key={filter.id}
                  onPress={() => onFilterChange(filter.id)}
                  pressTone="chip"
                  style={[styles.filterChip, styles.libraryStatusFilterChip, themeStyles?.filterChip, selected && styles.filterChipActive]}
                >
                  <View style={styles.filterChipLabelRow}>
                    <Text adjustsFontSizeToFit minimumFontScale={0.76} numberOfLines={1} style={[styles.filterText, selected && styles.filterTextActive]}>{filterLabel(filter.id, studyMode)}</Text>
                    {filter.id === 'favorites' && favoriteLocked && (
                      <Lock size={10} color={selected ? '#FFFFFF' : '#6C6C70'} strokeWidth={2.5} />
                    )}
                  </View>
                </AnimatedPressable>
              );
            })}
          </View>

          <FilterControlPanel
            activeFilter={activeFilter}
            activeInitial={activeInitial}
            activeLevel={activeLevel}
            activeSort={activeSort}
            count={words.length}
            favoritesLocked={favoriteLocked}
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
          <AnimatedPressable
            accessibilityHint={customSetsLocked ? ui.favoritesRequireSignIn : undefined}
            accessibilityLabel={ui.scanNewSheet}
            accessibilityRole="button"
            hapticEnabled={!customSetsLocked}
            onPress={onOpenScanner}
            pressTone="secondary"
            style={[styles.libraryManageSetsButton, themeStyles?.libraryTopButton]}
            testID="library-scan-button"
          >
            {customSetsLocked ? <Lock size={11} color={bodyIconColor} strokeWidth={2.5} /> : <ScanText size={14} color={bodyIconColor} strokeWidth={2.4} />}
            <Text adjustsFontSizeToFit minimumFontScale={0.86} numberOfLines={1} style={[styles.libraryManageSetsButtonLabel, themeStyles?.libraryTopButtonText]}>{ui.scanShort}</Text>
          </AnimatedPressable>
          <AnimatedPressable
            accessibilityHint={customSetsLocked ? ui.favoritesRequireSignIn : undefined}
            accessibilityRole="button"
            hapticEnabled={!customSetsLocked}
            onPress={onOpenCustomSets}
            pressTone="secondary"
            style={[styles.libraryManageSetsButton, themeStyles?.libraryTopButton]}
          >
            {customSetsLocked && <Lock size={11} color={bodyIconColor} strokeWidth={2.5} />}
            <Text adjustsFontSizeToFit minimumFontScale={0.86} numberOfLines={1} style={[styles.libraryManageSetsButtonLabel, themeStyles?.libraryTopButtonText]}>{ui.manage}</Text>
            <ChevronRight size={15} color={bodyIconColor} strokeWidth={2.4} />
          </AnimatedPressable>
        </View>
        {customSets.length > 0 ? (
          <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.filterRow}>
            {customSets.slice(0, 4).map((set) => (
              <AnimatedPressable
                accessibilityHint={customSetsLocked ? ui.favoritesRequireSignIn : undefined}
                accessibilityRole="button"
                hapticEnabled={!customSetsLocked}
                key={set.id}
                onPress={onOpenCustomSets}
                pressTone="chip"
                style={[styles.libraryCustomSetChip, themeStyles?.filterChip]}
              >
                <View style={[styles.customSetColorDot, { backgroundColor: set.color }]} />
                <Text numberOfLines={1} style={[styles.filterText, themeStyles?.filterText]}>{set.name}</Text>
                <Text style={[styles.libraryCustomSetCount, themeStyles?.libraryHeaderMeta]}>{set.wordIds.length}</Text>
                {customSetsLocked && <Lock size={10} color={bodyIconColor} strokeWidth={2.4} />}
              </AnimatedPressable>
            ))}
          </ScrollView>
        ) : (
          <Text style={[styles.customSetPickerEmpty, themeStyles?.customSetPickerEmpty]}>{ui.noCustomSets}</Text>
        )}
      </View>

    </View>
  );

  const renderItem = useCallback(
    ({ item, index }: { item: WordEntry; index: number }) => (
      <LibraryWordRow
        customSetsLocked={customSetsLocked}
        motionStyle={listMotionStyle(index)}
        favoriteLocked={favoriteLocked}
        studyMode={studyMode}
        word={item}
        wordProgress={progress.words[item.id]}
        onAddToSet={onAddToSet}
        onFavorite={onFavorite}
        onOpenWord={onOpenWord}
      />
    ),
    [customSetsLocked, favoriteLocked, listMotionStyle, onAddToSet, onFavorite, onOpenWord, progress.words, studyMode],
  );

  const assignFlashListRef = useCallback((instance: FlashListRef<WordEntry> | null) => {
    listRef.current = instance;
  }, [listRef]);

  const listEmptyComponent = (
    <View style={[styles.emptyState, themeStyles?.emptyState]}>
      <Text style={[styles.emptyTitle, themeStyles?.emptyTitle]}>
        {studyMode === 'chinese' ? ui.noChineseWords : ui.noLibraryWords}
      </Text>
      <Text style={[styles.emptyText, themeStyles?.emptyText]}>{ui.relaxLibraryFilters(hasQuery)}</Text>
    </View>
  );

  return (
    <FlashList
      contentContainerStyle={libraryListContentStyle}
      contentInsetAdjustmentBehavior="automatic"
      data={words}
      drawDistance={runtimePerformance.conserveResources || runtimePerformance.isLegacyIos ? 360 : 520}
      extraData={progress.words}
      ItemSeparatorComponent={LibraryItemSeparator}
      keyboardDismissMode="on-drag"
      keyboardShouldPersistTaps="handled"
      keyExtractor={libraryWordKeyExtractor}
      ListEmptyComponent={listEmptyComponent}
      ListHeaderComponent={listHeader}
      ListHeaderComponentStyle={styles.libraryListHeader}
      maintainVisibleContentPosition={{ disabled: true }}
      onContentSizeChange={onContentSizeChange}
      onLayout={onViewportLayout}
      onScroll={onScroll}
      ref={assignFlashListRef}
      renderItem={renderItem}
      scrollEventThrottle={runtimePerformance.conserveResources || runtimePerformance.isLegacyIos ? 32 : 16}
      showsVerticalScrollIndicator={false}
      style={styles.libraryFlashList}
      testID={IS_NATIVE_IOS ? 'library-native-list' : 'library-flash-list'}
    />
  );
});

function libraryWordKeyExtractor(word: WordEntry): string {
  return word.id;
}

function LibraryItemSeparator() {
  return <View style={styles.libraryItemSeparator} />;
}

const LibraryWordRow = memo(function LibraryWordRow({
  customSetsLocked,
  favoriteLocked,
  motionStyle,
  studyMode,
  word,
  wordProgress,
  onAddToSet,
  onFavorite,
  onOpenWord,
}: {
  customSetsLocked: boolean;
  favoriteLocked: boolean;
  motionStyle: StyleProp<ViewStyle>;
  studyMode: StudyMode;
  word: WordEntry;
  wordProgress: ProgressState['words'][string] | undefined;
  onAddToSet: (word: WordEntry) => void;
  onFavorite: (wordId: string) => void;
  onOpenWord: (word: WordEntry) => void;
}) {
  const themeStyles = useThemeStyles();
  const ui = modeInterfaceCopy[studyMode];
  const primaryWord = formatWordPrimary(word, studyMode);

  return (
    <Animated.View style={[styles.libraryItem, themeStyles?.libraryItem, motionStyle]}>
      <AnimatedPressable
        accessibilityLabel={ui.viewWordDetails(primaryWord)}
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
            {primaryWord}
          </Text>
          <Text style={styles.libraryGroup}>{word.group}</Text>
          <Text style={styles.libraryPos}>{word.partOfSpeech}</Text>
        </View>
        {studyMode === 'chinese' && (
          <Text style={[styles.libraryPinyin, themeStyles?.libraryPinyin]}>{formatWordPinyin(word, studyMode)}</Text>
        )}
        <Text style={[styles.libraryMeaning, themeStyles?.libraryMeaning]}>{formatMeaningDetail(word, studyMode)}</Text>
        {Boolean(formatExamplePrimary(word, studyMode)) && (
          <Text style={[styles.libraryExample, themeStyles?.libraryExample]}>{formatExamplePrimary(word, studyMode)}</Text>
        )}
      </AnimatedPressable>
      <View style={styles.librarySide}>
        <AnimatedPressable
          accessibilityLabel={ui.addToSetName(primaryWord)}
          accessibilityHint={customSetsLocked ? ui.favoritesRequireSignIn : undefined}
          accessibilityRole="button"
          hapticEnabled={!customSetsLocked}
          onPress={() => onAddToSet(word)}
          pressTone="icon"
          style={[styles.iconButton, styles.addToSetIconButton]}
          hitSlop={8}
        >
          <AddToSetGlyph locked={customSetsLocked} size={18} />
        </AnimatedPressable>
        <AnimatedPressable
          accessibilityLabel={wordProgress?.favorite ? ui.unfavoriteWordName(primaryWord) : ui.favoriteWordName(primaryWord)}
          accessibilityRole="button"
          hapticEnabled={!favoriteLocked}
          onPress={() => onFavorite(word.id)}
          pressTone="icon"
          style={styles.iconButton}
          hitSlop={8}
        >
          <FavoriteGlyph favorited={Boolean(wordProgress?.favorite)} locked={favoriteLocked} size={18} />
        </AnimatedPressable>
        <Text style={[styles.statusText, themeStyles?.statusText]}>{statusLabel(wordProgress?.status, studyMode)}</Text>
      </View>
    </Animated.View>
  );
});

export function LibraryWordDetailView({
  backDestination = 'library',
  customSetsLocked,
  favoriteLocked,
  progress,
  studyMode,
  word,
  onAddToSet,
  onBack,
  onFavorite,
}: {
  backDestination?: 'home' | 'library';
  customSetsLocked: boolean;
  favoriteLocked: boolean;
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
  const bodyIconColor = useContext(ThemeContext) === 'dark' ? '#F2F2F7' : '#1C1C1E';
  const ui = modeInterfaceCopy[studyMode];

  return (
    <View style={styles.screenStack}>
      <AnimatedPressable accessibilityRole="button" onPress={onBack} pressTone="secondary" style={[styles.libraryDetailBack, themeStyles?.libraryDetailBack]}>
        <ChevronLeft size={18} color={bodyIconColor} strokeWidth={2.5} />
        <Text style={[styles.libraryDetailBackText, themeStyles?.libraryDetailBackText]}>
          {backDestination === 'home' ? ui.backHome : ui.backLibrary}
        </Text>
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
              accessibilityHint={customSetsLocked ? ui.favoritesRequireSignIn : undefined}
              accessibilityRole="button"
              hapticEnabled={!customSetsLocked}
              onPress={() => onAddToSet(word)}
              pressTone="icon"
              style={styles.libraryDetailFavorite}
              hitSlop={8}
            >
              <AddToSetGlyph locked={customSetsLocked} size={21} />
            </AnimatedPressable>
            <AnimatedPressable
              accessibilityLabel={
                favorite
                  ? ui.unfavoriteWordName(formatWordPrimary(word, studyMode))
                  : ui.favoriteWordName(formatWordPrimary(word, studyMode))
              }
              accessibilityRole="button"
              hapticEnabled={!favoriteLocked}
              onPress={onFavorite}
              pressTone="icon"
              style={styles.libraryDetailFavorite}
              hitSlop={8}
            >
              <FavoriteGlyph favorited={favorite} locked={favoriteLocked} size={21} />
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

        {formatMeaningSupplement(word) && (
          <View style={[styles.libraryDetailSection, themeStyles?.libraryDetailSection]}>
            <Text style={[styles.libraryDetailLabel, themeStyles?.libraryDetailLabel]}>{ui.supplementalMeanings}</Text>
            <Text style={[styles.libraryDetailMeaning, themeStyles?.libraryDetailMeaning]}>
              {formatMeaningSupplement(word)}
            </Text>
          </View>
        )}

        {Boolean(formatExamplePrimary(word, studyMode)) && (
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
        )}
      </View>
    </View>
  );
}

const ProfileView = memo(function ProfileView({
  account,
  analytics,
  dailyPercent,
  onEmailChange,
  onAppleSignIn,
  onGoogleSignIn,
  onOpenFavorites,
  onOpenSettings,
  onOpenStats,
  onPasswordChange,
  onShowInstallGuide,
  onSignIn,
  onSignOut,
  onSignUp,
  progress,
  stats,
  studyMode,
  themeMode,
}: {
  account: AccountState;
  analytics: PersonalLearningAnalytics;
  dailyPercent: number;
  progress: ProgressState;
  stats: ReturnType<typeof computeStats>;
  studyMode: StudyMode;
  themeMode: ThemeMode;
  onEmailChange: (email: string) => void;
  onAppleSignIn: () => void;
  onGoogleSignIn: () => void;
  onOpenFavorites: () => void;
  onOpenSettings: () => void;
  onOpenStats: () => void;
  onPasswordChange: (password: string) => void;
  onShowInstallGuide: () => void;
  onSignIn: () => void;
  onSignOut: () => void;
  onSignUp: () => void;
}) {
  const themeStyles = useThemeStyles();
  const signedIn = Boolean(account.userId && !account.isAnonymous);
  const syncError = account.status === 'error';
  const palette = themeMode === 'dark' ? iosVisual.dark : iosVisual.light;
  const bodyIconColor = palette.label;
  const appleButtonForeground = themeMode === 'dark' ? '#000000' : '#FFFFFF';
  const ui = modeInterfaceCopy[studyMode];
  const showWebInstallGuidePanel = Platform.OS === 'web' && !IS_WEB_IOS_PREVIEW;
  const showAppleSignIn = Platform.OS === 'ios' || IS_WEB_IOS_PREVIEW;
  const signedInDisplayName = accountDisplayName(account.userName, account.userEmail, ui.appleAccountName);

  return (
    <View style={styles.screenStack}>
      <View style={[styles.profileCard, themeStyles?.profileCard]}>
        <View style={[styles.avatar, themeStyles?.avatar]}>
          <User size={32} color={bodyIconColor} strokeWidth={2.2} />
        </View>
        <Text
          adjustsFontSizeToFit
          minimumFontScale={0.7}
          numberOfLines={1}
          style={[styles.profileTitle, themeStyles?.profileTitle]}
        >
          {signedIn ? signedInDisplayName : ui.profileIdle}
        </Text>
        <Text style={[styles.profileText, themeStyles?.profileText]}>{ui.profileProgress(dailyPercent, stats.mastered)}</Text>
        <View style={[styles.syncPill, syncError && styles.syncPillError]}>
          <Cloud size={15} color={syncError ? palette.red : palette.green} strokeWidth={2.3} />
          <Text style={[styles.syncText, syncError && styles.syncTextError]}>{accountMessageForMode(account.message, studyMode)}</Text>
        </View>
      </View>

      <View style={[styles.accountCard, themeStyles?.accountCard]}>
        <View style={styles.rowBetween}>
          <Text style={[styles.sectionTitle, themeStyles?.sectionTitle]}>{ui.account}</Text>
          <Text style={[styles.cardMeta, themeStyles?.cardMeta]}>
            {account.configured ? (signedIn ? ui.signedIn : account.isAnonymous ? ui.guest : ui.signedOut) : ui.local}
          </Text>
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
                style={[styles.appleButton, themeStyles?.appleButton, (!account.configured || account.busy) && styles.disabledButton]}
              >
                <View style={[styles.appleIconMark, themeStyles?.appleIconMark]}>
                  <Smartphone size={18} color={appleButtonForeground} strokeWidth={2.4} />
                </View>
                <View style={styles.flexOne}>
                  <Text style={[styles.appleButtonTitle, themeStyles?.appleButtonTitle]}>{ui.appleSignIn}</Text>
                  <Text style={[styles.appleButtonText, themeStyles?.appleButtonText]}>{ui.appleSignInHint}</Text>
                </View>
                <ChevronRight size={18} color={appleButtonForeground} strokeWidth={2.4} />
              </AnimatedPressable>
            )}
            <Text style={[styles.emailFallbackLabel, themeStyles?.emailFallbackLabel]}>{ui.emailFallback}</Text>
            <View style={[styles.inputBox, themeStyles?.inputBox]}>
              <Mail size={17} color="#6C6C70" strokeWidth={2.2} />
              <TextInput
                autoCapitalize="none"
                editable={account.configured && !account.busy}
                keyboardType="email-address"
                onChangeText={onEmailChange}
                placeholder="Email"
                placeholderTextColor="#8E8E93"
                style={[styles.accountInput, themeStyles?.accountInput]}
                value={account.email}
              />
            </View>
            <View style={[styles.inputBox, themeStyles?.inputBox]}>
              <Lock size={17} color="#6C6C70" strokeWidth={2.2} />
              <TextInput
                editable={account.configured && !account.busy}
                onChangeText={onPasswordChange}
                placeholder={ui.passwordPlaceholder}
                placeholderTextColor="#8E8E93"
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
                <LogIn size={17} color="#FFFFFF" strokeWidth={2.4} />
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
            <LogOut size={17} color={palette.red} strokeWidth={2.4} />
            <Text style={styles.signOutButtonText}>{ui.signOut}</Text>
          </AnimatedPressable>
        )}
      </View>

      <AnimatedPressable
        accessibilityRole="button"
        onPress={onOpenStats}
        pressTone="list"
        style={[styles.settingsEntryButton, themeStyles?.settingsEntryButton]}
        testID="profile-learning-analytics"
      >
        <View style={[styles.settingsEntryIcon, themeStyles?.settingsEntryIcon]}>
          <ChartColumn size={21} color={palette.accent} strokeWidth={2.3} />
        </View>
        <View style={styles.flexOne}>
          <Text style={[styles.settingsEntryTitle, themeStyles?.settingsEntryTitle]}>{ui.learningAnalytics}</Text>
          <Text style={[styles.settingsEntryText, themeStyles?.settingsEntryText]}>
            {ui.analyticsPreview(analytics.activeDays7, analytics.quizAccuracy)}
          </Text>
        </View>
        <ChevronRight size={19} color={bodyIconColor} strokeWidth={2.4} />
      </AnimatedPressable>

      <ProfileLearningExperiencePanel
        dailyPercent={dailyPercent}
        progress={progress}
        signedIn={signedIn}
        stats={stats}
        studyMode={studyMode}
        onOpenFavorites={onOpenFavorites}
      />

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
        <ChevronRight size={18} color="#6C6C70" strokeWidth={2.3} />
      </AnimatedPressable>
    </View>
  );
});

function ProfileLearningExperiencePanel({
  dailyPercent,
  onOpenFavorites,
  progress,
  signedIn,
  studyMode,
  stats,
}: {
  dailyPercent: number;
  onOpenFavorites: () => void;
  progress: ProgressState;
  signedIn: boolean;
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
        <BookOpen size={21} color="#007AFF" strokeWidth={2.3} />
      </View>
      <View style={styles.learningMetricGrid}>
        <View style={[styles.learningMetric, themeStyles?.learningMetric]}>
          <Text style={[styles.learningMetricLabel, themeStyles?.learningMetricLabel]}>{ui.dailyTarget}</Text>
          <Text style={[styles.learningMetricValue, themeStyles?.learningMetricValue]}>{ui.wordsUnit(progress.dailyTarget)}</Text>
        </View>
        <AnimatedPressable
          accessibilityLabel={signedIn ? ui.favoriteWords : `${ui.favoriteWords}，${ui.favoritesRequireSignIn}`}
          accessibilityRole="button"
          hapticEnabled={signedIn}
          onPress={onOpenFavorites}
          pressTone="chip"
          style={[styles.learningMetric, themeStyles?.learningMetric]}
        >
          <Text style={[styles.learningMetricLabel, themeStyles?.learningMetricLabel]}>{ui.favoriteWords}</Text>
          {signedIn ? (
            <Text style={[styles.learningMetricValue, themeStyles?.learningMetricValue]}>{stats.favorites}</Text>
          ) : (
            <View style={styles.learningMetricLockedRow}>
              <Lock size={13} color="#6C6C70" strokeWidth={2.5} />
              <Text style={[styles.learningMetricLockedText, themeStyles?.learningMetricLabel]}>{ui.favoritesRequireSignIn}</Text>
            </View>
          )}
        </AnimatedPressable>
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
  const bodyIconColor = useContext(ThemeContext) === 'dark' ? '#F2F2F7' : '#1C1C1E';
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
      <ChevronRight size={18} color="#6C6C70" strokeWidth={2.3} />
    </AnimatedPressable>
  );
}

/**
 * The bank row doubles as the toolbar on study and quiz: the filters live
 * behind the small icon at its end, so the card gets the screen.
 */
function WordBankBar({
  count,
  filter,
  isScan,
  name,
  onPress,
  studyMode,
  testID,
}: {
  count: number;
  filter?: { active: boolean; open: boolean; testID: string; onPress: () => void };
  isScan: boolean;
  name: string;
  onPress: () => void;
  studyMode: StudyMode;
  testID: string;
}) {
  const themeStyles = useThemeStyles();
  const darkMode = useContext(ThemeContext) === 'dark';
  const ui = modeInterfaceCopy[studyMode];
  const accent = darkMode ? '#0A84FF' : '#007AFF';

  if (filter) {
    const highlighted = filter.active || filter.open;
    return (
      <View style={styles.wordBankToolbar}>
        <View style={styles.flexOne}>
          <WordBankBar count={count} isScan={isScan} name={name} studyMode={studyMode} testID={testID} onPress={onPress} />
        </View>
        <AnimatedPressable
          accessibilityLabel={ui.filterButtonLabel}
          accessibilityRole="button"
          accessibilityState={{ expanded: filter.open }}
          onPress={filter.onPress}
          pressTone="secondary"
          style={[styles.wordBankFilterButton, themeStyles?.wordBankBar, highlighted && { backgroundColor: accent }]}
          testID={filter.testID}
        >
          <AppIcon color={highlighted ? '#FFFFFF' : accent} name="filter" size={18} />
        </AnimatedPressable>
      </View>
    );
  }

  return (
    <AnimatedPressable
      accessibilityHint={ui.bankPickerHint}
      accessibilityLabel={`${ui.bankLabel} ${name}`}
      accessibilityRole="button"
      onPress={onPress}
      pressTone="list"
      style={[styles.wordBankBar, themeStyles?.wordBankBar]}
      testID={testID}
    >
      <View style={[styles.wordBankIcon, themeStyles?.wordBankIcon]}>
        <AppIcon color={accent} name={isScan ? 'scan' : 'bank'} size={16} />
      </View>
      <Text style={[styles.wordBankLabel, themeStyles?.cardMeta]}>{ui.bankLabel}</Text>
      <Text numberOfLines={1} style={[styles.wordBankName, themeStyles?.sectionTitle]}>{name}</Text>
      <Text style={[styles.wordBankCount, themeStyles?.cardMeta]}>{ui.bankWordCount(count)}</Text>
      <ChevronDown size={16} color={darkMode ? '#AEAEB2' : '#6C6C70'} strokeWidth={2.4} />
    </AnimatedPressable>
  );
}

function WordBankPickerSheet({
  activeBankId,
  canScan,
  coreCount,
  sets,
  studyMode,
  visible,
  onClose,
  onManage,
  onScan,
  onSelect,
}: {
  activeBankId: string;
  canScan: boolean;
  coreCount: number;
  sets: CustomVocabSet[];
  studyMode: StudyMode;
  visible: boolean;
  onClose: () => void;
  onManage: () => void;
  onScan: () => void;
  onSelect: (bankId: string) => void;
}) {
  const themeStyles = useThemeStyles();
  const darkMode = useContext(ThemeContext) === 'dark';
  const safeAreaInsets = useSafeAreaInsets();
  const ui = modeInterfaceCopy[studyMode];
  const accent = darkMode ? '#0A84FF' : '#007AFF';
  const bodyIconColor = darkMode ? '#F2F2F7' : '#1C1C1E';
  const banks = [
    { count: coreCount, id: CORE_BANK_ID, isScan: false, name: ui.coreBankName, tag: ui.builtInBank },
    ...sets.map((set) => {
      const isScan = set.wordIds.some(isScannedWordId);
      return { count: set.wordIds.length, id: set.id, isScan, name: set.name, tag: isScan ? ui.scanBankTag : '' };
    }),
  ];

  return (
    <Modal animationType="fade" onRequestClose={onClose} statusBarTranslucent transparent visible={visible}>
      <View style={styles.wordBankSheetRoot} testID="word-bank-picker">
        <Pressable accessibilityLabel={ui.closeSheet} onPress={onClose} style={[StyleSheet.absoluteFill, styles.wordBankSheetBackdrop]} />
        <View style={[styles.wordBankSheet, themeStyles?.wordBankSheet, { paddingBottom: Math.max(18, safeAreaInsets.bottom + 10) }]}>
          <View style={styles.homeDictionaryModalHandle} />
          <View style={styles.rowBetween}>
            <View style={styles.flexOne}>
              <Text style={[styles.customSetPickerTitle, themeStyles?.customSetPickerTitle]}>{ui.bankPickerTitle}</Text>
              <Text style={[styles.customSetPickerText, themeStyles?.customSetPickerText]}>{ui.bankPickerHint}</Text>
            </View>
            <AnimatedPressable accessibilityLabel={ui.closeSheet} accessibilityRole="button" onPress={onClose} pressTone="icon" style={[styles.iconButton, themeStyles?.iconButton]}>
              <X size={18} color={bodyIconColor} strokeWidth={2.5} />
            </AnimatedPressable>
          </View>
          <ScrollView style={styles.wordBankList} contentContainerStyle={styles.customSetPickerList}>
            {banks.map((bank) => {
              const selected = bank.id === activeBankId;
              return (
                <AnimatedPressable
                  accessibilityRole="radio"
                  accessibilityState={{ checked: selected }}
                  key={bank.id}
                  onPress={() => onSelect(bank.id)}
                  pressTone="list"
                  style={[styles.customSetPickerRow, themeStyles?.customSetPickerRow, selected && styles.wordBankRowActive]}
                  testID={`word-bank-option-${bank.id}`}
                >
                  <View style={[styles.wordBankIcon, themeStyles?.wordBankIcon]}>
                    {bank.id === CORE_BANK_ID ? (
                      <BookOpen size={17} color={accent} strokeWidth={2.3} />
                    ) : bank.isScan ? (
                      <ScanText size={17} color={accent} strokeWidth={2.3} />
                    ) : (
                      <Library size={17} color={accent} strokeWidth={2.3} />
                    )}
                  </View>
                  <View style={styles.flexOne}>
                    <Text numberOfLines={1} style={[styles.customSetRowTitle, themeStyles?.customSetRowTitle]}>{bank.name}</Text>
                    <Text style={[styles.customSetRowText, themeStyles?.customSetRowText]}>
                      {bank.tag ? `${bank.tag} · ` : ''}{ui.bankWordCount(bank.count)}
                    </Text>
                  </View>
                  <Check size={18} color={selected ? accent : 'transparent'} strokeWidth={2.6} />
                </AnimatedPressable>
              );
            })}
          </ScrollView>
          <View style={styles.wordBankActions}>
            <AnimatedPressable accessibilityRole="button" onPress={onScan} pressTone="primary" style={[styles.primaryButton, styles.flexOne]} testID="word-bank-scan">
              {canScan ? <ScanText size={18} color="#FFFFFF" strokeWidth={2.3} /> : <Lock size={16} color="#FFFFFF" strokeWidth={2.4} />}
              <Text style={styles.primaryButtonText}>{ui.scanNewSheet}</Text>
            </AnimatedPressable>
            <AnimatedPressable accessibilityRole="button" onPress={onManage} pressTone="secondary" style={[styles.secondaryButton, styles.wordBankManageButton, themeStyles?.secondaryButton]}>
              <Text numberOfLines={1} style={[styles.secondaryButtonText, themeStyles?.secondaryButtonText]}>{ui.manage}</Text>
            </AnimatedPressable>
          </View>
        </View>
      </View>
    </Modal>
  );
}

function AccountUpgradeOverlay({
  accountBusy,
  animation,
  onAppleSignIn,
  onDismiss,
  onGoogleSignIn,
  onShown,
  reason,
  studyMode,
  themeMode,
  visible,
}: {
  accountBusy: boolean;
  animation: Animated.Value;
  onAppleSignIn: () => void;
  onDismiss: () => void;
  onGoogleSignIn: () => void;
  onShown: () => void;
  reason: AccountUpgradeReason;
  studyMode: StudyMode;
  themeMode: ThemeMode;
  visible: boolean;
}) {
  const copy = accountUpgradeCopy[studyMode];
  const ui = modeInterfaceCopy[studyMode];
  const presentationStartedRef = useRef(false);
  const themeStyles = useThemeStyles();
  const darkMode = themeMode === 'dark';
  const foreground = darkMode ? iosVisual.dark.label : iosVisual.light.label;
  const showAppleSignIn = Platform.OS === 'ios' || IS_WEB_IOS_PREVIEW;
  const upgradeIconColor = reason === 'favorites' ? '#FF9500' : darkMode ? iosVisual.dark.accent : iosVisual.light.accent;
  const upgradeIcon = reason === 'favorites'
    ? <Star size={23} color={upgradeIconColor} fill="#FF9500" />
    : reason === 'customSets'
      ? <Library size={23} color={upgradeIconColor} strokeWidth={2.35} />
      : reason === 'dataTools'
        ? <Database size={23} color={upgradeIconColor} strokeWidth={2.35} />
        : <ShieldCheck size={23} color={upgradeIconColor} strokeWidth={2.35} />;
  const backdropMotion = {
    opacity: animation.interpolate({ inputRange: [0, 1], outputRange: [0, 1] }),
  };
  const panelMotion = {
    opacity: animation.interpolate({ inputRange: [0, 0.2, 1], outputRange: [0, 0.72, 1] }),
    transform: [
      {
        translateY: animation.interpolate({ inputRange: [0, 1], outputRange: [interactionMotion.accountPromptTranslateY, 0] }),
      },
      {
        scale: animation.interpolate({ inputRange: [0, 1], outputRange: [interactionMotion.accountPromptInitialScale, 1] }),
      },
    ],
  };

  const handleShown = useCallback(() => {
    if (presentationStartedRef.current) {
      return;
    }
    presentationStartedRef.current = true;
    onShown();
  }, [onShown]);

  useEffect(() => {
    if (!visible) {
      presentationStartedRef.current = false;
      return undefined;
    }
    if (Platform.OS !== 'web') {
      return undefined;
    }
    const frame = requestAnimationFrame(handleShown);
    return () => cancelAnimationFrame(frame);
  }, [handleShown, visible]);

  return (
    <Modal
      animationType="none"
      onRequestClose={onDismiss}
      onShow={handleShown}
      presentationStyle="overFullScreen"
      statusBarTranslucent
      transparent
      visible={visible}
    >
      <Animated.View style={[styles.accountUpgradeOverlay, themeStyles?.accountUpgradeOverlay, backdropMotion]}>
        <Pressable
          accessibilityLabel={copy.later}
          disabled={accountBusy}
          onPress={onDismiss}
          style={StyleSheet.absoluteFill}
        />
        <SafeAreaView pointerEvents="box-none" style={styles.accountUpgradeSafeArea}>
          <Animated.View style={[styles.accountUpgradePanel, themeStyles?.accountUpgradePanel, panelMotion]}>
            <View style={[styles.accountUpgradeHandle, themeStyles?.accountUpgradeHandle]} />
            <View style={styles.accountUpgradeHeader}>
              <View style={[
                styles.accountUpgradeIcon,
                themeStyles?.accountUpgradeIcon,
                reason === 'favorites' && styles.accountUpgradeFavoriteIcon,
                reason === 'favorites' && darkMode && styles.accountUpgradeFavoriteIconDark,
              ]}>
                {upgradeIcon}
              </View>
              <AnimatedPressable
                accessibilityLabel={copy.later}
                accessibilityRole="button"
                disabled={accountBusy}
                onPress={onDismiss}
                pressTone="icon"
                style={[styles.accountUpgradeClose, themeStyles?.accountUpgradeClose]}
              >
                <X size={19} color={foreground} strokeWidth={2.4} />
              </AnimatedPressable>
            </View>

            <Text style={[styles.accountUpgradeTitle, themeStyles?.accountUpgradeTitle]}>{copy.title[reason]}</Text>
            <Text style={[styles.accountUpgradeBody, themeStyles?.accountUpgradeBody]}>{copy.body[reason]}</Text>

            <View style={[styles.accountUpgradeMemoryPill, themeStyles?.accountUpgradeMemoryPill]}>
              <Cloud size={15} color={darkMode ? iosVisual.dark.green : iosVisual.light.green} strokeWidth={2.35} />
              <Text style={[styles.accountUpgradeMemoryText, themeStyles?.accountUpgradeMemoryText]}>{copy.badge[reason]}</Text>
            </View>

            <View style={styles.accountUpgradeActions}>
              {showAppleSignIn && (
                <AnimatedPressable
                  accessibilityLabel={ui.appleSignIn}
                  accessibilityRole="button"
                  disabled={accountBusy}
                  onPress={onAppleSignIn}
                  pressTone="primary"
                  style={[styles.accountUpgradeAppleButton, accountBusy && styles.disabledButton]}
                >
                  <Smartphone size={19} color="#FFFFFF" strokeWidth={2.4} />
                  <Text style={styles.accountUpgradeAppleText}>{ui.appleSignIn}</Text>
                </AnimatedPressable>
              )}
              <AnimatedPressable
                accessibilityLabel={ui.googleSignIn}
                accessibilityRole="button"
                disabled={accountBusy}
                onPress={onGoogleSignIn}
                pressTone="secondary"
                style={[styles.accountUpgradeGoogleButton, themeStyles?.accountUpgradeGoogleButton, accountBusy && styles.disabledButton]}
              >
                <LogIn size={19} color={foreground} strokeWidth={2.4} />
                <Text style={[styles.accountUpgradeGoogleText, themeStyles?.accountUpgradeGoogleText]}>{ui.googleSignIn}</Text>
              </AnimatedPressable>
            </View>

            <Text style={[styles.accountUpgradePrivacy, themeStyles?.accountUpgradePrivacy]}>{copy.privacy}</Text>
            <AnimatedPressable
              accessibilityRole="button"
              disabled={accountBusy}
              onPress={onDismiss}
              pressTone="secondary"
              style={styles.accountUpgradeLaterButton}
            >
              <Text style={[styles.accountUpgradeLaterText, themeStyles?.accountUpgradeLaterText]}>{copy.later}</Text>
            </AnimatedPressable>
          </Animated.View>
        </SafeAreaView>
      </Animated.View>
    </Modal>
  );
}

export function CustomSetPickerOverlay({
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
  const bodyIconColor = darkMode ? '#F2F2F7' : '#1C1C1E';
  const ui = modeInterfaceCopy[studyMode];
  const overlayAnim = useRef(new Animated.Value(0)).current;
  const overlayClosingRef = useRef(false);

  useEffect(() => {
    overlayClosingRef.current = false;
    overlayAnim.setValue(0);
    Animated.spring(overlayAnim, {
      damping: 24,
      mass: 0.72,
      overshootClamping: true,
      stiffness: 240,
      toValue: 1,
      useNativeDriver: Platform.OS !== 'web',
    }).start();
  }, [overlayAnim]);

  const dismissOverlay = useCallback((afterClose: () => void) => {
    if (overlayClosingRef.current) {
      return;
    }

    overlayClosingRef.current = true;
    Keyboard.dismiss();
    overlayAnim.stopAnimation();
    Animated.timing(overlayAnim, {
      duration: interactionMotion.settingsPanelExitMs,
      easing: Easing.inOut(Easing.cubic),
      toValue: 0,
      useNativeDriver: Platform.OS !== 'web',
    }).start(({ finished }) => {
      if (finished) {
        afterClose();
      } else {
        overlayClosingRef.current = false;
      }
    });
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
          <AnimatedPressable
            accessibilityLabel={studyMode === 'chinese' ? 'Close' : '關閉'}
            accessibilityRole="button"
            glassTone="icon"
            onPress={() => dismissOverlay(onClose)}
            pressTone="icon"
            style={styles.iconButton}
          >
            <X size={18} color={bodyIconColor} strokeWidth={2.5} />
          </AnimatedPressable>
        </View>

        <View style={styles.customSetCreateRow}>
          <View style={[styles.inputBox, themeStyles?.inputBox, styles.customSetNameInputBox]}>
            <TextInput
              onChangeText={onNewSetNameChange}
              placeholder={ui.newSetPlaceholder}
              placeholderTextColor="#8E8E93"
              style={[styles.accountInput, themeStyles?.accountInput]}
              value={newSetName}
            />
          </View>
          <AnimatedPressable
            accessibilityRole="button"
            onPress={() => dismissOverlay(onCreateAndAdd)}
            pressTone="primary"
            style={styles.customSetCreateButton}
          >
            <SquarePlus size={16} color="#FFFFFF" strokeWidth={2.4} />
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
              onPress={() => dismissOverlay(() => onAddToSet(set.id))}
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

export function ProfileCustomSetsView({
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
  const bodyIconColor = darkMode ? '#F2F2F7' : '#1C1C1E';
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
      Animated.spring(customSetPanelAnim, {
        damping: 24,
        mass: 0.72,
        overshootClamping: true,
        stiffness: 240,
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

      <Animated.View
        pointerEvents={customSetPanel === renderedCustomSetPanel ? 'auto' : 'none'}
        style={customSetPanelMotionStyle}
        testID="custom-set-panel-transition"
      >
      {renderedCustomSetPanel === 'list' && (
        <View style={styles.screenStack} testID="custom-set-list-panel">
          <View style={[styles.customSetsHeroCard, themeStyles?.customSetsHeroCard]}>
            <View style={styles.rowBetween}>
              <View style={styles.flexOne}>
                <Text style={[styles.sectionTitle, themeStyles?.sectionTitle]}>{ui.setLibrary}</Text>
                <Text style={[styles.cardMeta, themeStyles?.cardMeta]}>{ui.setLibrarySummary}</Text>
              </View>
              <Library size={21} color="#007AFF" strokeWidth={2.3} />
            </View>
            <View style={styles.customSetCreateRow}>
              <View style={[styles.inputBox, themeStyles?.inputBox, styles.customSetNameInputBox]}>
                <TextInput
                  onChangeText={onNewSetNameChange}
                  placeholder={ui.newSetPlaceholder}
                  placeholderTextColor="#8E8E93"
                  style={[styles.accountInput, themeStyles?.accountInput]}
                  value={newSetName}
                />
              </View>
              <AnimatedPressable accessibilityRole="button" onPress={onCreateCustomSet} pressTone="primary" style={styles.customSetWideCreateButton}>
                <SquarePlus size={16} color="#FFFFFF" strokeWidth={2.4} />
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
                  <Text adjustsFontSizeToFit minimumFontScale={0.86} numberOfLines={1} style={[styles.filterText, selected && styles.filterTextActive]}>{option.label}</Text>
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
                      <Check size={17} color={selected ? '#007AFF' : 'transparent'} strokeWidth={2.5} />
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
                      <Text adjustsFontSizeToFit minimumFontScale={0.82} numberOfLines={1} style={[styles.customSetActionText, themeStyles?.customSetActionText]}>{ui.startSetStudy}</Text>
                    </AnimatedPressable>
                    <AnimatedPressable accessibilityRole="button" onPress={() => onStartQuizSet(set.id)} pressTone="primary" style={styles.customSetPrimaryActionButton}>
                      <Target size={16} color="#FFFFFF" strokeWidth={2.3} />
                      <Text adjustsFontSizeToFit minimumFontScale={0.82} numberOfLines={1} style={styles.customSetPrimaryActionText}>{ui.startSetQuiz}</Text>
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
              <Settings size={21} color="#007AFF" strokeWidth={2.3} />
            </View>
            <View style={styles.customSetDetailActions} testID="custom-set-detail-actions">
              <AnimatedPressable accessibilityRole="button" onPress={() => onStartStudySet(selectedSet.id)} pressTone="secondary" style={[styles.customSetActionButton, themeStyles?.customSetActionButton]}>
                <BookOpen size={16} color={bodyIconColor} strokeWidth={2.3} />
                <Text adjustsFontSizeToFit minimumFontScale={0.82} numberOfLines={1} style={[styles.customSetActionText, themeStyles?.customSetActionText]}>{ui.startSetStudy}</Text>
              </AnimatedPressable>
              <AnimatedPressable accessibilityRole="button" onPress={() => onStartQuizSet(selectedSet.id)} pressTone="primary" style={styles.customSetPrimaryActionButton}>
                <Target size={16} color="#FFFFFF" strokeWidth={2.3} />
                <Text adjustsFontSizeToFit minimumFontScale={0.82} numberOfLines={1} style={styles.customSetPrimaryActionText}>{ui.startSetQuiz}</Text>
              </AnimatedPressable>
              <AnimatedPressable
                accessibilityRole="button"
                onPress={() => {
                  closeSetDetail();
                  onDeleteCustomSet(selectedSet.id);
                }}
                pressTone="secondary"
                style={[styles.customSetDeleteButton, themeStyles?.customSetDeleteButton]}
                testID="custom-set-delete-button"
              >
                <Trash2 size={15} color="#D70015" strokeWidth={2.3} />
                <Text adjustsFontSizeToFit minimumFontScale={0.84} numberOfLines={1} style={styles.customSetDeleteText}>{ui.deleteSet}</Text>
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
                  placeholderTextColor="#8E8E93"
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
                <Text adjustsFontSizeToFit minimumFontScale={0.82} numberOfLines={1} style={[styles.customSetActionText, themeStyles?.customSetActionText]}>{ui.saveSetName}</Text>
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
                    <X size={15} color="#D70015" strokeWidth={2.5} />
                    <Text adjustsFontSizeToFit minimumFontScale={0.84} numberOfLines={1} style={styles.customSetRemoveWordText}>{ui.removeFromSet}</Text>
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
                  placeholderTextColor="#8E8E93"
                  style={[styles.accountInput, themeStyles?.accountInput]}
                  value={manualCustomWord.word}
                />
              </View>
              <View style={[styles.inputBox, themeStyles?.inputBox]}>
                <TextInput
                  onChangeText={(value) => onManualCustomWordChange('meaningZh', value)}
                  placeholder={ui.customWordMeaningPlaceholder}
                  placeholderTextColor="#8E8E93"
                  style={[styles.accountInput, themeStyles?.accountInput]}
                  value={manualCustomWord.meaningZh}
                />
              </View>
              <View style={[styles.inputBox, themeStyles?.inputBox]}>
                <TextInput
                  onChangeText={(value) => onManualCustomWordChange('supplementalMeaningZh', value)}
                  placeholder={ui.customWordSupplementalMeaningPlaceholder}
                  placeholderTextColor="#8E8E93"
                  style={[styles.accountInput, themeStyles?.accountInput]}
                  value={manualCustomWord.supplementalMeaningZh}
                />
              </View>
              <View style={[styles.inputBox, themeStyles?.inputBox]}>
                <TextInput
                  onChangeText={(value) => onManualCustomWordChange('pronunciation', value)}
                  placeholder={ui.customWordPronunciationPlaceholder}
                  placeholderTextColor="#8E8E93"
                  style={[styles.accountInput, themeStyles?.accountInput]}
                  value={manualCustomWord.pronunciation}
                />
              </View>
              <View style={[styles.inputBox, themeStyles?.inputBox]}>
                <TextInput
                  onChangeText={(value) => onManualCustomWordChange('partOfSpeech', value)}
                  placeholder={ui.customWordPartPlaceholder}
                  placeholderTextColor="#8E8E93"
                  style={[styles.accountInput, themeStyles?.accountInput]}
                  value={manualCustomWord.partOfSpeech}
                />
              </View>
              <View style={[styles.inputBox, themeStyles?.inputBox, styles.customWordLongInput]}>
                <TextInput
                  onChangeText={(value) => onManualCustomWordChange('example', value)}
                  placeholder={ui.customWordExamplePlaceholder}
                  placeholderTextColor="#8E8E93"
                  style={[styles.accountInput, themeStyles?.accountInput]}
                  value={manualCustomWord.example}
                />
              </View>
              <View style={[styles.inputBox, themeStyles?.inputBox, styles.customWordLongInput]}>
                <TextInput
                  onChangeText={(value) => onManualCustomWordChange('exampleZh', value)}
                  placeholder={ui.customWordExampleZhPlaceholder}
                  placeholderTextColor="#8E8E93"
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
                <SquarePlus size={16} color="#FFFFFF" strokeWidth={2.3} />
                <Text adjustsFontSizeToFit minimumFontScale={0.82} numberOfLines={1} style={styles.developerPrimaryText}>{ui.addManualWord}</Text>
              </AnimatedPressable>
              <AnimatedPressable
                accessibilityRole="button"
                onPress={onImportCustomWords}
                pressTone="secondary"
                style={[styles.developerActionButton, themeStyles?.developerActionButton]}
              >
                <Upload size={16} color={bodyIconColor} strokeWidth={2.3} />
                <Text adjustsFontSizeToFit minimumFontScale={0.82} numberOfLines={1} style={[styles.developerActionText, themeStyles?.developerActionText]}>{ui.importCustomCsv}</Text>
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

export function ProfileSettingsView({
  accountBusy,
  accountReady,
  dailyTarget,
  developerMessage,
  developerVocabulary,
  onBack,
  onClearDeveloperVocabulary,
  onConfirmDeleteAccountData,
  onExportVocabulary,
  onImportVocabulary,
  onDailyTargetChange,
  onOpenAppInfoLink,
  onStreakReminderEnabledChange,
  onThemePreferenceChange,
  streakReminderEnabled,
  studyMode,
  themeMode,
  themePreference,
  vocabularyCount,
}: {
  accountBusy: boolean;
  accountReady: boolean;
  dailyTarget: number;
  developerMessage: string;
  developerVocabulary: DeveloperVocabularySnapshot | null;
  streakReminderEnabled: boolean;
  studyMode: StudyMode;
  themeMode: ThemeMode;
  themePreference: ThemePreference;
  vocabularyCount: number;
  onBack: () => void;
  onClearDeveloperVocabulary: () => void;
  onConfirmDeleteAccountData: () => void;
  onExportVocabulary: () => void;
  onImportVocabulary: () => void;
  onDailyTargetChange: (target: number) => void;
  onOpenAppInfoLink: (url: string) => void;
  onStreakReminderEnabledChange: (enabled: boolean) => void;
  onThemePreferenceChange: (preference: ThemePreference) => void;
}) {
  const themeStyles = useThemeStyles();
  const darkMode = themeMode === 'dark';
  const bodyIconColor = darkMode ? '#F2F2F7' : '#1C1C1E';
  const themeOptions: Array<{ id: ThemePreference; label: string }> = [
    { id: 'system', label: modeInterfaceCopy[studyMode].themeSystem },
    { id: 'light', label: modeInterfaceCopy[studyMode].themeLight },
    { id: 'dark', label: modeInterfaceCopy[studyMode].themeDark },
  ];
  const toggleStreakReminder = () => onStreakReminderEnabledChange(!streakReminderEnabled);
  const dangerIconColor = darkMode ? '#FF6961' : '#D70015';
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
          <Settings size={21} color="#007AFF" strokeWidth={2.3} />
        </View>

        <View style={[styles.settingOptionRow, styles.settingStackedRow, themeStyles?.settingOptionRow]} testID="daily-target-setting">
          <View style={styles.settingStackedHeader}>
            <View style={[styles.settingOptionIcon, themeStyles?.settingsEntryIcon]}>
              <Target size={19} color={darkMode ? '#0A84FF' : '#007AFF'} strokeWidth={2.3} />
            </View>
            <View style={styles.flexOne}>
              <Text style={[styles.settingsEntryTitle, themeStyles?.settingsEntryTitle]}>{ui.dailyTargetTitle}</Text>
              <Text style={[styles.settingsEntryText, themeStyles?.settingsEntryText]}>{ui.dailyTargetText}</Text>
            </View>
          </View>
          <View accessibilityRole="radiogroup" style={[styles.quizModeSwitch, themeStyles?.quizModeSwitch]}>
            {dailyTargetOptions.map((target) => {
              const selected = dailyTarget === target;
              return (
                <AnimatedPressable
                  accessibilityLabel={ui.dailyTargetOption(target)}
                  accessibilityRole="radio"
                  accessibilityState={{ checked: selected }}
                  key={target}
                  onPress={() => onDailyTargetChange(target)}
                  pressTone="chip"
                  style={[styles.quizModeButton, themeStyles?.quizModeButton, selected && styles.quizModeButtonActive]}
                >
                  <Text style={[styles.quizModeButtonText, themeStyles?.quizModeButtonText, selected && styles.quizModeButtonTextActive]}>
                    {target}
                  </Text>
                </AnimatedPressable>
              );
            })}
          </View>
        </View>

        <View style={[styles.settingOptionRow, styles.settingStackedRow, themeStyles?.settingOptionRow]} testID="appearance-setting">
          <View style={styles.settingStackedHeader}>
            <View style={[styles.settingOptionIcon, themeStyles?.settingsEntryIcon]}>
              {darkMode ? <Moon size={19} color="#FFD60A" strokeWidth={2.3} /> : <Sun size={19} color="#FF9500" strokeWidth={2.3} />}
            </View>
            <View style={styles.flexOne}>
              <Text style={[styles.settingsEntryTitle, themeStyles?.settingsEntryTitle]}>{ui.appearance}</Text>
              <Text style={[styles.settingsEntryText, themeStyles?.settingsEntryText]}>{ui.appearanceText}</Text>
            </View>
          </View>
          <View accessibilityRole="radiogroup" style={[styles.quizModeSwitch, themeStyles?.quizModeSwitch]}>
            {themeOptions.map((option) => {
              const selected = themePreference === option.id;
              return (
                <AnimatedPressable
                  accessibilityRole="radio"
                  accessibilityState={{ checked: selected }}
                  key={option.id}
                  onPress={() => onThemePreferenceChange(option.id)}
                  pressTone="chip"
                  style={[styles.quizModeButton, themeStyles?.quizModeButton, selected && styles.quizModeButtonActive]}
                  testID={`theme-option-${option.id}`}
                >
                  <Text style={[styles.quizModeButtonText, themeStyles?.quizModeButtonText, selected && styles.quizModeButtonTextActive]}>
                    {option.label}
                  </Text>
                </AnimatedPressable>
              );
            })}
          </View>
        </View>

        <AnimatedPressable
          accessibilityLabel={ui.toggleStreakReminder}
          accessibilityRole="switch"
          accessibilityState={{ checked: streakReminderEnabled }}
          onPress={toggleStreakReminder}
          pressTone="list"
          style={[styles.settingOptionRow, themeStyles?.settingOptionRow]}
          testID="streak-reminder-toggle"
        >
          <View style={[styles.settingOptionIcon, themeStyles?.settingsEntryIcon]}>
            <Flame size={20} color={streakReminderEnabled ? '#FF9F0A' : '#8E8E93'} strokeWidth={2.3} />
          </View>
          <View style={styles.flexOne}>
            <Text style={[styles.settingsEntryTitle, themeStyles?.settingsEntryTitle]}>{ui.streakReminder}</Text>
            <Text style={[styles.settingsEntryText, themeStyles?.settingsEntryText]}>
              {streakReminderEnabled ? ui.streakReminderOnText : ui.streakReminderOffText}
            </Text>
          </View>
          <View
            pointerEvents="none"
            style={[
              styles.themeStatusLight,
              streakReminderEnabled && styles.streakStatusLightActive,
            ]}
          >
            <View
              style={[
                styles.themeStatusLightCore,
                streakReminderEnabled && styles.streakStatusLightCoreActive,
              ]}
            />
          </View>
        </AnimatedPressable>
      </View>

      <View style={[styles.settingsCard, themeStyles?.settingsCard]}>
        <View style={styles.rowBetween}>
          <View>
            <Text style={[styles.sectionTitle, themeStyles?.sectionTitle]}>{ui.legalSupport}</Text>
            <Text style={[styles.cardMeta, themeStyles?.cardMeta]}>{ui.legalSupportSummary}</Text>
          </View>
          <Cloud size={21} color="#007AFF" strokeWidth={2.3} />
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
          <ChevronRight size={18} color="#6C6C70" strokeWidth={2.3} />
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
          <ChevronRight size={18} color="#6C6C70" strokeWidth={2.3} />
        </AnimatedPressable>

        <AnimatedPressable
          accessibilityRole="button"
          disabled={!accountReady || accountBusy}
          onPress={onConfirmDeleteAccountData}
          pressTone="secondary"
          style={[styles.deleteAccountDataButton, themeStyles?.deleteAccountDataButton, (!accountReady || accountBusy) && styles.disabledButton]}
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
  const bodyIconColor = useContext(ThemeContext) === 'dark' ? '#F2F2F7' : '#1C1C1E';
  const ui = modeInterfaceCopy[studyMode];

  return (
    <View style={[styles.developerCard, themeStyles?.developerCard]} testID="developer-vocabulary-panel">
      <View style={styles.rowBetween}>
        <View style={styles.flexOne}>
          <Text style={[styles.sectionTitle, themeStyles?.sectionTitle]}>{ui.developerPanel}</Text>
          <Text style={[styles.cardMeta, themeStyles?.cardMeta]}>{developerVocabulary ? ui.developerEnabled : ui.developerBuiltin}</Text>
        </View>
        <Database size={22} color="#007AFF" strokeWidth={2.3} />
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
          <Text adjustsFontSizeToFit minimumFontScale={0.82} numberOfLines={1} style={[styles.developerActionText, themeStyles?.developerActionText]}>{ui.exportCsv}</Text>
        </AnimatedPressable>
        <AnimatedPressable accessibilityRole="button" onPress={onImportVocabulary} pressTone="primary" style={styles.developerPrimaryButton}>
          <Upload size={16} color="#FFFFFF" strokeWidth={2.3} />
          <Text adjustsFontSizeToFit minimumFontScale={0.82} numberOfLines={1} style={styles.developerPrimaryText}>{ui.importData}</Text>
        </AnimatedPressable>
      </View>

      <AnimatedPressable
        accessibilityRole="button"
        disabled={!developerVocabulary}
        onPress={onClearDeveloperVocabulary}
        pressTone="secondary"
        style={[styles.developerClearButton, !developerVocabulary && styles.disabledButton]}
      >
        <Trash2 size={16} color="#A94400" strokeWidth={2.3} />
        <Text style={styles.developerClearText}>{ui.clearPreview}</Text>
      </AnimatedPressable>
    </View>
  );
}

function ProgressRing({
  children,
  color,
  percent,
  size,
  strokeWidth,
  trackColor,
}: {
  children: ReactNode;
  color: string;
  percent: number;
  size: number;
  strokeWidth: number;
  trackColor: string;
}) {
  const radius = (size - strokeWidth) / 2;
  const circumference = 2 * Math.PI * radius;
  const clamped = Math.max(0, Math.min(100, percent));

  return (
    <View accessibilityRole="progressbar" accessibilityValue={{ max: 100, min: 0, now: clamped }} style={{ alignItems: 'center', height: size, justifyContent: 'center', width: size }}>
      <Svg height={size} style={StyleSheet.absoluteFill} width={size}>
        <SvgCircle cx={size / 2} cy={size / 2} fill="none" r={radius} stroke={trackColor} strokeWidth={strokeWidth} />
        <SvgCircle
          cx={size / 2}
          cy={size / 2}
          fill="none"
          r={radius}
          rotation={-90}
          origin={`${size / 2}, ${size / 2}`}
          stroke={color}
          strokeDasharray={`${circumference} ${circumference}`}
          strokeDashoffset={circumference * (1 - clamped / 100)}
          strokeLinecap="round"
          strokeWidth={strokeWidth}
        />
      </Svg>
      <View style={styles.homeRingLabel}>{children}</View>
    </View>
  );
}

function StatCard({
  color,
  divider,
  emphasis,
  label,
  value,
}: {
  color?: string;
  divider?: boolean;
  emphasis?: boolean;
  label: string;
  value: string;
}) {
  const themeStyles = useThemeStyles();

  return (
    <View style={[styles.statCard, divider && styles.statCardDivider, themeStyles?.statCard, divider && themeStyles?.statCardDivider]}>
      <Text style={[styles.statValue, emphasis && styles.statValueEmphasis, themeStyles?.statValue, color ? { color } : null]}>{value}</Text>
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
    正在準備訪客進度: 'Preparing guest progress',
    訪客進度已自動保存: 'Guest progress saved automatically',
    訪客進度保存在這台裝置: 'Guest progress is saved on this device',
    已登入並同步: 'Signed in and synced',
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
    正在刪除帳號與資料: 'Deleting account and data',
    帳號學習資料已刪除: 'Account learning data deleted',
    無法開啟連結: 'Could not open link',
    建立帳號中: 'Creating account',
    請確認信箱後登入: 'Check your email, then sign in',
    'Email 和密碼至少 6 碼': 'Email and password need at least 6 characters',
    '請輸入 Email 和密碼': 'Enter email and password',
    登入中: 'Signing in',
    登入失敗: 'Sign-in failed',
    已登出: 'Signed out',
    正在切換為訪客模式: 'Switching to guest mode',
    '已登出，訪客進度保存在這台裝置': 'Signed out. Guest progress is saved on this device',
    '帳號已刪除，正在建立訪客進度': 'Account deleted. Preparing guest progress',
    '帳號已刪除，訪客進度保存在這台裝置': 'Account deleted. Guest progress is saved on this device',
  };
  return messages[message] ?? message;
}

const styles = StyleSheet.create({
  safeArea: {
    flex: 1,
    backgroundColor: '#F2F2F7',
  },
  webIosPreviewSafeArea: {
    alignItems: 'center',
    backgroundColor: '#000000',
    justifyContent: 'center',
    paddingHorizontal: 16,
    paddingVertical: 18,
  },
  appStorageBootScreen: {
    alignItems: 'center',
    backgroundColor: '#F2F2F7',
    flex: 1,
    gap: 12,
    justifyContent: 'center',
    padding: 28,
  },
  appStorageBootTitle: {
    color: '#1C1C1E',
    fontSize: 28,
    fontWeight: '700',
    marginTop: 6,
  },
  appStorageBootText: {
    color: '#6C6C70',
    fontSize: 15,
    fontWeight: '500',
    textAlign: 'center',
  },
  appShell: {
    alignSelf: 'center',
    backgroundColor: '#F2F2F7',
    flex: 1,
    maxWidth: 760,
    width: '100%',
  },
  webIosPreviewAppShell: {
    borderColor: '#3A3A3C',
    borderRadius: 30,
    borderCurve: 'continuous',
    borderWidth: 0,
    maxHeight: 852,
    maxWidth: 393,
    overflow: 'hidden',
    shadowColor: '#000000',
    shadowOffset: { height: 20, width: 0 },
    shadowOpacity: 0.26,
    shadowRadius: 34,
  },
  appScroll: {
    flex: 1,
    overflow: 'hidden',
  },
  webIosPreviewScroll: {
    marginBottom: WEB_IOS_PREVIEW_SCROLL_BOTTOM_INSET,
  },
  header: {
    alignItems: 'center',
    flexDirection: 'row',
    justifyContent: 'space-between',
    paddingHorizontal: 18,
    paddingTop: 10,
    paddingBottom: 10,
  },
  headerActions: {
    alignItems: 'flex-end',
    gap: 6,
  },
  brand: {
    color: '#1C1C1E',
    fontSize: 34,
    fontWeight: '700',
    lineHeight: 41,
  },
  headerSubtext: {
    color: '#6C6C70',
    fontSize: 13,
    marginTop: 3,
  },
  levelPill: {
    alignItems: 'center',
    backgroundColor: '#EAF9EE',
    borderColor: '#B7E9C2',
    borderRadius: 999,
    borderWidth: 0,
    flexDirection: 'row',
    gap: 6,
    paddingHorizontal: 10,
    paddingVertical: 8,
  },
  levelText: {
    color: '#248A3D',
    fontSize: 13,
    fontWeight: '500',
  },
  previewModePill: {
    alignItems: 'center',
    backgroundColor: '#EAF4FF',
    borderColor: '#B9DCFF',
    borderRadius: 999,
    borderWidth: 0,
    flexDirection: 'row',
    gap: 5,
    paddingHorizontal: 8,
    paddingVertical: 6,
  },
  previewModeText: {
    color: '#0066CC',
    fontSize: 12,
    fontWeight: '600',
  },
  updateRequiredOverlay: {
    alignItems: 'center',
    backgroundColor: 'rgba(28, 28, 30, 0.78)',
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
    backgroundColor: '#FFFFFF',
    borderColor: '#B9DCFF',
    borderRadius: 20,
    borderCurve: 'continuous',
    borderWidth: 0,
    maxWidth: 420,
    paddingHorizontal: 22,
    paddingVertical: 24,
    shadowColor: '#1C1C1E',
    shadowOffset: { height: 18, width: 0 },
    shadowOpacity: 0.2,
    shadowRadius: 30,
    width: '100%',
  },
  updateRequiredIcon: {
    alignItems: 'center',
    backgroundColor: '#EAF4FF',
    borderColor: '#B9DCFF',
    borderRadius: 11,
    borderCurve: 'continuous',
    borderWidth: 0,
    height: 58,
    justifyContent: 'center',
    width: 58,
  },
  updateRequiredTitle: {
    fontFamily: ROUNDED_FONT,
    color: '#1C1C1E',
    fontSize: 22,
    fontWeight: '700',
    marginTop: 16,
    textAlign: 'center',
  },
  updateRequiredText: {
    color: '#6C6C70',
    fontSize: 15,
    fontWeight: '500',
    lineHeight: 23,
    marginTop: 10,
    textAlign: 'center',
  },
  updateRequiredCountdown: {
    color: '#0066CC',
    fontSize: 15,
    fontWeight: '700',
    marginTop: 16,
  },
  updateRequiredButton: {
    alignItems: 'center',
    backgroundColor: '#007AFF',
    borderRadius: 12,
    borderCurve: 'continuous',
    flexDirection: 'row',
    gap: 8,
    justifyContent: 'center',
    marginTop: 16,
    minHeight: 48,
    paddingHorizontal: 18,
    width: '100%',
  },
  updateRequiredButtonText: {
    color: '#FFFFFF',
    fontSize: 15,
    fontWeight: '700',
  },
  content: {
    padding: 18,
    paddingBottom: CONTENT_BOTTOM_PADDING,
  },
  screenMotion: {
    gap: 14,
  },
  libraryScreenHost: {
    flex: 1,
    minHeight: 0,
  },
  libraryListStage: {
    flex: 1,
    minHeight: 0,
  },
  libraryFlashList: {
    flex: 1,
  },
  libraryListContent: {
    paddingBottom: CONTENT_BOTTOM_PADDING,
    paddingHorizontal: 18,
    paddingTop: 18,
  },
  libraryListHeader: {
    paddingBottom: 10,
  },
  libraryItemSeparator: {
    height: 10,
  },
  appStorageBootButton: {
    alignItems: 'center',
    backgroundColor: '#007AFF',
    borderRadius: 10,
    justifyContent: 'center',
    marginTop: 8,
    minHeight: 48,
    paddingHorizontal: 20,
  },
  appStorageBootButtonText: {
    color: '#FFFFFF',
    fontSize: 15,
    fontWeight: '700',
  },
  launchIcon: {
    borderColor: '#B9DCFF',
    borderRadius: 20,
    borderCurve: 'continuous',
    borderWidth: 0,
    shadowColor: '#1C1C1E',
    shadowOffset: { height: 14, width: 0 },
    shadowOpacity: 0.2,
    shadowRadius: 24,
  },
  installGuideOverlay: {
    backgroundColor: '#f2f2f7',
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
    borderColor: '#B9DCFF',
    borderRadius: 11,
    borderCurve: 'continuous',
    borderWidth: 0,
  },
  installGuideClose: {
    alignItems: 'center',
    backgroundColor: 'rgba(120, 120, 128, 0.12)',
    borderColor: '#E5E5EA',
    borderRadius: 11,
    borderCurve: 'continuous',
    borderWidth: 0,
    height: 42,
    justifyContent: 'center',
    width: 42,
  },
  installGuideCard: {
    alignItems: 'center',
    backgroundColor: '#FFFFFF',
    borderColor: '#D6E9FF',
    borderRadius: 20,
    borderCurve: 'continuous',
    borderWidth: 0,
    gap: 12,
    padding: 20,
    shadowColor: '#1C1C1E',
    shadowOffset: { height: 12, width: 0 },
    shadowOpacity: 0.08,
    shadowRadius: 22,
  },
  installGuideStepPill: {
    backgroundColor: '#EAF4FF',
    borderColor: '#B9DCFF',
    borderRadius: 999,
    borderWidth: 0,
    paddingHorizontal: 10,
    paddingVertical: 6,
  },
  installGuideStepText: {
    color: '#0066CC',
    fontSize: 12,
    fontWeight: '600',
  },
  installGuideIconWrap: {
    alignItems: 'center',
    backgroundColor: '#EAF4FF',
    borderColor: '#B9DCFF',
    borderRadius: 20,
    borderCurve: 'continuous',
    borderWidth: 0,
    height: 108,
    justifyContent: 'center',
    marginTop: 4,
    overflow: 'hidden',
    width: 108,
  },
  installGuideIconGlow: {
    backgroundColor: '#D6E9FF',
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
    fontFamily: ROUNDED_FONT,
    color: '#1C1C1E',
    fontSize: 28,
    fontWeight: '700',
    lineHeight: 35,
    marginTop: 4,
    textAlign: 'center',
  },
  installGuideText: {
    color: '#6C6C70',
    fontSize: 15,
    lineHeight: 23,
    textAlign: 'center',
  },
  installGuidePreview: {
    alignSelf: 'stretch',
    backgroundColor: '#F7FAFF',
    borderColor: '#D6E9FF',
    borderRadius: 14,
    borderCurve: 'continuous',
    borderWidth: 0,
    marginTop: 4,
    padding: 12,
  },
  installGuideBrowserBar: {
    alignSelf: 'center',
    backgroundColor: '#D1D1D6',
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
    backgroundColor: '#FFFFFF',
    borderColor: '#E5E5EA',
    borderRadius: 11,
    borderCurve: 'continuous',
    borderWidth: 0,
    height: 34,
    justifyContent: 'center',
    width: 34,
  },
  installGuideMiniStepActive: {
    backgroundColor: '#007AFF',
    borderColor: '#007AFF',
  },
  installGuideStepProgress: {
    shadowColor: '#007AFF',
    shadowOffset: { height: 3, width: 0 },
    shadowOpacity: 0.16,
    shadowRadius: 7,
    transform: [{ scale: 1.08 }],
  },
  installGuideMiniText: {
    color: '#6C6C70',
    fontSize: 13,
    fontWeight: '600',
  },
  installGuideMiniTextActive: {
    color: '#FFFFFF',
  },
  installGuideDots: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: 7,
    justifyContent: 'center',
  },
  installGuideDot: {
    backgroundColor: '#D1D1D6',
    borderRadius: 99,
    height: 7,
    width: 7,
  },
  installGuideDotActive: {
    backgroundColor: '#007AFF',
    width: 22,
  },
  installGuideActions: {
    flexDirection: 'row',
    gap: 10,
  },
  installGuideSecondary: {
    alignItems: 'center',
    backgroundColor: 'rgba(120, 120, 128, 0.12)',
    borderColor: '#D1D1D6',
    borderRadius: 12,
    borderCurve: 'continuous',
    borderWidth: 0,
    flex: 1,
    justifyContent: 'center',
    minHeight: 50,
    paddingHorizontal: 12,
  },
  installGuideSecondaryText: {
    color: '#1C1C1E',
    fontSize: 15,
    fontWeight: '700',
    textAlign: 'center',
  },
  installGuidePrimary: {
    alignItems: 'center',
    backgroundColor: '#1C1C1E',
    borderRadius: 12,
    borderCurve: 'continuous',
    flex: 1,
    flexDirection: 'row',
    gap: 6,
    justifyContent: 'center',
    minHeight: 50,
    paddingHorizontal: 12,
  },
  installGuidePrimaryText: {
    color: '#FFFFFF',
    fontSize: 15,
    fontWeight: '700',
  },
  modeSwitchBackdrop: {
    alignItems: 'center',
    backgroundColor: '#D6E9FF',
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
    backgroundColor: '#EAF4FF',
    borderColor: '#B9DCFF',
    borderRadius: 20,
    borderCurve: 'continuous',
    borderWidth: 0,
    elevation: 8,
    gap: 8,
    maxWidth: 420,
    padding: 24,
    shadowColor: '#1C1C1E',
    shadowOffset: { height: 10, width: 0 },
    shadowOpacity: 0.16,
    shadowRadius: 22,
    width: '100%',
  },
  modeSwitchPanelChinese: {
    backgroundColor: '#F0EFFF',
    borderColor: '#C9C7FF',
  },
  modeSwitchOverlayChinese: {
    backgroundColor: '#F0EFFF',
  },
  modeSwitchOverlayIcon: {
    alignItems: 'center',
    backgroundColor: '#FFFFFF',
    borderColor: '#B9DCFF',
    borderRadius: 20,
    borderCurve: 'continuous',
    borderWidth: 0,
    height: 70,
    justifyContent: 'center',
    width: 70,
  },
  modeSwitchOverlayIconChinese: {
    borderColor: '#C9C7FF',
  },
  modeSwitchOverlayTitle: {
    color: '#1C1C1E',
    fontSize: 22,
    fontWeight: '700',
  },
  modeSwitchOverlayText: {
    color: '#6C6C70',
    fontSize: 15,
    fontWeight: '600',
    textAlign: 'center',
  },
  screenStack: {
    gap: 14,
  },
  homeStack: {
    gap: 14,
  },
  hero: {
    backgroundColor: '#FFFFFF',
    borderColor: '#D1D1D6',
    borderRadius: 20,
    borderCurve: 'continuous',
    borderWidth: 0,
    gap: 14,
    padding: 16,
  },
  heroCopy: {
    flex: 1,
  },
  eyebrow: {
    color: '#6C6C70',
    fontSize: 12,
    fontWeight: '700',
    marginBottom: 8,
  },
  heroTitle: {
    fontFamily: ROUNDED_FONT,
    color: '#1C1C1E',
    fontSize: 30,
    fontWeight: '700',
    lineHeight: 36,
  },
  modeSwitchButton: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: 12,
    minHeight: 54,
    paddingHorizontal: 14,
    paddingVertical: 10,
  },
  modeSwitchButtonChinese: {
    backgroundColor: '#F0EFFF',
    borderColor: '#C9C7FF',
  },
  modeSwitchIcon: {
    alignItems: 'center',
    backgroundColor: '#EAF4FF',
    borderRadius: 8,
    borderCurve: 'continuous',
    height: 32,
    justifyContent: 'center',
    width: 32,
  },
  modeSwitchIconChinese: {
    backgroundColor: '#F0EFFF',
  },
  modeSwitchTitle: {
    fontFamily: ROUNDED_FONT,
    color: '#1C1C1E',
    fontSize: 17,
    fontWeight: '700',
  },
  modeSwitchText: {
    color: '#6C6C70',
    fontSize: 12,
    fontWeight: '500',
    lineHeight: 17,
    marginTop: 3,
  },
  progressCard: {
    backgroundColor: '#FFFFFF',
    borderColor: '#E5E5EA',
    borderRadius: 18,
    borderCurve: 'continuous',
    borderWidth: 0,
    gap: 12,
    padding: 15,
  },
  homeProgressHeader: {
    alignItems: 'center',
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginTop: 2,
  },
  rowBetween: {
    alignItems: 'center',
    flexDirection: 'row',
    justifyContent: 'space-between',
  },
  sectionTitle: {
    fontFamily: ROUNDED_FONT,
    color: '#1C1C1E',
    fontSize: 17,
    fontWeight: '600',
  },
  cardMeta: {
    color: '#6C6C70',
    fontSize: 13,
    fontWeight: '500',
  },
  progressTrack: {
    backgroundColor: '#DCEEFF',
    borderRadius: 999,
    height: 6,
    overflow: 'hidden',
  },
  progressFill: {
    backgroundColor: '#007AFF',
    borderRadius: 999,
    height: '100%',
  },
  primaryButton: {
    alignItems: 'center',
    backgroundColor: '#007AFF',
    borderRadius: 12,
    borderCurve: 'continuous',
    flexDirection: 'row',
    gap: 8,
    justifyContent: 'center',
    minHeight: 48,
    paddingHorizontal: 16,
  },
  nativeGlassButton: {
    backgroundColor: 'transparent',
    overflow: 'hidden',
  },
  nativeGlassFeedback: {
    bottom: 0,
    left: 0,
    position: 'absolute',
    right: 0,
    top: 0,
  },
  nativeGlassFeedbackLight: {
    backgroundColor: '#007AFF',
  },
  nativeGlassFeedbackDark: {
    backgroundColor: '#FFFFFF',
  },
  primaryButtonText: {
    color: '#FFFFFF',
    fontSize: 15,
    fontWeight: '600',
  },
  accountShortcut: {
    alignItems: 'center',
    backgroundColor: '#F7FAFF',
    borderColor: '#D6E9FF',
    borderRadius: 12,
    borderCurve: 'continuous',
    borderWidth: 0,
    flexDirection: 'row',
    gap: 7,
    justifyContent: 'center',
    minHeight: 42,
    paddingHorizontal: 12,
  },
  accountShortcutText: {
    color: '#1C1C1E',
    fontSize: 15,
    fontWeight: '600',
  },
  homeUpdateButton: {
    alignItems: 'center',
    backgroundColor: '#F7FAFF',
    borderColor: '#B9DCFF',
    borderCurve: 'continuous',
    borderRadius: 20,
    borderWidth: 0,
    flexDirection: 'row',
    gap: 11,
    minHeight: 66,
    overflow: 'hidden',
    paddingHorizontal: 11,
    paddingVertical: 10,
  },
  homeUpdateIcon: {
    alignItems: 'center',
    backgroundColor: '#EAF4FF',
    borderCurve: 'continuous',
    borderRadius: 11,
    height: 42,
    justifyContent: 'center',
    width: 42,
  },
  homeUpdateTitle: {
    fontFamily: ROUNDED_FONT,
    color: '#1C1C1E',
    fontSize: 15,
    fontWeight: '700',
  },
  homeUpdateText: {
    color: '#6C6C70',
    fontSize: 12,
    lineHeight: 17,
    marginTop: 2,
  },
  homeUpdateAction: {
    alignItems: 'center',
    backgroundColor: '#007AFF',
    borderCurve: 'continuous',
    borderRadius: 10,
    flexDirection: 'row',
    gap: 5,
    justifyContent: 'center',
    maxWidth: 112,
    minHeight: 34,
    minWidth: 86,
    paddingHorizontal: 9,
  },
  homeUpdateActionCurrent: {
    backgroundColor: '#248A3D',
  },
  homeUpdateActionAvailable: {
    backgroundColor: '#FF9500',
  },
  homeUpdateActionError: {
    backgroundColor: '#D70015',
  },
  homeUpdateActionText: {
    color: '#FFFFFF',
    flexShrink: 1,
    fontSize: 11,
    fontWeight: '700',
    textAlign: 'center',
  },
  homeDictionaryStandalone: {
    alignItems: 'center',
    backgroundColor: '#EAF4FF',
    borderColor: '#B9DCFF',
    borderRadius: 20,
    borderCurve: 'continuous',
    borderWidth: 0,
    flexDirection: 'row',
    gap: 10,
    minHeight: 60,
    paddingHorizontal: 10,
  },
  homeDictionaryLauncherIcon: {
    alignItems: 'center',
    backgroundColor: '#FFFFFF',
    borderRadius: 11,
    borderCurve: 'continuous',
    height: 42,
    justifyContent: 'center',
    width: 42,
  },
  homeDictionarySearch: {
    alignItems: 'center',
    backgroundColor: '#F7FAFF',
    borderColor: '#B9DCFF',
    borderRadius: 14,
    borderCurve: 'continuous',
    borderWidth: 0,
    flexDirection: 'row',
    gap: 10,
    minHeight: 58,
    paddingLeft: 14,
    paddingRight: 7,
  },
  homeDictionaryInput: {
    color: '#1C1C1E',
    flex: 1,
    fontSize: 15,
    minHeight: 48,
    paddingVertical: 0,
  },
  homeDictionaryLauncherText: {
    color: '#0066CC',
    flex: 1,
    fontSize: 15,
    fontWeight: '600',
  },
  homeDictionaryModalRoot: {
    flex: 1,
  },
  homeDictionaryModalRootNative: {
    backgroundColor: '#F2F2F7',
  },
  homeDictionaryBackdrop: {
    backgroundColor: 'rgba(28, 28, 30, 0.52)',
    bottom: 0,
    left: 0,
    position: 'absolute',
    right: 0,
    top: 0,
  },
  homeDictionaryKeyboardLayer: {
    flex: 1,
    justifyContent: 'flex-end',
  },
  homeDictionaryModalSheet: {
    alignSelf: 'center',
    backgroundColor: '#FFFFFF',
    borderColor: '#D1D1D6',
    borderTopLeftRadius: 8,
    borderTopRightRadius: 8,
    borderWidth: 0,
    elevation: 18,
    height: '82%',
    maxWidth: 640,
    overflow: 'hidden',
    shadowColor: '#000000',
    shadowOffset: { height: -10, width: 0 },
    shadowOpacity: 0.18,
    shadowRadius: 26,
    width: '100%',
  },
  homeDictionaryModalSheetNative: {
    backgroundColor: '#F6F9FC',
    borderTopLeftRadius: 0,
    borderTopRightRadius: 0,
    borderWidth: 0,
    elevation: 0,
    flex: 1,
    height: '100%',
    maxWidth: '100%',
    shadowOpacity: 0,
  },
  homeDictionaryModalHandle: {
    alignSelf: 'center',
    backgroundColor: '#D1D1D6',
    borderRadius: 999,
    height: 4,
    marginBottom: 8,
    marginTop: 8,
    width: 38,
  },
  homeDictionaryModalHeader: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: 12,
    paddingHorizontal: 18,
    paddingVertical: 8,
  },
  homeDictionaryModalHeaderNative: {
    paddingBottom: 10,
    paddingHorizontal: 22,
    paddingTop: 18,
  },
  homeDictionaryModalTitle: {
    color: '#1C1C1E',
    fontSize: 20,
    fontWeight: '700',
    lineHeight: 26,
  },
  homeDictionaryModalMeta: {
    color: '#6C6C70',
    fontSize: 12,
    fontWeight: '500',
    lineHeight: 18,
    marginTop: 3,
  },
  homeDictionaryModalSearch: {
    alignItems: 'center',
    backgroundColor: '#F7FAFF',
    borderColor: '#0A84FF',
    borderRadius: 14,
    borderCurve: 'continuous',
    borderWidth: 1,
    flexDirection: 'row',
    gap: 10,
    marginHorizontal: 18,
    marginTop: 4,
    minHeight: 54,
    paddingHorizontal: 14,
  },
  homeDictionaryModalSearchNative: {
    marginHorizontal: 22,
    marginTop: 2,
  },
  homeDictionaryModalInput: {
    color: '#1C1C1E',
    flex: 1,
    fontSize: 17,
    minHeight: 50,
    paddingVertical: 0,
  },
  homeDictionaryClearButton: {
    alignItems: 'center',
    borderRadius: 19,
    borderCurve: 'continuous',
    height: 38,
    justifyContent: 'center',
    width: 38,
  },
  homeDictionaryResults: {
    flex: 1,
    marginTop: 10,
  },
  homeDictionaryResultsContent: {
    flexGrow: 1,
    paddingHorizontal: 18,
    paddingBottom: 18,
  },
  homeDictionaryEmptyState: {
    alignItems: 'center',
    flex: 1,
    gap: 10,
    justifyContent: 'center',
    minHeight: 180,
    padding: 24,
  },
  homeDictionaryEmptyText: {
    color: '#6C6C70',
    fontSize: 15,
    fontWeight: '500',
    lineHeight: 21,
    textAlign: 'center',
  },
  homeDictionaryResultRow: {
    alignItems: 'center',
    borderBottomColor: '#E5E5EA',
    borderBottomWidth: 1,
    flexDirection: 'row',
    gap: 12,
    minHeight: 104,
    paddingHorizontal: 2,
    paddingVertical: 14,
  },
  homeDictionaryResultTitleRow: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: 8,
  },
  homeDictionaryResultTitle: {
    color: '#1C1C1E',
    flexShrink: 1,
    fontSize: 20,
    fontWeight: '700',
  },
  homeDictionaryResultPinyin: {
    color: '#6C6C70',
    fontSize: 13,
    fontWeight: '500',
    marginTop: 3,
  },
  homeDictionaryResultMeaning: {
    color: '#3A3A3C',
    fontSize: 15,
    fontWeight: '500',
    lineHeight: 21,
    marginTop: 5,
  },
  homeDictionaryResultExample: {
    color: '#6C6C70',
    fontSize: 13,
    lineHeight: 19,
    marginTop: 4,
  },
  statsGrid: {
    backgroundColor: '#FFFFFF',
    borderColor: '#D1D1D6',
    borderRadius: 20,
    borderCurve: 'continuous',
    borderWidth: 0,
    flexDirection: 'row',
    minHeight: 82,
    overflow: 'hidden',
  },
  statCard: {
    alignItems: 'center',
    flex: 1,
    justifyContent: 'center',
    paddingHorizontal: 8,
    paddingVertical: 13,
  },
  statCardDivider: {
    borderLeftColor: '#E5E5EA',
    borderLeftWidth: StyleSheet.hairlineWidth,
  },
  blueTint: {
    backgroundColor: '#EAF4FF',
    borderColor: '#B9DCFF',
    borderWidth: 0,
  },
  greenTint: {
    backgroundColor: '#EAF9EE',
    borderColor: '#B7E9C2',
    borderWidth: 0,
  },
  orangeTint: {
    backgroundColor: '#FFF4E5',
    borderColor: '#FFD7A8',
    borderWidth: 0,
  },
  statValue: {
    fontFamily: ROUNDED_FONT,
    color: '#1C1C1E',
    fontSize: 22,
    fontWeight: '700',
  },
  statValueEmphasis: {
    color: '#FF9500',
  },
  statLabel: {
    color: '#6C6C70',
    fontSize: 12,
    marginTop: 4,
    textAlign: 'center',
  },
  homeActionGroup: {
    backgroundColor: '#FFFFFF',
    borderColor: '#D1D1D6',
    borderRadius: 20,
    borderCurve: 'continuous',
    borderWidth: 0,
    overflow: 'hidden',
  },
  homeActionDivider: {
    backgroundColor: '#E5E5EA',
    height: StyleSheet.hairlineWidth,
    marginLeft: 70,
  },
  reviewStrip: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: 12,
    minHeight: 54,
    paddingHorizontal: 14,
    paddingVertical: 10,
  },
  reviewIcon: {
    alignItems: 'center',
    backgroundColor: '#FFF4E5',
    borderRadius: 8,
    borderCurve: 'continuous',
    height: 32,
    justifyContent: 'center',
    width: 32,
  },
  reviewTitle: {
    fontFamily: ROUNDED_FONT,
    color: '#1C1C1E',
    fontSize: 15,
    fontWeight: '600',
  },
  reviewText: {
    color: '#6C6C70',
    fontSize: 13,
    marginTop: 3,
  },
  flexOne: {
    flex: 1,
  },
  wordCard: {
    backgroundColor: '#FFFFFF',
    borderColor: '#D1D1D6',
    borderRadius: 24,
    borderCurve: 'continuous',
    borderWidth: 0,
    gap: 14,
    overflow: 'hidden',
    padding: 18,
  },
  studySwipeDeck: {
    borderRadius: 18,
    borderCurve: 'continuous',
    overflow: 'visible',
    position: 'relative',
  },
  studySwipeSwapStage: {
    position: 'relative',
  },
  studySwipeSlidingCard: {
    position: 'relative',
    zIndex: 2,
  },
  studySwipeDeckUnderlay: {
    // Deliberately no `bottom`: anchoring both edges made the underlay adopt
    // the stage's height, which the *live* card sets. A taller word would ride
    // up compressed and then unfold once it took over. Anchoring only the top
    // lets it size to its own content, so what floats up is the same shape it
    // will be when it becomes the live card.
    left: 0,
    position: 'absolute',
    right: 0,
    top: 0,
    zIndex: 0,
  },
  studySwipeRevealFill: {
    alignItems: 'center',
    borderCurve: 'continuous',
    borderRadius: 18,
    bottom: 0,
    justifyContent: 'center',
    left: 0,
    opacity: 0,
    overflow: 'hidden',
    position: 'absolute',
    right: 0,
    top: 0,
    zIndex: 1,
  },
  studySwipeRevealReview: {
    backgroundColor: 'rgba(255, 59, 48, 0.05)',
    right: 0,
  },
  studySwipeRevealKnown: {
    backgroundColor: 'rgba(52, 199, 89, 0.055)',
    left: 0,
  },
  studySwipeRevealGradientWrap: {
    bottom: 0,
    position: 'absolute',
    top: 0,
    width: STUDY_SWIPE_REVEAL_WIDTH,
    zIndex: 1,
  },
  studySwipeRevealReviewGradientWrap: {
    right: 0,
  },
  studySwipeRevealKnownGradientWrap: {
    left: 0,
  },
  studySwipeRevealGradient: {
    bottom: 0,
    left: 0,
    position: 'absolute',
    right: 0,
    top: 0,
    zIndex: 1,
  },
  studySwipeRevealCue: {
    alignItems: 'center',
    borderCurve: 'continuous',
    borderRadius: 20,
    bottom: 26,
    gap: 5,
    justifyContent: 'center',
    minHeight: 130,
    position: 'absolute',
    top: 26,
    width: 132,
    zIndex: 2,
  },
  // The deck underlay now sits behind the cue, so it needs a wash of its own to
  // stay legible against a full card instead of empty space.
  studySwipeRevealCueReview: {
    right: 8,
  },
  studySwipeRevealCueKnown: {
    left: 8,
  },
  studySwipeFeedbackReviewText: {
    color: '#D70015',
  },
  studySwipeFeedbackKnownText: {
    color: '#248A3D',
  },
  studySwipeFeedbackLine: {
    fontWeight: '700',
    includeFontPadding: false,
    letterSpacing: 0,
    maxWidth: 118,
    textAlign: 'center',
  },
  studySwipeFeedbackLead: {
    fontSize: 12,
    lineHeight: 15,
  },
  studySwipeFeedbackAction: {
    fontSize: 15,
    lineHeight: 18,
  },
  groupPill: {
    alignSelf: 'flex-start',
    backgroundColor: '#EAF4FF',
    borderRadius: 999,
    paddingHorizontal: 10,
    paddingVertical: 6,
  },
  groupText: {
    color: '#0066CC',
    fontSize: 12,
    fontWeight: '500',
  },
  iconButton: {
    alignItems: 'center',
    backgroundColor: 'rgba(0, 122, 255, 0.09)',
    borderColor: 'rgba(0, 122, 255, 0.18)',
    borderRadius: 19,
    borderCurve: 'continuous',
    borderWidth: 0,
    height: 38,
    justifyContent: 'center',
    width: 38,
  },
  lockedFeatureGlyph: {
    alignItems: 'center',
    justifyContent: 'center',
  },
  featureLockBadge: {
    alignItems: 'center',
    backgroundColor: '#FFFFFF',
    borderColor: '#D1D1D6',
    borderCurve: 'continuous',
    borderRadius: 6,
    borderWidth: StyleSheet.hairlineWidth,
    bottom: -1,
    height: 12,
    justifyContent: 'center',
    position: 'absolute',
    right: -1,
    width: 12,
  },
  featureLockBadgeDark: {
    backgroundColor: '#2C2C2E',
    borderColor: '#636366',
  },
  studyCardActions: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: 8,
  },
  bigWord: {
    color: '#1C1C1E',
    fontSize: 40,
    fontWeight: '700',
    lineHeight: 48,
  },
  bigChineseWord: {
    fontSize: 30,
    lineHeight: 38,
  },
  pronunciation: {
    color: '#6C6C70',
    fontSize: 17,
  },
  pinyinText: {
    color: '#007AFF',
    fontSize: 15,
    fontWeight: '600',
    lineHeight: 21,
  },
  studyWordIdentity: {
    gap: 3,
  },
  meaningBlock: {
    borderTopColor: '#E5E5EA',
    borderTopWidth: 1,
    gap: 6,
    paddingTop: 14,
  },
  partOfSpeech: {
    color: '#007AFF',
    fontSize: 13,
    fontWeight: '600',
  },
  meaning: {
    color: '#1C1C1E',
    fontSize: 22,
    fontWeight: '600',
    // Reserving two lines moves a one-line entry's leftover space up here,
    // next to the text it belongs to, instead of leaving it pooled at the
    // bottom of the fixed-height card where it reads as an empty card.
    lineHeight: 30,
    minHeight: 60,
  },
  studySupplement: {
    borderTopColor: '#E5E5EA',
    borderTopWidth: StyleSheet.hairlineWidth,
    gap: 3,
    paddingTop: 9,
  },
  studySupplementLabel: {
    color: '#6C6C70',
    fontSize: 11,
    fontWeight: '600',
  },
  studySupplementText: {
    color: '#3A3A3C',
    fontSize: 14,
    fontWeight: '500',
    lineHeight: 19,
  },
  studyCardExampleBox: {
    borderBottomLeftRadius: 0,
    borderBottomRightRadius: 0,
    borderLeftWidth: 0,
    borderRightWidth: 0,
    borderTopLeftRadius: 0,
    borderTopRightRadius: 0,
    borderTopWidth: StyleSheet.hairlineWidth,
    flex: 1,
    justifyContent: 'center',
    marginBottom: -18,
    marginHorizontal: -18,
    paddingHorizontal: 18,
  },
  exampleBox: {
    backgroundColor: '#F7FAFF',
    borderColor: '#D6E9FF',
    borderRadius: 14,
    borderCurve: 'continuous',
    borderWidth: 0,
    gap: 6,
    padding: 14,
  },
  example: {
    color: '#1C1C1E',
    fontSize: 15,
    lineHeight: 22,
  },
  exampleZh: {
    color: '#6C6C70',
    fontSize: 15,
    lineHeight: 23,
  },
  actionGrid: {
    flexDirection: 'row',
    gap: 10,
  },
  secondaryButton: {
    alignItems: 'center',
    backgroundColor: 'rgba(120, 120, 128, 0.12)',
    borderColor: '#B9DCFF',
    borderRadius: 12,
    borderCurve: 'continuous',
    borderWidth: 0,
    flex: 1,
    flexDirection: 'row',
    gap: 8,
    justifyContent: 'center',
    minHeight: 50,
  },
  secondaryButtonText: {
    color: '#1C1C1E',
    fontSize: 15,
    fontWeight: '600',
  },
  confirmButton: {
    alignItems: 'center',
    backgroundColor: '#007AFF',
    borderRadius: 12,
    borderCurve: 'continuous',
    flex: 1,
    flexDirection: 'row',
    gap: 8,
    justifyContent: 'center',
    minHeight: 50,
  },
  confirmButtonText: {
    color: '#FFFFFF',
    fontSize: 15,
    fontWeight: '700',
  },
  quizCard: {
    backgroundColor: '#FFFFFF',
    borderColor: '#D1D1D6',
    borderRadius: 20,
    borderCurve: 'continuous',
    borderWidth: 0,
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
    backgroundColor: 'rgba(120, 120, 128, 0.12)',
    borderColor: '#D6E9FF',
    borderRadius: 10,
    borderCurve: 'continuous',
    borderWidth: 0,
    flexDirection: 'row',
    gap: 4,
    minHeight: 34,
    paddingHorizontal: 10,
  },
  quizNextTopText: {
    color: '#1C1C1E',
    flexShrink: 1,
    fontSize: 12,
    fontWeight: '600',
    textAlign: 'center',
  },
  quizSetupCard: {
    backgroundColor: '#FFFFFF',
    borderColor: '#D1D1D6',
    borderRadius: 20,
    borderCurve: 'continuous',
    borderWidth: 0,
    gap: 14,
    padding: 18,
  },
  quizModeCard: {
    backgroundColor: '#FFFFFF',
    borderColor: '#D1D1D6',
    borderRadius: 14,
    borderCurve: 'continuous',
    borderWidth: 0,
    gap: 12,
    padding: 14,
  },
  quizSectionDivider: {
    backgroundColor: 'rgba(60, 60, 67, 0.18)',
    height: StyleSheet.hairlineWidth,
    marginHorizontal: -18,
  },
  quizModeSwitch: {
    backgroundColor: '#EDF5FF',
    borderColor: '#D6E9FF',
    borderRadius: 14,
    borderCurve: 'continuous',
    borderWidth: 0,
    flexDirection: 'row',
    gap: 6,
    padding: 4,
  },
  quizModeButton: {
    alignItems: 'center',
    borderRadius: 10,
    borderCurve: 'continuous',
    flex: 1,
    justifyContent: 'center',
    minHeight: 42,
    paddingHorizontal: 10,
  },
  quizModeButtonActive: {
    backgroundColor: '#007AFF',
  },
  quizModeButtonText: {
    color: '#6C6C70',
    fontSize: 15,
    fontWeight: '700',
  },
  quizModeButtonTextActive: {
    color: '#FFFFFF',
  },
  quizCountRow: {
    flexDirection: 'row',
    gap: 8,
  },
  quizCountChip: {
    alignItems: 'center',
    backgroundColor: 'rgba(120, 120, 128, 0.12)',
    borderColor: '#D6E9FF',
    borderRadius: 14,
    borderCurve: 'continuous',
    borderWidth: 0,
    flex: 1,
    justifyContent: 'center',
    minHeight: 54,
    paddingHorizontal: 10,
    paddingVertical: 8,
  },
  quizCountChipActive: {
    backgroundColor: '#007AFF',
    borderColor: '#007AFF',
  },
  quizCountText: {
    color: '#1C1C1E',
    fontSize: 15,
    fontWeight: '700',
  },
  quizCountTextActive: {
    color: '#FFFFFF',
  },
  quizCountMeta: {
    color: '#6C6C70',
    fontSize: 12,
    fontWeight: '600',
    marginTop: 3,
  },
  quizOptions: {
    gap: 10,
    marginTop: 8,
  },
  quizOption: {
    alignItems: 'center',
    backgroundColor: 'rgba(120, 120, 128, 0.12)',
    borderColor: '#D6E9FF',
    borderRadius: 14,
    borderCurve: 'continuous',
    borderWidth: 0,
    flexDirection: 'row',
    gap: 12,
    minHeight: 56,
    paddingHorizontal: 14,
    paddingVertical: 12,
  },
  quizOptionPressed: {
    backgroundColor: 'rgba(0, 122, 255, 0.10)',
  },
  quizOptionCorrect: {
    backgroundColor: '#EAF9EE',
    borderColor: '#6CD97E',
  },
  quizOptionMuted: {
    opacity: 0.55,
  },
  quizOptionText: {
    color: '#1C1C1E',
    fontSize: 17,
    fontWeight: '500',
  },
  quizOptionTextCorrect: {
    color: '#248A3D',
  },
  resultCard: {
    borderRadius: 18,
    borderCurve: 'continuous',
    borderWidth: 0,
    gap: 8,
    padding: 16,
  },
  resultCorrect: {
    backgroundColor: '#EAF9EE',
    borderColor: '#6CD97E',
  },
  resultWrong: {
    backgroundColor: '#FFF0EF',
    borderColor: '#FFC9C5',
  },
  resultTitle: {
    fontFamily: ROUNDED_FONT,
    color: '#1C1C1E',
    fontSize: 20,
    fontWeight: '700',
  },
  resultText: {
    color: '#6C6C70',
    fontSize: 15,
    lineHeight: 23,
  },
  speakingPromptQuestion: {
    color: '#1C1C1E',
    fontSize: 22,
    fontWeight: '700',
    lineHeight: 30,
  },
  quizExampleCard: {
    backgroundColor: 'rgba(255, 255, 255, 0.7)',
    borderColor: 'rgba(209, 209, 214, 0.72)',
    borderRadius: 14,
    borderCurve: 'continuous',
    borderWidth: 0,
    gap: 6,
    padding: 12,
  },
  quizExampleLabel: {
    color: '#6C6C70',
    fontSize: 12,
    fontWeight: '600',
    marginTop: 2,
  },
  speakingKeywordHeader: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: 12,
  },
  speakingIconWrap: {
    alignItems: 'center',
    backgroundColor: '#EAF4FF',
    borderColor: '#B9DCFF',
    borderRadius: 11,
    borderCurve: 'continuous',
    borderWidth: 0,
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
    backgroundColor: '#007AFF',
    borderRadius: 12,
    borderCurve: 'continuous',
    flex: 1,
    flexDirection: 'row',
    gap: 8,
    justifyContent: 'center',
    minHeight: 48,
    minWidth: 132,
    paddingHorizontal: 14,
  },
  speakingDoneButtonText: {
    color: '#FFFFFF',
    fontSize: 15,
    fontWeight: '700',
  },
  speakingSecondaryButton: {
    alignItems: 'center',
    backgroundColor: 'rgba(120, 120, 128, 0.12)',
    borderColor: '#E5E5EA',
    borderRadius: 12,
    borderCurve: 'continuous',
    borderWidth: 0,
    flex: 1,
    flexDirection: 'row',
    gap: 8,
    justifyContent: 'center',
    minHeight: 48,
    minWidth: 132,
    paddingHorizontal: 14,
  },
  speakingSecondaryText: {
    color: '#1C1C1E',
    fontSize: 15,
    fontWeight: '700',
  },
  quizScoreText: {
    fontFamily: ROUNDED_FONT,
    color: '#1C1C1E',
    fontSize: 22,
    fontWeight: '700',
  },
  libraryTopControlsInset: {
    gap: 10,
  },
  searchBox: {
    alignItems: 'center',
    backgroundColor: 'rgba(120, 120, 128, 0.12)',
    borderColor: '#B9DCFF',
    borderRadius: 14,
    borderCurve: 'continuous',
    borderWidth: 0,
    flexDirection: 'row',
    gap: 8,
    paddingHorizontal: 13,
    paddingVertical: 10,
  },
  searchBoxActive: {
    backgroundColor: '#FFFFFF',
    borderColor: '#007AFF',
    borderWidth: 0,
  },
  searchBoxFocused: {
    borderColor: '#007AFF',
  },
  searchInput: {
    color: '#1C1C1E',
    flex: 1,
    fontSize: 15,
  },
  searchClearButton: {
    alignItems: 'center',
    backgroundColor: '#EAF4FF',
    borderRadius: 11,
    borderCurve: 'continuous',
    height: 30,
    justifyContent: 'center',
    width: 30,
  },
  searchMetaBox: {
    backgroundColor: '#EAF4FF',
    borderColor: '#B9DCFF',
    borderRadius: 14,
    borderCurve: 'continuous',
    borderWidth: 0,
    paddingHorizontal: 12,
    paddingVertical: 9,
  },
  searchMetaText: {
    color: '#0066CC',
    fontSize: 12,
    fontWeight: '600',
  },
  foldedFilterCard: {
    backgroundColor: '#FFFFFF',
    borderColor: '#D1D1D6',
    borderRadius: 20,
    borderCurve: 'continuous',
    borderWidth: 0,
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
    backgroundColor: 'rgba(0, 122, 255, 0.07)',
  },
  filterSummaryTitle: {
    color: '#1C1C1E',
    fontSize: 15,
    fontWeight: '700',
  },
  filterSummaryText: {
    color: '#6C6C70',
    fontSize: 12,
    fontWeight: '500',
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
    borderTopColor: '#E5E5EA',
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
    color: '#6C6C70',
    fontSize: 12,
    fontWeight: '600',
  },
  filterRow: {
    gap: 8,
    paddingRight: 10,
  },
  libraryStatusFilterRow: {
    flexDirection: 'row',
    gap: 6,
  },
  libraryStatusFilterChip: {
    flex: 1,
    minWidth: 0,
    paddingHorizontal: 4,
  },
  filterChip: {
    backgroundColor: 'rgba(120, 120, 128, 0.12)',
    borderColor: '#D6E9FF',
    borderRadius: 999,
    borderCurve: 'continuous',
    borderWidth: 0,
    // 10 rather than 12: the five status chips summed to 326 against a 324
    // container, so the last one wrapped to a row of its own over 2px.
    paddingHorizontal: 10,
    paddingVertical: 8,
  },
  filterChipActive: {
    backgroundColor: '#007AFF',
    borderColor: '#007AFF',
  },
  levelChipActive: {
    backgroundColor: '#007AFF',
    borderColor: '#007AFF',
  },
  filterText: {
    color: '#6C6C70',
    flexShrink: 1,
    fontSize: 13,
    fontWeight: '500',
    textAlign: 'center',
  },
  filterTextActive: {
    color: '#FFFFFF',
  },
  filterChipLabelRow: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: 4,
    justifyContent: 'center',
  },
  letterRow: {
    gap: 6,
    paddingRight: 10,
  },
  letterChip: {
    alignItems: 'center',
    backgroundColor: 'rgba(120, 120, 128, 0.12)',
    borderColor: '#D6E9FF',
    borderRadius: 999,
    borderCurve: 'continuous',
    borderWidth: 0,
    height: 34,
    justifyContent: 'center',
    minWidth: 34,
    paddingHorizontal: 9,
  },
  letterChipActive: {
    backgroundColor: '#007AFF',
    borderColor: '#007AFF',
  },
  letterText: {
    color: '#6C6C70',
    fontSize: 12,
    fontWeight: '600',
  },
  letterTextActive: {
    color: '#FFFFFF',
  },
  libraryHeaderCard: {
    alignItems: 'stretch',
    backgroundColor: '#FFFFFF',
    borderColor: '#D1D1D6',
    borderRadius: 20,
    borderCurve: 'continuous',
    borderWidth: 0,
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
    justifyContent: 'flex-start',
  },
  libraryHeaderTitle: {
    fontFamily: ROUNDED_FONT,
    color: '#1C1C1E',
    fontSize: 17,
    fontWeight: '700',
    flexShrink: 1,
  },
  libraryHeaderMeta: {
    color: '#6C6C70',
    fontSize: 13,
    fontWeight: '500',
    marginTop: 3,
  },
  libraryHeaderMetaPill: {
    alignItems: 'center',
    backgroundColor: '#EAF4FF',
    borderRadius: 999,
    flexShrink: 1,
    justifyContent: 'center',
    maxWidth: '45%',
    minHeight: 28,
    paddingHorizontal: 9,
  },
  libraryHeaderMetaPillText: {
    color: '#0066CC',
    fontSize: 12,
    fontWeight: '600',
  },
  libraryTopButton: {
    alignItems: 'center',
    backgroundColor: 'rgba(120, 120, 128, 0.12)',
    borderColor: '#D6E9FF',
    borderRadius: 999,
    borderCurve: 'continuous',
    borderWidth: 0,
    flexDirection: 'row',
    gap: 6,
    minHeight: 40,
    paddingHorizontal: 11,
  },
  libraryTopButtonText: {
    color: '#1C1C1E',
    fontSize: 13,
    fontWeight: '600',
  },
  libraryCustomSetsCard: {
    backgroundColor: '#FFFFFF',
    borderColor: '#D1D1D6',
    borderRadius: 20,
    borderCurve: 'continuous',
    borderWidth: 0,
    gap: 10,
    padding: 11,
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
    fontFamily: ROUNDED_FONT,
    color: '#1C1C1E',
    fontSize: 15,
    fontWeight: '700',
  },
  libraryManageSetsButton: {
    alignItems: 'center',
    backgroundColor: 'rgba(120, 120, 128, 0.12)',
    borderColor: '#D6E9FF',
    borderRadius: 999,
    borderCurve: 'continuous',
    borderWidth: 0,
    flexDirection: 'row',
    flexShrink: 0,
    gap: 4,
    justifyContent: 'center',
    minHeight: 34,
    paddingHorizontal: 9,
  },
  libraryManageSetsButtonLabel: {
    color: '#1C1C1E',
    flexShrink: 1,
    fontSize: 12,
    fontWeight: '600',
    textAlign: 'center',
  },
  libraryCustomSetChip: {
    alignItems: 'center',
    backgroundColor: 'rgba(120, 120, 128, 0.12)',
    borderColor: '#D6E9FF',
    borderRadius: 999,
    borderCurve: 'continuous',
    borderWidth: 0,
    flexDirection: 'row',
    gap: 7,
    minHeight: 34,
    paddingHorizontal: 10,
  },
  libraryCustomSetCount: {
    fontSize: 12,
    fontWeight: '600',
  },
  libraryItem: {
    backgroundColor: '#FFFFFF',
    borderColor: '#D1D1D6',
    borderRadius: 14,
    borderCurve: 'continuous',
    borderWidth: 0,
    flexDirection: 'row',
    gap: 12,
    padding: 14,
  },
  libraryItemMain: {
    borderRadius: 14,
    borderCurve: 'continuous',
    flex: 1,
    minWidth: 0,
    paddingHorizontal: 2,
    paddingVertical: 2,
  },
  libraryItemPressed: {
    backgroundColor: 'rgba(0, 122, 255, 0.10)',
  },
  libraryItemPressedLift: {
    borderColor: '#B9DCFF',
    shadowColor: '#007AFF',
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
    color: '#1C1C1E',
    fontSize: 20,
    fontWeight: '700',
  },
  libraryChineseWord: {
    fontSize: 17,
    lineHeight: 23,
  },
  libraryGroup: {
    backgroundColor: '#EAF4FF',
    borderColor: '#B9DCFF',
    borderRadius: 999,
    borderWidth: 0,
    color: '#0066CC',
    fontSize: 12,
    fontWeight: '600',
    overflow: 'hidden',
    paddingHorizontal: 6,
    paddingVertical: 3,
  },
  libraryPos: {
    color: '#007AFF',
    fontSize: 12,
    fontWeight: '600',
  },
  libraryPinyin: {
    color: '#007AFF',
    fontSize: 12,
    fontWeight: '600',
    lineHeight: 18,
    marginTop: 5,
  },
  libraryMeaning: {
    color: '#1C1C1E',
    fontSize: 15,
    fontWeight: '500',
    marginTop: 5,
  },
  librarySupplemental: {
    color: '#6C6C70',
    fontSize: 12,
    fontWeight: '500',
    lineHeight: 18,
    marginTop: 4,
  },
  libraryExample: {
    color: '#6C6C70',
    fontSize: 13,
    lineHeight: 19,
    marginTop: 5,
  },
  libraryDetailBack: {
    alignItems: 'center',
    alignSelf: 'flex-start',
    backgroundColor: 'rgba(120, 120, 128, 0.12)',
    borderColor: '#D6E9FF',
    borderRadius: 999,
    borderCurve: 'continuous',
    borderWidth: 0,
    flexDirection: 'row',
    gap: 6,
    minHeight: 42,
    paddingHorizontal: 12,
  },
  libraryDetailBackText: {
    color: '#1C1C1E',
    fontSize: 15,
    fontWeight: '700',
  },
  libraryDetailPage: {
    backgroundColor: '#FFFFFF',
    borderRadius: 16,
    borderCurve: 'continuous',
    gap: 16,
    padding: 18,
  },
  libraryDetailHeader: {
    alignItems: 'flex-start',
    flexDirection: 'row',
    gap: 12,
  },
  libraryDetailWord: {
    fontFamily: ROUNDED_FONT,
    color: '#1C1C1E',
    fontSize: 42,
    fontWeight: '700',
    lineHeight: 48,
  },
  libraryDetailChineseWord: {
    fontSize: 30,
    lineHeight: 38,
  },
  libraryDetailPronunciation: {
    color: '#6C6C70',
    fontSize: 17,
    marginTop: 4,
  },
  libraryDetailPinyin: {
    color: '#007AFF',
    fontSize: 15,
    fontWeight: '600',
    lineHeight: 21,
    marginTop: 4,
  },
  libraryDetailFavorite: {
    alignItems: 'center',
    backgroundColor: '#F7FAFF',
    borderColor: '#D6E9FF',
    borderRadius: 11,
    borderCurve: 'continuous',
    borderWidth: 0,
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
    backgroundColor: '#EAF4FF',
    borderColor: '#B9DCFF',
    borderRadius: 999,
    borderWidth: 0,
    color: '#0066CC',
    fontSize: 12,
    fontWeight: '600',
    overflow: 'hidden',
    paddingHorizontal: 9,
    paddingVertical: 5,
  },
  libraryDetailSection: {
    borderTopColor: '#E5E5EA',
    borderTopWidth: 1,
    gap: 7,
    paddingTop: 15,
  },
  libraryDetailLabel: {
    color: '#6C6C70',
    fontSize: 12,
    fontWeight: '600',
  },
  libraryDetailMeaning: {
    color: '#1C1C1E',
    fontSize: 22,
    fontWeight: '700',
    lineHeight: 28,
  },
  libraryDetailExampleCard: {
    backgroundColor: '#F7FAFF',
    borderColor: '#D6E9FF',
    borderRadius: 14,
    borderCurve: 'continuous',
    borderWidth: 0,
    gap: 8,
    padding: 15,
  },
  libraryDetailExample: {
    color: '#1C1C1E',
    fontSize: 17,
    lineHeight: 26,
  },
  libraryDetailDivider: {
    backgroundColor: '#E5E5EA',
    height: 1,
    marginVertical: 2,
  },
  libraryDetailExampleZh: {
    color: '#6C6C70',
    fontSize: 15,
    lineHeight: 23,
  },
  librarySide: {
    alignItems: 'center',
    gap: 8,
  },
  statusText: {
    color: '#6C6C70',
    fontSize: 12,
    fontWeight: '500',
  },
  emptyState: {
    backgroundColor: '#FFFFFF',
    borderColor: '#D1D1D6',
    borderRadius: 20,
    borderCurve: 'continuous',
    borderWidth: 0,
    padding: 16,
  },
  emptyTitle: {
    fontFamily: ROUNDED_FONT,
    color: '#1C1C1E',
    fontSize: 15,
    fontWeight: '700',
  },
  emptyText: {
    color: '#6C6C70',
    fontSize: 13,
    marginTop: 5,
  },
  libraryFixedControls: {
    bottom: LIBRARY_FIXED_CONTROLS_BOTTOM,
    position: 'absolute',
    right: 0,
    top: LIBRARY_FIXED_CONTROLS_TOP,
    width: 24,
    zIndex: 20,
  },
  libraryFloatingTopButton: {
    alignItems: 'center',
    alignSelf: 'flex-end',
    backgroundColor: 'rgba(120, 120, 128, 0.12)',
    borderColor: '#D1D1D6',
    borderRadius: 11,
    borderCurve: 'continuous',
    borderWidth: 0,
    elevation: 4,
    flexDirection: 'row',
    gap: 5,
    marginBottom: 10,
    minHeight: 38,
    paddingHorizontal: 9,
    position: 'absolute',
    right: 4,
    shadowColor: '#1C1C1E',
    shadowOffset: { height: 2, width: 0 },
    shadowOpacity: 0.12,
    shadowRadius: 6,
    top: 0,
  },
  libraryFloatingTopText: {
    color: '#1C1C1E',
    fontSize: 12,
    fontWeight: '600',
  },
  libraryDragSlider: {
    alignItems: 'center',
    alignSelf: 'flex-end',
    backgroundColor: 'transparent',
    borderColor: 'transparent',
    borderWidth: 0,
    bottom: 0,
    position: 'absolute',
    right: 0,
    top: 92,
    width: 24,
  },
  libraryDragTrack: {
    backgroundColor: '#1C1C1E',
    borderRadius: 999,
    bottom: 8,
    left: 11,
    position: 'absolute',
    top: 8,
    width: 2,
  },
  libraryDragThumb: {
    backgroundColor: '#007AFF',
    borderColor: 'transparent',
    borderRadius: 999,
    borderWidth: 0,
    height: LIBRARY_SLIDER_THUMB_HEIGHT,
    left: 10,
    position: 'absolute',
    top: 5,
    width: 4,
  },
  profileCard: {
    alignItems: 'center',
    backgroundColor: '#FFFFFF',
    borderColor: '#D1D1D6',
    borderRadius: 20,
    borderCurve: 'continuous',
    borderWidth: 0,
    padding: 18,
  },
  avatar: {
    alignItems: 'center',
    backgroundColor: '#EAF4FF',
    borderRadius: 18,
    borderCurve: 'continuous',
    height: 64,
    justifyContent: 'center',
    marginBottom: 12,
    width: 64,
  },
  profileTitle: {
    fontFamily: ROUNDED_FONT,
    alignSelf: 'stretch',
    color: '#1C1C1E',
    fontSize: 22,
    fontWeight: '700',
    textAlign: 'center',
  },
  profileText: {
    color: '#6C6C70',
    fontSize: 15,
    lineHeight: 23,
    marginTop: 8,
    textAlign: 'center',
  },
  syncPill: {
    alignItems: 'center',
    backgroundColor: '#EAF9EE',
    borderColor: '#B7E9C2',
    borderRadius: 999,
    borderWidth: 0,
    flexDirection: 'row',
    gap: 6,
    marginTop: 14,
    paddingHorizontal: 10,
    paddingVertical: 7,
  },
  syncPillError: {
    backgroundColor: '#FFF0EF',
    borderColor: '#FFC9C5',
  },
  syncText: {
    color: '#248A3D',
    fontSize: 12,
    fontWeight: '600',
  },
  syncTextError: {
    color: '#D70015',
  },
  accountCard: {
    backgroundColor: '#FFFFFF',
    borderColor: '#D1D1D6',
    borderRadius: 20,
    borderCurve: 'continuous',
    borderWidth: 0,
    gap: 14,
    padding: 16,
  },
  googleButton: {
    alignItems: 'center',
    backgroundColor: 'rgba(120, 120, 128, 0.12)',
    borderColor: '#D1D1D6',
    borderRadius: 12,
    borderCurve: 'continuous',
    borderWidth: 0,
    flexDirection: 'row',
    gap: 11,
    minHeight: 62,
    paddingHorizontal: 12,
    paddingVertical: 10,
  },
  googleIconMark: {
    alignItems: 'center',
    backgroundColor: '#F7FAFF',
    borderColor: '#D6E9FF',
    borderRadius: 11,
    borderCurve: 'continuous',
    borderWidth: 0,
    height: 38,
    justifyContent: 'center',
    width: 38,
  },
  googleButtonTitle: {
    color: '#1C1C1E',
    fontSize: 15,
    fontWeight: '700',
  },
  googleButtonText: {
    color: '#6C6C70',
    fontSize: 12,
    fontWeight: '500',
    lineHeight: 17,
    marginTop: 2,
  },
  appleButton: {
    alignItems: 'center',
    backgroundColor: '#000000',
    borderColor: '#000000',
    borderRadius: 12,
    borderCurve: 'continuous',
    borderWidth: 1,
    flexDirection: 'row',
    gap: 11,
    minHeight: 62,
    paddingHorizontal: 12,
    paddingVertical: 10,
  },
  appleIconMark: {
    alignItems: 'center',
    backgroundColor: '#1C1C1E',
    borderColor: '#3A3A3C',
    borderRadius: 11,
    borderCurve: 'continuous',
    borderWidth: 0,
    height: 38,
    justifyContent: 'center',
    width: 38,
  },
  appleButtonTitle: {
    color: '#FFFFFF',
    fontSize: 15,
    fontWeight: '700',
  },
  appleButtonText: {
    color: '#D1D1D6',
    fontSize: 12,
    fontWeight: '500',
    lineHeight: 17,
    marginTop: 2,
  },
  emailFallbackLabel: {
    color: '#6C6C70',
    fontSize: 12,
    fontWeight: '600',
    marginTop: 2,
  },
  inputStack: {
    gap: 10,
  },
  inputBox: {
    alignItems: 'center',
    backgroundColor: 'rgba(120, 120, 128, 0.12)',
    borderColor: '#D6E9FF',
    borderRadius: 14,
    borderCurve: 'continuous',
    borderWidth: 0,
    flexDirection: 'row',
    gap: 8,
    minHeight: 46,
    paddingHorizontal: 12,
  },
  accountInput: {
    color: '#1C1C1E',
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
    backgroundColor: '#007AFF',
    borderRadius: 12,
    borderCurve: 'continuous',
    flex: 1,
    flexDirection: 'row',
    gap: 7,
    justifyContent: 'center',
    minHeight: 46,
    paddingHorizontal: 12,
  },
  accountButtonText: {
    color: '#FFFFFF',
    fontSize: 15,
    fontWeight: '700',
  },
  outlineButton: {
    alignItems: 'center',
    backgroundColor: 'rgba(120, 120, 128, 0.12)',
    borderColor: '#B9DCFF',
    borderRadius: 12,
    borderCurve: 'continuous',
    borderWidth: 0,
    flex: 1,
    justifyContent: 'center',
    minHeight: 46,
    paddingHorizontal: 12,
  },
  outlineButtonText: {
    color: '#1C1C1E',
    fontSize: 15,
    fontWeight: '700',
  },
  signOutButton: {
    alignItems: 'center',
    alignSelf: 'stretch',
    backgroundColor: '#FFF0EF',
    borderColor: '#FFC9C5',
    borderRadius: 12,
    borderCurve: 'continuous',
    borderWidth: 0,
    flexDirection: 'row',
    gap: 7,
    justifyContent: 'center',
    minHeight: 46,
    paddingHorizontal: 12,
  },
  signOutButtonText: {
    color: '#D70015',
    fontSize: 15,
    fontWeight: '700',
  },
  localOnlyBox: {
    backgroundColor: '#F7FAFF',
    borderColor: '#D6E9FF',
    borderRadius: 14,
    borderCurve: 'continuous',
    borderWidth: 0,
    padding: 13,
  },
  localOnlyTitle: {
    color: '#1C1C1E',
    fontSize: 15,
    fontWeight: '700',
  },
  localOnlyText: {
    color: '#6C6C70',
    fontSize: 13,
    marginTop: 4,
  },
  disabledButton: {
    opacity: 0.58,
  },
  activeSetBanner: {
    alignItems: 'center',
    backgroundColor: '#EAF4FF',
    borderColor: '#B9DCFF',
    borderRadius: 14,
    borderCurve: 'continuous',
    borderWidth: 0,
    flexDirection: 'row',
    gap: 12,
    paddingHorizontal: 14,
    paddingVertical: 12,
  },
  activeSetTitle: {
    color: '#0066CC',
    fontSize: 15,
    fontWeight: '700',
  },
  activeSetText: {
    color: '#6C6C70',
    fontSize: 12,
    fontWeight: '600',
    marginTop: 2,
  },
  activeSetClearButton: {
    backgroundColor: 'rgba(120, 120, 128, 0.12)',
    borderColor: '#B9DCFF',
    borderRadius: 10,
    borderCurve: 'continuous',
    borderWidth: 0,
    paddingHorizontal: 11,
    paddingVertical: 8,
  },
  activeSetClearText: {
    color: '#0066CC',
    flexShrink: 1,
    fontSize: 12,
    fontWeight: '600',
    textAlign: 'center',
  },
  addToSetIconButton: {
    backgroundColor: '#EAF4FF',
    borderColor: '#B9DCFF',
    borderRadius: 11,
    borderCurve: 'continuous',
    borderWidth: 0,
  },
  libraryDetailActionStack: {
    gap: 8,
  },
  accountUpgradeOverlay: {
    backgroundColor: 'rgba(15, 23, 34, 0.48)',
    flex: 1,
  },
  accountUpgradeSafeArea: {
    flex: 1,
    justifyContent: 'flex-end',
    paddingHorizontal: 10,
    paddingBottom: 8,
  },
  accountUpgradePanel: {
    alignSelf: 'center',
    backgroundColor: 'rgba(250, 252, 255, 0.98)',
    borderColor: 'rgba(255, 255, 255, 0.9)',
    borderCurve: 'continuous',
    borderRadius: 24,
    borderWidth: 0,
    maxWidth: 520,
    padding: 20,
    shadowColor: '#000000',
    shadowOffset: { height: 18, width: 0 },
    shadowOpacity: 0.22,
    shadowRadius: 34,
    width: '100%',
  },
  accountUpgradeHandle: {
    alignSelf: 'center',
    backgroundColor: 'rgba(60, 60, 67, 0.24)',
    borderRadius: 999,
    height: 5,
    marginBottom: 13,
    width: 38,
  },
  accountUpgradeHeader: {
    alignItems: 'center',
    flexDirection: 'row',
    justifyContent: 'space-between',
  },
  accountUpgradeIcon: {
    alignItems: 'center',
    backgroundColor: '#EAF4FF',
    borderColor: '#B9DCFF',
    borderCurve: 'continuous',
    borderRadius: 14,
    borderWidth: 0,
    height: 48,
    justifyContent: 'center',
    width: 48,
  },
  accountUpgradeFavoriteIcon: {
    backgroundColor: '#FFF4DF',
    borderColor: '#FFD598',
  },
  accountUpgradeFavoriteIconDark: {
    backgroundColor: '#3A2A10',
    borderColor: '#78571E',
  },
  accountUpgradeClose: {
    alignItems: 'center',
    backgroundColor: 'rgba(229, 229, 234, 0.72)',
    borderColor: 'rgba(199, 199, 204, 0.72)',
    borderCurve: 'continuous',
    borderRadius: 19,
    borderWidth: 0,
    height: 38,
    justifyContent: 'center',
    width: 38,
  },
  accountUpgradeTitle: {
    fontFamily: ROUNDED_FONT,
    color: '#1C1C1E',
    fontSize: 26,
    fontWeight: '700',
    letterSpacing: 0,
    lineHeight: 32,
    marginTop: 18,
  },
  accountUpgradeBody: {
    color: '#54545A',
    fontSize: 15,
    fontWeight: '500',
    letterSpacing: 0,
    lineHeight: 22,
    marginTop: 8,
  },
  accountUpgradeMemoryPill: {
    alignItems: 'center',
    alignSelf: 'flex-start',
    backgroundColor: '#EAF9EE',
    borderColor: '#B7E9C2',
    borderCurve: 'continuous',
    borderRadius: 11,
    borderWidth: 0,
    flexDirection: 'row',
    gap: 7,
    marginTop: 16,
    paddingHorizontal: 11,
    paddingVertical: 8,
  },
  accountUpgradeMemoryText: {
    color: '#1F7A3B',
    fontSize: 13,
    fontWeight: '600',
  },
  accountUpgradeActions: {
    gap: 10,
    marginTop: 20,
  },
  accountUpgradeAppleButton: {
    alignItems: 'center',
    backgroundColor: '#101722',
    borderCurve: 'continuous',
    borderRadius: 14,
    flexDirection: 'row',
    gap: 10,
    justifyContent: 'center',
    minHeight: 54,
    paddingHorizontal: 16,
  },
  accountUpgradeAppleText: {
    color: '#FFFFFF',
    flexShrink: 1,
    fontSize: 16,
    fontWeight: '700',
    textAlign: 'center',
  },
  accountUpgradeGoogleButton: {
    alignItems: 'center',
    backgroundColor: 'rgba(255, 255, 255, 0.7)',
    borderColor: '#C7C7CC',
    borderCurve: 'continuous',
    borderRadius: 14,
    borderWidth: 0,
    flexDirection: 'row',
    gap: 10,
    justifyContent: 'center',
    minHeight: 54,
    overflow: 'hidden',
    paddingHorizontal: 16,
  },
  accountUpgradeGoogleText: {
    color: '#1C1C1E',
    flexShrink: 1,
    fontSize: 16,
    fontWeight: '700',
    textAlign: 'center',
  },
  accountUpgradePrivacy: {
    color: '#6C6C70',
    fontSize: 12,
    lineHeight: 17,
    marginTop: 14,
    textAlign: 'center',
  },
  accountUpgradeLaterButton: {
    alignItems: 'center',
    justifyContent: 'center',
    minHeight: 42,
    marginTop: 2,
  },
  accountUpgradeLaterText: {
    color: '#007AFF',
    fontSize: 15,
    fontWeight: '600',
  },
  customSetOverlay: {
    alignItems: 'center',
    backgroundColor: 'rgba(28, 28, 30, 0.54)',
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
    backgroundColor: '#FFFFFF',
    borderColor: '#D6E9FF',
    borderRadius: 20,
    borderCurve: 'continuous',
    borderWidth: 0,
    gap: 14,
    maxWidth: 430,
    padding: 16,
    shadowColor: '#1C1C1E',
    shadowOffset: { height: 18, width: 0 },
    shadowOpacity: 0.2,
    shadowRadius: 30,
    width: '100%',
  },
  customSetPickerTitle: {
    fontFamily: ROUNDED_FONT,
    color: '#1C1C1E',
    fontSize: 20,
    fontWeight: '700',
  },
  customSetPickerText: {
    color: '#6C6C70',
    fontSize: 13,
    fontWeight: '600',
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
    backgroundColor: '#007AFF',
    borderRadius: 11,
    borderCurve: 'continuous',
    height: 44,
    justifyContent: 'center',
    width: 44,
  },
  customSetWideCreateButton: {
    alignItems: 'center',
    backgroundColor: '#007AFF',
    borderRadius: 12,
    borderCurve: 'continuous',
    flexDirection: 'row',
    gap: 6,
    minHeight: 44,
    paddingHorizontal: 12,
  },
  customSetWideCreateText: {
    color: '#FFFFFF',
    fontSize: 13,
    fontWeight: '600',
  },
  customSetPickerList: {
    gap: 8,
  },
  customSetPickerRow: {
    alignItems: 'center',
    backgroundColor: '#F7FAFF',
    borderColor: '#D6E9FF',
    borderRadius: 14,
    borderCurve: 'continuous',
    borderWidth: 0,
    flexDirection: 'row',
    gap: 10,
    padding: 12,
  },
  customSetPickerEmpty: {
    color: '#6C6C70',
    fontSize: 13,
    fontWeight: '600',
    lineHeight: 19,
  },
  customSetColorDot: {
    borderRadius: 99,
    height: 12,
    width: 12,
  },
  customSetRowTitle: {
    color: '#1C1C1E',
    fontSize: 15,
    fontWeight: '700',
  },
  customSetRowText: {
    color: '#6C6C70',
    fontSize: 12,
    fontWeight: '600',
    marginTop: 2,
  },
  customSetAddText: {
    color: '#007AFF',
    fontSize: 13,
    fontWeight: '600',
  },
  customSetsHeroCard: {
    backgroundColor: '#FFFFFF',
    borderColor: '#D1D1D6',
    borderRadius: 20,
    borderCurve: 'continuous',
    borderWidth: 0,
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
    backgroundColor: '#FFFFFF',
    borderColor: '#D1D1D6',
    borderRadius: 20,
    borderCurve: 'continuous',
    borderWidth: 0,
    gap: 12,
    padding: 13,
  },
  customSetCardActive: {
    borderColor: '#007AFF',
    shadowColor: '#007AFF',
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
    borderRadius: 11,
    borderCurve: 'continuous',
    height: 42,
    justifyContent: 'center',
    width: 42,
  },
  customSetTitleRow: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: 9,
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
    backgroundColor: 'rgba(120, 120, 128, 0.12)',
    borderColor: '#D6E9FF',
    borderRadius: 12,
    borderCurve: 'continuous',
    borderWidth: 0,
    flex: 1,
    flexDirection: 'row',
    gap: 6,
    justifyContent: 'center',
    minHeight: 42,
  },
  customSetActionText: {
    color: '#1C1C1E',
    flexShrink: 1,
    fontSize: 13,
    fontWeight: '600',
    textAlign: 'center',
  },
  customSetPrimaryActionButton: {
    alignItems: 'center',
    backgroundColor: '#007AFF',
    borderRadius: 12,
    borderCurve: 'continuous',
    flex: 1,
    flexDirection: 'row',
    gap: 6,
    justifyContent: 'center',
    minHeight: 42,
  },
  customSetPrimaryActionText: {
    color: '#FFFFFF',
    flexShrink: 1,
    fontSize: 13,
    fontWeight: '600',
    textAlign: 'center',
  },
  customSetDeleteButton: {
    alignItems: 'center',
    backgroundColor: '#FFF0EF',
    borderColor: '#FFC9C5',
    borderRadius: 12,
    borderCurve: 'continuous',
    borderWidth: 0,
    flexBasis: '100%',
    flexDirection: 'row',
    gap: 6,
    justifyContent: 'center',
    minHeight: 44,
    paddingHorizontal: 14,
    width: '100%',
  },
  customSetDeleteText: {
    color: '#D70015',
    flexShrink: 1,
    fontSize: 13,
    fontWeight: '600',
    textAlign: 'center',
  },
  customSetWordList: {
    gap: 8,
  },
  customSetWordRow: {
    alignItems: 'center',
    backgroundColor: '#F7FAFF',
    borderColor: '#D6E9FF',
    borderRadius: 14,
    borderCurve: 'continuous',
    borderWidth: 0,
    flexDirection: 'row',
    gap: 10,
    padding: 10,
  },
  customSetRemoveWordButton: {
    alignItems: 'center',
    backgroundColor: '#FFFFFF',
    borderColor: '#FFC9C5',
    borderRadius: 10,
    borderCurve: 'continuous',
    borderWidth: 0,
    flexDirection: 'row',
    gap: 4,
    minHeight: 34,
    paddingHorizontal: 9,
  },
  customSetRemoveWordText: {
    color: '#D70015',
    flexShrink: 1,
    fontSize: 12,
    fontWeight: '600',
    textAlign: 'center',
  },
  customWordFormGrid: {
    gap: 9,
  },
  customWordLongInput: {
    minHeight: 48,
  },
  customSetTinyMeta: {
    color: '#8E8E93',
    fontSize: 12,
    fontWeight: '600',
    textAlign: 'right',
  },
  settingsCard: {
    backgroundColor: '#FFFFFF',
    borderColor: '#D1D1D6',
    borderRadius: 20,
    borderCurve: 'continuous',
    borderWidth: 0,
    gap: 16,
    padding: 16,
  },
  profileInfoCard: {
    backgroundColor: '#FFFFFF',
    borderColor: '#D1D1D6',
    borderRadius: 20,
    borderCurve: 'continuous',
    borderWidth: 0,
    gap: 14,
    padding: 16,
  },
  learningMetricGrid: {
    flexDirection: 'row',
    gap: 8,
  },
  learningMetric: {
    backgroundColor: '#F7FAFF',
    borderColor: '#D6E9FF',
    borderRadius: 14,
    borderCurve: 'continuous',
    borderWidth: 0,
    flex: 1,
    minHeight: 66,
    padding: 10,
  },
  learningMetricLabel: {
    color: '#6C6C70',
    fontSize: 12,
    fontWeight: '600',
  },
  learningMetricValue: {
    fontFamily: ROUNDED_FONT,
    color: '#1C1C1E',
    fontSize: 17,
    fontWeight: '700',
    marginTop: 6,
  },
  learningMetricLockedRow: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: 5,
    marginTop: 7,
  },
  learningMetricLockedText: {
    fontSize: 12,
    fontWeight: '700',
  },
  settingOptionRow: {
    alignItems: 'center',
    backgroundColor: '#F7FAFF',
    borderColor: '#D6E9FF',
    borderRadius: 14,
    borderCurve: 'continuous',
    borderWidth: 0,
    flexDirection: 'row',
    gap: 12,
    minHeight: 70,
    padding: 12,
  },
  settingOptionIcon: {
    alignItems: 'center',
    backgroundColor: '#EAF4FF',
    borderRadius: 11,
    borderCurve: 'continuous',
    height: 42,
    justifyContent: 'center',
    width: 42,
  },
  themeStatusLight: {
    alignItems: 'center',
    backgroundColor: '#D6E9FF',
    borderRadius: 99,
    borderCurve: 'continuous',
    height: 14,
    justifyContent: 'center',
    width: 14,
  },
  themeStatusLightActive: {
    backgroundColor: '#D6E9FF',
    elevation: 4,
    shadowColor: '#007AFF',
    shadowOffset: { height: 0, width: 0 },
    shadowOpacity: 0.42,
    shadowRadius: 7,
  },
  themeStatusLightCore: {
    backgroundColor: '#8E8E93',
    borderRadius: 99,
    borderCurve: 'continuous',
    height: 8,
    width: 8,
  },
  themeStatusLightCoreActive: {
    backgroundColor: '#007AFF',
  },
  streakStatusLightActive: {
    backgroundColor: '#FFE8BF',
    elevation: 4,
    shadowColor: '#FF9F0A',
    shadowOffset: { height: 0, width: 0 },
    shadowOpacity: 0.42,
    shadowRadius: 7,
  },
  streakStatusLightCoreActive: {
    backgroundColor: '#FF9F0A',
  },
  settingsEntryButton: {
    alignItems: 'center',
    backgroundColor: '#FFFFFF',
    borderRadius: 14,
    borderCurve: 'continuous',
    flexDirection: 'row',
    gap: 12,
    minHeight: 68,
    padding: 14,
  },
  settingsEntryIcon: {
    alignItems: 'center',
    backgroundColor: '#EAF4FF',
    borderRadius: 11,
    borderCurve: 'continuous',
    height: 42,
    justifyContent: 'center',
    width: 42,
  },
  settingsEntryTitle: {
    fontFamily: ROUNDED_FONT,
    color: '#1C1C1E',
    fontSize: 17,
    fontWeight: '700',
  },
  settingsEntryText: {
    color: '#6C6C70',
    fontSize: 12,
    fontWeight: '500',
    lineHeight: 17,
    marginTop: 3,
  },
  developerCard: {
    backgroundColor: '#FFFFFF',
    borderRadius: 14,
    borderCurve: 'continuous',
    gap: 13,
    padding: 16,
  },
  developerText: {
    color: '#6C6C70',
    fontSize: 13,
    lineHeight: 20,
  },
  developerStats: {
    backgroundColor: '#F7FAFF',
    borderColor: '#D6E9FF',
    borderRadius: 14,
    borderCurve: 'continuous',
    borderWidth: 0,
    flexDirection: 'row',
    gap: 12,
    justifyContent: 'space-between',
    padding: 12,
  },
  developerLabel: {
    color: '#6C6C70',
    fontSize: 12,
    fontWeight: '600',
  },
  developerValue: {
    color: '#1C1C1E',
    fontSize: 15,
    fontWeight: '700',
    marginTop: 3,
  },
  developerSummary: {
    color: '#248A3D',
    fontSize: 12,
    fontWeight: '600',
    lineHeight: 18,
  },
  developerMessage: {
    color: '#6C6C70',
    fontSize: 12,
    fontWeight: '500',
    lineHeight: 18,
  },
  developerActionButton: {
    alignItems: 'center',
    backgroundColor: 'rgba(120, 120, 128, 0.12)',
    borderColor: '#D6E9FF',
    borderRadius: 12,
    borderCurve: 'continuous',
    borderWidth: 0,
    flex: 1,
    flexDirection: 'row',
    gap: 7,
    justifyContent: 'center',
    minHeight: 46,
    paddingHorizontal: 10,
  },
  developerActionText: {
    color: '#1C1C1E',
    flexShrink: 1,
    fontSize: 13,
    fontWeight: '600',
    textAlign: 'center',
  },
  developerPrimaryButton: {
    alignItems: 'center',
    backgroundColor: '#007AFF',
    borderRadius: 12,
    borderCurve: 'continuous',
    flex: 1,
    flexDirection: 'row',
    gap: 7,
    justifyContent: 'center',
    minHeight: 46,
    paddingHorizontal: 10,
  },
  developerPrimaryText: {
    color: '#FFFFFF',
    flexShrink: 1,
    fontSize: 13,
    fontWeight: '600',
    textAlign: 'center',
  },
  developerClearButton: {
    alignItems: 'center',
    alignSelf: 'stretch',
    backgroundColor: '#FFF4E5',
    borderColor: '#FFD7A8',
    borderRadius: 12,
    borderCurve: 'continuous',
    borderWidth: 0,
    flexDirection: 'row',
    gap: 7,
    justifyContent: 'center',
    minHeight: 42,
    paddingHorizontal: 12,
  },
  developerClearText: {
    color: '#A94400',
    fontSize: 13,
    fontWeight: '600',
  },
  deleteAccountDataButton: {
    alignItems: 'center',
    backgroundColor: '#FFF0EF',
    borderColor: '#FFC9C5',
    borderRadius: 12,
    borderCurve: 'continuous',
    borderWidth: 0,
    flexDirection: 'row',
    gap: 10,
    minHeight: 58,
    paddingHorizontal: 12,
    paddingVertical: 10,
  },
  deleteAccountDataTitle: {
    color: '#D70015',
    fontSize: 15,
    fontWeight: '700',
  },
  deleteAccountDataText: {
    color: '#D70015',
    fontSize: 12,
    fontWeight: '500',
    lineHeight: 17,
    marginTop: 2,
  },
  studyCardFace: {
    flex: 1,
    gap: 14,
  },
  studyRevealPrompt: {
    alignItems: 'center',
    backgroundColor: '#F4F8FD',
    borderColor: '#C7DDF5',
    borderRadius: 14,
    borderCurve: 'continuous',
    borderStyle: 'dashed',
    borderWidth: 0,
    flex: 1,
    gap: 10,
    justifyContent: 'center',
    paddingHorizontal: 24,
  },
  studyRevealPromptText: {
    color: '#3A6EA5',
    fontSize: 15,
    fontWeight: '600',
    lineHeight: 21,
    textAlign: 'center',
  },
  studySessionHeader: {
    gap: 8,
    paddingHorizontal: 2,
  },
  studySessionMeta: {
    flexShrink: 1,
    gap: 2,
  },
  studyAutoRevealToggle: {
    alignItems: 'center',
    backgroundColor: 'rgba(120, 120, 128, 0.12)',
    borderRadius: 999,
    flexDirection: 'row',
    flexShrink: 0,
    gap: 6,
    paddingLeft: 10,
    paddingRight: 6,
    paddingVertical: 6,
  },
  studyAutoRevealToggleOn: {
    backgroundColor: 'rgba(0, 122, 255, 0.12)',
  },
  studyAutoRevealText: {
    color: '#3A3A3C',
    fontSize: 13,
    fontWeight: '600',
  },
  studyAutoRevealTextOn: {
    color: '#0066CC',
  },
  studyAutoRevealTrack: {
    backgroundColor: '#C7C7CC',
    borderRadius: 999,
    height: 18,
    justifyContent: 'center',
    paddingHorizontal: 2,
    width: 30,
  },
  studyAutoRevealTrackOn: {
    backgroundColor: '#34C759',
  },
  studyAutoRevealKnob: {
    backgroundColor: '#FFFFFF',
    borderRadius: 7,
    height: 14,
    width: 14,
  },
  studyAutoRevealKnobOn: {
    alignSelf: 'flex-end',
  },
  studySessionLabel: {
    fontFamily: ROUNDED_FONT,
    color: '#1C1C1E',
    fontSize: 15,
    fontVariant: ['tabular-nums'],
    fontWeight: '700',
  },
  studySessionGoal: {
    color: '#6C6C70',
    fontSize: 13,
    fontVariant: ['tabular-nums'],
    fontWeight: '600',
  },
  studySessionTrack: {
    height: 5,
  },
  studyGradeRow: {
    alignItems: 'stretch',
    flexDirection: 'row',
    gap: 10,
  },
  studyUndoButton: {
    alignItems: 'center',
    backgroundColor: 'rgba(120, 120, 128, 0.12)',
    borderColor: '#D1D1D6',
    borderRadius: 14,
    borderCurve: 'continuous',
    borderWidth: 0,
    justifyContent: 'center',
    minHeight: 54,
    width: 54,
  },
  studyGradeButton: {
    alignItems: 'center',
    borderRadius: 14,
    borderCurve: 'continuous',
    flex: 1,
    flexDirection: 'row',
    gap: 8,
    justifyContent: 'center',
    minHeight: 54,
    paddingHorizontal: 12,
  },
  studyGradeReview: {
    backgroundColor: '#FFF0EF',
    borderColor: '#FFC9C5',
    borderWidth: 0,
  },
  studyGradeKnown: {
    backgroundColor: '#34C759',
  },
  studyRevealButton: {
    backgroundColor: '#007AFF',
  },
  studyGradeText: {
    fontSize: 16,
    fontWeight: '700',
  },
  studyGradeReviewText: {
    color: '#D70015',
  },
  studyGradeKnownText: {
    color: '#FFFFFF',
  },
  studyKeyboardHint: {
    color: '#8E8E93',
    fontSize: 12,
    textAlign: 'center',
  },
  sessionSummaryCard: {
    alignItems: 'stretch',
    backgroundColor: '#FFFFFF',
    borderColor: '#D1D1D6',
    borderRadius: 24,
    borderCurve: 'continuous',
    borderWidth: 0,
    gap: 12,
    padding: 20,
  },
  sessionSummaryIcon: {
    alignItems: 'center',
    alignSelf: 'center',
    backgroundColor: '#FFF4E5',
    borderRadius: 30,
    height: 60,
    justifyContent: 'center',
    width: 60,
  },
  sessionSummaryText: {
    fontSize: 15,
    textAlign: 'center',
  },
  sessionSummaryStats: {
    backgroundColor: '#F7FAFF',
    borderRadius: 14,
    flexDirection: 'row',
    overflow: 'hidden',
  },
  sessionSummaryGoal: {
    fontSize: 14,
    textAlign: 'center',
  },
  sessionSummaryWideButton: {
    flex: 0,
    minHeight: 48,
  },
  quizPromptLabel: {
    color: '#6C6C70',
    fontSize: 13,
    fontWeight: '600',
  },
  quizOptionWrong: {
    backgroundColor: '#FFF0EF',
    borderColor: '#FF8A80',
  },
  quizOptionTextWrong: {
    color: '#D70015',
  },
  quizOptionLetter: {
    alignItems: 'center',
    backgroundColor: '#EDF5FF',
    borderRadius: 14,
    height: 28,
    justifyContent: 'center',
    width: 28,
  },
  quizOptionLetterCorrect: {
    backgroundColor: '#34C759',
  },
  quizOptionLetterWrong: {
    backgroundColor: '#FF3B30',
  },
  quizOptionLetterText: {
    color: '#007AFF',
    fontSize: 13,
    fontWeight: '800',
  },
  quizNextButton: {
    minHeight: 54,
  },
  quizQuitButton: {
    alignItems: 'center',
    backgroundColor: 'rgba(120, 120, 128, 0.12)',
    borderColor: '#D1D1D6',
    borderRadius: 999,
    borderWidth: 0,
    flexDirection: 'row',
    gap: 4,
    paddingHorizontal: 12,
    paddingVertical: 6,
  },
  quizQuitText: {
    color: '#1C1C1E',
    fontSize: 13,
    fontWeight: '600',
  },
  quizResultEyebrow: {
    marginBottom: 0,
    textAlign: 'center',
  },
  quizResultTitle: {
    textAlign: 'center',
  },
  quizScoreRing: {
    alignItems: 'center',
    alignSelf: 'center',
    borderRadius: 56,
    borderWidth: 0,
    height: 112,
    justifyContent: 'center',
    width: 112,
  },
  quizScoreRingGood: {
    borderColor: '#34C759',
  },
  quizScoreRingOkay: {
    borderColor: '#FF9500',
  },
  quizScoreRingLow: {
    borderColor: '#FF3B30',
  },
  quizScoreRingValue: {
    fontFamily: ROUNDED_FONT,
    color: '#1C1C1E',
    fontSize: 28,
    fontVariant: ['tabular-nums'],
    fontWeight: '800',
  },
  quizMissedList: {
    gap: 8,
  },
  quizMissedRow: {
    alignItems: 'baseline',
    flexDirection: 'row',
    gap: 10,
    justifyContent: 'space-between',
  },
  quizMissedWord: {
    color: '#1C1C1E',
    flexShrink: 0,
    fontSize: 16,
    fontWeight: '700',
    maxWidth: '50%',
  },
  quizMissedMeaning: {
    flexShrink: 1,
    fontSize: 14,
    textAlign: 'right',
  },
  settingStackedRow: {
    alignItems: 'stretch',
    flexDirection: 'column',
    gap: 12,
  },
  settingStackedHeader: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: 12,
  },
  homeHeroEyebrow: {
    marginBottom: 0,
  },
  homeStreakPill: {
    alignItems: 'center',
    backgroundColor: '#FFF4E5',
    borderRadius: 999,
    flexDirection: 'row',
    gap: 4,
    marginTop: 8,
    paddingHorizontal: 10,
    paddingVertical: 4,
  },
  homeStreakText: {
    color: '#C25E00',
    fontSize: 13,
    fontVariant: ['tabular-nums'],
    fontWeight: '700',
  },
  homePlanText: {
    fontSize: 15,
    fontWeight: '600',
    marginTop: 6,
  },
  homeProgressCount: {
    fontVariant: ['tabular-nums'],
  },
  progressFillDone: {
    backgroundColor: '#34C759',
  },
  homeQuizIcon: {
    backgroundColor: '#EDF5FF',
  },
  wordBankBar: {
    alignItems: 'center',
    backgroundColor: '#FFFFFF',
    borderColor: '#D1D1D6',
    borderRadius: 20,
    borderCurve: 'continuous',
    borderWidth: 0,
    flexDirection: 'row',
    gap: 8,
    minHeight: 48,
    paddingHorizontal: 12,
    paddingVertical: 8,
  },
  wordBankIcon: {
    alignItems: 'center',
    backgroundColor: '#EDF5FF',
    borderRadius: 9,
    height: 30,
    justifyContent: 'center',
    width: 30,
  },
  wordBankLabel: {
    color: '#6C6C70',
    fontSize: 13,
    fontWeight: '600',
  },
  wordBankName: {
    fontFamily: ROUNDED_FONT,
    color: '#1C1C1E',
    flex: 1,
    fontSize: 16,
    fontWeight: '700',
  },
  wordBankCount: {
    color: '#6C6C70',
    fontSize: 13,
    fontVariant: ['tabular-nums'],
  },
  wordBankSheetRoot: {
    flex: 1,
    justifyContent: 'flex-end',
  },
  wordBankSheetBackdrop: {
    backgroundColor: 'rgba(0, 0, 0, 0.32)',
  },
  wordBankSheet: {
    backgroundColor: '#F2F2F7',
    borderTopLeftRadius: 22,
    borderTopRightRadius: 22,
    gap: 14,
    maxHeight: '82%',
    paddingHorizontal: 18,
    paddingTop: 8,
  },
  wordBankList: {
    flexGrow: 0,
  },
  wordBankRowActive: {
    borderColor: '#007AFF',
    borderWidth: 1.5,
  },
  wordBankActions: {
    flexDirection: 'row',
    gap: 10,
  },
  wordBankManageButton: {
    flex: 0,
    flexShrink: 0,
    minWidth: 84,
    paddingHorizontal: 18,
  },
  homeHeroRow: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: 18,
  },
  homeHeroCopy: {
    alignItems: 'flex-start',
    flex: 1,
    gap: 2,
  },
  homeHeroTitle: {
    fontSize: 24,
    lineHeight: 30,
  },
  homeRingLabel: {
    alignItems: 'center',
    justifyContent: 'center',
  },
  homeRingValue: {
    color: '#1C1C1E',
    fontFamily: ROUNDED_FONT,
    fontSize: 32,
    fontVariant: ['tabular-nums'],
    fontWeight: '800',
    lineHeight: 36,
  },
  homeRingTarget: {
    color: '#8E8E93',
    fontFamily: ROUNDED_FONT,
    fontSize: 13,
    fontVariant: ['tabular-nums'],
    fontWeight: '600',
  },
  homePrimaryButton: {
    borderRadius: 999,
    minHeight: 52,
  },
  homePrimaryButtonText: {
    fontSize: 17,
  },
  wordBankToolbar: {
    alignItems: 'stretch',
    flexDirection: 'row',
    gap: 8,
  },
  wordBankFilterButton: {
    alignItems: 'center',
    backgroundColor: '#FFFFFF',
    borderRadius: 20,
    borderCurve: 'continuous',
    justifyContent: 'center',
    minHeight: 48,
    width: 52,
  },
  filterInlineSummary: {
    color: '#6C6C70',
    fontSize: 13,
    fontWeight: '600',
    paddingHorizontal: 4,
  },
  homeRowValue: {
    color: '#8E8E93',
    fontSize: 16,
    fontVariant: ['tabular-nums'],
  },
});

const darkStyles = StyleSheet.create({
  safeArea: {
    backgroundColor: '#000000',
  },
  appShell: {
    backgroundColor: '#000000',
  },
  primaryButton: {
    backgroundColor: '#0A84FF',
  },
  confirmButton: {
    backgroundColor: '#0A84FF',
  },
  progressFill: {
    backgroundColor: '#0A84FF',
  },
  accountButton: {
    backgroundColor: '#0A84FF',
  },
  customSetPrimaryActionButton: {
    backgroundColor: '#0A84FF',
  },
  developerPrimaryButton: {
    backgroundColor: '#0A84FF',
  },
  filterChipActive: {
    backgroundColor: '#0A84FF',
    borderColor: '#0A84FF',
  },
  letterChipActive: {
    backgroundColor: '#0A84FF',
    borderColor: '#0A84FF',
  },
  quizModeButtonActive: {
    backgroundColor: '#0A84FF',
  },
  quizCountChipActive: {
    backgroundColor: '#0A84FF',
    borderColor: '#0A84FF',
  },
  appleButton: {
    backgroundColor: '#FFFFFF',
    borderColor: '#FFFFFF',
  },
  appleIconMark: {
    backgroundColor: '#F2F2F7',
    borderColor: '#D1D1D6',
  },
  appleButtonTitle: {
    color: '#000000',
  },
  appleButtonText: {
    color: '#3A3A3C',
  },
  previewModePill: {
    backgroundColor: 'rgba(10, 132, 255, 0.18)',
    borderColor: '#0A84FF',
  },
  previewModeText: {
    color: '#0A84FF',
  },
  brand: {
    color: '#FFFFFF',
  },
  headerSubtext: {
    color: '#AEAEB2',
  },
  levelPill: {
    backgroundColor: '#12351E',
    borderColor: '#30D158',
  },
  levelText: {
    color: '#30D158',
  },
  updateRequiredOverlay: {
    backgroundColor: 'rgba(0, 0, 0, 0.84)',
  },
  updateRequiredCard: {
    backgroundColor: '#1C1C1E',
    borderColor: '#3A3A3C',
  },
  updateRequiredIcon: {
    backgroundColor: 'rgba(10, 132, 255, 0.18)',
    borderColor: '#0A84FF',
  },
  updateRequiredTitle: {
    color: '#FFFFFF',
  },
  updateRequiredText: {
    color: '#AEAEB2',
  },
  updateRequiredCountdown: {
    color: '#0A84FF',
  },
  hero: {
    backgroundColor: '#1C1C1E',
    borderColor: '#3A3A3C',
  },
  heroTitle: {
    color: '#FFFFFF',
  },
  modeSwitchButton: {
    backgroundColor: '#1C1C1E',
    borderColor: '#29466A',
  },
  modeSwitchIcon: {
    backgroundColor: 'rgba(10, 132, 255, 0.18)',
  },
  modeSwitchTitle: {
    color: '#FFFFFF',
  },
  modeSwitchText: {
    color: '#AEAEB2',
  },
  installGuideOverlay: {
    backgroundColor: '#000000',
  },
  installGuideLogo: {
    backgroundColor: '#2563EB',
    borderColor: '#0A84FF',
  },
  installGuideClose: {
    backgroundColor: 'rgba(120, 120, 128, 0.24)',
    borderColor: '#3A3A3C',
  },
  installGuideCard: {
    backgroundColor: '#1C1C1E',
    borderColor: '#3A3A3C',
    shadowColor: '#000000',
    shadowOpacity: 0.2,
  },
  installGuideStepPill: {
    backgroundColor: 'rgba(10, 132, 255, 0.18)',
    borderColor: '#0A84FF',
  },
  installGuideStepText: {
    color: '#0A84FF',
  },
  installGuideIconWrap: {
    backgroundColor: 'rgba(10, 132, 255, 0.18)',
    borderColor: '#0A84FF',
  },
  installGuideIconGlow: {
    backgroundColor: '#0A84FF',
  },
  installGuideTitle: {
    color: '#FFFFFF',
  },
  installGuideText: {
    color: '#AEAEB2',
  },
  installGuidePreview: {
    backgroundColor: '#000000',
    borderColor: '#3A3A3C',
  },
  installGuideBrowserBar: {
    backgroundColor: '#636366',
  },
  installGuideMiniStep: {
    backgroundColor: '#1C1C1E',
    borderColor: '#3A3A3C',
  },
  installGuideMiniText: {
    color: '#AEAEB2',
  },
  installGuideDot: {
    backgroundColor: '#636366',
  },
  installGuideSecondary: {
    backgroundColor: 'rgba(120, 120, 128, 0.24)',
    borderColor: '#3A3A3C',
  },
  installGuideSecondaryText: {
    color: '#F2F2F7',
  },
  installGuidePrimary: {
    backgroundColor: '#0A84FF',
  },
  progressCard: {
    backgroundColor: '#1C1C1E',
    borderColor: '#3A3A3C',
  },
  sectionTitle: {
    color: '#FFFFFF',
  },
  cardMeta: {
    color: '#AEAEB2',
  },
  progressTrack: {
    backgroundColor: '#2C2C2E',
  },
  accountShortcut: {
    backgroundColor: '#1C1C1E',
    borderColor: '#29466A',
  },
  accountShortcutText: {
    color: '#F2F2F7',
  },
  homeUpdateButton: {
    backgroundColor: '#1C1C1E',
    borderColor: '#29466A',
  },
  homeUpdateIcon: {
    backgroundColor: 'rgba(10, 132, 255, 0.2)',
  },
  homeUpdateTitle: {
    color: '#FFFFFF',
  },
  homeUpdateText: {
    color: '#AEAEB2',
  },
  homeDictionaryCard: {
    backgroundColor: '#1C1C1E',
    borderColor: '#3A3A3C',
  },
  homeDictionarySearch: {
    backgroundColor: '#1C1C1E',
    borderColor: '#29466A',
  },
  homeDictionaryLauncherIcon: {
    backgroundColor: 'rgba(10, 132, 255, 0.24)',
  },
  homeDictionaryInput: {
    color: '#FFFFFF',
  },
  homeDictionaryModalRootNative: {
    backgroundColor: '#000000',
  },
  homeDictionaryModalSheet: {
    backgroundColor: '#1C1C1E',
    borderColor: '#3A3A3C',
  },
  homeDictionaryResultRow: {
    borderBottomColor: '#3A3A3C',
  },
  iconButton: {
    backgroundColor: 'rgba(10, 132, 255, 0.16)',
    borderColor: 'rgba(10, 132, 255, 0.32)',
  },
  homeGroupedSurface: {
    backgroundColor: '#1C1C1E',
    borderColor: '#3A3A3C',
  },
  homeDivider: {
    backgroundColor: '#3A3A3C',
  },
  statCard: {
    backgroundColor: 'transparent',
    borderColor: '#3A3A3C',
  },
  statValue: {
    color: '#FFFFFF',
  },
  statLabel: {
    color: '#AEAEB2',
  },
  reviewStrip: {
    backgroundColor: '#1C1C1E',
    borderColor: '#3A3A3C',
  },
  reviewTitle: {
    color: '#FFFFFF',
  },
  reviewText: {
    color: '#AEAEB2',
  },
  reviewIcon: {
    backgroundColor: '#3A2608',
  },
  emptyState: {
    backgroundColor: '#1C1C1E',
    borderColor: '#3A3A3C',
  },
  emptyTitle: {
    color: '#FFFFFF',
  },
  emptyText: {
    color: '#AEAEB2',
  },
  wordCard: {
    backgroundColor: '#1C1C1E',
    borderColor: '#3A3A3C',
  },
  groupPill: {
    backgroundColor: 'rgba(10, 132, 255, 0.18)',
  },
  groupText: {
    color: '#0A84FF',
  },
  bigWord: {
    color: '#FFFFFF',
  },
  pronunciation: {
    color: '#AEAEB2',
  },
  pinyinText: {
    color: '#0A84FF',
  },
  meaningBlock: {
    borderTopColor: '#3A3A3C',
  },
  meaning: {
    color: '#F2F2F7',
  },
  studySupplement: {
    borderTopColor: '#3A3A3C',
  },
  studySupplementLabel: {
    color: '#8E8E93',
  },
  studySupplementText: {
    color: '#D1D1D6',
  },
  exampleBox: {
    backgroundColor: '#1C1C1E',
    borderColor: '#29466A',
  },
  example: {
    color: '#FFFFFF',
  },
  exampleZh: {
    color: '#AEAEB2',
  },
  secondaryButton: {
    backgroundColor: 'rgba(120, 120, 128, 0.24)',
    borderColor: '#376694',
  },
  secondaryButtonText: {
    color: '#F2F2F7',
  },
  foldedFilterCard: {
    backgroundColor: '#1C1C1E',
    borderColor: '#3A3A3C',
  },
  filterSummaryButtonOpen: {
    backgroundColor: 'rgba(10, 132, 255, 0.12)',
  },
  filterPanel: {
    borderTopColor: '#3A3A3C',
  },
  filterSummaryTitle: {
    color: '#FFFFFF',
  },
  filterSummaryText: {
    color: '#AEAEB2',
  },
  filterSectionTitle: {
    color: '#AEAEB2',
  },
  filterChip: {
    backgroundColor: 'rgba(120, 120, 128, 0.24)',
    borderColor: '#29466A',
  },
  filterText: {
    color: '#AEAEB2',
  },
  letterChip: {
    backgroundColor: 'rgba(120, 120, 128, 0.24)',
    borderColor: '#29466A',
  },
  quizSetupCard: {
    backgroundColor: '#1C1C1E',
    borderColor: '#3A3A3C',
  },
  quizModeCard: {
    backgroundColor: '#1C1C1E',
    borderColor: '#3A3A3C',
  },
  quizSectionDivider: {
    backgroundColor: 'rgba(84, 84, 88, 0.55)',
  },
  quizModeSwitch: {
    backgroundColor: '#1C1C1E',
    borderColor: '#29466A',
  },
  quizModeButton: {
    backgroundColor: 'transparent',
  },
  quizModeButtonText: {
    color: '#AEAEB2',
  },
  quizCountChip: {
    backgroundColor: 'rgba(120, 120, 128, 0.24)',
    borderColor: '#29466A',
  },
  quizCountText: {
    color: '#F2F2F7',
  },
  quizCountMeta: {
    color: '#AEAEB2',
  },
  quizCard: {
    backgroundColor: '#1C1C1E',
    borderColor: '#3A3A3C',
  },
  quizNextTopButton: {
    backgroundColor: 'rgba(120, 120, 128, 0.24)',
    borderColor: '#29466A',
  },
  quizNextTopText: {
    color: '#F2F2F7',
  },
  quizOption: {
    backgroundColor: 'rgba(120, 120, 128, 0.24)',
    borderColor: '#29466A',
  },
  quizOptionPressed: {
    backgroundColor: 'rgba(10, 132, 255, 0.18)',
    borderColor: '#0A84FF',
  },
  quizOptionText: {
    color: '#F2F2F7',
  },
  resultCard: {
    backgroundColor: '#1C1C1E',
    borderColor: '#3A3A3C',
  },
  resultTitle: {
    color: '#FFFFFF',
  },
  quizScoreText: {
    color: '#FFFFFF',
  },
  quizExampleCard: {
    backgroundColor: '#1C1C1E',
    borderColor: '#29466A',
  },
  quizExampleLabel: {
    color: '#AEAEB2',
  },
  speakingIconWrap: {
    backgroundColor: 'rgba(10, 132, 255, 0.18)',
    borderColor: '#0A84FF',
  },
  speakingSecondaryButton: {
    backgroundColor: 'rgba(120, 120, 128, 0.24)',
    borderColor: '#29466A',
  },
  speakingSecondaryText: {
    color: '#F2F2F7',
  },
  resultText: {
    color: '#AEAEB2',
  },
  speakingPromptQuestion: {
    color: '#FFFFFF',
  },
  libraryFloatingTopButton: {
    backgroundColor: 'rgba(120, 120, 128, 0.24)',
    borderColor: '#3A3A3C',
    shadowColor: '#000000',
  },
  libraryFloatingTopText: {
    color: '#F2F2F7',
  },
  libraryDragSlider: {
    backgroundColor: 'transparent',
    borderColor: 'transparent',
  },
  libraryDragTrack: {
    backgroundColor: '#F2F2F7',
  },
  libraryDragThumb: {
    backgroundColor: '#0A84FF',
    borderColor: 'transparent',
  },
  libraryHeaderCard: {
    backgroundColor: '#1C1C1E',
    borderColor: '#3A3A3C',
  },
  libraryCustomSetsCard: {
    backgroundColor: '#1C1C1E',
    borderColor: '#29466A',
  },
  libraryHeaderMetaPill: {
    backgroundColor: 'rgba(10, 132, 255, 0.18)',
    borderColor: '#0A84FF',
  },
  libraryHeaderMetaPillText: {
    color: '#0A84FF',
  },
  libraryHeaderTitle: {
    color: '#FFFFFF',
  },
  libraryHeaderMeta: {
    color: '#AEAEB2',
  },
  libraryCustomSetsTitle: {
    color: '#FFFFFF',
  },
  libraryTopButton: {
    backgroundColor: 'rgba(120, 120, 128, 0.24)',
    borderColor: '#29466A',
  },
  libraryTopButtonText: {
    color: '#F2F2F7',
  },
  searchBox: {
    backgroundColor: 'rgba(120, 120, 128, 0.24)',
    borderColor: '#29466A',
  },
  searchBoxActive: {
    backgroundColor: '#2C2C2E',
    borderColor: '#0A84FF',
  },
  resultCorrect: {
    backgroundColor: '#12351E',
    borderColor: '#30D158',
  },
  resultWrong: {
    backgroundColor: '#3A1714',
    borderColor: '#FF453A',
  },
  syncPill: {
    backgroundColor: '#12351E',
    borderColor: '#30D158',
  },
  syncPillError: {
    backgroundColor: '#3A1714',
    borderColor: '#FF453A',
  },
  syncText: {
    color: '#30D158',
  },
  syncTextError: {
    color: '#FF453A',
  },
  signOutButton: {
    backgroundColor: '#3A1714',
    borderColor: '#FF453A',
  },
  signOutButtonText: {
    color: '#FF453A',
  },
  searchInput: {
    color: '#FFFFFF',
  },
  searchClearButton: {
    backgroundColor: 'rgba(10, 132, 255, 0.18)',
  },
  searchMetaBox: {
    backgroundColor: 'rgba(10, 132, 255, 0.18)',
    borderColor: '#0A84FF',
  },
  searchMetaText: {
    color: '#0A84FF',
  },
  libraryItem: {
    backgroundColor: '#1C1C1E',
    borderColor: '#3A3A3C',
  },
  libraryItemPressed: {
    backgroundColor: 'rgba(0, 122, 255, 0.18)',
  },
  libraryItemPressedLift: {
    borderColor: '#0A84FF',
    shadowColor: '#0A84FF',
    shadowOpacity: 0.16,
  },
  libraryWord: {
    color: '#FFFFFF',
  },
  libraryPinyin: {
    color: '#0A84FF',
  },
  libraryMeaning: {
    color: '#F2F2F7',
  },
  librarySupplemental: {
    color: '#AEAEB2',
  },
  libraryExample: {
    color: '#AEAEB2',
  },
  statusText: {
    color: '#AEAEB2',
  },
  libraryDetailBack: {
    backgroundColor: 'rgba(120, 120, 128, 0.24)',
    borderColor: '#29466A',
  },
  libraryDetailBackText: {
    color: '#F2F2F7',
  },
  libraryDetailPage: {
    backgroundColor: '#1C1C1E',
    borderColor: '#3A3A3C',
  },
  libraryDetailWord: {
    color: '#FFFFFF',
  },
  libraryDetailPronunciation: {
    color: '#AEAEB2',
  },
  libraryDetailPinyin: {
    color: '#0A84FF',
  },
  libraryDetailSection: {
    borderTopColor: '#3A3A3C',
  },
  libraryDetailLabel: {
    color: '#AEAEB2',
  },
  libraryDetailMeaning: {
    color: '#FFFFFF',
  },
  libraryDetailExampleCard: {
    backgroundColor: '#1C1C1E',
    borderColor: '#29466A',
  },
  libraryDetailExample: {
    color: '#FFFFFF',
  },
  libraryDetailDivider: {
    backgroundColor: '#3A3A3C',
  },
  libraryDetailExampleZh: {
    color: '#AEAEB2',
  },
  profileCard: {
    backgroundColor: '#1C1C1E',
    borderColor: '#3A3A3C',
  },
  avatar: {
    backgroundColor: '#1C1C1E',
    borderColor: '#29466A',
  },
  profileTitle: {
    color: '#FFFFFF',
  },
  profileText: {
    color: '#AEAEB2',
  },
  accountCard: {
    backgroundColor: '#1C1C1E',
    borderColor: '#3A3A3C',
  },
  accountUpgradeOverlay: {
    backgroundColor: 'rgba(0, 0, 0, 0.64)',
  },
  accountUpgradePanel: {
    backgroundColor: 'rgba(28, 28, 30, 0.98)',
    borderColor: '#3A3A3C',
  },
  accountUpgradeHandle: {
    backgroundColor: 'rgba(235, 235, 245, 0.3)',
  },
  accountUpgradeIcon: {
    backgroundColor: '#1C1C1E',
    borderColor: '#29466A',
  },
  accountUpgradeClose: {
    backgroundColor: 'rgba(58, 58, 60, 0.78)',
    borderColor: '#636366',
  },
  accountUpgradeTitle: {
    color: '#FFFFFF',
  },
  accountUpgradeBody: {
    color: '#C7C7CC',
  },
  accountUpgradeMemoryPill: {
    backgroundColor: 'rgba(48, 209, 88, 0.14)',
    borderColor: 'rgba(48, 209, 88, 0.36)',
  },
  accountUpgradeMemoryText: {
    color: '#30D158',
  },
  accountUpgradeGoogleButton: {
    backgroundColor: 'rgba(44, 44, 46, 0.76)',
    borderColor: '#636366',
  },
  accountUpgradeGoogleText: {
    color: '#FFFFFF',
  },
  accountUpgradePrivacy: {
    color: '#AEAEB2',
  },
  accountUpgradeLaterText: {
    color: '#0A84FF',
  },
  googleButton: {
    backgroundColor: 'rgba(120, 120, 128, 0.24)',
    borderColor: '#29466A',
  },
  googleIconMark: {
    backgroundColor: 'rgba(10, 132, 255, 0.14)',
    borderColor: '#29466A',
  },
  googleButtonTitle: {
    color: '#FFFFFF',
  },
  googleButtonText: {
    color: '#AEAEB2',
  },
  emailFallbackLabel: {
    color: '#AEAEB2',
  },
  localOnlyBox: {
    backgroundColor: '#1C1C1E',
    borderColor: '#29466A',
  },
  localOnlyTitle: {
    color: '#FFFFFF',
  },
  localOnlyText: {
    color: '#AEAEB2',
  },
  inputBox: {
    backgroundColor: 'rgba(120, 120, 128, 0.24)',
    borderColor: '#29466A',
  },
  accountInput: {
    color: '#FFFFFF',
  },
  outlineButton: {
    backgroundColor: 'rgba(120, 120, 128, 0.24)',
    borderColor: '#376694',
  },
  outlineButtonText: {
    color: '#F2F2F7',
  },
  activeSetBanner: {
    backgroundColor: 'rgba(10, 132, 255, 0.18)',
    borderColor: '#0A84FF',
  },
  activeSetTitle: {
    color: '#0A84FF',
  },
  activeSetText: {
    color: '#AEAEB2',
  },
  activeSetClearButton: {
    backgroundColor: 'rgba(120, 120, 128, 0.24)',
    borderColor: '#29466A',
  },
  activeSetClearText: {
    color: '#0A84FF',
  },
  customSetPickerCard: {
    backgroundColor: '#1C1C1E',
    borderColor: '#3A3A3C',
    shadowColor: '#000000',
  },
  customSetPickerTitle: {
    color: '#FFFFFF',
  },
  customSetPickerText: {
    color: '#AEAEB2',
  },
  customSetPickerRow: {
    backgroundColor: '#1C1C1E',
    borderColor: '#29466A',
  },
  customSetPickerEmpty: {
    color: '#AEAEB2',
  },
  customSetRowTitle: {
    color: '#FFFFFF',
  },
  customSetRowText: {
    color: '#AEAEB2',
  },
  customSetsHeroCard: {
    backgroundColor: '#1C1C1E',
    borderColor: '#3A3A3C',
  },
  customSetCard: {
    backgroundColor: '#1C1C1E',
    borderColor: '#3A3A3C',
  },
  customSetActionButton: {
    backgroundColor: 'rgba(120, 120, 128, 0.24)',
    borderColor: '#29466A',
  },
  customSetDeleteButton: {
    backgroundColor: '#3A1714',
    borderColor: '#FF453A',
  },
  customSetActionText: {
    color: '#F2F2F7',
  },
  customSetTinyMeta: {
    color: '#8E8E93',
  },
  settingsCard: {
    backgroundColor: '#1C1C1E',
    borderColor: '#3A3A3C',
  },
  profileInfoCard: {
    backgroundColor: '#1C1C1E',
    borderColor: '#3A3A3C',
  },
  learningMetric: {
    backgroundColor: '#1C1C1E',
    borderColor: '#29466A',
  },
  learningMetricLabel: {
    color: '#AEAEB2',
  },
  learningMetricValue: {
    color: '#FFFFFF',
  },
  settingOptionRow: {
    backgroundColor: '#1C1C1E',
    borderColor: '#29466A',
  },
  settingsEntryButton: {
    backgroundColor: '#1C1C1E',
    borderColor: '#3A3A3C',
  },
  settingsEntryIcon: {
    backgroundColor: '#1C1C1E',
    borderColor: '#29466A',
  },
  settingsEntryTitle: {
    color: '#FFFFFF',
  },
  settingsEntryText: {
    color: '#AEAEB2',
  },
  deleteAccountDataButton: {
    backgroundColor: '#3A1714',
    borderColor: '#FF453A',
  },
  deleteAccountDataTitle: {
    color: '#FF6961',
  },
  deleteAccountDataText: {
    color: '#FF6961',
  },
  developerCard: {
    backgroundColor: '#1C1C1E',
    borderColor: '#3A3A3C',
  },
  developerText: {
    color: '#AEAEB2',
  },
  developerStats: {
    backgroundColor: '#1C1C1E',
    borderColor: '#29466A',
  },
  developerLabel: {
    color: '#AEAEB2',
  },
  developerValue: {
    color: '#FFFFFF',
  },
  developerMessage: {
    color: '#AEAEB2',
  },
  developerActionButton: {
    backgroundColor: 'rgba(120, 120, 128, 0.24)',
    borderColor: '#29466A',
  },
  developerActionText: {
    color: '#F2F2F7',
  },
  studyRevealPrompt: {
    backgroundColor: '#1C1C1E',
    borderColor: '#2A4A70',
  },
  studyRevealPromptText: {
    color: '#8CC4FF',
  },
  studySessionLabel: {
    color: '#FFFFFF',
  },
  studyAutoRevealToggle: {
    backgroundColor: 'rgba(118, 118, 128, 0.24)',
  },
  studyAutoRevealToggleOn: {
    backgroundColor: 'rgba(10, 132, 255, 0.2)',
  },
  studyAutoRevealText: {
    color: '#EBEBF5',
  },
  studyAutoRevealTextOn: {
    color: '#0A84FF',
  },
  studyAutoRevealTrack: {
    backgroundColor: '#48484A',
  },
  studyGradeReview: {
    backgroundColor: '#3A1714',
    borderColor: '#6B2A24',
  },
  studyGradeReviewText: {
    color: '#FF6961',
  },
  sessionSummaryIcon: {
    backgroundColor: '#3A2608',
  },
  quizOptionLetter: {
    backgroundColor: '#2C2C2E',
  },
  quizOptionLetterText: {
    color: '#0A84FF',
  },
  quizQuitButton: {
    backgroundColor: 'rgba(120, 120, 128, 0.24)',
    borderColor: '#3A3A3C',
  },
  quizQuitText: {
    color: '#F2F2F7',
  },
  sessionSummaryStats: {
    backgroundColor: '#1C1C1E',
  },
  quizOptionCorrect: {
    backgroundColor: '#12351E',
    borderColor: '#30D158',
  },
  quizOptionTextCorrect: {
    color: '#30D158',
  },
  quizOptionWrong: {
    backgroundColor: '#3A1714',
    borderColor: '#FF453A',
  },
  quizOptionTextWrong: {
    color: '#FF6961',
  },
  homeStreakPill: {
    backgroundColor: '#3A2608',
  },
  homeQuizIcon: {
    backgroundColor: '#2C2C2E',
  },
  wordBankBar: {
    backgroundColor: '#1C1C1E',
    borderColor: '#3A3A3C',
  },
  wordBankIcon: {
    backgroundColor: '#2C2C2E',
  },
  wordBankSheet: {
    backgroundColor: '#111111',
  },
  statCardDivider: {
    borderLeftColor: '#38383A',
  },
});
