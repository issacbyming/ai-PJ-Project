# 把「語記」裝到 iPhone 上（用 Mac + Xcode）

需要：一台 Mac、Xcode 16 以上（App Store 免費）、iPhone（iOS 17 以上）、傳輸線、一組 Apple ID。
**不需要付費的 Apple Developer 帳號**，免費 Apple ID 就能裝到自己的手機，只是每 7 天要重新按一次執行（見最後一節）。

## 懶人版：一行指令

接上 iPhone、Xcode 登入過 Apple ID 之後，在終端機：

```bash
git clone https://github.com/issacbyming/ai-PJ-Project.git && cd ai-PJ-Project && git checkout claude/voicenote-ios
cd ios/VoiceNote && ./install-to-iphone.sh
```

腳本會自己找裝置、找簽章、編譯、安裝。失敗會印出原因。下面是手動版。

## 1. 拿到程式碼

打開「終端機」：

```bash
git clone https://github.com/issacbyming/ai-PJ-Project.git
cd ai-PJ-Project
git checkout claude/voicenote-ios
open ios/VoiceNote/VoiceNote.xcodeproj
```

Xcode 會打開專案。左邊檔案列表會看到 `VoiceNote`（App）和 `VoiceNoteCore`（文字規則套件）。第一次打開會跑幾秒「Resolving packages」，等它跑完。

## 2. 設定簽章（只做一次）

1. 左邊點最上面的藍色 **VoiceNote** 專案圖示 → 中間 TARGETS 選 **VoiceNote**。
2. 上方分頁點 **Signing & Capabilities**。
3. 勾 **Automatically manage signing**。
4. **Team** 下拉選單：
   - 如果是空的，點 **Add an Account…**，用你的 Apple ID 登入，回來再選「你的名字 (Personal Team)」。
5. **Bundle Identifier** 把 `com.example.voicenote` 改成只有你會用的字串，例如 `com.issac.voicenote`（全小寫，不能有空格）。
6. 如果下面出現紅字 "Failed to register bundle identifier"，就再換一個更獨特的，例如加上數字。

## 3. iPhone 這邊的準備

1. 用線接上 Mac。iPhone 跳出「信任這部電腦？」→ 信任。
2. iPhone 打開 **設定 → 隱私權與安全性 → 開發者模式**，開啟，手機會重開機。（iOS 16 之後要這個才能裝自己編譯的 App。這個選項只在接過 Xcode 之後才會出現，所以先接線再找。）

## 4. 編譯、安裝

1. Xcode 最上方工具列的裝置選單（寫著 "Any iOS Device" 或某個模擬器）→ 選你的 iPhone 名字。
2. 按左上角 ▶︎（或 `Cmd + R`）。
3. 第一次會花一兩分鐘。成功後 iPhone 上會出現「語記」並自動打開。

如果 iPhone 跳出「不受信任的開發者」：
iPhone **設定 → 一般 → VPN 與裝置管理** → 點你的 Apple ID → **信任**。再從主畫面打開語記。

## 5. 第一次使用

1. 允許「麥克風」和「語音辨識」權限。
2. 到 **設定** 分頁：
   - 語言選「中文（台灣）」。
   - **OpenAI 語音辨識** 貼上 OpenAI API key → 之後停止錄音會自動用雲端重新辨識，中英夾雜不會認錯。
   - **Claude 整理** 貼上 Claude API key（選用）→ 錄音頁會出現「AI 整理」。
3. 回 **錄音** 分頁，按麥克風開始講。試試看：
   - 「記下這三點，第一買牛奶，第二繳電費，第三打電話給媽媽，以上」
   - 「下午兩點開會，改三點」
4. 按停止 → 等幾秒雲端重辨識 → 按「儲存」。到 **筆記** 分頁可以切換「原文／整理後」。

## 常見問題

**編譯出現紅色錯誤**
這份程式碼是在沒有 Xcode 的環境寫的，第一次 build 可能有小錯。把錯誤訊息（Xcode 左邊紅色驚嘆號點開的那段）整段複製貼給我，我修完你再 `git pull` 重新 build。

**"Could not launch" / "Unable to install"**
通常是開發者模式沒開，或還沒在「VPN 與裝置管理」按信任。照第 3、4 節做一次。

**模擬器上語音辨識不會動**
正常。語音辨識要用實機測。

**7 天後 App 打不開**
免費 Apple ID 簽的 App 有效 7 天。接上 Mac、在 Xcode 再按一次 ▶︎ 就好，筆記和字典都還在。付費開發者帳號（每年 99 美元）可以延長到一年，也能用 TestFlight 裝。

**想更新到最新版**
```bash
cd ai-PJ-Project
git pull
```
然後在 Xcode 再按一次 ▶︎。

**專案檔打不開**
```bash
brew install xcodegen
cd ios/VoiceNote
xcodegen generate
open VoiceNote.xcodeproj
```
