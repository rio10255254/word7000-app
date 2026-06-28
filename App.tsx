import { StatusBar } from 'expo-status-bar';
import {
  ArrowUp,
  BookOpen,
  Check,
  ChevronDown,
  ChevronRight,
  Cloud,
  Compass,
  GripVertical,
  Home,
  Library,
  Lock,
  LogIn,
  LogOut,
  Mail,
  RotateCcw,
  Search,
  Share2,
  SlidersHorizontal,
  Smartphone,
  SquarePlus,
  Star,
  Target,
  Trophy,
  User,
  X,
} from 'lucide-react-native';
import { useEffect, useMemo, useRef, useState, type ReactNode } from 'react';
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

type Tab = 'home' | 'study' | 'quiz' | 'library' | 'profile';
type AccountStatus = 'local' | 'loading' | 'signedOut' | 'signedIn' | 'syncing' | 'saved' | 'error';

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

const today = new Date().toISOString().slice(0, 10);
const UPDATE_STORAGE_KEY = 'word7000-version-v1';
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

const levelFilters = [
  { id: 'all', label: '全部分級' },
  ...Array.from(new Set(sampleWords.map((word) => word.group))).map((group) => ({
    id: group,
    label: group.replace('Core ', 'L'),
  })),
];
const alphabetFilters = [
  { id: 'all', label: '全部' },
  ...'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.split('').map((letter) => ({
    id: letter,
    label: letter,
  })),
];
const MotionPressable = Animated.createAnimatedComponent(Pressable);

