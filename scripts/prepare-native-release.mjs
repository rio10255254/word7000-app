import fs from 'node:fs';
import path from 'node:path';
import xcode from 'xcode';

const [stageDirectory, buildNumber] = process.argv.slice(2);
if (!stageDirectory || !/^[1-9]\d*$/.test(buildNumber ?? '')) {
  throw new Error('Usage: prepare-native-release.mjs <staged project> <next build number>');
}

const projectPath = path.join(stageDirectory, 'ios/Word7000.xcodeproj/project.pbxproj');
const project = xcode.project(projectPath);
project.parseSync();

const identifiers = new Set(['com.rio.word7000', 'com.rio.word7000.ExpoWidgetsTarget']);
let updatedConfigurations = 0;
for (const configuration of Object.values(project.pbxXCBuildConfigurationSection())) {
  const settings = configuration?.buildSettings;
  if (settings && identifiers.has(settings.PRODUCT_BUNDLE_IDENTIFIER)) {
    settings.CURRENT_PROJECT_VERSION = buildNumber;
    updatedConfigurations += 1;
  }
}
if (updatedConfigurations !== 4) {
  throw new Error(`Expected four app/widget signing configurations; found ${updatedConfigurations}`);
}
fs.writeFileSync(projectPath, project.writeSync());

const configPath = path.join(stageDirectory, 'app.json');
const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
config.expo.ios.buildNumber = buildNumber;
fs.writeFileSync(configPath, `${JSON.stringify(config, null, 2)}\n`);
console.log(`Staged app and widget for native build ${buildNumber}.`);
