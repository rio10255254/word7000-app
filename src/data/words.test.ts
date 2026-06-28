import { describe, expect, test } from 'vitest';
import { sampleWords } from './words';

describe('full vocabulary dataset', () => {
  test('contains exactly 7000 app-ready words', () => {
    expect(sampleWords).toHaveLength(7000);
  });

  test('is split into 14 complete 500-word levels', () => {
    const groupCounts = sampleWords.reduce<Record<string, number>>((counts, word) => {
      counts[word.group] = (counts[word.group] ?? 0) + 1;
      return counts;
    }, {});

    expect(Object.keys(groupCounts)).toHaveLength(14);
    for (let level = 1; level <= 14; level += 1) {
      expect(groupCounts[`Core ${level}`]).toBe(500);
    }
  });

  test('uses unique ids and unique lowercase words', () => {
    const ids = new Set(sampleWords.map((word) => word.id));
    const words = new Set(sampleWords.map((word) => word.word.toLowerCase()));

    expect(ids.size).toBe(sampleWords.length);
    expect(words.size).toBe(sampleWords.length);
  });

  test('has complete fields for every word', () => {
    const incomplete = sampleWords.filter(
      (word) =>
        !word.id.trim() ||
        !word.word.trim() ||
        !word.partOfSpeech.trim() ||
        !word.pronunciation.trim() ||
        !word.meaningZh.trim() ||
        !word.example.trim() ||
        !word.exampleZh.trim() ||
        !word.group.trim(),
    );

    expect(incomplete).toEqual([]);
  });

  test('uses sentence examples instead of dictionary placeholder text', () => {
    const placeholderExamples = sampleWords.filter(
      (word) =>
        word.example.startsWith(`Review "${word.word}" with this meaning:`) ||
        word.exampleZh === `「${word.word}」：${word.meaningZh}`,
    );

    expect(placeholderExamples.slice(0, 20).map((word) => word.word)).toEqual([]);
  });

  test('uses contextual examples instead of meta-learning templates', () => {
    const metaPatterns = [
      /\bthe word\b/i,
      /\bsimple (sentence|example)\b/i,
      /\blearner/i,
      /\bcan show how\b/i,
      /\bpractical context\b/i,
      /\bmeaning clearer\b/i,
      /\bcomplete sentence\b/i,
      /\blong definition\b/i,
      /\bfamiliar idea\b/i,
    ];
    const metaExamples = sampleWords.filter((word) =>
      metaPatterns.some((pattern) => pattern.test(`${word.example} ${word.exampleZh}`)),
    );

    expect(metaExamples.slice(0, 20).map((word) => word.word)).toEqual([]);
  });

  test('keeps generated example frames varied across the full dataset', () => {
    const frameCounts = new Map<string, number>();

    for (const word of sampleWords) {
      const frame = word.example.toLowerCase().replaceAll(word.word.toLowerCase(), '{word}');
      frameCounts.set(frame, (frameCounts.get(frame) ?? 0) + 1);
    }

    const repeatedFrames = Array.from(frameCounts.entries())
      .filter(([, count]) => count > 35)
      .sort((a, b) => b[1] - a[1]);

    expect(repeatedFrames.slice(0, 10)).toEqual([]);
  });

  test('does not keep awkward generated scaffolding in examples or translations', () => {
    const awkwardPatterns = [
      /A note about [a-z]+ helped/i,
      /The report mentioned [a-z]+ before/i,
      /became important after/i,
      /pointed [a-z]+ the main entrance/i,
      /with a clear [a-z]+ during/i,
      /關於.+的筆記/,
      /標誌指向與.+相關/,
      /幫助處理/,
      /用清楚的.+於/,
    ];
    const awkwardExamples = sampleWords.filter((word) =>
      awkwardPatterns.some((pattern) => pattern.test(`${word.example} ${word.exampleZh}`)),
    );

    expect(awkwardExamples.slice(0, 20).map((word) => `${word.word}: ${word.example} / ${word.exampleZh}`)).toEqual([]);
  });

  test('does not keep high-risk generic examples that often produce unreasonable meanings', () => {
    const highRiskPatterns = [
      /\bexplained the [a-z]+ after the (meeting|lesson|interview|workshop|trip|review|practice|discussion|training|visit|trial|festival|inspection|presentation|debate|rehearsal)\b/i,
      /\btreated the [a-z]+ as important\b/i,
      /\bwas easy to find in the\b/i,
      /\bnoticed an? [a-z]+ detail in the\b/i,
      /\bhelped us [a-z]+ the next step\b/i,
      /\bPlease [a-z]+ the (plan|report|schedule|project|message|lesson|file|room|budget|map|letter|ticket|device|garden|contract|display) carefully\b/i,
      /在.+後說明了/,
      /視為重要/,
      /裡很容易找到/,
      /幫助我們.+下一步/,
    ];
    const highRiskExamples = sampleWords.filter((word) =>
      highRiskPatterns.some((pattern) => pattern.test(`${word.example} ${word.exampleZh}`)),
    );

    expect(highRiskExamples.slice(0, 40).map((word) => `${word.word}: ${word.example} / ${word.exampleZh}`)).toEqual([]);
  });

  test('uses polished examples for words that exposed machine-generated phrasing', () => {
    const expectedExamples = new Map([
      ['first', ['First, read the question carefully.', '首先，仔細閱讀題目。']],
      ['share', ['She owns a small share of the company.', '她擁有那家公司的一小部分股份。']],
      ['install', ['Please install the app before class.', '請在上課前安裝這個應用程式。']],
      ['homeless', ['The city opened a shelter for homeless families.', '市政府為無家可歸的家庭開設了收容中心。']],
      ['homework', ['I finished my homework before dinner.', '我在晚餐前完成了作業。']],
      ['hometown', ['He visits his hometown every summer.', '他每年夏天都會回故鄉。']],
      ['suit', ['This dark suit is for formal meetings.', '這套深色西裝適合正式會議。']],
      ['object', ['A small object was lying under the chair.', '椅子下方有一個小物品。']],
      ['whereas', ['I like tea, whereas my sister prefers coffee.', '我喜歡茶，而我妹妹比較喜歡咖啡。']],
      ['albeit', ['The room was small, albeit comfortable.', '房間雖小，但很舒適。']],
      ['thereby', ['The new rule saved time, thereby reducing stress.', '新規則節省了時間，因此減少了壓力。']],
      ['whereby', ['They created a system whereby students can ask questions online.', '他們建立了一套系統，讓學生可以在線上提問。']],
      ['provided', ['You can join the trip provided you sign up today.', '只要你今天報名，就可以參加這趟旅行。']],
      ['ourselves', ['We made the cake ourselves.', '我們自己做了這個蛋糕。']],
      ['beneath', ['The cat slept beneath the table.', '貓睡在桌子底下。']],
      ['sideways', ['The sign was hanging sideways after the storm.', '暴風雨後，那個招牌歪向一邊掛著。']],
      ['option', ['The cheapest option is not always the best.', '最便宜的選項不一定總是最好的。']],
      ['quiz', ['The quiz has ten short questions.', '這份小考有十題簡短的題目。']],
      ['operation', ['The operation of the machine is simple.', '這台機器的操作很簡單。']],
      ['compound', ['Water is not a compound of oxygen alone.', '水不是只由氧組成的化合物。']],
      ['proportion', ['A large proportion of students chose English.', '很大比例的學生選擇了英文。']],
      ['optional', ['The final question is optional.', '最後一題是選答題。']],
      ['crow', ['The child watched the crow from the fence.', '孩子從圍欄旁看著那隻烏鴉。']],
    ]);

    for (const [word, [example, exampleZh]] of expectedExamples) {
      const entry = sampleWords.find((item) => item.word === word);
      expect(entry?.example).toBe(example);
      expect(entry?.exampleZh).toBe(exampleZh);
    }
  });

  test('uses each word directly inside its English example', () => {
    const missingWordExamples = sampleWords.filter((word) => {
      const pattern = new RegExp(`(^|[^a-z])${word.word.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}([^a-z]|$)`, 'i');
      return !pattern.test(word.example);
    });

    expect(missingWordExamples.slice(0, 20).map((word) => word.word)).toEqual([]);
  });

  test('keeps examples free of obvious grammar artifacts', () => {
    const grammarArtifacts = sampleWords.filter(
      (word) =>
        /^[a-z]/.test(word.example) ||
        /\b[Aa] [aeiou]/.test(word.example) ||
        /\b[Aa]n [^aeiou\s]/.test(word.example) ||
        /的的/.test(word.exampleZh),
    );

    expect(grammarArtifacts.slice(0, 20).map((word) => `${word.word}: ${word.example} / ${word.exampleZh}`)).toEqual([]);
  });

  test('keeps English example sentences in English', () => {
    const mixedLanguageExamples = sampleWords.filter((word) => /[\u4e00-\u9fff]/.test(word.example));

    expect(mixedLanguageExamples.slice(0, 20).map((word) => word.word)).toEqual([]);
  });

  test('contains single-word English entries only', () => {
    const invalid = sampleWords.filter((word) => !/^[a-z]{2,18}$/.test(word.word));

    expect(invalid).toEqual([]);
  });

  test('keeps common words free of dictionary-domain noise', () => {
    const commonWords = sampleWords.filter((word) => ['be', 'for', 'it'].includes(word.word));
    const noisyPattern = /DOS|信息論|輸入終端|後端|總線|批處理/;

    expect(commonWords.map((word) => `${word.word}: ${word.meaningZh}`)).not.toEqual(
      expect.arrayContaining([expect.stringMatching(noisyPattern)]),
    );
  });

  test('keeps the first learning words stable for the home and study flow', () => {
    expect(sampleWords.slice(0, 5).map((word) => word.word)).toEqual([
      'adapt',
      'brief',
      'contrast',
      'expand',
      'precise',
    ]);
  });
});
