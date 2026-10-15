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
| `--embed` | 把字幕封進一個 `.dualsub.mp4`（不重新編碼，秒出）。丟到 iPhone 用「檔案」App 或 Infuse 直接看 |
| `--burn` | 把字幕燒進畫面成 `.burn.mp4`（重新編碼，30 分鐘影片約幾分鐘）。可存進「照片」、AirPlay、傳給別人 |
| `--burn-codec h264_videotoolbox` | Mac 上用硬體加速燒錄，快很多 |
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

## 在 iPhone 上看

電腦跑完後，只要把一個檔案丟到手機：

```bash
python dualsub.py "https://www.youtube.com/watch?v=XXXX" --embed
```

1. 把 `output/影片標題 [id].dualsub.mp4` AirDrop 到 iPhone，或放進 iCloud Drive。
2. 在「檔案」App 點開就能播，播放器右下角的對話框圖示可開關字幕。
3. 想要更好的播放體驗，裝 [Infuse](https://apps.apple.com/app/id1136220934)（免費版即可），它會自動顯示字幕、記住進度，也能直接讀 iCloud Drive 或家裡電腦的共享資料夾。

想存進「照片」App 或用 AirPlay 投到電視，改用 `--burn`，字幕直接畫在畫面上，任何播放器都看得到：

```bash
python dualsub.py "URL" --burn --burn-codec h264_videotoolbox
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
