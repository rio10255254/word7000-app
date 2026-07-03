import AsyncStorage from '@react-native-async-storage/async-storage';
import { createCachedAppStorage } from './appStorageCore';

const nativeStorage = createCachedAppStorage(AsyncStorage);

export function getNativeAppStorage() {
  return nativeStorage;
}
