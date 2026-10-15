# dualsub：YouTube 影片中英雙語字幕

貼上 YouTube 網址，跑完後用播放器打開影片，就有「中文在上、英文在下」的雙語字幕。

流程：`yt-dlp` 下載影片和英文字幕 → Claude 整段翻譯成中文 → 輸出與影片同名的字幕檔 → 播放器自動載入。
沒有英文字幕的影片可以改用 `faster-whisper` 在本機轉錄。

## 安裝（只需做一次）

需要 Python 3.10 以上，以及 ffmpeg（yt-dlp 合併影音用）。

```bash
# macOS
brew install ffmpeg
# Windows：winget install ffmpeg   或  https://ffmpeg.org/download.html

cd tools/dualsub
python3 -m venv .venv
source .venv/bin/activate        # Windows: .venv\Scripts\activate
pip install -r requirements.txt

cp .env.example .env             # 然後把 ANTHROPIC_API_KEY 填進去
```

播放器建議：macOS 用 [IINA](https://iina.io)，Windows 用 [mpv](https://mpv.io) 或 [VLC](https://www.videolan.org)。三者都會自動載入同名字幕。

## 使用

```bash
source .venv/bin/activate
python dualsub.py "https://www.youtube.com/watch?v=XXXXXXXX"
```

跑完後影片和字幕都在 `tools/dualsub/output/`：

```
output/
  影片標題 [id].mp4        ← 用播放器打開這個
  影片標題 [id].srt        ← 雙語字幕，自動載入
  影片標題 [id].en.json    ← 英文字幕快取
  影片標題 [id].zh-TW.json ← 翻譯快取（重跑不會再花錢）
```

常用選項：

| 選項 | 說明 |
|---|---|
| `--format ass` | 輸出 .ass，中文大字、英文小字灰色。`--zh-font` 可換字型（Windows 建議 `"Microsoft JhengHei"`） |
| `--embed` | 用 ffmpeg 把字幕封進一個 `.mkv`，方便丟到其他裝置看，不重新編碼 |
| `--model claude-haiku-5-5` | 換便宜的模型。也可以在 `.env` 設 `DUALSUB_MODEL` |
| `--lang zh-CN` | 翻成簡體 |
| `--whisper` | 影片沒有英文字幕時用本機轉錄。需先 `pip install faster-whisper`，第一次會下載模型 |
| `--whisper-model medium` | 轉錄模型大小，越大越準越慢（預設 `small`） |
| `--no-translate` | 只抓英文字幕不翻譯，用來先檢查字幕品質 |
| `--force` | 忽略快取重新翻譯 |

本機已經有的影片也可以：

```bash
python dualsub.py ~/Movies/talk.mp4 --whisper
```

## 費用

翻譯一支 30 分鐘、約 5000 個英文字的影片：

| 模型 | 約略費用 |
|---|---|
| `claude-opus-5-5`（預設，翻得最自然） | 約 0.25 美元 |
| `claude-sonnet-5-5` | 約 0.1 美元 |
| `claude-haiku-5-5` | 不到 0.01 美元 |

翻譯結果會快取在 `*.zh-TW.json`，同一支影片重跑不會再收費。

## 為什麼這樣設計

- **先用 YouTube 自己的英文字幕**：大多數英文影片都有，時間軸已對好，幾秒就抓完。Whisper 只當備案。
- **整段翻譯而不是逐句**：每批 50 句一起送，並附上前 6 句當上下文，專有名詞和語氣才會前後一致。
- **不把字幕燒進影片**：軟字幕不用重新編碼，秒出，而且之後想改翻譯只要改 .srt。
- **翻譯失敗自動重試**：Claude 回傳的句數對不上時會重送，最多三次。

## 注意

用 yt-dlp 下載影片在技術上違反 YouTube 服務條款，請只用於個人觀看，不要散布。
