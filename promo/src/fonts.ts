import '@fontsource/noto-sans-tc/500.css';
import '@fontsource/noto-sans-tc/700.css';
import '@fontsource/noto-sans-tc/900.css';
import '@fontsource/noto-serif/400.css';
import '@fontsource/noto-serif/800.css';
import { continueRender, delayRender } from 'remotion';

/** Chinese and UI text: the app shows Chinese in the system sans. */
export const FONT = '"Noto Sans TC", "PingFang TC", sans-serif';
/** English words and numbers: stands in for the app's serif display face (New York). */
export const SERIF = '"Noto Serif", "New York", Georgia, serif';

// Every glyph on screen, so the matching unicode-range subsets are fetched
// before the first frame is captured. Regenerate when the copy changes.
const LATIN = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789 .,/?!→';
const CJK = '→。・一上下不中乎亂了五今住你來例個備價出前十卡又句同吐和哪喔單嗎團在夠天好字學小差席幾度張待我所手才文新是時晚景會有校格案槽樂機死每永法準滑熟牠的盯看笑答繼續習背著蛤被複記認說識起週進遠還都錯間音點，？';

const handle = delayRender('Loading fonts');
Promise.all([
  ...['500', '700', '900'].map((weight) => document.fonts.load(`${weight} 64px "Noto Sans TC"`, CJK + LATIN)),
  ...['400', '800'].map((weight) => document.fonts.load(`${weight} 64px "Noto Serif"`, LATIN + 'əˈ')),
])
  .then(() => continueRender(handle))
  .catch((error) => {
    console.error(error);
    continueRender(handle);
  });
