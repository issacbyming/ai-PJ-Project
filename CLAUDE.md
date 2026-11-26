# ai-PJ-Project：跨年行程共編網站（/newyear）

這個 repo 原本是聊天機器人範本（`app/(chat)`），另有其他分支在做別的東西。這份只管「從新坡到三星」跨年行程共編網站，程式在分支 `claude/nifty-noether-c9ppqd`，**還沒併進 main**。

## 這是什麼
- 給親友一起排 12/31–1/2 跨年行程的手機網頁：時段裡放「吃的／玩的／節目」卡片，卡片可以按表情（👍 支持等五種）和留言；底部「口袋」放還沒排時段的點子。免登入，拿到網址的人都能改。
- 正式網址：https://xinpo-sanxing-2027.vercel.app （根目錄會轉到 /newyear）。Vercel 專案 `xinpo-sanxing-2027`（issacbyming's projects）。
- 程式：`app/(newyear)`、`components/newyear`、`lib/newyear`；固定文案在 `lib/newyear/config.ts`。

## 資料庫
- 借用 Vercel 上的 Supabase「ai-service-live-feedback」（Rax「AI 時代服務思考」課的現場回饋工具在用）。環境變數由 Vercel 的 Storage 連線自動帶入，不用手動設。
- 跨年網站只用 `ny_slots`、`ny_items`、`ny_comments`、`ny_reactions` 四張表，由 `supabase/migrations/` 依檔名順序建立。
- 那個資料庫原有的表（sessions、responses、speaker_state、analysis_runs、rate_hits）全部開 RLS、沒有任何開放規則，公開金鑰讀不到。**不要動它們、不要替它們加 policy。**
- 免費方案約 7 天沒人用會暫停：到 Vercel → Storage → ai-service-live-feedback 按 Resume，資料不會不見。

## 怎麼部署
- Vercel 的正式分支是 main，但這個網站在別的分支，所以用指令部署：在這個分支的資料夾 `vercel link --yes --project xinpo-sanxing-2027 --scope issacbymings-projects`，再 `vercel deploy --prod --yes`。
- 改了 `NEXT_PUBLIC_` 開頭的環境變數要重新部署才生效。
- 改動後跑：`pnpm type-check`、`pnpm lint`、`pnpm build`。

## 否決清單（Rax 說過不要的，整個產品都適用）
- 【2026-11-26】不要暫停或刪除任何 Supabase 專案（其他網站在用）。檢查方式：Vercel → Storage 兩個資料庫都還在、狀態 Available。
- 【2026-11-27】不要用 supabase-blue-flame（dreamtraveler-club 的資料庫）：Rax 說 dreamtraveler-club 不要在這裡。檢查方式：`vercel integration list --all` 裡 supabase-blue-flame 只連 dreamtraveler-club。
- 【2026-11-27】借用的資料庫裡「AI 時代服務思考」的資料要保留：不刪、不改那邊原有的表。檢查方式：跑 migration 前後，原有 5 張表的筆數一樣。
- 【2026-11-26】要不要開 PR 併進 main，先問 Rax。

## 交付前必測（曾經壞過的）
- 頁面出現「目前是單機試用」黃框 → 代表沒接上資料庫。測法：打開正式網址，頁首不該有那個黃框（2026-11-27 加入）。
- 兩支手機看到的內容不同步 → 測法：開兩個分頁，一邊新增卡片、按表情、留言，另一邊不重新整理也要出現；測完刪掉測試資料（2026-11-27 加入）。
