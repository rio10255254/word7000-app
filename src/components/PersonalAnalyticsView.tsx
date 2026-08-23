import {
  BookOpen,
  Brain,
  CalendarDays,
  ChartColumn,
  ChevronLeft,
  Flame,
  Languages,
  Target,
} from 'lucide-react-native';
import { useCallback, useEffect, useMemo, useRef, useState, type ReactNode } from 'react';
import { Pressable, StyleSheet, Text, View, type LayoutChangeEvent } from 'react-native';
import { Gesture, GestureDetector } from 'react-native-gesture-handler';
import { runOnJS, useSharedValue } from 'react-native-reanimated';
import Svg, {
  Circle as SvgCircle,
  Defs as SvgDefs,
  LinearGradient as SvgLinearGradient,
  Line as SvgLine,
  Path as SvgPath,
  Stop as SvgStop,
} from 'react-native-svg';
import type { WordEntry } from '../data/words';
import { iosVisual } from '../design/iosVisualSystem';
import {
  buildPersonalLearningAnalytics,
  type LearningChartPoint,
} from '../lib/learningAnalytics';
import { computeStats, type ProgressState } from '../lib/progress';
import { triggerPressHaptic } from '../lib/haptics';
import { useRuntimePerformance } from '../lib/runtimePerformance';

type StudyMode = 'chinese' | 'english';
type ThemeMode = 'dark' | 'light';
type Period = 7 | 30;

