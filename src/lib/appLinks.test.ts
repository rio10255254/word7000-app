import { describe, expect, test } from 'vitest';
import { appInfoLinks, buildHostedAppUrl } from './appLinks';

describe('App information links', () => {
  test('builds hosted policy and support pages from the public web origin', () => {
    expect(buildHostedAppUrl('/privacy.html')).toBe('https://word7000-app.rio10255254.workers.dev/privacy.html');
    expect(buildHostedAppUrl('support.html')).toBe('https://word7000-app.rio10255254.workers.dev/support.html');
  });

  test('exposes App Store-ready privacy and support links', () => {
    expect(appInfoLinks.privacy).toContain('/privacy.html');
    expect(appInfoLinks.support).toContain('/support.html');
  });
});
