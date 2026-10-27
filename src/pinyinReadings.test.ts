import fs from 'node:fs';
import path from 'node:path';
import OpenCC from 'opencc-js';
import { pinyin } from 'pinyin-pro';
import { describe, expect, it } from 'vitest';
// @ts-expect-error The generator is a plain ES module script.
import { makeReader, textsToRead } from '../scripts/build-pinyin-readings.mjs';

const root = path.resolve(__dirname, '..');
const read = makeReader({ pinyin, toSimplified: OpenCC.Converter({ from: 't', to: 'cn' }) });

describe('pinyin readings for Learn Chinese mode', () => {
  it('reads Traditional characters as whole words, the Taiwan way', () => {
    expect(read('長大')).toBe('zhǎng dà');
    expect(read('銀行')).toBe('yín háng');
    expect(read('還是')).toBe('hái shì');
    expect(read('乾淨')).toBe('gān jìng');
    expect(read('垃圾')).toBe('lè sè');
    expect(read('星期')).toBe('xīng qí');
  });

  it('turns Chinese punctuation into Latin and keeps other text', () => {
    expect(read('台北101是「地標」，對吧？')).toBe('tái běi 101 shì “dì biāo”, duì ba?');
  });

  it('matches the bundled file for every text the app shows', () => {
    const words = JSON.parse(fs.readFileSync(path.join(root, 'ios/Word7000/Resources/words.json'), 'utf8'));
    const resources = path.join(root, 'ios/Packages/Word7000Core/Sources/Word7000Core/Resources');
    const speaking = JSON.parse(fs.readFileSync(path.join(resources, 'speaking-prompts.json'), 'utf8'));
    const { readings } = JSON.parse(fs.readFileSync(path.join(resources, 'pinyin-readings.json'), 'utf8'));
    const texts: string[] = textsToRead(words, speaking);
    expect(Object.keys(readings).sort()).toEqual(texts);
    const stale = texts.filter((text) => readings[text] !== read(text));
    expect(stale.slice(0, 5)).toEqual([]);
  }, 60_000);
});
