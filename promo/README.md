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
- `src/fonts.ts`：載入 Noto Sans TC，並在第一格之前等字型下載完成。
- `public/icon.png`：App icon（從 `../assets/icon.png` 複製）。

## 分鏡（10 秒）

| 時間 | 畫面 |
| --- | --- |
| 0.0–1.8s | 數字滾到 7000「個單字。背了又忘？」 |
| 1.8–3.0s | 「這次，不一樣。」+ App icon 彈出 |
| 3.0–5.2s | 單字卡 attend：中文意思、例句與螢光筆標記 |
| 5.2–7.2s | 測驗：點選「出席」答對變綠 |
| 7.2–8.4s | 「會念，才算會。」聲波 + 麥克風 |
| 8.4–10.0s | 片尾：icon、Word7000、slogan |

## 授權

Remotion 對個人與 3 人以下公司免費，規模更大需購買 Company License。
