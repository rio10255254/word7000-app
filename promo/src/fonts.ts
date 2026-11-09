import '@fontsource/noto-sans-tc/500.css';
import '@fontsource/noto-sans-tc/700.css';
import '@fontsource/noto-sans-tc/900.css';
import '@fontsource/noto-serif/400.css';
import '@fontsource/noto-serif/700.css';
import '@fontsource/noto-serif/800.css';
import '@fontsource/caveat/400.css';
import '@fontsource/caveat/600.css';
import '@fontsource/noto-serif-tc/900.css';
import { continueRender, delayRender } from 'remotion';
import reels from './reels/episodes.json';

/** Chinese and UI text: the app shows Chinese in the system sans. */
export const FONT = '"Noto Sans TC", "PingFang TC", sans-serif';
/** English words and numbers: stands in for the app's serif display face (New York). */
export const SERIF = '"Noto Serif", "New York", Georgia, serif';
/** Chinese set in serif, beside SERIF: the app's name on the teaser's end card. */
export const SERIF_TC = '"Noto Serif TC", "Songti TC", serif';
/** Handwriting on a scanned word list. */
export const HAND = '"Caveat", cursive';

// Every glyph on screen, so the matching unicode-range subsets are fetched
// before the first frame is captured. Regenerate when the copy changes.
const LATIN = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789 .,:/?!'→";
const CJK = '…→↻▍、。「」・一上下不中乎亂了五什今以住你來例依係個們做備催傳像價先光入典再出別到刷刺前加動十午卡印去又友口句只叫可史合同吐吧和哪問啦喔單嗎嗯嘴回圓圖在地場壞外多夠天好子字存學完定客家寫小就差己已席帶常幫幾度庫建式引弱張影待很後得從心快怎思想意慢懂成我所手才找抓拍拼挑掃掉接描提換搭據改教敲整數文新方於日明星是時晚景暖更最會月有朋朗期本柔校根格案棒槽樂標樣機次止正歷死每毒比永沒油法活混清測準滑滿為焦然照熟片牠率玩現理用由的皮目盯直相看確示禮稍種笑笨筆答糖紀紙索經線練繪繼續習翻考而聽背能膠自與舌英著處蛤衝表被裡複要見觀角解言記設評認語誤說課談請講識議讀讓貓貼起跟較辨近這速連週進遠選還都配醒釋錄錯開間關陪集需面革音頁項題風驗麼點（），：；？';

// …and every character the IG reels show.
const REELS = JSON.stringify(reels);

const handle = delayRender('Loading fonts');
Promise.all([
  ...['500', '700', '900'].map((weight) => document.fonts.load(`${weight} 64px "Noto Sans TC"`, CJK + LATIN + REELS)),
  ...['400', '700', '800'].map((weight) => document.fonts.load(`${weight} 64px "Noto Serif"`, LATIN + 'əˈ\'')),
  ...['400', '600'].map((weight) => document.fonts.load(`${weight} 64px "Caveat"`, LATIN)),
  document.fonts.load('900 64px "Noto Serif TC"', REELS),
])
  .then(() => continueRender(handle))
  .catch((error) => {
    console.error(error);
    continueRender(handle);
  });
