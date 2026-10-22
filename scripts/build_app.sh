#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
APP_NAME="LightL"
APP_BUNDLE="${PROJECT_DIR}/${APP_NAME}.app"
BUILD_DIR="${PROJECT_DIR}/.build/release"

echo "==> Building ${APP_NAME} in Release mode..."
cd "${PROJECT_DIR}"
swift build -c release

echo "==> Packaging into ${APP_NAME}.app..."
rm -rf "${APP_BUNDLE}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

cp "${BUILD_DIR}/${APP_NAME}" "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"
if [ -d "${PROJECT_DIR}/Sources/LightL/Resources" ]; then
    cp -R "${PROJECT_DIR}/Sources/LightL/Resources/"* "${APP_BUNDLE}/Contents/Resources/"
fi

cat << 'EOF' > "${APP_BUNDLE}/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleLocalizations</key>
    <array>
        <string>en</string>
        <string>ru</string>
    </array>
    <key>CFBundleExecutable</key>
    <string>LightL</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIconName</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.puhavik.LightL</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>LightL</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>15.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSAppleEventsUsageDescription</key>
    <string>Требуется для чтения и вставки текста в сторонних приложениях.</string>
</dict>
</plist>
EOF

# Find Apple Development certificate or use custom SIGNING_IDENTITY env var
DEV_IDENTITY="${SIGNING_IDENTITY:-}"
if [ -z "$DEV_IDENTITY" ]; then
    DEV_IDENTITY=$(security find-identity -p codesigning -v 2>/dev/null | grep "Apple Development" | head -n 1 | sed -E 's/.*"([^"]+)".*/\1/' || true)
fi

if [ -n "$DEV_IDENTITY" ]; then
    echo "==> Signing ${APP_NAME}.app with stable developer certificate: ${DEV_IDENTITY}..."
    codesign --force --deep --sign "${DEV_IDENTITY}" "${APP_BUNDLE}"
else
    echo "==> Signing ${APP_NAME}.app (ad-hoc)..."
    codesign --force --deep --sign - "${APP_BUNDLE}"
fi

echo "=========================================="
echo "✓ Сборка завершена успешно!"
echo "Приложение создано: ${APP_BUNDLE}"
echo "Для запуска выполните: open ${APP_BUNDLE}"
echo "=========================================="