export function PersonalAnalyticsView({
  onBack,
  progress,
  studyMode,
  themeMode,
  today,
  vocabularyWords,
}: {
  onBack: () => void;
  progress: ProgressState;
  studyMode: StudyMode;
  themeMode: ThemeMode;
  today: string;
  vocabularyWords: WordEntry[];
}) {
  const [period, setPeriod] = useState<Period>(7);
  const lastChartHapticAt = useRef(0);
  const runtimePerformance = useRuntimePerformance();
  const palette = themeMode === 'dark' ? iosVisual.dark : iosVisual.light;
  const chineseUi = studyMode === 'english';
  const copy = chineseUi ? zhCopy : enCopy;
  const stats = useMemo(() => computeStats(vocabularyWords, progress), [progress, vocabularyWords]);
  const analytics = useMemo(
    () => buildPersonalLearningAnalytics(progress, stats, vocabularyWords.length, today),
    [progress, stats, today, vocabularyWords.length],
  );
  const chart = period === 7 ? analytics.chart7 : analytics.chart30;
  const [selectedDate, setSelectedDate] = useState(today);
  const activeDays = period === 7 ? analytics.activeDays7 : analytics.activeDays30;
  const maxActions = Math.max(1, progress.dailyTarget, ...chart.map((day) => day.actions));
  const newWords = Math.max(0, vocabularyWords.length - analytics.mastered - analytics.reviewWords);
  const selectedPoint = chart.find((point) => point.date === selectedDate) ?? chart.at(-1) ?? null;

  useEffect(() => {
    if (!chart.some((point) => point.date === selectedDate)) {
      setSelectedDate(chart.at(-1)?.date ?? today);
    }
  }, [chart, selectedDate, today]);

  const selectChartDate = useCallback((date: string) => {
    if (date !== selectedDate) {
      const now = Date.now();
      if (!runtimePerformance.lowPowerMode && now - lastChartHapticAt.current >= 45) {
        triggerPressHaptic('chip');
        lastChartHapticAt.current = now;
      }
      setSelectedDate(date);
    }
  }, [runtimePerformance.lowPowerMode, selectedDate]);

  const selectPeriod = (next: Period) => {
    if (next !== period) {
      if (!runtimePerformance.lowPowerMode) {
        triggerPressHaptic('chip');
      }
      setPeriod(next);
    }
  };

  return (
    <View style={styles.stack} testID="personal-analytics-panel">
      <Pressable
        accessibilityRole="button"
        onPress={onBack}
        style={({ pressed }) => [
          styles.backButton,
          { backgroundColor: palette.surfaceSecondary, borderColor: palette.separatorStrong },
          pressed && styles.pressed,
        ]}
      >
        <ChevronLeft size={18} color={palette.label} strokeWidth={2.5} />
        <Text style={[styles.backText, { color: palette.label }]}>{copy.back}</Text>
      </Pressable>

      <View style={styles.heroHeader}>
        <View style={styles.flexOne}>
          <Text style={[styles.eyebrow, { color: palette.accent }]}>{copy.eyebrow}</Text>
          <Text style={[styles.title, { color: palette.label }]}>{copy.title}</Text>
          <Text style={[styles.subtitle, { color: palette.labelSecondary }]}>{copy.subtitle}</Text>
        </View>
        <View style={[styles.heroIcon, { backgroundColor: palette.accentSoft, borderColor: palette.accentBorder }]}>
          <ChartColumn size={25} color={palette.accent} strokeWidth={2.4} />
        </View>
      </View>

      <View style={[styles.heroSurface, { backgroundColor: palette.surface, borderColor: palette.separatorStrong }]}>
        <View style={styles.heroMetric}>
          <Text style={[styles.heroMetricValue, { color: palette.label }]}>{analytics.weeklyActions}</Text>
          <Text style={[styles.metricLabel, { color: palette.labelSecondary }]}>{copy.thisWeek}</Text>
        </View>
        <View style={[styles.verticalDivider, { backgroundColor: palette.separator }]} />
        <View style={styles.heroMetric}>
          <Text style={[styles.heroMetricValue, { color: palette.orange }]}>{progress.streak}</Text>
          <Text style={[styles.metricLabel, { color: palette.labelSecondary }]}>{copy.currentStreak}</Text>
        </View>
        <View style={[styles.verticalDivider, { backgroundColor: palette.separator }]} />
        <View style={styles.heroMetric}>
          <Text style={[styles.heroMetricValue, { color: palette.green }]}>
            {formatWeeklyChange(analytics.weeklyChangePercent)}
          </Text>
          <Text style={[styles.metricLabel, { color: palette.labelSecondary }]}>{copy.weeklyChange}</Text>
        </View>
      </View>

      <AnalyticsSection
        icon={<CalendarDays size={20} color={palette.accent} strokeWidth={2.3} />}
        palette={palette}
        title={copy.activityTrend}
        trailing={(
          <View style={[styles.segmented, { backgroundColor: palette.surfaceTertiary }]}>
            {([7, 30] as const).map((value) => (
              <Pressable
                key={value}
                accessibilityRole="button"
                onPress={() => selectPeriod(value)}
                style={[
                  styles.segment,
                  period === value && { backgroundColor: palette.surface, borderColor: palette.separatorStrong },
                ]}
              >
                <Text style={[styles.segmentText, { color: period === value ? palette.label : palette.labelSecondary }]}>
                  {copy.days(value)}
                </Text>
              </Pressable>
            ))}
          </View>
        )}
      >
        {selectedPoint && (
          <View style={[styles.selectedSummary, { backgroundColor: palette.surfaceSecondary }]}>
            <View>
              <Text style={[styles.selectedDate, { color: palette.label }]}>
                {longDateLabel(selectedPoint.date, chineseUi)}
              </Text>
              <Text style={[styles.selectedDetail, { color: palette.labelSecondary }]}>
                {copy.selectedActions(selectedPoint.actions)}
              </Text>
            </View>
            <View style={[styles.goalBadge, { backgroundColor: selectedPoint.goalActions >= progress.dailyTarget ? palette.greenSoft : palette.surfaceTertiary }]}>
              <Text style={[styles.goalBadgeText, { color: selectedPoint.goalActions >= progress.dailyTarget ? palette.green : palette.labelSecondary }]}>
                {copy.goalProgress(selectedPoint.goalActions, progress.dailyTarget)}
              </Text>
            </View>
          </View>
        )}
        <ActivityChart
          chart={chart}
          dailyTarget={progress.dailyTarget}
          goalLabel={copy.dailyGoalLine}
          maxActions={maxActions}
          onSelectDate={selectChartDate}
          palette={palette}
          period={period}
          selectedDate={selectedPoint?.date ?? null}
        />
        <View style={[styles.sectionDivider, { backgroundColor: palette.separator }]} />
        <View style={styles.metricsGrid}>
          <Metric value={activeDays.toString()} label={copy.activeDays} palette={palette} />
          <Metric value={analytics.averagePerActiveDay30.toString()} label={copy.dailyAverage} palette={palette} />
          <Metric value={analytics.learningMinutes.toString()} label={copy.learningMinutes} palette={palette} />
          <Metric value={analytics.sessions.toString()} label={copy.learningSessions} palette={palette} />
          <Metric value={analytics.goalDays30.toString()} label={copy.goalDays} palette={palette} />
          <Metric value={formatBestDay(analytics.bestDay, chineseUi)} label={copy.bestDay} palette={palette} />
        </View>
      </AnalyticsSection>

      <AnalyticsSection
        icon={<Target size={20} color={palette.green} strokeWidth={2.3} />}
        palette={palette}
        title={copy.learningResults}
      >
        <View style={styles.metricsGrid}>
          <Metric value={`${analytics.masteryRate}%`} label={copy.masteryRate} palette={palette} />
          <Metric value={analytics.mastered.toString()} label={copy.mastered} palette={palette} />
          <Metric value={analytics.reviewWords.toString()} label={copy.reviewWords} palette={palette} />
          <Metric value={analytics.difficultWords.toString()} label={copy.difficultWords} palette={palette} />
        </View>
        <DistributionBar
          parts={[
            { color: palette.green, value: analytics.mastered },
            { color: palette.orange, value: analytics.reviewWords },
            { color: palette.separatorStrong, value: newWords },
          ]}
          total={vocabularyWords.length}
          trackColor={palette.surfaceTertiary}
        />
        <View style={styles.legendRow}>
          <Legend color={palette.green} label={copy.mastered} value={analytics.mastered} palette={palette} />
          <Legend color={palette.orange} label={copy.reviewWords} value={analytics.reviewWords} palette={palette} />
          <Legend color={palette.separatorStrong} label={copy.notStudied} value={newWords} palette={palette} />
        </View>
      </AnalyticsSection>

      <AnalyticsSection
        icon={<Brain size={20} color={palette.indigo} strokeWidth={2.3} />}
        palette={palette}
        title={copy.learningMethods}
      >
        <MethodRow icon={<BookOpen size={18} color={palette.accent} />} label={copy.studyCards} value={analytics.studyActions} palette={palette} />
        <MethodRow
          icon={<Target size={18} color={palette.green} />}
          label={copy.quizAttempts}
          value={analytics.quizAttempts}
          detail={analytics.quizAccuracy === null ? copy.noAccuracy : `${analytics.quizAccuracy}%`}
          palette={palette}
        />
        <MethodRow
          detail={copy.speakingSkipped(analytics.speakingSkipped)}
          icon={<Languages size={18} color={palette.indigo} />}
          label={copy.speakingCards}
          value={analytics.speakingCompleted}
          palette={palette}
        />
        <View style={[styles.sectionDivider, { backgroundColor: palette.separator }]} />
        <Text style={[styles.subheading, { color: palette.labelSecondary }]}>{copy.modeMix}</Text>
        <DistributionBar
          parts={[
            { color: palette.accent, value: analytics.englishActions },
            { color: palette.indigo, value: analytics.chineseActions },
          ]}
          total={Math.max(1, analytics.englishActions + analytics.chineseActions)}
          trackColor={palette.surfaceTertiary}
        />
        <View style={styles.legendRow}>
          <Legend color={palette.accent} label={copy.englishMode} value={analytics.englishActions} palette={palette} />
          <Legend color={palette.indigo} label={copy.chineseMode} value={analytics.chineseActions} palette={palette} />
        </View>
      </AnalyticsSection>

      <AnalyticsSection
        icon={<Flame size={20} color={palette.orange} strokeWidth={2.3} />}
        palette={palette}
        title={copy.streakRecord}
      >
        <View style={styles.metricsGrid}>
          <Metric value={progress.streak.toString()} label={copy.currentStreak} palette={palette} />
          <Metric value={analytics.bestStreak.toString()} label={copy.bestStreak} palette={palette} />
          <Metric value={analytics.totalActions.toString()} label={copy.recordedActions} palette={palette} />
          <Metric value={analytics.todayActions.toString()} label={copy.todayActions} palette={palette} />
        </View>
      </AnalyticsSection>

      <View style={[styles.insight, { backgroundColor: palette.accentSoft, borderColor: palette.accentBorder }]}>
        <View style={[styles.insightIcon, { backgroundColor: palette.surface }]}>
          <Brain size={21} color={palette.accent} strokeWidth={2.3} />
        </View>
        <View style={styles.flexOne}>
          <Text style={[styles.insightTitle, { color: palette.label }]}>{copy.personalInsight}</Text>
          <Text style={[styles.insightText, { color: palette.labelSecondary }]}>{copy.focus[analytics.focus]}</Text>
        </View>
      </View>

      <Text style={[styles.dataNote, { color: palette.labelTertiary }]}>{copy.dataNote}</Text>
    </View>
  );
}

