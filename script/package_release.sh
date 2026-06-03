#!/usr/bin/env bash
set -euo pipefail

APP_NAME="GongLaoBu"
APP_DISPLAY_NAME="功劳簿"
BUNDLE_ID="com.houtao.GongLaoBu"
MIN_SYSTEM_VERSION="14.0"
APP_VERSION="${APP_VERSION:-0.1.0}"
APP_BUILD="${APP_BUILD:-1}"
SIGN_IDENTITY="${SIGN_IDENTITY:-}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
RELEASE_DIR="$DIST_DIR/release"
APP_BUNDLE="$RELEASE_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_BINARY="$APP_MACOS/$APP_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"
APP_ICON_SOURCE="$ROOT_DIR/Resources/AppIcon.icns"
ZIP_PATH="$RELEASE_DIR/$APP_NAME-$APP_VERSION-macOS.zip"
DMG_PATH="$RELEASE_DIR/$APP_NAME-$APP_VERSION-macOS.dmg"

cd "$ROOT_DIR"

swift build -c release
BUILD_BINARY="$(swift build -c release --show-bin-path)/$APP_NAME"

rm -rf "$RELEASE_DIR"
mkdir -p "$APP_MACOS" "$APP_RESOURCES"
cp "$BUILD_BINARY" "$APP_BINARY"
chmod +x "$APP_BINARY"

if [[ -f "$APP_ICON_SOURCE" ]]; then
  cp "$APP_ICON_SOURCE" "$APP_RESOURCES/AppIcon.icns"
fi

cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleName</key>
  <string>$APP_DISPLAY_NAME</string>
  <key>CFBundleDisplayName</key>
  <string>$APP_DISPLAY_NAME</string>
  <key>CFBundleShortVersionString</key>
  <string>$APP_VERSION</string>
  <key>CFBundleVersion</key>
  <string>$APP_BUILD</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>LSApplicationCategoryType</key>
  <string>public.app-category.productivity</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
  <key>NSHumanReadableCopyright</key>
  <string>作者：hal3000</string>
  <key>NSCalendarsUsageDescription</key>
  <string>功劳簿需要访问系统日历，用于把当天紧急重要任务导入到单独的功劳簿日历。</string>
  <key>NSCalendarsFullAccessUsageDescription</key>
  <string>功劳簿需要完整日历访问权限，用于更新当天已导入的紧急重要任务，避免重复创建日程。</string>
  <key>NSCalendarsWriteOnlyAccessUsageDescription</key>
  <string>功劳簿需要写入系统日历，用于导入当天紧急重要任务。</string>
</dict>
</plist>
PLIST

plutil -lint "$INFO_PLIST"

if [[ -n "$SIGN_IDENTITY" ]]; then
  codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$APP_BUNDLE"
else
  codesign --force --sign - "$APP_BUNDLE"
fi

codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"

rm -f "$ZIP_PATH" "$DMG_PATH"
(
  cd "$RELEASE_DIR"
  ditto -c -k --keepParent "$APP_NAME.app" "$ZIP_PATH"
)

hdiutil create \
  -volname "$APP_DISPLAY_NAME" \
  -srcfolder "$APP_BUNDLE" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

echo "Release app: $APP_BUNDLE"
echo "Release zip: $ZIP_PATH"
echo "Release dmg: $DMG_PATH"

if [[ -z "$SIGN_IDENTITY" ]]; then
  echo "Signing: ad-hoc. Set SIGN_IDENTITY to a Developer ID identity for notarizable releases."
fi
