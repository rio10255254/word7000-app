import { StatusBar } from 'expo-status-bar';
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
import { createContext, useContext, useEffect, useMemo, useRef, useState, type ReactNode } from 'react';
import {
  Animated,
  Easing,
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
} from 'react-native';
import { sampleWords, type WordEntry } from './src/data/words';
import { scrollThumbOffset, wordWindowStartFromSlider } from './src/lib/libraryNavigation';
import {
  buildQuizOptions,
  buildQuizSession,
  computeStats,
  filterWords,
  markKnown,
  markReview,
  selectQuizWords,
  selectStudyWords,
  toggleFavorite,
  type QuizOption,
  type LibraryFilter,
  type ProgressState,
} from './src/lib/progress';
import { createAppSupabaseClient, type AppSupabaseClient } from './src/lib/supabaseClient';
import { loadProgressFromStorage, saveProgressToStorage, type StorageLike } from './src/lib/progressStorage';
import { loadCloudProgress, saveCloudProgress, type CloudProgressClient } from './src/lib/supabaseProgress';
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

type Tab = 'home' | 'study' | 'quiz' | 'library' | 'profile';
type ProfilePanel = 'overview' | 'settings';
type AccountStatus = 'local' | 'loading' | 'signedOut' | 'signedIn' | 'syncing' | 'saved' | 'error';
type ThemeMode = 'light' | 'dark';
type StudyMode = 'english' | 'chinese';

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
  message: string;
  refresh: () => void;
};
type FilterOption = {
  id: string;
  label: string;
};

const today = new Date().toISOString().slice(0, 10);
const UPDATE_STORAGE_KEY = 'word7000-version-v1';
const THEME_STORAGE_KEY = 'word7000-theme-v1';
const STUDY_MODE_STORAGE_KEY = 'word7000-study-mode-v1';
const LIBRARY_SLIDER_THUMB_HEIGHT = 42;
const LIBRARY_WINDOW_SIZE = 260;
const quizQuestionCounts = [10, 20, 50] as const;
const installGuideSteps = [
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
] as const;
const initialProgress: ProgressState = {
  dailyTarget: 20,
  streak: 1,
  studiedToday: 0,
  words: {},
};

const filters: Array<{ id: LibraryFilter; label: string }> = [
  { id: 'all', label: '全部' },
  { id: 'favorites', label: '收藏' },
  { id: 'review', label: '複習' },
  { id: 'mastered', label: '已會' },
  { id: 'new', label: '未背' },
];

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
    toggleTitle: '切到中文單字',
    toggleText: '把整個 App 換成中文單字練習',
    overlayTitle: '英文單字模式',
    overlayText: '回到看英文、想中文意思',
    heroEyebrow: 'ENGLISH MODE',
    heroTitle: '今天 20 個剛剛好',
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
    toggleTitle: 'Switch back to English words',
    toggleText: 'Return to the original English vocabulary app',
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
    reviewAgain: '再複習',
    known: '已會',
    filterStatus: '狀態',
    filterLevel: '分級',
    filterCountUnit: '個',
    filterLabels: {
      all: '全部',
      favorites: '收藏',
      review: '複習',
      mastered: '已會',
      new: '未背',
    },
    allLevels: '全部分級',
    allInitials: '全部',
    levelAccessibility: (label: string) => `分級 ${label}`,
    initialAccessibility: (label: string) => (label === 'all' ? '字首 全部' : `字首 ${label}`),
    questionCountTitle: '選擇題數',
    questionBankPrefix: '目前題庫',
    questionUnit: '題',
    cappedQuestionPrefix: '出',
    startQuiz: '開始測驗',
    quizFinished: '測驗完成',
    quizScore: (correct: number, total: number) => `答對 ${correct} / ${total} 題`,
    restartQuiz: '重新選題',
    correctResult: '答對了',
    wrongResult: '先放進複習',
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
    accountUnavailableTitle: '帳號登入尚未啟用',
    accountUnavailableText: '目前先用本機記憶；Cloudflare 設好 Supabase 後，這裡就能登入同步。',
    passwordPlaceholder: '密碼',
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
    reviewAgain: 'Review Again',
    known: 'I Know It',
    filterStatus: 'Status',
    filterLevel: 'Level',
    filterCountUnit: 'items',
    filterLabels: {
      all: 'All',
      favorites: 'Saved',
      review: 'Review',
      mastered: 'Known',
      new: 'New',
    },
    allLevels: 'All Levels',
    allInitials: 'All',
    levelAccessibility: (label: string) => `Level ${label}`,
    initialAccessibility: (label: string) => (label === 'all' ? 'First letter All' : `First letter ${label}`),
    questionCountTitle: 'Choose Question Count',
    questionBankPrefix: 'Question bank',
    questionUnit: 'questions',
    cappedQuestionPrefix: 'Uses',
    startQuiz: 'Start Quiz',
    quizFinished: 'Quiz Complete',
    quizScore: (correct: number, total: number) => `${correct} / ${total} correct`,
    restartQuiz: 'Choose Again',
    correctResult: 'Correct',
    wrongResult: 'Added to Review',
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
    accountUnavailableTitle: 'Account sign-in is not enabled yet',
    accountUnavailableText: 'Your progress is saved locally for now. After Supabase is connected on Cloudflare, sign-in sync will work here.',
    passwordPlaceholder: 'Password',
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
  },
} as const;

const levelFilters = buildLevelFilters(sampleWords);
const alphabetFilters: FilterOption[] = [
  { id: 'all', label: '全部' },
  ...'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.split('').map((letter) => ({
    id: letter,
    label: letter,
  })),
];
const ThemeContext = createContext<ThemeMode>('light');
const MotionPressable = Animated.createAnimatedComponent(Pressable);

