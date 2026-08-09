import fs from 'node:fs';
import path from 'node:path';
import zlib from 'node:zlib';

const root = process.cwd();
const bundleDirectory = path.join(root, 'dist', '_expo', 'static', 'js', 'web');
const appPath = path.join(root, 'App.tsx');

if (!fs.existsSync(bundleDirectory)) {
  fail('Web export is missing. Run npm run build:web first.');
}

const bundleFiles = fs.readdirSync(bundleDirectory).filter((file) => file.endsWith('.js'));
const entry = findBundle(bundleFiles, 'entry-');
const routeShell = findBundle(bundleFiles, 'index-');
const vocabulary = findBundle(bundleFiles, 'words-');
const measurements = [entry, routeShell, vocabulary].map(measureBundle);

const budgets = {
  entry: { gzip: 1_020_000, raw: 5_100_000 },
  index: { gzip: 12_000, raw: 40_000 },
  words: { gzip: 750_000, raw: 2_850_000 },
  totalGzip: 1_780_000,
};

checkBundle(measurements[0], budgets.entry);
checkBundle(measurements[1], budgets.index);
checkBundle(measurements[2], budgets.words);

const totalGzip = measurements.reduce((total, bundle) => total + bundle.gzip, 0);
if (totalGzip > budgets.totalGzip) {
  fail(`Total compressed JavaScript is ${formatBytes(totalGzip)}; budget is ${formatBytes(budgets.totalGzip)}.`);
}

const appSource = fs.readFileSync(appPath, 'utf8');
const requiredArchitecture = [
  'const HomeView = memo(function HomeView',
  'const StudyView = memo(function StudyView',
  'const QuizView = memo(function QuizView',
  'const LibraryView = memo(function LibraryView',
  'const ProfileView = memo(function ProfileView',
  'UserMemorySyncQueue',
  'Gesture.Pan()',
  "router.push({ pathname: '/library/[wordId]'",
  "router.push('/settings')",
  "router.push('/sets')",
];

for (const snippet of requiredArchitecture) {
  if (!appSource.includes(snippet)) {
    fail(`Required performance boundary is missing: ${snippet}`);
  }
}

const forbiddenArchitecture = [
  'PanResponder',
  'studySwipeScrollLocked',
  'renderedLibraryPanel',
  'selectedLibraryWord',
];

for (const snippet of forbiddenArchitecture) {
  if (appSource.includes(snippet)) {
    fail(`Retired performance path returned: ${snippet}`);
  }
}

for (const bundle of measurements) {
  console.log(`${bundle.label}: ${formatBytes(bundle.raw)} raw, ${formatBytes(bundle.gzip)} compressed`);
}
console.log(`Total compressed JavaScript: ${formatBytes(totalGzip)}`);
console.log('Performance architecture and bundle budgets passed.');

function findBundle(files, prefix) {
  const file = files.find((candidate) => candidate.startsWith(prefix));
  if (!file) {
    fail(`Expected ${prefix} web bundle was not generated.`);
  }
  return file;
}

function measureBundle(file) {
  const contents = fs.readFileSync(path.join(bundleDirectory, file));
  return {
    file,
    gzip: zlib.gzipSync(contents, { level: 9 }).length,
    label: file.split('-')[0],
    raw: contents.length,
  };
}

function checkBundle(bundle, budget) {
  if (bundle.raw > budget.raw) {
    fail(`${bundle.label} bundle is ${formatBytes(bundle.raw)}; raw budget is ${formatBytes(budget.raw)}.`);
  }
  if (bundle.gzip > budget.gzip) {
    fail(`${bundle.label} bundle is ${formatBytes(bundle.gzip)} compressed; budget is ${formatBytes(budget.gzip)}.`);
  }
}

function formatBytes(bytes) {
  return `${(bytes / 1024).toFixed(1)} KB`;
}

function fail(message) {
  console.error(`Performance check failed: ${message}`);
  process.exit(1);
}