function AnalyticsSection({ children, icon, palette, title, trailing }: {
  children: ReactNode;
  icon: ReactNode;
  palette: typeof iosVisual.light | typeof iosVisual.dark;
  title: string;
  trailing?: ReactNode;
}) {
  return (
    <View style={[styles.section, { backgroundColor: palette.surface, borderColor: palette.separatorStrong }]}>
      <View style={styles.sectionHeader}>
        <View style={[styles.sectionIcon, { backgroundColor: palette.surfaceSecondary }]}>{icon}</View>
        <Text style={[styles.sectionTitle, { color: palette.label }]}>{title}</Text>
        <View style={styles.flexOne} />
        {trailing}
      </View>
      {children}
    </View>
  );
}

function ActivityChart({ chart, dailyTarget, goalLabel, maxActions, onSelectDate, palette, period, selectedDate }: {
  chart: LearningChartPoint[];
  dailyTarget: number;
  goalLabel: string;
  maxActions: number;
  onSelectDate: (date: string) => void;
  palette: typeof iosVisual.light | typeof iosVisual.dark;
  period: Period;
  selectedDate: string | null;
}) {
  const [chartWidth, setChartWidth] = useState(320);
  const selectedIndex = useSharedValue(-1);
  const selectIndex = useCallback((index: number) => {
    const point = chart[Math.max(0, Math.min(chart.length - 1, index))];
    if (point) {
      onSelectDate(point.date);
    }
  }, [chart, onSelectDate]);
  const handleLayout = useCallback((event: LayoutChangeEvent) => {
    setChartWidth(Math.max(1, event.nativeEvent.layout.width));
  }, []);
  const scrubGesture = useMemo(() => {
    const selectAtX = (x: number) => {
      'worklet';
      const index = Math.max(0, Math.min(chart.length - 1, Math.floor((x / chartWidth) * chart.length)));
      if (index !== selectedIndex.value) {
        selectedIndex.value = index;
        runOnJS(selectIndex)(index);
      }
    };
    const pan = Gesture.Pan()
      .activeOffsetX([-4, 4])
      .failOffsetY([-10, 10])
      .onStart((event) => selectAtX(event.x))
      .onUpdate((event) => selectAtX(event.x));
    const tap = Gesture.Tap().onEnd((event) => selectAtX(event.x));
    return Gesture.Race(pan, tap);
  }, [chart.length, chartWidth, selectIndex, selectedIndex]);
  const chartGeometry = useMemo(() => {
    const horizontalInset = 7;
    const plotHeight = 76;
    const topInset = 7;
    const usableWidth = Math.max(1, chartWidth - horizontalInset * 2);
    const points = chart.map((point, index) => ({
      ...point,
      x: horizontalInset + (chart.length <= 1 ? 0 : (index / (chart.length - 1)) * usableWidth),
      y: topInset + plotHeight - (point.actions / maxActions) * plotHeight,
    }));
    const linePath = points.map((point, index) => `${index === 0 ? 'M' : 'L'} ${point.x} ${point.y}`).join(' ');
    const baseline = topInset + plotHeight;
    const areaPath = points.length > 0
      ? `${linePath} L ${points.at(-1)!.x} ${baseline} L ${points[0].x} ${baseline} Z`
      : '';
    const goalY = topInset + plotHeight - (Math.min(maxActions, dailyTarget) / maxActions) * plotHeight;
    return { areaPath, baseline, goalY, linePath, points, topInset };
  }, [chart, chartWidth, dailyTarget, maxActions]);
  const selectedPoint = chartGeometry.points.find((point) => point.date === selectedDate) ?? null;

  return (
    <GestureDetector gesture={scrubGesture}>
      <View accessibilityLabel="Interactive learning trend chart" onLayout={handleLayout} style={styles.chart}>
        <Svg height={92} width="100%" viewBox={`0 0 ${chartWidth} 92`}>
          <SvgDefs>
            <SvgLinearGradient id="analyticsArea" x1="0" y1="0" x2="0" y2="1">
              <SvgStop offset="0" stopColor={palette.accent} stopOpacity="0.3" />
              <SvgStop offset="1" stopColor={palette.accent} stopOpacity="0.02" />
            </SvgLinearGradient>
          </SvgDefs>
          {[0, 0.5, 1].map((ratio) => {
            const y = chartGeometry.topInset + ratio * (chartGeometry.baseline - chartGeometry.topInset);
            return <SvgLine key={ratio} x1={7} x2={chartWidth - 7} y1={y} y2={y} stroke={palette.separator} strokeWidth={0.7} />;
          })}
          <SvgLine
            x1={7}
            x2={chartWidth - 7}
            y1={chartGeometry.goalY}
            y2={chartGeometry.goalY}
            stroke={palette.green}
            strokeDasharray="4 4"
            strokeOpacity={0.65}
            strokeWidth={1}
          />
          {chartGeometry.areaPath ? <SvgPath d={chartGeometry.areaPath} fill="url(#analyticsArea)" /> : null}
          {chartGeometry.linePath ? (
            <SvgPath
              d={chartGeometry.linePath}
              fill="none"
              stroke={palette.accent}
              strokeLinecap="round"
              strokeLinejoin="round"
              strokeWidth={2.5}
            />
          ) : null}
          {period === 7 && chartGeometry.points.map((point) => (
            <SvgCircle
              key={point.date}
              cx={point.x}
              cy={point.y}
              fill={palette.surface}
              r={3}
              stroke={palette.accent}
              strokeWidth={1.8}
            />
          ))}
          {selectedPoint ? (
            <>
              <SvgLine
                x1={selectedPoint.x}
                x2={selectedPoint.x}
                y1={chartGeometry.topInset}
                y2={chartGeometry.baseline}
                stroke={palette.accent}
                strokeOpacity={0.28}
                strokeWidth={1}
              />
              <SvgCircle cx={selectedPoint.x} cy={selectedPoint.y} fill={palette.accent} opacity={0.18} r={8} />
              <SvgCircle cx={selectedPoint.x} cy={selectedPoint.y} fill={palette.surface} r={4.5} stroke={palette.accent} strokeWidth={2.4} />
            </>
          ) : null}
        </Svg>
        <View style={styles.chartLabels}>
          {chart.map((point, index) => {
            const selected = point.date === selectedDate;
            const showLabel = period === 7 || selected || index % 5 === 0 || index === chart.length - 1;
            return (
              <Text key={point.date} numberOfLines={1} style={[
                styles.chartLabel,
                { color: selected ? palette.accent : palette.labelTertiary, fontWeight: selected ? '700' : '500' },
              ]}>
                {showLabel ? shortDateLabel(point.date) : ''}
              </Text>
            );
          })}
        </View>
        <View style={styles.chartGoalLegend}>
          <View style={[styles.chartGoalDot, { backgroundColor: palette.green }]} />
          <Text style={[styles.chartGoalText, { color: palette.labelTertiary }]}>{goalLabel}</Text>
        </View>
      </View>
    </GestureDetector>
  );
}

