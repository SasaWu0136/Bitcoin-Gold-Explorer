# 從這裡開始：Bitcoin / Gold Explorer

## 先看網站

1. 解壓縮 `Bitcoin-Gold-Explorer.zip`。
2. 用 Chrome 開啟 `Bitcoin-Gold-Explorer/dist/index.html`。
3. 上方有四個頁面：Overview、Relationships、Dollar stress lab、Data & methods。
4. 選日期、30／60／90 筆滾動視窗，圖表會重新計算。

**網站預設是清楚標示的模擬資料，不是真實市場歷史。** 這次無法從原作業的 Google Drive 取得 CSV，也無法從本機連到 Yahoo，所以沒有冒用作業中的寫死數字當成市場結果。

## 換成真實資料

方法 A：有自己的 CSV

在 Data & methods 填資料來源後匯入 CSV。欄位必須是：

```csv
date,bitcoin,gold,dxy
```

資料為 USD 計價的 Bitcoin、黃金代理價格與美元指數水準。日期用 `YYYY-MM-DD`，數字不要加 `$` 或千分位逗號。空白價格會排除該日期；重複日期或無效價格會拒絕整份檔案。

方法 B：沿用 R / RStudio

1. 用 VS Code 開啟整個專案資料夾。
2. 在 R 或 RStudio 執行一次：

```r
install.packages(c("tidyquant", "jsonlite"))
```

3. 在專案資料夾的 Terminal 執行：

```sh
Rscript --vanilla R/refresh_data.R
```

或在 Mac 執行：

```sh
sh Refresh-Data.command
```

它會抓取原作業規劃的三個代號 `BTC-USD`、`GC=F`、`DX-Y.NYB`，預設日期是 2015-01-01 至 2026-05-24（包含結束日）。成功後更新 `dist/data.js`，重新整理網站即可看到真實歷史快照。

抓取失敗時不會覆寫舊資料，也不會自動把舊快照稱為最新行情。原始資料、清理後 CSV、計算結果及 R 套件環境會放在 `analysis-output/`。

## 這次修正什麼

- 一般相關矩陣與滾動相關性都使用「對數報酬率」。
- 不補造休市日價格；只分析三種資產都有觀測值的日期。
- 保留極端波動，不自動刪掉或美化市場風險。
- 統計、日期區間與品質資訊都根據實際資料計算。
- 當變異數是零或資料不足，顯示無法計算，不當成零相關。
- 明確標示：沒有實作 DCC-GARCH、Markov-switching 或避險成功分類。

黃金使用期貨時不等於實體黃金；美元指數也不是可直接投資的報酬。這是描述性研究工具。

## 放到 GitHub

先建立一個空 repo，例如 `Bitcoin-Gold-Explorer`，不要初始化 README。然後在 VS Code 開啟本資料夾，在 Terminal 執行（確認新 repo 名稱與網址相同）：

```sh
git init -b main
git add .
git commit -m "Build Bitcoin Gold Explorer research dashboard"
git remote add origin https://github.com/SasaWu0136/Bitcoin-Gold-Explorer.git
git push -u origin main
```

這個 GitHub repo 尚未替你建立；如果選別的名稱，必須更換 remote URL。失敗時不要用 `--force`，把錯誤貼回對話即可。

## Cloudflare Pages 設定

- Production branch：`main`
- Framework preset：`None`
- Build command：`exit 0`
- Build output directory：`dist`
- Root directory：留空

這份 ZIP 尚未部署，也沒有額外建立 Cloudflare 專案。發布前若希望直接展示真實歷史，先成功執行 R 更新並提交 `dist/data.js`；否則訪客會看到明確標示的模擬資料。

## 測試

```sh
node --test tests/analytics.test.js
Rscript --vanilla tests/test_reference.R
node --test tests/cross-language.test.js
```

R Markdown 報告模板在 `R/analysis.Rmd`；需要 Pandoc 才能輸出 HTML。本環境已驗證 R 計算與 JS 一致，但沒有 Pandoc，尚未驗證報告渲染，也尚未完成瀏覽器視覺驗證。
