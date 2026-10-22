import { mkdtempSync, copyFileSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

// Build the real settings/persistence code without needing an iOS simulator.
// No production behavior is translated or duplicated in the test runner.
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const swift = process.env.SWIFT_EXECUTABLE || 'swift';
const version = spawnSync(swift, ['--version'], { encoding: 'utf8' });
if (version.error || version.status !== 0) {
  throw new Error('Swift is required for the native behavior checks. Run this script on a Swift-equipped Mac or Linux host.');
}
const directory = mkdtempSync(path.join(tmpdir(), 'word7000-speaking-recency-'));
try {
  const core = JSON.stringify(path.join(root, 'ios/Packages/Word7000Core').replaceAll('\\', '/'));
  writeFileSync(path.join(directory, 'Package.swift'), `// swift-tools-version: 5.10
import PackageDescription
let package = Package(
    name: "SpeakingRecencyChecks",
    platforms: [.macOS(.v14)],
    dependencies: [.package(path: ${core})],
    targets: [.executableTarget(name: "SpeakingRecencyChecks",
        dependencies: [.product(name: "Word7000Core", package: "Word7000Core")],
        path: ".", exclude: ["Package.swift"])]
)
`);
  copyFileSync(path.join(root, 'ios/Word7000/Model/Persistence.swift'), path.join(directory, 'Persistence.swift'));
  copyFileSync(path.join(root, 'ios/Tests/SpeakingRecencyChecks.swift'), path.join(directory, 'main.swift'));
  // The only stand-ins are UI preference enums, not history or persistence.
  writeFileSync(path.join(directory, 'Preferences.swift'), `
enum AppearancePreference: String, Codable, Sendable { case system, light, dark }
enum StudyMode: String, Codable, Sendable { case english, chinese }
`);
  const result = spawnSync(swift, ['run', '--package-path', directory, 'SpeakingRecencyChecks'], { stdio: 'inherit' });
  if (result.error) throw result.error;
  if (result.status !== 0) process.exitCode = result.status || 1;
} finally {
  rmSync(directory, { recursive: true, force: true });
}