function Metric({ label, palette, value }: { label: string; palette: typeof iosVisual.light | typeof iosVisual.dark; value: string }) {
  return (
    <View style={styles.metric}>
      <Text adjustsFontSizeToFit minimumFontScale={0.74} numberOfLines={1} style={[styles.metricValue, { color: palette.label }]}>{value}</Text>
      <Text numberOfLines={2} style={[styles.metricLabel, { color: palette.labelSecondary }]}>{label}</Text>
    </View>
  );
}

function MethodRow({ detail, icon, label, palette, value }: {
  detail?: string;
  icon: ReactNode;
  label: string;
  palette: typeof iosVisual.light | typeof iosVisual.dark;
  value: number;
}) {
  return (
    <View style={[styles.methodRow, { borderBottomColor: palette.separator }]}>
      <View style={[styles.methodIcon, { backgroundColor: palette.surfaceSecondary }]}>{icon}</View>
      <Text style={[styles.methodLabel, { color: palette.label }]}>{label}</Text>
      {detail ? <Text style={[styles.methodDetail, { color: palette.labelSecondary }]}>{detail}</Text> : null}
      <Text style={[styles.methodValue, { color: palette.label }]}>{value}</Text>
    </View>
  );
}

function DistributionBar({ parts, total, trackColor }: { parts: Array<{ color: string; value: number }>; total: number; trackColor: string }) {
  return (
    <View style={[styles.distributionBar, { backgroundColor: trackColor }]}>
      {parts.filter((part) => part.value > 0).map((part, index) => (
        <View key={`${part.color}-${index}`} style={{ backgroundColor: part.color, flex: part.value / Math.max(1, total) }} />
      ))}
    </View>
  );
}

