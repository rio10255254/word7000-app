import fs from 'node:fs';
import path from 'node:path';
import { describe, expect, test } from 'vitest';
import app from '../app.json';

const manifestPath = path.join(process.cwd(), 'public', 'manifest.json');
const serviceWorkerPath = path.join(process.cwd(), 'public', 'service-worker.js');
const headersPath = path.join(process.cwd(), 'public', '_headers');
const appPath = path.join(process.cwd(), 'App.tsx');
const prepareExportPath = path.join(process.cwd(), 'scripts', 'prepare-web-export.mjs');

describe('free web launch configuration', () => {
  test('keeps web-facing app identity ready for static hosting', () => {
    expect(app.expo.name).toBe('Word7000');
    expect(app.expo.description).toContain('7000-word');
    expect(app.expo.web?.favicon).toBe('./assets/favicon.png');
  });

  test('provides a web app manifest for add-to-home-screen usage', () => {
    const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));

    expect(manifest.name).toBe('Word7000');
    expect(manifest.short_name).toBe('Word7000');
    expect(manifest.display).toBe('standalone');
    expect(manifest.start_url).toBe('/');
    expect(manifest.icons.length).toBeGreaterThanOrEqual(2);
    for (const icon of manifest.icons) {
      expect(fs.existsSync(path.join(process.cwd(), 'public', icon.src.replace(/^\//, '')))).toBe(true);
    }
  });

  test('provides offline cache support for the web app shell', () => {
    const serviceWorker = fs.readFileSync(serviceWorkerPath, 'utf8');
    const headers = fs.readFileSync(headersPath, 'utf8');
    const appSource = fs.readFileSync(appPath, 'utf8');
    const prepareExport = fs.readFileSync(prepareExportPath, 'utf8');

    expect(serviceWorker).toContain('word7000-static');
    expect(serviceWorker).toContain("self.addEventListener('fetch'");
    expect(serviceWorker).toContain('self.skipWaiting');
    expect(serviceWorker).toContain('self.clients.claim');
    expect(serviceWorker).toContain("request.mode === 'navigate'");
    expect(headers).toContain('/service-worker.js');
    expect(headers).toContain('Cache-Control: no-cache');
    expect(appSource).toContain('/service-worker.js');
    expect(prepareExport).toContain('rel="manifest"');
  });
});
