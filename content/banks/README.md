# 官方字庫

每個字庫一個檔案：`content/banks/<代號>.json`，代號只能用小寫英文、數字和 `-`（例：`medical`、`toeic-business`）。
格式照 `_example.json`（底線開頭的檔案不會被上架）。

- `mode`：`english`（學英文）或 `chinese`（學中文）
- `premium`：`true` 就只有 Premium 訂閱者能學
- `sort`：數字越小排越前面
- `icon`：SF Symbols 名稱；`color`：`#RRGGBB`
- 每個單字至少要有 `word` 和 `meaningZh`；`group` 是級數（預設 `Level 1`）
- 不用自己填 `id`：會用單字自動產生，之後更新字庫時同一個字的學習紀錄會保留

放好檔案後，到 Actions 按「📚 上架字庫」，填代號即可。