function Legend({ color, label, palette, value }: {
  color: string;
  label: string;
  palette: typeof iosVisual.light | typeof iosVisual.dark;
  value: number;
}) {
  return (
    <View style={styles.legendItem}>
      <View style={[styles.legendDot, { backgroundColor: color }]} />
      <Text style={[styles.legendText, { color: palette.labelSecondary }]}>{label} {value}</Text>
    </View>
  );
}

function formatWeeklyChange(value: number | null): string {
  if (value === null) return '–';
  return `${value >= 0 ? '+' : ''}${value}%`;
}

function formatBestDay(day: LearningChartPoint | null, chineseUi: boolean): string {
  if (!day || day.actions === 0) return '–';
  const [, month, date] = day.date.split('-');
  return chineseUi ? `${Number(month)}/${Number(date)}` : `${Number(month)}/${Number(date)}`;
}

function shortDateLabel(value: string): string {
  const [, month, date] = value.split('-');
  return `${Number(month)}/${Number(date)}`;
}

function longDateLabel(value: string, chineseUi: boolean): string {
  const [year, month, date] = value.split('-').map(Number);
  const parsed = new Date(year, month - 1, date);
  return new Intl.DateTimeFormat(chineseUi ? 'zh-TW' : 'en-US', {
    month: 'short',
    day: 'numeric',
    weekday: 'short',
  }).format(parsed);
}