export default function App() {
  const appScrollRef = useRef<ScrollView | null>(null);
  const launchAnim = useRef(new Animated.Value(0)).current;
  const installGuideAnim = useRef(new Animated.Value(0)).current;
  const screenAnim = useRef(new Animated.Value(1)).current;
  const cardAnim = useRef(new Animated.Value(1)).current;
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
  const [scrollY, setScrollY] = useState(0);
  const [sliderTrackHeight, setSliderTrackHeight] = useState(1);
  const [libraryWindowStart, setLibraryWindowStart] = useState(0);

  const stats = useMemo(() => computeStats(sampleWords, progress), [progress]);
  const studyWords = useMemo(
    () =>
      selectStudyWords(sampleWords, progress, studyFilter, {
        initial: studyInitial,
        level: studyLevel,
      }),
    [progress, studyFilter, studyInitial, studyLevel],
  );
  const studyWord = studyWords.length > 0 ? studyWords[wordIndex % studyWords.length] : null;
  const quizWords = useMemo(
    () =>
      selectQuizWords(sampleWords, progress, quizFilter, {
        initial: quizInitial,
        level: quizLevel,
      }),
    [progress, quizFilter, quizInitial, quizLevel],
  );
  const quizWord = quizStarted && quizSession.length > 0 ? quizSession[quizIndex] ?? null : null;
  const quizOptionSource = quizWords.length >= 3 ? quizWords : sampleWords;
  const quizOptions = useMemo(
    () => (quizWord ? buildQuizOptions(quizOptionSource, quizWord.id, `${quizSeed}:${quizIndex}`) : []),
    [quizIndex, quizOptionSource, quizSeed, quizWord],
  );
  const visibleQuizWord = answeredQuizWord ?? quizWord;
  const visibleQuizOptions = lockedQuizOptions ?? quizOptions;
  const quizSessionTotal = quizStarted || quizFinished ? quizSession.length : Math.min(quizQuestionCount, quizWords.length);
  const libraryWords = useMemo(
    () =>
      filterWords(sampleWords, progress, searchQuery, activeFilter, {
        initial: activeInitial,
        level: activeLevel,
      }),
    [activeFilter, activeInitial, activeLevel, progress, searchQuery],
  );
  const dailyPercent = Math.min(100, Math.round((stats.studiedToday / progress.dailyTarget) * 100));
  const updateState = useAppUpdateCheck();
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
  const launchOpacity = launchAnim.interpolate({
    inputRange: [0, 0.22, 1.62, 2],
    outputRange: [0, 1, 1, 0],
  });
  const launchScale = launchAnim.interpolate({
    inputRange: [0, 1, 2],
    outputRange: [0.94, 1, 1.04],
  });
  const installGuideOpacity = installGuideAnim;
  const installGuideTranslateY = installGuideAnim.interpolate({
    inputRange: [0, 1],
    outputRange: [24, 0],
  });
  const librarySliderVisible = activeTab === 'library' && libraryWords.length > LIBRARY_WINDOW_SIZE;
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
        useNativeDriver: true,
      }),
      Animated.delay(520),
      Animated.timing(launchAnim, {
        duration: 300,
        easing: Easing.inOut(Easing.cubic),
        toValue: 2,
        useNativeDriver: true,
      }),
    ]).start(() => setShowLaunch(false));
  }, [launchAnim]);

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
      useNativeDriver: true,
    }).start();
  }, [activeTab, screenAnim]);

  useEffect(() => {
    cardAnim.setValue(0);
    Animated.timing(cardAnim, {
      duration: interactionMotion.cardMs,
      easing: Easing.out(Easing.cubic),
      toValue: 1,
      useNativeDriver: true,
    }).start();
  }, [
    activeFilter,
    activeInitial,
    activeLevel,
    activeTab,
    cardAnim,
    libraryFiltersOpen,
    quizFilter,
    quizFiltersOpen,
    quizIndex,
    quizInitial,
    quizLevel,
    quizQuestionCount,
    quizStarted,
    quizFinished,
    searchQuery,
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
  }, [activeTab, activeFilter, activeInitial, activeLevel, searchQuery]);

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
      useNativeDriver: true,
    }).start();
  }

  function dismissInstallGuide() {
    markInstallGuideSeen(getBrowserStorage());
    Animated.timing(installGuideAnim, {
      duration: 220,
      easing: Easing.inOut(Easing.cubic),
      toValue: 0,
      useNativeDriver: true,
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

  return (
    <SafeAreaView style={styles.safeArea}>
      <StatusBar style="dark" />
      <View style={styles.appShell}>
        <View style={styles.header}>
          <View>
            <Text style={styles.brand}>Word7000</Text>
            <Text style={styles.headerSubtext}>每日輕學單字</Text>
          </View>
          <View style={styles.levelPill}>
            <Trophy size={15} color="#2f855a" strokeWidth={2.4} />
            <Text style={styles.levelText}>Day {progress.streak}</Text>
          </View>
        </View>
        {updateState.available && (
          <View style={styles.updateBanner}>
            <Text style={styles.updateText}>{updateState.message}</Text>
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
              onOpenAccount={() => setActiveTab('profile')}
              onStartStudy={() => setActiveTab('study')}
              onOpenReview={() => {
                setActiveFilter('review');
                setActiveTab('library');
              }}
            />
          )}
          {activeTab === 'study' && (
            <StudyView
              activeFilter={studyFilter}
              activeInitial={studyInitial}
              activeLevel={studyLevel}
              filtersOpen={studyFiltersOpen}
              motionStyle={cardMotionStyle}
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
              motionStyle={cardMotionStyle}
              options={visibleQuizOptions}
              questionCount={quizQuestionCount}
              questionCounts={quizQuestionCounts}
              questionIndex={quizIndex}
              quizFinished={quizFinished}
              quizStarted={quizStarted}
              result={quizResult}
              sessionTotal={quizSessionTotal}
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
              filtersOpen={libraryFiltersOpen}
              listMotionStyle={listMotionStyle}
              progress={progress}
              query={searchQuery}
              searchFocused={searchFocused}
              visibleStart={libraryWindowStart}
              visibleWindowSize={LIBRARY_WINDOW_SIZE}
              words={libraryWords}
              onFilterChange={setActiveFilter}
              onFiltersToggle={() => setLibraryFiltersOpen((current) => !current)}
              onFavorite={(wordId) => setProgress((current) => toggleFavorite(current, wordId))}
              onInitialChange={setActiveInitial}
              onLevelChange={setActiveLevel}
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
              progress={progress}
              stats={stats}
              onEmailChange={(email) => setAccount((current) => ({ ...current, email }))}
              onPasswordChange={(password) => setAccount((current) => ({ ...current, password }))}
              onShowInstallGuide={openInstallGuide}
              onSignIn={handleSignIn}
              onSignOut={handleSignOut}
              onSignUp={handleSignUp}
            />
          )}
          </Animated.View>
        </ScrollView>

        {activeTab === 'library' && (
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
                <Text style={styles.libraryFloatingTopText}>回頂端</Text>
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

        <View style={styles.tabBar}>
          {tabs.map((tab) => {
            const Icon = tab.icon;
            const selected = activeTab === tab.id;
            return (
              <AnimatedPressable
                accessibilityRole="button"
                key={tab.id}
                onPress={() => setActiveTab(tab.id)}
                pressTone="tab"
                style={[styles.tabButton, selected && styles.tabButtonActive]}
              >
                <Icon size={18} color={selected ? '#172033' : '#717987'} strokeWidth={2.2} />
                <Text style={[styles.tabLabel, selected && styles.tabLabelActive]}>{tab.label}</Text>
              </AnimatedPressable>
            );
          })}
        </View>

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
              <View style={styles.launchBarFill} />
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

function getBrowserStorage(): StorageLike | undefined {
  if (Platform.OS !== 'web') {
    return undefined;
  }

  return (globalThis as { localStorage?: StorageLike }).localStorage;
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
      useNativeDriver: true,
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
    <Animated.View style={[styles.filterPanel, panelMotionStyle]} testID={testID}>
      {children}
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
        <View style={styles.installGuideIconWrap}>
          <InstallGuideStepIcon icon={current.icon} />
        </View>
        <Text style={styles.installGuideTitle}>{current.title}</Text>
        <Text style={styles.installGuideText}>{current.text}</Text>

        <View style={styles.installGuidePreview}>
          <View style={styles.installGuideBrowserBar} />
          <View style={styles.installGuidePreviewRow}>
            {installGuideSteps.map((item, index) => (
              <View
                key={item.title}
                style={[styles.installGuideMiniStep, index <= step && styles.installGuideMiniStepActive]}
              >
                <Text style={[styles.installGuideMiniText, index <= step && styles.installGuideMiniTextActive]}>
                  {index + 1}
                </Text>
              </View>
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
    return <Share2 size={56} color="#2563eb" strokeWidth={2.1} />;
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
  onOpenAccount,
  onOpenReview,
  onStartStudy,
}: {
  dailyPercent: number;
  progress: ProgressState;
  stats: ReturnType<typeof computeStats>;
  onOpenAccount: () => void;
  onOpenReview: () => void;
  onStartStudy: () => void;
}) {
  return (
    <View style={styles.screenStack}>
      <View style={styles.hero}>
        <View style={styles.heroCopy}>
          <Text style={styles.eyebrow}>TODAY</Text>
          <Text style={styles.heroTitle}>今天 20 個剛剛好</Text>
          <Text style={styles.heroText}>保持一小段節奏，把單字變成每天都做得到的事。</Text>
        </View>
        <View style={styles.ring}>
          <Text style={styles.ringValue}>{dailyPercent}%</Text>
          <Text style={styles.ringLabel}>完成</Text>
        </View>
      </View>

      <View style={styles.progressCard}>
        <View style={styles.rowBetween}>
          <Text style={styles.sectionTitle}>今日進度</Text>
          <Text style={styles.cardMeta}>
            {stats.studiedToday} / {progress.dailyTarget}
          </Text>
        </View>
        <View style={styles.progressTrack}>
          <View style={[styles.progressFill, { width: `${dailyPercent}%` }]} />
        </View>
        <AnimatedPressable accessibilityRole="button" onPress={onStartStudy} pressTone="primary" style={styles.primaryButton}>
          <BookOpen size={18} color="#fff" strokeWidth={2.3} />
          <Text style={styles.primaryButtonText}>開始學習</Text>
          <ChevronRight size={18} color="#fff" strokeWidth={2.3} />
        </AnimatedPressable>
        <AnimatedPressable accessibilityRole="button" onPress={onOpenAccount} pressTone="secondary" style={styles.accountShortcut}>
          <User size={17} color="#172033" strokeWidth={2.3} />
          <Text style={styles.accountShortcutText}>帳號登入與同步</Text>
        </AnimatedPressable>
      </View>

      <View style={styles.statsGrid}>
        <StatCard label="連續天數" value={progress.streak.toString()} tone="green" />
        <StatCard label="已掌握" value={stats.mastered.toString()} tone="blue" />
        <StatCard label="待複習" value={stats.review.toString()} tone="orange" />
      </View>

      <AnimatedPressable accessibilityRole="button" onPress={onOpenReview} pressTone="list" style={styles.reviewStrip}>
        <RotateCcw size={20} color="#d97706" strokeWidth={2.4} />
        <View style={styles.flexOne}>
          <Text style={styles.reviewTitle}>複習清單</Text>
          <Text style={styles.reviewText}>{stats.review > 0 ? `${stats.review} 個單字需要再看一次` : '目前沒有卡住的單字'}</Text>
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
  motionStyle,
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
  motionStyle: StyleProp<ViewStyle>;
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

  return (
    <View style={styles.screenStack}>
      <FilterControlPanel
        activeFilter={activeFilter}
        activeInitial={activeInitial}
        activeLevel={activeLevel}
        count={wordCount}
        open={filtersOpen}
        showStatus
        testID="study-filter-toggle"
        title="學習篩選"
        onFilterChange={onFilterChange}
        onInitialChange={onInitialChange}
        onLevelChange={onLevelChange}
        onToggle={onFiltersToggle}
      />

      {!word && (
        <View style={styles.emptyState}>
          <Text style={styles.emptyTitle}>沒有符合的學習單字</Text>
          <Text style={styles.emptyText}>可以放寬狀態、分級或字首篩選。</Text>
        </View>
      )}

      {word && (
        <>
      <Animated.View style={[styles.wordCard, motionStyle]}>
        <View style={styles.rowBetween}>
          <View style={styles.groupPill}>
            <Text style={styles.groupText}>{word.group}</Text>
          </View>
          <AnimatedPressable
            accessibilityLabel={favorited ? '取消收藏這個單字' : '收藏這個單字'}
            accessibilityRole="button"
            onPress={onFavorite}
            pressTone="icon"
            style={styles.iconButton}
          >
            <Star size={20} color={favorited ? '#f59e0b' : '#717987'} fill={favorited ? '#f59e0b' : 'transparent'} />
          </AnimatedPressable>
        </View>
        <Text style={styles.bigWord}>{word.word}</Text>
        <Text style={styles.pronunciation}>{word.pronunciation}</Text>
        <View style={styles.meaningBlock}>
          <Text style={styles.partOfSpeech}>{word.partOfSpeech}</Text>
          <Text style={styles.meaning}>{word.meaningZh}</Text>
        </View>
        <View style={styles.exampleBox}>
          <Text style={styles.example}>{word.example}</Text>
          <Text style={styles.exampleZh}>{word.exampleZh}</Text>
        </View>
      </Animated.View>

      <View style={styles.actionGrid}>
        <AnimatedPressable accessibilityRole="button" onPress={onReview} pressTone="secondary" style={styles.secondaryButton}>
          <RotateCcw size={18} color="#9a3412" strokeWidth={2.3} />
          <Text style={styles.secondaryButtonText}>再複習</Text>
        </AnimatedPressable>
        <AnimatedPressable accessibilityRole="button" onPress={onKnown} pressTone="primary" style={styles.confirmButton}>
          <Check size={18} color="#fff" strokeWidth={2.4} />
          <Text style={styles.confirmButtonText}>已會</Text>
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
  open,
  showStatus,
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
  open: boolean;
  showStatus: boolean;
  testID: string;
  title: string;
  onFilterChange: (filter: LibraryFilter) => void;
  onInitialChange: (initial: string) => void;
  onLevelChange: (level: string) => void;
  onToggle: () => void;
}) {
  const summary = filterSummary(activeFilter, activeLevel, activeInitial, showStatus);

  return (
    <View style={styles.foldedFilterCard}>
      <AnimatedPressable
        accessibilityRole="button"
        onPress={onToggle}
        pressTone="secondary"
        style={styles.filterSummaryButton}
        testID={testID}
      >
        <View style={styles.flexOne}>
          <Text style={styles.filterSummaryTitle}>{title}</Text>
          <Text style={styles.filterSummaryText}>
            {summary} · {count} 個
          </Text>
        </View>
        <View style={styles.filterSummaryIcon}>
          <SlidersHorizontal size={16} color="#172033" strokeWidth={2.4} />
          <ChevronDown size={15} color="#172033" strokeWidth={2.4} style={open ? styles.filterChevronOpen : undefined} />
        </View>
      </AnimatedPressable>

      <AnimatedFilterPanel open={open} testID={`${testID}-panel`}>
          {showStatus && (
            <View style={styles.filterSection}>
              <Text style={styles.filterSectionTitle}>狀態</Text>
              <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.filterRow}>
                {filters.map((filter) => {
                  const selected = activeFilter === filter.id;
                  return (
                    <AnimatedPressable
                      accessibilityRole="button"
                      key={filter.id}
                      onPress={() => onFilterChange(filter.id)}
                      pressTone="chip"
                      style={[styles.filterChip, selected && styles.filterChipActive]}
                    >
                      <Text style={[styles.filterText, selected && styles.filterTextActive]}>{filter.label}</Text>
                    </AnimatedPressable>
                  );
                })}
              </ScrollView>
            </View>
          )}

          <View style={styles.filterSection}>
            <Text style={styles.filterSectionTitle}>分級</Text>
            <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.filterRow}>
              {levelFilters.map((level) => {
                const selected = activeLevel === level.id;
                return (
                  <AnimatedPressable
                    accessibilityLabel={`分級 ${level.label}`}
                    accessibilityRole="button"
                    key={level.id}
                    onPress={() => onLevelChange(level.id)}
                    pressTone="chip"
                    style={[styles.filterChip, selected && styles.levelChipActive]}
                  >
                    <Text style={[styles.filterText, selected && styles.filterTextActive]}>{level.label}</Text>
                  </AnimatedPressable>
                );
              })}
            </ScrollView>
          </View>

          <View style={styles.filterSection}>
            <Text style={styles.filterSectionTitle}>字首</Text>
            <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.letterRow}>
              {alphabetFilters.map((initial) => {
                const selected = activeInitial === initial.id;
                return (
                  <AnimatedPressable
                    accessibilityLabel={initial.id === 'all' ? '字首 全部' : `字首 ${initial.id}`}
                    accessibilityRole="button"
                    key={initial.id}
                    onPress={() => onInitialChange(initial.id)}
                    pressTone="chip"
                    style={[styles.letterChip, selected && styles.letterChipActive]}
                  >
                    <Text style={[styles.letterText, selected && styles.letterTextActive]}>{initial.label}</Text>
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
  motionStyle,
  options,
  questionCount,
  questionCounts,
  questionIndex,
  quizFinished,
  quizStarted,
  result,
  sessionTotal,
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
  motionStyle: StyleProp<ViewStyle>;
  options: ReturnType<typeof buildQuizOptions>;
  questionCount: (typeof quizQuestionCounts)[number];
  questionCounts: readonly (typeof quizQuestionCounts)[number][];
  questionIndex: number;
  quizFinished: boolean;
  quizStarted: boolean;
  result: 'correct' | 'wrong' | null;
  sessionTotal: number;
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
  return (
    <View style={styles.screenStack}>
      <FilterControlPanel
        activeFilter={activeFilter}
        activeInitial={activeInitial}
        activeLevel={activeLevel}
        count={wordCount}
        open={filtersOpen}
        showStatus
        testID="quiz-filter-toggle"
        title="測驗篩選"
        onFilterChange={onFilterChange}
        onInitialChange={onInitialChange}
        onLevelChange={onLevelChange}
        onToggle={onFiltersToggle}
      />

      {!quizStarted && !quizFinished && (
        <Animated.View style={[styles.quizSetupCard, motionStyle]}>
          <View style={styles.rowBetween}>
            <View>
              <Text style={styles.sectionTitle}>選擇題數</Text>
              <Text style={styles.cardMeta}>目前題庫 {wordCount} 個單字</Text>
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
                  style={[styles.quizCountChip, selected && styles.quizCountChipActive]}
                >
                  <Text style={[styles.quizCountText, selected && styles.quizCountTextActive]}>{count} 題</Text>
                  {cappedCount < count && <Text style={[styles.quizCountMeta, selected && styles.quizCountTextActive]}>出 {cappedCount}</Text>}
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
            <Text style={styles.primaryButtonText}>開始測驗</Text>
          </AnimatedPressable>
        </Animated.View>
      )}

      {quizFinished && (
        <Animated.View style={[styles.quizSetupCard, motionStyle]}>
          <Text style={styles.eyebrow}>RESULT</Text>
          <Text style={styles.resultTitle}>測驗完成</Text>
          <Text style={styles.quizScoreText}>
            答對 {correctCount} / {sessionTotal} 題
          </Text>
          <AnimatedPressable accessibilityRole="button" onPress={onRestart} pressTone="primary" style={styles.primaryButton}>
            <RotateCcw size={18} color="#fff" strokeWidth={2.3} />
            <Text style={styles.primaryButtonText}>重新選題</Text>
          </AnimatedPressable>
        </Animated.View>
      )}

      {quizStarted && !word && (
        <View style={styles.emptyState}>
          <Text style={styles.emptyTitle}>沒有符合的測驗題目</Text>
          <Text style={styles.emptyText}>可以放寬狀態、分級或字首篩選。</Text>
        </View>
      )}

      {quizStarted && word && (
        <>
      <Animated.View style={[styles.quizCard, motionStyle]}>
        <Text style={styles.eyebrow}>
          QUIZ {questionIndex + 1} / {sessionTotal}
        </Text>
        <Text style={styles.bigWord}>{word.word}</Text>
        <Text style={styles.pronunciation}>{word.pronunciation}</Text>
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
                result !== null && option.correct && styles.quizOptionCorrect,
                result === 'wrong' && !option.correct && styles.quizOptionMuted,
              ]}
            >
              <Text style={[styles.quizOptionText, result !== null && option.correct && styles.quizOptionTextCorrect]}>
                {option.meaning}
              </Text>
            </AnimatedPressable>
          ))}
        </View>
      </Animated.View>

      {result && (
        <Animated.View style={[styles.resultCard, result === 'correct' ? styles.resultCorrect : styles.resultWrong, motionStyle]}>
          <Text style={styles.resultTitle}>{result === 'correct' ? '答對了' : '先放進複習'}</Text>
          <Text style={styles.resultText}>{word.exampleZh}</Text>
          <AnimatedPressable accessibilityRole="button" onPress={onNext} pressTone="secondary" style={styles.nextButton}>
            <Text style={styles.nextButtonText}>下一題</Text>
            <ChevronRight size={18} color="#172033" strokeWidth={2.3} />
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
  filtersOpen,
  listMotionStyle,
  progress,
  query,
  searchFocused,
  visibleStart,
  visibleWindowSize,
  words,
  onFavorite,
  onFilterChange,
  onFiltersToggle,
  onInitialChange,
  onLevelChange,
  onQueryChange,
  onQueryClear,
  onReturnTop,
  onSearchBlur,
  onSearchFocus,
}: {
  activeFilter: LibraryFilter;
  activeInitial: string;
  activeLevel: string;
  filtersOpen: boolean;
  listMotionStyle: (index: number) => StyleProp<ViewStyle>;
  progress: ProgressState;
  query: string;
  searchFocused: boolean;
  visibleStart: number;
  visibleWindowSize: number;
  words: WordEntry[];
  onFavorite: (wordId: string) => void;
  onFilterChange: (filter: LibraryFilter) => void;
  onFiltersToggle: () => void;
  onInitialChange: (initial: string) => void;
  onLevelChange: (level: string) => void;
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

  useEffect(() => {
    Animated.timing(searchAnim, {
      duration: interactionMotion.hoverMs,
      easing: Easing.out(Easing.cubic),
      toValue: searchFocused || hasQuery ? 1 : 0,
      useNativeDriver: true,
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

  return (
    <View style={styles.screenStack}>
      <View style={styles.libraryHeaderCard}>
        <View>
          <Text style={styles.libraryHeaderTitle}>完整字庫</Text>
          <Text style={styles.libraryHeaderMeta}>目前篩選後 {words.length} 個單字</Text>
        </View>
        <AnimatedPressable
          accessibilityRole="button"
          onPress={onReturnTop}
          pressTone="secondary"
          style={styles.libraryTopButton}
          testID="library-top-return"
        >
          <ArrowUp size={16} color="#172033" strokeWidth={2.5} />
          <Text style={styles.libraryTopButtonText}>回到頂端</Text>
        </AnimatedPressable>
      </View>

      <Animated.View style={searchMotionStyle}>
        <View style={[styles.searchBox, searchFocused && styles.searchBoxFocused, hasQuery && styles.searchBoxActive]}>
          <Search size={18} color={searchFocused ? '#2563eb' : '#717987'} strokeWidth={2.2} />
          <TextInput
            onChangeText={onQueryChange}
            onBlur={onSearchBlur}
            onFocus={onSearchFocus}
            placeholder="搜尋英文、中文或例句"
            placeholderTextColor="#9ca3af"
            style={styles.searchInput}
            value={query}
          />
          {hasQuery && (
            <AnimatedPressable
              accessibilityLabel="清除搜尋"
              accessibilityRole="button"
              onPress={onQueryClear}
              pressTone="icon"
              style={styles.searchClearButton}
              testID="library-search-clear"
            >
              <X size={16} color="#64748b" strokeWidth={2.5} />
            </AnimatedPressable>
          )}
        </View>
      </Animated.View>

      {hasQuery && (
        <Animated.View style={[styles.searchMetaBox, searchMetaMotionStyle]}>
          <Text style={styles.searchMetaText}>搜尋「{query.trim()}」：找到 {words.length} 個結果</Text>
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
              style={[styles.filterChip, selected && styles.filterChipActive]}
            >
              <Text style={[styles.filterText, selected && styles.filterTextActive]}>{filter.label}</Text>
            </AnimatedPressable>
          );
        })}
      </ScrollView>

      <FilterControlPanel
        activeFilter={activeFilter}
        activeInitial={activeInitial}
        activeLevel={activeLevel}
        count={words.length}
        open={filtersOpen}
        showStatus={false}
        testID="library-filter-toggle"
        title="分級 / 字首"
        onFilterChange={onFilterChange}
        onInitialChange={onInitialChange}
        onLevelChange={onLevelChange}
        onToggle={onFiltersToggle}
      />

      <View style={styles.libraryPanel}>
        <View style={styles.wordList}>
        <Text style={styles.resultCount}>
          共 {words.length} 個結果，顯示第 {words.length === 0 ? 0 : safeStart + 1}-{visibleEnd} 個
        </Text>
        {visibleWords.map((word, index) => {
          const wordProgress = progress.words[word.id];
          return (
            <Animated.View key={word.id} style={[styles.libraryItem, listMotionStyle(index)]}>
              <View style={styles.flexOne}>
                <View style={styles.wordLine}>
                  <Text style={styles.libraryWord}>{word.word}</Text>
                  <Text style={styles.libraryGroup}>{word.group}</Text>
                  <Text style={styles.libraryPos}>{word.partOfSpeech}</Text>
                </View>
                <Text style={styles.libraryMeaning}>{word.meaningZh}</Text>
                <Text style={styles.libraryExample}>{word.example}</Text>
              </View>
              <View style={styles.librarySide}>
                <AnimatedPressable
                  accessibilityLabel={`${wordProgress?.favorite ? '取消收藏' : '收藏'} ${word.word}`}
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
                <Text style={styles.statusText}>{statusLabel(wordProgress?.status)}</Text>
              </View>
            </Animated.View>
          );
        })}
        {words.length === 0 && (
          <View style={styles.emptyState}>
            <Text style={styles.emptyTitle}>沒有符合的單字</Text>
            <Text style={styles.emptyText}>
              {hasQuery ? '可以清除搜尋，或換一個分級、字首。' : '可以換一個分級、字首。'}
            </Text>
          </View>
        )}
        </View>
      </View>
    </View>
  );
}

function ProfileView({
  account,
  dailyPercent,
  onEmailChange,
  onPasswordChange,
  onShowInstallGuide,
  onSignIn,
  onSignOut,
  onSignUp,
  progress,
  stats,
}: {
  account: AccountState;
  dailyPercent: number;
  progress: ProgressState;
  stats: ReturnType<typeof computeStats>;
  onEmailChange: (email: string) => void;
  onPasswordChange: (password: string) => void;
  onShowInstallGuide: () => void;
  onSignIn: () => void;
  onSignOut: () => void;
  onSignUp: () => void;
}) {
  const signedIn = Boolean(account.userId);
  const syncError = account.status === 'error';

  return (
    <View style={styles.screenStack}>
      <View style={styles.profileCard}>
        <View style={styles.avatar}>
          <User size={32} color="#172033" strokeWidth={2.2} />
        </View>
        <Text style={styles.profileTitle}>{signedIn ? account.userEmail : '穩定累積中'}</Text>
        <Text style={styles.profileText}>今天完成 {dailyPercent}%，目前掌握 {stats.mastered} 個單字。</Text>
        <View style={[styles.syncPill, syncError && styles.syncPillError]}>
          <Cloud size={15} color={syncError ? '#b91c1c' : '#166534'} strokeWidth={2.3} />
          <Text style={[styles.syncText, syncError && styles.syncTextError]}>{account.message}</Text>
        </View>
      </View>

      <View style={styles.accountCard}>
        <View style={styles.rowBetween}>
          <Text style={styles.sectionTitle}>帳號</Text>
          <Text style={styles.cardMeta}>{account.configured ? (signedIn ? '已登入' : '未登入') : '本機'}</Text>
        </View>

        {!signedIn && (
          <View style={styles.inputStack}>
            {!account.configured && (
              <View style={styles.localOnlyBox}>
                <Text style={styles.localOnlyTitle}>帳號登入尚未啟用</Text>
                <Text style={styles.localOnlyText}>目前先用本機記憶；Cloudflare 設好 Supabase 後，這裡就能登入同步。</Text>
              </View>
            )}
            <View style={styles.inputBox}>
              <Mail size={17} color="#717987" strokeWidth={2.2} />
              <TextInput
                autoCapitalize="none"
                editable={account.configured && !account.busy}
                keyboardType="email-address"
                onChangeText={onEmailChange}
                placeholder="Email"
                placeholderTextColor="#9ca3af"
                style={styles.accountInput}
                value={account.email}
              />
            </View>
            <View style={styles.inputBox}>
              <Lock size={17} color="#717987" strokeWidth={2.2} />
              <TextInput
                editable={account.configured && !account.busy}
                onChangeText={onPasswordChange}
                placeholder="密碼"
                placeholderTextColor="#9ca3af"
                secureTextEntry
                style={styles.accountInput}
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
                <Text style={styles.accountButtonText}>登入</Text>
              </AnimatedPressable>
              <AnimatedPressable
                accessibilityRole="button"
                disabled={!account.configured || account.busy}
                onPress={onSignUp}
                pressTone="secondary"
                style={[styles.outlineButton, (!account.configured || account.busy) && styles.disabledButton]}
              >
                <Text style={styles.outlineButtonText}>註冊</Text>
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
            <Text style={styles.signOutButtonText}>登出</Text>
          </AnimatedPressable>
        )}
      </View>

      <View style={styles.settingsCard}>
        <AnimatedPressable
          accessibilityRole="button"
          onPress={onShowInstallGuide}
          pressTone="secondary"
          style={styles.installGuideReplayButton}
        >
          <Smartphone size={17} color="#172033" strokeWidth={2.3} />
          <Text style={styles.installGuideReplayText}>重新查看加入主畫面教學</Text>
          <ChevronRight size={17} color="#64748b" strokeWidth={2.3} />
        </AnimatedPressable>
        <View style={styles.rowBetween}>
          <Text style={styles.sectionTitle}>每日目標</Text>
          <Text style={styles.settingValue}>{progress.dailyTarget} words</Text>
        </View>
        <View style={styles.rowBetween}>
          <Text style={styles.sectionTitle}>收藏單字</Text>
          <Text style={styles.settingValue}>{stats.favorites}</Text>
        </View>
        <View style={styles.rowBetween}>
          <Text style={styles.sectionTitle}>剩餘樣本</Text>
          <Text style={styles.settingValue}>{stats.remaining}</Text>
        </View>
      </View>
    </View>
  );
}

function StatCard({ label, tone, value }: { label: string; tone: 'blue' | 'green' | 'orange'; value: string }) {
  return (
    <View style={[styles.statCard, styles[`${tone}Tint`]]}>
      <Text style={styles.statValue}>{value}</Text>
      <Text style={styles.statLabel}>{label}</Text>
    </View>
  );
}

function statusLabel(status?: string) {
  if (status === 'mastered') {
    return '已會';
  }
  if (status === 'review') {
    return '複習';
  }
  return '未背';
}

function filterSummary(filter: LibraryFilter, level: string, initial: string, showStatus: boolean): string {
  const parts = [levelLabel(level), initialLabel(initial)];
  if (showStatus) {
    parts.unshift(filterLabel(filter));
  }
  return parts.join(' / ');
}

function filterLabel(filter: LibraryFilter): string {
  return filters.find((item) => item.id === filter)?.label ?? '全部';
}

function levelLabel(level: string): string {
  return levelFilters.find((item) => item.id === level)?.label ?? '全部分級';
}

function initialLabel(initial: string): string {
  return alphabetFilters.find((item) => item.id === initial)?.label ?? '全部';
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
    width: 108,
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

