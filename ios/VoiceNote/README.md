# 語記（VoiceNote）— iOS 即時語音筆記

一個給 iPhone 用的「邊講邊出字」筆記 App，概念來自 Typeless，但針對兩個痛點重新設計：

| Typeless 的問題 | 語記的做法 |
|---|---|
| AI 會主動潤飾、改寫你講的話，日記被改到忘記原本說什麼 | **原文永遠完整保留**。每則筆記同時存「原文」與「整理後」，隨時切換；整理只是另外產生的一份 |
| 整理全靠雲端 LLM，不可控 | 預設「輕整理」在手機上用**規則**做：字典、「記下這三點」分段、「改 3 點」自我更正。不改寫任何句子。AI 整理是選用的，而且提示詞明確禁止潤飾 |
| 鍵盤拿不到麥克風，要跳回 App | 直接做成筆記 App；存好之後一鍵複製／分享到任何地方 |
| Apple 內建辨識一次只認一種語言，中英夾雜會錯 | 停止錄音後自動把整段錄音送 OpenAI 語音辨識（自動偵測語言），用結果換掉即時草稿 |

## 功能

1. **即時辨識**：Apple Speech 框架，講的同時文字就出現。支援中文（台灣／香港／中國）、英文、日文。可選「裝置端辨識」（不上網、無時間限制）。
   - **中英夾雜**：Apple 的辨識一次只能認一種語言。填入 OpenAI API key 後，App 會在錄音的同時把聲音存成 m4a，停止時送到 OpenAI 的 `/v1/audio/transcriptions`（預設 `gpt-4o-transcribe`，不指定語言讓它自動偵測），再用結果換掉即時草稿。字典的正確寫法會當成提示詞一起送。也可以關掉自動、改成手動按「中英重辨識」。
2. **字典**：輸入正確寫法與常見錯字。正確寫法會送給語音辨識當提示（`contextualStrings`），常見錯字會在整理時自動換掉。
3. **口說指令分段**：
   - 「記下這三點」「以下幾點」「總結三個重點」→ 自動變成 `1. 2. 3.`
   - 「第一、第二、第三」→ 明確指定每一點
   - 「以上」「就這樣」→ 結束清單
   - 「換行」「新段落」→ 換行／空一行
   - 「句號」「逗號」「問號」→ 標點
4. **自我更正**：「下午 2 點開會，改 3 點」→「下午 3 點開會」；「星期三，不對，星期四」；「三個蘋果，不對，五個香蕉」；「二樓，不是，是三樓」。找不到可以替換的對象時**不會亂刪**，原句保留。
5. **變更記錄**：每次整理都列出「改了什麼」（字典、更正、指令），你看得到被動到的地方。
6. **AI 整理（選用）**：填入 Claude API key 後可以把「輕整理」的結果再交給 Claude 補強分段與更正。提示詞的規則是「只能做：自我更正、依指令分段、補標點、套字典；禁止改寫、潤飾、刪贅字（除非你開啟刪語助詞）」。預設模型 Claude Opus 5.5，可在設定換成 Sonnet／Haiku。API key 存在 Keychain，只送到 `api.anthropic.com`。

## 專案結構

```
ios/VoiceNote/
├── VoiceNote.xcodeproj/        # Xcode 16 專案（用 synchronized folder，加檔案不用改專案）
├── project.yml                 # XcodeGen 備援：xcodegen generate 可重新產生專案
├── VoiceNote/                  # App（SwiftUI, iOS 17+）
│   ├── VoiceNoteApp.swift
│   ├── Models/Note.swift
│   ├── Services/SpeechRecognizer.swift   # Apple Speech 即時辨識，自動續段
│   ├── Services/CloudTranscriber.swift   # OpenAI 語音辨識（中英夾雜，multipart 上傳）
│   ├── Services/ClaudeStructurer.swift   # Claude Messages API（URLSession）
│   ├── Storage/                          # 筆記、字典 JSON；設定；Keychain
│   └── Views/                            # 錄音、筆記、字典、設定
└── VoiceNoteCore/              # 純 Swift Package：文字整理規則（可獨立測試）
    ├── Sources/VoiceNoteCore/
    │   ├── DictionaryProcessor.swift     # 字典替換
    │   ├── CommandProcessors.swift       # 標點／換行／清單指令
    │   ├── CorrectionProcessor.swift     # 自我更正
    │   ├── FillerAndCleanup.swift        # 語助詞（預設關）、收尾
    │   └── TextPipeline.swift            # 串起來
    └── Tests/VoiceNoteCoreTests/         # 單元測試
```

## 怎麼跑起來

完整的逐步安裝說明（含簽章、開發者模式、常見錯誤）在 [INSTALL.md](INSTALL.md)。

需要 macOS + Xcode 16 以上，手機 iOS 17 以上（語音辨識在模擬器上不穩，建議用實機）。

1. 用 Xcode 開 `ios/VoiceNote/VoiceNote.xcodeproj`。
2. 選 **VoiceNote** target → Signing & Capabilities → Team 選你的 Apple ID；把 Bundle Identifier 從 `com.example.voicenote` 改成你自己的（例如 `com.你的名字.voicenote`）。
3. 把 iPhone 接上、選成執行目標，按 ▶︎。第一次會要求麥克風與語音辨識權限。
4. （選用）設定 → 「OpenAI 語音辨識」貼上 OpenAI API key：之後停止錄音會自動雲端重辨識，中英夾雜不再認錯。
5. （選用）設定 → 「Claude 整理」貼上 Claude API key，錄音頁就會出現「AI 整理」。

跑文字規則的單元測試：

```bash
cd ios/VoiceNote/VoiceNoteCore
swift test
```

如果 `VoiceNote.xcodeproj` 打不開（Xcode 版本太舊之類），用 XcodeGen 重新產生：

```bash
brew install xcodegen
cd ios/VoiceNote
xcodegen generate
```

## 設計原則

- **原文不可變**：`Note.rawText` 存了就不改；所有整理都寫到 `processedText`，而且可以用原文重跑。
- **先規則、後 AI**：規則版本在手機上跑、可預期、可測試；AI 只在你主動按或在設定裡選「AI 整理」時才用。
- **寧可不改也不亂改**：自我更正找不到明確對象（例如「很開心，不對，很難過」這種要靠語意的）就原文保留，留給 AI 或你自己處理。

## 已知限制／下一步

- **還不是鍵盤**：iOS 自訂鍵盤拿不到麥克風（Typeless 也是跳回主 App 錄音再把字送回去）。要做鍵盤的話，下一步是加一個 Keyboard Extension，按鈕用 URL scheme 打開語記錄音，存完透過 App Group 把文字塞回鍵盤。
- OpenAI 重辨識不是即時的：講的時候看到的是 Apple 的草稿，停止後幾秒才換成正確版本。單段錄音上限 25 MB（AAC 大約可錄一小時）。
- Apple 雲端辨識每段大約一分鐘會自動收尾、再接著下一段，中間可能漏掉半秒；想長時間錄建議開「裝置端辨識」。
- 自我更正目前靠「數字＋單位」與字形相似度，語意層面的更正（「很開心，不對，很難過」）交給 AI 整理。
- 這份程式碼是在沒有 Xcode 的環境寫出來的，還沒有實機編譯過；第一次 build 若有小錯誤，照錯誤訊息修即可。