const zhCopy = {
  activeDays: '活躍天數',
  activityTrend: '學習趨勢',
  back: '返回我的',
  bestDay: '最佳學習日',
  bestStreak: '最佳連勝',
  chineseMode: '中文單字',
  currentStreak: '目前連勝',
  dailyAverage: '活躍日平均',
  dataNote: '詳細趨勢從本版本開始累積；升級前只能保留可確認的今日總量。',
  days: (value: number) => `${value} 天`,
  difficultWords: '困難單字',
  englishMode: '英文單字',
  eyebrow: 'PERSONAL INSIGHTS',
  goalDays: '30 天達標日',
  dailyGoalLine: '每日目標線',
  goalProgress: (current: number, target: number) => current >= target ? '今日目標已完成' : `目標 ${current}/${target}`,
  learningMethods: '學習方式',
  learningMinutes: '有效學習分鐘',
  learningSessions: '學習時段',
  learningResults: '學習成果',
  mastered: '已掌握',
  masteryRate: '熟練度',
  modeMix: '模式分布',
  noAccuracy: '尚無正確率',
  notStudied: '未學習',
  personalInsight: '個人學習建議',
  quizAttempts: '測驗作答',
  recordedActions: '累積記錄',
  reviewWords: '待複習',
  selectedActions: (count: number) => `${count} 次學習行動`,
  speakingCards: '口說完成',
  speakingSkipped: (count: number) => `查看答案 ${count}`,
  streakRecord: '連勝與累積',
  studyCards: '單字卡判斷',
  subtitle: '從每天的行動看見真正的學習節奏',
  thisWeek: '本週學習次數',
  title: '你的學習分析',
  todayActions: '今日行動',
  weeklyChange: '較前一週',
  focus: {
    consistency: '本週活躍天數偏少。先把目標縮小到每天 5 個單字，比一次大量學習更容易維持。',
    momentum: '你的學習節奏穩定。維持目前頻率，並優先清掉待複習單字，可以讓熟練度持續上升。',
    quiz: '最近測驗正確率偏低。先回到複習清單加強容易混淆的單字，再重新測驗會更有效。',
    review: '待複習單字正在累積。下一次學習先使用「複習」篩選，避免舊單字被新內容蓋過。',
  },
} as const;

