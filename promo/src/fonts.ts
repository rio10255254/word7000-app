import '@fontsource/noto-sans-tc/500.css';
import '@fontsource/noto-sans-tc/700.css';
import '@fontsource/noto-sans-tc/900.css';
import { continueRender, delayRender } from 'remotion';

export const FONT = '"Noto Sans TC", "PingFang TC", sans-serif';

// Every glyph that appears on screen, so the matching unicode-range
// subsets are fetched before the first frame is captured.
const GLYPHS =
  '0123456789 7000個單字。背了又忘？這次，不一樣每都有例句考一下就記住會念才算答對！高中天點口說練習發音出席濃郁的抱怨允許是什麼意思我幾乎所有同學週五晚上學校音樂Word attend v. Nearly all my classmates will the school concert on Friday evening';

const handle = delayRender('Loading Noto Sans TC');
Promise.all(
  ['500', '700', '900'].map((weight) => document.fonts.load(`${weight} 64px "Noto Sans TC"`, GLYPHS)),
)
  .then(() => continueRender(handle))
  .catch((error) => {
    console.error(error);
    continueRender(handle);
  });
