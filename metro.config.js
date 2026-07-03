const { getDefaultConfig } = require('expo/metro-config');

const config = getDefaultConfig(__dirname);
const sourceExts = config.resolver.sourceExts ?? [];

config.resolver.sourceExts = sourceExts.includes('')
  ? sourceExts
  : ['', ...sourceExts];

module.exports = config;
