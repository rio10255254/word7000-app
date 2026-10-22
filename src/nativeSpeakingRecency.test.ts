import fs from 'node:fs';
import { spawnSync } from 'node:child_process';
import { describe, expect, it } from 'vitest';

const read = (file: string) => fs.readFileSync(file, 'utf8');
const persistence = read('ios/Word7000/Model/Persistence.swift');
const app = read('ios/Word7000/Model/AppModel.swift');
const account = read('ios/Word7000/Account/AccountModel.swift');
const view = read('ios/Word7000/Views/SpeakingSessionView.swift');

describe('native speaking recency integration', () => {
  it('keeps old settings decodable and migrates before installing the model settings', () => {
    expect(persistence).toContain('var speakingHistoryByOwner: [String: [String]]?');
    expect(persistence).toContain('var recentSpeakingIds: [String]?');
    const init = app.slice(app.indexOf('init(coreWords:'), app.indexOf('static func launch()'));
    expect(init.indexOf('settings.migrateSpeakingHistory()')).toBeGreaterThan(-1);
    expect(init.indexOf('settings.migrateSpeakingHistory()')).toBeLessThan(init.indexOf('self.settings = settings'));
  });

  it('routes all account transitions through the settings migration and immediate save', () => {
    expect(account).not.toMatch(/app\.settings\.localOwner(?:Id|IsAnonymous)\s*=(?!=)/);
    expect(account).toContain('app.setLocalOwner(activeSession.user.id, anonymous: activeSession.user.anonymous)');
    expect(account.match(/app\.setLocalOwner\(nil, anonymous: true\)/g)).toHaveLength(2);
    expect(app).toMatch(/func setLocalOwner[\s\S]*?settings\.setLocalOwner\(ownerId, anonymous: anonymous\)\s+saveNow\(\)/);
    const setter = persistence.slice(persistence.indexOf('mutating func setLocalOwner'), persistence.indexOf('mutating func forgetSpeakingHistory'));
    expect(setter.indexOf('migrateSpeakingHistory()')).toBeLessThan(setter.indexOf('localOwnerId = ownerId'));
  });

  it('uses only the current owner history for recording and choosing questions', () => {
    expect(app).toContain('var recentSpeakingIds: [String] { settings.currentRecentSpeakingIds }');
    expect(app).toContain('settings.rememberSpeaking(wordId)');
    expect(view).toContain('recent: model.recentSpeakingIds');
    expect(app + account + view).not.toContain('settings.recentSpeakingIds');
  });

  it('clears only a successfully deleted account history', () => {
    const deletion = account.slice(account.indexOf('func deleteAccount()'));
    const clear = 'app.forgetSpeakingHistory(ownerId: current.user.id, anonymous: current.user.anonymous)';
    expect(deletion).toContain(clear);
    expect(deletion.indexOf(clear)).toBeGreaterThan(deletion.indexOf('try await client.deleteAccount'));
    expect(deletion.indexOf(clear)).toBeLessThan(deletion.indexOf('app.setLocalOwner(nil'));
    expect(account.slice(account.indexOf('func signOut()'), account.indexOf('func deleteAccount()'))).not.toContain('forgetSpeakingHistory');
  });

  it('restarts open practice on identity change and rejects stale question actions', () => {
    expect(view).toContain('.onChange(of: model.speakingHistoryOwnerKey) { _, _ in start() }');
    expect(view).toContain('historyOwnerKey = model.speakingHistoryOwnerKey');
    expect(view.match(/guard historyOwnerKey == model\.speakingHistoryOwnerKey else \{ start\(\); return \}/g)).toHaveLength(2);
  });

  it('requires executable Swift checks in native CI, without an optional skip', () => {
    const workflow = read('.github/workflows/ios-native.yml');
    expect(workflow).toMatch(/- name: Speaking history account isolation\r?\n\s+run: node scripts\/test-native-speaking-recency\.mjs/);
    expect(workflow).toContain("- 'scripts/test-native-speaking-recency.mjs'");
  });
});

const swift = spawnSync(process.env.SWIFT_EXECUTABLE || 'swift', ['--version'], { encoding: 'utf8' });
it.skipIf(swift.error != null || swift.status !== 0)('executes real Swift migration, isolation, deletion, settings retention and disk round-trip checks', () => {
  const result = spawnSync(process.execPath, ['scripts/test-native-speaking-recency.mjs'], { encoding: 'utf8', timeout: 240_000 });
  expect(result.error, result.stderr).toBeUndefined();
  expect(result.status, result.stdout + result.stderr).toBe(0);
  expect(result.stdout).toMatch(/Speaking recency: \d+ checks passed/);
}, 250_000);
