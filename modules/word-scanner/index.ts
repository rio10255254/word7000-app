import { requireOptionalNativeModule } from 'expo';
import type { ScannedLine } from '../../src/lib/scanParser';

type WordScannerNativeModule = {
  recognizeTextAsync(uri: string, languages: string[]): Promise<Array<ScannedLine & { confidence: number }>>;
};

// Optional on purpose: the module only exists in iOS builds made after it was
// added. Web, Android and older TestFlight builds report "unavailable" instead
// of crashing on import.
const nativeModule = requireOptionalNativeModule<WordScannerNativeModule>('WordScanner');

export const SCAN_LANGUAGES = ['zh-Hant', 'en-US'];

export function isWordScannerAvailable(): boolean {
  return Boolean(nativeModule);
}

export async function recognizeTextInImage(uri: string): Promise<ScannedLine[]> {
  if (!nativeModule) {
    throw new Error('word-scanner-unavailable');
  }
  const lines = await nativeModule.recognizeTextAsync(uri, SCAN_LANGUAGES);
  return lines.map(({ height, text, width, x, y }) => ({ height, text, width, x, y }));
}
