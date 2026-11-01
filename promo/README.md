# Word7000 宣傳短片

用 [Remotion](https://www.remotion.dev/) 寫成的直式（1080×1920、9:16）宣傳片，目前是 10 秒試作版。

## 使用方式

```bash
cd promo
npm install
npm run studio   # 在瀏覽器即時預覽、拖時間軸
npm run render   # 輸出 out/word7000-teaser.mp4
```

在雲端容器或沒有下載 Chrome 的環境，可改用現有的 Chromium：

```bash
npx remotion render Teaser out/word7000-teaser.mp4 --browser-executable=/opt/pw-browsers/chromium
```

## 結構

- `src/Teaser.tsx`：所有場景。上方的 `SCENES` 控制每一幕的起點與長度（30 fps）。
- `src/collage.tsx`：App「紙張拼貼」風格的素材，從 `ios/Word7000/Design/Collage.swift`（`claude/friendly-darwin-obc3r1` 分支）移植而來，包括方格紙、橫線索引卡（含紅色邊線）、紙膠帶、撕邊、網點、炭筆線圈和橡皮章。這個風格沒有陰影，靠紙張彼此重疊做出層次。
- `src/Mascot.tsx`：吉祥物「小字團」，從 `Mascot.swift` 逐個形狀移植成 SVG。有 idle、smug、happy、annoyed 四種表情，也會呼吸、眨眼、甩尾巴。
- `src/fonts.ts`：中文用 Noto Sans TC，英文單字用 Noto Serif（代替 App 裡的 New York 襯線字）。文案有改時要更新裡面的字表。
- `public/icon-collage.png`：拼貼風格的 App icon。`public/icon.png` 是皮革風格的 icon，`public/paper-grain.png` 是紙張紋理。

尺寸換算是「App 的 pt × 1080/402」，也就是把 402pt 寬的 iPhone 放大到 1080px。小字團的台詞都是 App 裡實際會出現的句子。

## 分鏡（10 秒）

| 時間 | 畫面 |
| --- | --- |
| 0.0–2.0s | 「又在滑手機？」標題下畫出炭筆線，橫線紙片啪一聲貼上：「你滑手機的時間夠背十個字了。」小字團擺臭臉冒出來 |
| 2.0–3.2s | 方格紙背景，撕邊的蜜桃色紙片貼上，小字團開心跳起來：「認識一下，小字團。」接著蓋上「毒舌陪讀」印章 |
| 3.2–5.2s | 貼著膠帶的橫線索引卡（下面墊方格紙）：attend 看答案 → 翻面 → 點「認識」，小字團：「好喔，記住了。永遠。」 |
| 5.2–7.0s | 題目寫在撕邊方格紙上，選項是紙條：選錯「說法」，小字團：「蛤？你是來亂的嗎？」 |
| 7.0–8.6s | 拼貼版主卡（撕邊皮革、膠帶、網點），進度環 7／20，加上兩張練習方塊。小字團：「才 7 個？笑死。還差 13 個。」 |
| 8.6–10.0s | 拼貼版 icon 用膠帶貼上，出現 Word7000，最後蓋上「7000 單字」印章 |

## 授權

Remotion 對個人與 3 人以下公司免費，規模更大需購買 Company License。
