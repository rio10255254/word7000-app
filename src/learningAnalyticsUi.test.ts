import fs from 'node:fs';
import path from 'node:path';
import { describe, expect, test } from 'vitest';

describe('personal learning analytics experience', () => {
  const appSource = fs.readFileSync(path.join(process.cwd(), 'App.tsx'), 'utf8');
  const analyticsSource = fs.readFileSync(
    path.join(process.cwd(), 'src', 'components', 'PersonalAnalyticsView.tsx'),
    'utf8',
  );
  const routeSource = fs.readFileSync(path.join(process.cwd(), 'src', 'app', 'stats.tsx'), 'utf8');
  const rootLayout = fs.readFileSync(path.join(process.cwd(), 'src', 'app', '_layout.tsx'), 'utf8');
  const progressSource = fs.readFileSync(path.join(process.cwd(), 'src', 'lib', 'progress.ts'), 'utf8');

  test('records study, quiz, speaking, language mode, and device source data', () => {
    expect(appSource).toContain("'studyKnown'");
    expect(appSource).toContain("'studyReview'");
    expect(appSource).toContain("'quizCorrect' : 'quizWrong'");
    expect(appSource).toContain("'speakingCompleted'");
    expect(appSource).toContain('sourceId: streakDeviceId');
    expect(appSource).toContain('recordLearningDuration');
    expect(appSource).toContain('answeredQuizKeyRef.current === eventKey');
    expect(appSource).toContain('speakingRecordedKeyRef.current !== eventKey');
    expect(progressSource).toContain('mergeLearningAnalyticsStates');
  });

  test('adds a dedicated analytics route from the profile page', () => {
    expect(appSource).toContain('testID="profile-learning-analytics"');
    expect(appSource).toContain("router.push('/stats')");
    expect(rootLayout).toContain('<Stack.Screen name="stats" />');
    expect(routeSource).toContain('<PersonalAnalyticsView');
  });

  test('places learning analytics after the complete account section', () => {
    const profileStart = appSource.indexOf('const ProfileView = memo(function ProfileView({');
    const profileEnd = appSource.indexOf('function ProfileTutorialPanel(', profileStart);
    const profileSource = appSource.slice(profileStart, profileEnd);
    const accountStart = profileSource.indexOf('<View style={[styles.accountCard');
    const analyticsEntry = profileSource.indexOf('testID="profile-learning-analytics"');
    const learningExperience = profileSource.indexOf('<ProfileLearningExperiencePanel');

    expect(accountStart).toBeGreaterThan(-1);
    expect(analyticsEntry).toBeGreaterThan(accountStart);
    expect(learningExperience).toBeGreaterThan(analyticsEntry);
  });

  test('provides an interactive seven and thirty day chart with scrub details', () => {
    expect(analyticsSource).toContain('<GestureDetector gesture={scrubGesture}>');
    expect(analyticsSource).toContain('Gesture.Pan()');
    expect(analyticsSource).toContain('Gesture.Tap()');
    expect(analyticsSource).toContain('runOnJS(selectIndex)(index)');
    expect(analyticsSource).toContain('<SvgPath');
    expect(analyticsSource).toContain('chartGeometry.linePath');
    expect(analyticsSource).toContain('strokeDasharray="4 4"');
    expect(analyticsSource).toContain('selectedPoint.x');
    expect(analyticsSource).toContain('selectedSummary');
    expect(analyticsSource).toContain('period === 7 ? analytics.chart7 : analytics.chart30');
    expect(analyticsSource).toContain('copy.goalProgress');
  });

  test('shows outcomes, methods, streaks, and personalized recommendations in both languages', () => {
    expect(analyticsSource).toContain('learningResults');
    expect(analyticsSource).toContain('learningMethods');
    expect(analyticsSource).toContain('streakRecord');
    expect(analyticsSource).toContain('copy.focus[analytics.focus]');
    expect(analyticsSource).toContain('你的學習分析');
    expect(analyticsSource).toContain('Your learning analytics');
  });
});
