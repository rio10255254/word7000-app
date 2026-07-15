const { getDefaultConfig } = require('expo/metro-config');

const config = getDefaultConfig(__dirname);
const sourceExts = config.resolver.sourceExts ?? [];

config.resolver.sourceExts = sourceExts.includes('')
  ? sourceExts
  : ['', ...sourceExts];

config.transformer.getTransformOptions = async () => ({
  transform: {
    experimentalImportSupport: false,
    inlineRequires: true,
  },
});

module.exports = config;