const enCopy = {
  activeDays: 'Active days',
  activityTrend: 'Learning trend',
  back: 'Back to profile',
  bestDay: 'Best day',
  bestStreak: 'Best streak',
  chineseMode: 'Chinese words',
  currentStreak: 'Current streak',
  dailyAverage: 'Avg. per active day',
  dataNote: 'Detailed trends start with this version. Earlier data only includes totals that can be verified.',
  days: (value: number) => `${value} days`,
  difficultWords: 'Difficult words',
  englishMode: 'English words',
  eyebrow: 'PERSONAL INSIGHTS',
  goalDays: 'Goal days in 30',
  dailyGoalLine: 'Daily goal line',
  goalProgress: (current: number, target: number) => current >= target ? 'Daily goal complete' : `Goal ${current}/${target}`,
  learningMethods: 'Learning methods',
  learningMinutes: 'Active minutes',
  learningSessions: 'Learning sessions',
  learningResults: 'Learning results',
  mastered: 'Mastered',
  masteryRate: 'Mastery rate',
  modeMix: 'Mode mix',
  noAccuracy: 'No accuracy yet',
  notStudied: 'Not studied',
  personalInsight: 'Personal recommendation',
  quizAttempts: 'Quiz answers',
  recordedActions: 'Recorded actions',
  reviewWords: 'Need review',
  selectedActions: (count: number) => `${count} learning actions`,
  speakingCards: 'Speaking completed',
  speakingSkipped: (count: number) => `${count} viewed answer`,
  streakRecord: 'Streak and totals',
  studyCards: 'Study card decisions',
  subtitle: 'See the learning rhythm behind your daily practice',
  thisWeek: 'Actions this week',
  title: 'Your learning analytics',
  todayActions: 'Today',
  weeklyChange: 'vs. prior week',
  focus: {
    consistency: 'You were active on fewer than three days this week. A smaller daily target is more sustainable than one large session.',
    momentum: 'Your learning rhythm is steady. Keep the frequency and clear review words first to continue raising mastery.',
    quiz: 'Recent quiz accuracy is low. Review confusing words first, then retry the quiz for stronger recall.',
    review: 'Review words are building up. Start your next session with the Review filter before adding more new words.',
  },
} as const;

