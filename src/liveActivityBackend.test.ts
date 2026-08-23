import fs from 'node:fs';
import path from 'node:path';
import { describe, expect, test } from 'vitest';

describe('Lock Screen learning reminder backend', () => {
  const appSource = fs.readFileSync(path.join(process.cwd(), 'App.tsx'), 'utf8');
  const edgeFunction = fs.readFileSync(
    path.join(process.cwd(), 'supabase', 'functions', 'send-streak-live-activities', 'index.ts'),
    'utf8',
  );
  const migration = fs.readFileSync(
    path.join(process.cwd(), 'supabase', 'migrations', '20260813120000_noon_live_activity.sql'),
    'utf8',
  );
  const registration = fs.readFileSync(
    path.join(process.cwd(), 'src', 'lib', 'streakReminderRegistration.ts'),
    'utf8',
  );
  const liveActivityLayout = fs.readFileSync(
    path.join(process.cwd(), 'src', 'liveActivity', 'StreakLiveActivity.tsx'),
    'utf8',
  );

  test('claims one noon reminder per local day and preserves final-hour streak reminders', () => {
    expect(migration).toContain('claim_due_noon_live_activities');
    expect(migration).toContain("clock.local_now::time >= time '12:00'");
    expect(migration).toContain("clock.local_now::time < time '13:00'");
    expect(migration).toContain('noon_activity_started_for_local_date is distinct from clock.local_now::date');
    expect(migration).toContain('pg_timezone_names');
    expect(edgeFunction).toContain("supabase.rpc('claim_due_streak_live_activities')");
    expect(edgeFunction).toContain("supabase.rpc('claim_due_noon_live_activities')");
  });

  test('personalizes noon copy from the latest daily progress registration', () => {
    expect(registration).toContain('daily_target: Math.max(1, Math.round(registration.dailyTarget))');
    expect(registration).toContain('studied_today: Math.max(0, Math.round(registration.studiedToday))');
    expect(registration).toContain('progress_date: registration.progressDate');
    expect(appSource).toContain('dailyTarget: progress.dailyTarget');
    expect(appSource).toContain('studiedToday: progress.studiedToday');
    expect(edgeFunction).toContain("title: chinese ? '中午學習時間' : 'Your noon study break'");
    expect(edgeFunction).toContain('noon_activity_expires_at');
    expect(edgeFunction).toContain("activityKind: 'noon'");
    expect(edgeFunction).toContain('progressCurrent: studiedToday');
    expect(edgeFunction).toContain('progressTarget: Math.max(1, device.daily_target)');
  });

  test('provides distinct glanceable layouts for every Dynamic Island presentation', () => {
    expect(liveActivityLayout).toContain("props.activityKind === 'noon'");
    expect(liveActivityLayout).toContain('bannerSmall:');
    expect(liveActivityLayout).toContain('compactLeading:');
    expect(liveActivityLayout).toContain('compactTrailing,');
    expect(liveActivityLayout).toContain('minimal: isNoon');
    expect(liveActivityLayout).toContain('expandedCenter:');
    expect(liveActivityLayout).toContain('expandedBottom:');
    expect(liveActivityLayout).toContain("contentTransition('numericText')");
    expect(liveActivityLayout).toContain('activityBackgroundTint(activityBackground)');
  });
});
