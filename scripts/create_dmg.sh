#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
APP_NAME="LightL"
APP_BUNDLE="${PROJECT_DIR}/${APP_NAME}.app"
DMG_NAME="${APP_NAME}.dmg"
DMG_PATH="${PROJECT_DIR}/${DMG_NAME}"

if [ ! -d "${APP_BUNDLE}" ]; then
    echo "==> Building ${APP_NAME}.app first..."
    "${SCRIPT_DIR}/build_app.sh"
fi

echo "==> Creating ${DMG_NAME} with Applications symlink..."
DMG_TEMP_DIR="$(mktemp -d)"
cp -R "${APP_BUNDLE}" "${DMG_TEMP_DIR}/"
ln -s /Applications "${DMG_TEMP_DIR}/Applications"

rm -f "${DMG_PATH}"
hdiutil create -volname "${APP_NAME}" -srcfolder "${DMG_TEMP_DIR}" -ov -format UDZO "${DMG_PATH}"
rm -rf "${DMG_TEMP_DIR}"

echo "=========================================="
echo "✓ DMG created: ${DMG_PATH}"
echo "=========================================="
