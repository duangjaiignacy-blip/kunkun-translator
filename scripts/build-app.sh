#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

APP_NAME="困困翻译助手"
APP_DIR="build/${APP_NAME}.app"
BIN_NAME="TranslatorApp"

echo "→ Build release binary"
swift build -c release

echo "→ Ensure icon (always regenerate so name changes propagate)"
rm -f build/AppIcon.icns build/icon-1024.png
if [[ ! -f build/AppIcon.icns ]]; then
  swift scripts/gen-icon.swift build/icon-1024.png
  rm -rf build/AppIcon.iconset
  mkdir -p build/AppIcon.iconset
  SRC=build/icon-1024.png
  sips -z 16 16     "$SRC" --out build/AppIcon.iconset/icon_16x16.png      >/dev/null
  sips -z 32 32     "$SRC" --out build/AppIcon.iconset/icon_16x16@2x.png   >/dev/null
  sips -z 32 32     "$SRC" --out build/AppIcon.iconset/icon_32x32.png      >/dev/null
  sips -z 64 64     "$SRC" --out build/AppIcon.iconset/icon_32x32@2x.png   >/dev/null
  sips -z 128 128   "$SRC" --out build/AppIcon.iconset/icon_128x128.png    >/dev/null
  sips -z 256 256   "$SRC" --out build/AppIcon.iconset/icon_128x128@2x.png >/dev/null
  sips -z 256 256   "$SRC" --out build/AppIcon.iconset/icon_256x256.png    >/dev/null
  sips -z 512 512   "$SRC" --out build/AppIcon.iconset/icon_256x256@2x.png >/dev/null
  sips -z 512 512   "$SRC" --out build/AppIcon.iconset/icon_512x512.png    >/dev/null
  cp "$SRC"             build/AppIcon.iconset/icon_512x512@2x.png
  iconutil -c icns -o build/AppIcon.icns build/AppIcon.iconset
fi

echo "→ Assemble ${APP_DIR}"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp ".build/release/$BIN_NAME" "$APP_DIR/Contents/MacOS/$BIN_NAME"
cp build/AppIcon.icns "$APP_DIR/Contents/Resources/AppIcon.icns"

cat > "$APP_DIR/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>困困翻译助手</string>
    <key>CFBundleDisplayName</key><string>困困翻译助手</string>
    <key>CFBundleIdentifier</key><string>com.local.translator</string>
    <key>CFBundleExecutable</key><string>${BIN_NAME}</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>0.1</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSAppleEventsUsageDescription</key><string>用于在任意 App 中读取选中的英文文字</string>
    <key>NSAccessibilityUsageDescription</key><string>用于在任意 App 中读取你选中的文字进行翻译</string>
</dict>
</plist>
PLIST

echo "→ Sign with stable local identity (so Accessibility permission survives rebuilds)"
# 用固定的自签名证书签名：TCC 授权记录绑定到证书指纹，重新编译后依然有效。
# 如果这张证书不存在，回退到 ad-hoc（但那样每次重编都得重新授权辅助功能）。
SIGN_NAME="KUN Translator Local Signing"
# 同名证书可能不止一张，按指纹（SHA-1）签名才不会歧义。取第一张有效的。
SIGN_HASH="$(security find-identity -v -p codesigning | grep "$SIGN_NAME" | head -1 | awk '{print $2}')"
if [[ -n "$SIGN_HASH" ]]; then
  codesign --force --deep --sign "$SIGN_HASH" "$APP_DIR" 2>&1 | tail -3
  echo "   signed with: $SIGN_NAME ($SIGN_HASH)"
else
  echo "   ⚠️  未找到证书「$SIGN_NAME」，回退 ad-hoc（重编后需重新授权辅助功能）"
  codesign --force --deep --sign - "$APP_DIR" 2>&1 | tail -3
fi

echo "→ Done: $APP_DIR"
echo ""
echo "Install:"
echo "  ditto '$APP_DIR' '/Applications/${APP_NAME}.app'"
echo "Run:"
echo "  open '/Applications/${APP_NAME}.app'"