const styles = StyleSheet.create({
  backButton: { alignItems: 'center', alignSelf: 'flex-start', borderRadius: 10, borderWidth: StyleSheet.hairlineWidth, flexDirection: 'row', gap: 5, minHeight: 40, paddingHorizontal: 12 },
  backText: { fontSize: 14, fontWeight: '600' },
  chart: { height: 128, width: '100%' },
  chartGoalDot: { borderRadius: 99, height: 6, width: 6 },
  chartGoalLegend: { alignItems: 'center', flexDirection: 'row', gap: 5, height: 16, justifyContent: 'flex-end' },
  chartGoalText: { fontSize: 9, fontWeight: '500' },
  chartLabel: { flex: 1, fontSize: 8, fontWeight: '500', height: 12, minWidth: 0, textAlign: 'center' },
  chartLabels: { flexDirection: 'row', height: 14, width: '100%' },
  dataNote: { fontSize: 11, lineHeight: 16, paddingHorizontal: 4, textAlign: 'center' },
  distributionBar: { borderRadius: 99, flexDirection: 'row', height: 8, marginTop: 10, overflow: 'hidden', width: '100%' },
  eyebrow: { fontSize: 11, fontWeight: '700' },
  flexOne: { flex: 1 },
  heroHeader: { alignItems: 'center', flexDirection: 'row', gap: 14 },
  heroIcon: { alignItems: 'center', borderRadius: 14, borderWidth: StyleSheet.hairlineWidth, height: 52, justifyContent: 'center', width: 52 },
  heroMetric: { alignItems: 'center', flex: 1, minWidth: 0 },
  heroMetricValue: { fontSize: 22, fontVariant: ['tabular-nums'], fontWeight: '800' },
  heroSurface: { alignItems: 'center', borderRadius: 16, borderWidth: StyleSheet.hairlineWidth, flexDirection: 'row', minHeight: 84, paddingHorizontal: 12, paddingVertical: 14 },
  goalBadge: { borderRadius: 8, paddingHorizontal: 9, paddingVertical: 6 },
  goalBadgeText: { fontSize: 10, fontWeight: '700' },
  insight: { alignItems: 'flex-start', borderRadius: 16, borderWidth: StyleSheet.hairlineWidth, flexDirection: 'row', gap: 12, padding: 16 },
  insightIcon: { alignItems: 'center', borderRadius: 12, height: 42, justifyContent: 'center', width: 42 },
  insightText: { fontSize: 14, lineHeight: 20, marginTop: 3 },
  insightTitle: { fontSize: 16, fontWeight: '700' },
  legendDot: { borderRadius: 99, height: 7, width: 7 },
  legendItem: { alignItems: 'center', flexDirection: 'row', gap: 5 },
  legendRow: { flexDirection: 'row', flexWrap: 'wrap', gap: 12, marginTop: 9 },
  legendText: { fontSize: 10, fontWeight: '500' },
  methodDetail: { fontSize: 12, fontWeight: '600', marginLeft: 'auto' },
  methodIcon: { alignItems: 'center', borderRadius: 9, height: 34, justifyContent: 'center', width: 34 },
  methodLabel: { fontSize: 14, fontWeight: '600' },
  methodRow: { alignItems: 'center', borderBottomWidth: StyleSheet.hairlineWidth, flexDirection: 'row', gap: 10, minHeight: 54 },
  methodValue: { fontSize: 17, fontVariant: ['tabular-nums'], fontWeight: '700', minWidth: 30, textAlign: 'right' },
  metric: { alignItems: 'center', minHeight: 66, paddingHorizontal: 5, width: '50%' },
  metricLabel: { fontSize: 11, fontWeight: '500', lineHeight: 15, marginTop: 2, textAlign: 'center' },
  metricValue: { fontSize: 22, fontVariant: ['tabular-nums'], fontWeight: '800' },
  metricsGrid: { flexDirection: 'row', flexWrap: 'wrap', rowGap: 8 },
  pressed: { opacity: 0.72, transform: [{ scale: 0.985 }] },
  section: { borderRadius: 16, borderWidth: StyleSheet.hairlineWidth, gap: 12, padding: 16 },
  sectionDivider: { height: StyleSheet.hairlineWidth, width: '100%' },
  sectionHeader: { alignItems: 'center', flexDirection: 'row', gap: 9, minHeight: 36 },
  sectionIcon: { alignItems: 'center', borderRadius: 10, height: 36, justifyContent: 'center', width: 36 },
  sectionTitle: { fontSize: 17, fontWeight: '700' },
  segment: { alignItems: 'center', borderColor: 'transparent', borderRadius: 7, borderWidth: StyleSheet.hairlineWidth, justifyContent: 'center', minHeight: 30, paddingHorizontal: 10 },
  segmented: { borderRadius: 9, flexDirection: 'row', padding: 2 },
  segmentText: { fontSize: 11, fontWeight: '600' },
  selectedDate: { fontSize: 14, fontWeight: '700' },
  selectedDetail: { fontSize: 11, fontWeight: '500', marginTop: 2 },
  selectedSummary: { alignItems: 'center', borderRadius: 10, flexDirection: 'row', justifyContent: 'space-between', minHeight: 52, paddingHorizontal: 12, paddingVertical: 8 },
  stack: { gap: 16 },
  subheading: { fontSize: 11, fontWeight: '600' },
  subtitle: { fontSize: 14, lineHeight: 20, marginTop: 5 },
  title: { fontSize: 27, fontWeight: '800', marginTop: 3 },
  verticalDivider: { height: 42, width: StyleSheet.hairlineWidth },
});
