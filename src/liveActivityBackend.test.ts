import fs from 'node:fs';
import path from 'node:path';
import { describe, expect, test } from 'vitest';

describe('Lock Screen learning reminder backend', () => {
  const edgeFunction = fs.readFileSync(
    path.join(process.cwd(), 'supabase', 'functions', 'send-streak-live-activities', 'index.ts'),
    'utf8',
  );
  const migration = fs.readFileSync(
    path.join(process.cwd(), 'supabase', 'migrations', '20260813120000_noon_live_activity.sql'),
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
    expect(edgeFunction).toContain(`title: chinese ? '單字不會自己背好喔' : "Those words won't learn themselves"`);
    expect(edgeFunction).toContain('noon_activity_expires_at');
    expect(edgeFunction).toContain("activityKind: 'noon'");
    expect(edgeFunction).toContain('progressCurrent: studiedToday');
    expect(edgeFunction).toContain('progressTarget: Math.max(1, device.daily_target)');
  });
});