export default function App() {
  const appScrollRef = useRef<ScrollView | null>(null);
  const launchAnim = useRef(new Animated.Value(0)).current;
  const installGuideAnim = useRef(new Animated.Value(0)).current;
  const screenAnim = useRef(new Animated.Value(1)).current;
  const cardAnim = useRef(new Animated.Value(1)).current;
  const libraryDetailAnim = useRef(new Animated.Value(1)).current;
  const modeTransitionAnim = useRef(new Animated.Value(0)).current;
  const [supabaseClient] = useState<AppSupabaseClient | null>(() => createAppSupabaseClient());
  const [activeTab, setActiveTab] = useState<Tab>('home');
  const [progress, setProgress] = useState<ProgressState>(initialProgress);
  const [progressReady, setProgressReady] = useState(false);
  const [wordIndex, setWordIndex] = useState(0);
  const [studyFilter, setStudyFilter] = useState<LibraryFilter>('all');
  const [studyLevel, setStudyLevel] = useState('all');
  const [studyInitial, setStudyInitial] = useState('all');
  const [studyFiltersOpen, setStudyFiltersOpen] = useState(false);
  const [quizIndex, setQuizIndex] = useState(0);
  const [quizResult, setQuizResult] = useState<'correct' | 'wrong' | null>(null);
  const [answeredQuizWord, setAnsweredQuizWord] = useState<WordEntry | null>(null);
  const [lockedQuizOptions, setLockedQuizOptions] = useState<QuizOption[] | null>(null);
  const [quizQuestionCount, setQuizQuestionCount] = useState<(typeof quizQuestionCounts)[number]>(10);
  const [quizSession, setQuizSession] = useState<WordEntry[]>([]);
  const [quizStarted, setQuizStarted] = useState(false);
  const [quizFinished, setQuizFinished] = useState(false);
  const [quizCorrectCount, setQuizCorrectCount] = useState(0);
  const [quizSeed, setQuizSeed] = useState('');
  const [searchQuery, setSearchQuery] = useState('');
  const [searchFocused, setSearchFocused] = useState(false);
  const [activeFilter, setActiveFilter] = useState<LibraryFilter>('all');
  const [activeLevel, setActiveLevel] = useState('all');
  const [activeInitial, setActiveInitial] = useState('all');
  const [libraryFiltersOpen, setLibraryFiltersOpen] = useState(false);
  const [quizFilter, setQuizFilter] = useState<LibraryFilter>('all');
  const [quizLevel, setQuizLevel] = useState('all');
  const [quizInitial, setQuizInitial] = useState('all');
  const [quizFiltersOpen, setQuizFiltersOpen] = useState(false);
  const [showLaunch, setShowLaunch] = useState(true);
  const [installGuideChecked, setInstallGuideChecked] = useState(false);
  const [showInstallGuide, setShowInstallGuide] = useState(false);
  const [installGuideStep, setInstallGuideStep] = useState(0);
  const [account, setAccount] = useState<AccountState>(() => createInitialAccountState(Boolean(supabaseClient)));
  const [profilePanel, setProfilePanel] = useState<ProfilePanel>('overview');
  const [themeMode, setThemeMode] = useState<ThemeMode>(() => loadThemeMode(getBrowserStorage()));
  const [studyMode, setStudyMode] = useState<StudyMode>(() => loadStudyMode(getBrowserStorage()));
  const [modeSwitchTarget, setModeSwitchTarget] = useState<StudyMode>(() =>
    loadStudyMode(getBrowserStorage()) === 'english' ? 'chinese' : 'english',
  );
  const [showModeSwitch, setShowModeSwitch] = useState(false);
  const [scrollY, setScrollY] = useState(0);
  const [sliderTrackHeight, setSliderTrackHeight] = useState(1);
  const [libraryWindowStart, setLibraryWindowStart] = useState(0);
  const [selectedLibraryWord, setSelectedLibraryWord] = useState<WordEntry | null>(null);
  const [developerVocabulary, setDeveloperVocabulary] = useState<DeveloperVocabularySnapshot | null>(() =>
    loadDeveloperVocabulary(getBrowserStorage()),
  );
  const [developerVocabularyMessage, setDeveloperVocabularyMessage] = useState(
    '可匯出 CSV 修改例句，再匯入成這台裝置的預覽字庫。',
  );

  const vocabularyWords = developerVocabulary?.words ?? sampleWords;
  const levelFilterOptions = useMemo(() => buildLevelFilters(vocabularyWords), [vocabularyWords]);
  const stats = useMemo(() => computeStats(vocabularyWords, progress), [progress, vocabularyWords]);
  const studyWords = useMemo(
    () =>
      selectStudyWords(vocabularyWords, progress, studyFilter, {
        initial: studyInitial,
        level: studyLevel,
      }),
    [progress, studyFilter, studyInitial, studyLevel, vocabularyWords],
  );
  const studyWord = studyWords.length > 0 ? studyWords[wordIndex % studyWords.length] : null;
  const quizWords = useMemo(
    () =>
      selectQuizWords(vocabularyWords, progress, quizFilter, {
        initial: quizInitial,
        level: quizLevel,
      }),
    [progress, quizFilter, quizInitial, quizLevel, vocabularyWords],
  );
  const quizWord = quizStarted && quizSession.length > 0 ? quizSession[quizIndex] ?? null : null;
  const quizOptionSource = quizWords.length >= 3 ? quizWords : vocabularyWords;
  const quizOptions = useMemo(
    () => (quizWord ? buildQuizOptions(quizOptionSource, quizWord.id, `${quizSeed}:${quizIndex}`, studyMode === 'chinese' ? 'word' : 'meaning') : []),
    [quizIndex, quizOptionSource, quizSeed, quizWord, studyMode],
  );
  const visibleQuizWord = answeredQuizWord ?? quizWord;
  const visibleQuizOptions = lockedQuizOptions ?? quizOptions;
  const quizSessionTotal = quizStarted || quizFinished ? quizSession.length : Math.min(quizQuestionCount, quizWords.length);
  const libraryWords = useMemo(
    () =>
      filterWords(vocabularyWords, progress, searchQuery, activeFilter, {
        initial: activeInitial,
        level: activeLevel,
      }),
    [activeFilter, activeInitial, activeLevel, progress, searchQuery, vocabularyWords],
  );
  const dailyPercent = Math.min(100, Math.round((stats.studiedToday / progress.dailyTarget) * 100));
  const updateState = useAppUpdateCheck();
  const themeStyles = themeMode === 'dark' ? darkStyles : undefined;
  const darkMode = themeMode === 'dark';
  const activeModeCopy = modeCopy[studyMode];
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
  const listMotionStyle = (index: number) => ({
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
  });
  const detailMotionStyle = {
    opacity: libraryDetailAnim,
    transform: [
      {
        translateY: libraryDetailAnim.interpolate({
          inputRange: [0, 1],
          outputRange: [14, 0],
        }),
      },
      {
        scale: libraryDetailAnim.interpolate({
          inputRange: [0, 1],
          outputRange: [0.975, 1],
        }),
      },
    ],
  };
  const modeOverlayScale = modeTransitionAnim.interpolate({
    inputRange: [0, 1],
    outputRange: [0.94, 1],
  });
  const modeOverlayTranslateY = modeTransitionAnim.interpolate({
    inputRange: [0, 1],
    outputRange: [18, 0],
  });
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
  const libraryThumbOffset = scrollThumbOffset(
    libraryWindowStart,
    Math.max(libraryWords.length, LIBRARY_WINDOW_SIZE + 1),
    LIBRARY_WINDOW_SIZE,
    sliderTrackHeight,
    LIBRARY_SLIDER_THUMB_HEIGHT,
  );
  const librarySliderResponder = useMemo(
    () =>
      PanResponder.create({
        onMoveShouldSetPanResponder: () => activeTab === 'library',
        onStartShouldSetPanResponder: () => activeTab === 'library',
        onPanResponderGrant: (event) => handleLibrarySliderDrag(event.nativeEvent.locationY),
        onPanResponderMove: (event) => handleLibrarySliderDrag(event.nativeEvent.locationY),
      }),
    [activeTab, libraryWords.length, sliderTrackHeight],
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
    saveThemeMode(getBrowserStorage(), themeMode);
  }, [themeMode]);

  useEffect(() => {
    saveStudyMode(getBrowserStorage(), studyMode);
  }, [studyMode]);

  useEffect(() => {
    if (showLaunch || installGuideChecked) {
      return;
    }

    setInstallGuideChecked(true);
    if (shouldShowInstallGuide(getBrowserStorage(), isInstalledWebApp())) {
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
    activeTab,
    cardAnim,
    developerVocabulary?.importedAt,
    libraryFiltersOpen,
    profilePanel,
    quizFilter,
    quizFiltersOpen,
    quizIndex,
    quizInitial,
    quizLevel,
    quizQuestionCount,
    quizStarted,
    quizFinished,
    searchQuery,
    selectedLibraryWord?.id,
    studyMode,
    studyFilter,
    studyFiltersOpen,
    studyInitial,
    studyLevel,
    wordIndex,
  ]);

  useEffect(() => {
    appScrollRef.current?.scrollTo({ y: 0, animated: false });
    setScrollY(0);
    setLibraryWindowStart(0);
    setSelectedLibraryWord(null);
  }, [activeTab, activeFilter, activeInitial, activeLevel, profilePanel, searchQuery]);

  useEffect(() => {
    if (activeTab !== 'profile') {
      setProfilePanel('overview');
    }
  }, [activeTab]);

  useEffect(() => {
    setWordIndex(0);
  }, [studyFilter, studyInitial, studyLevel]);

  useEffect(() => {
    setQuizIndex(0);
    setQuizResult(null);
    setAnsweredQuizWord(null);
    setLockedQuizOptions(null);
    setQuizSession([]);
    setQuizStarted(false);
    setQuizFinished(false);
    setQuizCorrectCount(0);
    setQuizSeed('');
  }, [quizFilter, quizInitial, quizLevel]);

  useEffect(() => {
    setLibraryWindowStart((current) => Math.min(current, Math.max(0, libraryWords.length - LIBRARY_WINDOW_SIZE)));
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
    const localProgress = loadProgressFromStorage(getBrowserStorage(), initialProgress);
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

        await activateSignedInUser(data.session.user, localProgress);
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

    saveProgressToStorage(getBrowserStorage(), progress);
  }, [progress, progressReady]);

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

      saveCloudProgress(asCloudProgressClient(supabaseClient), account.userId ?? '', progress).then((result) => {
        if (cancelled) {
          return;
        }

        setAccount((current) => ({
          ...current,
          busy: false,
          status: result.ok ? 'saved' : 'error',
          message: result.ok ? '已保存到帳號' : result.message,
        }));
      });
    }, 450);

    return () => {
      cancelled = true;
      clearTimeout(syncTimer);
    };
  }, [account.userId, progress, progressReady, supabaseClient]);

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

  function handleLibraryQueryChange(query: string) {
    setSearchQuery(query);
    setLibraryWindowStart(0);
  }

  function clearLibrarySearch() {
    setSearchQuery('');
    setLibraryWindowStart(0);
  }

  function handleExportVocabulary() {
    const downloaded = downloadTextFile(`word7000-vocabulary-${today}.csv`, exportWordsToCsv(vocabularyWords), 'text/csv;charset=utf-8');
    setDeveloperVocabularyMessage(downloaded ? `已匯出 ${vocabularyWords.length} 筆字庫 CSV。` : '目前這個裝置不支援直接下載 CSV。');
  }

  async function handleImportVocabulary() {
    setDeveloperVocabularyMessage('正在讀取匯入檔案...');
    const picked = await pickVocabularyTextFile();
    if (!picked.ok) {
      setDeveloperVocabularyMessage(picked.message);
      return;
    }

    const parsed = parseVocabularyImport(picked.text, picked.fileName);
    if (!parsed.ok) {
      setDeveloperVocabularyMessage(parsed.errors.join(' '));
      return;
    }

    const applied = applyVocabularyImportRows(vocabularyWords, parsed.rows);
    if (applied.updated + applied.added === 0 && applied.errors.length > 0) {
      setDeveloperVocabularyMessage(applied.errors.slice(0, 3).join(' '));
      return;
    }

    const summary = `已套用本機預覽：更新 ${applied.updated} 筆，新增 ${applied.added} 筆，目前共 ${applied.words.length} 筆。`;
    const snapshot = {
      importedAt: new Date().toISOString(),
      summary,
      words: applied.words,
    };
    setDeveloperVocabulary(snapshot);
    saveDeveloperVocabulary(getBrowserStorage(), snapshot);
    setDeveloperVocabularyMessage(applied.errors.length > 0 ? `${summary} 另有 ${applied.errors.length} 筆未套用。` : summary);
  }

  function handleClearDeveloperVocabulary() {
    clearDeveloperVocabulary(getBrowserStorage());
    setDeveloperVocabulary(null);
    setDeveloperVocabularyMessage('已清除本機預覽，現在使用內建 7000 字庫。');
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
    setAnsweredQuizWord(null);
    setLockedQuizOptions(null);
    setQuizFinished(false);
    setQuizStarted(session.length > 0);
  }

  function restartQuiz() {
    setQuizIndex(0);
    setQuizResult(null);
    setAnsweredQuizWord(null);
    setLockedQuizOptions(null);
    setQuizStarted(false);
    setQuizFinished(false);
    setQuizCorrectCount(0);
  }

  function nextQuiz() {
    setQuizResult(null);
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
      setScrollY(event.nativeEvent.contentOffset.y);
    }
  }

  function handleLibrarySliderDrag(locationY: number) {
    const target = wordWindowStartFromSlider(
      locationY,
      sliderTrackHeight,
      libraryWords.length,
      LIBRARY_WINDOW_SIZE,
      LIBRARY_SLIDER_THUMB_HEIGHT,
    );
    setLibraryWindowStart(target);
    appScrollRef.current?.scrollTo({ y: 0, animated: false });
    setScrollY(0);
  }

  function returnLibraryToTop() {
    setLibraryWindowStart(0);
    appScrollRef.current?.scrollTo({ y: 0, animated: true });
    setScrollY(0);
  }

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
    markInstallGuideSeen(getBrowserStorage(), isInstalledWebApp());
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
    if (installGuideStep >= installGuideSteps.length - 1) {
      dismissInstallGuide();
      return;
    }

    setInstallGuideStep((current) => Math.min(current + 1, installGuideSteps.length - 1));
  }

  async function activateSignedInUser(user: SupabaseUser, fallback: ProgressState) {
    if (!supabaseClient) {
      return;
    }

    const loadedProgress = await loadCloudProgress(asCloudProgressClient(supabaseClient), user.id, fallback);
    setProgress(loadedProgress);
    saveProgressToStorage(getBrowserStorage(), loadedProgress);
    setAccount((current) => ({
      ...current,
      userId: user.id,
      userEmail: user.email ?? current.email,
      busy: false,
      status: 'signedIn',
      message: '已登入',
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
      await activateSignedInUser(data.user, progress);
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

    await activateSignedInUser(data.user, progress);
  }

  async function handleSignOut() {
    if (supabaseClient) {
      await supabaseClient.auth.signOut();
    }

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

  return (
    <ThemeContext.Provider value={themeMode}>
    <SafeAreaView style={[styles.safeArea, themeStyles?.safeArea]}>
      <StatusBar style={darkMode ? 'light' : 'dark'} />
      <View style={[styles.appShell, themeStyles?.appShell]}>
        <View style={styles.header}>
          <View>
            <Text style={[styles.brand, themeStyles?.brand]}>{activeModeCopy.brand}</Text>
            <Text style={[styles.headerSubtext, themeStyles?.headerSubtext]}>{activeModeCopy.subtitle}</Text>
          </View>
          <View style={[styles.levelPill, themeStyles?.levelPill]}>
            <Trophy size={15} color="#2f855a" strokeWidth={2.4} />
            <Text style={[styles.levelText, themeStyles?.levelText]}>Day {progress.streak}</Text>
          </View>
        </View>
        {updateState.available && (
          <View style={[styles.updateBanner, themeStyles?.updateBanner]}>
            <Text style={[styles.updateText, themeStyles?.updateText]}>{updateState.message}</Text>
            <AnimatedPressable accessibilityRole="button" onPress={updateState.refresh} pressTone="primary" style={styles.updateButton}>
              <Text style={styles.updateButtonText}>更新</Text>
            </AnimatedPressable>
          </View>
        )}

        <ScrollView
          contentContainerStyle={styles.content}
          onScroll={handleScroll}
          ref={appScrollRef}
          scrollEventThrottle={16}
          showsVerticalScrollIndicator={false}
        >
          <Animated.View style={[styles.screenMotion, screenMotionStyle]}>
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
              wordCount={studyWords.length}
              word={studyWord}
              progress={progress}
              onFilterChange={setStudyFilter}
              onFiltersToggle={() => setStudyFiltersOpen((current) => !current)}
              onInitialChange={setStudyInitial}
              onKnown={() => studyWord && handleKnown(studyWord.id)}
              onLevelChange={setStudyLevel}
              onReview={() => studyWord && handleReview(studyWord.id)}
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
              options={visibleQuizOptions}
              questionCount={quizQuestionCount}
              questionCounts={quizQuestionCounts}
              questionIndex={quizIndex}
              quizFinished={quizFinished}
              quizStarted={quizStarted}
              result={quizResult}
              sessionTotal={quizSessionTotal}
              studyMode={studyMode}
              correctCount={quizCorrectCount}
              word={visibleQuizWord}
              wordCount={quizWords.length}
              onAnswer={handleQuizAnswer}
              onFilterChange={setQuizFilter}
              onFiltersToggle={() => setQuizFiltersOpen((current) => !current)}
              onInitialChange={setQuizInitial}
              onLevelChange={setQuizLevel}
              onNext={nextQuiz}
              onQuestionCountChange={setQuizQuestionCount}
              onRestart={restartQuiz}
              onStart={startQuiz}
            />
          )}
          {activeTab === 'library' && (
            <LibraryView
              activeFilter={activeFilter}
              activeInitial={activeInitial}
              activeLevel={activeLevel}
              detailMotionStyle={detailMotionStyle}
              filtersOpen={libraryFiltersOpen}
              levelOptions={levelFilterOptions}
              listMotionStyle={listMotionStyle}
              progress={progress}
              query={searchQuery}
              searchFocused={searchFocused}
              selectedWord={selectedLibraryWord}
              studyMode={studyMode}
              visibleStart={libraryWindowStart}
              visibleWindowSize={LIBRARY_WINDOW_SIZE}
              words={libraryWords}
              onFilterChange={setActiveFilter}
              onFiltersToggle={() => setLibraryFiltersOpen((current) => !current)}
              onFavorite={(wordId) => setProgress((current) => toggleFavorite(current, wordId))}
              onInitialChange={setActiveInitial}
              onLevelChange={setActiveLevel}
              onCloseWord={() => setSelectedLibraryWord(null)}
              onOpenWord={(word) => {
                libraryDetailAnim.setValue(0);
                setSelectedLibraryWord(word);
                appScrollRef.current?.scrollTo({ y: 0, animated: true });
                Animated.timing(libraryDetailAnim, {
                  duration: interactionMotion.cardMs + 90,
                  easing: Easing.out(Easing.cubic),
                  toValue: 1,
                  useNativeDriver: Platform.OS !== 'web',
                }).start();
              }}
              onQueryChange={handleLibraryQueryChange}
              onQueryClear={clearLibrarySearch}
              onReturnTop={returnLibraryToTop}
              onSearchBlur={() => setSearchFocused(false)}
              onSearchFocus={() => setSearchFocused(true)}
            />
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
              onEmailChange={(email) => setAccount((current) => ({ ...current, email }))}
              onExportVocabulary={handleExportVocabulary}
              onImportVocabulary={handleImportVocabulary}
              onOpenSettings={() => setProfilePanel('settings')}
              onPasswordChange={(password) => setAccount((current) => ({ ...current, password }))}
              onShowInstallGuide={openInstallGuide}
              onSignIn={handleSignIn}
              onSignOut={handleSignOut}
              onSignUp={handleSignUp}
              onThemeModeChange={setThemeMode}
            />
          )}
          </Animated.View>
        </ScrollView>

        {activeTab === 'library' && !selectedLibraryWord && (
          <View pointerEvents="box-none" style={styles.libraryFixedControls}>
            {scrollY > 180 && (
              <AnimatedPressable
                accessibilityRole="button"
                onPress={returnLibraryToTop}
                pressTone="secondary"
                style={styles.libraryFloatingTopButton}
                testID="library-floating-top"
              >
                <ArrowUp size={15} color="#172033" strokeWidth={2.5} />
                <Text style={styles.libraryFloatingTopText}>{modeInterfaceCopy[studyMode].floatingTop}</Text>
              </AnimatedPressable>
            )}
            {librarySliderVisible && (
              <View
                {...librarySliderResponder.panHandlers}
                onLayout={(event) => setSliderTrackHeight(event.nativeEvent.layout.height)}
                style={styles.libraryDragSlider}
                testID="library-drag-slider"
              >
                <View style={styles.libraryDragTrack} />
                <View
                  style={[styles.libraryDragThumb, { transform: [{ translateY: libraryThumbOffset }] }]}
                  testID="library-drag-thumb"
                >
                  <GripVertical size={17} color="#172033" strokeWidth={2.4} />
                </View>
              </View>
            )}
          </View>
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
            <Text style={styles.launchTitle}>Word7000</Text>
            <Text style={styles.launchText}>每日輕學單字</Text>
            <View style={styles.launchBar}>
              <Animated.View style={[styles.launchBarFill, { width: launchProgressWidth }]} />
            </View>
          </Animated.View>
        )}
        {showInstallGuide && (
          <InstallGuideOverlay
            opacity={installGuideOpacity}
            step={installGuideStep}
            translateY={installGuideTranslateY}
            onDismiss={dismissInstallGuide}
            onNext={nextInstallGuideStep}
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

function useAppUpdateCheck(): UpdateState {
  const [available, setAvailable] = useState(false);
  const [latestVersion, setLatestVersion] = useState<string | null>(null);

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
        const storage = getBrowserStorage();
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
          setAvailable(true);
        }
      } catch {
        // Version checks should never block studying.
      }
    }

    checkVersion();

    const visibilityDocument = (globalThis as { document?: Document }).document;
    const handleVisibility = () => {
      if (visibilityDocument?.visibilityState === 'visible') {
        checkVersion();
      }
    };
    visibilityDocument?.addEventListener?.('visibilitychange', handleVisibility);

    return () => {
      cancelled = true;
      visibilityDocument?.removeEventListener?.('visibilitychange', handleVisibility);
    };
  }, []);

  function refresh() {
    const storage = getBrowserStorage();
    if (latestVersion) {
      storage?.setItem(UPDATE_STORAGE_KEY, latestVersion);
    }
    (globalThis as { location?: { reload: () => void } }).location?.reload();
  }

  return {
    available,
    message: '有新版本可用',
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

function useThemeStyles() {
  return useContext(ThemeContext) === 'dark' ? darkStyles : undefined;
}

function formatWordPrimary(word: WordEntry, studyMode: StudyMode): string {
  return studyMode === 'chinese' ? word.meaningZh : word.word;
}

function formatWordSecondary(word: WordEntry, studyMode: StudyMode): string {
  return studyMode === 'chinese' ? `${word.word} ${word.pronunciation}` : word.pronunciation;
}

function formatMeaningDetail(word: WordEntry, studyMode: StudyMode): string {
  return studyMode === 'chinese' ? word.word : word.meaningZh;
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

function getBrowserStorage(): StorageLike | undefined {
  if (Platform.OS !== 'web') {
    return undefined;
  }

  return (globalThis as { localStorage?: StorageLike }).localStorage;
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

function pickVocabularyTextFile(): Promise<{ fileName: string; ok: true; text: string } | { message: string; ok: false }> {
  const documentRef = (globalThis as { document?: Document }).document;
  if (Platform.OS !== 'web' || !documentRef) {
    return Promise.resolve({ message: '目前只有網頁版支援從檔案匯入字庫。', ok: false });
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
        resolve({ message: '沒有選擇檔案。', ok: false });
        return;
      }

      try {
        resolve({ fileName: file.name, ok: true, text: await file.text() });
      } catch {
        resolve({ message: '讀取檔案失敗，請確認檔案可以正常開啟。', ok: false });
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
  style?: StyleProp<ViewStyle>;
};

function AnimatedPressable({
  children,
  disabled,
  onPressIn,
  onPressOut,
  pressTone = 'secondary',
  style,
  ...props
}: AnimatedPressableProps) {
  const pressAnim = useRef(new Animated.Value(0)).current;
  const pressMotion = pressMotionFor(pressTone);
  const pressStyle = {
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
      animatePress(1, interactionMotion.pressInMs);
    }
    onPressIn?.(event);
  }

  function handlePressOut(event: Parameters<NonNullable<PressableProps['onPressOut']>>[0]) {
    if (!disabled) {
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
      style={[style, !disabled && pressStyle]}
    >
      {children}
    </MotionPressable>
  );
}

function AnimatedFilterPanel({ children, open, testID }: { children: ReactNode; open: boolean; testID: string }) {
  const themeStyles = useThemeStyles();
  const [rendered, setRendered] = useState(open);
  const panelAnim = useRef(new Animated.Value(open ? 1 : 0)).current;

  useEffect(() => {
    if (open) {
      setRendered(true);
    }

    Animated.timing(panelAnim, {
      duration: interactionMotion.panelMs,
      easing: Easing.out(Easing.cubic),
      toValue: open ? 1 : 0,
      useNativeDriver: false,
    }).start(({ finished }) => {
      if (finished && !open) {
        setRendered(false);
      }
    });
  }, [open, panelAnim]);

  if (!rendered) {
    return null;
  }

  const panelMotionStyle = {
    maxHeight: panelAnim.interpolate({
      inputRange: [0, 1],
      outputRange: [0, interactionMotion.panelMaxHeight],
    }),
    opacity: panelAnim,
    transform: [
      {
        translateY: panelAnim.interpolate({
          inputRange: [0, 1],
          outputRange: [-8, 0],
        }),
      },
    ],
  };

  return (
    <Animated.View style={[styles.filterPanel, themeStyles?.filterPanel, panelMotionStyle]} testID={testID}>
      {children}
    </Animated.View>
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
  opacity,
  step,
  translateY,
  onDismiss,
  onNext,
}: {
  opacity: Animated.Value;
  step: number;
  translateY: Animated.AnimatedInterpolation<number>;
  onDismiss: () => void;
  onNext: () => void;
}) {
  const current = installGuideSteps[step];
  const isLastStep = step === installGuideSteps.length - 1;
  const installGuideStepProgress = useRef(new Animated.Value(1)).current;

  useEffect(() => {
    installGuideStepProgress.setValue(0);
    Animated.timing(installGuideStepProgress, {
      duration: 260,
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
      style={[styles.installGuideOverlay, { opacity, transform: [{ translateY }] }]}
      testID="install-guide-overlay"
    >
      <View style={styles.installGuideTopBar}>
        <View style={styles.installGuideLogo}>
          <View style={styles.installGuideLogoDot} />
          <Text style={styles.installGuideLogoText}>W7</Text>
        </View>
        <AnimatedPressable
          accessibilityLabel="關閉加入主畫面教學"
          accessibilityRole="button"
          onPress={onDismiss}
          pressTone="icon"
          style={styles.installGuideClose}
        >
          <X size={18} color="#172033" strokeWidth={2.4} />
        </AnimatedPressable>
      </View>

      <View style={styles.installGuideCard}>
        <View style={styles.installGuideStepPill}>
          <Text style={styles.installGuideStepText}>
            {step + 1} / {installGuideSteps.length}
          </Text>
        </View>
        <Animated.View style={[styles.installGuideIconWrap, stepMotionStyle]}>
          <Animated.View
            pointerEvents="none"
            style={[
              styles.installGuideIconGlow,
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
            <InstallGuideStepIcon icon={current.icon} />
          </View>
        </Animated.View>
        <Animated.View style={[styles.installGuideCopyBlock, stepMotionStyle]}>
          <Text style={styles.installGuideTitle}>{current.title}</Text>
          <Text style={styles.installGuideText}>{current.text}</Text>
        </Animated.View>

        <View style={styles.installGuidePreview}>
          <View style={styles.installGuideBrowserBar} />
          <View style={styles.installGuidePreviewRow}>
            {installGuideSteps.map((item, index) => (
              <Animated.View
                key={item.title}
                style={[
                  styles.installGuideMiniStep,
                  index <= step && styles.installGuideMiniStepActive,
                  index === step && styles.installGuideStepProgress,
                ]}
              >
                <Text style={[styles.installGuideMiniText, index <= step && styles.installGuideMiniTextActive]}>
                  {index + 1}
                </Text>
              </Animated.View>
            ))}
          </View>
        </View>
      </View>

      <View style={styles.installGuideDots}>
        {installGuideSteps.map((item, index) => (
          <View key={item.title} style={[styles.installGuideDot, index === step && styles.installGuideDotActive]} />
        ))}
      </View>

      <View style={styles.installGuideActions}>
        <AnimatedPressable accessibilityRole="button" onPress={onDismiss} pressTone="secondary" style={styles.installGuideSecondary}>
          <Text style={styles.installGuideSecondaryText}>我先自己操作</Text>
        </AnimatedPressable>
        <AnimatedPressable accessibilityRole="button" onPress={onNext} pressTone="primary" style={styles.installGuidePrimary}>
          <Text style={styles.installGuidePrimaryText}>{isLastStep ? '完成' : '下一步'}</Text>
          <ChevronRight size={18} color="#fff" strokeWidth={2.5} />
        </AnimatedPressable>
      </View>
    </Animated.View>
  );
}

function InstallGuideStepIcon({ icon }: { icon: (typeof installGuideSteps)[number]['icon'] }) {
  if (icon === 'safari') {
    return <Compass size={56} color="#2563eb" strokeWidth={2.1} />;
  }
  if (icon === 'share') {
    return <SquareArrowUp size={56} color="#2563eb" strokeWidth={2.1} />;
  }
  if (icon === 'add') {
    return <SquarePlus size={56} color="#2563eb" strokeWidth={2.1} />;
  }
  return <Smartphone size={56} color="#2563eb" strokeWidth={2.1} />;
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
    <View style={styles.screenStack}>
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
  onFilterChange,
  onFiltersToggle,
  onFavorite,
  onInitialChange,
  onKnown,
  onLevelChange,
  onReview,
}: {
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
        <Text style={[styles.bigWord, studyMode === 'chinese' && styles.bigChineseWord, themeStyles?.bigWord]}>
          {formatWordPrimary(word, studyMode)}
        </Text>
        <Text style={[styles.pronunciation, themeStyles?.pronunciation]}>{formatWordSecondary(word, studyMode)}</Text>
        <View style={[styles.meaningBlock, themeStyles?.meaningBlock]}>
          <Text style={styles.partOfSpeech}>{studyMode === 'chinese' ? ui.englishCounterpart : word.partOfSpeech}</Text>
          <Text style={[styles.meaning, themeStyles?.meaning]}>{formatMeaningDetail(word, studyMode)}</Text>
        </View>
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
  onToggle,
}: {
  activeFilter: LibraryFilter;
  activeInitial: string;
  activeLevel: string;
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
  onToggle: () => void;
}) {
  const summary = filterSummary(activeFilter, activeLevel, activeInitial, showStatus, studyMode, levelOptions);
  const themeStyles = useThemeStyles();
  const bodyIconColor = useContext(ThemeContext) === 'dark' ? '#e2e8f0' : '#172033';
  const ui = modeInterfaceCopy[studyMode];

  return (
    <View style={[styles.foldedFilterCard, themeStyles?.foldedFilterCard]}>
      <AnimatedPressable
        accessibilityRole="button"
        onPress={onToggle}
        pressTone="secondary"
        style={styles.filterSummaryButton}
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
      </AnimatedFilterPanel>
    </View>
  );
}

function QuizView({
  activeFilter,
  activeInitial,
  activeLevel,
  correctCount,
  filtersOpen,
  levelOptions,
  motionStyle,
  options,
  questionCount,
  questionCounts,
  questionIndex,
  quizFinished,
  quizStarted,
  result,
  sessionTotal,
  studyMode,
  wordCount,
  word,
  onAnswer,
  onFilterChange,
  onFiltersToggle,
  onInitialChange,
  onLevelChange,
  onNext,
  onQuestionCountChange,
  onRestart,
  onStart,
}: {
  activeFilter: LibraryFilter;
  activeInitial: string;
  activeLevel: string;
  correctCount: number;
  filtersOpen: boolean;
  levelOptions: FilterOption[];
  motionStyle: StyleProp<ViewStyle>;
  options: ReturnType<typeof buildQuizOptions>;
  questionCount: (typeof quizQuestionCounts)[number];
  questionCounts: readonly (typeof quizQuestionCounts)[number][];
  questionIndex: number;
  quizFinished: boolean;
  quizStarted: boolean;
  result: 'correct' | 'wrong' | null;
  sessionTotal: number;
  studyMode: StudyMode;
  word: WordEntry | null;
  wordCount: number;
  onAnswer: (correct: boolean) => void;
  onFilterChange: (filter: LibraryFilter) => void;
  onFiltersToggle: () => void;
  onInitialChange: (initial: string) => void;
  onLevelChange: (level: string) => void;
  onNext: () => void;
  onQuestionCountChange: (count: (typeof quizQuestionCounts)[number]) => void;
  onRestart: () => void;
  onStart: () => void;
}) {
  const themeStyles = useThemeStyles();
  const bodyIconColor = useContext(ThemeContext) === 'dark' ? '#e2e8f0' : '#172033';
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
        testID="quiz-filter-toggle"
        title={copy.quizFilterTitle}
        initialTitle={copy.initialTitle}
        onFilterChange={onFilterChange}
        onInitialChange={onInitialChange}
        onLevelChange={onLevelChange}
        onToggle={onFiltersToggle}
      />

      {!quizStarted && !quizFinished && (
        <Animated.View style={[styles.quizSetupCard, themeStyles?.quizSetupCard, motionStyle]}>
          <View style={styles.rowBetween}>
            <View>
              <Text style={[styles.sectionTitle, themeStyles?.sectionTitle]}>{ui.questionCountTitle}</Text>
              <Text style={[styles.cardMeta, themeStyles?.cardMeta]}>{ui.questionBankPrefix} {wordCount} {copy.questionBankUnit}</Text>
            </View>
            <Target size={22} color="#2563eb" strokeWidth={2.3} />
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
            <Target size={18} color="#fff" strokeWidth={2.3} />
            <Text style={styles.primaryButtonText}>{ui.startQuiz}</Text>
          </AnimatedPressable>
        </Animated.View>
      )}

      {quizFinished && (
        <Animated.View style={[styles.quizSetupCard, themeStyles?.quizSetupCard, motionStyle]}>
          <Text style={styles.eyebrow}>RESULT</Text>
          <Text style={[styles.resultTitle, themeStyles?.resultTitle]}>{ui.quizFinished}</Text>
          <Text style={[styles.quizScoreText, themeStyles?.quizScoreText]}>{ui.quizScore(correctCount, sessionTotal)}</Text>
          <AnimatedPressable accessibilityRole="button" onPress={onRestart} pressTone="primary" style={styles.primaryButton}>
            <RotateCcw size={18} color="#fff" strokeWidth={2.3} />
            <Text style={styles.primaryButtonText}>{ui.restartQuiz}</Text>
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

      {quizStarted && word && (
        <>
      <Animated.View style={[styles.quizCard, themeStyles?.quizCard, motionStyle]}>
        <Text style={styles.eyebrow}>
          QUIZ {questionIndex + 1} / {sessionTotal}
        </Text>
        <Text style={[styles.bigWord, studyMode === 'chinese' && styles.bigChineseWord, themeStyles?.bigWord]}>
          {formatWordPrimary(word, studyMode)}
        </Text>
        <Text style={[styles.pronunciation, themeStyles?.pronunciation]}>{formatWordSecondary(word, studyMode)}</Text>
        <View style={styles.quizOptions}>
          {options.map((option) => (
            <AnimatedPressable
              accessibilityRole="button"
              disabled={result !== null}
              key={option.meaning}
              onPress={() => onAnswer(option.correct)}
              pressTone="list"
              style={[
                styles.quizOption,
                themeStyles?.quizOption,
                result !== null && option.correct && styles.quizOptionCorrect,
                result === 'wrong' && !option.correct && styles.quizOptionMuted,
              ]}
            >
              <Text style={[styles.quizOptionText, themeStyles?.quizOptionText, result !== null && option.correct && styles.quizOptionTextCorrect]}>
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
          </View>
          <AnimatedPressable accessibilityRole="button" onPress={onNext} pressTone="secondary" style={[styles.nextButton, themeStyles?.nextButton]}>
            <Text style={[styles.nextButtonText, themeStyles?.nextButtonText]}>{ui.nextQuestion}</Text>
            <ChevronRight size={18} color={bodyIconColor} strokeWidth={2.3} />
          </AnimatedPressable>
        </Animated.View>
      )}
        </>
      )}
    </View>
  );
}

function LibraryView({
  activeFilter,
  activeInitial,
  activeLevel,
  detailMotionStyle,
  filtersOpen,
  levelOptions,
  listMotionStyle,
  progress,
  query,
  searchFocused,
  selectedWord,
  studyMode,
  visibleStart,
  visibleWindowSize,
  words,
  onCloseWord,
  onFavorite,
  onFilterChange,
  onFiltersToggle,
  onInitialChange,
  onLevelChange,
  onOpenWord,
  onQueryChange,
  onQueryClear,
  onReturnTop,
  onSearchBlur,
  onSearchFocus,
}: {
  activeFilter: LibraryFilter;
  activeInitial: string;
  activeLevel: string;
  detailMotionStyle: StyleProp<ViewStyle>;
  filtersOpen: boolean;
  levelOptions: FilterOption[];
  listMotionStyle: (index: number) => StyleProp<ViewStyle>;
  progress: ProgressState;
  query: string;
  searchFocused: boolean;
  selectedWord: WordEntry | null;
  studyMode: StudyMode;
  visibleStart: number;
  visibleWindowSize: number;
  words: WordEntry[];
  onCloseWord: () => void;
  onFavorite: (wordId: string) => void;
  onFilterChange: (filter: LibraryFilter) => void;
  onFiltersToggle: () => void;
  onInitialChange: (initial: string) => void;
  onLevelChange: (level: string) => void;
  onOpenWord: (word: WordEntry) => void;
  onQueryChange: (query: string) => void;
  onQueryClear: () => void;
  onReturnTop: () => void;
  onSearchBlur: () => void;
  onSearchFocus: () => void;
}) {
  const safeStart = Math.min(visibleStart, Math.max(0, words.length - visibleWindowSize));
  const visibleEnd = Math.min(words.length, safeStart + visibleWindowSize);
  const visibleWords = words.slice(safeStart, visibleEnd);
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

  if (selectedWord) {
    return (
      <LibraryWordDetailView
        motionStyle={detailMotionStyle}
        progress={progress}
        studyMode={studyMode}
        word={selectedWord}
        onBack={onCloseWord}
        onFavorite={() => onFavorite(selectedWord.id)}
      />
    );
  }

  return (
    <View style={styles.screenStack}>
      <View style={[styles.libraryHeaderCard, themeStyles?.libraryHeaderCard]}>
        <View>
          <Text style={[styles.libraryHeaderTitle, themeStyles?.libraryHeaderTitle]}>{copy.libraryTitle}</Text>
          <Text style={[styles.libraryHeaderMeta, themeStyles?.libraryHeaderMeta]}>{ui.filteredCount(words.length)}</Text>
        </View>
        <AnimatedPressable
          accessibilityRole="button"
          onPress={onReturnTop}
          pressTone="secondary"
          style={[styles.libraryTopButton, themeStyles?.libraryTopButton]}
          testID="library-top-return"
        >
          <ArrowUp size={16} color={bodyIconColor} strokeWidth={2.5} />
          <Text style={[styles.libraryTopButtonText, themeStyles?.libraryTopButtonText]}>{ui.returnTop}</Text>
        </AnimatedPressable>
      </View>

      <Animated.View style={searchMotionStyle}>
        <View style={[styles.searchBox, themeStyles?.searchBox, searchFocused && styles.searchBoxFocused, hasQuery && styles.searchBoxActive]}>
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
        onToggle={onFiltersToggle}
      />

      <View style={styles.libraryPanel}>
        <View style={styles.wordList}>
        <Text style={[styles.resultCount, themeStyles?.resultCount]}>
          {ui.resultCount(words.length, safeStart, visibleEnd)}
        </Text>
        {visibleWords.map((word, index) => {
          const wordProgress = progress.words[word.id];
          return (
            <Animated.View key={word.id} style={[styles.libraryItem, themeStyles?.libraryItem, listMotionStyle(index)]}>
              <AnimatedPressable
                accessibilityLabel={ui.viewWordDetails(formatWordPrimary(word, studyMode))}
                accessibilityRole="button"
                onPress={() => onOpenWord(word)}
                pressTone="list"
                style={styles.libraryItemMain}
              >
                <View style={styles.wordLine}>
                  <Text style={[styles.libraryWord, studyMode === 'chinese' && styles.libraryChineseWord, themeStyles?.libraryWord]}>
                    {formatWordPrimary(word, studyMode)}
                  </Text>
                  <Text style={styles.libraryGroup}>{word.group}</Text>
                  <Text style={styles.libraryPos}>{word.partOfSpeech}</Text>
                </View>
                <Text style={[styles.libraryMeaning, themeStyles?.libraryMeaning]}>{formatMeaningDetail(word, studyMode)}</Text>
                <Text style={[styles.libraryExample, themeStyles?.libraryExample]}>{formatExamplePrimary(word, studyMode)}</Text>
                <Text style={styles.libraryDetailHint}>{ui.viewDetails}</Text>
              </AnimatedPressable>
              <View style={styles.librarySide}>
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
}

function LibraryWordDetailView({
  motionStyle,
  progress,
  studyMode,
  word,
  onBack,
  onFavorite,
}: {
  motionStyle: StyleProp<ViewStyle>;
  progress: ProgressState;
  studyMode: StudyMode;
  word: WordEntry;
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

      <Animated.View style={[styles.libraryDetailPage, themeStyles?.libraryDetailPage, motionStyle]} testID="library-word-detail">
        <View style={styles.libraryDetailHeader}>
          <View style={styles.flexOne}>
            <Text style={styles.eyebrow}>{ui.detailTitle}</Text>
            <Text style={[styles.libraryDetailWord, studyMode === 'chinese' && styles.libraryDetailChineseWord, themeStyles?.libraryDetailWord]}>
              {formatWordPrimary(word, studyMode)}
            </Text>
            <Text style={[styles.libraryDetailPronunciation, themeStyles?.libraryDetailPronunciation]}>
              {formatWordSecondary(word, studyMode)}
            </Text>
          </View>
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
      </Animated.View>
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
  onExportVocabulary,
  onImportVocabulary,
  onOpenSettings,
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
  onEmailChange: (email: string) => void;
  onExportVocabulary: () => void;
  onImportVocabulary: () => void;
  onOpenSettings: () => void;
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

  if (panel === 'settings') {
    return (
      <ProfileSettingsView
        developerMessage={developerMessage}
        developerVocabulary={developerVocabulary}
        studyMode={studyMode}
        themeMode={themeMode}
        vocabularyCount={vocabularyCount}
        onBack={onCloseSettings}
        onClearDeveloperVocabulary={onClearDeveloperVocabulary}
        onExportVocabulary={onExportVocabulary}
        onImportVocabulary={onImportVocabulary}
        onThemeModeChange={onThemeModeChange}
      />
    );
  }

  return (
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

      <ProfileTutorialPanel studyMode={studyMode} onShowInstallGuide={onShowInstallGuide} />

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

function ProfileSettingsView({
  developerMessage,
  developerVocabulary,
  onBack,
  onClearDeveloperVocabulary,
  onExportVocabulary,
  onImportVocabulary,
  onThemeModeChange,
  studyMode,
  themeMode,
  vocabularyCount,
}: {
  developerMessage: string;
  developerVocabulary: DeveloperVocabularySnapshot | null;
  studyMode: StudyMode;
  themeMode: ThemeMode;
  vocabularyCount: number;
  onBack: () => void;
  onClearDeveloperVocabulary: () => void;
  onExportVocabulary: () => void;
  onImportVocabulary: () => void;
  onThemeModeChange: (themeMode: ThemeMode) => void;
}) {
  const themeStyles = useThemeStyles();
  const darkMode = themeMode === 'dark';
  const bodyIconColor = darkMode ? '#e2e8f0' : '#172033';
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

        <View style={[styles.settingOptionRow, themeStyles?.settingOptionRow]}>
          <View style={[styles.settingOptionIcon, themeStyles?.settingsEntryIcon]}>
            {darkMode ? <Sun size={19} color="#fbbf24" strokeWidth={2.3} /> : <Moon size={19} color="#2563eb" strokeWidth={2.3} />}
          </View>
          <View style={styles.flexOne}>
            <Text style={[styles.settingsEntryTitle, themeStyles?.settingsEntryTitle]}>{ui.darkMode}</Text>
            <Text style={[styles.settingsEntryText, themeStyles?.settingsEntryText]}>
              {darkMode ? ui.darkModeOnText : ui.darkModeOffText}
            </Text>
          </View>
          <AnimatedPressable
            accessibilityLabel={ui.toggleDarkMode}
            accessibilityRole="button"
            onPress={() => onThemeModeChange(darkMode ? 'light' : 'dark')}
            pressTone="chip"
            style={[styles.themeSwitchButton, darkMode && styles.themeSwitchButtonActive]}
          >
            <View style={[styles.themeSwitchDot, darkMode && styles.themeSwitchDotActive]} />
            <Text style={[styles.themeSwitchText, darkMode && styles.themeSwitchTextActive]}>{darkMode ? ui.on : ui.off}</Text>
          </AnimatedPressable>
        </View>
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
): string {
  const parts = [levelLabel(level, studyMode, levelOptions), initialLabel(initial, studyMode)];
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
  appShell: {
    alignSelf: 'center',
    backgroundColor: '#f8fafc',
    flex: 1,
    maxWidth: 760,
    width: '100%',
  },
  header: {
    alignItems: 'center',
    flexDirection: 'row',
    justifyContent: 'space-between',
    paddingHorizontal: 22,
    paddingTop: 18,
    paddingBottom: 12,
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
  content: {
    padding: 18,
    paddingBottom: 102,
  },
  screenMotion: {
    gap: 14,
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
    justifyContent: 'space-between',
    left: 0,
    paddingHorizontal: 22,
    paddingVertical: 24,
    position: 'absolute',
    right: 0,
    top: 0,
    zIndex: 80,
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
    gap: 14,
    padding: 16,
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
    minHeight: 44,
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
    padding: 14,
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
    padding: 16,
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
  quizSetupCard: {
    backgroundColor: '#fff',
    borderColor: '#e5e7eb',
    borderRadius: 8,
    borderWidth: 1,
    gap: 14,
    padding: 18,
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
    borderTopWidth: 1,
    gap: 12,
    overflow: 'hidden',
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
    alignItems: 'center',
    backgroundColor: '#fff',
    borderColor: '#e5e7eb',
    borderRadius: 8,
    borderWidth: 1,
    flexDirection: 'row',
    gap: 12,
    justifyContent: 'space-between',
    padding: 14,
  },
  libraryHeaderTitle: {
    color: '#172033',
    fontSize: 17,
    fontWeight: '900',
  },
  libraryHeaderMeta: {
    color: '#717987',
    fontSize: 13,
    fontWeight: '700',
    marginTop: 3,
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
  libraryPanel: {
    position: 'relative',
  },
  wordList: {
    gap: 10,
    paddingRight: 44,
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
    flex: 1,
    minWidth: 0,
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
  libraryMeaning: {
    color: '#172033',
    fontSize: 14,
    fontWeight: '700',
    marginTop: 5,
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
    backgroundColor: '#ffffff',
    borderColor: '#cbd5e1',
    borderRadius: 8,
    borderWidth: 1,
    elevation: 5,
    height: 500,
    paddingHorizontal: 4,
    paddingVertical: 5,
    position: 'absolute',
    right: 0,
    shadowColor: '#172033',
    shadowOffset: { height: 2, width: 0 },
    shadowOpacity: 0.14,
    shadowRadius: 7,
    top: 100,
    width: 34,
  },
  libraryDragTrack: {
    backgroundColor: '#e5e7eb',
    borderRadius: 8,
    bottom: 8,
    position: 'absolute',
    top: 8,
    width: 4,
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
    width: 24,
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
  tabBar: {
    alignSelf: 'center',
    backgroundColor: '#fff',
    borderColor: '#e5e7eb',
    borderRadius: 8,
    borderWidth: 1,
    bottom: 16,
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
  meaningBlock: {
    borderTopColor: '#334155',
  },
  meaning: {
    color: '#e2e8f0',
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
  letterChip: {
    backgroundColor: '#182033',
    borderColor: '#334155',
  },
  quizSetupCard: {
    backgroundColor: '#111827',
    borderColor: '#334155',
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
  quizOption: {
    backgroundColor: '#182033',
    borderColor: '#334155',
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
  resultText: {
    color: '#cbd5e1',
  },
  nextButton: {
    backgroundColor: '#182033',
    borderColor: '#334155',
  },
  nextButtonText: {
    color: '#e2e8f0',
  },
  libraryHeaderCard: {
    backgroundColor: '#111827',
    borderColor: '#334155',
  },
  libraryHeaderTitle: {
    color: '#f8fafc',
  },
  libraryHeaderMeta: {
    color: '#94a3b8',
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
  libraryWord: {
    color: '#f8fafc',
  },
  libraryMeaning: {
    color: '#e2e8f0',
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

