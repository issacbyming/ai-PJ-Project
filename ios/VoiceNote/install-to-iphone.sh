#!/bin/bash
# 在 Mac 上一鍵把「語記」編譯並安裝到接上的 iPhone。
# 用法：cd ios/VoiceNote && ./install-to-iphone.sh [TEAM_ID] [BUNDLE_ID]
# 需要：Xcode 16+、已在 Xcode 登入 Apple ID、iPhone 接上並已信任這台電腦。
set -euo pipefail
cd "$(dirname "$0")"

TEAM_ID="${1:-}"
BUNDLE_ID="${2:-}"

echo "== 1/5 檢查 Xcode"
xcodebuild -version | head -1

echo "== 2/5 找接上的 iPhone"
DEVICE_LINE=$(xcrun xctrace list devices 2>/dev/null | grep -v Simulator | grep -E "iPhone" | head -1 || true)
if [ -z "$DEVICE_LINE" ]; then
  echo "找不到接上的 iPhone。請用傳輸線接上、在手機按「信任這部電腦」，再跑一次。"; exit 1
fi
UDID=$(echo "$DEVICE_LINE" | grep -oE '\(([0-9A-Fa-f-]{25,})\)' | tr -d '()' | tail -1)
echo "裝置：$DEVICE_LINE"

echo "== 3/5 找簽章 Team"
if [ -z "$TEAM_ID" ]; then
  TEAM_ID=$(security find-identity -v -p codesigning 2>/dev/null | grep -oE 'Apple Development: .*\(([A-Z0-9]{10})\)' | grep -oE '\([A-Z0-9]{10}\)' | tr -d '()' | head -1 || true)
fi
if [ -z "$TEAM_ID" ]; then
  echo "找不到簽章憑證。請打開 Xcode → Settings → Accounts 登入 Apple ID，然後用 Xcode 開 VoiceNote.xcodeproj 在 Signing 選一次 Team，再跑一次。"
  echo "或直接指定：./install-to-iphone.sh <TEAM_ID>"; exit 1
fi
echo "Team：$TEAM_ID"

if [ -z "$BUNDLE_ID" ]; then
  BUNDLE_ID="com.$(whoami | tr -cd 'a-z0-9').voicenote"
fi
echo "Bundle ID：$BUNDLE_ID"

echo "== 4/5 編譯（第一次會比較久）"
DERIVED="$PWD/DerivedData"
xcodebuild -project VoiceNote.xcodeproj -scheme VoiceNote \
  -destination "id=$UDID" -configuration Debug \
  -derivedDataPath "$DERIVED" -allowProvisioningUpdates \
  DEVELOPMENT_TEAM="$TEAM_ID" PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE_ID" \
  build | grep -E "error:|warning: .*VoiceNote|BUILD" || true

APP=$(find "$DERIVED/Build/Products" -name "VoiceNote.app" -path "*iphoneos*" | head -1)
if [ -z "$APP" ]; then
  echo "編譯失敗。把上面的 error 整段貼給 Claude 修。"; exit 1
fi

echo "== 5/5 安裝到 iPhone"
xcrun devicectl device install app --device "$UDID" "$APP"
xcrun devicectl device process launch --device "$UDID" "$BUNDLE_ID" || true
echo
echo "完成。若手機說「不受信任的開發者」：設定 → 一般 → VPN 與裝置管理 → 信任；"
echo "若要求「開發者模式」：設定 → 隱私權與安全性 → 開發者模式 → 開啟（會重開機），然後再跑一次這個腳本。"
