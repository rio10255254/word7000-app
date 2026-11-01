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
- `src/Mascot.tsx`：吉祥物「小字團」。從 `ios/Word7000/Design/Mascot.swift`（`claude/friendly-darwin-obc3r1` 分支）逐個形狀移植成 SVG，有 idle、smug、happy、annoyed 四種表情，也會呼吸、眨眼、甩尾巴。
- `src/fonts.ts`：中文用 Noto Sans TC，英文單字用 Noto Serif（代替 App 裡的 New York 襯線字），在第一格之前先等字型下載完成。文案有改時要更新裡面的字表。
- `public/icon.png`、`public/paper-grain.png`：測試版的 App icon 與紙張紋理。

配色取自測試版 `Theme.swift` 的 WarmTone（紙色 `#F3EEE4`、赤陶 `#C96442`、鼠尾草綠 `#6E8F5E` 等），小字團的台詞也都是 App 裡實際會出現的句子。

## 分鏡（10 秒）

| 時間 | 畫面 |
| --- | --- |
| 0.0–2.0s | 「又在滑手機？」小字團擺臭臉冒出來：「你滑手機的時間夠背十個字了。」 |
| 2.0–3.1s | 赤陶色背景，小字團開心跳起來：「認識一下，小字團。」 |
| 3.1–5.1s | 單字卡 attend：看答案 → 翻面（出席、例句）→ 點「認識」，小字團：「好喔，記住了。永遠。」 |
| 5.1–7.0s | 測驗 which：點錯「說法」，正解「哪一個」，小字團：「蛤？你是來亂的嗎？」 |
| 7.0–8.6s | 今天的單字進度環 7／20，小字團：「才 7 個？笑死。還差 13 個。」 |
| 8.6–10.0s | 片尾：App icon、Word7000、「和小字團一起背 7000 單字。」 |

## 授權

Remotion 對個人與 3 人以下公司免費，規模更大需購買 Company License。
